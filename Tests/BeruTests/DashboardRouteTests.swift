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
        }
    }

    func testWorkspaceRoutesAreTheOnesGroupedBelowSettings() {
        XCTAssertEqual(
            Set(DashboardRoute.allCases.filter(\.isWorkspace)),
            [.vault, .runs, .actions, .targets]
        )
    }

    func testEmptyQueryMatchesEverythingSoTheSidebarIsNeverBlank() {
        for route in DashboardRoute.allCases {
            XCTAssertTrue(route.matches(""))
            XCTAssertTrue(route.matches("   "))
        }
    }

    func testSearchMatchesTitleCaseInsensitively() {
        XCTAssertTrue(DashboardRoute.models.matches("MODELS"))
        XCTAssertTrue(DashboardRoute.models.matches("mod"))
        XCTAssertFalse(DashboardRoute.models.matches("zzzz"))
    }

    func testSearchMatchesSubtitleText() {
        XCTAssertTrue(
            DashboardRoute.permissions.matches("dictation"),
            "subtitles are searchable, which is why they must not be empty"
        )
    }

    /// The Tip card's CTA sends people to Models, and "tip" is how they look for
    /// it again afterwards.
    func testAboutIsFindableByItsExtraSearchTerms() {
        XCTAssertTrue(DashboardRoute.about.matches("tip"))
        XCTAssertTrue(DashboardRoute.about.matches("version"))
        XCTAssertTrue(DashboardRoute.about.matches("update"))
    }

    func testRouteIDMatchesRawValueSoSelectionSurvivesEncoding() {
        for route in DashboardRoute.allCases {
            XCTAssertEqual(route.id, route.rawValue)
            XCTAssertEqual(DashboardRoute(rawValue: route.rawValue), route)
        }
    }
}
