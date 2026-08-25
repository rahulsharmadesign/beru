import SwiftUI

/// Six tone cards for a finished Smart Reply run. Clicking a card (or the
/// composer tone pill) chooses which body Insert / Copy / Pin send.
struct ReplySuggestionsView: View {
    let suggestions: [ReplySuggestion]
    let selected: ReplyTone
    let onSelect: (ReplyTone) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BeruSpace.xs) {
                ForEach(suggestions) { item in
                    card(item)
                }
            }
            .padding(.horizontal, BeruSpace.md)
            .padding(.vertical, BeruSpace.md)
            .contributesPanelHeight()
        }
    }

    private func card(_ item: ReplySuggestion) -> some View {
        let isSelected = item.tone == selected
        return Button {
            onSelect(item.tone)
        } label: {
            VStack(alignment: .leading, spacing: BeruSpace.xxs) {
                Text(item.tone.title)
                    .font(BeruType.captionMedium)
                    .foregroundStyle(isSelected ? BeruColor.accent : BeruColor.textSecondary)
                Text(item.body)
                    .font(BeruType.resultBody)
                    .foregroundStyle(BeruColor.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .padding(BeruSpace.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                BeruRadius.shape(BeruRadius.md)
                    .fill(isSelected ? BeruColor.accent.opacity(0.08) : BeruColor.subtleFill)
                    .overlay(
                        BeruRadius.shape(BeruRadius.md)
                            .strokeBorder(
                                isSelected ? BeruColor.accent : BeruColor.border,
                                lineWidth: 1
                            )
                    )
            }
            .contentShape(BeruRadius.shape(BeruRadius.md))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.tone.title) reply")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
