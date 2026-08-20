import Foundation

/// OpenAI-compatible chat completions provider — works against Ollama, Groq,
/// LM Studio, or any other endpoint that speaks the same wire format.
struct OpenAICompatProvider: LLMProvider {
    let baseURL: String
    let apiKey: String?
    let enhanceModel: String
    let grammarModel: String

    var parsedURL: URL? {
        URL(string: baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    /// Any server on this machine. Local endpoints share a set of quirks —
    /// reasoning templates that need switching off, and a "nothing is
    /// listening" failure mode that a remote host doesn't have.
    var isLoopback: Bool {
        guard let host = parsedURL?.host?.lowercased() else { return false }
        return ["localhost", "127.0.0.1", "::1", "[::1]", "0.0.0.0"].contains(host)
            || host.hasSuffix(".localhost")
    }

    /// Ollama specifically, identified by its port. Loopback alone is not
    /// enough: LM Studio, llama.cpp, and vLLM all live here too, and telling
    /// someone to run `ollama serve` when their LM Studio server is down sends
    /// them to the wrong place entirely.
    var isOllama: Bool {
        isLoopback && parsedURL?.port == 11434
    }

    /// host:port, for error messages that have to be actionable. Never the full
    /// URL — a custom base URL can carry credentials in its userinfo.
    var displayHost: String {
        guard let url = parsedURL, let host = url.host else { return "the configured server" }
        return url.port.map { "\(host):\($0)" } ?? host
    }

    var serverLabel: String {
        if isOllama { return "Ollama" }
        if isLoopback { return "The local server at \(displayHost)" }
        return displayHost
    }

    func model(for role: ModelRole) -> String {
        switch role {
        case .enhance: return enhanceModel
        case .grammar: return grammarModel
        }
    }

    func endpoint() throws -> URL {
        try ProviderHTTP.chatCompletionsURL(from: baseURL)
    }

    /// Ollama's native generate endpoint, derived by dropping a trailing /v1
    /// from the OpenAI-compatible base URL. Returns nil when the URL doesn't
    /// have that shape, so a non-Ollama local server is never poked.
    func nativeGenerateURL() -> URL? {
        var trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard trimmed.hasSuffix("/v1") else { return nil }
        trimmed.removeLast("/v1".count)
        return URL(string: trimmed + "/api/generate")
    }

    /// Reasoning models emit a chain-of-thought pass before any answer. For
    /// short editing tasks that is pure latency, so it is switched off.
    static func isReasoningModel(_ modelID: String) -> Bool {
        let id = modelID.lowercased()
        return ["qwen3", "deepseek-r1", "gpt-oss", "magistral", "thinking"].contains { id.contains($0) }
    }

    /// Groq's gpt-oss models reject `none` (only `low` / `medium` / `high`).
    /// Qwen-style templates honor `none`.
    static func reasoningEffort(for modelID: String) -> String {
        modelID.lowercased().contains("gpt-oss") ? "low" : "none"
    }

    /// OpenAI-compatible `{ "error": { "message": "..." } }` body, if present.
    static func openAIErrorMessage(from data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let error = obj["error"] as? [String: Any],
           let message = error["message"] as? String,
           !message.isEmpty {
            return message
        }
        if let message = obj["error"] as? String, !message.isEmpty {
            return message
        }
        return nil
    }

    /// How long Ollama should keep weights resident after a request.
    static let keepAlive = "30m"

    func requestBody(
        system: String,
        user: String,
        role: ModelRole,
        suppressThinking: Bool,
        expectsRationale: Bool
    ) -> [String: Any] {
        var body: [String: Any] = [
            "model": model(for: role),
            "stream": true,
            "temperature": ProviderTuning.temperature(for: role),
            // Random seed per request: some servers reuse a fixed sampling
            // seed, which makes even nonzero temperatures produce identical
            // output for identical input.
            "seed": Int.random(in: 0..<Int(Int32.max)),
            "max_tokens": ProviderTuning.maxTokens(
                for: role,
                input: user,
                expectsRationale: expectsRationale
            ),
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
        ]
        if suppressThinking {
            // Verified against Ollama's qwen3 template: reasoning_effort is
            // honored, while the older "/no_think" prompt suffix and
            // chat_template_kwargs are both ignored. Sent to every local
            // server, not just Ollama, because chat_template_kwargs is the
            // documented switch on LM Studio and llama.cpp.
            // Groq gpt-oss does not accept `none` — only low/medium/high.
            body["reasoning_effort"] = Self.reasoningEffort(for: model(for: role))
            if isLoopback {
                body["chat_template_kwargs"] = ["enable_thinking": false]
            }
        }
        return body
    }

    func stream(
        system: String,
        user: String,
        role: ModelRole,
        expectsRationale: Bool
    ) -> AsyncThrowingStream<StreamChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = try endpoint()
                    let modelID = model(for: role)
                    var suppressThinking = isLoopback || Self.isReasoningModel(modelID)
                    var retriedTransport = false

                    var bytes: URLSession.AsyncBytes
                    var response: URLResponse
                    while true {
                        var request = URLRequest(url: url)
                        request.httpMethod = "POST"
                        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        if let apiKey, !apiKey.isEmpty {
                            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                        }
                        request.httpBody = try JSONSerialization.data(
                            withJSONObject: requestBody(
                                system: system,
                                user: user,
                                role: role,
                                suppressThinking: suppressThinking,
                                expectsRationale: expectsRationale
                            )
                        )

                        do {
                            (bytes, response) = try await ProviderHTTP.session().bytes(for: request)
                        } catch {
                            // The session pools keep-alive sockets, and a local
                            // model server closes them when it goes idle. The
                            // first request onto a socket the server has
                            // already dropped fails at the transport layer and
                            // URLSession surfaces it rather than retrying — it
                            // looks exactly like "the server is down" even
                            // though the next attempt connects fine. Nothing
                            // has been streamed yet, so one repeat is safe.
                            if !retriedTransport, !Task.isCancelled, Self.isTransientTransportFailure(error) {
                                retriedTransport = true
                                try? await Task.sleep(for: .milliseconds(120))
                                continue
                            }
                            throw connectionError(error)
                        }

                        // A server that rejects the thinking-suppression keys
                        // does so before generating anything, so retrying once
                        // without them costs a round trip and keeps the
                        // parameter safe to send to unknown endpoints.
                        if suppressThinking, let http = response as? HTTPURLResponse,
                           http.statusCode == 400 || http.statusCode == 422 {
                            suppressThinking = false
                            continue
                        }
                        break
                    }
                    try validate(response: response)

                    for await payload in ProviderHTTP.sseLines(from: bytes) {
                        if Task.isCancelled { break }
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8),
                              let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = event["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any] else {
                            continue
                        }
                        // Order matters: Ollama sends an empty "content"
                        // alongside every reasoning delta, so content must be
                        // checked for emptiness before falling through.
                        if let content = delta["content"] as? String, !content.isEmpty {
                            continuation.yield(.content(content))
                        } else if let reasoning = (delta["reasoning"] ?? delta["reasoning_content"]) as? String,
                                  !reasoning.isEmpty {
                            continuation.yield(.reasoning(reasoning))
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: ProviderError.cancelled)
                } catch let error as ProviderError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: ProviderError.connectionFailed(error.localizedDescription))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Loads model weights ahead of the first real request and pins them in
    /// memory. Ollama ignores keep_alive on the OpenAI-compatible endpoint, so
    /// this uses the native generate endpoint with no prompt: it returns
    /// done_reason "load" in milliseconds when the model is already resident.
}
