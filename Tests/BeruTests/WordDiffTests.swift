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

    // MARK: - Memory budget

    func testDiffBudgetRejectsPathologicalSizes() {
        // Two 20k-word texts with nothing in common would ask for ~1.6 GB.
        XCTAssertTrue(WordDiff.exceedsDiffBudget(20_000, 20_000))
    }

    func testDiffBudgetAllowsRealisticSizes() {
        // A long document whose changed middle region is still substantial.
        XCTAssertFalse(WordDiff.exceedsDiffBudget(1_500, 1_500))
    }

    func testDiffBudgetIsOverflowSafe() {
        XCTAssertTrue(WordDiff.exceedsDiffBudget(Int.max, Int.max))
    }

    func testOversizedDiffDegradesToReplaceRatherThanAllocating() {
        // Nothing shared, so the prefix/suffix trim cannot help.
        let original = (0..<3_000).map { "alpha\($0)" }.joined(separator: " ")
        let revised = (0..<3_000).map { "omega\($0)" }.joined(separator: " ")

        let ops = WordDiff.diff(original: original, revised: revised)

        // Must terminate and stay small rather than building a 9M-cell table.
        XCTAssertFalse(ops.isEmpty)
        let hasDeletion = ops.contains { if case .deletion = $0 { return true } else { return false } }
        let hasInsertion = ops.contains { if case .insertion = $0 { return true } else { return false } }
        XCTAssertTrue(hasDeletion)
        XCTAssertTrue(hasInsertion)
    }

    func testOversizedDiffStillRoundTrips() {
        let original = (0..<3_000).map { "alpha\($0)" }.joined(separator: " ")
        let revised = (0..<3_000).map { "omega\($0)" }.joined(separator: " ")

        let ops = WordDiff.diff(original: original, revised: revised)
        var rebuiltOriginal = ""
        var rebuiltRevised = ""
        for op in ops {
            switch op {
            case .equal(let text):
                rebuiltOriginal += text
                rebuiltRevised += text
            case .deletion(let text):
                rebuiltOriginal += text
            case .insertion(let text):
                rebuiltRevised += text
            }
        }
        XCTAssertEqual(rebuiltOriginal, original)
        XCTAssertEqual(rebuiltRevised, revised)
    }
}
