import SwiftUI

/// A destination in the dashboard sidebar.
enum DashboardRoute: String, Identifiable, CaseIterable, Hashable {
    case general
    case models
    case permissions
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .models: return "Models"
        case .permissions: return "Permissions"
        case .about: return "About"
        }
    }

    var pageSubtitle: String {
        switch self {
        case .general: return "Global preferences for Enhancify."
        case .models: return "Choose a local or cloud provider and the models it should use."
        case .permissions: return "Accessibility and dictation."
        case .about: return "This build, and how to reach the person who made it."
        }
    }

    /// Stored icon id (may be Lucide kebab-case). `BeruIcon` maps it to SF Symbols.
    var lucideIcon: String {
        switch self {
        case .general: return "settings"
        case .models: return "cpu"
        case .permissions: return "lock"
        case .about: return "info"
        }
    }

    /// SF Symbol for the settings sidebar.
    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .models: return "cpu"
        case .permissions: return "lock.fill"
        case .about: return "info.circle"
        }
    }

    static let menu: [DashboardRoute] = [.general, .models, .permissions]

    /// Pinned under the sidebar.
    static let footer: [DashboardRoute] = [.about]
}
