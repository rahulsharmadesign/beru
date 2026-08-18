import XCTest
@testable import Beru

final class AppUpdateServiceTests: XCTestCase {
    func testTagStripsLeadingV() {
        XCTAssertEqual(AppUpdateFeed.version(fromTag: "v1.1.2"), "1.1.2")
        XCTAssertEqual(AppUpdateFeed.version(fromTag: "1.1.2"), "1.1.2")
    }

    func testNewerVersionIsDetected() {
        XCTAssertTrue(AppUpdateFeed.isNewer("1.1.2", than: "1.1.1"))
        XCTAssertTrue(AppUpdateFeed.isNewer("v1.2.0", than: "1.1.9"))
        XCTAssertFalse(AppUpdateFeed.isNewer("1.1.1", than: "1.1.1"))
        XCTAssertFalse(AppUpdateFeed.isNewer("1.1.0", than: "1.1.1"))
    }

    func testPrefersMatchingBeruDMG() {
        let assets = ["notes.txt", "Beru-1.1.2.dmg", "Beru-1.1.2.zip"]
        XCTAssertEqual(AppUpdateFeed.dmgAsset(named: assets, preferring: "1.1.2"), "Beru-1.1.2.dmg")
    }

    func testTrustedDownloadHosts() {
        XCTAssertTrue(
            AppUpdateFeed.isTrustedDownload(
                URL(string: "https://github.com/rahulsharmadesign/beru/releases/download/v1.1.2/Beru-1.1.2.dmg")!
            )
        )
        XCTAssertTrue(
            AppUpdateFeed.isTrustedDownload(
                URL(string: "https://objects.githubusercontent.com/github-production-release-asset-2e65be/Beru.dmg")!
            )
        )
        XCTAssertFalse(
            AppUpdateFeed.isTrustedDownload(URL(string: "https://example.com/Beru.dmg")!)
        )
    }
}
