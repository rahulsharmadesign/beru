import Foundation

/// Ollama's own management API, used for listing and installing models.
///
/// Separate from `OpenAICompatProvider`, which speaks the OpenAI-compatible
/// subset and must keep working against Groq, LM Studio and anything else on
/// that shape. Listing and pulling are Ollama-specific, so they are only ever
/// attempted against a base URL that looks like Ollama's — the same restraint
/// `nativeGenerateURL()` already applies when warming a model.
struct OllamaAdmin: Sendable {
    struct Model: Identifiable, Sendable, Equatable {
        var name: String
        var bytes: Int64
        var id: String { name }

        /// "4.7 GB". Decimal units, matching how Ollama's own site quotes sizes.
        var sizeDescription: String {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .decimal
            formatter.allowedUnits = [.useGB, .useMB]
            return formatter.string(fromByteCount: bytes)
        }
    }

    /// One line of a streamed pull.
    struct PullProgress: Sendable, Equatable {
        var status: String
        var completed: Int64?
        var total: Int64?
        /// Ollama reports failures in-band, as an `error` key on an otherwise
        /// ordinary progress line, so every line has to be inspected — the HTTP
        /// status is 200 for a pull that fails halfway.
        var errorMessage: String?

        /// Nil until the server reports both figures — the first few lines are
        /// manifest work with no byte counts, and showing 0% for those would
        /// read as a stalled download.
        var fraction: Double? {
            guard let completed, let total, total > 0 else { return nil }
            return min(1, Double(completed) / Double(total))
        }

        var isDone: Bool { status == "success" }
    }

    enum AdminError: LocalizedError {
        case notOllama
        case unreachable(String)
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .notOllama:
                return "This only works with Ollama. The base URL in Models & Provider does not look like an Ollama server."
            case .unreachable(let where_):
                return "Could not reach \(where_). Start the server and try again."
            case .failed(let message):
                return message
            }
        }
    }

    var baseURL: String

    /// Ollama's native API root, derived by dropping a trailing `/v1` from the
    /// OpenAI-compatible base URL. Returns nil for a URL of any other shape, so
    /// a non-Ollama local server is never poked with endpoints it does not have.
    ///
    /// Pure and static so the derivation is testable without a server.
    static func nativeRoot(from baseURL: String) -> URL? {
        var trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        trimmed = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard trimmed.hasSuffix("/v1") else { return nil }
        trimmed.removeLast("/v1".count)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }
        return url
    }

    private func endpoint(_ path: String) throws -> URL {
        guard let root = Self.nativeRoot(from: baseURL) else { throw AdminError.notOllama }
        return root.appendingPathComponent(path)
    }

    /// Host and port only. The base URL can carry credentials in its userinfo,
    /// which must never reach a message or a log.
    private var safeHost: String {
        guard let root = Self.nativeRoot(from: baseURL), let host = root.host else { return "the server" }
        return root.port.map { "\(host):\($0)" } ?? host
    }

    // MARK: - Listing

    func installedModels() async throws -> [Model] {
        let url = try endpoint("api/tags")
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(for: request)
        } catch {
            throw AdminError.unreachable(safeHost)
        }
        return Self.parseTags(data)
    }

    /// Tolerates a model entry missing its size rather than failing the list —
    /// a model you cannot see is worse than one with an unknown size.
    static func parseTags(_ data: Data) -> [Model] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = root["models"] as? [[String: Any]] else { return [] }
        return models.compactMap { entry in
            guard let name = entry["name"] as? String ?? entry["model"] as? String else { return nil }
            let bytes = (entry["size"] as? NSNumber)?.int64Value ?? 0
            return Model(name: name, bytes: bytes)
        }
        .sorted { $0.name < $1.name }
    }

    // MARK: - Pulling

    /// Streams progress while Ollama downloads a model.
    ///
    /// The response is newline-delimited JSON, one object per line, not SSE — so
    /// it is parsed by line rather than by `data:` prefix.
    func pull(model: String) -> AsyncThrowingStream<PullProgress, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = try endpoint("api/pull")
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    // No overall timeout: a multi-gigabyte pull legitimately
                    // takes many minutes, and the per-line updates are the
                    // liveness signal.
                    request.timeoutInterval = 3600
                    request.httpBody = try JSONSerialization.data(
                        withJSONObject: ["model": model, "stream": true]
                    )

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                        throw AdminError.failed("The server refused to pull \(model) (HTTP \(http.statusCode)).")
                    }
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        guard let progress = Self.parsePullLine(line) else { continue }
                        if let error = progress.errorMessage {
                            throw AdminError.failed(error)
                        }
                        continuation.yield(progress)
                        if progress.isDone { break }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func parsePullLine(_ line: String) -> PullProgress? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return PullProgress(
            status: object["status"] as? String ?? "",
            completed: (object["completed"] as? NSNumber)?.int64Value,
            total: (object["total"] as? NSNumber)?.int64Value,
            errorMessage: object["error"] as? String
        )
    }
}
