import AppKit

/// Saves the user's clipboard around a simulated Cmd-C / Cmd-V operation and
/// restores it afterward, so Beru never leaves the pasteboard modified.
final class ClipboardGuard {
    private var savedItems: [NSPasteboardItem] = []
    private var savedChangeCount: Int = 0

    func save() {
        let pasteboard = NSPasteboard.general
        savedChangeCount = pasteboard.changeCount
        savedItems = pasteboard.pasteboardItems?.map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        } ?? []
    }

    func restore() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if !savedItems.isEmpty {
            pasteboard.writeObjects(savedItems)
        }
        savedItems = []
    }

    /// Waits (briefly) for the pasteboard change count to advance, indicating
    /// a simulated Cmd-C has landed the new selection.
    static func waitForChange(from previousChangeCount: Int, timeoutMS: Int = 150) async -> Bool {
        let pasteboard = NSPasteboard.general
        let start = ContinuousClock.now
        let timeout = Duration.milliseconds(timeoutMS)
        while ContinuousClock.now - start < timeout {
            if pasteboard.changeCount != previousChangeCount {
                return true
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return pasteboard.changeCount != previousChangeCount
    }

    static var currentChangeCount: Int {
        NSPasteboard.general.changeCount
    }
}
