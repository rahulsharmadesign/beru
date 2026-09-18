import XCTest
@testable import Beru

/// Listing is Ollama-specific, so the guard against sending that request
/// anywhere else matters as much as the parsing.
final class OllamaAdminTests: XCTestCase {
    // MARK: - Endpoint derivation

    func testNativeRootDropsTheOpenAICompatibilitySuffix() {
        XCTAssertEqual(
            OllamaAdmin.nativeRoot(from: "http://localhost:11434/v1")?.absoluteString,
            "http://localhost:11434"
        )
        XCTAssertEqual(
            OllamaAdmin.nativeRoot(from: "http://localhost:11434/v1/")?.absoluteString,
            "http://localhost:11434"
        )
        XCTAssertEqual(
            OllamaAdmin.nativeRoot(from: "  http://192.168.1.9:11434/v1  ")?.absoluteString,
            "http://192.168.1.9:11434"
        )
    }

    /// LM Studio, llama.cpp and vLLM all sit on loopback too. A URL that is not
    /// shaped like Ollama's gets no Ollama-only requests, rather than a 404 per
    /// endpoint against someone else's server.
    func testNonOllamaShapedURLsAreRefused() {
        for url in [
            "http://localhost:1234",
            "http://localhost:8080/api",
            "https://api.groq.com/openai/v1beta",
            "file:///tmp/v1",
            ""
        ] {
            XCTAssertNil(OllamaAdmin.nativeRoot(from: url), "should refuse \(url)")
        }
    }

    // MARK: - Tag listing

    func testParsesInstalledModels() {
        let json = """
        {"models":[
          {"name":"qwen3:8b","size":5225000000},
          {"name":"llama3.2:3b","size":2019000000}
        ]}
        """
        let models = OllamaAdmin.parseTags(Data(json.utf8))
        XCTAssertEqual(models.map(\.name), ["llama3.2:3b", "qwen3:8b"])
        XCTAssertTrue(models.first { $0.name == "qwen3:8b" }?.sizeDescription.contains("GB") ?? false)
    }

    /// A model with no size is still a model. Dropping it would hide something
    /// the user has installed.
    func testAModelMissingItsSizeIsStillListed() {
        let models = OllamaAdmin.parseTags(Data(#"{"models":[{"name":"mystery"}]}"#.utf8))
        XCTAssertEqual(models.map(\.name), ["mystery"])
        XCTAssertEqual(models.first?.bytes, 0)
    }

    func testUnexpectedPayloadsYieldNoModelsRatherThanThrowing() {
        XCTAssertTrue(OllamaAdmin.parseTags(Data("not json".utf8)).isEmpty)
        XCTAssertTrue(OllamaAdmin.parseTags(Data("{}".utf8)).isEmpty)
        XCTAssertTrue(OllamaAdmin.parseTags(Data(#"{"models":"nope"}"#.utf8)).isEmpty)
    }
}
