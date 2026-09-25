import SwiftUI

/// Settings shell: sidebar + detail. Plain glyphs, neutral selection.
struct DashboardView: View {
    @Bindable var model: DashboardModel
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
                .frame(height: EnhancifyMetrics.titlebarHeight)
                .frame(maxWidth: .infinity)
            Rectangle()
                .fill(EnhancifyColor.border)
                .frame(height: EnhancifyMetrics.hairline)
                .frame(maxWidth: .infinity)
            HStack(spacing: 0) {
                sidebar
                    .frame(width: EnhancifyMetrics.sidebarWidth)
                    .frame(maxHeight: .infinity)
                Rectangle()
                    .fill(EnhancifyColor.border)
                    .frame(width: EnhancifyMetrics.hairline)
                    .frame(maxHeight: .infinity)
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .tint(EnhancifyColor.accent)
        .font(EnhancifyType.control)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: EnhancifySpace.md)
            // Custom rows, not a List: AppKit draws List selection with the
            // system accent and ignores SwiftUI tint.
            VStack(alignment: .leading, spacing: EnhancifySpace.xs) {
                sidebarGroup(title: "Settings", routes: DashboardRoute.menu)
            }
            .padding(.horizontal, EnhancifySpace.xs)
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                SettingsHeaderRule()
                ForEach(DashboardRoute.footer) { route in
                    sidebarButton(route)
                }
                .padding(.horizontal, EnhancifySpace.xs)
                .padding(.vertical, EnhancifySpace.xxs)
                .frame(maxWidth: .infinity, minHeight: EnhancifyMetrics.workspaceChromeMinHeight)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Inset panel: 4pt of glass around the sidebar, clipped to the same
        // rounded enclosure as the window.
        .padding(EnhancifySpace.xxs)
        .clipShape(EnhancifyRadius.shape(EnhancifyRadius.sm))
    }

    @ViewBuilder
    private func sidebarGroup(title: String, routes: [DashboardRoute]) -> some View {
        if !routes.isEmpty {
            Text(title)
                .font(EnhancifyType.footnoteSemibold)
                .foregroundStyle(EnhancifyColor.textTertiary)
                .padding(.horizontal, EnhancifySpace.sm)
                .padding(.top, EnhancifySpace.xs)
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
        return HStack(spacing: EnhancifySpace.sm) {
            // Plain glyph, no colored tile: with four pages the icons are
            // wayfinding, not decoration.
            EnhancifyIcon(name: route.lucideIcon, size: EnhancifyMetrics.sidebarTileGlyph)
                .foregroundStyle(EnhancifyColor.textSecondary)
                .frame(width: EnhancifyMetrics.sidebarTileBox, height: EnhancifyMetrics.sidebarTileBox)
            Text(route.title)
                .font(selected ? EnhancifyType.sidebarSelected : EnhancifyType.sidebar)
            Spacer(minLength: 0)
            if route == .about, updates.showsUpdateButton {
                SidebarUpdateChip()
            }
        }
        .foregroundStyle(EnhancifyColor.textPrimary)
        .padding(.horizontal, EnhancifySpace.sm)
        .frame(maxWidth: .infinity, minHeight: EnhancifyMetrics.sidebarRowHeight, alignment: .leading)
        .frame(height: EnhancifyMetrics.sidebarRowHeight)
        .background {
            EnhancifyRadius.shape(EnhancifyRadius.md)
                .fill(selected ? EnhancifyColor.hoverFill : Color.clear)
        }
        .contentShape(RoundedRectangle(cornerRadius: EnhancifyRadius.md, style: .continuous))
    }

    private var detail: some View {
        Group {
            switch model.route {
            case .general: GeneralSettingsTab()
            case .models: ModelsView()
            case .permissions: PermissionsSettingsTab()
            case .about: AboutSettingsTab()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct SidebarUpdateChip: View {
    @Bindable private var updates = AppUpdateService.shared

    var body: some View {
        SettingsIconButton(
            icon: "square.and.arrow.down",
            size: EnhancifyMetrics.iconSizeCompact,
            frameSize: EnhancifyMetrics.hitTargetCompact,
            enabled: !updates.isBusy,
            help: updates.availableVersion.map { "Install Enhancify \($0)" } ?? "Install the latest Enhancify"
        ) {
            updates.install()
        }
        .accessibilityLabel("Install update")
    }
}
