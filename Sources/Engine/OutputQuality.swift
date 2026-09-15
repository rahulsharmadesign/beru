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
        // Small models sometimes return list items as bare paragraphs with
        // every marker dropped. Markers are known strings from the source, so
        // they graft back exactly; anything that does not align 1:1 is left
        // alone. Runs before paraphrase scoring so the score sees the text
        // that will actually publish.
        let repaired = parsed.suggestions.map {
            GrammarSuggestion(
                kind: $0.kind,
                body: restoringListMarkers(source: source, body: $0.body)
            )
        }
        if parsed.usedFallback {
            if canRetry, !repaired.isEmpty {
                return Decision(
                    outcome: .retry(previousResult: nil, hint: parseHint),
                    text: raw
                )
            }
            let kind = repaired.first?.kind ?? .corrected
            let body = repaired.first?.body ?? raw
            return Decision(
                outcome: .publish,
                text: body,
                grammarSuggestions: repaired,
                selectedGrammarKind: kind
            )
        }

        var suggestions = repaired
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

    // MARK: - Grammar list structure

    /// Leading marker of one list item line (`1.` `2)` `-` `*` `•` `[ ]`
    /// `[x]`), or nil when the line is not a list item. A marker needs
    /// trailing whitespace and real text after it, so `20x20 px`, `10% of`,
    /// and `[UIKit]` never read as markers.
    static func listMarkerPrefix(of line: String) -> String? {
        var rest = line[line.startIndex...]
        while rest.first?.isWhitespace == true { rest = rest.dropFirst() }
        if rest.hasPrefix("[ ] ") || rest.hasPrefix("[x] ") || rest.hasPrefix("[X] ") {
            return String(rest.prefix(3))
        }
        if let first = rest.first, "-*•‣".contains(first) {
            let after = rest.dropFirst()
            guard after.first?.isWhitespace == true,
                  after.dropFirst().contains(where: { !$0.isWhitespace })
            else { return nil }
            return String(first)
        }
        let digits = rest.prefix(while: \.isNumber)
        guard !digits.isEmpty else { return nil }
        var tail = rest.dropFirst(digits.count)
        guard tail.first == "." || tail.first == ")" else { return nil }
        let punct = tail.first!
        tail = tail.dropFirst()
        guard tail.first?.isWhitespace == true,
              tail.dropFirst().contains(where: { !$0.isWhitespace })
        else { return nil }
        return String(digits) + String(punct)
    }

    /// Puts back list markers the model dropped. Only when every non-empty
    /// source line carries a marker, the body holds the same number of
    /// markerless paragraphs, and none of them kept a marker: then each
    /// paragraph is the corrected item with its marker missing, and the
    /// source markers go back on verbatim — a mid-list selection keeps `6.`,
    /// not `1.`. Anything else returns the body untouched.
    static func restoringListMarkers(source: String, body: String) -> String {
        let sourceLines = source
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !sourceLines.isEmpty else { return body }
        var markers: [String] = []
        for line in sourceLines {
            guard let marker = listMarkerPrefix(of: line) else { return body }
            markers.append(marker)
        }
        // Blank-line blocks first (the shape Grammar emits), else one item
        // per non-empty line.
        let blocks = body
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let lines = body
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let units: [String]
        let joiner: String
        if blocks.count == markers.count {
            units = blocks
            joiner = "\n\n"
        } else if lines.count == markers.count {
            units = lines
            joiner = "\n"
        } else {
            return body
        }
        // Never double-mark: if the model kept any marker, its structure stands.
        guard !units.contains(where: { listMarkerPrefix(of: $0) != nil }) else { return body }
        return zip(markers, units).map { "\($0) \($1)" }.joined(separator: joiner)
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
