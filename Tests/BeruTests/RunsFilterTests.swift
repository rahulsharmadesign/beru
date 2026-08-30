import XCTest
@testable import Beru

/// The All Runs filters. Pure rules, tested without a view.
final class RunsFilterTests: XCTestCase {
    private func run(
        action: String? = "enhance",
        app: String? = "Cursor",
        input: String = "some input",
        output: String? = "some output",
        rationale: String? = nil,
        outcome: UsageRun.Outcome = .replaced
    ) -> UsageRun {
        UsageRun(
            id: UUID(),
            startedAt: Date(),
            hostAppName: app,
            hostBundleID: nil,
            targetID: nil,
            actionID: action,
            actionName: action,
            model: nil,
            providerKind: nil,
            inputText: input,
            outputText: output,
            rationale: rationale,
            instruction: nil,
            inputTokens: nil,
            outputTokens: nil,
            savedTokens: nil,
            outcome: outcome,
            generationCount: 1,
            totalMs: nil,
            truncated: false
        )
    }

    private func filter(
        _ runs: [UsageRun],
        query: String = "",
        acceptedOnly: Bool = false,
        action: String? = nil,
        app: String? = nil
    ) -> [UsageRun] {
        RunsModel.filter(runs, query: query, acceptedOnly: acceptedOnly, action: action, app: app)
    }

    func testNoFiltersKeepsEverything() {
        let runs = [run(), run(outcome: .dismissed)]
        XCTAssertEqual(filter(runs).count, 2)
    }

    /// "Accepted only" has to mean the same thing the savings total means, or
    /// the list and the number on Home describe different sets of runs.
    func testAcceptedOnlyMatchesWhatCreditsTheSavingsTotal() {
        let runs = [
            run(outcome: .replaced),
            run(outcome: .copied),
            run(outcome: .dismissed),
            run(outcome: .abandoned),
            run(outcome: .cancelled),
            run(outcome: .failed("boom"))
        ]
        let kept = filter(runs, acceptedOnly: true)
        XCTAssertEqual(kept.count, 2)
        XCTAssertTrue(kept.allSatisfy(\.outcome.wasAccepted))
    }

    /// Search covers what the user wrote and what they got back, including the
    /// explanation — that is often the only place a memorable phrase lives.
    func testSearchLooksAtInputResultAndRationale() {
        let runs = [
            run(input: "fix the flaky retry test", output: "nothing here"),
            run(input: "nothing here", output: "Verify with swift test"),
            run(input: "nothing", output: "nothing", rationale: "Cut the hedging")
        ]
        XCTAssertEqual(filter(runs, query: "flaky").count, 1)
        XCTAssertEqual(filter(runs, query: "swift test").count, 1)
        XCTAssertEqual(filter(runs, query: "hedging").count, 1)
    }

    func testSearchIgnoresCaseAndSurroundingSpace() {
        let runs = [run(input: "The Flaky Retry Test")]
        XCTAssertEqual(filter(runs, query: "  FLAKY  ").count, 1)
    }

    /// A run that failed before producing text has no output. Search must not
    /// drop it from an unrelated query or crash on the nil.
    func testARunWithNoOutputIsStillSearchableByItsInput()  {
        let runs = [run(input: "the thing I typed", output: nil, outcome: .failed("no"))]
        XCTAssertEqual(filter(runs, query: "typed").count, 1)
        XCTAssertEqual(filter(runs, query: "absent").count, 0)
    }

    func testActionAndAppFiltersCombine() {
        let runs = [
            run(action: "enhance", app: "Cursor"),
            run(action: "grammar", app: "Cursor"),
            run(action: "enhance", app: "Slack")
        ]
        XCTAssertEqual(filter(runs, action: "enhance").count, 2)
        XCTAssertEqual(filter(runs, app: "Cursor").count, 2)
        XCTAssertEqual(filter(runs, action: "enhance", app: "Cursor").count, 1)
    }

    func testFiltersAndSearchApplyTogether() {
        let runs = [
            run(action: "enhance", app: "Cursor", input: "flaky test", outcome: .replaced),
            run(action: "enhance", app: "Cursor", input: "flaky test", outcome: .dismissed),
            run(action: "grammar", app: "Cursor", input: "flaky test", outcome: .replaced)
        ]
        let kept = filter(runs, query: "flaky", acceptedOnly: true, action: "enhance", app: "Cursor")
        XCTAssertEqual(kept.count, 1)
    }

    func testEnhanceAgainPrefersTheResultThenTheInput() {
        XCTAssertEqual(run(input: "draft", output: "polished").enhanceAgainText, "polished")
        XCTAssertEqual(run(input: "draft", output: nil).enhanceAgainText, "draft")
        XCTAssertEqual(run(input: "draft", output: "  ").enhanceAgainText, "draft")
        XCTAssertNil(run(input: "", output: nil).enhanceAgainText)
    }

    func testResultForVaultIgnoresEmptyOutput() {
        XCTAssertEqual(run(output: "done").resultForVault, "done")
        XCTAssertNil(run(output: nil).resultForVault)
        XCTAssertNil(run(output: "\n").resultForVault)
    }

    func testSuggestedVaultTitleStripsAHeading() {
        XCTAssertEqual(
            run(action: "enhance", output: "# Ship it\n\nBody").suggestedVaultTitle,
            "Ship it"
        )
        XCTAssertEqual(run(action: "Grammar", output: nil).suggestedVaultTitle, "Grammar")
    }
}
