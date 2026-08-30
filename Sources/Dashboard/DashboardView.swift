import SwiftUI

/// Adaptive two-column shell shared by settings and workspace pages.
struct DashboardView: View {
    @Bindable var model: DashboardModel
    @State private var query = ""
    @Bindable private var updates = AppUpdateService.shared
    @Bindable private var appearance = AppearanceObserver.shared

    init(model: DashboardModel) {
        _model = Bindable(model)
    }

    var body: some View {
        // Observation only invalidates on values read while body runs, and
        // nothing in this tree reads the system appearance. This read is the
        // subscription that repaints AppKit-backed surfaces on a light/dark switch.
        let _ = appearance.signature
        // Titleband → full-width hairline → sidebar | detail. The stroke sits
        // under the traffic lights and meets the vertical rule at a T-junction.
        VStack(spacing: 0) {
            Color.clear
                .frame(height: SettingsChrome.titlebarHeight)
                .frame(maxWidth: .infinity)
            Rectangle()
                .fill(SettingsTheme.border)
                .frame(height: 1)
                .frame(maxWidth: .infinity)
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .tint(BeruColor.accent)
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

    /// Hide the tip while sidebar search is filtering.
    private var searchIsEmpty: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                    if searchIsEmpty {
                        SettingsTipCard {
                            model.route = .models
                        }
                        .padding(.bottom, BeruSpace.xs)
                    }
                }
            }
            .padding(.horizontal, SettingsChrome.workspaceListInset)
            .padding(.top, BeruSpace.md)
            if searchIsEmpty || !filteredFooter.isEmpty {
                VStack(spacing: 0) {
                    SettingsHeaderRule()
                    VStack(spacing: 2) {
                        ForEach(filteredFooter) { route in
                            sidebarButton(route)
                        }
                    }
                    .padding(.horizontal, SettingsChrome.workspaceListInset)
                    .frame(maxWidth: .infinity, minHeight: BeruMetrics.workspaceChromeMinHeight)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
            .padding(.horizontal, BeruSpace.xxs)
            .padding(.vertical, BeruSpace.xs)
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
        return HStack(spacing: BeruSpace.sm) {
            Image(systemName: route.systemImage)
                .font(BeruType.body)
                .foregroundStyle(SettingsTheme.textSecondary)
                .frame(width: 18, height: 18)
            Text(route.title)
                .font(selected ? BeruSans.sidebarSelected : BeruSans.sidebar)
            Spacer(minLength: 0)
            if route == .models {
                ModelsDownloadBadge()
            }
            if route == .about, updates.showsUpdateButton {
                SidebarUpdateChip()
            }
        }
        .foregroundStyle(SettingsTheme.textPrimary)
        .padding(.horizontal, BeruSpace.sm)
        .padding(.vertical, BeruSpace.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            GlassSelectedFill(isSelected: selected, radius: SettingsChrome.rowRadius)
        }
        .contentShape(RoundedRectangle(cornerRadius: SettingsChrome.rowRadius, style: .continuous))
    }

    private var detail: some View {
        Group {
            switch model.route {
            case .general: GeneralSettingsTab()
            case .models: ModelsView()
            case .permissions: PermissionsSettingsTab()
            case .data: HistorySettingsTab()
            case .vault: VaultView(model: model)
            case .runs: RunsView(dashboard: model)
            case .actions: ActionsView()
            case .targets: TargetsView()
            case .about: AboutSettingsTab()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Isolated so a pull's progress ticks do not re-layout the whole dashboard.
private struct ModelsDownloadBadge: View {
    @Bindable private var pull = OllamaPullService.shared

    var body: some View {
        if pull.pulling != nil {
            Text("Downloading…")
                .font(BeruSans.footnote)
                .foregroundStyle(SettingsTheme.textSecondary)
                .lineLimit(1)
        }
    }
}

/// Isolated so dismissing the tip does not animate or invalidate the dashboard.
private struct SettingsTipCard: View {
    var onViewModels: () -> Void
    @Bindable private var settings = SettingsStore.shared
    @State private var revealed = false

    var body: some View {
        if !settings.hasDismissedSettingsTip {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Text("Tip")
                        .font(BeruSans.sidebarHeader)
                        .foregroundStyle(SettingsTheme.textPrimary)
                    Spacer(minLength: 0)
                    SettingsIconButton(icon: "x", size: 12, frameSize: 22, help: "Dismiss tip") {
                        settings.hasDismissedSettingsTip = true
                    }
                }
                Text("Gemma 3 1B is a lightweight local model (~815 MB) that fits the widget.")
                    .font(BeruSans.footnote)
                    .foregroundStyle(SettingsTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                SettingsPrimaryButton(title: "View models", action: onViewModels)
            }
            .padding(BeruSpace.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                BeruRadius.shape(SettingsChrome.rowRadius)
                    .fill(BeruColor.surface)
                    .overlay {
                        BeruRadius.shape(SettingsChrome.rowRadius)
                            .strokeBorder(SettingsTheme.border, lineWidth: 1)
                    }
            }
            .opacity(revealed ? 1 : 0)
            .onAppear { revealed = true }
            .animation(.easeOut(duration: 0.25), value: revealed)
        }
    }
}

private struct SidebarUpdateChip: View {
    @Bindable private var updates = AppUpdateService.shared

    var body: some View {
        SettingsPrimaryButton(
            title: updates.buttonTitle,
            enabled: !updates.isBusy
        ) {
            updates.install()
        }
        .accessibilityLabel("Update")
    }
}
