import XCTest
@testable import Beru

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
}
