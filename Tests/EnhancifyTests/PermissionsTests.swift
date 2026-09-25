import XCTest
@testable import Enhancify

final class PermissionsTests: XCTestCase {
    func testPrivacyURLsUseCurrentAndLegacySystemSettingsIdentifiers() {
        XCTAssertTrue(Permissions.accessibilityURLs.contains {
            $0.contains("PrivacySecurity.extension") && $0.contains("Privacy_Accessibility")
        })
        XCTAssertTrue(Permissions.accessibilityURLs.contains {
            $0.contains("com.apple.preference.security") && $0.contains("Privacy_Accessibility")
        })
        XCTAssertTrue(Permissions.microphoneURLs.contains { $0.contains("Privacy_Microphone") })
        XCTAssertTrue(Permissions.speechRecognitionURLs.contains { $0.contains("Privacy_SpeechRecognition") })
        XCTAssertTrue(Permissions.keyboardDictationURLs.contains { $0.contains("Dictation") || $0.contains("keyboard") })
    }

    func testPostUpdateNudgeFiresOnlyOnChangedBuildWithoutTrust() {
        XCTAssertTrue(AppCoordinator.needsPostUpdateNudge(lastRunBuild: "28", currentBuild: "29", isTrusted: false))
        XCTAssertFalse(AppCoordinator.needsPostUpdateNudge(lastRunBuild: "29", currentBuild: "29", isTrusted: false))
        XCTAssertFalse(AppCoordinator.needsPostUpdateNudge(lastRunBuild: "28", currentBuild: "29", isTrusted: true))
        XCTAssertFalse(AppCoordinator.needsPostUpdateNudge(lastRunBuild: nil, currentBuild: "29", isTrusted: false))
        XCTAssertFalse(AppCoordinator.needsPostUpdateNudge(lastRunBuild: "", currentBuild: "29", isTrusted: false))
        XCTAssertFalse(AppCoordinator.needsPostUpdateNudge(lastRunBuild: "28", currentBuild: nil, isTrusted: false))
    }
}
