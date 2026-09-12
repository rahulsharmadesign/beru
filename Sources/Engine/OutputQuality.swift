import Foundation

/// Post-stream checks that keep a chip's output honest. Prompts are a
/// probability; Replace pastes into a real document, so the tag contract,
/// language match, Grammar-vs-paraphrase, and "did the job" for transform
/// verbs are enforced here — the same detectors the tests already covered
/// but the engine never ran.
enum OutputQuality {
    /// Matches `PanelEngine.grammarParaphraseCeiling`. Corrections cluster
    /// near 0; the reported synonym-swap scored 1.0. 0.4 sits in the gap.
    static let grammarParaphraseCeiling = 0.4

    static let unchangedMessage = "The model returned the source unchanged — try Regenerate"
    static let languageMessage = "The replies didn't match the message's language — try Regenerate"

    static let parseHint = """
    Your previous output did not use the required tags. Output ONLY the tagged documents in the exact format specified in the system instructions, and nothing else.
    """

    static let replyLanguageHint = """
    Your previous replies did not match the incoming message's language and script. Rewrite all six replies in the SAME language and script as the message. Do not translate.
    """

    enum Outcome: Equatable {
        case publish
        case retry(previousResult: String?, hint: String?)
        case reject(message: String)
    }

    struct Decision: Equatable {
        var outcome: Outcome
        var text: String
        var replySuggestions: [ReplySuggestion] = []
        var grammarSuggestions: [GrammarSuggestion] = []
        var selectedReplyTone: ReplyTone?
        var selectedGrammarKind: GrammarKind?
    }

    static func evaluate(
        actionID: String,
        raw: String,
        source: String,
        selectedReplyTone: ReplyTone,
        preferredGrammarKind: GrammarKind?,
        canRetry: Bool
    ) -> Decision {
        if actionID == EnhancementAction.replyID {
            return evaluateReply(
                raw: raw,
                source: source,
                selectedTone: selectedReplyTone,
                canRetry: canRetry
            )
        }
        if actionID == EnhancementAction.grammarID {
            return evaluateGrammar(
                raw: raw,
                source: source,
                preferredKind: preferredGrammarKind,
                canRetry: canRetry
            )
        }
        if EnhancementAction.rejectsUnchangedOutput(actionID) {
            return evaluateUnchanged(raw: raw, source: source, canRetry: canRetry)
        }
        return Decision(outcome: .publish, text: raw)
    }

    // MARK: - Smart Reply

    private static func evaluateReply(
        raw: String,
        source: String,
        selectedTone: ReplyTone,
        canRetry: Bool
    ) -> Decision {
        let parsed = ReplySuggestions.parseWithStatus(raw)
        if parsed.usedFallback {
            if canRetry, !parsed.suggestions.isEmpty {
                return Decision(
                    outcome: .retry(previousResult: nil, hint: parseHint),
                    text: raw
                )
            }
            let tone = parsed.suggestions.first?.tone ?? selectedTone
            let body = parsed.suggestions.first?.body ?? raw
            return Decision(
                outcome: .publish,
                text: body,
                replySuggestions: parsed.suggestions,
                selectedReplyTone: tone
            )
        }

        let policy = ReplyLanguagePolicy.analyze(source)
        let kept = parsed.suggestions.filter { !policy.bodyViolatesPolicy($0.body) }
        if kept.isEmpty {
            if canRetry {
                return Decision(
                    outcome: .retry(previousResult: nil, hint: replyLanguageHint),
                    text: raw
                )
            }
            return Decision(
                outcome: .reject(message: languageMessage),
                text: raw
            )
        }

        let tone = kept.contains(where: { $0.tone == selectedTone })
            ? selectedTone
            : (kept.first?.tone ?? selectedTone)
        let body = ReplySuggestions.body(in: kept, matching: tone) ?? kept[0].body
        return Decision(
            outcome: .publish,
            text: body,
            replySuggestions: kept,
            selectedReplyTone: tone
        )
    }

    // MARK: - Grammar

    private static func evaluateGrammar(
        raw: String,
        source: String,
        preferredKind: GrammarKind?,
        canRetry: Bool
    ) -> Decision {
        let parsed = GrammarSuggestions.parseWithStatus(raw)
        if parsed.usedFallback {
            if canRetry, !parsed.suggestions.isEmpty {
                return Decision(
                    outcome: .retry(previousResult: nil, hint: parseHint),
                    text: raw
                )
            }
            let kind = parsed.suggestions.first?.kind ?? .corrected
            let body = parsed.suggestions.first?.body ?? raw
            return Decision(
                outcome: .publish,
                text: body,
                grammarSuggestions: parsed.suggestions,
                selectedGrammarKind: kind
            )
        }

        var suggestions = parsed.suggestions
        let preferred = preferredKind ?? .corrected
        var kind = suggestions.contains(where: { $0.kind == preferred })
            ? preferred
            : (suggestions.first?.kind ?? .corrected)

        let sourceTrimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sourceTrimmed.isEmpty,
           let corrected = suggestions.first(where: { $0.kind == .corrected })?.body {
            let score = WordDiff.paraphraseScore(WordDiff.diff(original: source, revised: corrected))
            if score > grammarParaphraseCeiling {
                if canRetry {
                    return Decision(
                        outcome: .retry(previousResult: corrected, hint: nil),
                        text: raw,
                        grammarSuggestions: suggestions,
                        selectedGrammarKind: .corrected
                    )
                }
                suggestions = revertedToSource(suggestions, source: source)
                kind = .corrected
            }
        }

        let body = GrammarSuggestions.body(in: suggestions, matching: kind)
            ?? suggestions.first?.body
            ?? raw
        return Decision(
            outcome: .publish,
            text: body,
            grammarSuggestions: suggestions,
            selectedGrammarKind: kind
        )
    }

    /// Corrected becomes the original. Clearer / Tighter stay only when they
    /// themselves are still a correction of the original, not a second rewrite.
    private static func revertedToSource(
        _ suggestions: [GrammarSuggestion],
        source: String
    ) -> [GrammarSuggestion] {
        suggestions.compactMap { item in
            if item.kind == .corrected {
                return GrammarSuggestion(kind: .corrected, body: source)
            }
            let score = WordDiff.paraphraseScore(WordDiff.diff(original: source, revised: item.body))
            guard score <= grammarParaphraseCeiling else { return nil }
            return item
        }
    }

    // MARK: - Summarize / Explain / Instruction

    private static func evaluateUnchanged(
        raw: String,
        source: String,
        canRetry: Bool
    ) -> Decision {
        let sourceTrimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceTrimmed.isEmpty, isUnchanged(source: source, output: raw) else {
            return Decision(outcome: .publish, text: raw)
        }
        if canRetry {
            return Decision(
                outcome: .retry(previousResult: raw, hint: nil),
                text: raw
            )
        }
        return Decision(outcome: .reject(message: unchangedMessage), text: raw)
    }

    static func isUnchanged(source: String, output: String) -> Bool {
        normalized(source) == normalized(output)
    }

    private static func normalized(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased()
    }
}
