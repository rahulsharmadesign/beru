import AppKit
import SwiftUI

/// Dashboard-flavored names for the tokens in `BeruColor`.
///
/// These are aliases, not a second palette. New code should reach for
/// `BeruColor` directly; this exists so the several hundred existing dashboard
/// call sites keep reading naturally while there is one definition behind them.
enum SettingsTheme {
    static var window: Color { BeruColor.canvas }
    static var sidebar: Color { BeruColor.canvas }
    static var surface: Color { BeruColor.surface }
    static var border: Color { BeruColor.border }
    static var textPrimary: Color { BeruColor.textPrimary }
    static var textSecondary: Color { BeruColor.textSecondary }
    @MainActor
    static var active: Color { BeruColor.accent }
    /// Was pinned to `PrimaryColor.indigo`, so picking any other accent left the
    /// glyph color derived from a color no longer on screen.
    @MainActor
    static var onActive: Color { BeruColor.onAccent }
    static var badgeBg: Color { BeruColor.badge }
    static var sidebarSelected: Color { BeruColor.selectedRow }
    static var hoverFill: Color { BeruColor.hoverFill }
    static var inputBg: Color { BeruColor.input }
    static var destructive: Color { BeruColor.destructive }
    static var positive: Color { BeruColor.positive }
}

/// Dashboard-flavored names for the geometry in `BeruMetrics`.
enum SettingsChrome {
    static let windowWidth = BeruMetrics.windowWidth
    static let windowHeight = BeruMetrics.windowHeight
    static let sidebarWidth = BeruMetrics.sidebarWidth
    static let workspaceListMaxWidth = BeruMetrics.workspaceListWidth
    static let contentPadding = BeruMetrics.contentPadding
    static let headerContentSpacing = BeruSpace.md
    static let workspaceListInset = BeruSpace.md
    static let rowRadius = BeruRadius.md
    static let fieldWidth = BeruMetrics.fieldWidth
    static let labelMaxWidth = BeruMetrics.labelMaxWidth
    /// Band under the traffic lights before the settings body. Hairline sits
    /// on its bottom edge and meets the sidebar vertical rule.
    static let titlebarHeight: CGFloat = 4
}
