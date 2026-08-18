import AppKit
import SwiftUI

/// Semantic tokens shared by every dashboard surface.
///
/// Window and sidebar fills come from frozen BrandColors canvas/surface tokens.
enum SettingsTheme {
    static var window: Color { BrandColors.canvas }
    static var sidebar: Color { BrandColors.surface }
    static var surface: Color { BrandColors.surface }
    static var border: Color { BrandColors.border }
    static var textPrimary: Color { Color(nsColor: .labelColor) }
    static var textSecondary: Color { Color(nsColor: .secondaryLabelColor) }
    @MainActor
    static var active: Color { BrandColors.accentColor }
    static var onActive: Color { PrimaryColor.indigo.selectedForeground }
    static var badgeBg: Color { Color(nsColor: .unemphasizedSelectedContentBackgroundColor) }
    static var sidebarSelected: Color { Color(nsColor: .unemphasizedSelectedContentBackgroundColor) }
    static var hoverFill: Color { Color(nsColor: .quaternaryLabelColor) }
    static var inputBg: Color { BrandColors.input }
    static var destructive: Color { Color(nsColor: .systemRed) }
    static var positive: Color { Color(nsColor: .systemGreen) }
}

enum SettingsChrome {
    static let windowWidth: CGFloat = 1180
    static let windowHeight: CGFloat = 720
    static let sidebarWidth: CGFloat = 240
    static let workspaceListMaxWidth: CGFloat = 280
    static let contentPadding: CGFloat = 32
    static let headerContentSpacing: CGFloat = 16
    static let workspaceListInset: CGFloat = 16
    static let rowRadius: CGFloat = 10
    static let fieldWidth: CGFloat = 200
    static let labelMaxWidth: CGFloat = 560
}

struct SettingsHeaderRule: View {
    var body: some View {
        Rectangle()
            .fill(SettingsTheme.border)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}

struct SettingsVRule: View {
    var body: some View {
        Rectangle()
            .fill(SettingsTheme.border)
            .frame(width: 1)
            .frame(maxHeight: .infinity)
    }
}

/// Fixed sidebar + flexible detail. `HSplitView` collapses the detail pane on
/// macOS when a child also asks for `maxWidth`.
struct SettingsSplitView<Sidebar: View, Detail: View>: View {
    var sidebarWidth: CGFloat = SettingsChrome.workspaceListMaxWidth
    @ViewBuilder var sidebar: Sidebar
    @ViewBuilder var detail: Detail

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: sidebarWidth)
                .frame(maxHeight: .infinity)
            SettingsVRule()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SettingsTheme.window)
    }
}

struct SettingsPage<Content: View>: View {
    let title: String
    var content: Content

    init(title: String, subtitle _: String = "", @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsChrome.headerContentSpacing) {
                SettingsPageHeader(title: title)
                SettingsHeaderRule()
                content
            }
            .padding(.horizontal, SettingsChrome.contentPadding)
            .padding(.top, 28)
            .padding(.bottom, 48)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SettingsTheme.window)
    }
}

struct SettingsWorkspace<Content: View>: View {
    let title: String
    var content: Content

    init(title: String, subtitle _: String = "", @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsChrome.headerContentSpacing) {
            VStack(alignment: .leading, spacing: SettingsChrome.headerContentSpacing) {
                SettingsPageHeader(title: title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SettingsHeaderRule()
            }
            .padding(.horizontal, SettingsChrome.contentPadding)
            .padding(.top, 28)
            .padding(.bottom, 0)
            .fixedSize(horizontal: false, vertical: true)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SettingsTheme.window)
    }
}

struct SettingsPageHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(BeruSans.pageTitle)
            .foregroundStyle(SettingsTheme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    var content: Content

    init(title: String, subtitle _: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(BeruSans.section)
                .foregroundStyle(SettingsTheme.textPrimary)
            VStack(alignment: .leading, spacing: 18) {
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsFootnote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(BeruSans.footnote)
            .foregroundStyle(SettingsTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct SettingsRow<Control: View>: View {
    let title: String
    var caption: String?
    @ViewBuilder var control: Control

    var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontalLayout
            verticalLayout
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var labels: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(BeruSans.rowTitle)
                .foregroundStyle(SettingsTheme.textPrimary)
            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(BeruSans.rowCaption)
                    .foregroundStyle(SettingsTheme.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var horizontalLayout: some View {
        HStack(alignment: .top, spacing: 24) {
            labels
            .frame(minWidth: 0, maxWidth: SettingsChrome.labelMaxWidth, alignment: .leading)
            Spacer(minLength: 12)
            control
                .padding(.top, 2)
                .layoutPriority(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var verticalLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            labels
            control
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

struct SettingsPillButton: View {
    let title: String
    var role: ButtonRole?
    var enabled: Bool = true
    var trailingIcon: String? = nil
    var leadingIcon: String? = nil
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 6) {
                if let leadingIcon {
                    BeruIcon(name: leadingIcon, size: 14)
                }
                Text(title)
                    .font(BeruSans.control)
                    .lineLimit(1)
                if let trailingIcon {
                    BeruIcon(name: trailingIcon, size: 14)
                }
            }
            .foregroundStyle(SettingsTheme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background {
                Capsule()
                    .fill(isHovered && enabled ? SettingsTheme.hoverFill : Color.clear)
                    .overlay(Capsule().strokeBorder(SettingsTheme.border, lineWidth: 1))
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .fixedSize()
        .opacity(enabled ? 1 : 0.45)
        .onHover { isHovered = $0 }
    }
}

struct SettingsPrimaryButton: View {
    let title: String
    var icon: String? = nil
    var enabled: Bool = true
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    BeruIcon(name: icon, size: 14)
                }
                Text(title)
                    .font(BeruSans.control)
                    .lineLimit(1)
            }
            .foregroundStyle(SettingsTheme.onActive)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background {
                Capsule()
                    .fill(
                        enabled
                            ? (isHovered ? SettingsTheme.active.opacity(0.88) : SettingsTheme.active)
                            : SettingsTheme.active.opacity(0.45)
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .fixedSize()
        .onHover { isHovered = $0 }
    }
}

struct SettingsTogglePill: View {
    let title: String
    var icon: String? = nil
    @Binding var isOn: Bool

    @State private var isHovered = false

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: 6) {
                if let icon {
                    BeruIcon(name: icon, size: 14)
                }
                Text(title)
                    .font(BeruSans.control)
                    .lineLimit(1)
            }
            .foregroundStyle(isOn ? SettingsTheme.onActive : SettingsTheme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background {
                Capsule()
                    .fill(
                        isOn
                            ? SettingsTheme.active
                            : (isHovered ? SettingsTheme.hoverFill : Color.clear)
                    )
                    .overlay {
                        if !isOn {
                            Capsule().strokeBorder(SettingsTheme.border, lineWidth: 1)
                        }
                    }
            }
        }
        .buttonStyle(.plain)
        .fixedSize()
        .onHover { isHovered = $0 }
    }
}

struct SettingsIconButton: View {
    let icon: String
    var size: CGFloat = 16
    /// Tap-target frame. Smaller for icon buttons living inside a compact
    /// row (e.g. a card in a narrow list) rather than a toolbar/footer.
    var frameSize: CGFloat = 28
    var enabled: Bool = true
    /// Hover tooltip and VoiceOver name. Required so an icon-only control
    /// never ships without a description of what it does.
    let help: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            BeruIcon(name: icon, size: size)
                .foregroundStyle(SettingsTheme.textPrimary)
                .frame(width: frameSize, height: frameSize)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isHovered && enabled ? SettingsTheme.hoverFill : Color.clear)
                }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .fixedSize()
        .opacity(enabled ? 1 : 0.45)
        .help(help)
        .accessibilityLabel(help)
        .onHover { isHovered = $0 }
    }
}

/// Small text-only button for actions packed into a tight row (e.g. a card
/// footer), where a full `SettingsPillButton` would be too heavy.
struct SettingsInlineButton: View {
    let title: String
    var role: ButtonRole?
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(role: role, action: action) {
            Text(title)
                .font(BeruSans.footnote)
                .foregroundStyle(role == .destructive ? SettingsTheme.destructive : SettingsTheme.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isHovered ? SettingsTheme.hoverFill : Color.clear)
                }
        }
        .buttonStyle(.plain)
        .fixedSize()
        .onHover { isHovered = $0 }
    }
}

struct SettingsWorkspaceToolbar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                toolbarContent
                ScrollView(.horizontal, showsIndicators: false) {
                    toolbarContent
                }
            }
            .padding(.horizontal, SettingsChrome.contentPadding)
            .padding(.bottom, 10)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            SettingsHeaderRule()
        }
        .background(SettingsTheme.window)
    }

    private var toolbarContent: some View {
        HStack(alignment: .center, spacing: 10) {
            content
        }
    }
}

struct SettingsListFooter<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            SettingsHeaderRule()
            HStack(spacing: 8) {
                content
                Spacer(minLength: 0)
            }
            .buttonStyle(.plain)
            .foregroundStyle(SettingsTheme.textPrimary)
            .padding(.horizontal, SettingsChrome.contentPadding)
            .padding(.vertical, 8)
            .fixedSize(horizontal: false, vertical: true)
            .background(DashboardChrome.sidebarSurface)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct SettingsValue: View {
    let text: String
    var mono: Bool = false

    var body: some View {
        Text(text)
            .font(mono ? BeruSans.mono : BeruSans.control)
            .foregroundStyle(SettingsTheme.textSecondary)
            .multilineTextAlignment(.trailing)
    }
}

struct SettingsField: View {
    let placeholder: String
    @Binding var text: String
    var width: CGFloat = SettingsChrome.fieldWidth
    var alignment: TextAlignment = .leading

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(BeruSans.control)
            .foregroundStyle(SettingsTheme.textPrimary)
            .multilineTextAlignment(alignment)
            .frame(width: width)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background {
                Capsule()
                    .fill(SettingsTheme.inputBg)
                    .overlay(Capsule().strokeBorder(SettingsTheme.border, lineWidth: 1))
            }
    }
}

struct SettingsSecretField: View {
    let placeholder: String
    @Binding var text: String
    var width: CGFloat = SettingsChrome.fieldWidth
    @State private var visible = false

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if visible {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .font(BeruSans.mono)
            .foregroundStyle(SettingsTheme.textSecondary)
            Button {
                visible.toggle()
            } label: {
                BeruIcon(name: visible ? "visibility_off" : "visibility", size: 15)
                    .foregroundStyle(SettingsTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .help(visible ? "Hide" : "Show")
            .accessibilityLabel(visible ? "Hide secret" : "Show secret")
        }
        .frame(width: width)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background {
            Capsule()
                .fill(SettingsTheme.inputBg)
                .overlay(Capsule().strokeBorder(SettingsTheme.border, lineWidth: 1))
        }
    }
}

/// Custom toggle matching SettingsScreen.jsx (42×24, #635BFF active).
struct SettingsSwitch: View {
    @Binding var isOn: Bool
    var accessibilityLabel: String = "Toggle"

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? SettingsTheme.active : SettingsTheme.border)
                    .frame(width: 42, height: 24)
                Circle()
                    .fill(SettingsTheme.onActive)
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)
                    .padding(3)
            }
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isOn)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

struct SettingsSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search settings..."

    var body: some View {
        HStack(spacing: 8) {
            BeruIcon(name: "search", size: 16)
                .foregroundStyle(SettingsTheme.textSecondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(BeruSans.search)
                .foregroundStyle(SettingsTheme.textPrimary)
                .lineLimit(1)
                .frame(minWidth: 0, maxWidth: .infinity)
                .layoutPriority(1)
        }
        .padding(.horizontal, SettingsChrome.workspaceListInset)
        .padding(.vertical, 10)
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .background {
            Capsule()
                .strokeBorder(SettingsTheme.border, lineWidth: 1)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel(placeholder)
    }
}

struct SettingsMenuPill<Selection: Hashable, Content: View>: View {
    @Binding var selection: Selection
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        Menu {
            content
        } label: {
            HStack(spacing: 6) {
                Text(label)
                    .font(BeruSans.control)
                BeruIcon(name: "expand_more", size: 14)
            }
            .foregroundStyle(SettingsTheme.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background {
                Capsule()
                    .strokeBorder(SettingsTheme.border, lineWidth: 1)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

extension View {
    func settingsWorkspacePane() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(SettingsTheme.window)
    }

    func settingsSidebarList() -> some View {
        listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .contentMargins(.horizontal, SettingsChrome.workspaceListInset, for: .scrollContent)
            .background(SettingsTheme.window)
    }

    /// Inset list-row highlight so selection pills do not touch column edges.
    func settingsListRowBackground(isHighlighted: Bool, fill: some ShapeStyle = SettingsTheme.active) -> some View {
        listRowBackground(
            RoundedRectangle(cornerRadius: SettingsChrome.rowRadius, style: .continuous)
                .fill(isHighlighted ? AnyShapeStyle(fill) : AnyShapeStyle(Color.clear))
                .padding(.horizontal, SettingsChrome.workspaceListInset)
        )
    }

    func settingsEditorSurface() -> some View {
        padding(10)
            .background {
                RoundedRectangle(cornerRadius: SettingsChrome.rowRadius, style: .continuous)
                    .fill(SettingsTheme.inputBg)
                    .overlay {
                        RoundedRectangle(cornerRadius: SettingsChrome.rowRadius, style: .continuous)
                            .strokeBorder(SettingsTheme.border, lineWidth: 1)
                    }
            }
    }
}
