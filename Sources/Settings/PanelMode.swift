import Foundation

/// Which actions the panel offers.
///
/// Focused (the default) keeps the panel to its two jobs: Enhance Prompt
/// first, Grammar second, with Tab flipping between them. "Show all actions"
/// in Settings → General brings back Search, Smart Reply, Summarize, Explain,
/// the Instruction chip, and custom actions.
///
/// Read straight from UserDefaults rather than living on SettingsStore:
/// Settings binds it with `@AppStorage`, and the panel re-reads it on every
/// show, so it needs no observation of its own.
enum PanelMode {
    static let showAllActionsKey = "showAllActions"

    /// Tab order in focused mode.
    static let focusedActionIDs = [EnhancementAction.enhanceID, EnhancementAction.grammarID]

    static var showsAllActions: Bool {
        UserDefaults.standard.bool(forKey: showAllActionsKey)
    }

    static var isFocused: Bool { !showsAllActions }
}
