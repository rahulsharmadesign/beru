import Foundation

/// Anthropic Messages API provider. Streams via SSE `content_block_delta` events.
struct AnthropicProvider: LLMProvider {
    enum Constants {
        static let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!
        static let apiVersion = "2023-06-01"
        /// Sonnet 5 for prompt authoring, Haiku 4.5 for copy-editing: the
        /// grammar pass is mechanical and wants the cheapest fast model.
        static let enhanceModel = "claude-sonnet-5"
        static let grammarModel = "claude-haiku-4-5"
    }

    let apiKey: String

    private func model(for role: ModelRole) -> String {
        switch role {
        case .enhance: return Constants.enhanceModel
        case .grammar: return Constants.grammarModel
        }
    }

    /// Claude 5 and 4.7+ models reject non-default sampling parameters with a
    /// 400. Older models (Haiku 4.5) still accept temperature.
    private static func acceptsTemperature(_ modelID: String) -> Bool {
        let rejecting = ["claude-opus-5", "claude-sonnet-5", "claude-fable-5", "claude-mythos-5",
                         "claude-opus-4-8", "claude-opus-4-7"]
        return !rejecting.contains { modelID.hasPrefix($0) }
    }

    /// Models with adaptive thinking think by default when `thinking` is
    /// omitted. Editing and rewriting are not reasoning-bound, so thinking is
    /// pure latency and cost here — the same problem the local provider hit.
    private static func supportsAdaptiveThinking(_ modelID: String) -> Bool {
        let adaptive = ["claude-opus-5", "claude-sonnet-5", "claude-opus-4-8", "claude-opus-4-7",
                        "claude-opus-4-6", "claude-sonnet-4-6"]
        return adaptive.contains { modelID.hasPrefix($0) }
    }

    private func requestBody(
        system: String,
        user: String,
        role: ModelRole,
        expectsRationale: Bool = false
    ) -> [String: Any] {
        let modelID = model(for: role)
        var body: [String: Any] = [
            "model": modelID,
            "max_tokens": ProviderTuning.maxTokens(
                for: role,
                input: user,
                expectsRationale: expectsRationale
            ),
            "stream": true,
            "system": system,
            "messages": [["role": "user", "content": user]]
        ]
        if Self.acceptsTemperature(modelID) {
            body["temperature"] = ProviderTuning.temperature(for: role)
        }
        if Self.supportsAdaptiveThinking(modelID) {
            body["thinking"] = ["type": "disabled"]
        }
        return body
    }

    /// Exposes the assembled body so tests can assert the model-specific rules
    /// (omitted temperature, disabled thinking) without making a network call.
    func requestBodyForTesting(system: String, user: String, role: ModelRole) -> [String: Any] {
        requestBody(system: system, user: user, role: role)
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
                    var request = URLRequest(url: Constants.baseURL)
                    request.httpMethod = "POST"
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue(Constants.apiVersion, forHTTPHeaderField: "anthropic-version")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    request.httpBody = try JSONSerialization.data(
                        withJSONObject: requestBody(
                            system: system,
                            user: user,
                            role: role,
                            expectsRationale: expectsRationale
                        )
                    )

                    let (bytes, response) = try await ProviderHTTP.session().bytes(for: request)
                    try Self.validate(response: response, bytes: bytes)

                    for await payload in ProviderHTTP.sseLines(from: bytes) {
                        if Task.isCancelled { break }
                        guard let data = payload.data(using: .utf8),
                              let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                            continue
                        }
                        if let type = event["type"] as? String, type == "content_block_delta",
                           let delta = event["delta"] as? [String: Any] {
                            if let text = delta["text"] as? String {
                                continuation.yield(.content(text))
                            } else if let thinking = delta["thinking"] as? String {
                                continuation.yield(.reasoning(thinking))
                            }
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

    func testConnection() async -> Result<Void, ProviderError> {
        var request = URLRequest(url: Constants.baseURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Constants.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": Constants.grammarModel,
            "max_tokens": 1,
            "messages": [["role": "user", "content": "hi"]]
        ]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await ProviderHTTP.session().data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.connectionFailed("No response from Anthropic"))
            }
            switch http.statusCode {
            case 200..<300: return .success(())
            case 401: return .failure(.invalidAPIKey)
            case 429: return .failure(.rateLimited)
            default: return .failure(.badResponse("Anthropic returned status \(http.statusCode)"))
            }
        } catch {
            return .failure(.connectionFailed(error.localizedDescription))
        }
    }

    private static func validate(response: URLResponse, bytes: URLSession.AsyncBytes) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200..<300: return
        case 401: throw ProviderError.invalidAPIKey
        case 429: throw ProviderError.rateLimited
        case 404: throw ProviderError.modelUnavailable("Anthropic returned status 404")
        default: throw ProviderError.badResponse("Anthropic returned status \(http.statusCode)")
        }
    }
}
