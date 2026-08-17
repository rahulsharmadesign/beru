import Foundation

enum ProviderError: Error, Equatable {
    case invalidAPIKey
    case rateLimited
    case connectionFailed(String)
    case badResponse(String)
    case cancelled

    var userMessage: String {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key — check Settings"
        case .rateLimited:
            return "Rate limited — try again"
        case .connectionFailed(let hint):
            return hint
        case .badResponse(let message):
            return message
        case .cancelled:
            return "Cancelled"
        }
    }
}

/// A single piece of a model response. Reasoning models emit a "thinking"
/// preamble that must never reach the user's document, but must still be
/// visible as a state — a silently discarded reasoning stream is
/// indistinguishable from a hung request.
enum StreamChunk: Sendable, Equatable {
    case content(String)
    case reasoning(String)
}

protocol LLMProvider: Sendable {
    /// `expectsRationale` only sizes the output ceiling — the instruction itself
    /// is already in the system prompt. It has to be passed explicitly because
    /// the provider cannot otherwise know that the response carries an
    /// explanation on top of the result.
    func stream(
        system: String,
        user: String,
        role: ModelRole,
        expectsRationale: Bool
    ) -> AsyncThrowingStream<StreamChunk, Error>
    func testConnection() async -> Result<Void, ProviderError>
    /// Best-effort pre-loading of the model this role will use, so the first
    /// real request doesn't pay a cold start. Default is a no-op; only local
    /// providers implement it.
    func warmUp(role: ModelRole) async
}

extension LLMProvider {
    func warmUp(role: ModelRole) async {}

    /// Convenience for callers with no rationale to account for.
    func stream(system: String, user: String, role: ModelRole) -> AsyncThrowingStream<StreamChunk, Error> {
        stream(system: system, user: user, role: role, expectsRationale: false)
    }
}

/// Rewriting and editing need stable instruction-following, not creative
/// variance: grammar is fully deterministic, enhance keeps mild variation so
/// Regenerate produces alternatives.
enum ProviderTuning {
    static func temperature(for role: ModelRole) -> Double {
        switch role {
        case .enhance: return 0.3
        case .grammar: return 0.0
        }
    }

    /// Output length tracks input length, so size the cap to the input rather
    /// than a fixed number — long selections near the 8k-char capture cap
    /// would otherwise be truncated mid-result.
    ///
    /// A rationale is a fixed couple of sentences whatever the input length, so
    /// it is headroom added on top of the ceiling rather than a share of it.
    /// Without this, Grammar's 500-token floor would clamp a short message plus
    /// its explanation mid-sentence.
    static let rationaleHeadroom = 200

    static func maxTokens(for role: ModelRole, input: String, expectsRationale: Bool = false) -> Int {
        let estimated = input.count / 3
        let base: Int
        switch role {
        case .enhance:
            base = max(1500, estimated + 300)
        case .grammar:
            base = max(500, estimated + 200)
        }
        return min(4000, base) + (expectsRationale ? rationaleHeadroom : 0)
    }
}

enum ProviderHTTP {
    /// Allowed gap between bytes, not total duration. Generous enough to cover
    /// a cold model load before the first token arrives.
    static let requestTimeout: TimeInterval = 60
    /// Ceiling on a whole streamed response. Must be far above requestTimeout:
    /// applying the same 30s to both silently truncated long generations.
    static let resourceTimeout: TimeInterval = 600

    // One shared session so HTTP/2 connections (and their TLS handshakes) are
    // reused across invocations instead of re-established per request.
    private static let sharedSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = requestTimeout
        config.timeoutIntervalForResource = resourceTimeout
        return URLSession(configuration: config)
    }()

    static func session() -> URLSession {
        sharedSession
    }

    /// Chat-completions URL for an OpenAI-compatible base. Only `http` and
    /// `https` are accepted — `file:`, `unix:`, and similar schemes are rejected
    /// so a pasted URL cannot be used to read local files or sockets.
    static func chatCompletionsURL(from baseURL: String) throws -> URL {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let hint = "The base URL in Settings isn't a usable address — it should look like http://localhost:11434/v1"
        guard !trimmed.isEmpty, let url = URL(string: trimmed + "/chat/completions") else {
            throw ProviderError.connectionFailed(hint)
        }
        try requireHTTPScheme(url)
        guard url.host != nil else {
            throw ProviderError.connectionFailed(hint)
        }
        return url
    }

    static func requireHTTPScheme(_ url: URL) throws {
        let scheme = url.scheme?.lowercased() ?? ""
        guard scheme == "http" || scheme == "https" else {
            throw ProviderError.connectionFailed("The base URL must start with http:// or https://")
        }
    }

    /// Splits a raw SSE byte stream into individual `data: ...` payload lines.
    static func sseLines(from bytes: URLSession.AsyncBytes) -> AsyncStream<String> {
        AsyncStream { continuation in
            let task = Task {
                do {
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        continuation.yield(payload)
                    }
                } catch {
                    // Stream ended or was cancelled; finish normally either way.
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
