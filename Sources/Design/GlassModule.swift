import SwiftUI

/// Overlay language for modules sitting on the Haze panel plate.
///
/// Inner cards are fills and hairlines, not a second blur. Reduce Transparency
/// still paints a surface so text stays readable.
struct GlassModule: ViewModifier {
    var radius: CGFloat = EnhancifyRadius.md
    var focusRing: Bool = false
    var scrim: ScrimWeight = .chrome
    /// When nil, content draws a hairline. Wells always get a light hairline
    /// so the composer reads as its own surface on the slab.
    var bordered: Bool? = nil
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency


    enum ScrimWeight {
        case base
        case chrome
        /// Result band: a light surface so markdown sits on a card, not the wash.
        case content
        /// Composer well: appearance-matched wash plus a light hairline.
        /// Not Liquid Glass — `NSGlassEffectView` has no opacity control.
        case well
    }

    private var shape: RoundedRectangle {
        EnhancifyRadius.shape(radius)
    }

    private var fill: Color {
        switch scrim {
        case .base, .chrome, .well: return Color.clear
        case .content: return EnhancifyColor.surface
        }
    }

    private var wellFill: Color {
        reduceTransparency ? EnhancifyColor.panelSolid : EnhancifyColor.composerWell
    }

    private var border: Color {
        EnhancifyColor.border
    }

    private var showsBorder: Bool {
        if scrim == .well { return true }
        if let bordered { return bordered }
        return scrim == .content
    }

    func body(content: Content) -> some View {
        // Chrome modules must not clipShape their content: a short card plus
        // an inner radius inside the window mask shears top/bottom padding.
        Group {
            if scrim == .well {
                content
                    .frame(maxWidth: .infinity)
                    .background {
                        shape.fill(wellFill)
                    }
                    .clipShape(shape)
                    .overlay {
                        shape.strokeBorder(EnhancifyColor.border, lineWidth: EnhancifyMetrics.hairline)
                    }
            } else {
                filledChrome(content)
            }
        }
        .overlay(focusEdge)
        .animation(nil, value: focusRing)
        // Resting Haze e2 lift on the composer well only: contact shadow
        // plus soft lift. Render-only, never measured. Chrome and result
        // cards stay flat on the plate.
        .shadow(color: wellShadow(EnhancifyColor.liftShadow), radius: EnhancifySpace.lg, y: EnhancifySpace.xs)
        .shadow(color: wellShadow(EnhancifyColor.contactShadow), radius: EnhancifySpace.hair, y: 1)
    }

    /// Wells are the only modules that float. Anything else returns clear.
    private func wellShadow(_ color: Color) -> Color {
        // Fill-only well: a 10% wash has no refraction to lift against.
        .clear
    }

    private var liftOpacity: Double { 0.35 }
    private var contactOpacity: Double { 0.30 }

    private func filledChrome(_ content: Content) -> some View {
        let filled = content.background { shape.fill(fill) }
        return Group {
            if scrim == .content {
                if showsBorder {
                    filled
                        .clipShape(shape)
                        .overlay { shape.strokeBorder(border, lineWidth: EnhancifyMetrics.hairline) }
                } else {
                    filled.clipShape(shape)
                }
            } else if showsBorder {
                filled.overlay { shape.strokeBorder(border, lineWidth: EnhancifyMetrics.hairline) }
            } else {
                filled
            }
        }
    }

    @ViewBuilder
    private var focusEdge: some View {
        if focusRing {
            shape
                .strokeBorder(EnhancifyColor.accent, lineWidth: EnhancifyMetrics.hairline)
                .shadow(color: EnhancifyColor.focusGlow, radius: EnhancifyMetrics.focusHalo)
        }
    }
}

extension View {
    /// Makes the receiver an overlay module on a glass slab.
    func glassModule(
        radius: CGFloat = EnhancifyRadius.md,
        focusRing: Bool = false,
        scrim: GlassModule.ScrimWeight = .chrome,
        bordered: Bool? = nil
    ) -> some View {
        modifier(GlassModule(radius: radius, focusRing: focusRing, scrim: scrim, bordered: bordered))
    }
}
