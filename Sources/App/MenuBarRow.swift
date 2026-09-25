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
            HStack(spacing: EnhancifySpace.xs) {
                EnhancifyIcon(name: icon, size: EnhancifyMetrics.iconSizeCompact, strokeWidth: 2)
                    .foregroundStyle(EnhancifyColor.textSecondary)
                    .frame(width: EnhancifyMetrics.iconSize)
                Text(title)
                    .font(EnhancifyType.control)
                    .foregroundStyle(EnhancifyColor.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: EnhancifySpace.xs)
                if let shortcut {
                    Text(shortcut)
                        .font(EnhancifyType.footnote)
                        .foregroundStyle(EnhancifyColor.textTertiary)
                }
            }
            .padding(.horizontal, EnhancifySpace.xs)
            .frame(maxWidth: .infinity, minHeight: height, alignment: .leading)
            .background(
                EnhancifyRadius.shape(EnhancifyRadius.sm)
                    .fill(isHovered ? EnhancifyColor.hoverFill : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(title)
    }
}
