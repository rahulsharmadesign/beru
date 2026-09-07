import SwiftUI

// Grammar row outcomes: vote, write-back, and pin act on the row after
// selecting it first, so the decision log and the sent text agree —
// exactly like row copy. The tab footer is gone; rows own every outcome.

extension PanelView {
    /// Row vote teaches the row's kind even when another row is selected —
    /// unlike the footer vote, which follows the selection. Tapping the
    /// active side clears it without logging, matching search turns.
    func setGrammarVote(_ kind: GrammarKind, liked: Bool) {
        if appState.grammarVote[kind] == liked {
            appState.grammarVote.removeValue(forKey: kind)
        } else {
            appState.grammarVote[kind] = liked
            guard let body = GrammarSuggestions.body(in: appState.grammarSuggestions, matching: kind) else { return }
            engine.recordResultVote(
                actionID: EnhancementAction.grammarID,
                liked: liked,
                text: body,
                grammarKind: kind
            )
        }
    }

    func replaceGrammarKind(_ kind: GrammarKind) {
        engine.applyGrammarKind(kind)
        performReplace()
    }

    func pinGrammarKind(_ kind: GrammarKind) {
        engine.applyGrammarKind(kind)
        pinRowFlash(key: kind.rawValue, text: GrammarSuggestions.body(in: appState.grammarSuggestions, matching: kind))
    }
}
