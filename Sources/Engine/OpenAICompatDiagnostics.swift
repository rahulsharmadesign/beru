import Foundation

// Warm-up, connection testing and error interpretation. Kept apart from the
// request and stream path, which is the only part on the hot path.

extension OpenAICompatProvider {
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
            // A few tokens, thinking kept short: this answers "can I talk to
            // this server and does it know this model". One token is not enough
            // for gpt-oss, which must emit reasoning before any visible output.
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
                    "max_tokens": 16,
                    "messages": [["role": "user", "content": "hi"]]
                ]
                if suppressThinking {
                    body["reasoning_effort"] = Self.reasoningEffort(for: enhanceModel)
                    if isLoopback {
                        body["chat_template_kwargs"] = ["enable_thinking": false]
                    }
                }
                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                let (data, response): (Data, URLResponse)
                do {
                    (data, response) = try await ProviderHTTP.session().data(for: request)
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
                case 404: return .failure(.modelUnavailable(await unknownModelMessage(serverBody: data)))
                case 429: return .failure(.rateLimited)
                default:
                    if let message = Self.openAIErrorMessage(from: data) {
                        return .failure(.badResponse(message))
                    }
                    return .failure(.badResponse("\(displayHost) returned status \(http.statusCode)"))
                }
            }
        } catch let error as ProviderError {
            return .failure(error)
        } catch {
            return .failure(.connectionFailed(error.localizedDescription))
        }
    }

    func unknownModelMessage(serverBody: Data) async -> String {
        if let message = Self.openAIErrorMessage(from: serverBody), !message.isEmpty {
            return message
        }
        let listed = await listedChatModelIDs()
        if listed.contains(enhanceModel) {
            return "\(displayHost) rejected the test request for \"\(enhanceModel)\"."
        }
        if !listed.isEmpty {
            let sample = listed.prefix(8).joined(separator: ", ")
            return "\(displayHost) has no model named \"\(enhanceModel)\". Available: \(sample)"
        }
        return "\(displayHost) has no model named \"\(enhanceModel)\" — check the model name in Settings."
    }

    func listedChatModelIDs() async -> [String] {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: trimmed + "/models") else { return [] }
        var request = URLRequest(url: url)
        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        guard let (data, response) = try? await ProviderHTTP.session().data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = obj["data"] as? [[String: Any]] else {
            return []
        }
        return rows.compactMap { $0["id"] as? String }.filter { id in
            let lower = id.lowercased()
            return !lower.contains("whisper") && !lower.contains("guard")
        }
    }

    func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200..<300: return
        case 401: throw ProviderError.invalidAPIKey
        case 429: throw ProviderError.rateLimited
        case 404: throw ProviderError.modelUnavailable("Server returned status 404")
        default: throw ProviderError.badResponse("Server returned status \(http.statusCode)")
        }
    }

    /// Transport failures worth one silent repeat, because they routinely mean
    /// "that socket was stale" rather than "that server is gone". A timeout is
    /// deliberately excluded: retrying it doubles the wait the user already sat
    /// through.
    static func isTransientTransportFailure(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return false }
        return nsError.code == NSURLErrorNetworkConnectionLost
            || nsError.code == NSURLErrorCannotConnectToHost
    }

    /// Turns a URL-loading failure into something the user can act on. The
    /// distinction that matters: nothing listening (start the server) versus
    /// listening but silent (the model is loading — wait), versus anything else
    /// (say what it was, and which host it was talking to).
    func connectionError(_ error: Error) -> ProviderError {
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
