import XCTest
@testable import Enhancify

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
        XCTAssertTrue(GrammarSuggestions.parseWithStatus("He doesn't know whether it's right.").usedFallback)
        XCTAssertFalse(GrammarSuggestions.parseWithStatus(tagged).usedFallback)
    }

    func testSelectedBodyPrefersMatchingKindThenFirst() {
        let suggestions = [
            GrammarSuggestion(kind: .corrected, body: "corrected"),
            GrammarSuggestion(kind: .clearer, body: "clearer")
        ]
        XCTAssertEqual(GrammarSuggestions.body(in: suggestions, matching: .clearer), "clearer")
        XCTAssertEqual(GrammarSuggestions.body(in: suggestions, matching: .tighter), "corrected")
    }

    func testPromptAsksForThreeTaggedKinds() {
        XCTAssertTrue(Prompts.grammar.contains("kind=\"corrected\""))
        XCTAssertTrue(Prompts.grammar.contains("kind=\"clearer\""))
        XCTAssertTrue(Prompts.grammar.contains("kind=\"tighter\""))
        XCTAssertTrue(Prompts.grammar.contains("Do not restyle"))
        XCTAssertTrue(Prompts.grammar.contains("not a second copy-edit"))
        XCTAssertFalse(Prompts.grammar.contains("Why isn't the grammar response working?"))
    }

    func testVariantsIdenticalToCorrectedCollapse() {
        // An already-clean sentence has no clearer or tighter form; the model
        // repeats Corrected in all three tags. Three identical cards read as a
        // bug, so the parse keeps only the genuine rephrases.
        let raw = """
        <grammar kind="corrected">Two problems in the composer.</grammar>
        <grammar kind="clearer">Two problems in the composer.</grammar>
        <grammar kind="tighter">Two problems in the composer.</grammar>
        """
        let parsed = GrammarSuggestions.parse(raw)
        XCTAssertEqual(parsed, [GrammarSuggestion(kind: .corrected, body: "Two problems in the composer.")])
    }

    func testOnlyTheIdenticalVariantDrops() {
        let raw = """
        <grammar kind="corrected">He doesn't know whether it's right.</grammar>
        <grammar kind="clearer">He doesn't know whether it's right.</grammar>
        <grammar kind="tighter">He isn't sure it's right.</grammar>
        """
        let parsed = GrammarSuggestions.parse(raw)
        XCTAssertEqual(parsed.map(\.kind), [.corrected, .tighter])
    }

    func testCollapseIgnoresCaseAndWhitespace() {
        let raw = """
        <grammar kind="corrected">He doesn't know whether it's right.</grammar>
        <grammar kind="clearer">he  doesn't   know whether it's right.</grammar>
        """
        let parsed = GrammarSuggestions.parse(raw)
        XCTAssertEqual(parsed.map(\.kind), [.corrected])
    }
}
