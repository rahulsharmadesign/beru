import AppKit
import ApplicationServices

enum SelectionLocator {
    /// Gap between the selection's bottom edge and the panel's top edge.
    private static let selectionGap: CGFloat = 8

    /// Returns the on-screen anchor point (Cocoa coordinates, origin bottom-left)
    /// where the panel should appear: the bottom-left of the selection bounds if
    /// the Accessibility API can report them, otherwise a stable screen-center
    /// position.
    ///
    /// Prefer passing the pre-capture `element` — once the panel is key, the
    /// focused AX element is Beru itself and selection bounds disappear, which
    /// used to fall back to the mouse and drift the panel downward each run.
    ///
    /// When there is no selection and no element (clipboard, vault, dictation),
    /// we use a stable screen-center position instead of mouse location. Mouse
    /// location varies between invocations and causes the panel to "wander"
    /// across the screen — confusing when the user invokes from the menu bar
    /// with no text selected anywhere.
    static func anchorPoint(for element: AXUIElement? = nil) -> CGPoint {
        if let bounds = selectionBottomLeft(for: element) {
            return bounds
        }
        if element != nil, let bounds = selectionBottomLeft(for: nil) {
            // Pinned element failed; try whatever is focused as a second chance.
            return bounds
        }
        // No selection anywhere — use a stable position in the upper-center of
        // the main screen. This keeps the panel in a predictable spot when
        // invoked from the menu bar (Enhance Clipboard, Dictate, Vault) where
        // there is no text selection to anchor to.
        return stableMenuBarAnchor()
    }

    /// A stable anchor point for menu-bar invocations: horizontally centered
    /// on the main screen, vertically positioned in the upper third. This
    /// prevents the panel from "wandering" when there's no selection to
    /// anchor to.
    private static func stableMenuBarAnchor() -> CGPoint {
        guard let screen = NSScreen.main else {
            // Fallback: mouse location if no screen available (shouldn't happen)
            return NSEvent.mouseLocation
        }
        let visible = screen.visibleFrame
        let x = visible.midX - PanelMetrics.width / 2
        // Position in the upper third of the screen — below menu bar but not
        // at the very top where it might overlap with menu bar extras.
        let y = visible.maxY - visible.height / 3
        return CGPoint(x: x, y: y)
    }

    /// Bottom-left of the selection in Cocoa coordinates, if available.
    private static func selectionBottomLeft(for element: AXUIElement?) -> CGPoint? {
        let target = element ?? TextCapture.focusedElement()
        guard let target else { return nil }

        var rangeValue: AnyObject?
        let rangeResult = AXUIElementCopyAttributeValue(
            target,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeValue
        )
        guard rangeResult == .success, let rangeValue,
              CFGetTypeID(rangeValue) == AXValueGetTypeID() else {
            return nil
        }

        var boundsValue: AnyObject?
        let boundsResult = AXUIElementCopyParameterizedAttributeValue(
            target,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue,
            &boundsValue
        )
        guard boundsResult == .success, let boundsValue,
              CFGetTypeID(boundsValue) == AXValueGetTypeID() else {
            return nil
        }

        let axRectValue = boundsValue as! AXValue
        var rect = CGRect.zero
        guard AXValueGetValue(axRectValue, .cgRect, &rect) else { return nil }
        guard rect.width.isFinite, rect.height.isFinite,
              rect.width >= 0, rect.height >= 0 else { return nil }

        return cocoaBottomLeft(fromAX: rect)
    }

    /// AX global coords: origin at the top-left of the primary display, Y down.
    /// Cocoa: origin at the bottom-left of the primary display, Y up.
    private static func cocoaBottomLeft(fromAX rect: CGRect) -> CGPoint {
        guard let primary = NSScreen.screens.first else {
            return CGPoint(x: rect.minX, y: rect.minY)
        }
        // Bottom edge of the AX rect → cocoa Y.
        let cocoaY = primary.frame.maxY - rect.maxY
        return CGPoint(x: rect.minX, y: cocoaY)
    }

    static var panelGapBelowSelection: CGFloat { selectionGap }
}
