import Foundation

/// One panel session, reconstructed from every event sharing an `invocationID`.
///
/// The log records *events*, not sessions: a single press of the hotkey can
/// produce an `invoked`, several `generationStarted` / `generationFinished`
/// pairs as the user regenerates or switches action, and one terminal event.
/// Showing those raw would list the same piece of work three times, so the
/// reader folds them back into the thing the user actually did.
struct UsageRun: Identifiable, Sendable, Equatable {
    /// The invocation id. Stable, so a selection survives a reload.
    let id: UUID
    let startedAt: Date

    let hostAppName: String?
    let hostBundleID: String?
    let targetID: String?

    /// The action whose result the user took, or the last one generated.
    let actionID: String?
    let actionName: String?
    let model: String?
    let providerKind: String?

    let inputText: String
    let outputText: String?
    let rationale: String?
    let instruction: String?

    let inputTokens: Int?
    let outputTokens: Int?
    /// Positive when the result came out leaner. Negative means it grew, and is
    /// shown that way rather than clamped.
    let savedTokens: Int?

    let outcome: Outcome
    /// How many generations ran. More than one means regenerate, or a switch
    /// between actions within the session.
    let generationCount: Int
    let totalMs: Int?
    let truncated: Bool

    enum Outcome: Equatable, Sendable {
        case replaced
        case copied
        case dismissed
        case cancelled
        case failed(String?)
        /// The hotkey fired with nothing selected.
        case emptySelection
        /// No terminal event. There is no click-outside dismissal, so this
        /// means the panel was left open and the app quit or the session was
        /// otherwise abandoned — it is not the same as "dismissed".
        case abandoned

        /// Only results the user took credit the savings total, so this is also
        /// what the list filters on.
        var wasAccepted: Bool {
            self == .replaced || self == .copied
        }

        var label: String {
            switch self {
            case .replaced: return "Replaced"
            case .copied: return "Copied"
            case .dismissed: return "Dismissed"
            case .cancelled: return "Cancelled"
            case .failed: return "Failed"
            case .emptySelection: return "No text selected"
            case .abandoned: return "Left open"
            }
        }
    }

    /// First line of the input, for the list row.
    var summaryLine: String {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstLine = trimmed.split(separator: "\n", omittingEmptySubsequences: true).first else {
            return trimmed
        }
        return String(firstLine)
    }

    /// Text to send back to the panel. Prefer the result; fall back to the input.
    var enhanceAgainText: String? {
        let output = outputText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !output.isEmpty { return output }
        let input = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        return input.isEmpty ? nil : input
    }

    /// Result body for Pin / Save as note. Nil when the run produced nothing.
    var resultForVault: String? {
        let output = outputText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return output.isEmpty ? nil : output
    }

    /// Title for a vault note created from this run.
    var suggestedVaultTitle: String {
        guard let body = resultForVault else {
            return actionName ?? "Untitled"
        }
        let line = body.split(whereSeparator: \.isNewline).first?
            .trimmingCharacters(in: .whitespaces) ?? ""
        let cleaned = line.hasPrefix("#")
            ? line.drop(while: { $0 == "#" || $0 == " " })
            : Substring(line)
        let title = String(cleaned.prefix(80))
        if title.isEmpty { return actionName ?? "Untitled" }
        return title
    }
}
