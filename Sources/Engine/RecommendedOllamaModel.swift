import Foundation

/// The shipped default local model id, in one place. SettingsStore reads it
/// rather than repeating the string.
///
/// There used to be a three-model install catalog here (Gemma 3 1B, Qwen 3 8B,
/// Qwen 2.5 7B) driving an in-app installer. It is gone on purpose: the 1B
/// entry was too weak for Enhance/Grammar for the app to recommend, and
/// downloading belongs to the Ollama app / `ollama pull` in Terminal, where
/// file variants and sizes are visible. Any installed id can be typed into
/// Settings → Models; this id is only the fresh-install default.
enum RecommendedOllamaModel {
    /// One 7B-class model serving both roles: two different models make
    /// Ollama swap weights in and out when the user switches tabs.
    static let defaultID = "qwen2.5:7b"
}
