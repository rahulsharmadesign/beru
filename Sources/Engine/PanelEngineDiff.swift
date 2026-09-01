import Foundation
import os

// Post-stream work: the word diff and the usage-log outcome records.

extension PanelEngine {
    /// How much of the result must survive from the original for a diff to be
    /// worth rendering (see `WordDiff.retentionRatio`).
    ///
    /// An inline diff communicates by showing a mostly-intact document with the
    /// changes marked. Once little is shared there is no skeleton left, so the
    /// renderer interleaves two unrelated documents word by word and emits things
    /// like `Can<context>` and `I need theThe` — output that looks corrupted even
    /// though the result is perfectly correct. Enhance hits this routinely, since
    /// rewriting into a structured prompt shares almost no wording with the input.
    ///
    /// Calibrated against measured values rather than guessed: a single typo
    /// retains 0.55, a short grammar pass 0.52, a long one 0.80, a tone rewrite
    /// 0.48 — while the reported XML-structure rewrite retained 0.27 and a total
    /// rewrite 0.06. 0.4 sits in the gap with margin on both sides.
    static let diffLegibilityFloor = 0.4

    func computeDiff(actionID: String, original: String, revised: String) async {
        // Transform verbs are new documents, not edits of the selection. Skip
        // before the LCS work — and before we could store a "legible" diff that
        // still reads as corrupted interleaved text.
        guard EnhancementAction.showsInlineDiff(for: actionID) else { return }

        let ops = await Task.detached(priority: .userInitiated) {
            WordDiff.diff(original: original, revised: revised)
        }.value
        // The result may have been superseded while the diff ran; a diff
        // attached to text that is no longer on screen would highlight the
        // wrong words.
        guard case .done(revised) = appState.resultState(for: actionID) else { return }

        // A diff of identical text is all `.equal` — nothing to highlight, and
        // storing it would hide the "nothing needed fixing" notice behind an
        // apparently-empty diff view.
        let hasChanges = ops.contains {
            switch $0 {
            case .insertion, .deletion: return true
            case .equal: return false
            }
        }
        guard hasChanges else { return }

        guard WordDiff.retentionRatio(ops) >= Self.diffLegibilityFloor else {
            // Leave the diff unset so the plain result renders, and say why —
            // silently dropping it would look like the diff had failed.
            appState.heavyRewriteNotices.insert(actionID)
            return
        }
        appState.diffs[actionID] = ops

        // Grammar may only replace a word with a corrected spelling of it. When
        // most of its substitutions are unrelated words, the model paraphrased —
        // and it should say so rather than pass a rewrite off as a correction.
        if actionID == EnhancementAction.grammarID,
           appState.selectedGrammarKind == .corrected,
           WordDiff.paraphraseScore(ops) > Self.grammarParaphraseCeiling {
            appState.restyledNotices.insert(actionID)
        }
    }

    /// Above this share of unrelated word substitutions, Grammar has rewritten
    /// rather than corrected. Corrections cluster near 0 (every replacement is a
    /// near-miss of the original word); the reported paraphrase scored 1.0.
    static let grammarParaphraseCeiling = 0.4

    /// Separates the result from its explanation.
    ///
    /// MUST run in the engine, before `.done(...)` — never in the view. Replace
    /// pastes the result string verbatim into the user's document, so a split
    /// that happened at render time would eventually paste "here's why I
    /// changed your wording" into somebody's Slack message.
    ///
    /// An unterminated opening tag (cancelled or truncated stream) still counts
    /// as a split: everything from the tag onward becomes the rationale, so the
    /// markup cannot survive into the result under any circumstances.
    static func splitRationale(_ text: String) -> (result: String, rationale: String?) {
        guard let open = text.range(of: Prompts.rationaleOpenTag) else {
            return (text, nil)
        }
        let result = String(text[..<open.lowerBound])
        var rationale = String(text[open.upperBound...])
        if let close = rationale.range(of: Prompts.rationaleCloseTag) {
            rationale = String(rationale[..<close.lowerBound])
        }
        let trimmed = rationale.trimmingCharacters(in: .whitespacesAndNewlines)
        return (
            result.trimmingCharacters(in: .whitespacesAndNewlines),
            trimmed.isEmpty ? nil : trimmed
        )
    }

    /// The portion of a partial stream that is safe to display. Drops anything
    /// from the rationale tag onward, and also any incomplete prefix of it, so
    /// the user never watches "<wh" appear and then vanish mid-stream.
    static func visibleWhileStreaming(_ text: String) -> String {
        if let open = text.range(of: Prompts.rationaleOpenTag) {
            return String(text[..<open.lowerBound])
        }
        var partial = Prompts.rationaleOpenTag.dropLast()
        while !partial.isEmpty {
            if text.hasSuffix(partial) {
                return String(text.dropLast(partial.count))
            }
            partial = partial.dropLast()
        }
        return text
    }

    /// Container tags a model added that the user never wrote.
    ///
    /// Replace pastes the result into the document the text came from, so a
    /// `<context>…</context><task>…</task>` skeleton lands in the middle of
    /// someone's writing. The Claude target no longer asks for tags, but a
    /// prompt instruction is a probability and this is a one-way write into a
    /// real document, so the guarantee is made structurally as well.
    ///
    /// Only tags absent from the input are removed. Someone enhancing text that
    /// genuinely discusses `<task>`, or a prompt they deliberately tagged
    /// themselves, must get their own markup back untouched — the rule is the
    /// same one the target fragments follow: never remove what the user supplied.
    ///
    /// Container names only. `<b>`, `<div>` and the like are left alone: those
    /// appear in text about code, where they are content rather than scaffolding.
    nonisolated static let scaffoldingTags = ["context", "task", "document", "instructions", "examples", "example"]

    /// `nonisolated` so the rule is testable off the main actor, like the
    /// wrapping strip it composes with.
    nonisolated static func strippedScaffolding(_ text: String, input: String) -> String {
        var result = text
        for tag in scaffoldingTags {
            for form in ["<\(tag)>", "</\(tag)>"] {
                // Present in the input means the user wrote it; leave it.
                guard !input.localizedCaseInsensitiveContains(form) else { continue }
                guard result.localizedCaseInsensitiveContains(form) else { continue }
                // Drop the tag and, when it sat alone, the line it occupied, so
                // removing it does not leave a blank gap mid-paragraph.
                result = result.replacingOccurrences(
                    of: "^[ \t]*\(form)[ \t]*\n?",
                    with: "",
                    options: [.regularExpression, .caseInsensitive]
                )
                result = result.replacingOccurrences(
                    of: "\n[ \t]*\(form)[ \t]*(?=\n|$)",
                    with: "",
                    options: [.regularExpression, .caseInsensitive]
                )
                result = result.replacingOccurrences(
                    of: form, with: "", options: [.caseInsensitive]
                )
            }
        }
        // Collapse the runs of blank lines that removal can leave behind.
        result = result.replacingOccurrences(
            of: "\n{3,}", with: "\n\n", options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Models occasionally wrap output in code fences or quotes despite the
    /// prompt forbidding it; strip a single wrapping layer deterministically.
    ///
    /// The marker case now matters on every action, not just Grammar: the
    /// captured text always arrives wrapped, so any model that echoes its input
    /// framing echoes the markers with it.
    nonisolated static func strippedWrapping(_ text: String) -> String {
        var result = text
        if result.hasPrefix(Prompts.textOpenTag), result.hasSuffix(Prompts.textCloseTag) {
            result = String(
                result.dropFirst(Prompts.textOpenTag.count).dropLast(Prompts.textCloseTag.count)
            ).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if result.hasPrefix("```"), result.hasSuffix("```"), result.count > 6 {
            var lines = result.components(separatedBy: "\n")
            if lines.count >= 2 {
                lines.removeFirst()
                if lines.last?.trimmingCharacters(in: .whitespaces) == "```" {
                    lines.removeLast()
                }
                result = lines.joined(separator: "\n")
            }
        }
        for (open, close) in [("\"", "\""), ("\u{201C}", "\u{201D}")] {
            if result.hasPrefix(open), result.hasSuffix(close), result.count > 2 {
                result = String(result.dropFirst().dropLast())
                break
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Search answers used to render as plain text, so ATX headings (`### Yes`)
    /// printed as hashes. The panel now styles those lines as headings; this
    /// remains for tests and any caller that still needs the stripped form.
    nonisolated static func strippedSearchChrome(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n").map { line -> String in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("#") else { return line }
            let hashes = trimmed.prefix { $0 == "#" }.count
            guard (1...6).contains(hashes) else { return line }
            let rest = trimmed.dropFirst(hashes)
            guard rest.first?.isWhitespace == true else { return line }
            return rest.trimmingCharacters(in: .whitespaces)
        }
        return lines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Builds a generation-outcome history record. Output text is stored only
    /// here (once per generation); terminal events reference it by digest.
    static func recordOutcome(
        _ kind: UsageEventKind,
        invocationID: UUID,
        actionID: String,
        attempt: Int,
        ttfbMs: Int? = nil,
        totalMs: Int,
        reasoningChunks: Int,
        output: String? = nil,
        savings: TokenSavings? = nil,
        rationale: String? = nil,
        errorMessage: String? = nil
    ) {
        UsageLog.record {
            UsageEvent(
                invocationID: invocationID,
                kind: kind,
                actionID: actionID,
                attempt: attempt,
                outputText: output,
                outputChars: output?.count,
                outputDigest: output.map { UsageLog.digest($0) },
                inputTokens: savings?.inputTokens,
                outputTokens: savings?.outputTokens,
                savedTokens: savings?.savedTokens,
                rationale: rationale,
                ttfbMs: ttfbMs,
                totalMs: totalMs,
                reasoningChunks: reasoningChunks,
                errorMessage: errorMessage
            )
        }
    }

    static func milliseconds(_ duration: Duration) -> Int {
        Int(duration.components.seconds) * 1000 +
            Int(duration.components.attoseconds / 1_000_000_000_000_000)
    }
}
