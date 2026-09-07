import SwiftUI

/// Menu of recommended Ollama ids plus the current value if it is custom.
struct OllamaModelIDPicker: View {
    @Binding var selection: String
    var accessibilityLabel: String

    private var options: [SettingsPickerOption<String>] {
        var list = RecommendedOllamaModel.all.map {
            SettingsPickerOption(value: $0.name, title: $0.title)
        }
        if !RecommendedOllamaModel.all.contains(where: { $0.name == selection }),
           !selection.isEmpty {
            list.append(SettingsPickerOption(value: selection, title: selection))
        }
        return list
    }

    var body: some View {
        SettingsMenuPicker(
            selection: $selection,
            options: options,
            accessibilityLabel: accessibilityLabel
        )
    }
}
