import SwiftUI

/// One selectable suggestion row: tone / kind label, body, icon-only copy
/// at the trailing bottom. Shared by Smart Reply and Grammar. Haze `.sugg`
/// rows are borderless — transparent idle, surface on hover, accent wash
/// with an accent edge when selected.
///
/// Grammar opts into a left-aligned action strip (copy, regenerate,
/// like, dislike) under the body; Reply keeps the single trailing copy.
/// The strip is a sibling of the select control, not an overlay on the
/// `Button`: nesting buttons plus `textSelection` inside the label crashed
/// AttributeGraph (`Array.==` during layout compare).
struct SuggestionOptionCard: View {
    let title: String
    let bodyText: String
    let isSelected: Bool
    var copied: Bool = false
    let accessibilityLabel: String
    let onSelect: () -> Void
    let onCopy: () -> Void
    /// Opt-in action strip under the body: copy, regenerate, like,
    /// dislike, write-back, pin. Grammar and Reply rows show it; the tab
    /// footers there are gone, so the rows own every outcome.
    var showActions: Bool = false
    var vote: Bool? = nil
    var pinned: Bool = false
    var writeHelp: String = "Replace with this"
    var onRegenerate: () -> Void = {}
    var onVote: (Bool) -> Void = { _ in }
    var onReplace: () -> Void = {}
    var onPin: () -> Void = {}

    @State private var isHovered = false

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

            if showActions {
                HStack(spacing: BeruSpace.hair) {
                    SearchActionButton(
                        icon: copied ? "check" : "copy",
                        help: copied ? "Copied" : "Copy \(title)",
                        tint: copied ? BeruColor.positive : nil
                    ) {
                        onCopy()
                    }
                    SearchActionButton(icon: "rotate-cw", help: "Check again — rewrites all the options") {
                        onRegenerate()
                    }
                    SearchActionButton(
                        icon: "thumbs-up",
                        help: "Good \(title.lowercased()) — helps Beru learn",
                        active: vote == true
                    ) {
                        onVote(true)
                    }
                    SearchActionButton(
                        icon: "thumbs-down",
                        help: "Bad \(title.lowercased()) — helps Beru learn",
                        active: vote == false
                    ) {
                        onVote(false)
                    }
                    SearchActionButton(icon: "replace", help: "\(writeHelp) — \(title.lowercased())") {
                        onReplace()
                    }
                    SearchActionButton(
                        icon: pinned ? "check" : "pin",
                        help: pinned ? "Pinned" : "Pin \(title.lowercased())",
                        tint: pinned ? BeruColor.positive : nil
                    ) {
                        onPin()
                    }
                }
            } else {
                HStack {
                    Spacer(minLength: 0)
                    BeruIconButton(
                        icon: copied ? "check" : "copy",
                        size: 12,
                        frameSize: BeruMetrics.hitTargetCompact,
                        tint: copied ? BeruColor.positive : BeruColor.textSecondary,
                        help: copied ? "Copied" : "Copy \(title)"
                    ) {
                        onCopy()
                    }
                }
            }
        }
        .padding(BeruSpace.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            BeruRadius.shape(BeruRadius.md)
                .fill(isSelected ? BeruColor.accentSoft : (isHovered ? BeruColor.hoverFill : Color.clear))
                .overlay {
                    if isSelected {
                        BeruRadius.shape(BeruRadius.md)
                            .strokeBorder(BeruColor.accent, lineWidth: 1)
                    }
                }
        }
        .beruColorEase(isSelected)
        .onHover { isHovered = $0 }
.beruHoverEase(isHovered)
    }
}
