import XCTest
@testable import Beru

/// Opt-in integration check for the main-actor façade and its background pump.
/// Writes to the real history directory, so it only runs when explicitly
/// requested: BERU_TEST_HISTORY_PUMP=1.
final class UsageLogPumpTests: XCTestCase {
    @MainActor
    func testRecordReachesDisk() async throws {
        guard ProcessInfo.processInfo.environment["BERU_TEST_HISTORY_PUMP"] == "1" else {
            throw XCTSkip("Set BERU_TEST_HISTORY_PUMP=1 to exercise the real history pump")
        }

        SettingsStore.shared.usageLoggingEnabled = true
        UsageLog.start()

        let before = await UsageLogWriter.shared.stats().entryCount
        let marker = UUID()
        UsageLog.record {
            var event = UsageEvent(invocationID: marker, kind: .invoked)
            event.inputText = "pump check"
            return event
        }

        // The pump is a detached task; poll briefly rather than sleeping blind.
        var after = before
        for _ in 0..<40 {
            try? await Task.sleep(for: .milliseconds(50))
            after = await UsageLogWriter.shared.stats().entryCount
            if after > before { break }
        }
        XCTAssertGreaterThan(after, before, "UsageLog.record must reach disk through the pump")
    }
}
