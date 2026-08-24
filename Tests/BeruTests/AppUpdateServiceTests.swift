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

    func testPatchTenIsNewerThanPatchEight() {
        // Guards the 1.1.8 → 1.1.10 case that exposed the "no Update chip"
        // complaint: compare must not treat "10" as less than "8".
        XCTAssertTrue(AppUpdateFeed.isNewer("1.1.10", than: "1.1.8"))
        XCTAssertTrue(AppUpdateFeed.isNewer("1.1.9", than: "1.1.8"))
        XCTAssertFalse(AppUpdateFeed.isNewer("1.1.8", than: "1.1.10"))
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

    func testAboutStatusCaption() {
        let dummy = URL(string: "https://github.com/rahulsharmadesign/beru/releases/download/v1.1.10/Beru-1.1.10.dmg")!
        XCTAssertEqual(
            AppUpdateService.statusCaption(status: .idle, note: .none),
            "Check GitHub for a newer DMG."
        )
        XCTAssertEqual(
            AppUpdateService.statusCaption(status: .idle, note: .upToDate),
            "You’re on the latest version."
        )
        XCTAssertEqual(
            AppUpdateService.statusCaption(status: .checking, note: .none),
            "Checking GitHub for a newer build…"
        )
        XCTAssertEqual(
            AppUpdateService.statusCaption(status: .available(version: "1.1.10", downloadURL: dummy), note: .none),
            "Beru 1.1.10 is ready to install."
        )
        XCTAssertEqual(
            AppUpdateService.statusCaption(status: .idle, note: .localBuild),
            "This is a local signing build. GitHub updates are skipped so they don’t overwrite it."
        )
    }
}
