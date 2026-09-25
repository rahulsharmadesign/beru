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
                EnhancifyGlassButton(
                    title: updates.buttonTitle,
                    prominent: true,
                    size: .compact
                ) {}
                .allowsHitTesting(false)
            }
            .fixedSize()
            .help(updates.availableVersion.map { "Install Enhancify \($0)" } ?? "Install the latest Enhancify")
            .accessibilityLabel("Update")
            .accessibilityAddTraits(.isButton)
        }
    }
}

/// Settings gear. AppKit hit target so window-drag does not swallow the click.
/// Quiet glyph — a glass circle here reads as a purple FAB on the slab.
struct PanelSettingsLink: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        ZStack {
            DictationPressView(onToggle: action)
            EnhancifyIcon(name: "settings", size: EnhancifyMetrics.iconSize)
                .foregroundStyle(EnhancifyColor.textPrimary)
                .frame(width: EnhancifyMetrics.hitTarget, height: EnhancifyMetrics.hitTarget)
                .background {
                    EnhancifyRadius.shape(EnhancifyRadius.sm)
                        .fill(isHovered ? EnhancifyColor.hoverFill : Color.clear)
                }
                .allowsHitTesting(false)
        }
        .frame(width: EnhancifyMetrics.hitTarget, height: EnhancifyMetrics.hitTarget)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .enhancifyHoverEase(isHovered)
        .help("Settings")
        .accessibilityLabel("Settings")
        .accessibilityAddTraits(.isButton)
    }
}

/// AppKit click target around a capsule so window-drag does not swallow
/// Replace / Copy / Pin — the same reason the mic is an `NSView`.
struct PanelHitCapsule<Label: View>: View {
    var help: String
    var accessibilityLabel: String? = nil
    /// Solid helper pill above the control instead of the native tooltip.
    var showsHelpPill: Bool = false
    /// Which way that pill grows. Controls on the panel's leading edge pass
    /// `.leading`; a centered pill hangs past the window and gets sheared.
    var helpAnchor: EnhancifyHelpAnchor = .center
    var action: () -> Void
    @ViewBuilder var label: () -> Label

    @State private var isHovered = false

    var body: some View {
        ZStack {
            DictationPressView(onToggle: action)
            label()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .fixedSize()
        .onHover { isHovered = $0 }
        .enhancifyHoverEase(isHovered)
        .environment(\.enhancifyParentHovered, isHovered)
        .enhancifyHoverHelp(help, isVisible: showsHelpPill && isHovered, anchor: helpAnchor)
        .enhancifyNativeHelp(help, enabled: !showsHelpPill)
        .accessibilityLabel(accessibilityLabel ?? help)
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
        enhancifyBeginWindowDrag(with: event)
    }
}
