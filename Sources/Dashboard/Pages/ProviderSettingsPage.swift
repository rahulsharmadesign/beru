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
        VStack(alignment: .leading, spacing: 32) {
            SettingsSection(title: "Provider", subtitle: "Which backend Beru sends requests to.") {
                SettingsRow(
                    title: "Active provider",
                    caption: "Local Ollama stays on this Mac. Anthropic and API presets send requests to the host you configure."
                ) {
                    Picker("", selection: Binding(
                        get: { settings.activeProvider },
                        set: { settings.selectProvider($0) }
                    )) {
                        ForEach(ProviderKind.allCases, id: \.self) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .labelsHidden()
                    .accessibilityLabel("Active provider")
                    .pickerStyle(.menu)
                    .fixedSize()
                }
            }

            SettingsSection(title: "Configuration", subtitle: "Host, credentials, and model ids for the active provider.") {
                configurationRows
            }

            SettingsSection(title: "Connection", subtitle: "Verify the provider responds before you run.") {
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
            SettingsRow(title: "Base URL", caption: "Ollama or any compatible /v1 host.") {
                SettingsField(placeholder: "http://127.0.0.1:11434/v1", text: $settings.ollamaBaseURL, width: 260)
            }
            SettingsRow(title: "Enhance model", caption: "Local Ollama tag used for Enhance Prompt.") {
                OllamaModelIDPicker(selection: $settings.ollamaEnhanceModel, accessibilityLabel: "Enhance model")
            }
            SettingsRow(title: "Grammar model", caption: "Local Ollama tag used for Grammar.") {
                OllamaModelIDPicker(selection: $settings.ollamaGrammarModel, accessibilityLabel: "Grammar model")
            }
        case .anthropic:
            SettingsRow(title: "API key", caption: "Stored in the Keychain on this Mac.") {
                SettingsSecretField(placeholder: "sk-ant-…", text: $anthropicKey, width: 260)
            }
        case .custom:
            SettingsRow(
                title: "Preset",
                caption: "Groq, OpenAI, OpenRouter, LM Studio, or any OpenAI-compatible /v1 API."
            ) {
                Picker("", selection: $apiPreset) {
                    ForEach(CompatibleAPIPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .labelsHidden()
                .accessibilityLabel("API preset")
                .pickerStyle(.menu)
                .fixedSize()
                .onChange(of: apiPreset) { _, preset in
                    applyAPIPreset(preset)
                }
            }
            SettingsRow(title: "Base URL") {
                SettingsField(placeholder: "https://api.example.com/v1", text: $settings.customBaseURL, width: 260)
            }
            SettingsRow(title: "API key", caption: "Stored in the Keychain on this Mac.") {
                SettingsSecretField(placeholder: "sk-…", text: $customKey, width: 260)
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
            ProgressView().controlSize(.small)
        case .success:
            BeruIcon(name: "circle-check", size: 16)
                .foregroundStyle(SettingsTheme.active)
        case .failure:
            BeruIcon(name: "circle-x", size: 16)
                .foregroundStyle(SettingsTheme.textSecondary)
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
