import XCTest
@testable import Enhancify

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

    func testLocalDevelopmentBuildNeverOffersUpdate() {
        XCTAssertFalse(
            AppUpdateFeed.shouldOfferUpdate(latest: "1.1.8", current: "1.1.7", isLocalDevelopmentBuild: true)
        )
        XCTAssertTrue(
            AppUpdateFeed.shouldOfferUpdate(latest: "1.1.8", current: "1.1.7", isLocalDevelopmentBuild: false)
        )
        XCTAssertFalse(
            AppUpdateFeed.shouldOfferUpdate(latest: "1.1.8", current: "1.1.8", isLocalDevelopmentBuild: false)
        )
    }

    func testPrefersMatchingEnhancifyDMG() {
        let assets = ["notes.txt", "Enhancify-1.2.0.dmg", "Enhancify-1.2.0.zip"]
        XCTAssertEqual(AppUpdateFeed.dmgAsset(named: assets, preferring: "1.2.0"), "Enhancify-1.2.0.dmg")
    }

    func testFallsBackToABareDMGWhenTheNameOmitsEnhancify() {
        XCTAssertEqual(
            AppUpdateFeed.dmgAsset(named: ["notes.txt", "V1.01_build_16.dmg"], preferring: "1.01"),
            "V1.01_build_16.dmg"
        )
    }

    func testPlainHTTPDownloadIsNeverTrusted() {
        XCTAssertFalse(AppUpdateFeed.isTrustedDownload(
            URL(string: "http://github.com/rahulsharmadesign/enhancify/releases/download/v2.0.0/Enhancify-2.0.0.dmg")!
        ))
    }

    func testTrustedDownloadHosts() {
        XCTAssertTrue(
            AppUpdateFeed.isTrustedDownload(
                URL(string: "https://github.com/rahulsharmadesign/enhancify/releases/download/v1.1.2/Enhancify-1.1.2.dmg")!
            )
        )
        XCTAssertTrue(
            AppUpdateFeed.isTrustedDownload(
                URL(string: "https://objects.githubusercontent.com/github-production-release-asset-2e65be/Enhancify.dmg")!
            )
        )
        XCTAssertFalse(
            AppUpdateFeed.isTrustedDownload(URL(string: "https://example.com/Enhancify.dmg")!)
        )
    }
}
