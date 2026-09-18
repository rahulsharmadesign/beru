import XCTest
@testable import Beru

/// Composer submit on a verb chip with no selection: the typed text is the
/// document to work on, not an instruction. The bug this pins: Enter on
/// Grammar with typed text left the text in the field and never produced a
/// correction — the engine read the composer as the source mid-call but the
/// field-clear skipped verbs, and the synchronous clear raced the composer's
/// own text-change callback and was resurrected.
@MainActor
final class ComposerSubmitTests: XCTestCase {
    func testTypedTextOnAVerbBecomesTheSource() async {
        let state = AppState()
        state.reset(withCapturedText: "")
        state.selectAction(EnhancementAction.grammarID)
        state.describeInstruction = "their are three thing"
        let engine = PanelEngine(appState: state, onDismiss: {})

        engine.runDescribe(instruction: state.describeInstruction)

        // Promoted to the capture so Grammar runs on it as the document.
        XCTAssertEqual(state.capturedText, "their are three thing")
        // The clear is deferred off the Return handler's call stack.
        await Task.yield()
        await Task.yield()
        XCTAssertEqual(state.describeInstruction, "")
    }

    func testTypedTextOnEnhanceBecomesTheSource() {
        let state = AppState()
        state.reset(withCapturedText: "")
        state.selectAction(EnhancementAction.enhanceID)
        state.describeInstruction = "write a parser"
        let engine = PanelEngine(appState: state, onDismiss: {})

        engine.runDescribe(instruction: state.describeInstruction)

        XCTAssertEqual(state.capturedText, "write a parser")
    }

    func testTypedTextWithASelectionStaysAnExtraInstruction() {
        let state = AppState()
        state.reset(withCapturedText: "selected draft")
        state.selectAction(EnhancementAction.grammarID)
        state.describeInstruction = "keep my tone"
        let engine = PanelEngine(appState: state, onDismiss: {})

        engine.runDescribe(instruction: state.describeInstruction)

        // A selection is present, so the composer text is an extra instruction,
        // not the source — the capture is untouched and the field stays put for
        // tweaking. Only the no-selection path promotes typed text.
        XCTAssertEqual(state.capturedText, "selected draft")
        XCTAssertEqual(state.describeInstruction, "keep my tone")
    }
}
