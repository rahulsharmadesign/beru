import AppKit
import SwiftUI

enum PanelCloseChromePolicy {
    static let discSize: CGFloat = 12
    static let hitSize: CGFloat = 28
}

/// AppKit close so window-drag does not swallow the click.
struct PanelCloseDot: View {
    let action: () -> Void

    var body: some View {
        PanelCloseDotRepresentable(onClose: action)
            .frame(width: PanelCloseChromePolicy.hitSize, height: PanelCloseChromePolicy.hitSize)
            .help("Close")
            .accessibilityLabel("Close")
            .accessibilityAddTraits(.isButton)
    }
}

private struct PanelCloseDotRepresentable: NSViewRepresentable {
    let onClose: () -> Void

    func makeNSView(context: Context) -> PanelStripCloseButton {
        let button = PanelStripCloseButton()
        button.onClose = onClose
        return button
    }

    func updateNSView(_ nsView: PanelStripCloseButton, context: Context) {
        nsView.onClose = onClose
    }
}

/// Solid red traffic-light disc. The dark × appears on hover, matching macOS.
final class PanelStripCloseButton: NSControl {
    var onClose: () -> Void = {}
    private var hovering = false
    private var pressing = false
    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Close")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: NSSize {
        NSSize(width: PanelCloseChromePolicy.hitSize, height: PanelCloseChromePolicy.hitSize)
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        trackingArea = area
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        hovering = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hovering = false
        pressing = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        pressing = true
        needsDisplay = true
        while let next = window?.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]) {
            let inside = bounds.contains(convert(next.locationInWindow, from: nil))
            if next.type == .leftMouseUp {
                pressing = false
                needsDisplay = true
                if inside { onClose() }
                return
            }
            if pressing != inside {
                pressing = inside
                needsDisplay = true
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let size = PanelCloseChromePolicy.discSize
        let oval = NSRect(
            x: ((bounds.width - size) / 2) + 0.5,
            y: ((bounds.height - size) / 2) + 0.5,
            width: size - 1,
            height: size - 1
        )
        let fill = pressing ? BeruColor.CloseDisc.pressedFill : BeruColor.CloseDisc.fill
        fill.setFill()
        NSBezierPath(ovalIn: oval).fill()

        guard hovering || pressing else { return }
        let pad = oval.width * 0.28
        let glyph = NSBezierPath()
        glyph.lineWidth = 1.05
        glyph.lineCapStyle = .round
        glyph.move(to: NSPoint(x: oval.minX + pad, y: oval.minY + pad))
        glyph.line(to: NSPoint(x: oval.maxX - pad, y: oval.maxY - pad))
        glyph.move(to: NSPoint(x: oval.maxX - pad, y: oval.minY + pad))
        glyph.line(to: NSPoint(x: oval.minX + pad, y: oval.maxY - pad))
        BeruColor.CloseDisc.glyph.setStroke()
        glyph.stroke()
    }
}
