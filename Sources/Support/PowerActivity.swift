import Foundation

/// Scopes App Nap suppression to exactly the moments real work is in flight.
/// The process stays fully nappable while idle; a reference-counted activity
/// assertion is held only while at least one LLM stream is running, so the
/// scheduler neither throttles active streaming nor keeps us hot afterward.
@MainActor
final class PowerActivity {
    private var token: NSObjectProtocol?
    private var activeStreams = 0

    func streamBegan() {
        activeStreams += 1
        guard token == nil else { return }
        token = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Streaming LLM response"
        )
    }

    func streamEnded() {
        activeStreams = max(0, activeStreams - 1)
        guard activeStreams == 0, let token else { return }
        ProcessInfo.processInfo.endActivity(token)
        self.token = nil
    }
}
