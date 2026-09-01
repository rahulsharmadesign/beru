import SwiftUI

/// Three Grammar bodies as stacked cards. Clicking a card (or its copy icon)
/// chooses which body Replace / Copy / Pin send — no second model call.
struct GrammarSuggestionsView: View {
    let suggestions: [GrammarSuggestion]
    let selected: GrammarKind
    var copied: Bool = false
    let onSelect: (GrammarKind) -> Void
    let onCopy: (GrammarKind) -> Void

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
                    onCopy: { onCopy(item.kind) }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
