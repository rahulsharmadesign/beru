import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    private var onOpenModels: () -> Void = {}
    private var openingModels = false
    private var restoredAccessory = false

    convenience init(onOpenModels: @escaping () -> Void = {}) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Get Started"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
        window.center()
        self.init(window: window)
        self.onOpenModels = onOpenModels
        window.delegate = self
        window.contentView = NSHostingView(rootView: GetStartedView(controller: self))
    }

    func show() {
        restoredAccessory = false
        openingModels = false
        NSApp.setActivationPolicy(.regular)
        window?.appearance = NSApp.effectiveAppearance
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func finish(openModels: Bool) {
        SettingsStore.shared.hasCompletedGetStarted = true
        openingModels = openModels
        window?.close()
        if openModels {
            onOpenModels()
        }
    }

    func windowWillClose(_ notification: Notification) {
        if Permissions.isAccessibilityTrusted() {
            SettingsStore.shared.hasCompletedGetStarted = true
        }
        if !openingModels {
            restoreAccessoryIfNeeded()
        }
    }

    private func restoreAccessoryIfNeeded() {
        guard !restoredAccessory else { return }
        restoredAccessory = true
        let dashboardOpen = NSApp.windows.contains {
            $0.isVisible && $0.title == "Beru" && $0 !== window
        }
        if !dashboardOpen {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

private enum GetStartedStep: Int, CaseIterable {
    case welcome
    case accessibility
    case microphone
    case models
}

struct GetStartedView: View {
    weak var controller: OnboardingWindowController?

    @State private var step: GetStartedStep = .welcome
    @State private var isTrusted = Permissions.isAccessibilityTrusted()
    @State private var dictation = DictationService.shared
    private var a11y = AccessibilityPreferences.shared

    init(controller: OnboardingWindowController?) {
        self.controller = controller
    }

    var body: some View {
        let _ = AppearanceObserver.shared.signature

        VStack(spacing: 0) {
            Group {
                switch step {
                case .welcome: welcome
                case .accessibility: accessibility
                case .microphone: microphone
                case .models: models
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 36)
            .id(step)
            .transition(stepTransition)

            stepDots
                .padding(.bottom, 28)
        }
        .frame(width: 420, height: 520)
        .background(BrandColors.canvas)
        .animation(motion, value: step)
        .animation(motion, value: isTrusted)
        .task {
            while !Task.isCancelled {
                isTrusted = Permissions.isAccessibilityTrusted()
                dictation.refreshAvailability()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private var motion: Animation? {
        a11y.reduceMotion ? nil : .easeInOut(duration: 0.22)
    }

    private var stepTransition: AnyTransition {
        a11y.reduceMotion ? .opacity : .opacity
    }

    private var stepDots: some View {
        HStack(spacing: 8) {
            ForEach(GetStartedStep.allCases, id: \.rawValue) { item in
                Capsule()
                    .fill(item == step ? BrandColors.accentColor : Color.secondary.opacity(0.28))
                    .frame(width: item == step ? 18 : 6, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step.rawValue + 1) of \(GetStartedStep.allCases.count)")
    }

    private var welcome: some View {
        stepLayout(
            title: "Get started with Beru",
            body: "Beru lives in the menu bar. Select text in any app, press the shortcut, and it refines the writing in place — grammar, prompts, replies, and questions."
        ) {
            OnboardContinueButton("Continue") { step = .accessibility }
        }
    }

    private var accessibility: some View {
        stepLayout(
            title: "Allow Accessibility",
            body: "Beru reads and replaces selected text in other apps. Grant access in System Settings. This window stays open until you continue."
        ) {
            VStack(spacing: 12) {
                statusLine(isTrusted ? "Granted" : "Needed")
                OnboardContinueButton("Open System Settings") {
                    Permissions.requestAccessibilityIfNeeded()
                    Permissions.openAccessibilitySettings()
                }
                OnboardContinueButton("Continue", prominent: false, enabled: isTrusted) {
                    step = .microphone
                }
            }
        }
    }

    private var microphone: some View {
        let ready = dictation.availability.isReady
        return stepLayout(
            title: "Microphone (optional)",
            body: "Speak an instruction instead of typing. Transcription stays on this Mac — Beru will not send your voice to Apple."
        ) {
            VStack(spacing: 12) {
                statusLine(ready ? "Ready" : (dictation.availability.message ?? "Not set up yet"))
                if dictation.availability == .needsPermission {
                    OnboardContinueButton("Allow Microphone") {
                        Task { await dictation.requestPermissions() }
                    }
                } else if !ready {
                    OnboardContinueButton("Open System Settings") {
                        dictation.availability.openSystemSettings()
                    }
                }
                OnboardContinueButton(ready ? "Continue" : "Skip", prominent: !ready ? false : true) {
                    step = .models
                }
            }
        }
    }

    private var models: some View {
        stepLayout(
            title: "Pick a model",
            body: "Use a local model with Ollama, or connect Anthropic / Groq in Settings. qwen3:8b is the recommended local default."
        ) {
            VStack(spacing: 12) {
                OnboardContinueButton("Open Models") {
                    controller?.finish(openModels: true)
                }
                OnboardContinueButton("Done", prominent: false) {
                    controller?.finish(openModels: false)
                }
            }
        }
    }

    private func stepLayout<Footer: View>(
        title: String,
        body: String,
        @ViewBuilder footer: () -> Footer
    ) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            VStack(spacing: 20) {
                Image("BrandMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(SettingsTheme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(body)
                    .font(.system(size: 13))
                    .foregroundStyle(SettingsTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 320)
                footer()
                    .padding(.top, 4)
            }
            Spacer(minLength: 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func statusLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(SettingsTheme.textSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Compact capsule CTA. Prominent uses system blue so it matches the native
/// Continue control; the brand accent is reserved for the pager.
private struct OnboardContinueButton: View {
    let title: String
    var prominent: Bool = true
    var enabled: Bool = true
    let action: () -> Void

    init(
        _ title: String,
        prominent: Bool = true,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.prominent = prominent
        self.enabled = enabled
        self.action = action
    }

    var body: some View {
        if prominent {
            Button(title, action: action)
                .buttonStyle(.borderedProminent)
                .tint(Color(nsColor: .controlAccentColor))
                .controlSize(.large)
                .disabled(!enabled)
        } else {
            Button(title, action: action)
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!enabled)
        }
    }
}
