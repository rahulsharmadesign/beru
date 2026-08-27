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

/// Settings gear. AppKit hit target so window-drag does not swallow the click.
/// SF Symbol `gearshape` at 16pt — the system settings glyph.
struct PanelSettingsLink: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        ZStack {
            DictationPressView(onToggle: action)
            Image(systemName: "gearshape")
                .resizable()
                .scaledToFit()
                .frame(width: BeruSpace.md, height: BeruSpace.md)
                .foregroundStyle(isHovered ? BeruColor.textPrimary : BeruColor.textSecondary)
                .allowsHitTesting(false)
        }
        .frame(width: BeruMetrics.hitTarget, height: BeruMetrics.hitTarget)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .help("Settings")
        .accessibilityLabel("Settings")
        .accessibilityAddTraits(.isButton)
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
    override var isOpaque: Bool { false }
    override var mouseDownCanMoveWindow: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.isOpaque = false
        layer?.backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func mouseDown(with event: NSEvent) {
        beruBeginWindowDrag(with: event)
    }
}
