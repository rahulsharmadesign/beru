import SwiftUI

extension View {
    /// Compact action chip on the panel glass slab. Selected chips tint;
    /// idle chips use regular glass. Reduce Transparency falls back to
    /// opaque capsules so 11pt labels stay readable.
    func glassChip(selected: Bool) -> some View {
        modifier(GlassChipModifier(selected: selected))
    }
}

private struct GlassChipModifier: ViewModifier {
    let selected: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let padded = content
            .padding(.horizontal, BeruSpace.xs)
            .padding(.vertical, BeruSpace.xs)

        if reduceTransparency {
            padded
                .background {
                    Capsule().fill(selected ? BeruColor.accent : BeruColor.surface)
                }
                .foregroundStyle(selected ? BeruColor.onAccent : BeruColor.textPrimary)
                .overlay {
                    if !selected {
                        Capsule().strokeBorder(BeruColor.border, lineWidth: 0.75)
                    }
                }
        } else {
            padded
                .foregroundStyle(selected ? BeruColor.onAccent : BeruColor.textPrimary)
                .glassEffect(
                    selected ? .regular : .clear,
                    in: Capsule()
                )
        }
    }
}
