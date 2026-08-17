import SwiftUI

/// The "why" line under a result.
///
/// Collapsed to a single line by default and never auto-expanded: the panel is a
/// two-second surface, and a paragraph of advice in the middle of a replace-and-go
/// flow would be an obstacle rather than a lesson. Expanding is a choice the user
/// makes when they have a moment.
struct RationaleNote: View {
    let text: String

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.easeOut(duration: 0.16)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 5) {
                    BeruIcon(name: "graduation-cap", size: 10, strokeWidth: 2)
                    Text(isExpanded ? "Why" : text)
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    BeruIcon(name: "chevron-down", size: 8, strokeWidth: 2.5)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(text)

            if isExpanded {
                Text(text)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        // The panel sizes itself from measured content; without this the window
        // does not grow and the expanded text is clipped.
        .contributesPanelHeight()
    }
}
