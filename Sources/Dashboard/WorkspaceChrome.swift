import SwiftUI

// Native source-list chrome for Vault, Actions, Targets, and Runs.
// These pages live in Settings, so they use List selection and the system
// highlight rather than a painted accent pill.

struct WorkspaceListRow<Leading: View, Accessory: View>: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    @ViewBuilder var leading: Leading
    @ViewBuilder var accessory: Accessory

    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        @ViewBuilder leading: () -> Leading = { EmptyView() },
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.leading = leading()
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .center, spacing: BeruSpace.sm) {
            leading
            if let icon {
                BeruIcon(name: icon, size: 16)
                    .frame(width: 18, height: 18)
            }
            VStack(alignment: .leading, spacing: BeruSpace.hair) {
                HStack(alignment: .firstTextBaseline, spacing: BeruSpace.xs) {
                    Text(title)
                        .font(BeruType.rowTitle)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    accessory
                        .font(BeruType.footnote)
                }
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(BeruType.footnote)
                        .foregroundStyle(BeruColor.textSecondary)
                        .lineLimit(2)
                }
            }
        }
    }
}

struct WorkspaceSourceList<Selection: Hashable, Content: View, Footer: View>: View {
    @Binding var selection: Selection?
    var isEmpty: Bool
    var emptyIcon: String
    var emptyTitle: String
    var emptyMessage: String
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    init(
        selection: Binding<Selection?>,
        isEmpty: Bool,
        emptyIcon: String,
        emptyTitle: String,
        emptyMessage: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer = { EmptyView() }
    ) {
        _selection = selection
        self.isEmpty = isEmpty
        self.emptyIcon = emptyIcon
        self.emptyTitle = emptyTitle
        self.emptyMessage = emptyMessage
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if isEmpty {
                    BeruEmptyState(icon: emptyIcon, title: emptyTitle, message: emptyMessage)
                        .padding(.horizontal, BeruMetrics.workspaceChromeInset)
                } else {
                    List(selection: $selection) {
                        content
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DashboardChrome.sidebarSurface)
    }
}

extension View {
    func workspaceSourceRow() -> some View {
        listRowSeparator(.hidden)
            .listRowInsets(
                EdgeInsets(
                    top: BeruSpace.xxs,
                    leading: BeruMetrics.workspaceChromeInset,
                    bottom: BeruSpace.xxs,
                    trailing: BeruMetrics.workspaceChromeInset
                )
            )
    }
}

/// One padded band: toolbar, inspector title, inspector actions, list +/−.
struct WorkspaceChromeBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .center, spacing: BeruSpace.sm) {
            content
        }
        .padding(.horizontal, BeruMetrics.workspaceChromeInset)
        .padding(.vertical, BeruMetrics.workspaceChromePadding)
        .frame(maxWidth: .infinity, minHeight: BeruMetrics.workspaceChromeMinHeight, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Inspector column: title bar, body, action bar. Hairlines are full-bleed so
/// they meet the split and the list footer.
struct WorkspaceInspector<Header: View, Main: View, Footer: View>: View {
    @ViewBuilder var header: Header
    @ViewBuilder var main: Main
    @ViewBuilder var footer: Footer

    init(
        @ViewBuilder header: () -> Header,
        @ViewBuilder main: () -> Main,
        @ViewBuilder footer: () -> Footer
    ) {
        self.header = header()
        self.main = main()
        self.footer = footer()
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            SettingsHeaderRule()
            main
                .frame(minWidth: 0, minHeight: 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
            SettingsHeaderRule()
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
