import Foundation

/// OpenAI-compatible chat completions provider — works against Ollama, Groq,
/// LM Studio, or any other endpoint that speaks the same wire format.
struct OpenAICompatProvider: LLMProvider {
    let baseURL: String
    let apiKey: String?
    let enhanceModel: String
    let grammarModel: String

    private var parsedURL: URL? {
        URL(string: baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    /// Any server on this machine. Local endpoints share a set of quirks —
    /// reasoning templates that need switching off, and a "nothing is
    /// listening" failure mode that a remote host doesn't have.
    private var isLoopback: Bool {
        guard let host = parsedURL?.host?.lowercased() else { return false }
        return ["localhost", "127.0.0.1", "::1", "[::1]", "0.0.0.0"].contains(host)
            || host.hasSuffix(".localhost")
    }

    /// Ollama specifically, identified by its port. Loopback alone is not
    /// enough: LM Studio, llama.cpp, and vLLM all live here too, and telling
    /// someone to run `ollama serve` when their LM Studio server is down sends
    /// them to the wrong place entirely.
    private var isOllama: Bool {
        isLoopback && parsedURL?.port == 11434
    }

    /// host:port, for error messages that have to be actionable. Never the full
    /// URL — a custom base URL can carry credentials in its userinfo.
    private var displayHost: String {
        guard let url = parsedURL, let host = url.host else { return "the configured server" }
        return url.port.map { "\(host):\($0)" } ?? host
    }

    private var serverLabel: String {
        if isOllama { return "Ollama" }
        if isLoopback { return "The local server at \(displayHost)" }
        return displayHost
    }

    private func model(for role: ModelRole) -> String {
        switch role {
        case .enhance: return enhanceModel
        case .grammar: return grammarModel
        }
    }

    private func endpoint() throws -> URL {
        try ProviderHTTP.chatCompletionsURL(from: baseURL)
    }

    /// Ollama's native generate endpoint, derived by dropping a trailing /v1
    /// from the OpenAI-compatible base URL. Returns nil when the URL doesn't
    /// have that shape, so a non-Ollama local server is never poked.
    private func nativeGenerateURL() -> URL? {
        var trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard trimmed.hasSuffix("/v1") else { return nil }
        trimmed.removeLast("/v1".count)
        return URL(string: trimmed + "/api/generate")
    }

    /// Reasoning models emit a chain-of-thought pass before any answer. For
    /// short editing tasks that is pure latency, so it is switched off.
    private static func isReasoningModel(_ modelID: String) -> Bool {
        let id = modelID.lowercased()
        return ["qwen3", "deepseek-r1", "gpt-oss", "magistral", "thinking"].contains { id.contains($0) }
    }

    /// How long Ollama should keep weights resident after a request.
    private static let keepAlive = "30m"

    private func requestBody(
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
            body["reasoning_effort"] = "none"
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
    func warmUp(role: ModelRole) async {
        guard isOllama, let url = nativeGenerateURL() else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": model(for: role),
            "keep_alive": Self.keepAlive
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        request.httpBody = data
        _ = try? await ProviderHTTP.session().data(for: request)
    }

    func testConnection() async -> Result<Void, ProviderError> {
        do {
            let url = try endpoint()
            // One token, no reasoning pass: this answers "can I talk to this
            // server and does it know this model", and nothing else. Letting a
            // thinking model write a full greeting made the button sit spinning
            // for seconds against a server that was perfectly healthy.
            var suppressThinking = isLoopback || Self.isReasoningModel(enhanceModel)

            while true {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                if let apiKey, !apiKey.isEmpty {
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                }
                var body: [String: Any] = [
                    "model": enhanceModel,
                    "stream": false,
                    "max_tokens": 1,
                    "messages": [["role": "user", "content": "hi"]]
                ]
                if suppressThinking {
                    body["reasoning_effort"] = "none"
                    if isLoopback {
                        body["chat_template_kwargs"] = ["enable_thinking": false]
                    }
                }
                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                let (_, response): (Data, URLResponse)
                do {
                    (_, response) = try await ProviderHTTP.session().data(for: request)
                } catch {
                    return .failure(connectionError(error))
                }
                guard let http = response as? HTTPURLResponse else {
                    return .failure(.connectionFailed("No response from \(displayHost)"))
                }
                // Same one-shot fallback as the streaming path, so a server
                // that rejects the suppression keys reports its real status
                // instead of a spurious 400.
                if suppressThinking, http.statusCode == 400 || http.statusCode == 422 {
                    suppressThinking = false
                    continue
                }
                switch http.statusCode {
                case 200..<300: return .success(())
                case 401: return .failure(.invalidAPIKey)
                case 404:
                    return .failure(.badResponse(
                        "\(displayHost) has no model named \"\(enhanceModel)\" — check the model name in Settings."
                    ))
                case 429: return .failure(.rateLimited)
                default: return .failure(.badResponse("\(displayHost) returned status \(http.statusCode)"))
                }
            }
        } catch let error as ProviderError {
            return .failure(error)
        } catch {
            return .failure(.connectionFailed(error.localizedDescription))
        }
    }

    private func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200..<300: return
        case 401: throw ProviderError.invalidAPIKey
        case 429: throw ProviderError.rateLimited
        default: throw ProviderError.badResponse("Server returned status \(http.statusCode)")
        }
    }

    /// Transport failures worth one silent repeat, because they routinely mean
    /// "that socket was stale" rather than "that server is gone". A timeout is
    /// deliberately excluded: retrying it doubles the wait the user already sat
    /// through.
    private static func isTransientTransportFailure(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return false }
        return nsError.code == NSURLErrorNetworkConnectionLost
            || nsError.code == NSURLErrorCannotConnectToHost
    }

    /// Turns a URL-loading failure into something the user can act on. The
    /// distinction that matters: nothing listening (start the server) versus
    /// listening but silent (the model is loading — wait), versus anything else
    /// (say what it was, and which host it was talking to).
    private func connectionError(_ error: Error) -> ProviderError {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else {
            return .connectionFailed(error.localizedDescription)
        }
        switch nsError.code {
        case NSURLErrorCancelled:
            return .cancelled
        case NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost,
             NSURLErrorDNSLookupFailed, NSURLErrorNetworkConnectionLost:
            if isOllama {
                return .connectionFailed(
                    "Can't reach Ollama at \(displayHost) — run `ollama serve`, then Test Connection in Settings."
                )
            }
            if isLoopback {
                return .connectionFailed(
                    "Nothing is listening on \(displayHost) — start that server "
                        + "(LM Studio: `lms server start`) or fix the base URL in Settings."
                )
            }
            return .connectionFailed("Can't reach \(displayHost) — check the base URL and your connection.")
        case NSURLErrorTimedOut:
            // Something accepted the connection and then sent nothing for the
            // whole window. On a local server that is a cold model load, not a
            // dead process — saying "not reachable" here would be a lie.
            return .connectionFailed(
                "\(serverLabel) accepted the request but sent nothing for "
                    + "\(Int(ProviderHTTP.requestTimeout))s — the model may still be loading. Try again."
            )
        case NSURLErrorNotConnectedToInternet:
            return .connectionFailed("No network connection.")
        default:
            return .connectionFailed("\(serverLabel): \(error.localizedDescription) [URLError \(nsError.code)]")
        }
    }
}
