import SwiftUI

/// One surface for the whole detail area.
///
/// The centered "patch" was a 720pt Form drawing its own fill on top of a
/// darker window. Form scroll chrome is hidden; every pane paints the same
/// canvas full-bleed. Grouped sections stay as inset cards on that one ground —
/// System Settings style, no floating column.
enum DashboardChrome {
    /// Overlay on the system window material. A second canvas fill here is
    /// what flattened Tahoe glass into a grey card.
    static var sidebarSurface: Color { Color.clear }
}

extension View {
    func dashboardEditorCanvas() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Color.clear)
    }
}
