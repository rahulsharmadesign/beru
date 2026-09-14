import XCTest
@testable import Beru

/// `isConfigured` gates onboarding and the panel's setup placeholder. When it
/// returns a false positive the user reaches a working-looking app that fails on
/// first use, so the validation is worth pinning down.
final class ProviderConfigurationTests: XCTestCase {

    // MARK: - Base URL validation

    func testWellFormedURLsAreUsable() {
        XCTAssertTrue(SettingsStore.isUsableBaseURL("http://localhost:11434"))
        XCTAssertTrue(SettingsStore.isUsableBaseURL("https://api.groq.com/openai/v1"))
        XCTAssertTrue(SettingsStore.isUsableBaseURL("  https://api.openai.com/v1  "))
    }

    func testEmptyOrWhitespaceURLIsNotUsable() {
        XCTAssertFalse(SettingsStore.isUsableBaseURL(""))
        XCTAssertFalse(SettingsStore.isUsableBaseURL("   "))
        XCTAssertFalse(SettingsStore.isUsableBaseURL("\n\t"))
    }

    func testNonURLTextIsNotUsable() {
        // All of these passed the old non-empty check.
        XCTAssertFalse(SettingsStore.isUsableBaseURL("hello"))
        XCTAssertFalse(SettingsStore.isUsableBaseURL("localhost:11434"), "No scheme.")
        XCTAssertFalse(SettingsStore.isUsableBaseURL("://nohost"))
    }

    func testNonHTTPSchemesAreRejected() {
        XCTAssertFalse(SettingsStore.isUsableBaseURL("ftp://example.com"))
        XCTAssertFalse(SettingsStore.isUsableBaseURL("file:///etc/passwd"))
        XCTAssertFalse(SettingsStore.isUsableBaseURL("javascript:alert(1)"))
    }

    // MARK: - Loopback detection

    func testLoopbackHostsAreRecognised() {
        XCTAssertTrue(SettingsStore.isLoopback("http://localhost:11434"))
        XCTAssertTrue(SettingsStore.isLoopback("http://127.0.0.1:1234/v1"))
        XCTAssertTrue(SettingsStore.isLoopback("http://[::1]:8080"))
    }

    func testRemoteHostsAreNotLoopback() {
        XCTAssertFalse(SettingsStore.isLoopback("https://api.openai.com/v1"))
    }

    func testHostnameContainingLocalhostIsNotLoopback() {
        // The old check was a substring match, so this counted as loopback and
        // skipped the API-key requirement.
        XCTAssertFalse(SettingsStore.isLoopback("https://localhost.evil.example.com/v1"))
        XCTAssertFalse(SettingsStore.isLoopback("https://not-127.0.0.1.example.com/v1"))
    }

    // MARK: - Model and key validation

    func testWhitespaceOnlyModelIsNotUsable() {
        XCTAssertFalse(SettingsStore.isUsableModel("   "))
        XCTAssertTrue(SettingsStore.isUsableModel("llama3.1"))
    }

    func testWhitespaceOnlyKeyIsNotUsable() {
        XCTAssertFalse(SettingsStore.isUsableKey(nil))
        XCTAssertFalse(SettingsStore.isUsableKey(""))
        XCTAssertFalse(SettingsStore.isUsableKey("  \n "))
        XCTAssertTrue(SettingsStore.isUsableKey("sk-abc123"))
    }
}

final class CompatibleAPIPresetTests: XCTestCase {
    func testMatchingRecognisesKnownHosts() {
        XCTAssertEqual(
            CompatibleAPIPreset.matching(baseURL: "https://api.groq.com/openai/v1"),
            .groq
        )
        XCTAssertEqual(
            CompatibleAPIPreset.matching(baseURL: "https://api.openai.com/v1"),
            .openAI
        )
        XCTAssertEqual(
            CompatibleAPIPreset.matching(baseURL: "https://openrouter.ai/api/v1"),
            .openRouter
        )
    }

    func testMatchingTreatsUnknownHostsAsCustom() {
        XCTAssertEqual(
            CompatibleAPIPreset.matching(baseURL: "http://127.0.0.1:1234/v1"),
            .custom
        )
        XCTAssertEqual(
            CompatibleAPIPreset.matching(baseURL: "https://api.example.com/v1"),
            .custom
        )
    }

    func testMatchingEmptyURLDefaultsToGroq() {
        XCTAssertEqual(CompatibleAPIPreset.matching(baseURL: ""), .groq)
        XCTAssertEqual(CompatibleAPIPreset.matching(baseURL: "  "), .groq)
    }

    func testMatchingIsCaseInsensitive() {
        XCTAssertEqual(
            CompatibleAPIPreset.matching(baseURL: "HTTPS://API.GROQ.COM/openai/v1"),
            .groq
        )
    }

    func testNamedPresetsCarryABaseURLAndModel() {
        for preset in CompatibleAPIPreset.allCases where preset != .custom {
            XCTAssertFalse(preset.baseURL.isEmpty, "\(preset.title) needs a base URL")
            XCTAssertFalse(preset.defaultModel.isEmpty, "\(preset.title) needs a default model")
        }
        XCTAssertTrue(CompatibleAPIPreset.custom.baseURL.isEmpty)
        XCTAssertTrue(CompatibleAPIPreset.custom.defaultModel.isEmpty)
    }
}
