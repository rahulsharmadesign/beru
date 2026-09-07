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
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: BeruMetrics.onboardingWidth,
                height: BeruMetrics.onboardingHeight
            ),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Get Started"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.isOpaque = true
        window.backgroundColor = BeruColor.canvasNSColor
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
        window?.backgroundColor = BeruColor.canvasNSColor
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
    case startBeru
}

struct GetStartedView: View {
    weak var controller: OnboardingWindowController?

    @State private var step: GetStartedStep = .welcome
    @State private var isTrusted = Permissions.isAccessibilityTrusted()
    /// Was a plain stored property, which reads the current value but never
    /// subscribes, so a preference changed mid-onboarding went unnoticed.
    @Bindable private var a11y = AccessibilityPreferences.shared
    @Bindable private var appearance = AppearanceObserver.shared

    init(controller: OnboardingWindowController?) {
        self.controller = controller
    }

    var body: some View {
        // Observation only invalidates on values read while body runs, and
        // nothing in this tree reads the system appearance. This read is the
        // subscription that repaints AppKit-backed surfaces on a light/dark switch.
        let _ = appearance.signature

        VStack(spacing: 0) {
            Group {
                switch step {
                case .welcome: welcome
                case .accessibility: accessibility
                case .startBeru: startBeru
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, BeruSpace.xl)
            .id(step)
            .transition(stepTransition)

            stepDots
                .padding(.bottom, BeruSpace.lg)
        }
        .frame(width: BeruMetrics.onboardingWidth, height: BeruMetrics.onboardingHeight)
        .background(BeruColor.canvas)
        .animation(motion, value: step)
        .animation(motion, value: isTrusted)
        .task {
            while !Task.isCancelled {
                isTrusted = Permissions.isAccessibilityTrusted()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private var motion: Animation? {
        a11y.reduceMotion ? nil : .easeInOut(duration: BeruMotion.stepCrossfade)
    }

    private var stepTransition: AnyTransition {
        .opacity
    }

    private var stepDots: some View {
        HStack(spacing: BeruSpace.xs) {
            ForEach(GetStartedStep.allCases, id: \.rawValue) { item in
                Capsule()
                    .fill(item == step ? BeruColor.accent : BeruColor.textSecondary.opacity(0.28))
                    .frame(
                        width: item == step
                            ? BeruMetrics.onboardingDotWidth
                            : BeruMetrics.onboardingDotHeight,
                        height: BeruMetrics.onboardingDotHeight
                    )
                    .animation(motion, value: item == step)
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
            VStack(spacing: BeruSpace.lg) {
                HStack(spacing: BeruSpace.xs) {
                    BeruChip(icon: "wand-sparkles", title: "Fix grammar")
                    BeruChip(icon: "sparkles", title: "Refine prompts")
                    BeruChip(icon: "messages-square", title: "Write replies")
                }
                OnboardContinueButton("Continue") { step = .accessibility }
            }
        }
    }

    private var accessibility: some View {
        stepLayout(
            title: "Allow Accessibility",
            body: "Beru needs Accessibility access to read and replace selected text in other apps. You can enable it from System Settings."
        ) {
            VStack(spacing: BeruSpace.sm) {
                if isTrusted {
                    SettingsStatusBadge(title: "Accessibility is on", isPositive: true)
                    OnboardContinueButton("Continue") { step = .startBeru }
                } else {
                    OnboardContinueButton("Open System Settings") {
                        Permissions.requestAccessibilityIfNeeded()
                        Permissions.openAccessibilitySettings()
                    }
                    BeruButton(title: "Continue", variant: .pill, size: .regular) {
                        step = .startBeru
                    }
                    Text("You can continue now and grant access later.")
                        .font(BeruType.footnote)
                        .foregroundStyle(BeruColor.textTertiary)
                }
            }
        }
    }

    private var startBeru: some View {
        stepLayout(
            title: "Start Beru",
            body: "Press the shortcut to open Beru anytime, right from the app you're working in."
        ) {
            VStack(spacing: BeruSpace.sm) {
                BeruKbd(text: shortcutLabel)
                OnboardContinueButton("Start Beru") {
                    controller?.finishAndOpenPanel()
                }
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
            Spacer(minLength: BeruSpace.sm)
            VStack(spacing: BeruSpace.lg) {
                Image("BrandMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: BeruMetrics.brandOnboarding, height: BeruMetrics.brandOnboarding)
                    .clipShape(BeruRadius.shape(BeruRadius.lg))
                    .accessibilityHidden(true)
                Text(title)
                    .font(BeruType.heroTitle)
                    .foregroundStyle(BeruColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text(body)
                    .font(BeruType.body)
                    .foregroundStyle(BeruColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: BeruMetrics.onboardingBodyWidth)
                footer()
                    .padding(.top, BeruSpace.xxs)
            }
            Spacer(minLength: BeruSpace.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The onboarding CTA. Used to be a system `.borderedProminent` in system blue,
/// which made this the only surface in Beru not painted in the brand accent.
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
        BeruButton(
            title: title,
            variant: prominent ? .primary : .pill,
            size: .large,
            enabled: enabled,
            action: action
        )
    }
}
