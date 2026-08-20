import Foundation

/// Catalog of local models Beru recommends for Ollama. Shared by the Models
/// install list and the Enhance/Grammar pickers so an advertised option like
/// Gemma 3 1B actually appears as a selectable setting.
struct RecommendedOllamaModel: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let title: String
    let size: String
    let note: String

    var isDefault: Bool { name == Self.defaultID }

    /// "Default" is derived, never typed into `note`. It used to be, on the
    /// wrong entry, so the install list advertised one model as the default
    /// while the setting shipped another.
    var caption: String {
        isDefault ? "\(size) · Default. \(note)" : "\(size) · \(note)"
    }

    /// The shipped default, in one place. SettingsStore hardcoded this id twice
    /// and OllamaPullService a third time.
    static let defaultID = "qwen2.5:7b"

    /// Gemma first so the lightweight option from the Tip is visible without scrolling.
    static let all: [RecommendedOllamaModel] = [
        RecommendedOllamaModel(
            name: "gemma3:1b",
            title: "Gemma 3 1B",
            size: "~815 MB",
            note: "Lightweight. Fits the widget."
        ),
        RecommendedOllamaModel(
            name: "qwen3:8b",
            title: "Qwen 3 8B",
            size: "~5 GB",
            note: "Strongest of the three. Reasoning suppressed automatically."
        ),
        RecommendedOllamaModel(
            name: "qwen2.5:7b",
            title: "Qwen 2.5 7B",
            size: "~4.7 GB",
            note: "No reasoning pass; faster first token."
        )
    ]
}
