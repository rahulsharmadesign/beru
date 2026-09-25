import SwiftUI

// Reusable dashboard buttons, toggles, and badges. Fields live in
// SettingsFields.swift, pickers and menus in SettingsPickers.swift.
// The on/off switch is Apple's own: a native `Toggle` renders the Liquid
// Glass switch on Tahoe and later, including Reduce Transparency handling.

struct SettingsPillButton: View {
    let title: String
    var role: ButtonRole?
    var enabled: Bool = true
    var trailingIcon: String? = nil
    var leadingIcon: String? = nil
    let action: () -> Void

    var body: some View {
        EnhancifyButton(
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
        EnhancifyButton(
            title: title,
            variant: .primary,
            size: .regular,
            leadingIcon: icon,
            enabled: enabled,
            action: action
        )
    }
}

/// Haze round button: outlined circle, hairline, Lucide glyph. Hover fills.
struct SettingsIconButton: View {
    let icon: String
    var size: CGFloat = EnhancifyMetrics.iconSize
    var frameSize: CGFloat = EnhancifyMetrics.hitTarget
    var enabled: Bool = true
    let help: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(isHovered && enabled ? EnhancifyColor.hoverFill : Color.clear)
                Circle().strokeBorder(EnhancifyColor.strongBorder, lineWidth: EnhancifyMetrics.hairline)
                EnhancifyIcon(name: icon, size: size)
                    .foregroundStyle(EnhancifyColor.textPrimary)
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
        .enhancifyHoverEase(isHovered)
    }
}

struct SettingsValue: View {
    let text: String
    var mono: Bool = false

    var body: some View {
        Text(text)
            .font(mono ? EnhancifyType.mono : EnhancifyType.control)
            .foregroundStyle(EnhancifyColor.textSecondary)
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
            .font(EnhancifyType.captionMedium)
            .foregroundStyle(isPositive ? EnhancifyColor.positive : EnhancifyColor.textSecondary)
            .padding(.horizontal, EnhancifySpace.xs)
            .padding(.vertical, EnhancifySpace.xxs)
            .background {
                EnhancifyRadius.shape(EnhancifyRadius.sm)
                    .fill(EnhancifyColor.badge)
                    .overlay {
                        EnhancifyRadius.shape(EnhancifyRadius.sm)
                            .strokeBorder(EnhancifyColor.border, lineWidth: EnhancifyMetrics.hairline)
                    }
            }
            .accessibilityLabel(title)
    }
}

/// Apple switch. A native `Toggle` renders the Liquid Glass control on
/// Tahoe and later (tinted with the Enhancify accent when on) and adapts to
/// Reduce Transparency and Increase Contrast on its own.
struct SettingsSwitch: View {
    @Binding var isOn: Bool
    var accessibilityLabel: String = "Toggle"

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(accessibilityLabel)
        }
        .toggleStyle(.switch)
        .labelsHidden()
        .tint(EnhancifyColor.accent)
        .accessibilityLabel(accessibilityLabel)
    }
}
