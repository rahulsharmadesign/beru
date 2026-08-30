import SwiftUI

// Page scaffolding for the dashboard: the shells every route builds inside.
// The reusable controls these pages fill themselves with live in
// Sources/Design/SettingsControls.swift.

struct SettingsHeaderRule: View {
    var body: some View {
        Rectangle()
            .fill(BeruColor.border)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}

struct SettingsVRule: View {
    var body: some View {
        Rectangle()
            .fill(BeruColor.border)
            .frame(width: 1)
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
    var content: Content

    init(title: String, subtitle: String = "", @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: BeruMetrics.headerContentSpacing) {
                SettingsPageHeader(title: title, subtitle: subtitle)
                SettingsHeaderRule()
            }
            .padding(.horizontal, BeruMetrics.contentPadding)
            .padding(.top, BeruSpace.lg)
            .fixedSize(horizontal: false, vertical: true)
            ScrollView {
                content
                    .padding(.horizontal, BeruMetrics.contentPadding)
                    .padding(.top, BeruMetrics.headerContentSpacing)
                    .padding(.bottom, BeruSpace.xxl)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollContentBackground(.hidden)
            .scrollEdgeEffectStyle(.none, for: .vertical)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct SettingsWorkspace<Content: View>: View {
    let title: String
    let subtitle: String
    var content: Content

    init(title: String, subtitle: String = "", @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsPageHeader(title: title, subtitle: subtitle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, BeruMetrics.workspaceChromeInset)
                .padding(.top, BeruSpace.lg)
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

    var body: some View {
        // Every page already declares a subtitle in DashboardRoute and search
        // matches against it, but the header discarded the argument, so the
        // copy explaining each page was written and never shown.
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let subtitle: String?
    var content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
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
            VStack(alignment: .leading, spacing: BeruSpace.md) {
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
        HStack(alignment: .top, spacing: BeruSpace.lg) {
            labels
                .frame(minWidth: 0, maxWidth: BeruMetrics.labelMaxWidth, alignment: .leading)
            Spacer(minLength: BeruSpace.sm)
            control
                .padding(.top, BeruSpace.hair)
                .layoutPriority(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var verticalLayout: some View {
        VStack(alignment: .leading, spacing: BeruSpace.xs) {
            labels
            control
                .frame(maxWidth: .infinity, alignment: .trailing)
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
        fill: some ShapeStyle = BeruColor.accent
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
