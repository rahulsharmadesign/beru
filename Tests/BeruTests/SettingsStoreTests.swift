import XCTest
@testable import Beru

/// `Sources/Settings/` had no tests, and its init is one long list of defaults
/// where a subtle mistake looks correct: `bool(forKey:)` returns false for an
/// unset key, so any setting that should default to **on** has to check for the
/// key's presence instead. Getting that wrong ships a feature silently disabled
/// for every existing install, and nothing about the code looks wrong.
@MainActor
final class SettingsStoreTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "beru.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    // MARK: - Defaults on a clean install

    func testCleanInstallDefaultsToLocalOllama() {
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.activeProvider, .ollama)
        XCTAssertEqual(store.ollamaBaseURL, "http://localhost:11434/v1")
    }

    func testBothOllamaRolesDefaultToTheSameModel() {
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.ollamaEnhanceModel, RecommendedOllamaModel.defaultID)
        XCTAssertEqual(
            store.ollamaGrammarModel, store.ollamaEnhanceModel,
            "two models make Ollama swap weights on every tab switch"
        )
    }

    func testSettingsThatDefaultOnSurviveAnUnsetKey() {
        let store = SettingsStore(defaults: defaults)
        XCTAssertTrue(store.explainChanges)
        XCTAssertTrue(store.sessionContextEnabled)
    }

    func testRecordingIsOffUntilExplicitlyChosen() {
        let store = SettingsStore(defaults: defaults)
        XCTAssertFalse(
            store.usageLoggingEnabled,
            "selected text can contain secrets; recording must be opt-in"
        )
    }

    func testAnExplicitOffIsNotOverwrittenByTheOnDefault() {
        defaults.set(false, forKey: "explainChanges")
        defaults.set(false, forKey: "sessionContextEnabled")
        let store = SettingsStore(defaults: defaults)
        XCTAssertFalse(store.explainChanges)
        XCTAssertFalse(store.sessionContextEnabled)
    }

    func testAnExplicitOnIsPreserved() {
        defaults.set(true, forKey: "usageLoggingEnabled")
        XCTAssertTrue(SettingsStore(defaults: defaults).usageLoggingEnabled)
    }

    func testRemainingDefaults() {
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.primaryColorID, PrimaryColor.indigo.rawValue)
        XCTAssertEqual(store.defaultActionID, EnhancementAction.grammarID)
        XCTAssertEqual(store.lastTargetID, TargetProfile.genericID)
        XCTAssertEqual(store.historyRetentionDays, 90)
        XCTAssertEqual(store.historyMaxMegabytes, 200)
        XCTAssertEqual(store.userName, "")
        XCTAssertFalse(store.launchAtLogin)
        XCTAssertFalse(store.hasCompletedGetStarted)
        XCTAssertFalse(store.hasDismissedSettingsTip)
        XCTAssertTrue(store.lastTargetByApp.isEmpty)
    }

    /// A zero would mean "keep nothing", which is never what an unset key means.
    func testZeroRetentionFallsBackToTheShippedWindow() {
        defaults.set(0, forKey: "historyRetentionDays")
        defaults.set(0, forKey: "historyMaxMegabytes")
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.historyRetentionDays, 90)
        XCTAssertEqual(store.historyMaxMegabytes, 200)
    }

    // MARK: - Migrations

    func testRetiredGroqModelsAreRewrittenOnLoad() {
        defaults.set("llama-3.3-70b-versatile", forKey: "customEnhanceModel")
        defaults.set("llama3-8b-8192", forKey: "customGrammarModel")
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.customEnhanceModel, CompatibleAPIPreset.groq.defaultModel)
        XCTAssertEqual(store.customGrammarModel, CompatibleAPIPreset.groq.defaultModel)
        // Rewritten in place, so the next launch does not repeat the work.
        XCTAssertEqual(
            defaults.string(forKey: "customEnhanceModel"),
            CompatibleAPIPreset.groq.defaultModel
        )
    }

    func testALiveModelIDIsLeftAlone() {
        defaults.set("openai/gpt-oss-120b", forKey: "customEnhanceModel")
        XCTAssertEqual(
            SettingsStore(defaults: defaults).customEnhanceModel,
            "openai/gpt-oss-120b"
        )
    }

    func testFirstLaunchPersistsTheProviderChoiceForNextTime() {
        _ = SettingsStore(defaults: defaults)
        XCTAssertEqual(defaults.string(forKey: "activeProvider"), ProviderKind.ollama.rawValue)
        XCTAssertTrue(defaults.bool(forKey: "hasLaunchedBefore"))
    }

    func testAnExistingProviderChoiceIsNotResetOnLaunch() {
        defaults.set(true, forKey: "hasLaunchedBefore")
        defaults.set(ProviderKind.anthropic.rawValue, forKey: "activeProvider")
        XCTAssertEqual(SettingsStore(defaults: defaults).activeProvider, .anthropic)
    }

    func testAnUnrecognisedProviderFallsBackRatherThanCrashing() {
        defaults.set(true, forKey: "hasLaunchedBefore")
        defaults.set("some-provider-we-removed", forKey: "activeProvider")
        XCTAssertEqual(SettingsStore(defaults: defaults).activeProvider, .ollama)
    }

    // MARK: - Round-tripping

    func testWritesArePersistedToTheInjectedDomain() {
        let store = SettingsStore(defaults: defaults)
        store.userName = "Rahul"
        store.explainChanges = false
        store.historyRetentionDays = 30
        store.primaryColorID = PrimaryColor.teal.rawValue

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.userName, "Rahul")
        XCTAssertFalse(reloaded.explainChanges)
        XCTAssertEqual(reloaded.historyRetentionDays, 30)
        XCTAssertEqual(reloaded.primaryColorID, PrimaryColor.teal.rawValue)
    }

    func testAccentIsStoredUnderTheKeyPrimaryColorReadsBack() {
        let store = SettingsStore(defaults: defaults)
        store.primaryColorID = PrimaryColor.rose.rawValue
        XCTAssertEqual(
            defaults.string(forKey: PrimaryColor.storageKey),
            PrimaryColor.rose.rawValue,
            "PrimaryColor.selected reads this key directly from UserDefaults"
        )
    }

    // MARK: - Configuration gating

    func testOllamaIsConfiguredOnlyWithABaseURLAndBothModels() {
        let store = SettingsStore(defaults: defaults)
        XCTAssertTrue(store.isConfigured(.ollama))
        store.ollamaEnhanceModel = ""
        XCTAssertFalse(store.isConfigured(.ollama))
    }

    func testSelectingAProviderPersistsIt() {
        let store = SettingsStore(defaults: defaults)
        store.selectProvider(.anthropic)
        XCTAssertEqual(store.activeProvider, .anthropic)
        XCTAssertEqual(SettingsStore(defaults: defaults).activeProvider, .anthropic)
    }

    func testModelIDFollowsTheActiveProviderAndRole() {
        let store = SettingsStore(defaults: defaults)
        store.ollamaEnhanceModel = "gemma3:1b"
        store.ollamaGrammarModel = "qwen2.5:7b"
        XCTAssertEqual(store.modelID(for: .enhance), "gemma3:1b")
        XCTAssertEqual(store.modelID(for: .grammar), "qwen2.5:7b")
    }
}
