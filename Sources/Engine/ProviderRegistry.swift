import Foundation

@MainActor
enum ProviderRegistry {
    static func activeProvider(settings: SettingsStore = .shared) -> LLMProvider {
        switch settings.activeProvider {
        case .ollama:
            return OpenAICompatProvider(
                baseURL: settings.ollamaBaseURL,
                apiKey: nil,
                enhanceModel: settings.ollamaEnhanceModel,
                grammarModel: settings.ollamaGrammarModel
            )
        case .anthropic:
            return AnthropicProvider(apiKey: settings.anthropicAPIKey ?? "")
        case .custom:
            return OpenAICompatProvider(
                baseURL: settings.customBaseURL,
                apiKey: settings.customAPIKey,
                enhanceModel: settings.customEnhanceModel,
                grammarModel: settings.customGrammarModel
            )
        }
    }
}
