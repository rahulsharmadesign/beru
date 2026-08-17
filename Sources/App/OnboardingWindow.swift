import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    private var onOpenModels: () -> Void = {}
    private var openingModels = false
    private var restoredAccessory = false

    convenience init(onOpenModels: @escaping () -> Void = {}) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 540),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Get Started"
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

    var body: some View {
        let _ = AppearanceObserver.shared.signature
        VStack(spacing: 0) {
            stepDots
                .padding(.top, 24)
                .padding(.bottom, 16)
            Group {
                switch step {
                case .welcome: welcome
                case .accessibility: accessibility
                case .microphone: microphone
                case .models: models
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 32)
        }
        .frame(width: 460, height: 540)
        .background(BrandColors.canvas)
        .task {
            while !Task.isCancelled {
                isTrusted = Permissions.isAccessibilityTrusted()
                dictation.refreshAvailability()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private var stepDots: some View {
        HStack(spacing: 8) {
            ForEach(GetStartedStep.allCases, id: \.rawValue) { item in
                Capsule()
                    .fill(item == step ? BrandColors.accentColor : Color.secondary.opacity(0.25))
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
            Button("Continue") { step = .accessibility }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }

    private var accessibility: some View {
        stepLayout(
            title: "Allow Accessibility",
            body: "Beru reads and replaces selected text in other apps. Grant access in System Settings. This window stays open until you continue."
        ) {
            VStack(spacing: 12) {
                statusLine(isTrusted ? "Granted" : "Needed")
                Button("Open System Settings") {
                    Permissions.requestAccessibilityIfNeeded()
                    Permissions.openAccessibilitySettings()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Button("Continue") { step = .microphone }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(!isTrusted)
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
                    Button("Allow Microphone") {
                        Task { await dictation.requestPermissions() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else if !ready {
                    Button("Open System Settings") {
                        dictation.availability.openSystemSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                Button(ready ? "Continue" : "Skip") { step = .models }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
        }
    }

    private var models: some View {
        stepLayout(
            title: "Pick a model",
            body: "Use a local model with Ollama, or connect Anthropic / Groq in Settings. qwen3:8b is the recommended local default."
        ) {
            VStack(spacing: 12) {
                Button("Open Models") {
                    controller?.finish(openModels: true)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Button("Done") {
                    controller?.finish(openModels: false)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    private func stepLayout<Footer: View>(
        title: String,
        body: String,
        @ViewBuilder footer: () -> Footer
    ) -> some View {
        VStack(spacing: 20) {
            Image("BrandMark")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text(body)
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            footer()
            Spacer(minLength: 8)
        }
        .padding(.top, 8)
        .padding(.bottom, 28)
    }

    private func statusLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}
