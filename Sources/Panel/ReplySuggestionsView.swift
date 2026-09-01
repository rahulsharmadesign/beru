import SwiftUI

/// Six tone cards for a finished Smart Reply run. Clicking a card (or the
/// composer tone pill) chooses which body Insert / Copy / Pin send.
struct ReplySuggestionsView: View {
    let suggestions: [ReplySuggestion]
    let selected: ReplyTone
    var copied: Bool = false
    let onSelect: (ReplyTone) -> Void
    let onCopy: (ReplyTone) -> Void

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
                    onCopy: { onCopy(item.tone) }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
