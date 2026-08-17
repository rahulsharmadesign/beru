import XCTest
@testable import Beru

/// Opt-in end-to-end smoke test against a real local OpenAI-compatible server
/// (Ollama, LM Studio, etc). Skips itself when nothing is listening, so it's
/// safe to leave in the suite for machines without a local LLM running.
final class LiveProviderSmokeTestCase: XCTestCase {
    func testStreamingAgainstLocalServerProducesGrammarCorrection() async throws {
        let baseURL = ProcessInfo.processInfo.environment["BERU_TEST_BASE_URL"] ?? "http://localhost:1234/v1"
        let model = ProcessInfo.processInfo.environment["BERU_TEST_MODEL"] ?? "qwen/qwen3-1.7b"

        guard await Self.isReachable(baseURL) else {
            throw XCTSkip("No local OpenAI-compatible server reachable at \(baseURL)")
        }

        let provider = OpenAICompatProvider(
            baseURL: baseURL,
            apiKey: nil,
            enhanceModel: model,
            grammarModel: model
        )

        var accumulated = ""
        var reasoningChunks = 0
        let stream = provider.stream(
            system: Prompts.grammar,
            user: "i has went to the store yesterday and buyed some milk",
            role: .grammar
        )
        for try await chunk in stream {
            switch chunk {
            case .content(let text): accumulated += text
            case .reasoning: reasoningChunks += 1
            }
        }

        XCTAssertFalse(accumulated.isEmpty, "Expected non-empty streamed output")
        XCTAssertTrue(accumulated.lowercased().contains("store"), "Expected corrected text to retain original content")
        // Regression guard for the invisible-reasoning-pass bug: a reasoning
        // model must have its thinking suppressed, not merely discarded.
        if model.lowercased().contains("qwen3") {
            XCTAssertEqual(reasoningChunks, 0, "Thinking should be suppressed, not streamed and dropped")
        }
    }

    private static func isReachable(_ baseURL: String) async -> Bool {
        guard let url = URL(string: baseURL + "/models") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        return (try? await URLSession.shared.data(for: request)) != nil
    }
}
