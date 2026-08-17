import XCTest
@testable import Beru

final class TokenEstimateTests: XCTestCase {
    func testEmptyAndWhitespaceCostNothing() {
        XCTAssertEqual(TokenEstimate.tokens(in: ""), 0)
        XCTAssertEqual(TokenEstimate.tokens(in: "   \n\t "), 0)
    }

    func testEveryChunkCostsAtLeastOneToken() {
        // The floor is the whole point of not using a flat chars/4: nine
        // one-character words cannot tokenize to two tokens.
        XCTAssertEqual(TokenEstimate.tokens(in: "a b c d e f g h i"), 9)
    }

    func testProseLandsNearTheKnownRatio() {
        // 45 characters of ordinary English; a BPE tokenizer puts this in the
        // low teens, so the estimate must not be off by a factor.
        let text = "The quick brown fox jumps over the lazy dog."
        let estimate = TokenEstimate.tokens(in: text)
        XCTAssertGreaterThanOrEqual(estimate, 9)
        XCTAssertLessThanOrEqual(estimate, 14)
    }

    func testLongWordsCostMoreThanOneToken() {
        XCTAssertGreaterThan(
            TokenEstimate.tokens(in: "internationalization"),
            TokenEstimate.tokens(in: "cat")
        )
    }

    func testMonotonicInLength() {
        let short = TokenEstimate.tokens(in: "one two three")
        let long = TokenEstimate.tokens(in: "one two three four five six seven")
        XCTAssertGreaterThan(long, short)
    }

    func testWideScriptCostsAboutOneTokenPerCharacter() {
        // Four CJK characters must not collapse to one token the way four
        // Latin characters do.
        XCTAssertEqual(TokenEstimate.tokens(in: "你好世界"), 4)
    }
}

final class TokenSavingsTests: XCTestCase {
    func testShorterOutputSaves() {
        let savings = TokenSavings(inputTokens: 100, outputTokens: 60)
        XCTAssertEqual(savings.savedTokens, 40)
        XCTAssertEqual(savings.direction, .leaner)
        XCTAssertEqual(savings.percent, 40)
        XCTAssertEqual(savings.shortLabel, "\u{2212}40 tok")
    }

    func testLongerOutputIsReportedAsGrowthNotZero() {
        let savings = TokenSavings(inputTokens: 100, outputTokens: 130)
        XCTAssertEqual(savings.savedTokens, -30)
        XCTAssertEqual(savings.direction, .longer)
        // Magnitude only — the sign lives in the glyph, not the percentage.
        XCTAssertEqual(savings.percent, 30)
        XCTAssertEqual(savings.shortLabel, "+30 tok")
    }

    func testEqualLengthIsNeitherWinNorLoss() {
        let savings = TokenSavings(inputTokens: 50, outputTokens: 50)
        XCTAssertEqual(savings.direction, .unchanged)
        XCTAssertEqual(savings.savedTokens, 0)
        XCTAssertEqual(savings.shortLabel, "±0 tok")
    }

    func testEmptyInputDoesNotDivideByZero() {
        let savings = TokenSavings(inputTokens: 0, outputTokens: 0)
        XCTAssertEqual(savings.ratio, 0)
        XCTAssertEqual(savings.percent, 0)
        XCTAssertEqual(savings.outputShare, 1)
    }

    func testOutputShareIsClampedForTheMeter() {
        let grown = TokenSavings(inputTokens: 10, outputTokens: 90)
        XCTAssertEqual(grown.outputShare, 1)
        let halved = TokenSavings(inputTokens: 10, outputTokens: 5)
        XCTAssertEqual(halved.outputShare, 0.5, accuracy: 0.0001)
    }

    func testDerivedFromTextMatchesTheEstimator() {
        let savings = TokenSavings(input: "one two three four", output: "one two")
        XCTAssertEqual(savings.inputTokens, TokenEstimate.tokens(in: "one two three four"))
        XCTAssertEqual(savings.outputTokens, TokenEstimate.tokens(in: "one two"))
        XCTAssertEqual(savings.direction, .leaner)
    }

    func testDetailAlwaysSaysItIsAnEstimate() {
        for savings in [
            TokenSavings(inputTokens: 10, outputTokens: 4),
            TokenSavings(inputTokens: 4, outputTokens: 10),
            TokenSavings(inputTokens: 7, outputTokens: 7)
        ] {
            XCTAssertTrue(savings.detail.contains("Estimated"), savings.detail)
        }
    }
}

@MainActor
final class SavingsStoreTests: XCTestCase {
    private func makeStore() -> SavingsStore {
        // A throwaway suite so the real lifetime totals are never touched.
        let defaults = UserDefaults(suiteName: "com.rahul.beru.tests.\(UUID().uuidString)")!
        return SavingsStore(defaults: defaults)
    }

    func testStartsEmpty() {
        let store = makeStore()
        XCTAssertFalse(store.hasData)
        XCTAssertEqual(store.totalSavedTokens, 0)
        XCTAssertNil(store.trackingSince)
    }

    func testAccumulatesAcrossRuns() {
        let store = makeStore()
        store.record(TokenSavings(inputTokens: 100, outputTokens: 70))
        let total = store.record(TokenSavings(inputTokens: 200, outputTokens: 130))
        XCTAssertEqual(store.acceptedRuns, 2)
        XCTAssertEqual(store.totalInputTokens, 300)
        XCTAssertEqual(store.totalOutputTokens, 200)
        XCTAssertEqual(store.totalSavedTokens, 100)
        XCTAssertEqual(total, 100)
        XCTAssertNotNil(store.trackingSince)
    }

    func testRatioIsWeightedByVolumeNotAveragedPerRun() {
        let store = makeStore()
        // A tiny 50%-saving run must not outweigh a large 10%-saving one.
        store.record(TokenSavings(inputTokens: 2, outputTokens: 1))
        store.record(TokenSavings(inputTokens: 1000, outputTokens: 900))
        XCTAssertEqual(store.ratio, 101.0 / 1002.0, accuracy: 0.0001)
        XCTAssertEqual(store.percent, 10)
    }

    func testGrowthMakesTheTotalNegativeRatherThanZero() {
        let store = makeStore()
        store.record(TokenSavings(inputTokens: 10, outputTokens: 40))
        XCTAssertEqual(store.totalSavedTokens, -30)
        XCTAssertTrue(store.hasData)
    }

    func testTrackingSinceIsSetOnceAndKept() {
        let store = makeStore()
        store.record(TokenSavings(inputTokens: 10, outputTokens: 5))
        let first = store.trackingSince
        store.record(TokenSavings(inputTokens: 10, outputTokens: 5))
        XCTAssertEqual(store.trackingSince, first)
    }

    func testResetClearsEverything() {
        let store = makeStore()
        store.record(TokenSavings(inputTokens: 100, outputTokens: 40))
        store.reset()
        XCTAssertFalse(store.hasData)
        XCTAssertEqual(store.totalSavedTokens, 0)
        XCTAssertEqual(store.totalInputTokens, 0)
        XCTAssertNil(store.trackingSince)
    }

    func testTotalsSurviveAcrossInstances() {
        let suite = "com.rahul.beru.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        SavingsStore(defaults: defaults).record(TokenSavings(inputTokens: 80, outputTokens: 30))
        let reloaded = SavingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.totalSavedTokens, 50)
        XCTAssertEqual(reloaded.acceptedRuns, 1)
    }
}
