import AppKit
import KeyboardShortcuts
import os.log

private let logger = Logger(subsystem: "com.rahul.beru", category: "coordinator")

@MainActor
final class AppCoordinator {
    let appState = AppState()
    lazy var panelController = PanelController(appState: appState)
    lazy var engine = PanelEngine(appState: appState) { [weak self] in
        self?.dismiss()
    }
    var onboardingWindow: OnboardingWindowController?
    var dashboardWindow: DashboardWindowController?
    var openingPanelAfterGetStarted = false

    /// Where the next transcript should land. Dictation drives two different
    /// fields — the instruction, and the text being worked on — and the
    /// recogniser has no idea which, so the coordinator remembers.
    enum DictationDestination {
        case instruction
        case sourceText
    }
    var dictationDestination: DictationDestination = .instruction

    lazy var pushToTalk = PushToTalkMonitor(
        fieldHasText: { [weak self] in
            !(self?.appState.describeInstruction.isEmpty ?? true)
        },
        onPress: { [weak self] in self?.beginPushToTalk() },
        onRelease: { DictationService.shared.stop() },
        onEscape: { [weak self] in self?.dismiss() }
    )

    func start() {
        logger.notice("start() called; registering hotkey")
        engine.onStreamingStarted = { [weak self] in
            self?.panelController.streamingDidStart()
        }
        engine.onStreamingEnded = { [weak self] in
            self?.panelController.streamingDidEnd()
        }
        KeyboardShortcuts.onKeyDown(for: .invokeBeru) { [weak self] in
            logger.notice("hotkey fired")
            self?.handleInvokeHotkey()
        }
        KeyboardShortcuts.onKeyDown(for: .dictateToBeru) { [weak self] in
            logger.notice("dictate hotkey fired")
            self?.invokeVoiceAsk()
        }
        let invoke = KeyboardShortcuts.getShortcut(for: .invokeBeru)?.description ?? "nil"
        logger.notice("invoke shortcut bound = \(invoke, privacy: .public)")

        engine.onRequestDictationPermission = { [weak self] in
            self?.showDashboard(route: .permissions)
        }
        engine.onRequestProviderSetup = { [weak self] preferLocal in
            if preferLocal {
                // "Use a local model": the zero-install one when this Mac can
                // answer, otherwise Ollama.
                SettingsStore.shared.selectProvider(
                    AppleModelState.isConfigured ? .apple : .ollama
                )
            }
            self?.showDashboard(route: .models)
        }
        engine.onOpenSettings = { [weak self] in
            // The requested order: the panel goes away first, then Settings
            // appears. dismiss() also disarms the mic and cancels any run.
            self?.dismiss()
            self?.showDashboard(route: .general)
        }
        engine.onRevealVaultNote = { [weak self] id in
            self?.revealVaultNote(id)
        }
        DictationService.shared.onText = { [weak self] text in
            self?.applyDictated(text)
        }
        // Escape while the panel is up. The dictate shortcut is global so it
        // can open Ask and start listening from any app.

        let trusted = Permissions.isAccessibilityTrusted()
        logger.notice("initial accessibility trusted = \(trusted)")
        if !SettingsStore.shared.hasCompletedGetStarted {
            showOnboarding()
        } else {
            checkPostUpdateTrust()
        }

        UsageLog.start()

        // No warm-up here: with launch at login that loaded a multi-GB local
        // model into memory before the user asked for anything. The hotkey
        // warms the model instead, overlapping the load with text capture.
        migrateDictateShortcutIfNeeded()
        AppUpdateService.shared.check()
    }

    /// Fire-and-forget pre-load of the model the next invocation will most
    /// likely need; a no-op for remote providers. Warms exactly one model —
    /// warming both roles would make the server evict and swap weights.
    func warmUpProvider() {
        let provider = ProviderRegistry.activeProvider()
        let role = ActionRegistry.shared.action(withID: appState.selectedActionID)?.role
            ?? ActionRegistry.shared.action(withID: SettingsStore.shared.defaultActionID)?.role
            ?? .grammar
        Task.detached(priority: .utility) {
            await provider.warmUp(role: role)
        }
    }

    func handleInvokeHotkey() {
        if onboardingWindow?.isPresented == true {
            openPanelAfterGetStarted()
            return
        }
        invoke()
    }

    func invoke() {
        if !SettingsStore.shared.hasCompletedGetStarted {
            showOnboarding()
            return
        }

        let trusted = Permissions.isAccessibilityTrusted()
        logger.notice("invoke() accessibility trusted = \(trusted)")
        if !trusted {
            Permissions.requestAccessibilityIfNeeded()
            presentEmptySelectionNotice()
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
            let isEditableField = TextCapture.isEditableElement(targetElement)
            let windowTitle = HostApp.focusedWindowTitle()
            let result = await TextCapture.captureSelection()
            switch result {
            case .text(let text):
                logger.notice("captured text, length = \(text.count)")
                presentPanel(
                    with: text,
                    targetElement: targetElement,
                    host: host,
                    isEditableField: isEditableField,
                    windowTitle: windowTitle
                )
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

    func presentPanel(
        with rawText: String,
        targetElement: AXUIElement? = nil,
        host: HostApp.Info? = nil,
        vaultNoteID: String? = nil,
        recordEmptySelection: Bool = false,
        source: String? = nil,
        openOnSearch: Bool = false,
        isEditableField: Bool = false,
        windowTitle: String? = nil
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
        // A different app is a different conversation. Dropped here rather than
        // at the moment of switching so the thread survives a trip to another
        // app and back without invoking, which is how you go and look something
        // up mid-edit.
        SessionThread.shared.hostChanged(to: host?.bundleID)
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
        // Route the landing chip from where the invoke came. Unconfigured
        // installs stay on AI Search so setup copy is visible.
        let needsSetup = !SettingsStore.shared.isConfigured(SettingsStore.shared.activeProvider)
        // Telemetry distinguishes a real clipboard paste ("clipboard") from a
        // hotkey whose selection needed the Cmd-C fallback (still a hotkey
        // invoke — the fallback just leaves no pinned element). Only the
        // caller-set sources are real paste flows, so ROUTING treats any
        // unset source as the hotkey.
        let resolvedSource = source
            ?? (targetElement == nil ? "clipboard" : "hotkey")
        let routingSource = source ?? "hotkey"
        let hasCapture = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        appState.selectAction(
            Self.initialActionID(
                openOnSearch: openOnSearch,
                needsSetup: needsSetup,
                host: host,
                hasCapture: hasCapture,
                isEditableField: isEditableField,
                capturedText: text,
                source: routingSource,
                windowTitle: windowTitle
            )
        )
        panelController.show(at: anchor, appState: appState, engine: engine)
        pushToTalk.arm()
        let landing = appState.selectedActionID
        if hasCapture && landing != EnhancementAction.searchID {
            engine.startIfNeeded(actionID: landing)
        }
    }

    /// Pasteboard snapshot for the context chip. Only kept when it differs from
    /// the selection so we never show a redundant Clipboard chip.
    func snapshotClipboard(relativeTo selection: String) {
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
}
