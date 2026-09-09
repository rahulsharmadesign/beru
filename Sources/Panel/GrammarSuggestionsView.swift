import SwiftUI

/// Three Grammar bodies as stacked cards. Clicking a card (or its copy icon)
/// chooses which body Replace / Copy / Pin send — no second model call.
/// Every card carries its own copy / regenerate / like / dislike / replace /
/// pin row: regenerate re-runs the whole triple from any row, a vote teaches
/// that row's kind even when another row is selected, and replace / pin act
/// on the row after selecting it first. The tab footer is gone.
struct GrammarSuggestionsView: View {
    let suggestions: [GrammarSuggestion]
    let selected: GrammarKind
    var copied: Bool = false
    var votes: [GrammarKind: Bool] = [:]
    var pinnedRow: String? = nil
    let onSelect: (GrammarKind) -> Void
    let onCopy: (GrammarKind) -> Void
    let onRegenerate: () -> Void
    let onVote: (GrammarKind, Bool) -> Void
    let onReplace: (GrammarKind) -> Void
    let onPin: (GrammarKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BeruSpace.xs) {
            ForEach(suggestions) { item in
                SuggestionOptionCard(
                    title: item.kind.title,
                    bodyText: item.body,
                    isSelected: item.kind == selected,
                    copied: copied && item.kind == selected,
                    accessibilityLabel: "\(item.kind.title) grammar option",
                    onSelect: { onSelect(item.kind) },
                    onCopy: { onCopy(item.kind) },
                    showActions: true,
                    vote: votes[item.kind],
                    pinned: pinnedRow == item.kind.rawValue,
                    writeTitle: "Replace",
                    writeHelp: "Replace with this",
                    onRegenerate: onRegenerate,
                    onVote: { onVote(item.kind, $0) },
                    onReplace: { onReplace(item.kind) },
                    onPin: { onPin(item.kind) }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
