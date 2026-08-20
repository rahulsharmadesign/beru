import SwiftUI

/// One surface for the whole detail area.
///
/// The centered "patch" was a 720pt Form drawing its own fill on top of a
/// darker window. Form scroll chrome is hidden; every pane paints the same
/// canvas full-bleed. Grouped sections stay as inset cards on that one ground —
/// System Settings style, no floating column.
///
/// Seven more modifiers and a `DashboardTheme` used to live here with no
/// callers, describing a layout the app had already moved away from.
enum DashboardChrome {
    /// Solid sidebar ground; unlike vibrancy it does not wash out while the
    /// window is inactive behind another app.
    static var sidebarSurface: Color { BeruColor.canvas }
}

extension View {
    func dashboardEditorCanvas() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Color.clear)
    }
}
