import SwiftUI

/// One selectable suggestion card: tone / kind label, body, icon-only copy
/// at the trailing bottom. Shared by Smart Reply and Grammar.
///
/// Copy is a sibling of the select control, not an overlay on a `Button`.
/// Nesting buttons plus `textSelection` inside the label crashed AttributeGraph
/// (`Array.==` during layout compare).
struct SuggestionOptionCard: View {
    let title: String
    let bodyText: String
    let isSelected: Bool
    var copied: Bool = false
    let accessibilityLabel: String
    let onSelect: () -> Void
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BeruSpace.xxs) {
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: BeruSpace.xxs) {
                    Text(title)
                        .font(BeruType.captionMedium)
                        .foregroundStyle(isSelected ? BeruColor.accent : BeruColor.textSecondary)
                    Text(bodyText)
                        .font(BeruType.resultBody)
                        .foregroundStyle(BeruColor.textPrimary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            HStack {
                Spacer(minLength: 0)
                BeruIconButton(
                    icon: copied ? "checkmark" : "square.on.square",
                    size: 12,
                    frameSize: BeruMetrics.hitTargetCompact,
                    tint: copied ? BeruColor.positive : BeruColor.textSecondary,
                    help: copied ? "Copied" : "Copy \(title)"
                ) {
                    onCopy()
                }
            }
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
    }
}
