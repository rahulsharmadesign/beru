import AppKit
import KeyboardShortcuts
import SwiftUI

@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    private var onOpenPanel: () -> Void = {}
    private var restoredAccessory = false
    private var shortcutMonitor: Any?

    convenience init(onOpenPanel: @escaping () -> Void = {}) {
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
        window.backgroundColor = BrandColors.canvasNSColor
        window.center()
        self.init(window: window)
        self.onOpenPanel = onOpenPanel
        window.delegate = self
        window.contentView = NSHostingView(rootView: GetStartedView(controller: self))
    }

    var isPresented: Bool { window?.isVisible == true }

    func show() {
        restoredAccessory = false
        window?.contentView = NSHostingView(rootView: GetStartedView(controller: self))
        window?.backgroundColor = BrandColors.canvasNSColor
        NSApp.setActivationPolicy(.regular)
        window?.appearance = NSApp.effectiveAppearance
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        installShortcutMonitor()
    }

    func finish() {
        removeShortcutMonitor()
        SettingsStore.shared.hasCompletedGetStarted = true
        window?.close()
    }

    func finishAndOpenPanel() {
        finish()
        onOpenPanel()
    }

    func windowWillClose(_ notification: Notification) {
        removeShortcutMonitor()
        if Permissions.isAccessibilityTrusted() {
            SettingsStore.shared.hasCompletedGetStarted = true
        }
        restoreAccessoryIfNeeded()
    }

    /// Get Started is key, so the global hotkey can miss. Swallow the live
    /// invoke shortcut here and treat it like tapping Start Beru.
    private func installShortcutMonitor() {
        guard shortcutMonitor == nil else { return }
        shortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.matchesInvokeShortcut(event) else { return event }
            self.finishAndOpenPanel()
            return nil
        }
    }

    private func removeShortcutMonitor() {
        if let shortcutMonitor {
            NSEvent.removeMonitor(shortcutMonitor)
            self.shortcutMonitor = nil
        }
    }

    private func matchesInvokeShortcut(_ event: NSEvent) -> Bool {
        guard let pressed = KeyboardShortcuts.Shortcut(event: event) else { return false }
        let expected = KeyboardShortcuts.getShortcut(for: .invokeBeru)
            ?? KeyboardShortcuts.Shortcut(.p, modifiers: [.control, .option, .command])
        return pressed == expected
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
    case startBeru
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
                case .startBeru: startBeru
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
            body: "Beru lives in your menu bar. Select text in any app, press the shortcut, and improve it instantly. Fix grammar, refine prompts, write replies, or ask questions."
        ) {
            OnboardContinueButton("Continue") { step = .accessibility }
        }
    }

    private var accessibility: some View {
        stepLayout(
            title: "Allow Accessibility",
            body: "Beru needs Accessibility access to read and replace selected text in other apps. You can enable it from System Settings."
        ) {
            VStack(spacing: 12) {
                if !isTrusted {
                    OnboardContinueButton("Open System Settings", prominent: false) {
                        Permissions.requestAccessibilityIfNeeded()
                        Permissions.openAccessibilitySettings()
                    }
                }
                OnboardContinueButton("Continue") { step = .microphone }
            }
        }
    }

    private var microphone: some View {
        stepLayout(
            title: "Microphone (optional)",
            body: "Use your voice instead of typing. Your speech is transcribed right on your Mac and never sent to Apple."
        ) {
            VStack(spacing: 12) {
                if dictation.availability == .needsPermission {
                    OnboardContinueButton("Allow Microphone", prominent: false) {
                        Task { await dictation.requestPermissions() }
                    }
                }
                OnboardContinueButton("Continue") { step = .startBeru }
            }
        }
    }

    private var startBeru: some View {
        stepLayout(
            title: "Start Beru",
            body: "Press the shortcut to open Beru anytime, right from the app you're working in."
        ) {
            OnboardContinueButton("Press \(shortcutLabel)") {
                controller?.finishAndOpenPanel()
            }
        }
    }

    private var shortcutLabel: String {
        KeyboardShortcuts.getShortcut(for: .invokeBeru)?.description ?? "⌃⌥⌘P"
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
