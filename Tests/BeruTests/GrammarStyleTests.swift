import XCTest
@testable import Beru

final class GrammarStyleTests: XCTestCase {
    func testEveryStyleIsReachableExactlyOnce() {
        let listed = GrammarStyle.quick + GrammarStyle.tones + GrammarStyle.fun
        XCTAssertEqual(Set(listed), Set(GrammarStyle.allCases), "a style missing from the row and menu can never be picked")
        XCTAssertEqual(listed.count, GrammarStyle.allCases.count, "a style listed twice shows up twice")
    }

    func testProofreadKeepsTheBuiltInGrammarPrompt() {
        XCTAssertFalse(GrammarStyle.proofread.isRewrite)
        XCTAssertEqual(GrammarStyle.proofread.instruction, "")
        XCTAssertEqual(GrammarStyle.quick.first, .proofread, "Proofread is the default and leads the row")
    }

    func testRewriteStylesAskForOnePlainDocument() {
        for style in GrammarStyle.allCases where style.isRewrite {
            let prompt = style.systemPrompt
            XCTAssertFalse(style.instruction.isEmpty, style.title)
            XCTAssertTrue(prompt.contains(style.instruction), style.title)
            XCTAssertTrue(prompt.contains("<text>"), "\(style.title) must describe the input markers")
            XCTAssertTrue(prompt.contains("Output ONLY"), "\(style.title) must forbid preamble")
            XCTAssertFalse(prompt.contains("<grammar"), "\(style.title) must not ask for the proofread tag format")
        }
    }

    func testToEnglishUnderstandsHinglish() {
        XCTAssertTrue(GrammarStyle.english.instruction.contains("Hinglish"))
    }
}
