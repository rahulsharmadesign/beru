import SwiftUI

/// SF Symbols used consistently across Beru. Stored ids may still be Lucide
/// kebab-case, Material names, or SF Symbol names; `IconNames.system` maps them.
struct BeruIcon: View {
    let name: String
    var size: CGFloat = 18
    /// Kept so existing call sites compile. SF Symbols use font weight, not stroke.
    var strokeWidth: CGFloat = 1.8

    var body: some View {
        Image(systemName: IconNames.system(stored: name))
            .font(.system(size: size, weight: strokeWidth >= 2.2 ? .semibold : .medium))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Icon + title label using SF Symbols.
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

/// Resolves stored icon ids (Lucide kebab-case, Material, or SF Symbol) to SF Symbols.
enum IconNames {
    static func system(stored: String) -> String {
        if let mapped = lucideToSystem[stored] { return mapped }
        if stored.contains(".") { return stored }
        return stored
    }

    private static let lucideToSystem: [String: String] = [
        // Lucide kebab-case
        "circle-check": "checkmark.circle",
        "sparkles": "sparkles",
        "corner-up-left": "arrowshape.turn.up.left",
        "list": "list.bullet",
        "lightbulb": "lightbulb",
        "smile": "face.smiling",
        "briefcase": "briefcase",
        "minimize-2": "arrow.down.right.and.arrow.up.left",
        "circle-dashed": "circle.dashed",
        "code": "chevron.left.forwardslash.chevron.right",
        "messages-square": "bubble.left.and.bubble.right",
        "globe": "globe",
        "message-square": "message",
        "wand-sparkles": "wand.and.stars",
        "target": "target",
        "message-circle": "message.circle",
        "maximize-2": "arrow.up.left.and.arrow.down.right",
        "settings": "gearshape",
        "check": "checkmark",
        "chevrons-up-down": "chevron.up.chevron.down",
        "graduation-cap": "graduationcap",
        "chevron-down": "chevron.down",
        "rotate-cw": "arrow.clockwise",
        "x": "xmark",
        "search": "magnifyingglass",
        "circle-arrow-up": "arrow.up.circle.fill",
        "arrow-down-right": "arrow.down.right",
        "arrow-up-right": "arrow.up.right",
        "arrow-up": "arrow.up",
        "equal": "equal",
        "trash-2": "trash",
        "plus": "plus",
        "minus": "minus",
        "mic": "mic.fill",
        "library": "books.vertical",
        "mic-off": "mic.slash",
        // DictationButton. Lucide `audio-lines` is not an SF Symbol name.
        "audio-lines": "mic.fill",
        "eye": "eye",
        "eye-off": "eye.slash",
        "circle-x": "xmark.circle",
        "pin": "pin",
        "pin-off": "pin.slash",
        "sticky-note": "note.text",
        "list-filter": "line.3.horizontal.decrease",
        "package": "shippingbox",
        "cpu": "cpu",
        "house": "house",
        "link": "link",
        "pause": "pause",
        "history": "clock.arrow.circlepath",
        "person": "person",
        "info": "info.circle",
        "lock": "lock.fill",
        "database": "internaldrive",
        // Material Symbols leftover in settings chrome
        "close": "xmark",
        "visibility": "eye",
        "visibility_off": "eye.slash",
        "expand_more": "chevron.down",
        "check_circle": "checkmark.circle",
        "cancel": "xmark.circle",
        "keep": "pin",
        "keep_off": "pin.slash",
        "sticky_note_2": "note.text",
        "auto_awesome": "sparkles",
        "filter_list": "line.3.horizontal.decrease",
        "inventory_2": "shippingbox",
        "track_changes": "target",
        "memory": "cpu",
        "remove": "minus",
        "add": "plus",
        "home": "house",
    ]
}

/// Empty-state placeholder with an SF Symbol.
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
        VStack(spacing: BeruSpace.sm) {
            BeruIcon(name: icon, size: 32, strokeWidth: 1.5)
                .foregroundStyle(BeruColor.textSecondary)
            Text(title)
                .font(BeruType.section)
                .foregroundStyle(BeruColor.textPrimary)
            Text(message)
                .font(BeruType.footnote)
                .foregroundStyle(BeruColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            actions
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(BeruSpace.md)
    }
}
