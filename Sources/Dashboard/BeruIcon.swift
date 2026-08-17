import Lucide
import SwiftUI

/// Lucide icons (ISC) used consistently across Beru.
struct BeruIcon: View {
    let name: String
    var size: CGFloat = 18
    var strokeWidth: CGFloat = 1.8

    var body: some View {
        (Lucide(IconNames.lucide(stored: name)) ?? Lucide(.circleQuestionMark))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Icon + title label using Lucide instead of SF Symbols.
struct BeruLabel: View {
    let title: String
    let icon: String
    var iconSize: CGFloat = 16
    var strokeWidth: CGFloat = 1.8

    var body: some View {
        Label {
            Text(title)
        } icon: {
            BeruIcon(name: icon, size: iconSize, strokeWidth: strokeWidth)
        }
    }
}

/// Resolves stored icon ids (Lucide kebab-case or legacy SF Symbol / Material names).
enum IconNames {
    static func lucide(stored: String) -> String {
        legacy[stored] ?? stored
    }

    private static let legacy: [String: String] = [
        // SF Symbols — actions & targets
        "checkmark.circle": "circle-check",
        "sparkles": "sparkles",
        "sparkle.magnifyingglass": "sparkles",
        "arrowshape.turn.up.left": "corner-up-left",
        "list.bullet.rectangle": "list",
        "lightbulb": "lightbulb",
        "face.smiling": "smile",
        "briefcase": "briefcase",
        "arrow.down.right.and.arrow.up.left": "minimize-2",
        "circle.dashed": "circle-dashed",
        "chevron.left.forwardslash.chevron.right": "code",
        "bubble.left.and.bubble.right": "messages-square",
        "sparkle": "sparkles",
        "globe.asia.australia": "globe",
        "text.bubble": "message-square",
        "wand.and.stars": "wand-sparkles",
        "target": "target",
        "character.bubble": "message-circle",
        "arrow.up.left.and.arrow.down.right": "maximize-2",
        "list.bullet": "list",
        "bubble.left": "message-square",
        // SF Symbols — chrome
        "gearshape": "settings",
        "checkmark": "check",
        "chevron.up.chevron.down": "chevrons-up-down",
        "graduationcap": "graduation-cap",
        "chevron.down": "chevron-down",
        "arrow.clockwise": "rotate-cw",
        "xmark": "x",
        "magnifyingglass": "search",
        "arrow.up.circle.fill": "circle-arrow-up",
        "arrow.down.right": "arrow-down-right",
        "arrow.up.right": "arrow-up-right",
        "equal": "equal",
        "trash": "trash-2",
        "plus": "plus",
        "waveform": "mic",
        "books.vertical": "library",
        "mic.fill": "mic",
        "mic.slash": "mic-off",
        // Material Symbols — settings chrome
        "close": "x",
        "visibility": "eye",
        "visibility_off": "eye-off",
        "expand_more": "chevron-down",
        "check_circle": "circle-check",
        "cancel": "circle-x",
        "keep": "pin",
        "keep_off": "pin-off",
        "sticky_note_2": "sticky-note",
        "auto_awesome": "sparkles",
        "filter_list": "list-filter",
        "inventory_2": "package",
        "track_changes": "target",
        "memory": "cpu",
        "remove": "minus",
        "add": "plus",
        "home": "house",
    ]
}

/// Empty-state placeholder with a Lucide icon.
///
/// One shared layout for every "nothing selected / nothing here" moment in
/// the dashboard, so icon size, spacing, and typography never drift between
/// pages. `actions` is optional for pages (Vault) that offer a way out of
/// the empty state, e.g. "New Note".
struct BeruEmptyState<Actions: View>: View {
    let icon: String
    let title: String
    let message: String
    @ViewBuilder var actions: Actions

    init(
        icon: String,
        title: String,
        message: String,
        @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: 12) {
            BeruIcon(name: icon, size: 32, strokeWidth: 1.5)
                .foregroundStyle(SettingsTheme.textSecondary)
            Text(title)
                .font(BeruSans.section)
                .foregroundStyle(SettingsTheme.textPrimary)
            Text(message)
                .font(BeruSans.rowCaption)
                .foregroundStyle(SettingsTheme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            actions
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
