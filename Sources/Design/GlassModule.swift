import SwiftUI

/// Overlay language for modules sitting on a single glass slab.
///
/// Inner cards are not Liquid Glass — Apple forbids stacking glass on glass.
/// Chrome sits on the window material with no fill. Reduce Transparency still
/// paints a surface so text stays readable.
struct GlassModule: ViewModifier {
    var radius: CGFloat = BeruRadius.md
    var focusRing: Bool = false
    var scrim: ScrimWeight = .chrome
    /// When nil, only `.content` modules draw a border.
    var bordered: Bool? = nil

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    enum ScrimWeight {
        case base
        case chrome
        case content
    }

    private var shape: RoundedRectangle {
        BeruRadius.shape(radius)
    }

    private var fill: Color {
        reduceTransparency && scrim == .content ? BeruColor.surface : Color.clear
    }

    private var border: Color {
        switch scrim {
        case .base, .chrome: BeruColor.border
        case .content: BeruColor.border.opacity(0.78)
        }
    }

    private var showsBorder: Bool {
        if let bordered { return bordered }
        return scrim == .content
    }

    func body(content: Content) -> some View {
        // Chrome modules must not clipShape their content: a short card plus
        // an inner radius inside the window mask shears top/bottom padding.
        let filled = content.background { shape.fill(fill) }
        Group {
            if scrim == .content {
                if showsBorder {
                    filled
                        .clipShape(shape)
                        .overlay { shape.strokeBorder(border, lineWidth: 0.75) }
                } else {
                    filled.clipShape(shape)
                }
            } else if showsBorder {
                filled.overlay { shape.strokeBorder(border, lineWidth: 0.75) }
            } else {
                filled
            }
        }
        .overlay(focusEdge)
        .animation(nil, value: focusRing)
    }

    @ViewBuilder
    private var focusEdge: some View {
        if focusRing {
            shape.strokeBorder(BeruColor.accent, lineWidth: 1.5)
        }
    }
}

extension View {
    /// Makes the receiver an overlay module on a glass slab.
    func glassModule(
        radius: CGFloat = BeruRadius.md,
        focusRing: Bool = false,
        scrim: GlassModule.ScrimWeight = .chrome,
        bordered: Bool? = nil
    ) -> some View {
        modifier(GlassModule(radius: radius, focusRing: focusRing, scrim: scrim, bordered: bordered))
    }
}
