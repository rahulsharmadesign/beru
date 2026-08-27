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
}
