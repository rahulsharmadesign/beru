import SwiftUI

/// Groups sibling Liquid Glass controls so they share one rendering pass and
/// can blend instead of flooding as independent lenses. Lives in Design so
/// Panel never mentions `GlassEffectContainer` (the glass-on-glass guard).
struct BeruGlassContainer<Content: View>: View {
    var spacing: CGFloat = BeruSpace.xs
    var content: Content

    init(
        spacing: CGFloat = BeruSpace.xs,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        GlassEffectContainer(spacing: spacing) {
            content
        }
    }
}

/// How a panel control sits on the window slab. `.glass` is a second
/// refractive lens and muddies NSGlassEffectView — do not use it there.
enum BeruGlassKind {
    /// Filled accent control. Selected tab, Replace, Send when ready.
    case prominent
    /// No extra material. Idle tabs, menus, and icon actions on the slab.
    case plain
}

/// Native glass-prominent or plain button for the floating panel.
/// Settings keeps `BeruButton` (outlined / accent pills, no refraction).
struct BeruGlassButton: View {
    let title: String
    var prominent: Bool = false
    var size: BeruButton.Size = .compact
    var leadingIcon: String?
    var trailingIcon: String?
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        BeruGlassControl(
            kind: prominent ? .prominent : .plain,
            enabled: enabled,
            size: controlSize,
            action: action
        ) {
            HStack(spacing: BeruSpace.xxs) {
                if let leadingIcon {
                    BeruIcon(name: leadingIcon, size: iconSize)
                }
                Text(title)
                    .font(font)
                    .lineLimit(1)
                if let trailingIcon {
                    BeruIcon(name: trailingIcon, size: iconSize)
                }
            }
            .padding(.horizontal, BeruSpace.sm)
            .frame(height: height)
            .contentShape(Capsule())
        }
        .fixedSize()
        .frame(height: height)
        .clipShape(Capsule())
        .contentShape(Capsule())
    }

    private var controlSize: ControlSize {
        size == .compact ? .small : .regular
    }

    private var font: Font {
        size == .compact ? BeruType.footnote : BeruType.control
    }

    private var iconSize: CGFloat {
        size == .compact ? BeruMetrics.iconSizeCompact : BeruMetrics.iconSize
    }

    private var height: CGFloat {
        size == .compact ? BeruMetrics.pillHeightSm : BeruMetrics.pillHeight
    }
}

/// Verb chip: 12pt continuous corners on every side. Idle is outlined with
/// primary type; selected is a solid accent fill — never a second glass
/// lens on the slab, never a capsule, never a square.
/// Visual only: the panel wraps this in `PanelHitCapsule` so window-drag
/// cannot swallow the click.
struct BeruGlassChip: View {
    let title: String
    let icon: String
    var isSelected: Bool
    var isHovered: Bool = false

    private var chipShape: RoundedRectangle { BeruRadius.shape(BeruRadius.sm2) }

    var body: some View {
        BeruLabel(title: title, icon: icon, iconSize: BeruMetrics.iconSizeCompact, strokeWidth: 2)
            .labelStyle(.titleAndIcon)
            .font(BeruType.footnoteMedium)
            .foregroundStyle(isSelected ? BeruColor.onAccent : BeruColor.textPrimary)
            .padding(.horizontal, BeruSpace.sm)
            .frame(height: BeruMetrics.tabHeight)
            .background {
                chipShape.fill(isSelected ? BeruColor.accent : Color.clear)
            }
            .overlay {
                chipShape.strokeBorder(
                    isSelected ? Color.clear : BeruColor.strongBorder,
                    lineWidth: BeruMetrics.hairline
                )
            }
            .clipShape(chipShape)
            .contentShape(chipShape)
            .opacity(isSelected || isHovered ? 1 : 0.92)
            .beruTabSwitchEase(isSelected)
    }
}

/// Accent-gradient circle. Composer send — a fill, not a glass lens, so it
/// does not refract against the well or the window slab.
struct BeruFilledCircleButton: View {
    let icon: String
    var frameSize: CGFloat = BeruMetrics.sendButton
    var iconSize: CGFloat = BeruMetrics.iconSize
    var enabled: Bool = true
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(enabled ? AnyShapeStyle(BeruColor.accentGradient) : AnyShapeStyle(BeruColor.disabledFill))
                BeruIcon(name: icon, size: iconSize)
                    .foregroundStyle(enabled ? BeruColor.onAccent : BeruColor.textTertiary)
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

/// Circular icon. Copy / mic / votes stay plain so they do not stack a lens
/// on the slab or the composer well.
struct BeruGlassIconButton: View {
    let icon: String
    var size: CGFloat = BeruMetrics.iconSize
    var frameSize: CGFloat = BeruMetrics.roundButtonSm
    var prominent: Bool = false
    var enabled: Bool = true
    var tint: Color?
    var active: Bool = false
    let help: String
    let action: () -> Void

    var body: some View {
        BeruGlassControl(
            kind: prominent ? .prominent : .plain,
            circular: true,
            enabled: enabled,
            size: .small,
            action: action
        ) {
            BeruIcon(name: icon, size: size)
                .foregroundStyle(iconForeground)
                .frame(width: frameSize, height: frameSize)
                .contentShape(Circle())
        }
        .opacity(enabled ? 1 : 0.45)
        .help(help)
        .accessibilityLabel(help)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private var iconForeground: Color {
        if let tint { return tint }
        if active { return BeruColor.accent }
        if prominent { return BeruColor.onAccent }
        return BeruColor.textSecondary
    }
}

/// Shared panel button chrome. Panel hit targets wrap this with
/// `allowsHitTesting(false)` so window-drag does not swallow the click.
struct BeruGlassControl<Label: View>: View {
    var kind: BeruGlassKind = .plain
    var circular: Bool = false
    /// Slightly rounded rect instead of a capsule. Tabs use this so all
    /// four corners share `BeruRadius.sm`.
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
                .tint(BeruColor.accent)
        case .plain:
            button.buttonStyle(.plain)
        }
    }

    private var prominentShape: ButtonBorderShape {
        if circular { return .circle }
        if rounded { return .roundedRectangle(radius: BeruRadius.sm) }
        return .capsule
    }
}

extension View {
    /// Capsule glass for non-button chrome (token pill, toast).
    func beruGlassCapsule(interactive: Bool = false) -> some View {
        modifier(BeruGlassCapsule(interactive: interactive))
    }
}

private struct BeruGlassCapsule: ViewModifier {
    var interactive: Bool

    func body(content: Content) -> some View {
        if interactive {
            content.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            content.glassEffect(.regular, in: Capsule())
        }
    }
}
