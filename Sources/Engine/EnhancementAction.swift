import Foundation

enum ModelRole: String, Codable {
    case enhance
    case grammar
}

/// One of the panel's two jobs. Enhance turns a rough idea into a prompt for
/// another AI; Grammar fixes or restyles the author's own writing.
struct EnhancementAction: Identifiable, Equatable {
    let id: String
    let name: String
    let icon: String
    let role: ModelRole
    let systemPrompt: String

    static let grammarID = "grammar"
    static let enhanceID = "enhance"

    static let enhance = EnhancementAction(
        id: enhanceID,
        name: "Enhance Prompt",
        icon: "sparkles",
        role: .enhance,
        systemPrompt: Prompts.enhance
    )

    static let grammar = EnhancementAction(
        id: grammarID,
        name: "Grammar",
        icon: "circle-check",
        role: .grammar,
        systemPrompt: Prompts.grammar
    )

    /// Tab order.
    static let all: [EnhancementAction] = [enhance, grammar]

    static func action(withID id: String) -> EnhancementAction? {
        all.first { $0.id == id }
    }

    /// Hover text for the tab.
    var summary: String {
        switch id {
        case Self.grammarID:
            return "Fix spelling, grammar, and punctuation while keeping your meaning and tone"
        default:
            return "Rewrite your rough idea into a clear, effective prompt for an AI"
        }
    }

    /// Composer hint. With nothing selected, typed text is the source; with a
    /// selection, it is an optional refinement.
    static func composerPlaceholder(actionID: String, hasCapture: Bool, targetName: String? = nil) -> String {
        if !hasCapture {
            if actionID == grammarID { return "Type or paste text to fix…" }
            if let targetName, !targetName.isEmpty, targetName != "Generic" {
                return "Rough idea for \(targetName)…"
            }
            return "Rough idea to turn into a prompt…"
        }
        return actionID == grammarID
            ? "Optional: e.g. \u{201C}keep my tone\u{201D}"
            : "Optional: e.g. \u{201C}for beginners\u{201D}"
    }

    /// Whether the panel word-diffs the result against the selection. Only
    /// Grammar is a true edit of the source; an enhanced prompt shares too
    /// little wording with its rough idea for a diff to read well.
    static func showsInlineDiff(for actionID: String) -> Bool {
        actionID == grammarID
    }

    /// How the composer and the host selection combine for one run.
    ///
    /// With a selection, typed text is an extra instruction. With none, typed
    /// text is the source document itself and must not also be sent as an
    /// instruction.
    struct ResolvedInput: Equatable {
        var sourceText: String
        var extraInstruction: String
        var usedComposerAsSource: Bool
    }

    static func resolveInput(capturedText: String, composerText: String) -> ResolvedInput {
        let captured = capturedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let composer = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !captured.isEmpty {
            return ResolvedInput(sourceText: capturedText, extraInstruction: composer, usedComposerAsSource: false)
        }
        return ResolvedInput(sourceText: composer, extraInstruction: "", usedComposerAsSource: !composer.isEmpty)
    }
}
