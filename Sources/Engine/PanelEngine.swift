import AppKit
import Foundation
import os.log

let engineLogger = Logger(subsystem: "com.rahul.beru", category: "engine")

/// Orchestrates capture -> LLM streaming -> replace/copy for the floating panel.
/// UI-agnostic: PanelView drives it, AppState holds the state it produces.
@MainActor
final class PanelEngine {
    static let maxCapturedLength = 8000

    let appState: AppState
    let onDismiss: () -> Void
    /// Notified when no stream is in flight, so the panel may shrink to fit.
    var onStreamingEnded: (() -> Void)?
    /// Notified when a stream begins, so the panel only grows until it ends.
    var onStreamingStarted: (() -> Void)?

    /// Set by the coordinator to open the dashboard's Permissions screen.
    ///
    /// The panel cannot ask for microphone access itself: it is a
    /// non-activating window in an accessory process, so the system dialog may
    /// never come to the front. The request has to be made from a real window.
    var onRequestDictationPermission: (() -> Void)?

    func requestDictationPermission() {
        onRequestDictationPermission?()
    }

    /// Opens Settings → Models. `preferLocal` switches the active provider to Ollama first.
    var onRequestProviderSetup: ((Bool) -> Void)?

    func requestProviderSetup(preferLocal: Bool) {
        onRequestProviderSetup?(preferLocal)
    }

    /// Opens Settings → General. The panel stays up so an in-flight run is not killed.
    var onOpenSettings: (() -> Void)?

    func openSettings() {
        onOpenSettings?()
    }

    let powerActivity = PowerActivity()
    var lastDescribeInstruction: String?
    /// Regeneration count per action within the current invocation.
    var attempts: [String: Int] = [:]

    /// Monotonic for the life of the process, never reset: a token that came
    /// round again could let a task cancelled in a previous invocation write
    /// into the current one.
    var generationCounter = 0
    /// The generation whose writes are still wanted, per action.
    var liveGeneration: [String: Int] = [:]

    /// Called when a new panel session begins, so attempt numbering restarts.
    func resetForNewInvocation() {
        attempts.removeAll()
        // Nothing from the previous session is live any more. Clearing rather
        // than reassigning matters: an in-flight task holds a token that now
        // matches no entry, so it can no longer publish.
        liveGeneration.removeAll()
        lastDescribeInstruction = nil
    }

    func beginGeneration(for actionID: String) -> Int {
        generationCounter += 1
        liveGeneration[actionID] = generationCounter
        return generationCounter
    }

    func isLive(_ generation: Int, for actionID: String) -> Bool {
        liveGeneration[actionID] == generation
    }

    /// Writes result state only while this generation is still the live one.
    ///
    /// A superseded stream ends with nothing accumulated, which is
    /// indistinguishable from a genuinely empty model response — without this
    /// guard it paints "empty response" over the run that replaced it, and the
    /// panel shows an error while a perfectly good result is still streaming.
    func publish(_ state: ResultState, for actionID: String, generation: Int) {
        guard isLive(generation, for: actionID) else { return }
        appState.setResult(state, for: actionID)
        if actionID == EnhancementAction.searchID {
            appState.updateLiveSearchTurn(state)
        }
    }

    init(appState: AppState, onDismiss: @escaping () -> Void) {
        self.appState = appState
        self.onDismiss = onDismiss
    }

    func startIfNeeded(actionID: String) {
        guard !appState.hasStarted(actionID) else { return }
        start(actionID: actionID)
    }

    func retry(actionID: String) {
        // Regenerate after a successful result means "give me a different
        // take" — pass the previous output so the model must diverge from it.
        // Retry after an error is a plain re-attempt.
        // Search / describe need the last question even if the composer was cleared.
        let instruction: String? = {
            if actionID == EnhancementAction.searchID || actionID == EnhancementAction.describeID {
                let live = appState.describeInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
                if !live.isEmpty { return live }
                return lastDescribeInstruction
            }
            return nil
        }()
        if case .done(let previous) = appState.resultState(for: actionID) {
            start(actionID: actionID, previousResult: previous, instruction: instruction)
        } else {
            start(actionID: actionID, instruction: instruction)
        }
    }

    /// Runs the free-form "Describe your change" instruction. Both the text
    /// field's onSubmit and the panel's Return handler call this, so a single
    /// keystroke can arrive twice; without the in-flight guard the second call
    /// would cancel the first stream and look exactly like a hang.
    func runDescribe(instruction: String) {
        let trimmed = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let current = appState.selectedActionID
        let capturedEmpty = appState.capturedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        // Quick search (no selection) still uses the one-off instruction path.
        // Otherwise stay on the chip the user is on — switching to describe
        // looked like a jump to Enhance (same sparkles icon).
        let actionID: String = {
            if current == EnhancementAction.searchID { return EnhancementAction.searchID }
            if appState.isQuickSearch && capturedEmpty { return EnhancementAction.searchID }
            if current == EnhancementAction.describeID { return EnhancementAction.describeID }
            if ActionRegistry.shared.action(withID: current) != nil { return current }
            return EnhancementAction.searchID
        }()
        if trimmed == lastDescribeInstruction {
            switch appState.resultState(for: actionID) {
            case .loading, .thinking, .streaming:
                return
            default:
                break
            }
        }
        lastDescribeInstruction = trimmed
        if actionID == EnhancementAction.searchID || actionID == EnhancementAction.describeID {
            appState.selectAction(actionID)
        }
        start(actionID: actionID, instruction: trimmed)
    }

    /// Runs a question through Beru’s selected AI provider on the AI Search tab.
    func runQuickSearch(query: String) {
        let question = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        appState.selectAction(EnhancementAction.searchID)
        start(actionID: EnhancementAction.searchID, instruction: question)
    }

    /// Minimum interval between streaming UI publishes. Local models can emit
    /// 100+ chunks per second; re-laying-out the full text for each one wastes
    /// main-thread time with no visible benefit.
    /// Coalesce UI publishes. Tighter than this re-lays out the panel (height
    /// preferences, glass, shadow) dozens of times per second and heats the Mac.
    static let streamPublishInterval: Duration = .milliseconds(100)
}
