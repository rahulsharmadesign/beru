import SwiftUI

// Moved out of Sources/Settings/SettingsView.swift, which held five
// unrelated pages in one 622-line file and no longer contained a
// SettingsView at all. These are dashboard pages, so they live with the
// dashboard; SettingsStore stays the single place they read and write.

/// Provider rows used on Models. Same store as the rest of settings.
struct ProviderSettingsSections: View {
    @Bindable private var settings = SettingsStore.shared
    @State private var testState: TestState = .idle
    @State private var anthropicKey: String = ""
    @State private var customKey: String = ""
    @State private var apiPreset: CompatibleAPIPreset = .groq

    enum TestState: Equatable {
        case idle, testing, success, failure(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BeruSpace.xxl) {
            SettingsSection(title: "Provider") {
                SettingsRow(
                    title: "Active provider",
                    caption: "Local Ollama stays on this Mac. Anthropic and API presets send requests to the host you configure."
                ) {
                    SettingsMenuPicker(
                        selection: Binding(
                            get: { settings.activeProvider },
                            set: { settings.selectProvider($0) }
                        ),
                        options: ProviderKind.allCases.map {
                            SettingsPickerOption(value: $0, title: $0.title)
                        },
                        accessibilityLabel: "Active provider"
                    )
                }
            }

            SettingsSection(title: "Configuration") {
                configurationRows
            }

            SettingsSection(title: "Connection") {
                SettingsRow(title: "Test connection", caption: testCaption) {
                    HStack(spacing: BeruSpace.sm) {
                        testStatusView
                        SettingsPillButton(title: "Test", enabled: testState != .testing) {
                            testConnection()
                        }
                    }
                }
            }
        }
        .onAppear {
            hydrateKeysForActiveProvider()
            apiPreset = Self.detectPreset(baseURL: settings.customBaseURL)
            if settings.activeProvider == .custom {
                if settings.customBaseURL.isEmpty {
                    applyAPIPreset(.groq)
                    apiPreset = .groq
                } else if apiPreset == .groq, settings.customEnhanceModel.isEmpty {
                    applyAPIPreset(.groq)
                }
            }
        }
        .onChange(of: settings.activeProvider) { _, kind in
            hydrateKeysForActiveProvider()
            if kind == .custom, settings.customBaseURL.isEmpty {
                applyAPIPreset(.groq)
                apiPreset = .groq
            }
        }
        .onChange(of: anthropicKey) { _, newValue in
            settings.anthropicAPIKey = newValue
        }
        .onChange(of: customKey) { _, newValue in
            settings.customAPIKey = newValue
        }
        .onChange(of: settings.customEnhanceModel) { oldValue, newValue in
            if settings.customGrammarModel.isEmpty || settings.customGrammarModel == oldValue {
                settings.customGrammarModel = newValue
            }
        }
    }

    /// Ollama has no secrets. Hitting Keychain on every Models visit is what
    /// raised "Beru wants to use your confidential information".
    private func hydrateKeysForActiveProvider() {
        switch settings.activeProvider {
        case .ollama:
            break
        case .anthropic:
            anthropicKey = settings.anthropicAPIKey ?? ""
        case .custom:
            customKey = settings.customAPIKey ?? ""
        }
    }

    @ViewBuilder
    private var configurationRows: some View {
        switch settings.activeProvider {
        case .ollama:
            SettingsRow(title: "Base URL") {
                SettingsField(placeholder: "http://127.0.0.1:11434/v1", text: $settings.ollamaBaseURL, width: BeruMetrics.wideFieldWidth)
            }
            SettingsRow(title: "Enhance model") {
                OllamaModelIDPicker(selection: $settings.ollamaEnhanceModel, accessibilityLabel: "Enhance model")
            }
            SettingsRow(title: "Grammar model") {
                OllamaModelIDPicker(selection: $settings.ollamaGrammarModel, accessibilityLabel: "Grammar model")
            }
        case .anthropic:
            SettingsRow(title: "API key", caption: "Stored in the Keychain on this Mac.") {
                SettingsSecretField(placeholder: "sk-ant-…", text: $anthropicKey, width: BeruMetrics.wideFieldWidth)
            }
        case .custom:
            SettingsRow(
                title: "Preset",
                caption: "Groq, OpenAI, OpenRouter, LM Studio, or any OpenAI-compatible /v1 API."
            ) {
                SettingsMenuPicker(
                    selection: $apiPreset,
                    options: CompatibleAPIPreset.allCases.map {
                        SettingsPickerOption(value: $0, title: $0.title)
                    },
                    accessibilityLabel: "API preset"
                )
                .onChange(of: apiPreset) { _, preset in
                    applyAPIPreset(preset)
                }
            }
            SettingsRow(title: "Base URL") {
                SettingsField(placeholder: "https://api.example.com/v1", text: $settings.customBaseURL, width: BeruMetrics.wideFieldWidth)
            }
            SettingsRow(title: "API key", caption: "Stored in the Keychain on this Mac.") {
                SettingsSecretField(placeholder: "sk-…", text: $customKey, width: BeruMetrics.wideFieldWidth)
            }
            SettingsRow(title: "Model") {
                SettingsField(placeholder: "Model id", text: $settings.customEnhanceModel)
            }
            SettingsRow(title: "Grammar model", caption: "Optional. Defaults to the same model.") {
                SettingsField(placeholder: "Optional", text: $settings.customGrammarModel)
            }
        }
    }

    private var testCaption: String {
        switch testState {
        case .idle: return "Sends a lightweight request to the selected provider."
        case .testing: return "Checking…"
        case .success: return "Connected."
        case .failure(let message): return message
        }
    }

    private func applyAPIPreset(_ preset: CompatibleAPIPreset) {
        guard preset != .custom else { return }
        settings.customBaseURL = preset.baseURL
        settings.customEnhanceModel = preset.defaultModel
        settings.customGrammarModel = preset.defaultModel
    }

    private static func detectPreset(baseURL: String) -> CompatibleAPIPreset {
        let url = baseURL.lowercased()
        if url.contains("api.groq.com") { return .groq }
        if url.contains("api.openai.com") { return .openAI }
        if url.contains("openrouter.ai") { return .openRouter }
        if url.isEmpty { return .groq }
        return .custom
    }

    @ViewBuilder
    private var testStatusView: some View {
        switch testState {
        case .idle:
            EmptyView()
        case .testing:
            BeruLoader.compact(tint: BeruColor.accent)
        case .success:
            BeruIcon(name: "circle-check", size: BeruMetrics.iconSize)
                .foregroundStyle(BeruColor.positive)
        case .failure:
            BeruIcon(name: "circle-x", size: BeruMetrics.iconSize)
                .foregroundStyle(BeruColor.destructive)
        }
    }

    private func testConnection() {
        testState = .testing
        Task {
            let provider = ProviderRegistry.activeProvider(settings: settings)
            let result = await provider.testConnection()
            switch result {
            case .success:
                testState = .success
            case .failure(let error):
                testState = .failure(error.userMessage)
            }
        }
    }
}
