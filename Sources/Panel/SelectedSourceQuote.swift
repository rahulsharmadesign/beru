import SwiftUI

/// The selected text a Search question is asked about, quoted above the
/// thread. The panel used to show only "N characters" here, so a question
/// like "What is this?" read as ungrounded — for the user and the model.
///
/// Collapsed to two lines with tap-to-expand (the `RationaleNote` pattern):
/// a selection can run to 8000 chars and must not shove the composer.
/// Lives in the measured result band, so it grows the window like a thread
/// turn instead of fighting the composer's overlap.
struct SelectedSourceQuote: View {
    /// Collapsed char cap on top of the two-line clamp, so a wall of text
    /// without line breaks still settles instead of stretching the window.
    static let collapsedCharCap = 300

    let text: String

    @State private var isExpanded = false

    static func preview(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > collapsedCharCap else { return trimmed }
        return String(trimmed.prefix(collapsedCharCap)).trimmingCharacters(in: .whitespaces) + "…"
    }

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.16)) { isExpanded.toggle() }
        } label: {
            HStack(alignment: .top, spacing: BeruSpace.xs) {
                Rectangle()
                    .fill(BeruColor.accent)
                    .frame(width: 2)
                if isExpanded {
                    Text(text.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(BeruType.footnote)
                        .foregroundStyle(BeruColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                } else {
                    Text(Self.preview(text))
                        .font(BeruType.footnote)
                        .foregroundStyle(BeruColor.textSecondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                BeruIcon(name: "chevron-down", size: BeruMetrics.iconSizeDense, strokeWidth: 2)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    .foregroundStyle(BeruColor.textTertiary)
            }
            .padding(BeruSpace.sm)
            .background(BeruColor.surface2)
            .clipShape(BeruRadius.shape(BeruRadius.sm2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Selected text this question is asked about. Click to expand.")
        .padding(.bottom, BeruSpace.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
