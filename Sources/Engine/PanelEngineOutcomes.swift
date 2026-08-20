import AppKit
import Foundation

// What the user does with a result: replace, copy, pin, or cancel.

extension PanelEngine {
    func replace(text: String) {
        // Grab everything the record needs before dismiss clears it.
        let target = appState.capturedElement
        let vaultNoteID = appState.vaultNoteID
        recordDecision(.replaced, text: text)
        onDismiss()
        if let vaultNoteID {
            VaultStore.shared.applyResult(text, toNoteID: vaultNoteID)
            return
        }
        Task {
            // Let the panel finish resigning key status so the host app is
            // the keystroke recipient again; otherwise a simulated Cmd-V can
            // land on our own (still-ordered-in) panel.
            try? await Task.sleep(for: .milliseconds(250))
            await TextReplace.replaceSelection(with: text, target: target)
        }
    }

    func copy(text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        recordDecision(.copied, text: text)
        appState.copiedFeedback = true
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            appState.copiedFeedback = false
            onDismiss()
        }
    }

    /// Saves the finished result into the vault pin board without dismissing.
    func pin(text: String) {
        let title = String(text.prefix(72))
            .replacingOccurrences(of: "\n", with: " ")
        VaultStore.shared.pinResult(
            title: title,
            body: text,
            actionID: appState.selectedActionID,
            noteID: appState.vaultNoteID
        )
        appState.pinnedFeedback = true
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            appState.pinnedFeedback = false
        }
    }

    func cancel() {
        var resultText: String?
        if case .done(let text) = appState.resultState(for: appState.selectedActionID) {
            resultText = text
        }
        recordDecision(.dismissed, text: resultText)
        lastDescribeInstruction = nil
        onDismiss()
    }

    /// Records a terminal user decision. Must be called BEFORE onDismiss(),
    /// which clears the results, captured text, and savings this reads from.
    /// Carries only a length and digest — the full output was already stored
    /// once by the generation record it refers to.
    ///
    /// This is also where lifetime savings are credited: taking the result is
    /// what makes the saving real, so Replace and Copy count and a dismissal
    /// does not.
    func recordDecision(_ kind: UsageEventKind, text: String?) {
        let actionID = appState.selectedActionID
        let invocationID = appState.invocationID
        let attempt = attempts[actionID]
        let accepted = kind == .replaced || kind == .copied
        let savings = accepted ? appState.savings[actionID] : nil
        let cumulative = savings.map { SavingsStore.shared.record($0) }
        if let savings {
            engineLogger.notice(
                "accepted \(actionID) via \(kind.rawValue): saved \(savings.savedTokens) est. tokens, lifetime \(cumulative ?? 0)"
            )
        }
        UsageLog.record {
            UsageEvent(
                invocationID: invocationID,
                kind: kind,
                actionID: actionID,
                targetID: appState.selectedTargetID,
                attempt: attempt,
                outputChars: text?.count,
                outputDigest: text.map { UsageLog.digest($0) },
                inputTokens: savings?.inputTokens,
                outputTokens: savings?.outputTokens,
                savedTokens: savings?.savedTokens,
                cumulativeSavedTokens: cumulative,
                hadResult: text != nil
            )
        }
    }
}
