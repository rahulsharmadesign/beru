import AppKit
import ApplicationServices

/// Identifies the application a capture came from. Used to label the panel
/// and to pre-select a prompt target. Never infers a target from a browser URL.
enum HostApp {
    struct Info: Equatable {
        let bundleID: String
        let name: String?

        var isHelper: Bool {
            let id = bundleID.lowercased()
            let label = (name ?? "").lowercased()
            return id.contains("helper")
                || id.contains("electron")
                || label.contains("helper")
        }
    }

    /// Prefers the process owning the accessibility element actually being
    /// edited. Electron apps (Cursor, Claude, ChatGPT) focus a Helper process
    /// whose bundle id is `com.github.Electron.helper` — map that back to the
    /// real app so the panel can show Cursor / Claude in the target picker.
    static func identify(from element: AXUIElement?) -> Info? {
        let focused = element.flatMap { info(forElement: $0) }
        let frontmost = info(for: NSWorkspace.shared.frontmostApplication)
        let running = NSWorkspace.shared.runningApplications.compactMap { info(for: $0) }
        return pick(focused: focused, frontmost: frontmost, running: running)
    }

    /// Pure so helper → owner mapping can be tested without Accessibility.
    static func pick(focused: Info?, frontmost: Info?, running: [Info]) -> Info? {
        if let focused, !focused.isHelper { return focused }
        if let focused, focused.isHelper {
            if let owner = running.first(where: { $0.isOwner(ofHelperNamed: focused.name) }) {
                return owner
            }
            if let frontmost { return frontmost }
            return focused
        }
        return frontmost
    }

    /// Title of the system-wide focused window, when readable. Used only to
    /// recognize an Instagram / YouTube / X tab for invoke routing — never a
    /// URL and never page content. Returns nil for anything unreadable.
    static func focusedWindowTitle() -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        var window: AnyObject?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedWindowAttribute as CFString,
            &window
        ) == .success, let window else { return nil }
        var titleValue: AnyObject?
        guard AXUIElementCopyAttributeValue(
            window as! AXUIElement,
            kAXTitleAttribute as CFString,
            &titleValue
        ) == .success,
              let title = titleValue as? String,
              !title.isEmpty
        else { return nil }
        return title
    }

    /// "Cursor Helper (Renderer)" → "Cursor"
    static func helperStem(_ name: String) -> String {
        name.replacingOccurrences(of: #"\s*Helper.*$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func info(forElement element: AXUIElement) -> Info? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return nil }
        return info(for: NSRunningApplication(processIdentifier: pid))
    }

    private static func info(for app: NSRunningApplication?) -> Info? {
        guard let app, let bundleID = app.bundleIdentifier,
              bundleID != Bundle.main.bundleIdentifier else {
            return nil
        }
        return Info(bundleID: bundleID, name: app.localizedName)
    }
}

extension HostApp.Info {
    func isOwner(ofHelperNamed helperName: String?) -> Bool {
        guard let helperName, let name, !isHelper else { return false }
        let stem = HostApp.helperStem(helperName)
        guard !stem.isEmpty else { return false }
        return name.caseInsensitiveCompare(stem) == .orderedSame
            || helperName.localizedCaseInsensitiveContains(name)
    }
}
