import SwiftUI

/// Compact picker for Grammar's three bodies. Only the selected body is in
/// the result field; these pills swap it without a second model call.
struct GrammarKindPicker: View {
    let suggestions: [GrammarSuggestion]
    let selected: GrammarKind
    let onSelect: (GrammarKind) -> Void

    var body: some View {
        HStack(spacing: BeruSpace.xs) {
            ForEach(suggestions) { item in
                BeruButton(
                    title: item.kind.title,
                    variant: .pill,
                    size: .compact,
                    isActive: item.kind == selected
                ) {
                    onSelect(item.kind)
                }
                .accessibilityLabel("\(item.kind.title) grammar option")
                .accessibilityAddTraits(item.kind == selected ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
        .padding(.top, BeruSpace.xs)
    }
}
