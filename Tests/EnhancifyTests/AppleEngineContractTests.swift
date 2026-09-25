import XCTest
@testable import Enhancify

final class AppleEngineContractTests: XCTestCase {
    private func budget(
        system: String = "system prompt",
        contextSize: Int = 4096,
        role: ModelRole = .grammar,
        input: String = "hello"
    ) -> PromptBudget {
        PromptBudget.onDevice(
            system: system,
            role: role,
            input: input,
            contextSize: contextSize
        )
    }

    func testShortCapturesPassThroughUntouched() {
        let clamp = budget().clamp("fix my grammar please")
        XCTAssertFalse(clamp.truncated)
        XCTAssertEqual(clamp.text, "fix my grammar please")
        XCTAssertEqual(clamp.droppedCharacters, 0)
    }

    func testLongCaptureTrimsWithNotice() {
        let huge = String(repeating: "word ", count: 20_000)
        let clamp = budget(contextSize: 2048).clamp(huge)
        XCTAssertTrue(clamp.truncated)
        XCTAssertGreaterThan(clamp.droppedCharacters, 0)
        XCTAssertEqual(clamp.text.count + clamp.droppedCharacters, huge.count)
    }

    func testEnhancifysCapIsTheCeiling() {
        let huge = String(repeating: "word ", count: 200_000)
        let clamp = budget(contextSize: 1_000_000).clamp(huge)
        XCTAssertTrue(clamp.truncated)
        XCTAssertLessThanOrEqual(clamp.text.count, 8000)
    }
}