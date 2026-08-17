import AppKit
import KeyboardShortcuts
import os.log

private let logger = Logger(subsystem: "com.rahul.beru", category: "coordinator")

@MainActor
final class AppCoordinator {
    private let appState = AppState()
    private lazy var panelController = PanelController(appState: appState)
    private lazy var engine = PanelEngine(appState: appState) { [weak self] in
        self?.dismiss()
    }
    private var onboardingWindow: OnboardingWindowController?
    private var dashboardWindow: DashboardWindowController?

    /// Where the next transcript should land. Dictation drives two different
    /// fields — the instruction, and the text being worked on — and the
    /// recogniser has no idea which, so the coordinator remembers.
    private enum DictationDestination {
        case instruction
        case sourceText
    }
    private var dictationDestination: DictationDestination = .instruction

    private lazy var pushToTalk = PushToTalkMonitor(
        fieldHasText: { [weak self] in
            !(self?.appState.describeInstruction.isEmpty ?? true)
        },
        onPress: { [weak self] in self?.beginPushToTalk() },
        onRelease: { DictationService.shared.stop() },
        onEscape: { [weak self] in self?.dismiss() }
    )

    func start() {
        logger.notice("start() called; registering hotkey")
        engine.onStreamingEnded = { [weak self] in
            self?.panelController.streamingDidEnd()
        }
        // Switching to a local provider should start loading its weights now,
        // not on the next hotkey press.
        SettingsStore.shared.onProviderChanged = { [weak self] _ in
            self?.warmUpProvider()
        }
        KeyboardShortcuts.onKeyDown(for: .invokeBeru) { [weak self] in
            logger.notice("hotkey fired")
            self?.invoke()
        }
        KeyboardShortcuts.onKeyDown(for: .dictateToBeru) { [weak self] in
            logger.notice("dictate hotkey fired")
            self?.invokeVoiceAsk()
        }

        engine.onRequestDictationPermission = { [weak self] in
            self?.showDashboard(route: .permissions)
        }
        DictationService.shared.onText = { [weak self] text in
            self?.applyDictated(text)
        }
        // Escape while the panel is up. The dictate shortcut is global so it
        // can open Ask and start listening from any app.

        let trusted = Permissions.isAccessibilityTrusted()
        logger.notice("initial accessibility trusted = \(trusted)")
        if !trusted || !SettingsStore.shared.hasCompletedGetStarted {
            showOnboarding()
        }

        UsageLog.start()

        // Pre-load local model weights so the first invocation streams
        // immediately instead of paying a cold start.
        warmUpProvider()
        migrateDictateShortcutIfNeeded()
    }

    /// Fire-and-forget pre-load of the model the next invocation will most
    /// likely need; a no-op for remote providers. Warms exactly one model —
    /// warming both roles would make the server evict and swap weights.
    private func warmUpProvider() {
        let provider = ProviderRegistry.activeProvider()
        let role = ActionRegistry.shared.action(withID: appState.selectedActionID)?.role
            ?? ActionRegistry.shared.action(withID: SettingsStore.shared.defaultActionID)?.role
            ?? .grammar
        Task.detached(priority: .utility) {
            await provider.warmUp(role: role)
        }
    }

    func invoke() {
        let trusted = Permissions.isAccessibilityTrusted()
        logger.notice("invoke() accessibility trusted = \(trusted)")
        guard trusted else {
            showOnboarding()
            return
        }

        // Overlap the model load with text capture (up to 150 ms) so a model
        // idled out by Ollama's keep-alive is loading while we read the
        // selection.
        warmUpProvider()

        Task {
            // Pin the host app's focused element now, before our panel takes
            // key status; Replace targets this element later.
            let targetElement = TextCapture.focusedElement()
            let host = HostApp.identify(from: targetElement)
            let result = await TextCapture.captureSelection()
            switch result {
            case .text(let text):
                logger.notice("captured text, length = \(text.count)")
                presentPanel(with: text, targetElement: targetElement, host: host)
            case .empty:
                logger.notice("capture returned empty")
                presentEmptySelectionNotice()
            }
        }
    }

    func enhanceClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            // Clipboard is empty or has no text — show an intent-ready panel
            // so the user gets feedback and can type or dictate text instead
            // of seeing nothing happen. Matches the hotkey behavior when there's
            // no selection.
            presentPanel(with: "", host: HostApp.identify(from: nil), source: "clipboard", openOnSearch: true)
            return
        }
        presentPanel(with: text, host: HostApp.identify(from: nil), source: "clipboard")
    }

    /// Opens the panel on arbitrary text (pinned runs, paste).
    func enhanceText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        presentPanel(with: trimmed, host: HostApp.identify(from: nil), source: "vault")
    }

    /// Opens the panel on a vault note; Replace applies the result back to that note.
    func enhanceNote(id: String) {
        guard let note = VaultStore.shared.note(id: id) else { return }
        let body = note.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        presentPanel(
            with: body,
            host: HostApp.identify(from: nil),
            vaultNoteID: note.id,
            source: "vault"
        )
    }

    private func presentPanel(
        with rawText: String,
        targetElement: AXUIElement? = nil,
        host: HostApp.Info? = nil,
        vaultNoteID: String? = nil,
        recordEmptySelection: Bool = false,
        source: String? = nil,
        openOnSearch: Bool = false
    ) {
        let (text, wasTruncated) = truncatedIfNeeded(rawText)
        // Use the element pinned *before* capture/panel focus — focused AX after
        // show is Beru, which has no selection and used to mouse-anchor drift.
        let anchor = SelectionLocator.anchorPoint(for: targetElement)
        logger.notice("presenting panel at anchor = \(anchor.debugDescription)")
        appState.reset(withCapturedText: text)
        appState.capturedElement = targetElement
        appState.hostBundleID = host?.bundleID
        appState.hostAppName = host?.name
        appState.vaultNoteID = vaultNoteID
        snapshotClipboard(relativeTo: text)
        appState.selectedTargetID = TargetRegistry.resolveTargetID(
            bundleID: host?.bundleID,
            appName: host?.name,
            perApp: SettingsStore.shared.lastTargetByApp,
            lastUsed: SettingsStore.shared.lastTargetID,
            known: Set(TargetRegistry.shared.profiles.map(\.id))
        )
        appState.truncationNotice = wasTruncated
        appState.isPanelVisible = true
        engine.resetForNewInvocation()

        let invocationID = appState.invocationID
        let selectedTarget = appState.selectedTargetID
        if recordEmptySelection {
            UsageLog.record { UsageEvent(invocationID: invocationID, kind: .emptySelection) }
        } else {
            let resolvedSource = source
                ?? (targetElement == nil ? "clipboard" : "hotkey")
            UsageLog.record {
                UsageEvent(
                    invocationID: invocationID,
                    kind: .invoked,
                    source: resolvedSource,
                    hostBundleID: host?.bundleID,
                    hostAppName: host?.name,
                    targetID: selectedTarget,
                    inputText: text,
                    truncated: wasTruncated
                )
            }
        }
        // Empty hotkey → AI Search. Text selected in Cursor / Claude / ChatGPT
        // → Enhance with that target. Anything else → Settings default skill.
        if openOnSearch {
            appState.selectAction(EnhancementAction.searchID)
        } else if host.flatMap({ TargetProfile.seededID(forBundleID: $0.bundleID, name: $0.name) }) != nil {
            appState.selectAction(EnhancementAction.enhanceID)
        } else {
            appState.selectAction(SettingsStore.shared.defaultActionID)
        }
        panelController.show(at: anchor, appState: appState, engine: engine)
        // The dictate key listens only while the panel is up.
        pushToTalk.arm()
        // Search waits for a query. Skills auto-run only when there is text.
        let hasCapture = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasCapture, appState.selectedActionID != EnhancementAction.searchID {
            engine.startIfNeeded(actionID: appState.selectedActionID)
        }
    }

    /// Pasteboard snapshot for the context chip. Only kept when it differs from
    /// the selection so we never show a redundant Clipboard chip.
    private func snapshotClipboard(relativeTo selection: String) {
        appState.includeClipboard = false
        guard let clip = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !clip.isEmpty,
              clip != selection.trimmingCharacters(in: .whitespacesAndNewlines) else {
            appState.clipboardText = nil
            return
        }
        appState.clipboardText = clip
    }

    /// Opens Beru in Ask and starts listening. Press the same shortcut again to stop.
    func invokeVoiceAsk() {
        if DictationService.shared.isRecording {
            DictationService.shared.stop()
            return
        }

        let trusted = Permissions.isAccessibilityTrusted()
        logger.notice("invokeVoiceAsk() accessibility trusted = \(trusted)")
        guard trusted else {
            showOnboarding()
            return
        }

        if appState.isPanelVisible {
            appState.selectAction(EnhancementAction.searchID)
            beginVoiceAsk()
            return
        }

        Task {
            let targetElement = TextCapture.focusedElement()
            let host = HostApp.identify(from: targetElement)
            let result = await TextCapture.captureSelection()
            let text: String
            switch result {
            case .text(let captured): text = captured
            case .empty: text = ""
            }
            presentPanel(
                with: text,
                targetElement: targetElement,
                host: host,
                openOnSearch: true
            )
            beginVoiceAsk()
        }
    }

    /// Opens the panel in Ask and starts dictating a question.
    func dictateNewText() {
        invokeVoiceAsk()
    }

    /// No selection: open an intent-ready panel so the user can type or dictate
    /// instead of seeing a two-second error dismiss.
    private func presentEmptySelectionNotice() {
        let targetElement = TextCapture.focusedElement()
        let host = HostApp.identify(from: targetElement)
        presentPanel(
            with: "",
            targetElement: targetElement,
            host: host,
            recordEmptySelection: true,
            openOnSearch: true
        )
    }

    private func truncatedIfNeeded(_ text: String) -> (String, Bool) {
        guard text.count > PanelEngine.maxCapturedLength else { return (text, false) }
        let truncated = String(text.prefix(PanelEngine.maxCapturedLength))
        return (truncated, true)
    }

    /// Routes a transcript to whichever field the dictation was started for.
    private func applyDictated(_ text: String) {
        switch dictationDestination {
        case .instruction:
            appState.describeInstruction = text
        case .sourceText:
            appState.capturedText = text
        }
    }

    /// Start listening into the Ask field.
    private func beginVoiceAsk() {
        dictationDestination = .instruction
        guard !DictationService.shared.start() else { return }
        if let reason = DictationService.shared.availability.message {
            appState.setResult(.error(reason), for: appState.selectedActionID)
        }
    }

    /// Toggle listening from the panel mic.
    private func beginPushToTalk() {
        beginVoiceAsk()
    }

    private func dismiss() {
        // Never leave the microphone live, or the key intercepted, because a
        // panel went away.
        pushToTalk.disarm()
        DictationService.shared.cancel()
        dictationDestination = .instruction
        panelController.hide()
        appState.dismiss()
    }

    /// Existing installs stored Space as the dictate shortcut. Toggle-to-talk
    /// cannot use a bare Space, so move that old default to Control-Option-Command-L
    /// once. A shortcut the user actually chose is left alone.
    private func migrateDictateShortcutIfNeeded() {
        let key = "migratedDictateShortcutFromSpace"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        let current = KeyboardShortcuts.getShortcut(for: .dictateToBeru)
        let oldDefault = KeyboardShortcuts.Shortcut(.space)
        guard current == nil || current == oldDefault else { return }
        KeyboardShortcuts.setShortcut(
            KeyboardShortcuts.Shortcut(.l, modifiers: [.control, .option, .command]),
            for: .dictateToBeru
        )
    }

    private func showOnboarding() {
        if onboardingWindow == nil {
            onboardingWindow = OnboardingWindowController { [weak self] in
                self?.showDashboard(route: .models)
            }
        }
        onboardingWindow?.show()
    }

    /// Opens the dashboard, creating it on first use so an install that never
    /// opens it pays nothing for it.
    func showDashboard(route: DashboardRoute? = nil) {
        if dashboardWindow == nil {
            dashboardWindow = DashboardWindowController(
                enhanceText: { [weak self] text in self?.enhanceText(text) },
                enhanceNote: { [weak self] id in self?.enhanceNote(id: id) }
            )
        }
        dashboardWindow?.show(route: route)
    }
}
