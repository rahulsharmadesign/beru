import ApplicationServices
import Foundation
import Observation

enum ResultState: Equatable {
    case idle
    case loading
    /// The model is emitting a reasoning pass; no answer tokens yet. Distinct
    /// from .loading so a long think doesn't look like a hung request.
    case thinking
    case streaming(String)
    case done(String)
    case error(String)
}

/// One Q&A in the AI Search panel thread. Lives only while the widget is open.
struct SearchThreadTurn: Identifiable, Equatable {
    let id: UUID
    let question: String
    var answer: ResultState

    init(id: UUID = UUID(), question: String, answer: ResultState = .loading) {
        self.id = id
        self.question = question
        self.answer = answer
    }
}

@MainActor
@Observable
final class AppState {
    var isPanelVisible: Bool = false
    var panelOrigin: CGPoint = .zero
    /// When non-nil, the result module scrolls inside this height and the
    /// window is at the 75% viewport cap. Nil = result sizes intrinsically.
    /// Owned by `PanelController` from layout measures — views must not write it.
    var panelResultScrollHeight: CGFloat? = nil

    var capturedText: String = ""
    /// The host app's focused AX element at capture time. Replace must target
    /// this element, not whatever is focused at replace time (our own panel
    /// holds key status by then).
    var capturedElement: AXUIElement?
    /// The active action's id. Results are keyed by action id, including the
    /// reserved `EnhancementAction.describeID` for one-off instructions.
    var selectedActionID: String
    var results: [String: ResultState] = [:]
    /// AI Search Q&A stack for this panel open. Cleared on dismiss / reset —
    /// not persisted. Soft-capped so a long session cannot balloon forever.
    var searchThread: [SearchThreadTurn] = []
    /// Soft ceiling for stacked Search turns in one panel session.
    static let searchThreadMaxTurns = 20
    /// The instruction text typed into the intent bar.
    var describeInstruction: String = ""
    /// Which AI environment an enhanced prompt is being written for.
    var selectedTargetID: String = TargetProfile.genericID
    /// The app the current capture came from, used to remember its target.
    var hostBundleID: String?
    var hostAppName: String?
    /// Pasteboard text snapped at panel present time, when it differs from the
    /// selection. Shown as an opt-in context chip; never sent unless included.
    var clipboardText: String?
    /// When true, `clipboardText` is appended outside `<text>` in the user message.
    var includeClipboard: Bool = false
    /// Changes on every invocation. The panel's NSHostingView is created once
    /// and reused, so SwiftUI would otherwise never rebuild the subtree —
    /// keying the root on this restores per-invocation onAppear/focus.
    private(set) var panelSessionID = UUID()
    /// Correlates every history event produced by one panel session. Not
    /// cleared on dismiss — the terminal event is recorded during dismissal.
    private(set) var invocationID = UUID()
    var showDiff: Bool = true
    var copiedFeedback: Bool = false
    var truncationNotice: Bool = false
    /// Diff ops per completed action, computed once off-main when that stream
    /// completes. Keyed like `results` and cleared with them; a missing entry
    /// means still streaming, or the computation hasn't finished.
    var diffs: [String: [DiffOp]] = [:]
    /// Actions whose result changed most of the text, i.e. the model restyled
    /// instead of correcting. Only ever populated for Grammar: for Enhance a
    /// near-total rewrite is the intended outcome, so warning about it there
    /// would be misleading.
    var heavyRewriteNotices: Set<String> = []
    /// Actions where the model rewrote rather than corrected — it replaced correct
    /// words with unrelated ones. Shown alongside the diff, unlike
    /// `heavyRewriteNotices` which replaces it.
    var restyledNotices: Set<String> = []
    /// Actions whose result came back identical to the input. Without saying so,
    /// "nothing needed fixing" is indistinguishable from "the tool did nothing",
    /// which is what drives people to hit Regenerate until it invents changes.
    var cleanNotices: Set<String> = []
    /// The model's explanation of what it changed, per action. Keyed and cleared
    /// like `results` — advice attached to a result that is no longer on screen
    /// would describe the wrong text.
    var rationales: [String: String] = [:]
    /// Context sources that shaped each generated result, for transparent local provenance.
    var contextApplications: [String: ContextApplication] = [:]
    /// Estimated token accounting per completed action, for the footer pill.
    /// Keyed like `results`, and cleared with them — a savings figure outliving
    /// the result it describes would be attached to the wrong text.
    var savings: [String: TokenSavings] = [:]
    /// Parsed Smart Reply cards. Empty until a Reply stream finishes, and
    /// cleared when that action re-runs.
    var replySuggestions: [ReplySuggestion] = []
    /// Which of the six tones Insert / Copy / Pin will send. Choosing a tone
    /// does not re-run the model.
    var selectedReplyTone: ReplyTone = .formal
    /// Smart Reply when the model switched script (e.g. Roman in, Devanagari out).
    var replyScriptNotices: Set<String> = []
    /// Search mode is the AI Search tab — a question, not a rewrite skill.
    var isQuickSearch = false
    /// When set, Replace writes the result back into this vault note instead of
    /// the host app's selection.
    var vaultNoteID: String?
    /// Brief "Pinned" confirmation in the panel footer.
    var pinnedFeedback: Bool = false
    /// Which provider produced the current error, per action. Lets the panel
    /// offer "Try with [other provider]" instead of the user opening Settings.
    var errorProviders: [String: ProviderKind] = [:]
    /// Actions whose error is a missing/unknown model, so the panel can offer
    /// Connect to model next to Retry.
    var errorNeedsModelSetup: Set<String> = []

    private var streamTasks: [String: Task<Void, Never>] = [:]

    init() {
        let defaults = UserDefaults.standard
        // Migrate the pre-actions "lastUsedTab" key if present.
        let legacy = defaults.string(forKey: "lastUsedTab")
        let saved = defaults.string(forKey: "lastUsedActionID") ?? legacy
        self.selectedActionID = saved ?? EnhancementAction.grammarID
    }

    func resultState(for actionID: String) -> ResultState {
        results[actionID] ?? .idle
    }

    func selectAction(_ actionID: String) {
        selectedActionID = actionID
        isQuickSearch = actionID == EnhancementAction.searchID
        UserDefaults.standard.set(actionID, forKey: "lastUsedActionID")
    }

    func selectTarget(_ targetID: String) {
        selectedTargetID = targetID
        SettingsStore.shared.lastTargetID = targetID
        if let hostBundleID {
            SettingsStore.shared.lastTargetByApp[hostBundleID] = targetID
        }
    }

    /// Starts a new Search Q&A. Regenerate rewrites the live turn instead.
    func beginSearchTurn(question: String, regenerating: Bool) {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if regenerating, !searchThread.isEmpty {
            searchThread[searchThread.count - 1].answer = .loading
            return
        }
        searchThread.append(SearchThreadTurn(question: trimmed, answer: .loading))
        if searchThread.count > Self.searchThreadMaxTurns {
            searchThread.removeFirst(searchThread.count - Self.searchThreadMaxTurns)
        }
    }

    func updateLiveSearchTurn(_ state: ResultState) {
        guard !searchThread.isEmpty else { return }
        searchThread[searchThread.count - 1].answer = state
    }

    func reset(withCapturedText text: String) {
        for task in streamTasks.values { task.cancel() }
        streamTasks.removeAll()
        results.removeAll()
        searchThread.removeAll()
        savings.removeAll()
        // Only on reset, never on dismiss: regenerating during the fade-out
        // would rebuild the view hierarchy mid-animation.
        panelSessionID = UUID()
        invocationID = UUID()
        panelResultScrollHeight = nil
        capturedText = text
        capturedElement = nil
        hostBundleID = nil
        hostAppName = nil
        clipboardText = nil
        includeClipboard = false
        describeInstruction = ""
        copiedFeedback = false
        pinnedFeedback = false
        truncationNotice = false
        vaultNoteID = nil
        isQuickSearch = false
        diffs.removeAll()
        rationales.removeAll()
        contextApplications.removeAll()
        heavyRewriteNotices.removeAll()
        restyledNotices.removeAll()
        cleanNotices.removeAll()
        errorProviders.removeAll()
        errorNeedsModelSetup.removeAll()
        replySuggestions = []
        replyScriptNotices.removeAll()
    }

    func dismiss() {
        isPanelVisible = false
        for task in streamTasks.values { task.cancel() }
        streamTasks.removeAll()
        results.removeAll()
        searchThread.removeAll()
        savings.removeAll()
        capturedText = ""
        capturedElement = nil
        clipboardText = nil
        includeClipboard = false
        describeInstruction = ""
        truncationNotice = false
        vaultNoteID = nil
        pinnedFeedback = false
        diffs.removeAll()
        rationales.removeAll()
        contextApplications.removeAll()
        heavyRewriteNotices.removeAll()
        restyledNotices.removeAll()
        cleanNotices.removeAll()
        errorProviders.removeAll()
        errorNeedsModelSetup.removeAll()
        replySuggestions = []
        replyScriptNotices.removeAll()
    }

    func setResult(_ state: ResultState, for actionID: String) {
        results[actionID] = state
    }

    func registerStreamTask(_ task: Task<Void, Never>, for actionID: String) {
        streamTasks[actionID]?.cancel()
        streamTasks[actionID] = task
    }

    func hasStarted(_ actionID: String) -> Bool {
        results[actionID] != nil
    }

    /// Text Insert / Copy / Pin should send. Smart Reply uses the selected
    /// card, not the tagged stream blob.
    func acceptedText(for actionID: String? = nil) -> String? {
        let id = actionID ?? selectedActionID
        if id == EnhancementAction.replyID, !replySuggestions.isEmpty {
            return ReplySuggestions.body(in: replySuggestions, matching: selectedReplyTone)
        }
        if case .done(let text) = resultState(for: id) { return text }
        return nil
    }
}
