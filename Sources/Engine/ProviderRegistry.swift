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
            return AnthropicProvider(apiKey: settings.resolvedAnthropicAPIKey ?? "")
        case .custom:
            return OpenAICompatProvider(
                baseURL: settings.customBaseURL,
                apiKey: settings.resolvedCustomAPIKey,
                enhanceModel: settings.customEnhanceModel,
                grammarModel: settings.customGrammarModel
            )
        }
    }
}
