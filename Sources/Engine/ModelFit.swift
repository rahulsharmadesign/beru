import Foundation

// Whether a model id is a good fit for Beru's text roles (Enhance, Grammar,
// Smart Reply). Pure name matching, so it is unit-testable and runs without
// touching the server.
//
// Vision, embedding, speech, and guard models all pull cleanly from Ollama
// and then fail Beru's jobs in confusing ways: a vision model drafts replies
// from its prompt vocabulary ("smart reply footer") and ignores bans the
// tagged formats rely on. Flagging the mismatch where the model is picked
// beats debugging the output later.

enum ModelFit: Equatable {
    case good
    case weak(kind: WeakKind)

    enum WeakKind: Equatable {
        case vision
        case embedding
        case speech
        case guardrail
    }

    /// One-line caption for the Models list. Nil when the model is fine.
    var warning: String? {
        switch self {
        case .good:
            return nil
        case .weak(let kind):
            switch kind {
            case .vision:
                return "Vision model — weak at Beru's text tasks"
            case .embedding:
                return "Embedding model — cannot generate text"
            case .speech:
                return "Speech model — cannot do Beru's text tasks"
            case .guardrail:
                return "Filter model — cannot do Beru's text tasks"
            }
        }
    }

    /// Noun phrase for composed sentences ("X is a vision model").
    var articleNoun: String? {
        switch self {
        case .good:
            return nil
        case .weak(let kind):
            switch kind {
            case .vision:
                return "a vision model"
            case .embedding:
                return "an embedding model"
            case .speech:
                return "a speech model"
            case .guardrail:
                return "a filter model"
            }
        }
    }
}

enum OllamaModelFit {
    /// Classifies by id substring, lowercased. Deliberately narrow: an
    /// instruct or reasoning text model must never be flagged.
    static func fit(for modelID: String) -> ModelFit {
        let id = modelID.lowercased()
        // Specific function before family name: "mxbai-rerank-large" is a
        // reranker that happens to carry an embedding-family name.
        if visionMarkers.contains(where: id.contains) { return .weak(kind: .vision) }
        if speechMarkers.contains(where: id.contains) { return .weak(kind: .speech) }
        if guardrailMarkers.contains(where: id.contains) { return .weak(kind: .guardrail) }
        if embeddingMarkers.contains(where: id.contains) { return .weak(kind: .embedding) }
        return .good
    }

    /// Roles Enhanced by `modelID`, for the Models banner. Empty when fine.
    static func weakRoles(enhanceModel: String, grammarModel: String) -> [String] {
        var roles: [String] = []
        if fit(for: enhanceModel) != .good { roles.append("Enhance") }
        if fit(for: grammarModel) != .good { roles.append("Grammar") }
        return roles
    }

    private static let visionMarkers = [
        "-vl", "vl:", "vision", "llava", "moondream", "bakllava", "minicpm-v",
    ]

    private static let embeddingMarkers = [
        "embed", "bge", "e5-", "e5:", "snowflake", "nomic", "mxbai", "gte-", "gte:",
    ]

    private static let speechMarkers = [
        "whisper", "parakeet", "canary", "kokoro", "piper", "-tts", ":tts", "-stt", ":stt",
    ]

    private static let guardrailMarkers = [
        "guard", "rerank", "shieldgemma", "shield-gemma",
    ]
}
