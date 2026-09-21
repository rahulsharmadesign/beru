import AppKit
import SwiftUI

enum PanelCloseChromePolicy {
    static let discSize: CGFloat = 12
    static let hitSize: CGFloat = 28
    /// Gap between the close and zoom discs. 10 sits off the 4pt grid on
    /// purpose: it is the titlebar's optical spacing, not layout rhythm.
    static let discGap: CGFloat = 10
}

/// Glyph drawn on a traffic disc when hovered or pressed. macOS shows the
/// mark only on hover; a zoomed disc carries the minus (restore) instead of
/// the plus.
enum PanelTrafficGlyph {
    case cross
    case plus
    case minus
}

/// AppKit close so window-drag does not swallow the click.
struct PanelCloseDot: View {
    let action: () -> Void

    var body: some View {
        PanelTrafficDiscRepresentable(kind: .cross, isZoomed: false, onPress: action)
            .frame(width: PanelCloseChromePolicy.hitSize, height: PanelCloseChromePolicy.hitSize)
            .help("Close")
            .accessibilityLabel("Close")
            .accessibilityAddTraits(.isButton)
    }
}

/// Green zoom disc. Same AppKit hit target as the close dot: window-drag
/// must not swallow the click. No yellow — a borderless NSPanel cannot
/// Dock-minimize.
struct PanelZoomDot: View {
    var isZoomed: Bool
    let action: () -> Void

    var body: some View {
        PanelTrafficDiscRepresentable(kind: .plus, isZoomed: isZoomed, onPress: action)
            .frame(width: PanelCloseChromePolicy.hitSize, height: PanelCloseChromePolicy.hitSize)
            .help(isZoomed ? "Restore" : "Zoom")
            .accessibilityLabel(isZoomed ? "Restore zoom" : "Zoom")
            .accessibilityAddTraits(.isButton)
    }
}

private struct PanelTrafficDiscRepresentable: NSViewRepresentable {
    let kind: PanelTrafficGlyph
    let isZoomed: Bool
    let onPress: () -> Void

    func makeNSView(context: Context) -> PanelTrafficDisc {
        let button = PanelTrafficDisc()
        button.onPress = onPress
        return button
    }

    func updateNSView(_ nsView: PanelTrafficDisc, context: Context) {
        nsView.onPress = onPress
        nsView.glyph = isZoomed ? .minus : kind
        nsView.isZoomed = isZoomed
    }
}

/// Solid traffic-light disc. The glyph appears on hover, matching macOS.
final class PanelTrafficDisc: NSControl {
    var onPress: () -> Void = {}
    var glyph: PanelTrafficGlyph = .cross
    var isZoomed = false {
        didSet { setAccessibilityLabel(isZoomed ? "Restore zoom" : glyph == .cross ? "Close" : "Zoom") }
    }
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
                if inside { onPress() }
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
        let isClose = glyph == .cross
        let fill = isClose
            ? (pressing ? BeruColor.CloseDisc.pressedFill : BeruColor.CloseDisc.fill)
            : (pressing ? BeruColor.ZoomDisc.pressedFill : BeruColor.ZoomDisc.fill)
        fill.setFill()
        NSBezierPath(ovalIn: oval).fill()

        guard hovering || pressing else { return }
        let pad = oval.width * 0.28
        let mark = NSBezierPath()
        mark.lineWidth = 1.05
        mark.lineCapStyle = .round
        switch glyph {
        case .cross:
            mark.move(to: NSPoint(x: oval.minX + pad, y: oval.minY + pad))
            mark.line(to: NSPoint(x: oval.maxX - pad, y: oval.maxY - pad))
            mark.move(to: NSPoint(x: oval.maxX - pad, y: oval.minY + pad))
            mark.line(to: NSPoint(x: oval.minX + pad, y: oval.maxY - pad))
        case .plus:
            let center = NSPoint(x: oval.midX, y: oval.midY)
            mark.move(to: NSPoint(x: center.x, y: oval.minY + pad))
            mark.line(to: NSPoint(x: center.x, y: oval.maxY - pad))
            mark.move(to: NSPoint(x: oval.minX + pad, y: center.y))
            mark.line(to: NSPoint(x: oval.maxX - pad, y: center.y))
        case .minus:
            let center = NSPoint(x: oval.midX, y: oval.midY)
            mark.move(to: NSPoint(x: oval.minX + pad, y: center.y))
            mark.line(to: NSPoint(x: oval.maxX - pad, y: center.y))
        }
        (isClose ? BeruColor.CloseDisc.glyph : BeruColor.ZoomDisc.glyph).setStroke()
        mark.stroke()
    }
}
