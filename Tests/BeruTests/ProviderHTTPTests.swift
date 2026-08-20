import XCTest
@testable import Beru

final class ProviderHTTPTests: XCTestCase {
    func testHTTPSAndLocalHTTPAreAccepted() throws {
        let remote = try ProviderHTTP.chatCompletionsURL(from: "https://api.groq.com/openai/v1")
        XCTAssertEqual(remote.scheme, "https")
        XCTAssertEqual(remote.host, "api.groq.com")
        XCTAssertTrue(remote.path.hasSuffix("/chat/completions"))

        let local = try ProviderHTTP.chatCompletionsURL(from: "http://localhost:11434/v1")
        XCTAssertEqual(local.scheme, "http")
        XCTAssertEqual(local.host, "localhost")
        XCTAssertEqual(local.port, 11434)
    }

    func testFileAndUnixSchemesAreRejected() {
        XCTAssertThrowsError(try ProviderHTTP.chatCompletionsURL(from: "file:///tmp/v1")) { error in
            XCTAssertEqual(
                error as? ProviderError,
                .connectionFailed("The base URL must start with http:// or https://")
            )
        }
        XCTAssertThrowsError(try ProviderHTTP.chatCompletionsURL(from: "unix:///var/run/docker.sock/v1"))
    }

    func testEmptyAndHostlessURLsAreRejected() {
        XCTAssertThrowsError(try ProviderHTTP.chatCompletionsURL(from: ""))
        XCTAssertThrowsError(try ProviderHTTP.chatCompletionsURL(from: "   "))
    }

    func testModelUnavailableKeepsServerErrorCopyAndFlagsSetup() {
        let error = ProviderError.modelUnavailable("Server returned status 404")
        XCTAssertEqual(error.userMessage, "Server returned status 404")
        XCTAssertTrue(error.needsModelSetup)
        XCTAssertFalse(ProviderError.badResponse("Server returned status 500").needsModelSetup)
    }

    func testRecommendedCatalogSurfacesGemma3First() {
        XCTAssertEqual(RecommendedOllamaModel.all.first?.name, "gemma3:1b")
        XCTAssertEqual(RecommendedOllamaModel.all.first?.title, "Gemma 3 1B")
        XCTAssertTrue(RecommendedOllamaModel.all.contains(where: { $0.name == "qwen2.5:7b" }))
    }

    /// The install list used to label one model "Default" while the store
    /// shipped another. Exactly one entry may claim it, and it must be the id
    /// the store actually defaults to.
    func testExactlyOneCatalogEntryIsTheShippedDefault() {
        let defaults = RecommendedOllamaModel.all.filter(\.isDefault)
        XCTAssertEqual(defaults.count, 1)
        XCTAssertEqual(defaults.first?.name, RecommendedOllamaModel.defaultID)
        XCTAssertTrue(defaults.first?.caption.contains("Default") == true)
        XCTAssertFalse(
            RecommendedOllamaModel.all.contains { !$0.isDefault && $0.note.contains("Default") },
            "Default is derived from defaultID; do not type it into a note"
        )
    }
}
