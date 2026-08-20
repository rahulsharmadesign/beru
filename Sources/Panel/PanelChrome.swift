import AppKit
import SwiftUI

// Small panel-local chrome: the update pill, an icon hit target, the chip
// frame preference, and the AppKit drag region.

/// Solid Update pill, left of the close disc. Hidden unless a newer release exists.
struct PanelUpdateButton: View {
    @Bindable var updates = AppUpdateService.shared

    var body: some View {
        if updates.showsUpdateButton {
            ZStack {
                DictationPressView {
                    guard !updates.isBusy else { return }
                    updates.install()
                }
                Text(updates.buttonTitle)
                    .font(BeruType.captionSemibold)
                    .foregroundStyle(BeruColor.onAccent)
                    .padding(.horizontal, BeruSpace.xs)
                    .padding(.vertical, BeruSpace.xxs)
                    .background(Capsule().fill(BeruColor.accent))
                    .allowsHitTesting(false)
            }
            .fixedSize()
            .help(updates.availableVersion.map { "Install Beru \($0)" } ?? "Install the latest Beru")
            .accessibilityLabel("Update")
            .accessibilityAddTraits(.isButton)
        }
    }
}

/// AppKit click target so the panel's window-drag hit test leaves footer icons
/// alone — the same reason the mic is an `NSView` instead of a SwiftUI `Button`.
struct PanelIconHitButton: View {
    let icon: String
    let help: String
    var hint: String = ""
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        ZStack {
            DictationPressView(onToggle: { if enabled { action() } })
            BeruIcon(name: icon, size: 16)
                .foregroundStyle(BeruColor.textPrimary)
                .opacity(enabled ? 1 : 0.35)
                .allowsHitTesting(false)
        }
        .frame(width: BeruMetrics.hitTarget, height: BeruMetrics.hitTarget)
        .contentShape(Rectangle())
        .help(help)
        .accessibilityLabel(help)
        .accessibilityHint(hint)
        .accessibilityAddTraits(.isButton)
    }
}

struct ChipFramesKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

/// Empty chrome that reports itself as the window-move target. Sits behind
/// chips and text so those keep their clicks.
struct PanelDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = WindowMoveView()
        view.autoresizingMask = [.width, .height]
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

final class WindowMoveView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDown(with event: NSEvent) {
        beruBeginWindowDrag(with: event)
    }
}
