import AppKit
import SwiftUI

// Haze dropdown popup. NSMenu cannot carry the Haze look — its panel and
// highlight are system chrome — so dropdown pills present this borderless
// panel instead: panelSolid surface, hairline, hover fill, accent check.

final class DropdownPopup: NSPanel {
    @MainActor private static var current: DropdownPopup?
    private var monitors: [Any] = []
    private let anchorView: NSView

    @MainActor
    static func toggle(anchor: NSView, items: [DropdownItem]) {
        if let current, current.anchorView === anchor {
            close()
            return
        }
        close()
        let popup = DropdownPopup(anchor: anchor, items: items)
        current = popup
        popup.orderFront(nil)
    }

    @MainActor
    static func close() {
        guard let panel = current else { return }
        current = nil
        // Fade out quickly; remove monitors after the panel is gone.
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
            panel.alphaValue = 1
            DispatchQueue.main.async {
                panel.monitors.forEach { NSEvent.removeMonitor($0) }
            }
        })
    }


    private init(anchor: NSView, items: [DropdownItem]) {
        self.anchorView = anchor
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        hasShadow = true
        isMovableByWindowBackground = false

        let content = DropdownPopupContent(items: items) { [weak self] index in
            guard self != nil else { return }
            DropdownPopup.close()
            items[index].action()
        }
        let hosting = NSHostingView(rootView: content)
        hosting.layoutSubtreeIfNeeded()
        let natural = hosting.fittingSize
        let size = NSSize(width: max(natural.width, anchor.bounds.width), height: natural.height)
        contentView = hosting

        if let window = anchor.window {
            let anchorScreen = window.convertToScreen(anchor.convert(anchor.bounds, to: nil))
            var origin = NSPoint(
                x: anchorScreen.minX,
                y: anchorScreen.minY - size.height - BeruSpace.xxs
            )
            if let screen = window.screen ?? NSScreen.main {
                let visible = screen.visibleFrame
                origin.x = min(
                    max(origin.x, visible.minX + BeruSpace.sm),
                    visible.maxX - size.width - BeruSpace.sm
                )
                if origin.y < visible.minY {
                    origin.y = anchorScreen.maxY + BeruSpace.xxs
                }
            }
            setFrame(NSRect(origin: origin, size: size), display: true)
        }

        // Click anywhere else closes. The local monitor covers our own
        // windows, the global one other apps, Escape always closes.
        let local = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if self != nil, event.window !== self {
                DropdownPopup.close()
            }
            return event
        }
        let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            DropdownPopup.close()
        }
        let keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self != nil, event.keyCode == 53 { // Escape
                DropdownPopup.close()
                return nil
            }
            return event
        }
        monitors = [local, global, keys].compactMap { $0 }
    }
}

/// The Haze option list inside the popup panel.
private struct DropdownPopupContent: View {
    let items: [DropdownItem]
    let pick: (Int) -> Void

    @State private var hovered: Int?
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: BeruSpace.hair) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if item.isSeparator {
                    Rectangle()
                        .fill(BeruColor.border)
                        .frame(height: BeruMetrics.hairline)
                        .padding(.vertical, BeruSpace.xxs)
                } else {
                    Button {
                        pick(index)
                    } label: {
                        HStack(spacing: BeruSpace.sm) {
                            BeruIcon(name: "check", size: BeruMetrics.iconSizeDense)
                                .foregroundStyle(BeruColor.accent)
                                .opacity(item.isOn ? 1 : 0)
                            Text(item.title)
                                .font(BeruType.control)
                                .foregroundStyle(item.isEnabled ? BeruColor.textPrimary : BeruColor.textTertiary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, BeruSpace.sm)
                        .frame(minHeight: BeruMetrics.pillHeightSm, alignment: .leading)
                        .background {
                            BeruRadius.shape(BeruRadius.sm)
                                .fill(hovered == index ? AnyShapeStyle(BeruColor.hoverFill) : AnyShapeStyle(Color.clear))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!item.isEnabled)
                    .onHover { hovered = $0 ? index : nil }
                }
            }
        }
        .padding(BeruSpace.xs)
        .frame(maxWidth: BeruMetrics.menuDropdownWidth, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
        .background {
            BeruRadius.shape(BeruRadius.sm2)
                .fill(BeruColor.panelSolid)
                .overlay {
                    BeruRadius.shape(BeruRadius.sm2)
                        .strokeBorder(BeruColor.border, lineWidth: BeruMetrics.hairline)
                }
        }
        // Launches out of its pill: quick fade with a small scale-up from
        // the top edge, mirroring the panel's entrance recipe.
        .scaleEffect(shown ? 1 : 0.94, anchor: .top)
        .opacity(shown ? 1 : 0)
        .onAppear {
            if reduceMotion {
                shown = true
            } else {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                    shown = true
                }
            }
        }
    }
}
