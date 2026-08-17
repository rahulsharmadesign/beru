import SwiftUI

/// Adaptive two-column shell shared by settings and workspace pages.
struct DashboardView: View {
    @Bindable var model: DashboardModel
    @State private var query = ""

    init(model: DashboardModel) {
        _model = Bindable(model)
    }

    var body: some View {
        let _ = AppearanceObserver.shared.signature
        HStack(spacing: 0) {
            sidebar
                .frame(width: SettingsChrome.sidebarWidth)
                .frame(maxHeight: .infinity)
            Rectangle()
                .fill(SettingsTheme.border)
                .frame(width: 1)
                .frame(maxHeight: .infinity)
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .background(SettingsTheme.window)
        .tint(BrandColors.accentColor)
        .font(BeruSans.font(13))
    }

    private var filteredMenu: [DashboardRoute] {
        DashboardRoute.menu.filter { $0.matches(query) }
    }

    private var filteredFooter: [DashboardRoute] {
        DashboardRoute.footer.filter { $0.matches(query) }
    }

    private var settingsMenu: [DashboardRoute] {
        filteredMenu.filter { !$0.isWorkspace }
    }

    private var workspaceMenu: [DashboardRoute] {
        filteredMenu.filter(\.isWorkspace)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSearchField(text: $query)
                .padding(.bottom, SettingsChrome.headerContentSpacing)
            if filteredMenu.isEmpty && filteredFooter.isEmpty {
                sidebarNoMatches
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(settingsMenu) { route in
                            sidebarButton(route)
                        }
                        if !settingsMenu.isEmpty && !workspaceMenu.isEmpty {
                            sidebarGroupDivider
                        }
                        ForEach(workspaceMenu) { route in
                            sidebarButton(route)
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                Spacer(minLength: 0)
                if !filteredFooter.isEmpty {
                    sidebarGroupDivider
                    ForEach(filteredFooter) { route in
                        sidebarButton(route)
                    }
                }
            }
        }
        .padding(.horizontal, SettingsChrome.workspaceListInset)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(SettingsTheme.sidebar)
    }

    private func sidebarButton(_ route: DashboardRoute) -> some View {
        Button {
            model.route = route
        } label: {
            sidebarRow(route)
        }
        .buttonStyle(.plain)
    }

    /// Separates preferences from workspace pages.
    private var sidebarGroupDivider: some View {
        Rectangle()
            .fill(SettingsTheme.border)
            .frame(height: 1)
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
    }

    private var sidebarNoMatches: some View {
        Text("No matches")
            .font(BeruSans.rowCaption)
            .foregroundStyle(SettingsTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 24)
    }

    private func sidebarRow(_ route: DashboardRoute) -> some View {
        let selected = model.route == route
        return HStack(spacing: 10) {
            BeruIcon(name: route.lucideIcon, size: 18)
                .foregroundStyle(SettingsTheme.textSecondary)
                .frame(width: 18, height: 18)
            Text(route.title)
                .font(selected ? BeruSans.sidebarSelected : BeruSans.sidebar)
            Spacer(minLength: 0)
        }
        .foregroundStyle(SettingsTheme.textPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: SettingsChrome.rowRadius, style: .continuous)
                .fill(selected ? SettingsTheme.sidebarSelected : Color.clear)
        }
        .contentShape(RoundedRectangle(cornerRadius: SettingsChrome.rowRadius, style: .continuous))
    }

    @ViewBuilder
    private var detail: some View {
        Group {
            switch model.route {
            case .general: GeneralSettingsTab()
            case .models: ModelsView()
            case .permissions: PermissionsSettingsTab()
            case .data: HistorySettingsTab()
            case .vault: VaultView(model: model)
            case .runs: RunsView()
            case .actions: ActionsView()
            case .targets: TargetsView()
            case .about: AboutSettingsTab()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SettingsTheme.window)
    }
}
