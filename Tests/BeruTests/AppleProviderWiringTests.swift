import XCTest
@testable import Beru

/// Phase A2: Apple on-device is selectable in Settings, not just present in
/// the engine. Every provider must render in the pickers (title/icon) and
/// route to its provider; Apple's "configured" state is the system state.
@MainActor
final class AppleProviderWiringTests: XCTestCase {
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

    func testEveryProviderHasPickerChrome() {
        for kind in ProviderKind.allCases {
            XCTAssertFalse(kind.title.isEmpty, "\(kind.rawValue) needs a Settings title")
            XCTAssertFalse(kind.composerTitle.isEmpty, "\(kind.rawValue) needs a composer title")
            XCTAssertFalse(kind.composerIcon.isEmpty, "\(kind.rawValue) needs a composer icon")
        }
    }

    func testAppleConfiguredMirrorsSystemState() {
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.isConfigured(.apple), AppleModelState.isConfigured)
    }

    func testSelectingAppleRoutesToTheOnDeviceProvider() {
        let store = SettingsStore(defaults: defaults)
        store.selectProvider(.apple)
        XCTAssertEqual(store.activeProvider, .apple)
        XCTAssertTrue(ProviderRegistry.activeProvider(settings: store) is AppleOnDeviceProvider)
    }

    func testFallbacksNeverIncludeTheActiveProvider() {
        let store = SettingsStore(defaults: defaults)
        store.selectProvider(.apple)
        XCTAssertFalse(store.fallbackProviders.contains(.apple))
    }

    /// Grammar's three-in-one call echoes under greedy decoding on the
    /// on-device model (measured with Beru's exact prompt), so it alone gets
    /// temperature while every other role keeps the shared tuning.
    func testGrammarSamplingAvoidsGreedy() {
        XCTAssertEqual(
            AppleGeneration.sampling(for: .grammar, actionID: EnhancementAction.grammarID),
            .temperature(AppleGeneration.grammarTemperature)
        )
        XCTAssertEqual(
            AppleGeneration.sampling(for: .enhance, actionID: EnhancementAction.enhanceID),
            .temperature(ProviderTuning.temperature(for: .enhance))
        )
    }
}
