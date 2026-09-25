import SwiftUI

// Focused-mode composer collapse, plus the footer's vote and provenance
// helpers. Split out of PanelComposer.swift to keep it under 400 lines.

extension PanelView {
    /// Focused mode hides the composer while there is a selection to work on:
    /// the result and its actions are the whole panel. It comes back when
    /// there is nothing selected (it is the input then), when you type or
    /// dictate, or on ⌘L / Refine.
    var composerCollapsed: Bool {
        PanelMode.isFocused
            && hasCapturedText
            && appState.describeInstruction.isEmpty
            && !composerExpanded
            && !DictationService.shared.isRecording
    }

    /// One quiet line in the otherwise empty footer band, so the keyboard
    /// moves stay discoverable without a headline in the middle of the panel.
    var footerHint: String? {
        let other = appState.selectedActionID == EnhancementAction.grammarID ? "Enhance" : "Grammar"
        if composerCollapsed {
            return "Type to refine · Tab switches to \(other)"
        }
        if idleIsCompact && showsIdlePlaceholderOnly {
            return "Return runs · Tab switches to \(other)"
        }
        return nil
    }

    func hintLine(_ text: String) -> some View {
        Text(text)
            .font(BeruType.captionMedium)
            .foregroundStyle(BeruColor.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, PanelMetrics.moduleInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(false)
    }

    /// Footer vote: same toggle-and-log as search turns, keyed by action.
    /// Likes on Smart Reply and Grammar additionally teach the stored
    /// preference inside `recordResultVote`; dislikes clear a match.
    func setResultVoteFooter(liked: Bool) {
        let actionID = appState.selectedActionID
        guard let text = appState.acceptedText() else { return }
        if appState.resultFeedback[actionID] == liked {
            appState.resultFeedback.removeValue(forKey: actionID)
        } else {
            appState.resultFeedback[actionID] = liked
            engine.recordResultVote(actionID: actionID, liked: liked, text: text)
        }
    }

    var contextProvenance: String? {
        guard let context = appState.contextApplications[appState.selectedActionID] else { return nil }
        if let playbook = context.playbook { return "Playbook: \(playbook.name)" }
        if !context.rules.isEmpty { return "Rules: \(context.rules.count)" }
        if let workspace = context.workspace, workspace.hasMemory { return "Workspace: \(workspace.name)" }
        return context.glossary.isEmpty ? nil : "Glossary"
    }
}
