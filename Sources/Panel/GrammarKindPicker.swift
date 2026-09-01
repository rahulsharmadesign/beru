import SwiftUI

/// Compact picker for Grammar's three bodies. Only the selected body is in
/// the result field; these segments swap it without a second model call.
struct GrammarKindPicker: View {
    let suggestions: [GrammarSuggestion]
    let selected: GrammarKind
    let onSelect: (GrammarKind) -> Void

    var body: some View {
        Picker("Grammar option", selection: Binding(
            get: { selected },
            set: { onSelect($0) }
        )) {
            ForEach(suggestions) { item in
                Text(item.kind.title)
                    .tag(item.kind)
                    .accessibilityLabel("\(item.kind.title) grammar option")
                    .accessibilityAddTraits(item.kind == selected ? .isSelected : [])
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
        .labelsHidden()
        .padding(.top, BeruSpace.xs)
    }
}
