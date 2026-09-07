import SwiftUI

/// Settings shell: grouped sidebar + detail. Same nine routes and behavior,
/// rebuilt around Haze rows — icon tiles, group headers, gradient selection.
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
                .frame(height: BeruMetrics.titlebarHeight)
                .frame(maxWidth: .infinity)
            Rectangle()
                .fill(BeruColor.border)
                .frame(height: BeruMetrics.hairline)
                .frame(maxWidth: .infinity)
            HStack(spacing: 0) {
                sidebar
                    .frame(width: BeruMetrics.sidebarWidth)
                    .frame(maxHeight: .infinity)
                Rectangle()
                    .fill(BeruColor.border)
                    .frame(width: BeruMetrics.hairline)
                    .frame(maxHeight: .infinity)
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .tint(BeruColor.accent)
        .font(BeruType.font(13))
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
            SettingsSearchField(text: $query)
                .padding(.horizontal, BeruMetrics.workspaceListInset)
                .padding(.top, BeruSpace.md)
                .padding(.bottom, BeruSpace.sm)
            if filteredMenu.isEmpty && filteredFooter.isEmpty {
                sidebarNoMatches
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: BeruSpace.xs) {
                        sidebarGroup(title: "Settings", routes: settingsMenu)
                        sidebarGroup(title: "Workspace", routes: workspaceMenu)
                    }
                    .padding(.horizontal, BeruSpace.xs)
                }
                .scrollBounceBehavior(.basedOnSize)
                Spacer(minLength: 0)
                if searchIsEmpty {
                    SettingsTipCard {
                        model.route = .models
                    }
                    .padding(.horizontal, BeruSpace.xs)
                    .padding(.bottom, BeruSpace.xs)
                }
            }
            if searchIsEmpty || !filteredFooter.isEmpty {
                VStack(spacing: 0) {
                    SettingsHeaderRule()
                    ForEach(filteredFooter) { route in
                        sidebarButton(route)
                    }
                    .padding(.horizontal, BeruSpace.xs)
                    .padding(.vertical, BeruSpace.xxs)
                    .frame(maxWidth: .infinity, minHeight: BeruMetrics.workspaceChromeMinHeight)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func sidebarGroup(title: String, routes: [DashboardRoute]) -> some View {
        if !routes.isEmpty {
            Text(title)
                .font(BeruType.footnoteSemibold)
                .foregroundStyle(BeruColor.textTertiary)
                .padding(.horizontal, BeruSpace.sm)
                .padding(.top, BeruSpace.xs)
                .accessibilityAddTraits(.isHeader)
            ForEach(routes) { route in
                sidebarButton(route)
            }
        }
    }

    private func sidebarButton(_ route: DashboardRoute) -> some View {
        Button {
            model.route = route
        } label: {
            sidebarRow(route)
        }
        .buttonStyle(.plain)
    }

    private func sidebarRow(_ route: DashboardRoute) -> some View {
        let selected = model.route == route
        return HStack(spacing: BeruSpace.sm) {
            ZStack {
                BeruRadius.shape(BeruRadius.sm)
                    .fill(selected ? BeruColor.onAccent.opacity(0.22) : BeruColor.subtleFill)
                    .overlay {
                        if !selected {
                            BeruRadius.shape(BeruRadius.sm)
                                .strokeBorder(BeruColor.border, lineWidth: 1)
                        }
                    }
                BeruIcon(name: route.lucideIcon, size: BeruMetrics.iconSize)
                    .foregroundStyle(selected ? BeruColor.onAccent : BeruColor.textSecondary)
            }
            .frame(width: BeruMetrics.roundButtonSm, height: BeruMetrics.roundButtonSm)
            Text(route.title)
                .font(selected ? BeruType.sidebarSelected : BeruType.sidebar)
            Spacer(minLength: 0)
            if route == .models {
                ModelsDownloadBadge()
            }
            if route == .about, updates.showsUpdateButton {
                SidebarUpdateChip()
            }
        }
        .foregroundStyle(selected ? BeruColor.onAccent : BeruColor.textPrimary)
        .padding(.horizontal, BeruSpace.sm)
        .padding(.vertical, BeruSpace.xxs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            BeruRadius.shape(BeruRadius.md)
                .fill(selected ? AnyShapeStyle(BeruColor.accentGradient) : AnyShapeStyle(Color.clear))
        }
        .contentShape(RoundedRectangle(cornerRadius: BeruRadius.md, style: .continuous))
    }

    private var sidebarNoMatches: some View {
        Text("No matches")
            .font(BeruType.footnote)
            .foregroundStyle(BeruColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, BeruSpace.xl)
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
                .font(BeruType.footnote)
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
            VStack(alignment: .leading, spacing: BeruSpace.xs) {
                HStack(alignment: .center, spacing: BeruSpace.xs) {
                    Text("Tip")
                        .font(BeruType.sidebarHeader)
                        .foregroundStyle(BeruColor.textPrimary)
                    Spacer(minLength: 0)
                    SettingsIconButton(icon: "x", size: BeruMetrics.iconSizeDense, frameSize: BeruMetrics.hitTargetCompact, help: "Dismiss tip") {
                        settings.hasDismissedSettingsTip = true
                    }
                }
                Text("Gemma 3 1B is a lightweight local model (~815 MB) that fits the widget.")
                    .font(BeruType.footnote)
                    .foregroundStyle(BeruColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                SettingsPrimaryButton(title: "View models", action: onViewModels)
            }
            .padding(BeruSpace.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                BeruRadius.shape(BeruRadius.md)
                    .fill(BeruColor.card)
                    .overlay {
                        BeruRadius.shape(BeruRadius.md)
                            .strokeBorder(BeruColor.border, lineWidth: 1)
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
        SettingsIconButton(
            icon: "square.and.arrow.down",
            size: 14,
            frameSize: BeruMetrics.hitTargetCompact,
            enabled: !updates.isBusy,
            help: updates.availableVersion.map { "Install Beru \($0)" } ?? "Install the latest Beru"
        ) {
            updates.install()
        }
        .accessibilityLabel("Install update")
    }
}
