import SwiftUI

// Native source-list chrome for Vault, Actions, Targets, and Runs.
// Rows select by tap and paint the Haze accent wash themselves: the system
// List highlight follows the system accent color, which fights the brand
// no matter what tint the window applies.

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
                ZStack {
                    BeruRadius.shape(BeruRadius.sm)
                        .fill(Color.clear)
                        .overlay {
                            BeruRadius.shape(BeruRadius.sm)
                                .strokeBorder(BeruColor.strongBorder, lineWidth: BeruMetrics.hairline)
                        }
                    BeruIcon(name: icon, size: BeruMetrics.iconSize)
                        .foregroundStyle(BeruColor.textSecondary)
                }
                .frame(width: BeruMetrics.roundButtonSm, height: BeruMetrics.roundButtonSm)
            }
            VStack(alignment: .leading, spacing: BeruSpace.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: BeruSpace.xs) {
                    Text(title)
                        .font(BeruType.rowTitle)
                        .foregroundStyle(BeruColor.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    accessory
                        .font(BeruType.footnote)
                }
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(BeruType.footnote)
                        .foregroundStyle(BeruColor.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        // One-line and two-line rows share the same floor, so list spacing
        // reads as equidistant no matter the row content.
        .frame(minHeight: BeruMetrics.workspaceRowMinHeight, alignment: .leading)
    }
}

struct WorkspaceSourceList<Content: View, Footer: View>: View {
    var isEmpty: Bool
    var emptyIcon: String
    var emptyTitle: String
    var emptyMessage: String
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    init(
        isEmpty: Bool,
        emptyIcon: String,
        emptyTitle: String,
        emptyMessage: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer = { EmptyView() }
    ) {
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
                    List {
                        content
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                    // Gutter so rows and selection pills never touch the
                    // split borders.
                    .padding(.horizontal, BeruSpace.sm)
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
    /// Painted selection for a workspace source row. Replaces `.tag` plus
    /// `List(selection:)`: the system highlight follows the system accent,
    /// so rows select through a plain button and paint the Haze accent wash
    /// themselves.
    ///
    /// All List row modifiers sit on the Button itself — `listRowInsets`
    /// inside a Button label are swallowed, which left row content stretched
    /// edge to edge. Content spacing is plain padding inside the label.
    func workspaceRowSelection<Selection: Hashable>(
        _ selection: Binding<Selection?>,
        value: Selection,
        isSelected: Bool
    ) -> some View {
        Button {
            selection.wrappedValue = value
        } label: {
            self
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, BeruSpace.xxs)
                .padding(.horizontal, BeruSpace.md)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowSeparator(.hidden)
        .listRowInsets(
            EdgeInsets(
                top: BeruSpace.hair,
                leading: 0,
                bottom: BeruSpace.hair,
                trailing: 0
            )
        )
        .listRowBackground(
            Group {
                if isSelected {
                    BeruRadius.shape(BeruRadius.md)
                        .fill(BeruColor.selectedRow)
                        .padding(.horizontal, BeruSpace.xs)
                }
            }
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
