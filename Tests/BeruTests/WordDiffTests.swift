import XCTest
@testable import Beru

final class WordDiffTests: XCTestCase {
    func testIdenticalStringsProduceOnlyEqualOps() {
        let ops = WordDiff.diff(original: "hello world", revised: "hello world")
        XCTAssertEqual(ops, [.equal("hello world")])
    }

    func testSingleWordSubstitution() {
        let ops = WordDiff.diff(original: "I are happy", revised: "I am happy")
        XCTAssertEqual(ops, [
            .equal("I "),
            .deletion("are"),
            .insertion("am"),
            .equal(" happy")
        ])
    }

    func testInsertionOnly() {
        let ops = WordDiff.diff(original: "hello world", revised: "hello there world")
        XCTAssertEqual(ops, [
            .equal("hello "),
            .insertion("there "),
            .equal("world")
        ])
    }

    func testDeletionOnly() {
        let ops = WordDiff.diff(original: "hello there world", revised: "hello world")
        XCTAssertEqual(ops, [
            .equal("hello "),
            .deletion("there "),
            .equal("world")
        ])
    }

    func testEmptyOriginal() {
        let ops = WordDiff.diff(original: "", revised: "new text")
        XCTAssertEqual(ops, [.insertion("new text")])
    }

    func testEmptyRevised() {
        let ops = WordDiff.diff(original: "old text", revised: "")
        XCTAssertEqual(ops, [.deletion("old text")])
    }

    func testBothEmpty() {
        let ops = WordDiff.diff(original: "", revised: "")
        XCTAssertEqual(ops, [])
    }

    func testReconstructionRoundTripsToOriginalAndRevised() {
        let original = "The quick brown fox  jumps over lazy dog."
        let revised = "The quick brown fox jumps over the lazy dog!"
        let ops = WordDiff.diff(original: original, revised: revised)

        var reconstructedOriginal = ""
        var reconstructedRevised = ""
        for op in ops {
            switch op {
            case .equal(let s):
                reconstructedOriginal += s
                reconstructedRevised += s
            case .deletion(let s):
                reconstructedOriginal += s
            case .insertion(let s):
                reconstructedRevised += s
            }
        }
        XCTAssertEqual(reconstructedOriginal, original)
        XCTAssertEqual(reconstructedRevised, revised)
    }
}
