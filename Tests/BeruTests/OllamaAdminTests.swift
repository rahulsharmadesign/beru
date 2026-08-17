import XCTest
@testable import Beru

/// Listing and pulling are Ollama-specific, so the guard against sending those
/// requests anywhere else matters as much as the parsing.
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

    // MARK: - Pull progress

    func testParsesAProgressLine() {
        let line = #"{"status":"downloading sha256:abc","completed":2900000000,"total":4700000000}"#
        let progress = OllamaAdmin.parsePullLine(line)
        XCTAssertEqual(progress?.completed, 2_900_000_000)
        XCTAssertEqual(progress?.total, 4_700_000_000)
        XCTAssertEqual(progress?.fraction ?? 0, 0.617, accuracy: 0.01)
    }

    /// The opening lines carry no byte counts. Reporting those as 0% would show
    /// a progress bar that appears stuck before the download has begun.
    func testEarlyLinesHaveNoFractionRatherThanZero() {
        let progress = OllamaAdmin.parsePullLine(#"{"status":"pulling manifest"}"#)
        XCTAssertEqual(progress?.status, "pulling manifest")
        XCTAssertNil(progress?.fraction)
        XCTAssertFalse(progress?.isDone ?? true)
    }

    func testSuccessLineEndsTheStream() {
        XCTAssertTrue(OllamaAdmin.parsePullLine(#"{"status":"success"}"#)?.isDone ?? false)
    }

    /// A pull can fail halfway with HTTP 200 and an `error` key on a progress
    /// line, so the status code alone never proves the download worked.
    func testInBandErrorIsSurfaced() {
        let progress = OllamaAdmin.parsePullLine(#"{"error":"model 'nope' not found"}"#)
        XCTAssertEqual(progress?.errorMessage, "model 'nope' not found")
    }

    func testBlankAndMalformedLinesAreSkipped() {
        XCTAssertNil(OllamaAdmin.parsePullLine(""))
        XCTAssertNil(OllamaAdmin.parsePullLine("   "))
        XCTAssertNil(OllamaAdmin.parsePullLine("{oops"))
    }

    /// Guards against a divide-by-zero and against a bar overshooting its track
    /// if the server ever reports more completed than total.
    func testFractionIsBoundedAndSafe() {
        func fraction(completed: Int64?, total: Int64?) -> Double? {
            OllamaAdmin.PullProgress(status: "x", completed: completed, total: total).fraction
        }
        XCTAssertNil(fraction(completed: 5, total: 0))
        XCTAssertNil(fraction(completed: nil, total: 100))
        XCTAssertNil(fraction(completed: 50, total: nil))
        XCTAssertEqual(fraction(completed: 150, total: 100), 1)
    }
}
