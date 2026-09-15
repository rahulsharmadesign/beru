import Foundation
import FoundationModels
import XCTest
@testable import Beru

// Phase A1: Apple on-device provider, engine only. Mirrors the ondevice spike,
// adapted to Beru's XCTest suite (the spike used Swift Testing). No UI, no
// default flip: nothing here can change what any existing user sees.

@MainActor
final class AppleModelStateTests: XCTestCase {
    func testAvailableIsReady() {
        XCTAssertEqual(AppleModelState.state(from: .available), .ready)
        XCTAssertTrue(AppleModelState.state(from: .available).isReady)
    }

    func testReasonsMap() {
        XCTAssertEqual(
            AppleModelState.state(from: .unavailable(.deviceNotEligible)),
            .deviceNotEligible
        )
        XCTAssertEqual(
            AppleModelState.state(from: .unavailable(.appleIntelligenceNotEnabled)),
            .intelligenceNotEnabled
        )
        XCTAssertEqual(
            AppleModelState.state(from: .unavailable(.modelNotReady)),
            .modelNotReady
        )
    }

    func testNonReadyStatesAreNotReady() {
        let states: [AppleModelState] = [.deviceNotEligible, .intelligenceNotEnabled, .modelNotReady]
        for state in states {
            XCTAssertFalse(state.isReady, "\(state) must not read as configured")
        }
    }

    func testReadySummaryNamesThePrivacyStory() {
        XCTAssertTrue(AppleModelState.ready.summary.contains("nothing leaves this Mac"))
    }

    func testFailureCopyNamesTheFix() {
        XCTAssertTrue(AppleModelState.intelligenceNotEnabled.summary.contains("System Settings"))
        XCTAssertTrue(AppleModelState.deviceNotEligible.summary.contains("doesn't support Apple Intelligence"))
    }

    func testNoStateRoutesToConnectToModel() {
        // `.modelUnavailable` drives Beru's "Connect to model" offer, which makes
        // no sense for a provider the user cannot configure with a URL or key.
        let states: [AppleModelState] = [
            .ready, .deviceNotEligible, .intelligenceNotEnabled, .modelNotReady
        ]
        for state in states {
            XCTAssertFalse(state.providerError.needsModelSetup, "\(state)")
        }
    }

    func testGenerationErrorMapping() {
        XCTAssertEqual(AppleModelState.providerError(for: CancellationError()), .cancelled)
        XCTAssertEqual(
            AppleModelState.providerError(
                for: LanguageModelSession.GenerationError.rateLimited(.init(debugDescription: "x"))
            ),
            .rateLimited
        )
        let blocked = AppleModelState.providerError(
            for: LanguageModelSession.GenerationError.guardrailViolation(.init(debugDescription: "x"))
        )
        switch blocked {
        case .badResponse:
            break
        default:
            XCTFail("a guardrail refusal must surface as a bad response, not a setup prompt")
        }
    }

    func testAppleReportsConfiguredOnlyWhenUsable() {
        // Cannot assert `.ready` on arbitrary CI, but the mapping above is the
        // rule `isConfigured` delegates to — this just pins the contract
        // against a silently inverted reading.
        XCTAssertEqual(AppleModelState.isConfigured, AppleModelState.current().isReady)
    }

    func testModelIDIsStableForUsageAttribution() {
        XCTAssertEqual(AppleOnDeviceProvider.modelID, "apple-on-device")
        let suiteName = "beru.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SettingsStore(defaults: defaults)
        store.selectProvider(.apple)
        XCTAssertEqual(store.modelID(for: .enhance), "apple-on-device")
        XCTAssertEqual(store.modelID(for: .grammar), "apple-on-device")
    }
}