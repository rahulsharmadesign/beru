import AppKit
import KeyboardShortcuts
import SwiftUI

// Voice entry points, dictation, and the onboarding and dashboard windows.

extension AppCoordinator {
    func invokeVoiceAsk() {
        if DictationService.shared.isRecording {
            DictationService.shared.stop()
            return
        }

        if !SettingsStore.shared.hasCompletedGetStarted {
            showOnboarding()
            return
        }
        if !Permissions.isAccessibilityTrusted() {
            Permissions.requestAccessibilityIfNeeded()
            presentEmptySelectionNotice()
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
    func presentEmptySelectionNotice() {
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

    func truncatedIfNeeded(_ text: String) -> (String, Bool) {
        guard text.count > PanelEngine.maxCapturedLength else { return (text, false) }
        let truncated = String(text.prefix(PanelEngine.maxCapturedLength))
        return (truncated, true)
    }

    /// Routes a transcript to whichever field the dictation was started for.
    func applyDictated(_ text: String) {
        switch dictationDestination {
        case .instruction:
            appState.describeInstruction = text
        case .sourceText:
            appState.capturedText = text
        }
    }

    /// Start listening into the Ask field.
    func beginVoiceAsk() {
        dictationDestination = .instruction
        guard !DictationService.shared.start() else { return }
        if let reason = DictationService.shared.availability.message {
            appState.setResult(.error(reason), for: appState.selectedActionID)
        }
    }

    /// Toggle listening from the panel mic.
    func beginPushToTalk() {
        beginVoiceAsk()
    }

    func dismiss() {
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
    func migrateDictateShortcutIfNeeded() {
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

    func showOnboarding() {
        if onboardingWindow == nil {
            onboardingWindow = OnboardingWindowController { [weak self] in
                self?.openPanelAfterGetStarted()
            }
        }
        onboardingWindow?.show()
    }

    /// Closes Get Started and shows the panel. Used by the Start Beru button
    /// and by the live shortcut while that window is key.
    func openPanelAfterGetStarted() {
        guard !openingPanelAfterGetStarted else { return }
        openingPanelAfterGetStarted = true
        onboardingWindow?.finish()
        presentPanel(
            with: "",
            recordEmptySelection: true,
            openOnSearch: true
        )
        DispatchQueue.main.async { [weak self] in
            self?.openingPanelAfterGetStarted = false
        }
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
