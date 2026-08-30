import Foundation

enum ModelRole: String, Codable {
    case enhance
    case grammar
}

/// One panel action: a named, icon-tagged system prompt. Grammar and Enhance
/// are built in; users can save any number of custom verb/tone actions
/// ("Smart Reply", "For my VP", ...) which behave identically.
struct EnhancementAction: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var icon: String
    var role: ModelRole
    var systemPrompt: String
    var isBuiltIn: Bool

    /// One-line plain-language description shown on hover in the panel and in
    /// the Actions list, so a terse chip label never has to be learned by
    /// running the action.
    var summary: String {
        switch id {
        case Self.grammarID:
            return "Fix spelling, grammar, and punctuation while keeping your meaning and tone"
        case Self.enhanceID:
            return "Rewrite your rough idea into a clear, effective prompt for an AI"
        case Self.replyID:
            return "Six reply options in your voice"
        case Self.summarizeID:
            return "Compress the selected text into its key facts"
        case Self.explainID:
            return "Explain the selected text in plain language"
        case Self.describeID:
            return "Run a one-off instruction on the selected text"
        case Self.searchID:
            return "Ask a question. No selected text required."
        default:
            return "Run a saved custom prompt on the selected text"
        }
    }

    /// Title and body for the panel when this action has nothing to work on.
    ///
    /// Verb skills cannot run on an empty capture. The sentence must not tell
    /// people to type in the composer — that field is a no-op until they
    /// highlight text or switch to Search.
    static func emptyCaptureCopy(actionID: String) -> (title: String, subtitle: String) {
        if actionID == searchID {
            return (
                "Ask a question",
                "Type below and press Return."
            )
        }
        if actionID == describeID {
            return (
                "Give an instruction",
                "Type what you want Beru to do, then press Return."
            )
        }
        return (
            "No text selected",
            "Highlight text in another app and press the shortcut, or switch to AI Search to ask."
        )
    }

    /// Composer field hint. Search and Instruction can run with no selection;
    /// every other chip cannot, so the empty-capture line must not say “ask”.
    static func composerPlaceholder(actionID: String, hasCapture: Bool, isQuickSearch: Bool) -> String {
        if isQuickSearch || actionID == searchID {
            return "Ask anything — no selection needed"
        }
        if actionID == describeID {
            return "Type what you want Beru to do"
        }
        if !hasCapture {
            return "Highlight text first"
        }
        switch actionID {
        case grammarID:
            return "Optional: e.g. \u{201C}keep my tone\u{201D}"
        case enhanceID:
            return "Optional: e.g. \u{201C}for beginners\u{201D}"
        case replyID:
            return "Optional: e.g. \u{201C}mention Friday\u{201D}"
        case summarizeID, explainID:
            return "Optional: e.g. \u{201C}in 5 bullets\u{201D}"
        default:
            return "Optional instruction for this action…"
        }
    }

    /// Chip label for an id. Search and Instruction are not in the registry.
    static func resolvedName(actionID: String, registryName: String?) -> String {
        if let registryName, !registryName.isEmpty { return registryName }
        switch actionID {
        case searchID: return search.name
        case describeID: return describe.name
        case grammarID: return grammar.name
        case enhanceID: return enhance.name
        default: return "This action"
        }
    }

    /// Caption under the verb chips: which skill is live, and which app it
    /// came from — so a Cursor landing on Enhance is not read as Grammar.
    static func contextSummary(actionName: String, hostAppName: String?, characterCount: Int) -> String {
        let trimmedHost = hostAppName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let host = trimmedHost.isEmpty ? "Mac" : trimmedHost
        if characterCount == 0 {
            return "\(actionName) · \(host)"
        }
        return "\(actionName) · \(host) · \(characterCount) characters"
    }

    static let grammarID = "grammar"
    static let enhanceID = "enhance"
    /// Reserved id for one-off intent-bar instructions.
    static let describeID = "describe"
    /// First panel tab. Not a rewrite skill — it answers a question.
    static let searchID = "ai-search"

    static let replyID = "verb-reply"
    static let summarizeID = "verb-summarize"
    static let explainID = "verb-explain"

    /// Shipped verb chips whose prompts live in `Prompts` and must stay live —
    /// UserDefaults can hold a stale copy from an older seed.
    static func isShippedVerb(_ id: String) -> Bool {
        id == replyID || id == summarizeID || id == explainID
    }

    /// Whether the panel should word-diff the result against the selection.
    ///
    /// Reply / Summarize / Explain produce a *new* document. Diffing that against
    /// the source reuses shared nouns as `.equal` and interleaves the rest —
    /// `Manage- yourManage` garble that looks like a failed run even when the
    /// summary is fine. Grammar and Enhance stay on the diff path (with the
    /// retention floor in `PanelEngine.computeDiff`).
    static func showsInlineDiff(for actionID: String) -> Bool {
        !isShippedVerb(actionID) && actionID != describeID && actionID != searchID
    }

    /// Search and one-off instructions can run from the composer alone.
    static func allowsEmptyCapture(_ actionID: String) -> Bool {
        actionID == searchID || actionID == describeID
    }

    /// Current system prompt for a shipped verb, or nil for any other id.
    static func liveSystemPrompt(for id: String) -> String? {
        switch id {
        case replyID: return Prompts.reply
        case summarizeID: return Prompts.summarize
        case explainID: return Prompts.explain
        default: return nil
        }
    }

    /// Prompt actually sent to the model: live shipped text wins over a stale
    /// persisted copy on Reply / Summarize / Explain.
    static func resolvedSystemPrompt(for action: EnhancementAction) -> String {
        liveSystemPrompt(for: action.id) ?? action.systemPrompt
    }

    /// Built-in copy-edit skill (id stays `grammar` for history / defaults).
    static let grammar = EnhancementAction(
        id: grammarID,
        name: "Grammar",
        icon: "circle-check",
        role: .grammar,
        systemPrompt: Prompts.grammar,
        isBuiltIn: true
    )

    /// Built-in prompt-authoring skill (id stays `enhance` for history / defaults).
    static let enhance = EnhancementAction(
        id: enhanceID,
        name: "Enhance Prompt",
        icon: "sparkles",
        role: .enhance,
        systemPrompt: Prompts.enhance,
        isBuiltIn: true
    )

    /// Always the first chip. Not in `ActionRegistry` so Settings → Actions,
    /// Cmd-2…9, and the default-action picker stay on rewrite skills.
    static let search = EnhancementAction(
        id: searchID,
        name: "AI Search",
        icon: "search",
        role: .enhance,
        systemPrompt: "",
        isBuiltIn: true
    )

    /// Shown as a chip only while a one-off instruction is active. Deliberately
    /// NOT part of ActionRegistry.allActions: adding it would shift the Cmd-1..9
    /// mapping and change branch order in PanelEngine.start, which resolves the
    /// describe prompt before any registry lookup.
    static let describe = EnhancementAction(
        id: describeID,
        name: "Instruction",
        icon: "sparkles",
        role: .enhance,
        systemPrompt: "",
        isBuiltIn: true
    )

    /// Verb skills seeded for new installs (and once for existing installs that
    /// have not received them yet). Edit or delete like any custom action.
    static let starterVerbActions: [EnhancementAction] = [
        EnhancementAction(
            id: replyID,
            name: "Smart Reply",
            icon: "corner-up-left",
            role: .enhance,
            systemPrompt: Prompts.reply,
            isBuiltIn: false
        ),
        EnhancementAction(
            id: summarizeID,
            name: "Summarize",
            icon: "list",
            role: .enhance,
            systemPrompt: Prompts.summarize,
            isBuiltIn: false
        ),
        EnhancementAction(
            id: explainID,
            name: "Explain",
            icon: "lightbulb",
            role: .enhance,
            systemPrompt: Prompts.explain,
            isBuiltIn: false
        )
    ]
}
