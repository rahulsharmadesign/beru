import AppKit
import ApplicationServices
import os.log

private let logger = Logger(subsystem: "com.rahul.beru", category: "capture")

enum TextReplace {
    /// Replaces the selection with `text`: first via the Accessibility API on
    /// `target` (the element captured at invoke time — the panel holds key
    /// status at replace time so re-querying focus would find the wrong
    /// element), falling back to a simulated Cmd-V. The user's clipboard is
    /// preserved either way.
    static func replaceSelection(with text: String, target: AXUIElement?) async {
        if let target, !isElectronHelper(target), replaceViaAccessibility(with: text, element: target) {
            logger.notice("replaced via AX on captured target")
            return
        }
        if let current = TextCapture.focusedElement(),
           !isElectronHelper(current),
           replaceViaAccessibility(with: text, element: current) {
            logger.notice("replaced via AX on focused element")
            return
        }
        logger.notice("AX replace skipped or unverified; falling back to clipboard")
        await replaceViaClipboard(with: text, target: target)
    }

    /// Electron (Cursor, Claude, ChatGPT) reports `kAXSelectedText` as settable
    /// and SetAttribute as success without changing the document. Trusting that
    /// skips the Cmd-V fallback, so Replace dismisses and the text stays put.
    static func isElectronHelper(_ element: AXUIElement) -> Bool {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success,
              let app = NSRunningApplication(processIdentifier: pid),
              let bundleID = app.bundleIdentifier else { return false }
        return HostApp.Info(bundleID: bundleID, name: app.localizedName).isHelper
    }

    /// Whether an AX write actually changed the selection. `SetAttribute`
    /// returning success is not enough — some hosts no-op.
    static func didMutateSelection(before: String?, after: String?, replacement: String) -> Bool {
        if before == replacement { return true }
        if after == replacement { return true }
        if let before, after == before { return false }
        return after != before
    }

    private static func replaceViaAccessibility(with text: String, element: AXUIElement) -> Bool {
        var settable: DarwinBoolean = false
        let settableResult = AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &settable)
        guard settableResult == .success, settable.boolValue else { return false }

        let before = selectedText(of: element)
        let result = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
        guard result == .success else { return false }
        let after = selectedText(of: element)
        let mutated = didMutateSelection(before: before, after: after, replacement: text)
        if !mutated {
            logger.notice("AX SetAttribute succeeded but selection did not change")
        }
        return mutated
    }

    private static func selectedText(of element: AXUIElement) -> String? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? String
    }

    private static func replaceViaClipboard(with text: String, target: AXUIElement?) async {
        activateHost(owning: target)
        await KeySimulator.waitForModifierRelease()

        let guardBox = ClipboardGuard()
        guardBox.save()

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        KeySimulator.simulateCommandV()

        // Electron and busy web views often need longer than a key-repeat to
        // service the paste. Restoring too soon yanks the replacement off the
        // pasteboard before the host reads it.
        try? await Task.sleep(for: .milliseconds(400))
        guardBox.restore()
    }

    private static func activateHost(owning element: AXUIElement?) {
        guard let element else { return }
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success,
              let app = NSRunningApplication(processIdentifier: pid),
              app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        app.activate()
    }
}
