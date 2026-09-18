import Foundation

// Which provider to talk to and the presets for reaching one. These describe
// the engine's capabilities, not how settings are stored, so they no longer
// sit at the top of SettingsStore.

enum ProviderKind: String, CaseIterable, Codable {
    case ollama
    case anthropic
    case custom
    /// Apple's on-device model (Foundation Models). Zero install, no key, and
    /// selected text never leaves this Mac. The first-launch default wherever
    /// this Mac can answer; Ollama stays the fallback.
    case apple

    var title: String {
        switch self {
        case .ollama: return "Ollama (local)"
        case .anthropic: return "Anthropic"
        case .custom: return "API (Groq, OpenAI, …)"
        case .apple: return "Apple · on-device"
        }
    }

    /// One-line quality caveat for the Settings row, or nil when the provider
    /// carries the full prompts. Apple on-device is the general-purpose ~3B
    /// base model — not the task-adapted models behind Apple's own Writing
    /// Tools — so Beru serves it the simplified prompts and says so here, the
    /// same honesty `ModelFit` gives a small Ollama model at pick time.
    var qualityCaption: String? {
        switch self {
        case .apple:
            return "On-device runs simplified prompts: Grammar returns one corrected version and Enhance skips target, context, and explanation. For the full features, pick Anthropic or an API model."
        case .ollama, .anthropic, .custom:
            return nil
        }
    }
}

/// One-click base URL + model defaults for common OpenAI-compatible hosts.
///
/// ## Groq Integration
/// Groq provides exceptionally fast inference (typically 200-500 tokens/second)
/// on their LPU (Language Processing Unit) infrastructure. The free tier offers
/// generous rate limits suitable for personal use:
/// - 30 requests/minute
/// - 14,400 requests/day
/// - 6,000 tokens/minute
///
/// For Beru's text enhancement use case, this is more than sufficient. Groq
/// retired `llama-3.3-70b-versatile` on 16 Aug 2026; `openai/gpt-oss-120b`
/// is the production replacement.
enum CompatibleAPIPreset: String, CaseIterable, Identifiable {
    case groq
    case openAI
    case openRouter
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .groq: return "Groq"
        case .openAI: return "OpenAI"
        case .openRouter: return "OpenRouter"
        case .custom: return "Custom URL"
        }
    }

    var baseURL: String {
        switch self {
        case .groq: return "https://api.groq.com/openai/v1"
        case .openAI: return "https://api.openai.com/v1"
        case .openRouter: return "https://openrouter.ai/api/v1"
        case .custom: return ""
        }
    }

    /// Sensible default model id; user can edit after applying.
    var defaultModel: String {
        switch self {
        case .groq: return "openai/gpt-oss-120b"
        case .openAI: return "gpt-4o-mini"
        case .openRouter: return "openai/gpt-4o-mini"
        case .custom: return ""
        }
    }

    /// Groq ids that 404 as of the 16 Aug 2026 deprecation. Existing installs
    /// that still have these saved are rewritten to `defaultModel`.
    static let retiredGroqModels: Set<String> = [
        "llama-3.3-70b-versatile",
        "llama-3.1-8b-instant",
        "llama-3.1-70b-versatile",
        "llama3-70b-8192",
        "llama3-8b-8192"
    ]

    /// Which preset a saved base URL corresponds to. Unknown hosts stay
    /// Custom so a typed URL is never overwritten on the next Settings visit.
    static func matching(baseURL: String) -> CompatibleAPIPreset {
        let url = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if url.isEmpty { return .groq }
        if url.contains("api.groq.com") { return .groq }
        if url.contains("api.openai.com") { return .openAI }
        if url.contains("openrouter.ai") { return .openRouter }
        return .custom
    }
}
