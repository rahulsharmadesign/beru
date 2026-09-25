import SwiftUI

/// A plain menu-bar dropdown row, drawn like a native menu item: a quiet
/// icon, the title, an optional shortcut, and a soft fill on hover. No
/// accent — the dropdown is a list of commands, not a call to action.
struct MenuBarRow: View {
    let title: String
    let icon: String
    var shortcut: String?
    let height: CGFloat
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: BeruSpace.xs) {
                BeruIcon(name: icon, size: BeruMetrics.iconSizeCompact, strokeWidth: 2)
                    .foregroundStyle(BeruColor.textSecondary)
                    .frame(width: BeruMetrics.iconSize)
                Text(title)
                    .font(BeruType.control)
                    .foregroundStyle(BeruColor.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: BeruSpace.xs)
                if let shortcut {
                    Text(shortcut)
                        .font(BeruType.footnote)
                        .foregroundStyle(BeruColor.textTertiary)
                }
            }
            .padding(.horizontal, BeruSpace.xs)
            .frame(maxWidth: .infinity, minHeight: height, alignment: .leading)
            .background(
                BeruRadius.shape(BeruRadius.sm)
                    .fill(isHovered ? BeruColor.hoverFill : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(title)
    }
}
