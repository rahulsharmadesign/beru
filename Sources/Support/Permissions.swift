import AppKit
import ApplicationServices

enum Permissions {
    static func isAccessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the system dialog to grant Accessibility access if not already trusted.
    @discardableResult
    static func requestAccessibilityIfNeeded() -> Bool {
        let options: [String: Bool] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    static func openAccessibilitySettings() {
        open(Self.accessibilityURLs)
    }

    /// Microphone pane. Speech Recognition is the neighbouring row, so this
    /// lands the user close enough to fix either.
    static func openPrivacySettings() {
        openMicrophoneSettings()
    }

    static func openMicrophoneSettings() {
        open(Self.microphoneURLs)
    }

    static func openSpeechRecognitionSettings() {
        open(Self.speechRecognitionURLs)
    }

    /// On-device language packs live under Keyboard › Dictation.
    static func openKeyboardDictationSettings() {
        open(Self.keyboardDictationURLs)
    }

    /// URLs tried in order. System Settings identifiers changed from the
    /// pre-Ventura preference pane to `PrivacySecurity.extension`.
    static let accessibilityURLs = [
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    ]
    static let microphoneURLs = [
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Microphone",
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
    ]
    static let speechRecognitionURLs = [
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_SpeechRecognition",
        "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition"
    ]
    static let keyboardDictationURLs = [
        "x-apple.systempreferences:com.apple.Keyboard-Settings.extension?Dictation",
        "x-apple.systempreferences:com.apple.preference.keyboard?Dictation",
        "x-apple.systempreferences:com.apple.preference.keyboard"
    ]

    @discardableResult
    static func open(_ urlStrings: [String]) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        for string in urlStrings {
            guard let url = URL(string: string) else { continue }
            if NSWorkspace.shared.open(url) { return true }
        }
        return false
    }
}
