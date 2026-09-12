import Foundation

/// How a cloud API key is resolved for a custom (OpenAI-compatible) or
/// Anthropic connector. Keychain wins; the environment is a launch-time
/// fallback so a connector can run without pasting the secret into Settings.
///
/// Never persist an environment value from here — `SettingsStore` writes
/// Keychain only when the user edits the field.
enum ProviderAPIKey {
    /// OpenAI-compatible hosts (Groq, OpenAI, OpenRouter, custom `/v1`).
    static let environmentVariable = "BERU_API_KEY"
    /// Anthropic Messages API.
    static let anthropicEnvironmentVariable = "BERU_ANTHROPIC_API_KEY"

    /// Trimmed non-empty value from `environment`, or nil.
    nonisolated static func fromEnvironment(
        name: String = environmentVariable,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String? {
        guard let raw = environment[name] else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Keychain (or other stored) value first; environment if that is empty.
    nonisolated static func resolved(stored: String?, fallback: String?) -> String? {
        if let stored {
            let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        if let fallback {
            let trimmed = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }
}
