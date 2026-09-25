import SwiftUI

/// How a panel control sits on the window slab. `.glass` is a second
/// refractive lens and muddies NSGlassEffectView — do not use it there.
enum EnhancifyGlassKind {
    /// Filled accent control. Selected tab, Send when ready.
    case prominent
    /// No extra material. Idle tabs, menus, and icon actions on the slab.
    case plain
}

/// Native glass-prominent or plain button for the floating panel.
/// Settings keeps `EnhancifyButton` (outlined / accent pills, no refraction).
struct EnhancifyGlassButton: View {
    let title: String
    var prominent: Bool = false
    /// Outlined hairline pill in the same muted type as copy. Replace /
    /// Insert / Apply keep this look — never an accent fill.
    var secondary: Bool = false
    var size: EnhancifyButton.Size = .compact
    var leadingIcon: String?
    var trailingIcon: String?
    var enabled: Bool = true
    /// Hover helper pill. Empty skips it.
    var help: String = ""
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.enhancifyParentHovered) private var parentHovered

    private var hovered: Bool { enabled && (isHovered || parentHovered) }

    var body: some View {
        if secondary {
            Button(action: action) {
                labelStack
                    .foregroundStyle(EnhancifyColor.textSecondary)
                    .padding(.horizontal, EnhancifySpace.sm)
                    .frame(height: height)
                    .background {
                        Capsule()
                            .fill(hovered ? EnhancifyColor.hoverFill : Color.clear)
                            .overlay {
                                Capsule().strokeBorder(
                                    EnhancifyColor.strongBorder,
                                    lineWidth: EnhancifyMetrics.hairline
                                )
                            }
                    }
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
            .fixedSize()
            .frame(height: height)
            .clipShape(Capsule())
            .contentShape(Capsule())
            .opacity(enabled ? 1 : 0.45)
            .onHover { isHovered = $0 }
            .enhancifyHoverEase(hovered)
            .enhancifyHoverHelp(help, isVisible: hovered && !parentHovered)
            .accessibilityLabel(help.isEmpty ? title : help)
        } else {
            EnhancifyGlassControl(
                kind: prominent ? .prominent : .plain,
                enabled: enabled,
                size: controlSize,
                action: action
            ) {
                labelStack
                    .padding(.horizontal, EnhancifySpace.sm)
                    .frame(height: height)
                    .contentShape(Capsule())
            }
            .fixedSize()
            .frame(height: height)
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
    }

    private var labelStack: some View {
        HStack(spacing: EnhancifySpace.xxs) {
            if let leadingIcon {
                EnhancifyIcon(name: leadingIcon, size: iconSize)
            }
            Text(title)
                .font(font)
                .lineLimit(1)
            if let trailingIcon {
                EnhancifyIcon(name: trailingIcon, size: iconSize)
            }
        }
    }

    private var controlSize: ControlSize {
        size == .compact ? .small : .regular
    }

    private var font: Font {
        size == .compact ? EnhancifyType.footnote : EnhancifyType.control
    }

    private var iconSize: CGFloat {
        size == .compact ? EnhancifyMetrics.iconSizeCompact : EnhancifyMetrics.iconSize
    }

    private var height: CGFloat {
        size == .compact ? EnhancifyMetrics.pillHeightSm : EnhancifyMetrics.pillHeight
    }
}

/// Verb chip: 12pt continuous corners on every side. Idle is outlined with
/// primary type; selected is a solid accent fill — never a second glass
/// lens on the slab, never a capsule, never a square.
/// Visual only: the panel wraps this in `PanelHitCapsule` so window-drag
/// cannot swallow the click.
///
/// The accent fill is a shared `matchedGeometryEffect` highlight (Animate UI
/// `layoutId`). Type still cross-fades as two baked layers so it never
/// interpolates through muddy midtones.
struct EnhancifyGlassChip: View {
    let title: String
    let icon: String
    var isSelected: Bool
    var isHovered: Bool = false
    var highlightNamespace: Namespace.ID

    private var chipShape: RoundedRectangle { EnhancifyRadius.shape(EnhancifyRadius.sm2) }

    var body: some View {
        ZStack {
            // Neutral, like a macOS segmented control: the accent is kept for
            // the one thing that should pop (send), not for which tab is on.
            if isSelected {
                chipShape.fill(EnhancifyColor.hoverFill)
                    .matchedGeometryEffect(id: "tabHighlight", in: highlightNamespace)
            }

            chipLabel(EnhancifyColor.textSecondary)
                .compositingGroup()
                .opacity(isSelected ? 0 : 1)

            chipLabel(EnhancifyColor.textPrimary)
                .compositingGroup()
                .opacity(isSelected ? 1 : 0)
        }
        .frame(height: EnhancifyMetrics.tabHeight)
        .contentShape(chipShape)
        .opacity(isSelected || isHovered ? 1 : 0.92)
        .enhancifyTabSwitchEase(isSelected)
    }

    private func chipLabel(_ color: Color) -> some View {
        EnhancifyLabel(title: title, icon: icon, iconSize: EnhancifyMetrics.iconSizeCompact, strokeWidth: 2)
            .labelStyle(.titleAndIcon)
            .font(EnhancifyType.footnoteMedium)
            .foregroundStyle(color)
            .padding(.horizontal, EnhancifySpace.sm)
            .frame(height: EnhancifyMetrics.tabHeight)
    }
}

/// Accent-gradient circle. Composer send — a fill, not a glass lens, so it
/// does not refract against the well or the window slab.
struct EnhancifyFilledCircleButton: View {
    let icon: String
    var frameSize: CGFloat = EnhancifyMetrics.sendButton
    var iconSize: CGFloat = EnhancifyMetrics.iconSize
    var enabled: Bool = true
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(enabled ? AnyShapeStyle(EnhancifyColor.accentGradient) : AnyShapeStyle(EnhancifyColor.disabledFill))
                EnhancifyIcon(name: icon, size: iconSize)
                    .foregroundStyle(enabled ? EnhancifyColor.onAccent : EnhancifyColor.textTertiary)
            }
            .frame(width: frameSize, height: frameSize)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(help)
        .accessibilityLabel(help)
    }
}

/// Shared panel button chrome. Panel hit targets wrap this with
/// `allowsHitTesting(false)` so window-drag does not swallow the click.
struct EnhancifyGlassControl<Label: View>: View {
    var kind: EnhancifyGlassKind = .plain
    var circular: Bool = false
    /// Slightly rounded rect instead of a capsule. Tabs use this so all
    /// four corners share `EnhancifyRadius.sm`.
    var rounded: Bool = false
    var enabled: Bool = true
    var size: ControlSize = .small
    let action: () -> Void
    @ViewBuilder var label: () -> Label

    var body: some View {
        let button = Button(action: action, label: label)
            .controlSize(size)
            .disabled(!enabled)

        switch kind {
        case .prominent:
            button
                .buttonBorderShape(prominentShape)
                .buttonStyle(.glassProminent)
                .tint(EnhancifyColor.accent)
        case .plain:
            button.buttonStyle(.plain)
        }
    }

    private var prominentShape: ButtonBorderShape {
        if circular { return .circle }
        if rounded { return .roundedRectangle(radius: EnhancifyRadius.sm) }
        return .capsule
    }
}

extension View {
    /// Solid capsule on a glass slab (toast, token chip). Not a second lens.
    func enhancifyOverlayCapsule() -> some View {
        modifier(EnhancifyOverlayCapsule())
    }
}

private struct EnhancifyOverlayCapsule: ViewModifier {
    func body(content: Content) -> some View {
        content.background {
            Capsule()
                .fill(EnhancifyColor.panelSolid)
                .overlay {
                    Capsule().strokeBorder(EnhancifyColor.strongBorder, lineWidth: EnhancifyMetrics.hairline)
                }
        }
    }
}
