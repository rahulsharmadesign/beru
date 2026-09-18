import Foundation

/// Ollama's own management API, used for listing installed models.
///
/// Separate from `OpenAICompatProvider`, which speaks the OpenAI-compatible
/// subset and must keep working against Groq, LM Studio and anything else on
/// that shape. Listing is Ollama-specific, so it is only ever attempted
/// against a base URL that looks like Ollama's — the same restraint
/// `nativeGenerateURL()` already applies when warming a model.
///
/// Downloading used to live here too. It is gone on purpose: the Ollama app
/// and `ollama pull` show file variants and sizes that an in-app downloader
/// cannot, and picked-by-name pulls are how wrong models (vision, F16 giants)
/// got installed with no questions asked.
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
}
