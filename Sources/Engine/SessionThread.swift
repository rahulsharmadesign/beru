import Foundation
import Observation

/// Short-term memory of what you just asked for, per app.
///
/// Every request is otherwise exactly `[system, user]` with no history, so two
/// Enhance passes in a row are strangers: the second cannot build on the first,
/// and a follow-up like "shorter" has nothing to be shorter than. This keeps
/// turns for the app you invoked from and folds them into the system prompt.
///
/// Deliberately forgetful, not small:
///
/// - **Memory only.** Never written to disk, at any setting. It dies with the
///   process. This is text pulled out of whatever you had selected, often from a
///   document you would not want cached, and it is independent of usage logging.
/// - **Per app.** Keyed by host bundle id, so an Enhance in Mail cannot leak
///   into an Enhance in Terminal, and switching apps clears the thread.
/// - **Until you clear it.** Click the chip, switch apps, turn the setting off,
///   or quit. No idle expiry. A safety cap only guards a runaway loop.
@MainActor
@Observable
final class SessionThread {
    static let shared = SessionThread()

    struct Turn: Equatable {
        let actionID: String
        let actionName: String
        /// What the user typed in the intent field, if anything.
        let instruction: String
        /// Opening of the text that was worked on, for grounding only.
        let inputDigest: String
        let output: String
        let at: Date
    }

    /// Runaway-loop guard only. The prompt budget, not this, is what the model sees.
    static let storageCap = 100
    /// The whole block, so history can never crowd out the actual request.
    static let blockCharBudget = 8000
    /// Per-turn output. The shape of a previous answer is the useful signal;
    /// the whole of it is not.
    static let outputCharBudget = 400
    static let inputDigestCharBudget = 160

    private(set) var bundleID: String?
    private(set) var turns: [Turn] = []
    /// Bumped on `clear()`. An in-flight stream that started before a clear
    /// must not append after it.
    private(set) var epoch: UInt64 = 0

    private init() {}

    /// Turns available for the app in front. Reading this is what the panel
    /// chip and the prompt layer both go through, so neither can show or send
    /// a stale thread.
    func turns(forBundleID id: String?) -> [Turn] {
        guard let id, bundleID == id else { return [] }
        return turns
    }

    func record(
        actionID: String,
        actionName: String,
        instruction: String,
        input: String,
        output: String,
        bundleID id: String?,
        at now: Date = Date(),
        expectedEpoch: UInt64? = nil
    ) {
        if let expectedEpoch, expectedEpoch != epoch { return }
        guard Prompts.threadApplies(actionID: actionID) else { return }
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOutput.isEmpty else { return }

        // A different app is a different conversation, not a continuation.
        if bundleID != id {
            bundleID = id
            turns = []
        }

        turns.append(
            Turn(
                actionID: actionID,
                actionName: actionName,
                instruction: instruction.trimmingCharacters(in: .whitespacesAndNewlines),
                inputDigest: Self.clip(input, to: Self.inputDigestCharBudget),
                output: Self.clip(trimmedOutput, to: Self.outputCharBudget),
                at: now
            )
        )
        if turns.count > Self.storageCap {
            turns.removeFirst(turns.count - Self.storageCap)
        }
    }

    /// User-initiated, from the panel chip.
    func clear() {
        epoch += 1
        turns = []
        bundleID = nil
    }

    /// Called when the host app changes, so the next invocation starts clean.
    func hostChanged(to id: String?) {
        guard bundleID != id else { return }
        clear()
        bundleID = id
    }

    /// Truncates on a word boundary where there is one nearby, so the model is
    /// not handed a fragment of a word as if it were the whole thought.
    nonisolated static func clip(_ text: String, to limit: Int) -> String {
        let collapsed = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        guard collapsed.count > limit else { return collapsed }
        let head = collapsed.prefix(limit)
        if let space = head.lastIndex(of: " "), head.distance(from: head.startIndex, to: space) > limit / 2 {
            return String(head[head.startIndex..<space]) + "…"
        }
        return String(head) + "…"
    }
}
