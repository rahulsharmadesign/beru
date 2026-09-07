import SwiftUI

// Reusable dashboard buttons, toggles, and badges. Fields live in
// SettingsFields.swift, pickers and menus in SettingsPickers.swift.
// Native switch, checkbox, and bordered buttons stay out.

struct SettingsPillButton: View {
    let title: String
    var role: ButtonRole?
    var enabled: Bool = true
    var trailingIcon: String? = nil
    var leadingIcon: String? = nil
    let action: () -> Void

    var body: some View {
        BeruButton(
            title: title,
            variant: .pill,
            size: .regular,
            leadingIcon: leadingIcon,
            trailingIcon: trailingIcon,
            enabled: enabled,
            role: role,
            action: action
        )
    }
}

struct SettingsPrimaryButton: View {
    let title: String
    var icon: String? = nil
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        BeruButton(
            title: title,
            variant: .primary,
            size: .regular,
            leadingIcon: icon,
            enabled: enabled,
            action: action
        )
    }
}

/// Haze check: 18pt box, accent fill, Lucide check. Replaces `.checkbox`.
struct SettingsTogglePill: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: BeruSpace.xs) {
                ZStack {
                    BeruRadius.shape(BeruRadius.sm)
                        .fill(isOn ? AnyShapeStyle(BeruColor.accentGradient) : AnyShapeStyle(BeruColor.subtleFill))
                        .overlay {
                            if !isOn {
                                BeruRadius.shape(BeruRadius.sm)
                                    .strokeBorder(BeruColor.border, lineWidth: 1)
                            }
                        }
                    if isOn {
                        BeruIcon(name: "check", size: BeruMetrics.iconSizeDense)
                            .foregroundStyle(BeruColor.onAccent)
                    }
                }
                .frame(width: BeruSpace.md, height: BeruSpace.md)
                Text(title)
                    .font(BeruType.control)
                    .foregroundStyle(BeruColor.textPrimary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Haze round button: subtle-fill circle, hairline, Lucide glyph.
struct SettingsIconButton: View {
    let icon: String
    var size: CGFloat = BeruMetrics.iconSize
    var frameSize: CGFloat = BeruMetrics.hitTarget
    var enabled: Bool = true
    let help: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(isHovered && enabled ? BeruColor.hoverFill : BeruColor.subtleFill)
                Circle().strokeBorder(BeruColor.border, lineWidth: 1)
                BeruIcon(name: icon, size: size)
                    .foregroundStyle(BeruColor.textPrimary)
            }
            .frame(width: frameSize, height: frameSize)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .fixedSize()
        .opacity(enabled ? 1 : 0.45)
        .help(help)
        .accessibilityLabel(help)
        .onHover { isHovered = $0 }
.beruHoverEase(isHovered)
    }
}

struct SettingsInlineButton: View {
    let title: String
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        BeruButton(title: title, variant: .inline, size: .regular, role: role, action: action)
    }
}

struct SettingsValue: View {
    let text: String
    var mono: Bool = false

    var body: some View {
        Text(text)
            .font(mono ? BeruType.mono : BeruType.control)
            .foregroundStyle(BeruColor.textSecondary)
            .multilineTextAlignment(.trailing)
            .textSelection(.enabled)
    }
}

/// Granted / Needed (or Unavailable) on a settings row. Haze metapill:
/// surface fill, hairline, status-colored text.
struct SettingsStatusBadge: View {
    let title: String
    var isPositive: Bool = false

    var body: some View {
        Text(title)
            .font(BeruType.captionMedium)
            .foregroundStyle(isPositive ? BeruColor.positive : BeruColor.textSecondary)
            .padding(.horizontal, BeruSpace.xs)
            .padding(.vertical, BeruSpace.xxs)
            .background {
                BeruRadius.shape(BeruRadius.sm)
                    .fill(BeruColor.badge)
                    .overlay {
                        BeruRadius.shape(BeruRadius.sm)
                            .strokeBorder(BeruColor.border, lineWidth: 1)
                    }
            }
            .accessibilityLabel(title)
    }
}

/// Haze toggle: 40×24 track, 18pt thumb, accent gradient when on.
/// Replaces `.switch`.
struct SettingsSwitch: View {
    @Binding var isOn: Bool
    var accessibilityLabel: String = "Toggle"

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? AnyShapeStyle(BeruColor.accentGradient) : AnyShapeStyle(BeruColor.subtleFill))
                    .overlay {
                        if !isOn {
                            Capsule().strokeBorder(BeruColor.border, lineWidth: 1)
                        }
                    }
                Circle()
                    .fill(isOn ? BeruColor.onAccent : BeruColor.panelSolid)
                    .frame(width: BeruMetrics.toggleThumb, height: BeruMetrics.toggleThumb)
                    // (24pt track − 18pt thumb) / 2.
                    .padding(3)
            }
            .frame(width: BeruMetrics.toggleWidth, height: BeruMetrics.toggleHeight)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isOn)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
