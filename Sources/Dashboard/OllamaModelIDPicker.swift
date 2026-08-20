import SwiftUI

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
