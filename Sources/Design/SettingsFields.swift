import SwiftUI

// Haze field wells for settings: 32pt pills, surface fill, hairline,
// focus glow. Plain `TextField` / `SecureField` stay out.

/// Haze field well: 32pt pill, surface fill, hairline, focus glow.
struct SettingsField: View {
    let placeholder: String
    @Binding var text: String
    var width: CGFloat = EnhancifyMetrics.fieldWidth
    var alignment: TextAlignment = .leading
    var leadingIcon: String? = nil
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: EnhancifySpace.xs) {
            if let leadingIcon {
                EnhancifyIcon(name: leadingIcon, size: EnhancifyMetrics.iconSize)
                    .foregroundStyle(EnhancifyColor.textSecondary)
            }
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(EnhancifyType.control)
                .multilineTextAlignment(alignment)
                .focused($focused)
        }
        .padding(.horizontal, EnhancifySpace.sm)
        .frame(width: width, height: EnhancifyMetrics.fieldHeight, alignment: .leading)
        .background {
            Capsule()
                .fill(EnhancifyColor.subtleFill)
                .overlay {
                    Capsule().strokeBorder(
                        focused ? EnhancifyColor.accent : EnhancifyColor.border,
                        lineWidth: EnhancifyMetrics.hairline
                    )
                }
                .shadow(color: focused ? EnhancifyColor.focusGlow : .clear, radius: EnhancifyMetrics.focusHalo)
        }
        .enhancifyFocusEase(focused)
        .onTapGesture { focused = true }
    }
}

/// Secret field with a Lucide visibility round. Same well as `SettingsField`.
struct SettingsSecretField: View {
    let placeholder: String
    @Binding var text: String
    var width: CGFloat = EnhancifyMetrics.fieldWidth
    @State private var visible = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: EnhancifySpace.xs) {
            Group {
                if visible {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .font(EnhancifyType.mono)
            .focused($focused)
            Button {
                visible.toggle()
            } label: {
                EnhancifyIcon(name: visible ? "visibility_off" : "visibility", size: EnhancifyMetrics.iconSize)
                    .foregroundStyle(EnhancifyColor.textSecondary)
            }
            .buttonStyle(.plain)
            .help(visible ? "Hide secret" : "Show secret")
            .accessibilityLabel(visible ? "Hide secret" : "Show secret")
        }
        .padding(.horizontal, EnhancifySpace.sm)
        .frame(width: width, height: EnhancifyMetrics.fieldHeight)
        .background {
            Capsule()
                .fill(EnhancifyColor.subtleFill)
                .overlay {
                    Capsule().strokeBorder(
                        focused ? EnhancifyColor.accent : EnhancifyColor.border,
                        lineWidth: EnhancifyMetrics.hairline
                    )
                }
                .shadow(color: focused ? EnhancifyColor.focusGlow : .clear, radius: EnhancifyMetrics.focusHalo)
        }
        .enhancifyFocusEase(focused)
    }
}
