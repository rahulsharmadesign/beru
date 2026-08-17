import XCTest
@testable import Beru

final class OpenAICompatProviderTests: XCTestCase {
    func testGptOssUsesLowReasoningEffortBecauseGroqRejectsNone() {
        XCTAssertEqual(OpenAICompatProvider.reasoningEffort(for: "openai/gpt-oss-120b"), "low")
        XCTAssertEqual(OpenAICompatProvider.reasoningEffort(for: "openai/gpt-oss-20b"), "low")
        XCTAssertEqual(OpenAICompatProvider.reasoningEffort(for: "qwen3:8b"), "none")
    }

    func testGptOssIsTreatedAsAReasoningModel() {
        XCTAssertTrue(OpenAICompatProvider.isReasoningModel("openai/gpt-oss-120b"))
        XCTAssertTrue(OpenAICompatProvider.isReasoningModel("qwen3:8b"))
        XCTAssertFalse(OpenAICompatProvider.isReasoningModel("llama-3.3-70b-versatile"))
    }

    func testOpenAIErrorMessageReadsNestedMessage() throws {
        let data = Data(#"{ "error": { "message": "The model does not exist or you do not have access to it." } }"#.utf8)
        XCTAssertEqual(
            OpenAICompatProvider.openAIErrorMessage(from: data),
            "The model does not exist or you do not have access to it."
        )
    }

    func testOpenAIErrorMessageIgnoresEmptyBodies() {
        XCTAssertNil(OpenAICompatProvider.openAIErrorMessage(from: Data("{}".utf8)))
        XCTAssertNil(OpenAICompatProvider.openAIErrorMessage(from: Data("not-json".utf8)))
    }
}
