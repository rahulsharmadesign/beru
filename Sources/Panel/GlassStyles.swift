import SwiftUI

extension View {
    /// Compact action chip. Selection fill is drawn by the sliding pill in
    /// `PanelView`; chips only handle type color, idle fill, and idle border.
    func glassChip(selected: Bool) -> some View {
        modifier(GlassChipModifier(selected: selected))
    }
}

private struct GlassChipModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let selected: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, BeruSpace.xs)
            .padding(.vertical, BeruSpace.xs)
            .background {
                Capsule().fill(
                    selected
                        ? Color.clear
                        : colorScheme == .dark ? BeruColor.Dark.surface : BeruColor.Light.surface
                )
            }
            .foregroundStyle(selected ? PrimaryColor.selected.selectedForeground : BeruColor.textPrimary)
            .overlay {
                if !selected {
                    Capsule().strokeBorder(
                        colorScheme == .dark ? BeruColor.Dark.border : BeruColor.Light.border,
                        lineWidth: 0.75
                    )
                }
            }
    }
}
