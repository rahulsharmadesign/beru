import SwiftUI

/// Six tone cards for a finished Smart Reply run. Clicking a card (or the
/// composer tone pill) chooses which body Insert / Copy / Pin send.
/// Every card carries its own copy / regenerate / like / dislike / insert /
/// pin row: regenerate re-runs all six from any row, a vote teaches that
/// row's tone even when another is selected, and insert / pin act on the
/// row after selecting it first. The tab footer is gone.
struct ReplySuggestionsView: View {
    let suggestions: [ReplySuggestion]
    let selected: ReplyTone
    var copied: Bool = false
    var votes: [ReplyTone: Bool] = [:]
    var pinnedRow: String? = nil
    let onSelect: (ReplyTone) -> Void
    let onCopy: (ReplyTone) -> Void
    let onRegenerate: () -> Void
    let onVote: (ReplyTone, Bool) -> Void
    let onReplace: (ReplyTone) -> Void
    let onPin: (ReplyTone) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BeruSpace.xs) {
            ForEach(suggestions) { item in
                SuggestionOptionCard(
                    title: item.tone.title,
                    bodyText: item.body,
                    isSelected: item.tone == selected,
                    copied: copied && item.tone == selected,
                    accessibilityLabel: "\(item.tone.title) reply",
                    onSelect: { onSelect(item.tone) },
                    onCopy: { onCopy(item.tone) },
                    showActions: true,
                    vote: votes[item.tone],
                    pinned: pinnedRow == item.tone.rawValue,
                    writeTitle: "Insert",
                    writeHelp: "Insert this reply",
                    onRegenerate: onRegenerate,
                    onVote: { onVote(item.tone, $0) },
                    onReplace: { onReplace(item.tone) },
                    onPin: { onPin(item.tone) }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
