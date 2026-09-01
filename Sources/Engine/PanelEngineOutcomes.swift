import AppKit
import Foundation

// What the user does with a result: replace, copy, pin, or cancel.

extension PanelEngine {
    func replace(text: String) {
        guard appState.replacedFeedback == nil else { return }
        // Grab everything the record needs before dismiss clears it.
        let target = appState.capturedElement
        let vaultNoteID = appState.vaultNoteID
        let toast = OutcomeCopy.replaceToast(
            hostAppName: appState.hostAppName,
            isVault: vaultNoteID != nil,
            isInsert: appState.selectedActionID == EnhancementAction.replyID
        )
        recordDecision(.replaced, text: text)
        if let vaultNoteID {
            VaultStore.shared.applyResult(text, toNoteID: vaultNoteID)
        }
        pendingReplaceText = text
        pendingReplaceTarget = target
        pendingReplaceIsVault = vaultNoteID != nil
        pendingReplaceVaultNoteID = vaultNoteID
        appState.replacedFeedback = toast
        replaceToastTask?.cancel()
        replaceToastTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                return
            }
            await self?.completeReplace()
        }
    }

    /// Dismiss, then paste once the panel is gone so Cmd-V cannot hit the composer.
    func completeReplace() async {
        let text = pendingReplaceText
        let target = pendingReplaceTarget
        let isVault = pendingReplaceIsVault
        let vaultID = pendingReplaceVaultNoteID
        pendingReplaceText = nil
        pendingReplaceTarget = nil
        pendingReplaceIsVault = false
        pendingReplaceVaultNoteID = nil
        replaceToastTask = nil
        appState.replacedFeedback = nil
        guard text != nil || isVault else { return }
        onDismiss()
        if isVault {
            if let vaultID { onRevealVaultNote?(vaultID) }
            return
        }
        guard let text else { return }
        // hide() fades 180ms then orderOut. Cmd-V before that lands on the
        // panel's field editor. Wait until the window is gone, then paste.
        try? await Task.sleep(for: .milliseconds(350))
        await TextReplace.replaceSelection(with: text, target: target)
    }

    func copy(text: String) {
        guard appState.replacedFeedback == nil else { return }
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
        guard appState.replacedFeedback == nil else { return }
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
        if appState.replacedFeedback != nil {
            replaceToastTask?.cancel()
            Task { await completeReplace() }
            return
        }
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
        if accepted {
            SettingsStore.shared.recordAcceptedInteraction(
                actionID: actionID,
                replyTone: actionID == EnhancementAction.replyID ? appState.selectedReplyTone : nil,
                grammarKind: actionID == EnhancementAction.grammarID ? appState.selectedGrammarKind : nil,
                targetName: TargetRegistry.shared.profile(withID: appState.selectedTargetID)?.name,
                instruction: appState.describeInstruction
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

/// Footer confirmation after Replace / Insert / Apply.
enum OutcomeCopy {
    static func replaceToast(hostAppName: String?, isVault: Bool, isInsert: Bool) -> String {
        if isVault { return "Applied to note" }
        let trimmed = hostAppName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let host = trimmed.isEmpty ? "Mac" : trimmed
        return isInsert ? "Inserted in \(host)" : "Replaced in \(host)"
    }
}
