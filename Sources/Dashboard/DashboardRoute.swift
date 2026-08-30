import Foundation

/// A destination in the dashboard sidebar.
enum DashboardRoute: String, Identifiable, CaseIterable, Hashable {
    case general
    case models
    case permissions
    case data
    case vault
    case runs
    case actions
    case targets
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .models: return "Models"
        case .permissions: return "Permissions"
        case .data: return "Data"
        case .vault: return "Vault"
        case .runs: return "Runs"
        case .actions: return "Actions"
        case .targets: return "Targets"
        case .about: return "About"
        }
    }

    var pageSubtitle: String {
        switch self {
        case .general: return "Global preferences for Beru."
        case .models: return "Choose a local or cloud provider and the models it should use."
        case .permissions: return "Accessibility and dictation. Required for capture and replace."
        case .data: return "Local history, exports, and token savings."
        case .vault: return "Local notes and pins. Nothing leaves this Mac."
        case .runs: return "Every recorded invocation, with the diff and the reason."
        case .actions: return "Verb chips in the panel. Built-in jobs plus your own."
        case .targets: return "Where an enhanced prompt is going, so Enhance Prompt can speak that dialect."
        case .about: return "This build, and how to reach the person who made it."
        }
    }

    /// Extra search terms so "tip" or "version" still finds About.
    var searchTerms: String {
        switch self {
        case .about: return "about tip razorpay contact github version support donate update"
        default: return ""
        }
    }

    /// Lucide icon name (kebab-case). Used in the panel; settings sidebar
    /// uses `systemImage`.
    var lucideIcon: String {
        switch self {
        case .general: return "settings"
        case .models: return "cpu"
        case .permissions: return "lock"
        case .data: return "database"
        case .vault: return "package"
        case .runs: return "history"
        case .actions: return "sparkles"
        case .targets: return "target"
        case .about: return "info"
        }
    }

    /// SF Symbol for the settings sidebar.
    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .models: return "cpu"
        case .permissions: return "lock.fill"
        case .data: return "internaldrive"
        case .vault: return "archivebox"
        case .runs: return "clock"
        case .actions: return "sparkles"
        case .targets: return "target"
        case .about: return "info.circle"
        }
    }

    static let menu: [DashboardRoute] = [
        .general, .models, .permissions, .data,
        .vault, .runs, .actions, .targets
    ]

    /// Pinned under the scrollable sidebar. Not a setting and not a workspace.
    static let footer: [DashboardRoute] = [.about]

    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return true }
        return title.localizedCaseInsensitiveContains(q)
            || pageSubtitle.localizedCaseInsensitiveContains(q)
            || searchTerms.localizedCaseInsensitiveContains(q)
    }

    /// Workspace pages sit below the settings group in the sidebar.
    var isWorkspace: Bool {
        switch self {
        case .vault, .runs, .actions, .targets: return true
        default: return false
        }
    }
}
