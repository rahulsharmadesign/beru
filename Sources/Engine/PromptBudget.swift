import Foundation
import FoundationModels

/// Keeps a request inside the on-device model's context window.
///
/// Beru caps a capture at `PanelEngine.maxCapturedLength` (8000 characters)
/// because a 128k-context server model can take it. The on-device model cannot:
/// its window is a few thousand tokens for prompt *and* reply together, and
/// Beru's own system prompts are already ~700 of them. Without this clamp the
/// first long selection would fail with `exceededContextWindowSize` — an error
/// the user cannot act on, on a provider they cannot reconfigure.
///
/// Pure and synchronous by design: it must be unit-testable without a Mac that
/// has Apple Intelligence, and the clamp has to happen before the request.
struct PromptBudget: Equatable, Sendable {
    let contextSize: Int
    let systemTokens: Int
    let requestedOutputTokens: Int
    /// Beru's own capture cap, so this clamp can never widen a capture.
    var capturedCharacterCap: Int = 8000

    /// Output is worth at most half the window: the model has to fit the
    /// instruction, the source text, and its own reply in one budget, and a
    /// reply that is longer than its source is a symptom, not a goal.
    var outputTokens: Int {
        min(requestedOutputTokens, max(256, contextSize / 2))
    }

    var inputTokensAvailable: Int {
        max(0, contextSize - systemTokens - outputTokens)
    }

    /// Live budget, read from the framework rather than hardcoded — Apple
    /// changes the window between OS releases.
    static func onDevice(
        system: String,
        role: ModelRole,
        expectsRationale: Bool,
        input: String,
        contextSize: Int = SystemLanguageModel.default.contextSize
    ) -> PromptBudget {
        PromptBudget(
            contextSize: contextSize,
            systemTokens: TokenEstimate.tokens(in: system),
            requestedOutputTokens: ProviderTuning.maxTokens(
                for: role, input: input, expectsRationale: expectsRationale
            )
        )
    }

    /// Trims the captured text to what fits, on a character budget.
    ///
    /// Trims at a whitespace boundary where one is close, so the model is not
    /// handed half a word, and reports how much was dropped so the panel can
    /// raise the same truncation notice it uses for the 8000-character cap.
    func clamp(_ captured: String) -> PromptClamp {
        let allowed = min(TokenEstimate.characters(forTokens: inputTokensAvailable), capturedCharacterCap)
        guard captured.count > allowed else {
            return PromptClamp(text: captured, truncated: false, droppedCharacters: 0)
        }
        var kept = String(captured.prefix(max(0, allowed)))
        if let lastSpace = kept.lastIndex(where: { $0.isWhitespace }),
           kept.distance(from: kept.startIndex, to: lastSpace) > allowed / 2 {
            kept = String(kept[..<lastSpace])
        }
        return PromptClamp(
            text: kept,
            truncated: true,
            droppedCharacters: captured.count - kept.count
        )
    }
}

struct PromptClamp: Equatable, Sendable {
    let text: String
    let truncated: Bool
    let droppedCharacters: Int
}

/// Turns cumulative snapshots from Foundation Models into the deltas Beru's
/// stream consumers append.
///
/// `ResponseStream<String>.Snapshot.content` is the text *so far*, not the new
/// piece. Beru's `StreamChunk.content` is treated as a delta everywhere
/// (`PanelEngineStream` appends), so a provider that forwarded snapshots
/// verbatim would print the answer growing quadratically.
struct DeltaAccumulator {
    private(set) var emitted = ""

    mutating func delta(forCumulative cumulative: String) -> String? {
        guard cumulative.count > emitted.count else { return nil }
        let delta = String(cumulative.dropFirst(emitted.count))
        emitted = cumulative
        return delta
    }

    /// Non-mutating helper, so the delta rule is testable on its own.
    static func delta(from emitted: String, to cumulative: String) -> String? {
        guard cumulative.count > emitted.count else { return nil }
        return String(cumulative.dropFirst(emitted.count))
    }
}