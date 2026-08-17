import XCTest
@testable import Beru

final class AnthropicProviderTests: XCTestCase {
    private func body(for role: ModelRole) -> [String: Any] {
        let provider = AnthropicProvider(apiKey: "test-key-not-used")
        return provider.requestBodyForTesting(system: "sys", user: "hello", role: role)
    }

    func testCurrentModelIDsHaveNoDateSuffix() {
        // Aliases are complete as-is; appending a date suffix 404s.
        XCTAssertEqual(AnthropicProvider.Constants.enhanceModel, "claude-sonnet-5")
        XCTAssertEqual(AnthropicProvider.Constants.grammarModel, "claude-haiku-4-5")
    }

    func testSonnet5OmitsTemperature() {
        // Claude 5 models reject non-default sampling parameters with a 400.
        let enhance = body(for: .enhance)
        XCTAssertEqual(enhance["model"] as? String, "claude-sonnet-5")
        XCTAssertNil(enhance["temperature"], "Sonnet 5 returns 400 for a non-default temperature")
    }

    func testSonnet5DisablesThinking() {
        // Adaptive thinking is on by default; for copy-editing and rewriting it
        // is pure latency, exactly as with the local reasoning models.
        let enhance = body(for: .enhance)
        let thinking = enhance["thinking"] as? [String: Any]
        XCTAssertEqual(thinking?["type"] as? String, "disabled")
    }

    func testHaikuKeepsTemperatureAndSendsNoThinking() {
        // Haiku 4.5 predates adaptive thinking and still accepts temperature,
        // so grammar stays deterministic.
        let grammar = body(for: .grammar)
        XCTAssertEqual(grammar["model"] as? String, "claude-haiku-4-5")
        XCTAssertEqual(grammar["temperature"] as? Double, 0.0)
        XCTAssertNil(grammar["thinking"], "Haiku 4.5 does not take an adaptive thinking config")
    }

    func testBodyAlwaysCarriesRequiredFields() {
        for role in [ModelRole.enhance, .grammar] {
            let body = body(for: role)
            XCTAssertNotNil(body["model"])
            XCTAssertNotNil(body["max_tokens"])
            XCTAssertEqual(body["stream"] as? Bool, true)
            XCTAssertEqual(body["system"] as? String, "sys")
        }
    }
}
