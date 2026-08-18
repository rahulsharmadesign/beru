import AppKit
import SwiftUI

enum DashboardTheme {
    static let formMaxWidth: CGFloat = 720
    @MainActor
    static var accent: Color { BrandColors.accentColor }
}

/// One surface for the whole detail area.
///
/// The centered “patch” was a 720pt Form drawing its own fill on top of a
/// darker window. Form scroll chrome is hidden; every pane paints the same
/// `contentSurface` full-bleed. Grouped sections stay as inset cards on that
/// one ground — System Settings style, no floating column.
enum DashboardChrome {
    static let wellRadius: CGFloat = 10
    /// Soft readable width for form *content*; never painted as its own slab.
    static let formMaxWidth: CGFloat = 680

    static var contentSurface: Color {
        SettingsTheme.window
    }
    /// Solid sidebar ground; unlike vibrancy it does not wash out while the window is inactive behind another app.
    static var sidebarSurface: Color {
        SettingsTheme.sidebar
    }
}

extension View {
    /// Grouped Form whose underlay matches the detail pane (no second tint).
    func settingsFormStyle() -> some View {
        self
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .tint(DashboardTheme.accent)
    }

    func dashboardWell(padding: CGFloat = 0) -> some View {
        self
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: DashboardChrome.wellRadius, style: .continuous)
                    .fill(BrandColors.surface)
            }
    }

    func dashboardPane() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(DashboardChrome.contentSurface)
    }

    func dashboardSidebar() -> some View {
        self
            .scrollContentBackground(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(DashboardChrome.sidebarSurface)
            .tint(DashboardTheme.accent)
    }
    func dashboardListPane() -> some View {
        self
            .scrollContentBackground(.hidden)
            .dashboardPane()
    }

    func dashboardEditorCanvas() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Color.clear)
    }

    /// Full-bleed surface; form content optionally width-capped without a
    /// painted middle slab (that was the patch).
    func settingsDetailColumn() -> some View {
        self
            .frame(maxWidth: DashboardChrome.formMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(DashboardChrome.contentSurface)
    }
}

struct AppEditorModeControl: View {
    @Binding var showingPreview: Bool
    var body: some View {
        HStack(spacing: 3) {
            mode("Edit", active: !showingPreview) { showingPreview = false }
            mode("Preview", active: showingPreview) { showingPreview = true }
        }
        .padding(3)
        .background(SettingsTheme.badgeBg, in: Capsule())
        .fixedSize()
    }
    private func mode(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(BeruSans.control)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundStyle(active ? SettingsTheme.onActive : SettingsTheme.textPrimary)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(active ? SettingsTheme.active : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
    }
}
