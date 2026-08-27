import SwiftUI

/// Chrome sitting on a window-level Liquid Glass slab. Inner modules are not
/// themselves glass — Apple forbids stacking glass on glass. Reduce
/// Transparency paints an opaque canvas so type stays readable.
struct GlassSlabBackground: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content.background(reduceTransparency ? BeruColor.canvas : Color.clear)
    }
}

/// Selected-row overlay on a glass slab. Not a second `glassEffect`.
struct GlassSelectedFill: View {
    var isSelected: Bool
    var radius: CGFloat = BeruRadius.md

    var body: some View {
        if isSelected {
            BeruRadius.shape(radius).fill(BeruColor.selectedRow)
        } else {
            Color.clear
        }
    }
}

extension View {
    /// Overlay chrome on the window glass slab. Not a second glass card.
    func glassSlabBackground() -> some View {
        modifier(GlassSlabBackground())
    }
}
