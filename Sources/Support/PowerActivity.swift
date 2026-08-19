import Foundation

/// Scopes App Nap suppression to exactly the moments real work is in flight.
/// The process stays fully nappable while idle; a reference-counted activity
/// assertion is held only while at least one LLM stream or model pull is
/// running, so the scheduler neither throttles active work nor keeps us hot afterward.
@MainActor
final class PowerActivity {
    private var token: NSObjectProtocol?
    private var activeCount = 0

    func streamBegan() {
        retain(reason: "Streaming LLM response")
    }

    func streamEnded() {
        release()
    }

    func pullBegan() {
        retain(reason: "Downloading local model")
    }

    func pullEnded() {
        release()
    }

    private func retain(reason: String) {
        activeCount += 1
        guard token == nil else { return }
        token = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: reason
        )
    }

    private func release() {
        activeCount = max(0, activeCount - 1)
        guard activeCount == 0, let token else { return }
        ProcessInfo.processInfo.endActivity(token)
        self.token = nil
    }
}
