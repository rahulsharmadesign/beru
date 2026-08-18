import XCTest
@testable import Beru

final class PanelCloseChromeTests: XCTestCase {
    func testCloseDiscIsTrafficLightSized() {
        XCTAssertEqual(PanelCloseChromePolicy.discSize, 12)
        XCTAssertGreaterThan(PanelCloseChromePolicy.hitSize, PanelCloseChromePolicy.discSize)
    }

    func testCloseStripSitsAboveTheInnerCards() {
        XCTAssertEqual(PanelMetrics.closeStripHeight, 28)
    }
}
