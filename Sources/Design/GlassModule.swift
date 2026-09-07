import SwiftUI

/// Overlay language for modules sitting on the Haze panel plate.
///
/// Inner cards are fills and hairlines, not a second blur. Reduce Transparency
/// still paints a surface so text stays readable.
struct GlassModule: ViewModifier {
    var radius: CGFloat = BeruRadius.md
    var focusRing: Bool = false
    var scrim: ScrimWeight = .chrome
    /// When nil, wells and content draw a hairline.
    var bordered: Bool? = nil


    enum ScrimWeight {
        case base
        case chrome
        /// Result band: a light surface so markdown sits on a card, not the wash.
        case content
        /// Composer well: opaque plate, hairline, focus halo.
        case well
    }

    private var shape: RoundedRectangle {
        BeruRadius.shape(radius)
    }

    private var fill: Color {
        switch scrim {
        case .base, .chrome: return Color.clear
        case .content: return BeruColor.surface
        case .well: return BeruColor.panelSolid
        }
    }

    private var border: Color {
        BeruColor.border
    }

    private var showsBorder: Bool {
        if let bordered { return bordered }
        return scrim == .well || scrim == .content
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
                        .overlay { shape.strokeBorder(border, lineWidth: 1) }
                } else {
                    filled.clipShape(shape)
                }
            } else if showsBorder {
                filled.overlay { shape.strokeBorder(border, lineWidth: 1) }
            } else {
                filled
            }
        }
        .overlay(focusEdge)
        .animation(nil, value: focusRing)
        // Resting Haze e2 lift on the composer well only: contact shadow
        // plus soft lift. Render-only, never measured. Chrome and result
        // cards stay flat on the plate.
        .shadow(color: wellShadow(BeruColor.liftShadow), radius: BeruSpace.lg, y: BeruSpace.xs)
        .shadow(color: wellShadow(BeruColor.contactShadow), radius: BeruSpace.hair, y: 1)
    }

    /// Wells are the only modules that float. Anything else returns clear.
    private func wellShadow(_ color: Color) -> Color {
        scrim == .well ? color : .clear
    }

    private var liftOpacity: Double { 0.35 }
    private var contactOpacity: Double { 0.30 }

    @ViewBuilder
    private var focusEdge: some View {
        if focusRing {
            shape
                .strokeBorder(BeruColor.accent, lineWidth: 1)
                .shadow(color: BeruColor.focusGlow, radius: BeruMetrics.focusHalo)
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
