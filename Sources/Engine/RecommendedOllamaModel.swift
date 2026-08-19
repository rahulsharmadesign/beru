import SwiftUI

/// Catalog of local models Beru recommends for Ollama. Shared by the Models
/// install list and the Enhance/Grammar pickers so a advertised option like
/// Gemma 3 1B actually appears as a selectable setting.
struct RecommendedOllamaModel: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let title: String
    let size: String
    let note: String

    var caption: String { "\(size) · \(note)" }

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
            note: "Default. Reasoning suppressed automatically."
        ),
        RecommendedOllamaModel(
            name: "qwen2.5:7b",
            title: "Qwen 2.5 7B",
            size: "~4.7 GB",
            note: "No reasoning pass; slightly faster first token."
        )
    ]
}

/// Menu of recommended Ollama ids plus the current value if it is custom.
struct OllamaModelIDPicker: View {
    @Binding var selection: String
    var accessibilityLabel: String

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(RecommendedOllamaModel.all) { item in
                Text(item.title).tag(item.name)
            }
            if !RecommendedOllamaModel.all.contains(where: { $0.name == selection }),
               !selection.isEmpty {
                Text(selection).tag(selection)
            }
        }
        .labelsHidden()
        .accessibilityLabel(accessibilityLabel)
        .pickerStyle(.menu)
        .fixedSize()
    }
}
