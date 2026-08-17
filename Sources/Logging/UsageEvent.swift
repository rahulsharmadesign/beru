import Foundation

enum UsageEventKind: String, Codable, Sendable {
    case invoked
    case emptySelection
    case generationStarted
    case generationFinished
    case generationFailed
    case generationCancelled
    case replaced
    case copied
    case dismissed
}

/// One line of the local usage history. Events from a single panel session
/// share an `invocationID`; `seq` is a process-wide monotonic counter that
/// establishes order even if two events share a timestamp.
///
/// Size discipline: full text appears exactly once per stage — the input on
/// `.invoked`, the system prompt on `.generationStarted`, the output on
/// `.generationFinished`. Terminal events carry only a length and digest so a
/// regenerate-then-replace session doesn't store the same output three times.
///
/// API keys, tokens, and authorization headers are never included in any field.
struct UsageEvent: Codable, Sendable {
    /// v2 added the estimated token-accounting fields below, v3 the `rationale`.
    /// Every one of them is optional, so an older reader still parses a newer
    /// line.
    var schema: Int = 3
    var id: UUID = UUID()
    var invocationID: UUID
    var seq: Int = 0
    var ts: String = ""
    var kind: UsageEventKind
    var appVersion: String?

    var source: String?
    var hostBundleID: String?
    var hostAppName: String?

    var actionID: String?
    var actionName: String?
    var role: String?
    var targetID: String?
    var attempt: Int?
    var providerKind: String?
    var model: String?
    var usedCustomSkillPrompt: Bool?

    var inputText: String?
    var instruction: String?
    var systemPrompt: String?
    var outputText: String?
    var outputChars: Int?
    var outputDigest: String?

    /// Estimated token accounting (see `TokenEstimate` — these are never exact
    /// counts from a provider). Present on `generationFinished` for the result
    /// that was produced, and on `replaced`/`copied` for the result the user
    /// actually took. Absent on `dismissed`: nothing was saved there, so
    /// carrying the numbers would invite summing them.
    var inputTokens: Int?
    var outputTokens: Int?
    /// `inputTokens - outputTokens`. Negative when the result grew.
    var savedTokens: Int?
    /// Lifetime accepted total at the moment of this event, so the log alone
    /// can reconstruct the curve without replaying every line.
    var cumulativeSavedTokens: Int?

    /// The model's explanation of its most important change, recorded on
    /// `generationFinished` so the advice outlives the panel it appeared in.
    /// Absent when Explain changes is off or the model chose to omit it.
    var rationale: String?

    var ttfbMs: Int?
    var totalMs: Int?
    var reasoningChunks: Int?
    var errorMessage: String?
    var hadResult: Bool?
    var truncated: Bool?
}
