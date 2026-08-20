import SwiftUI

// A `panelFrosting` environment key used to sit here, fed from a persisted
// setting and injected by PanelView on every invocation. Nothing below ever
// read it — the plain-white skin replaced the gradient it controlled — and no
// UI had set it since. The whole chain is gone.

/// A neutral white surface used by the floating composer.
///
/// The existing scrim hierarchy is retained, but it now changes only border
/// weight and elevation. No blur, gradient, or translucent glass remains.
struct GlassModule: ViewModifier {
    var radius: CGFloat = PanelMetrics.moduleRadius
    var focusRing: Bool = false
    var scrim: ScrimWeight = .chrome

    enum ScrimWeight {
        case base
        case chrome
        case content
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: radius,
            style: .circular
        )
    }

    private var border: Color {
        switch scrim {
        case .base: return BeruColor.border
        case .chrome: return BeruColor.border
        case .content: return BeruColor.border.opacity(0.78)
        }
    }

    private var shadow: Color {
        switch scrim {
        case .base: return .clear
        case .chrome: return Color.black.opacity(0.035)
        case .content: return .clear
        }
    }

    func body(content: Content) -> some View {
        // Chrome modules must not clipShape their content: a short card plus
        // an inner radius inside the window mask shears top/bottom padding.
        // The fill is already a rounded rect; only the result surface clips.
        let filled = content.background { shape.fill(BeruColor.surface) }
        Group {
            if scrim == .content {
                filled.clipShape(shape)
            } else {
                filled
            }
        }
        .overlay(shape.strokeBorder(border, lineWidth: 0.75))
        .overlay(focusEdge)
        .shadow(color: shadow, radius: scrim == .base ? 22 : 10, y: scrim == .base ? 8 : 3)
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
    /// Makes the receiver a white, softly elevated card module.
    func glassModule(
        radius: CGFloat = PanelMetrics.moduleRadius,
        focusRing: Bool = false,
        scrim: GlassModule.ScrimWeight = .chrome
    ) -> some View {
        modifier(GlassModule(radius: radius, focusRing: focusRing, scrim: scrim))
    }
}
