import Foundation

// Invoke routing: which chip an invoke lands on. Pure host/selection/table
// rules with no UI and no side effects, split out of AppCoordinator so that
// file stays under the 400-line limit.

extension AppCoordinator {
    /// Chip to select when the invoke hotkey fires. First match wins.
    ///
    /// - Dictation/menu invoke or an unconfigured install → AI Search.
    /// - No selection anywhere → AI Search (the ask-without-input surface).
    /// - Selection inside an editable field → Grammar, whatever the app is:
    ///   what you are composing is what gets rewritten, including drafts in
    ///   Mail or WhatsApp.
    /// - Selection inside Cursor / Claude / ChatGPT / Kimi → Enhance Prompt,
    ///   checked before the editable-field test because Electron exposes a
    ///   thin AX tree and the role read is unreliable exactly there.
    /// - A received message in a chat/mail app → Smart Reply.
    /// - A selection on an Instagram / YouTube / X feed (the apps themselves,
    ///   or a browser tab whose window title names them) → Smart Reply: a
    ///   comment there is reply material. No URL is ever read — only the
    ///   window title the system already shows, per the no-scraping rule.
    /// - Any other selection (webpage, PDF, docs) → Summarize.
    static func initialActionID(
        openOnSearch: Bool,
        needsSetup: Bool,
        host: HostApp.Info?,
        hasCapture: Bool = false,
        isEditableField: Bool = false,
        capturedText: String = "",
        source: String? = nil,
        windowTitle: String? = nil,
        focused: Bool = false
    ) -> String {
        if focused {
            return focusedActionID(
                host: host,
                hasCapture: hasCapture,
                isEditableField: isEditableField,
                source: source
            )
        }
        if openOnSearch || needsSetup || !hasCapture {
            return EnhancementAction.searchID
        }
        // Clipboard and vault sources hand Beru text directly; they are not
        // answers-to-something, so they stay on AI Search.
        guard source == nil || source == "hotkey" else {
            return EnhancementAction.searchID
        }
        if let bundleID = host?.bundleID.lowercased() {
            // Seeded LLM tool routes to Enhance Prompt on any selection,
            // without the editable-field check: Electron's AX tree is thin
            // unless an assistive client is already attached, so the role
            // read is unreliable exactly where it matters most.
            if TargetProfile.seededID(forBundleID: bundleID, name: host?.name) != nil {
                return EnhancementAction.enhanceID
            }
            // Your own draft is correction material wherever you wrote it —
            // this must win over the chat-app rule below, or selecting a
            // half-written reply inside Mail routes it as someone else's
            // message.
            if isEditableField {
                return EnhancementAction.grammarID
            }
            if isCommunicationApp(bundleID) {
                return EnhancementAction.replyID
            }
        }
        // Plain selections elsewhere are prompt material: Enhance runs by
        // default; summarization stays one chip away.
        return Self.isSocialFeedSelection(bundleID: host?.bundleID, windowTitle: windowTitle)
            ? EnhancementAction.replyID
            : EnhancementAction.enhanceID
    }

    /// Focused mode (`PanelMode`): only Enhance and Grammar exist. First match
    /// wins.
    ///
    /// - No selection, clipboard, vault, or dictation → Enhance: whatever is
    ///   typed or spoken becomes the rough idea to turn into a prompt.
    /// - Selection inside Cursor / Claude / ChatGPT / Kimi → Enhance.
    /// - Selection in an editable field, or anywhere in a chat/mail app →
    ///   Grammar: that is your own writing. Chat apps are matched by bundle
    ///   because Electron clients (Slack, Discord) expose a thin AX tree.
    /// - Anything else (a webpage, notes, a PDF) → Enhance.
    static func focusedActionID(
        host: HostApp.Info?,
        hasCapture: Bool,
        isEditableField: Bool,
        source: String?
    ) -> String {
        guard hasCapture, source == nil || source == "hotkey",
              let bundleID = host?.bundleID.lowercased() else {
            return EnhancementAction.enhanceID
        }
        if TargetProfile.seededID(forBundleID: bundleID, name: host?.name) != nil {
            return EnhancementAction.enhanceID
        }
        if isEditableField || isCommunicationApp(bundleID) {
            return EnhancementAction.grammarID
        }
        return EnhancementAction.enhanceID
    }

    private static let communicationBundlePrefixes: [String] = [
        "com.apple.mail", "com.apple.mobilesms", "com.tinyspeck",
        "com.microsoft.teams", "net.whatsapp", "ru.keepcoder.telegram",
        "org.telegram", "com.hnc.discord", "com.facebook", "com.linkedin",
        "com.reddit", "com.beeper"
    ]

    /// Chat, mail, and social apps where a selection is usually someone
    /// talking to you.
    static func isCommunicationApp(_ bundleID: String) -> Bool {
        communicationBundlePrefixes.contains { bundleID.hasPrefix($0) }
    }

    private static let socialFeedBundleIDs: [String] = [
        "com.burbn.instagram", "com.google.youtube", "com.google.ios.youtube",
        "com.atebits.tweetie2"
    ]

    private static let socialFeedTitleMarkers: [String] = [
        "youtube", "instagram", "twitter", "/ x", "x.com"
    ]

    /// True when the selection likely sits on an Instagram, YouTube, or X
    /// feed — either inside those apps, or in a browser whose focused window
    /// title names them. The title is a heuristic, not page data; a false
    /// positive costs one chip click to reach Summarize.
    static func isSocialFeedSelection(bundleID: String?, windowTitle: String?) -> Bool {
        if let bundleID = bundleID?.lowercased(),
           socialFeedBundleIDs.contains(where: bundleID.hasPrefix) {
            return true
        }
        guard let title = windowTitle?.lowercased() else { return false }
        return socialFeedTitleMarkers.contains { title.contains($0) }
    }
}
