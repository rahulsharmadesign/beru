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
    /// Bumped when a named preset writes URL/model so AppKit text fields remount.
    @State private var fieldStamp = 0

    enum TestState: Equatable {
        case idle, testing, success, failure(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BeruSpace.xxl) {
            SettingsSection(title: "Provider") {
                SettingsRow(
                    title: "Active provider",
                    caption: "Apple on-device and local Ollama stay on this Mac. Anthropic and API presets send requests to the host you configure."
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
            apiPreset = CompatibleAPIPreset.matching(baseURL: settings.customBaseURL)
            if settings.activeProvider == .custom {
                if settings.customBaseURL.isEmpty {
                    applyAPIPreset(.groq)
                } else if apiPreset == .groq, settings.customEnhanceModel.isEmpty {
                    applyAPIPreset(.groq)
                }
            }
        }
        .onChange(of: settings.activeProvider) { _, kind in
            hydrateKeysForActiveProvider()
            if kind == .custom, settings.customBaseURL.isEmpty {
                applyAPIPreset(.groq)
            }
        }
        .onChange(of: anthropicKey) { _, newValue in
            settings.anthropicAPIKey = newValue
        }
        .onChange(of: customKey) { _, newValue in
            settings.customAPIKey = newValue
        }
        .onChange(of: settings.customBaseURL) { _, url in
            let detected = CompatibleAPIPreset.matching(baseURL: url)
            if detected != apiPreset {
                apiPreset = detected
            }
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
        case .ollama, .apple:
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
            SettingsRow(
                title: "API key",
                caption: "Stored in the Keychain. If empty, BERU_ANTHROPIC_API_KEY is used when Beru is launched from a terminal."
            ) {
                SettingsSecretField(placeholder: "sk-ant-…", text: $anthropicKey, width: BeruMetrics.wideFieldWidth)
            }
        case .apple:
            appleConfigurationRows
        case .custom:
            SettingsRow(
                title: "Preset",
                caption: "Groq, OpenAI, OpenRouter, LM Studio, or any OpenAI-compatible /v1 API."
            ) {
                SettingsMenuPicker(
                    selection: Binding(
                        get: { apiPreset },
                        set: { applyAPIPreset($0) }
                    ),
                    options: CompatibleAPIPreset.allCases.map {
                        SettingsPickerOption(value: $0, title: $0.title)
                    },
                    accessibilityLabel: "API preset"
                )
            }
            SettingsRow(title: "Base URL") {
                SettingsField(
                    placeholder: "https://api.example.com/v1",
                    text: $settings.customBaseURL,
                    width: BeruMetrics.wideFieldWidth
                )
                .id("base-\(fieldStamp)")
            }
            SettingsRow(
                title: "API key",
                caption: "Stored in the Keychain. If empty, BERU_API_KEY is used when Beru is launched from a terminal."
            ) {
                SettingsSecretField(placeholder: "sk-…", text: $customKey, width: BeruMetrics.wideFieldWidth)
            }
            SettingsRow(title: "Model") {
                SettingsField(placeholder: "Model id", text: $settings.customEnhanceModel)
                    .id("enhance-\(fieldStamp)")
            }
            SettingsRow(title: "Grammar model", caption: "Optional. Defaults to the same model.") {
                SettingsField(placeholder: "Optional", text: $settings.customGrammarModel)
                    .id("grammar-\(fieldStamp)")
            }
        }
    }

    /// Apple owns the model, so there is nothing to type: one status row with
    /// the live availability and one row naming the usage-attribution id.
    /// Kept separate so the `switch` above stays a single view per case.
    private var appleConfigurationRows: some View {
        let state = AppleModelState.current()
        return Group {
            SettingsRow(
                title: "On-device model",
                caption: state.summary
            ) {
                SettingsStatusBadge(title: state.badge, isPositive: state.isReady)
            }
            SettingsRow(
                title: "Model",
                caption: "The system owns the model — there is nothing to install or pick."
            ) {
                SettingsValue(text: AppleOnDeviceProvider.modelID, mono: true)
            }
        }
    }

    private var testCaption: String {
        if settings.activeProvider == .apple {
            switch testState {
            case .idle: return "Checks whether Apple's on-device model is available on this Mac."
            case .testing: return "Checking…"
            case .success: return "Connected."
            case .failure(let message): return message
            }
        }
        switch testState {
        case .idle: return "Sends a lightweight request to the selected provider."
        case .testing: return "Checking…"
        case .success: return "Connected."
        case .failure(let message): return message
        }
    }

    private func applyAPIPreset(_ preset: CompatibleAPIPreset) {
        apiPreset = preset
        guard preset != .custom else { return }
        settings.customBaseURL = preset.baseURL
        settings.customEnhanceModel = preset.defaultModel
        settings.customGrammarModel = preset.defaultModel
        fieldStamp += 1
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
