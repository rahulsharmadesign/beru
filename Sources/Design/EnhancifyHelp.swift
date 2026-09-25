import SwiftUI

/// Hover helper in the ChatGPT "Copy response" shape: a solid capsule
/// parked above the control. Not a glass lens, not a native tooltip.
struct EnhancifyHelpPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(EnhancifyType.captionMedium)
            .foregroundStyle(EnhancifyColor.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, EnhancifySpace.xs)
            .frame(height: EnhancifyMetrics.metapillHeight)
            .background {
                Capsule()
                    .fill(EnhancifyColor.panelSolid)
                    .overlay {
                        Capsule().strokeBorder(
                            EnhancifyColor.strongBorder,
                            lineWidth: EnhancifyMetrics.hairline
                        )
                    }
                    .shadow(
                        color: EnhancifyColor.liftShadow,
                        radius: EnhancifySpace.xs,
                        y: EnhancifySpace.hair
                    )
            }
            .fixedSize()
            .allowsHitTesting(false)
    }
}

/// Which way a hover helper pill grows out of its control.
///
/// Centered is the default. A centered pill is wider than the control it
/// describes, so half of the difference hangs past the control's leading
/// edge. For a control parked on the panel's leading inset that lands outside
/// the window, and the clipping hosting view shears the cap off — which is
/// what the Replace footer action did. Controls on an edge opt into
/// `.leading` / `.trailing` so the pill grows inward instead.
enum EnhancifyHelpAnchor {
    case center
    case leading
    case trailing

    var overlayAlignment: Alignment {
        switch self {
        case .center: return .top
        case .leading: return .topLeading
        case .trailing: return .topTrailing
        }
    }
}

private struct EnhancifyHoverHelp: ViewModifier {
    let text: String
    let isVisible: Bool
    var anchor: EnhancifyHelpAnchor = .center

    func body(content: Content) -> some View {
        content
            .overlay(alignment: anchor.overlayAlignment) {
                EnhancifyHelpPill(text: text)
                    .offset(y: -EnhancifyMetrics.helpPillOffset)
                    .opacity(isVisible && !text.isEmpty ? 1 : 0)
            }
    }
}

extension View {
    /// Paints `EnhancifyHelpPill` above this view while `isVisible`. Does not
    /// change layout height. Pass `anchor` for a control on a window edge.
    func enhancifyHoverHelp(
        _ text: String,
        isVisible: Bool,
        anchor: EnhancifyHelpAnchor = .center
    ) -> some View {
        modifier(EnhancifyHoverHelp(text: text, isVisible: isVisible, anchor: anchor))
    }

    @ViewBuilder
    func enhancifyNativeHelp(_ text: String, enabled: Bool) -> some View {
        if enabled {
            self.help(text)
        } else {
            self
        }
    }
}
