import XCTest
@testable import Beru

/// The sidebar is built from `menu` and `footer` rather than `allCases`, so a
/// new route compiles, works, and is simply unreachable — which is exactly the
/// kind of miss no compiler catches.
final class DashboardRouteTests: XCTestCase {

    func testEveryRouteIsReachableFromTheSidebar() {
        let listed = Set(DashboardRoute.menu + DashboardRoute.footer)
        let missing = Set(DashboardRoute.allCases).subtracting(listed)
        XCTAssertTrue(
            missing.isEmpty,
            "unreachable route(s): \(missing.map(\.rawValue).sorted()) — add to menu or footer"
        )
    }

    func testNoRouteAppearsInBothMenuAndFooter() {
        let overlap = Set(DashboardRoute.menu).intersection(DashboardRoute.footer)
        XCTAssertTrue(overlap.isEmpty, "duplicated route(s): \(overlap.map(\.rawValue))")
    }

    func testEveryRouteHasATitleAndASubtitleToRender() {
        for route in DashboardRoute.allCases {
            XCTAssertFalse(route.title.isEmpty, "\(route.rawValue) has no title")
            XCTAssertFalse(
                route.pageSubtitle.isEmpty,
                "\(route.rawValue) has no subtitle — the header renders it now"
            )
            XCTAssertFalse(route.lucideIcon.isEmpty, "\(route.rawValue) has no icon")
            XCTAssertFalse(route.systemImage.isEmpty, "\(route.rawValue) has no sidebar symbol")
        }
    }

    func testSettingsKeepsToTheFourPages() {
        XCTAssertEqual(DashboardRoute.allCases, [.general, .models, .permissions, .about])
    }

    func testRouteIDMatchesRawValueSoSelectionSurvivesEncoding() {
        for route in DashboardRoute.allCases {
            XCTAssertEqual(route.id, route.rawValue)
            XCTAssertEqual(DashboardRoute(rawValue: route.rawValue), route)
        }
    }
}
