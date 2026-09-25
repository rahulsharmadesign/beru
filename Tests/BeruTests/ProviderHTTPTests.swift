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

    /// The install catalog is gone — in-app downloads could not show file
    /// variants or sizes, and recommended a 1B model too weak for the tasks.
    /// What remains is the single shipped default the store reads.
    func testShippedDefaultLocalModelFollowsMemory() {
        XCTAssertEqual(RecommendedOllamaModel.defaultID(physicalMemoryGB: 8), "qwen2.5:3b")
        XCTAssertEqual(RecommendedOllamaModel.defaultID(physicalMemoryGB: 16), "qwen2.5:3b")
        XCTAssertEqual(RecommendedOllamaModel.defaultID(physicalMemoryGB: 24), "qwen2.5:7b")
        XCTAssertEqual(RecommendedOllamaModel.defaultID(physicalMemoryGB: 64), "qwen2.5:7b")
    }

    func testResidentSizeIsReadFromTheModelTag() {
        XCTAssertEqual(RecommendedOllamaModel.estimatedResidentGB(forModel: "qwen2.5:7b") ?? 0, 4.7, accuracy: 0.01)
        XCTAssertEqual(RecommendedOllamaModel.estimatedResidentGB(forModel: "gemma3:1b") ?? 0, 1.1, accuracy: 0.01)
        XCTAssertNil(RecommendedOllamaModel.estimatedResidentGB(forModel: "llama3"))
    }

    func testMemoryAdviceWarnsOnlyWhenTheModelIsHeavyForThisMac() {
        XCTAssertNotNil(RecommendedOllamaModel.memoryAdvice(model: "qwen2.5:7b", physicalMemoryGB: 16))
        XCTAssertNil(RecommendedOllamaModel.memoryAdvice(model: "qwen2.5:3b", physicalMemoryGB: 16))
        XCTAssertNil(RecommendedOllamaModel.memoryAdvice(model: "qwen2.5:7b", physicalMemoryGB: 32))
        XCTAssertNotNil(
            RecommendedOllamaModel.memoryAdvice(model: "qwen2.5:3b", physicalMemoryGB: 8),
            "8 GB Macs are always steered away from local models."
        )
    }
}
