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
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background {
                Capsule().fill(
                    selected
                        ? Color.clear
                        : colorScheme == .dark ? BrandColors.darkSurface : BrandColors.lightSurface
                )
            }
            .foregroundStyle(selected ? PrimaryColor.selected.selectedForeground : Color.primary)
            .overlay {
                if !selected {
                    Capsule().strokeBorder(
                        colorScheme == .dark ? BrandColors.darkBorder : BrandColors.lightBorder,
                        lineWidth: 0.75
                    )
                }
            }
    }
}
