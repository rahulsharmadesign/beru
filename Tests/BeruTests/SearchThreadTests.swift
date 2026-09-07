import XCTest
@testable import Beru

@MainActor
final class SearchThreadTests: XCTestCase {
    func testBeginSearchTurnAppendsAndCaps() {
        let state = AppState()
        state.searchThread.removeAll()
        for i in 0..<AppState.searchThreadMaxTurns + 3 {
            state.beginSearchTurn(question: "Q\(i)", regenerating: false)
        }
        XCTAssertEqual(state.searchThread.count, AppState.searchThreadMaxTurns)
        XCTAssertEqual(state.searchThread.last?.question, "Q\(AppState.searchThreadMaxTurns + 2)")
    }

    func testRegenerateRewritesLiveTurnOnly() {
        let state = AppState()
        state.beginSearchTurn(question: "One", regenerating: false)
        state.updateLiveSearchTurn(.done("A1"))
        state.beginSearchTurn(question: "Two", regenerating: false)
        state.updateLiveSearchTurn(.done("A2"))
        XCTAssertEqual(state.searchThread.count, 2)

        state.beginSearchTurn(question: "Two", regenerating: true)
        XCTAssertEqual(state.searchThread.count, 2)
        XCTAssertEqual(state.searchThread[0].answer, .done("A1"))
        XCTAssertEqual(state.searchThread[1].answer, .loading)
    }

    func testDismissClearsSearchThread() {
        let state = AppState()
        state.beginSearchTurn(question: "Keep?", regenerating: false)
        state.updateLiveSearchTurn(.done("Nope"))
        state.dismiss()
        XCTAssertTrue(state.searchThread.isEmpty)
    }

    func testDismissAndResetClearSearchFeedback() {
        let state = AppState()
        state.beginSearchTurn(question: "Q", regenerating: false)
        let id = state.searchThread[0].id
        state.searchFeedback[id] = true
        state.dismiss()
        XCTAssertTrue(state.searchFeedback.isEmpty)

        state.beginSearchTurn(question: "Q", regenerating: false)
        let id2 = state.searchThread[0].id
        state.searchFeedback[id2] = false
        state.reset(withCapturedText: "")
        XCTAssertTrue(state.searchFeedback.isEmpty)
    }

    func testDismissAndResetClearResultFeedback() {
        let state = AppState()
        state.resultFeedback["grammar"] = true
        state.dismiss()
        XCTAssertTrue(state.resultFeedback.isEmpty)

        state.resultFeedback["grammar"] = false
        state.reset(withCapturedText: "")
        XCTAssertTrue(state.resultFeedback.isEmpty)
    }

    func testQuotePreviewTrimsWhitespace() {
        XCTAssertEqual(SelectedSourceQuote.preview("  scaffolding.  "), "scaffolding.")
        XCTAssertEqual(SelectedSourceQuote.preview(""), "")
    }

    func testQuotePreviewCapsLongSelections() {
        let long = String(repeating: "word ", count: 500)
        let preview = SelectedSourceQuote.preview(long)
        XCTAssertLessThanOrEqual(preview.count, SelectedSourceQuote.collapsedCharCap + 1)
        XCTAssertTrue(preview.hasSuffix("…"))
    }
}
