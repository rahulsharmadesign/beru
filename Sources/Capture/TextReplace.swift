import AppKit
import ApplicationServices

enum TextReplace {
    /// Replaces the selection with `text`: first via the Accessibility API on
    /// `target` (the element captured at invoke time — the panel holds key
    /// status at replace time so re-querying focus would find the wrong
    /// element), falling back to a simulated Cmd-V. The user's clipboard is
    /// preserved either way.
    static func replaceSelection(with text: String, target: AXUIElement?) async {
        if let target, replaceViaAccessibility(with: text, element: target) {
            return
        }
        if let current = TextCapture.focusedElement(), replaceViaAccessibility(with: text, element: current) {
            return
        }
        await replaceViaClipboard(with: text)
    }

    private static func replaceViaAccessibility(with text: String, element: AXUIElement) -> Bool {
        var settable: DarwinBoolean = false
        let settableResult = AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &settable)
        guard settableResult == .success, settable.boolValue else { return false }

        let result = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
        return result == .success
    }

    private static func replaceViaClipboard(with text: String) async {
        let guardBox = ClipboardGuard()
        guardBox.save()

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        KeySimulator.simulateCommandV()

        try? await Task.sleep(for: .milliseconds(300))
        guardBox.restore()
    }
}
