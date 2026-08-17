import AppKit
import ApplicationServices
import os.log

private let logger = Logger(subsystem: "com.rahul.beru", category: "capture")

enum CaptureResult {
    case text(String)
    case empty
}

enum TextCapture {
    /// Reads the current text selection: first via the Accessibility API, then
    /// falling back to a simulated Cmd-C for apps that don't expose AX selection
    /// (Electron apps, some web views).
    static func captureSelection() async -> CaptureResult {
        if let axText = focusedSelectedText(), !axText.isEmpty {
            logger.notice("captured via AX, length = \(axText.count)")
            return .text(axText)
        }
        logger.notice("AX capture empty/unavailable, trying clipboard fallback")

        if let clipboardText = await captureViaClipboard(), !clipboardText.isEmpty {
            logger.notice("captured via clipboard fallback, length = \(clipboardText.count)")
            return .text(clipboardText)
        }

        logger.notice("clipboard fallback also empty")
        return .empty
    }

    static func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        let result = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused)
        guard result == .success, let element = focused, CFGetTypeID(element) == AXUIElementGetTypeID() else {
            logger.notice("no focused AXUIElement, AXError = \(result.rawValue)")
            return nil
        }
        // Runtime type already confirmed via CFGetTypeID above.
        return (element as! AXUIElement)
    }

    private static func focusedSelectedText() -> String? {
        guard let element = focusedElement() else { return nil }

        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value)
        guard result == .success, let text = value as? String else {
            logger.notice("kAXSelectedTextAttribute unavailable, AXError = \(result.rawValue)")
            return nil
        }
        return text
    }

    private static func captureViaClipboard() async -> String? {
        // Wait for the user to release the hotkey's modifiers first, or the
        // simulated Cmd-C reaches the app as Ctrl-Option-Cmd-C and does nothing.
        await KeySimulator.waitForModifierRelease()

        let guardBox = ClipboardGuard()
        guardBox.save()
        defer { guardBox.restore() }

        let previousChangeCount = ClipboardGuard.currentChangeCount
        KeySimulator.simulateCommandC()

        // 300 ms: Electron apps and busy web views regularly need >150 ms to
        // service a copy command.
        let changed = await ClipboardGuard.waitForChange(from: previousChangeCount, timeoutMS: 300)
        logger.notice("clipboard changed after simulated Cmd-C = \(changed)")
        guard changed else { return nil }

        return NSPasteboard.general.string(forType: .string)
    }
}
