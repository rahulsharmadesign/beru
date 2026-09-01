import XCTest
@testable import Beru

final class PanelViewportCapTests: XCTestCase {
    func testViewportCapIsSeventyFivePercent() {
        XCTAssertEqual(PanelMetrics.maxViewportFraction, 0.75, accuracy: 0.0001)
    }

    func testLayoutIdealIsChromePlusResult() {
        let layout = PanelLayoutHeights(chrome: 120, result: 400)
        XCTAssertEqual(layout.ideal, 520)
    }

    func testScrollBudgetKeepsChromePinned() {
        let chrome: CGFloat = 180
        let cap: CGFloat = 600
        let resultIdeal: CGFloat = 900
        XCTAssertGreaterThan(chrome + resultIdeal, cap)

        let scroll = max(PanelMetrics.resultIdleMinHeight, (cap - chrome).rounded())
        let window = min(cap, chrome + scroll)
        XCTAssertEqual(window, cap)
        XCTAssertEqual(scroll + chrome, window)
        XCTAssertGreaterThanOrEqual(scroll, PanelMetrics.resultIdleMinHeight)
    }

    func testModuleInsetsStayAtTen() {
        XCTAssertEqual(PanelMetrics.moduleInset, 10)
        XCTAssertEqual(PanelMetrics.moduleSpacing, 10)
    }

    func testMinimumChromeSitsBetweenGarbageAndRealChrome() {
        let garbage = PanelMetrics.moduleInset * 2 + PanelMetrics.moduleSpacing * 2
        XCTAssertGreaterThan(PanelMetrics.minimumChromeHeight, garbage)
        let realIdle = PanelLayoutHeights.fromBands(
            top: PanelMetrics.closeStripHeight + PanelMetrics.moduleSpacing + PanelMetrics.chipRowHeight,
            bottom: PanelMetrics.composerMinHeight,
            result: PanelMetrics.resultIdleMinHeight
        )
        XCTAssertNotNil(realIdle)
        XCTAssertGreaterThanOrEqual(realIdle!.chrome, PanelMetrics.minimumChromeHeight)
    }

    func testIncompleteChromeBandsAreIgnored() {
        XCTAssertNil(PanelLayoutHeights.fromBands(top: 0, bottom: 0, result: 80))
        XCTAssertNil(PanelLayoutHeights.fromBands(top: 90, bottom: 0, result: 80))
        XCTAssertNil(PanelLayoutHeights.fromBands(top: 0, bottom: 80, result: 80))
    }

    func testCompleteBandsProduceChromeThatIncludesInsets() {
        let top = PanelMetrics.closeStripHeight + PanelMetrics.moduleSpacing + PanelMetrics.chipRowHeight
        let bottom = PanelMetrics.composerMinHeight
        let layout = PanelLayoutHeights.fromBands(top: top, bottom: bottom, result: 72)
        XCTAssertEqual(
            layout?.chrome,
            PanelMetrics.moduleInset * 2 + top + bottom + PanelMetrics.moduleSpacing * 2
        )
        XCTAssertEqual(layout?.result, 72)
    }

    func testUndersizedChromeKeepsTheLastRealChrome() {
        let last = 220 as CGFloat
        let applied = PanelLayoutHeights.resolved(
            layout: PanelLayoutHeights(chrome: 40, result: 80),
            lastChrome: last,
            lastResult: 80
        )
        XCTAssertEqual(applied?.chrome, last)
        XCTAssertEqual(applied?.lastChrome, last)
        XCTAssertEqual(applied?.result, 80)
    }

    func testFirstUndersizedChromeDoesNotResize() {
        XCTAssertNil(PanelLayoutHeights.resolved(
            layout: PanelLayoutHeights(chrome: 40, result: 80),
            lastChrome: 0,
            lastResult: 0
        ))
    }

    func testValidChromeMayShrinkWhenTheFooterHides() {
        let applied = PanelLayoutHeights.resolved(
            layout: PanelLayoutHeights(chrome: 214, result: 72),
            lastChrome: 238,
            lastResult: 72
        )
        XCTAssertEqual(applied?.chrome, 214)
        XCTAssertEqual(applied?.lastChrome, 214)
    }

    func testTabChangeShrinksImmediatelyAndUnanimated() {
        XCTAssertEqual(
            PanelLayoutHeights.shrinkBehavior(isTabChange: true, isStreaming: false),
            .applyNowUnanimated
        )
        XCTAssertEqual(
            PanelLayoutHeights.shrinkBehavior(isTabChange: true, isStreaming: true),
            .applyNowUnanimated
        )
    }

    func testStreamingShrinkIsSkippedUntilFlush() {
        XCTAssertEqual(
            PanelLayoutHeights.shrinkBehavior(isTabChange: false, isStreaming: true),
            .skip
        )
    }

    func testNonTabShrinkDebouncesAndAnimates() {
        XCTAssertEqual(
            PanelLayoutHeights.shrinkBehavior(isTabChange: false, isStreaming: false),
            .debounceAnimated
        )
    }

    func testMissingResultKeepsTheLastRealResult() {
        let applied = PanelLayoutHeights.resolved(
            layout: PanelLayoutHeights(chrome: 220, result: 0),
            lastChrome: 220,
            lastResult: 400
        )
        XCTAssertEqual(applied?.result, 400)
        XCTAssertEqual(applied?.lastResult, 400)
        XCTAssertEqual(applied?.chrome, 220)
    }
}
