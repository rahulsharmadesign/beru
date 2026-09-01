import XCTest
@testable import Beru

final class GrammarSuggestionsTests: XCTestCase {
    private let tagged = """
    preamble
    <grammar kind="corrected">He doesn't know whether it's right.</grammar>
    <grammar kind="clearer">He isn't sure whether it's right.</grammar>
    <grammar kind="tighter">He isn't sure it's right.</grammar>
    """

    func testParseYieldsThreeKindsInOrder() {
        let parsed = GrammarSuggestions.parse(tagged)
        XCTAssertEqual(parsed.map(\.kind), GrammarKind.allCases)
        XCTAssertEqual(parsed.first?.body, "He doesn't know whether it's right.")
        XCTAssertEqual(parsed.last?.body, "He isn't sure it's right.")
    }

    func testMissingKindsAreDroppedNotInvented() {
        let raw = """
        <grammar kind="corrected">Fixed.</grammar>
        <grammar kind="tighter">Short.</grammar>
        """
        let parsed = GrammarSuggestions.parse(raw)
        XCTAssertEqual(parsed.map(\.kind), [.corrected, .tighter])
    }

    func testUntaggedOutputFallsBackToCorrected() {
        let parsed = GrammarSuggestions.parse("He doesn't know whether it's right.")
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed.first?.kind, .corrected)
        XCTAssertEqual(parsed.first?.body, "He doesn't know whether it's right.")
    }

    func testSelectedBodyPrefersMatchingKindThenFirst() {
        let suggestions = [
            GrammarSuggestion(kind: .corrected, body: "corrected"),
            GrammarSuggestion(kind: .clearer, body: "clearer")
        ]
        XCTAssertEqual(GrammarSuggestions.body(in: suggestions, matching: .clearer), "clearer")
        XCTAssertEqual(GrammarSuggestions.body(in: suggestions, matching: .tighter), "corrected")
    }

    @MainActor
    func testAcceptedTextUsesTheSelectedGrammarKind() {
        let state = AppState()
        state.selectAction(EnhancementAction.grammarID)
        state.setResult(.done("corrected"), for: EnhancementAction.grammarID)
        state.grammarSuggestions = [
            GrammarSuggestion(kind: .corrected, body: "corrected"),
            GrammarSuggestion(kind: .clearer, body: "clearer"),
            GrammarSuggestion(kind: .tighter, body: "tighter")
        ]
        state.selectedGrammarKind = .tighter
        XCTAssertEqual(state.acceptedText(), "tighter")
        state.selectGrammarKind(.clearer)
        XCTAssertEqual(state.acceptedText(), "clearer")
        if case .done(let text) = state.resultState(for: EnhancementAction.grammarID) {
            XCTAssertEqual(text, "clearer")
        } else {
            XCTFail("result field should show the selected body")
        }
    }

    func testPromptAsksForThreeTaggedKinds() {
        XCTAssertTrue(Prompts.grammar.contains("kind=\"corrected\""))
        XCTAssertTrue(Prompts.grammar.contains("kind=\"clearer\""))
        XCTAssertTrue(Prompts.grammar.contains("kind=\"tighter\""))
        XCTAssertTrue(Prompts.grammar.contains("Do not restyle"))
        XCTAssertTrue(Prompts.grammar.contains("not a second copy-edit"))
        XCTAssertFalse(Prompts.grammar.contains("Why isn't the grammar response working?"))
    }
}
