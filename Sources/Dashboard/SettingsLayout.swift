import SwiftUI

// Page scaffolding for the dashboard: the shells every route builds inside.
// The reusable controls these pages fill themselves with live in
// Sources/Design/SettingsControls.swift.

struct SettingsHeaderRule: View {
    var body: some View {
        Rectangle()
            .fill(BeruColor.border)
            .frame(height: BeruMetrics.hairline)
            .frame(maxWidth: .infinity)
    }
}

struct SettingsVRule: View {
    var body: some View {
        Rectangle()
            .fill(BeruColor.border)
            .frame(width: BeruMetrics.hairline)
            .frame(maxHeight: .infinity)
    }
}

/// Fixed sidebar + flexible detail. `HSplitView` collapses the detail pane on
/// macOS when a child also asks for `maxWidth`.
struct SettingsSplitView<Sidebar: View, Detail: View>: View {
    var sidebarWidth: CGFloat = BeruMetrics.workspaceListWidth
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
    }
}

struct SettingsPage<Content: View>: View {
    let title: String
    let subtitle: String
    var icon: String?
    var content: Content

    init(title: String, subtitle: String = "", icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: BeruMetrics.headerContentSpacing) {
                SettingsPageHeader(title: title, subtitle: subtitle, icon: icon)
                SettingsHeaderRule()
            }
            .padding(.bottom, BeruMetrics.headerContentSpacing)
            .fixedSize(horizontal: false, vertical: true)
            ScrollView {
                // Explicit stack: a bare ViewBuilder lays sections out with
                // zero gap, so wells would touch edge to edge.
                VStack(alignment: .leading, spacing: BeruSpace.xl) {
                    content
                }
                .padding(.top, BeruMetrics.headerContentSpacing)
                .padding(.bottom, BeruSpace.xxl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollContentBackground(.hidden)
            .scrollEdgeEffectStyle(.none, for: .vertical)
        }
        // One readable column, centered in the detail pane. Without the cap a
        // 1180pt window stretches every row to full bleed.
        .frame(maxWidth: BeruMetrics.formMaxWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, BeruMetrics.contentPadding)
        .padding(.top, BeruSpace.xl)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

struct SettingsWorkspace<Content: View>: View {
    let title: String
    let subtitle: String
    var icon: String?
    var content: Content

    init(
        title: String,
        subtitle: String = "",
        icon: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsPageHeader(title: title, subtitle: subtitle, icon: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, BeruMetrics.workspaceChromeInset)
                .padding(.top, BeruSpace.xl)
                .padding(.bottom, BeruMetrics.headerContentSpacing)
            SettingsHeaderRule()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct SettingsPageHeader: View {
    let title: String
    var subtitle: String = ""
    var icon: String? = nil

    var body: some View {
        HStack(alignment: .center, spacing: BeruSpace.md) {
            if let icon {
                // Same 28pt tile the sidebar rows paint, in accent, so the
                // page announces its route before its title.
                ZStack {
                    BeruRadius.shape(BeruRadius.sm)
                        .fill(BeruColor.subtleFill)
                        .overlay {
                            BeruRadius.shape(BeruRadius.sm)
                                .strokeBorder(BeruColor.border, lineWidth: BeruMetrics.hairline)
                        }
                    BeruIcon(name: icon, size: BeruMetrics.iconSize)
                        .foregroundStyle(BeruColor.accent)
                }
                .frame(width: BeruMetrics.hitTarget, height: BeruMetrics.hitTarget)
            }
            VStack(alignment: .leading, spacing: BeruSpace.xxs) {
                Text(title)
                    .font(BeruType.pageTitle)
                    .foregroundStyle(BeruColor.textPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(BeruType.pageSubtitle)
                        .foregroundStyle(BeruColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// How a section's well is painted. Danger groups keep the section geometry
/// but swap the Haze fill for the destructive wash.
enum SettingsSectionTone {
    case module
    case danger
}

struct SettingsSection<Content: View>: View {
    let title: String
    let subtitle: String?
    var tone: SettingsSectionTone
    var content: Content

    init(
        title: String,
        subtitle: String? = nil,
        tone: SettingsSectionTone = .module,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BeruSpace.sm) {
            VStack(alignment: .leading, spacing: BeruSpace.xxs) {
                Text(title)
                    .font(BeruType.section)
                    .foregroundStyle(BeruColor.textPrimary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(BeruType.footnote)
                        .foregroundStyle(BeruColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            // Grouped rows sit in a Haze well so every page — form pages and
            // workspace inspectors alike — reads as one card language.
            VStack(alignment: .leading, spacing: BeruSpace.md) {
                content
            }
            .padding(.horizontal, BeruSpace.md)
            .padding(.vertical, BeruSpace.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(SectionWell(tone: tone))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SectionWell: ViewModifier {
    let tone: SettingsSectionTone

    func body(content: Content) -> some View {
        switch tone {
        case .module:
            content.settingsModule()
        case .danger:
            content.background {
                BeruRadius.shape(BeruRadius.md)
                    .fill(BeruColor.dangerFill)
                    .overlay {
                        BeruRadius.shape(BeruRadius.md)
                            .strokeBorder(BeruColor.dangerBorder, lineWidth: BeruMetrics.hairline)
                    }
            }
        }
    }
}

struct SettingsFootnote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(BeruType.footnote)
            .foregroundStyle(BeruColor.textSecondary)
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
        VStack(alignment: .leading, spacing: BeruSpace.hair) {
            Text(title)
                .font(BeruType.rowTitle)
                .foregroundStyle(BeruColor.textPrimary)
            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(BeruType.footnote)
                    .foregroundStyle(BeruColor.textSecondary)
                    .lineSpacing(BeruSpace.hair)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var horizontalLayout: some View {
        // Centered: the label block rides the control's vertical center, so a
        // title-only row reads as one line and captioned rows stay balanced.
        HStack(alignment: .center, spacing: BeruSpace.lg) {
            labels
                .frame(minWidth: 0, maxWidth: BeruMetrics.labelMaxWidth, alignment: .leading)
            Spacer(minLength: BeruSpace.sm)
            control
                .layoutPriority(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var verticalLayout: some View {
        VStack(alignment: .leading, spacing: BeruSpace.xs) {
            labels
            // Leading, like System Settings' stacked rows: a trailing-aligned
            // control under a left label reads detached.
            control
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
            .padding(.horizontal, BeruMetrics.workspaceChromeInset)
            .padding(.vertical, BeruMetrics.workspaceChromePadding)
            .frame(maxWidth: .infinity, minHeight: BeruMetrics.workspaceChromeMinHeight, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            SettingsHeaderRule()
        }
    }

    private var toolbarContent: some View {
        HStack(alignment: .center, spacing: BeruSpace.sm) {
            content
        }
    }
}

struct SettingsListFooter<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            SettingsHeaderRule()
            HStack(spacing: BeruSpace.xs) {
                content
                Spacer(minLength: 0)
            }
            .buttonStyle(.plain)
            .foregroundStyle(BeruColor.textPrimary)
            .padding(.horizontal, BeruMetrics.workspaceChromeInset)
            .padding(.vertical, BeruMetrics.workspaceChromePadding)
            .frame(maxWidth: .infinity, minHeight: BeruMetrics.workspaceChromeMinHeight, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .background(DashboardChrome.sidebarSurface)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

extension View {
    func settingsWorkspacePane() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    func settingsSidebarList() -> some View {
        listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .contentMargins(.horizontal, BeruMetrics.workspaceListInset, for: .scrollContent)
    }

    /// Inset list-row highlight so selection pills do not touch column edges.
    func settingsListRowBackground(
        isHighlighted: Bool,
        fill: some ShapeStyle = BeruColor.accentGradient
    ) -> some View {
        listRowBackground(
            BeruRadius.shape(BeruRadius.md)
                .fill(isHighlighted ? AnyShapeStyle(fill) : AnyShapeStyle(Color.clear))
                .padding(.horizontal, BeruMetrics.workspaceListInset)
        )
    }

    func settingsEditorSurface() -> some View {
        padding(BeruSpace.sm)
            .background {
                BeruRadius.shape(BeruRadius.md)
                    .fill(BeruColor.input)
                    .overlay {
                        BeruRadius.shape(BeruRadius.md)
                            .strokeBorder(BeruColor.border, lineWidth: 1)
                    }
            }
    }
}
