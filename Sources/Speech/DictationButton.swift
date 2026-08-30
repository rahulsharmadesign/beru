import AppKit
import KeyboardShortcuts
import SwiftUI

/// Toggle microphone control.
///
/// An `NSView` owns the click. A SwiftUI `Button` on this panel is stolen by
/// the window-drag hit test, so the mic never started recording.
struct DictationButton: View {
    @Bindable private var dictation = DictationService.shared

    /// Fallback when permission is denied or dictation cannot start: open
    /// Settings → Permissions so the user can fix it.
    var onNeedsPermission: () -> Void = {}

    var body: some View {
        ZStack {
            DictationPressView(onToggle: toggle)
            Circle()
                .strokeBorder(BeruColor.border, lineWidth: 1)
            BeruIcon(name: symbol, size: 14, strokeWidth: 2)
                .foregroundStyle(tint)
                .allowsHitTesting(false)
        }
        .frame(width: 28, height: 28)
        .contentShape(Circle())
        .help(helpText)
        .accessibilityLabel(dictation.isRecording ? "Stop dictation" : "Dictate an instruction")
        .accessibilityHint(helpText)
    }

    private func toggle() {
        switch DictationService.intentForMicPress(
            isRecording: dictation.isRecording,
            availability: dictation.availability
        ) {
        case .stop:
            dictation.stop()
        case .requestPermissionThenStart:
            Task { await promptThenStart() }
        case .start:
            if !dictation.start() {
                onNeedsPermission()
            }
        case .openSettings:
            onNeedsPermission()
        }
    }

    /// Activate, show the system prompt, then listen if both grants land.
    private func promptThenStart() async {
        await dictation.requestPermissions()
        if dictation.availability.isReady {
            _ = dictation.start()
            return
        }
        if DictationService.intentForMicPress(
            isRecording: false,
            availability: dictation.availability
        ) == .openSettings {
            onNeedsPermission()
        }
    }

    private var isActionable: Bool {
        dictation.availability.isReady || dictation.availability == .needsPermission
    }

    private var symbol: String {
        if dictation.isRecording { return "audio-lines" }
        return isActionable ? "audio-lines" : "mic-off"
    }

    private var tint: AnyShapeStyle {
        if dictation.isRecording { return AnyShapeStyle(.red) }
        return isActionable ? AnyShapeStyle(BeruColor.accent) : AnyShapeStyle(.tertiary)
    }

    private var helpText: String {
        if dictation.isRecording { return "Listening — click, press the shortcut, or Escape to stop" }
        if let reason = dictation.availability.message { return reason }
        guard let shortcut = KeyboardShortcuts.getShortcut(for: .dictateToBeru) else {
            return "Click the mic, or set a dictate shortcut in Settings › General"
        }
        let key = "\(shortcut)"
        return shortcut.modifiers.isEmpty
            ? "Click the mic, or press \(key) while the instruction is empty"
            : "Click the mic, or press \(key). Press again to stop."
    }
}

/// AppKit click target so the panel's window-drag hit test leaves the mic alone.
struct DictationPressView: NSViewRepresentable {
    var onToggle: () -> Void

    func makeNSView(context: Context) -> DictationPressNSView {
        let view = DictationPressNSView()
        view.onToggle = onToggle
        return view
    }

    func updateNSView(_ nsView: DictationPressNSView, context: Context) {
        nsView.onToggle = onToggle
    }
}

final class DictationPressNSView: NSView {
    var onToggle: () -> Void = {}

    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        onToggle()
    }
}
