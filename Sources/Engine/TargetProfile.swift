import Foundation

/// The AI environment an enhanced prompt is destined for. Each profile carries
/// a prompt fragment describing that environment's conventions, appended to the
/// Enhance system prompt so the produced prompt suits where it will be pasted.
struct TargetProfile: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var name: String
    var icon: String
    var promptFragment: String
    var isBuiltIn: Bool

    static let genericID = "target-generic"

    /// Ordered as shown in the picker. Generic is first and deliberately
    /// carries an empty fragment, so leaving the picker alone reproduces the
    /// unmodified Enhance prompt exactly.
    static let builtInDefaults: [TargetProfile] = [
        TargetProfile(
            id: genericID,
            name: "Generic",
            icon: "circle-dashed",
            promptFragment: "",
            isBuiltIn: true
        ),
        TargetProfile(
            id: "target-cursor",
            name: "Cursor",
            icon: "code",
            promptFragment: Prompts.targetCursor,
            isBuiltIn: true
        ),
        TargetProfile(
            id: "target-chatgpt",
            name: "ChatGPT",
            icon: "messages-square",
            promptFragment: Prompts.targetChatGPT,
            isBuiltIn: true
        ),
        TargetProfile(
            id: "target-claude",
            name: "Claude",
            icon: "sparkle",
            promptFragment: Prompts.targetClaude,
            isBuiltIn: true
        ),
        TargetProfile(
            id: "target-kimi",
            name: "Kimi",
            icon: "globe",
            promptFragment: Prompts.targetKimi,
            isBuiltIn: true
        )
    ]

    /// Bundle identifiers that imply a target, used only to pre-select a
    /// sensible option the first time the tool is used in a given app.
    static let bundleSeeds: [String: String] = [
        "com.todesktop.230313mzl4w4u92": "target-cursor",
        "com.anysphere.cursor": "target-cursor",
        "com.microsoft.VSCode": "target-cursor",
        "com.openai.chat": "target-chatgpt",
        "com.anthropic.claudefordesktop": "target-claude",
        "com.anthropic.claude": "target-claude"
    ]

    /// Fallback for apps not in the seed map (helpers, forks, betas).
    static func seededID(forBundleID bundleID: String, name: String? = nil) -> String? {
        if let exact = bundleSeeds[bundleID] { return exact }
        let haystack = "\(bundleID) \(name ?? "")".lowercased()
        if haystack.contains("cursor") { return "target-cursor" }
        if haystack.contains("openai") || haystack.contains("chatgpt") { return "target-chatgpt" }
        if haystack.contains("anthropic") || haystack.contains("claude") { return "target-claude" }
        if haystack.contains("kimi") || haystack.contains("moonshot") { return "target-kimi" }
        return nil
    }
}
