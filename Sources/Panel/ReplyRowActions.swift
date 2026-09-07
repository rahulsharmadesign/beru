import SwiftUI

// Smart Reply row outcomes: vote, insert, and pin act on the row after
// selecting it first, so the decision log and the sent text agree —
// exactly like row copy. The tab footer is gone; rows own every outcome.

extension PanelView {
    /// Row vote teaches the row's tone even when another is selected.
    /// Tapping the active side clears it without logging, matching search.
    func setReplyVote(_ tone: ReplyTone, liked: Bool) {
        if appState.replyVote[tone] == liked {
            appState.replyVote.removeValue(forKey: tone)
        } else {
            appState.replyVote[tone] = liked
            guard let body = ReplySuggestions.body(in: appState.replySuggestions, matching: tone) else { return }
            engine.recordResultVote(
                actionID: EnhancementAction.replyID,
                liked: liked,
                text: body,
                replyTone: tone
            )
        }
    }

    func replaceReplyTone(_ tone: ReplyTone) {
        appState.selectedReplyTone = tone
        performReplace()
    }

    func pinReplyTone(_ tone: ReplyTone) {
        appState.selectedReplyTone = tone
        pinRowFlash(key: tone.rawValue, text: ReplySuggestions.body(in: appState.replySuggestions, matching: tone))
    }
}
