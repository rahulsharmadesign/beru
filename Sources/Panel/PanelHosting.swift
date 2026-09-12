import AppKit
import SwiftUI

/// Hosts SwiftUI. Window height comes only from layout band preferences.
final class PanelHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }
    override var mouseDownCanMoveWindow: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        clearHostFill()
    }

    override func layout() {
        super.layout()
        clearHostFill()
        if let container = superview {
            frame = container.bounds
        }
        clipsToBounds = true
    }

    private func clearHostFill() {
        wantsLayer = true
        layer?.isOpaque = false
        layer?.backgroundColor = .clear
    }
}

extension NSView {
    func beruBeginWindowDrag(with event: NSEvent) {
        guard let window else { return }
        let grab = event.locationInWindow
        while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if next.type == .leftMouseUp { break }
            let mouse = NSEvent.mouseLocation
            window.setFrameOrigin(NSPoint(x: mouse.x - grab.x, y: mouse.y - grab.y))
        }
    }
}
