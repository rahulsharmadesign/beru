import AppKit
import SwiftUI

// The result module and every state it can be in: idle, provider setup,
// missing accessibility, streaming, diff, and errors.

extension PanelView {
    // MARK: - Result

    var resultModule: some View {
        VStack(alignment: .leading, spacing: 0) {
            if appState.truncationNotice {
                truncationBanner
            }
            resultArea
            if let rationale = appState.rationales[appState.selectedActionID],
               case .done = appState.resultState(for: appState.selectedActionID) {
                RationaleNote(text: rationale)
            }
        }
        // Inset inside clipShape so placeholder copy is not sheared by the
        // card radius. Height is intrinsic — the window sizes to the stack.
        // Every tab renders plateless on the panel wash: idle text, threads,
        // diffs, and errors alike. No outer card anywhere.
        .padding(PanelMetrics.moduleInset)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .glassModule(scrim: .chrome)
    }

    @ViewBuilder
    var resultArea: some View {
        let state = appState.resultState(for: appState.selectedActionID)
        VStack(alignment: .trailing, spacing: 0) {
            if appState.selectedActionID == EnhancementAction.replyID,
               case .done = state,
               !appState.replySuggestions.isEmpty {
                ReplySuggestionsView(
                    suggestions: appState.replySuggestions,
                    selected: appState.selectedReplyTone,
                    copied: appState.copiedFeedback,
                    votes: appState.replyVote,
                    pinnedRow: appState.pinnedRow,
                    onSelect: { appState.selectedReplyTone = $0 },
                    onCopy: { copyReplyTone($0) },
                    onRegenerate: { engine.retry(actionID: EnhancementAction.replyID) },
                    onVote: { setReplyVote($0, liked: $1) },
                    onReplace: { replaceReplyTone($0) },
                    onPin: { pinReplyTone($0) }
                )
            } else if appState.selectedActionID == EnhancementAction.grammarID,
                      case .done = state,
                      !appState.grammarSuggestions.isEmpty {
                GrammarSuggestionsView(
                    suggestions: appState.grammarSuggestions,
                    selected: appState.selectedGrammarKind,
                    copied: appState.copiedFeedback,
                    votes: appState.grammarVote,
                    pinnedRow: appState.pinnedRow,
                    onSelect: { engine.applyGrammarKind($0) },
                    onCopy: { copyGrammarKind($0) },
                    onRegenerate: { engine.retry(actionID: EnhancementAction.grammarID) },
                    onVote: { setGrammarVote($0, liked: $1) },
                    onReplace: { replaceGrammarKind($0) },
                    onPin: { pinGrammarKind($0) }
                )
            } else if appState.selectedActionID == EnhancementAction.searchID {
                if hasCapturedText {
                    SelectedSourceQuote(text: appState.capturedText)
                }
                if appState.searchThread.isEmpty {
                    idlePlaceholder
                } else {
                    searchThreadList
                }
            } else if case .done(let revised) = state,
                      appState.diffs[appState.selectedActionID] != nil {
                diffResult(revised: revised)
            } else if case .error(let message) = state {
                errorView(message: message)
            } else if case .idle = state,
                      appState.selectedActionID == EnhancementAction.describeID
                        || appState.capturedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                idlePlaceholder
            } else {
                ResultView(state: state, usesMarkdown: usesSearchMarkdown)
            }
        }
        // Short content hugs the top of the idle-tall band instead of
        // floating centered in it.
        .frame(maxWidth: .infinity, minHeight: PanelMetrics.resultIdleMinHeight, alignment: .topLeading)
        // Do not `.id` the tab or animate this swap: that scaled the result
        // copy and, with the window animator, sheared the close strip and composer.
        .animation(nil, value: appState.selectedActionID)
    }

    /// Stacked Search Q&As for this panel open, split by dotted rules.
    /// Window grows to the 75% cap; then `panelResultScrollHeight` scrolls
    /// this list — chrome stays pinned.
    var searchThreadList: some View {
        VStack(alignment: .leading, spacing: BeruSpace.lg) {
            ForEach(appState.searchThread) { turn in
                VStack(alignment: .leading, spacing: BeruSpace.xxs) {
                    HStack(alignment: .center, spacing: BeruSpace.xs) {
                        BeruResponseMark()
                        Text(turn.question)
                            .font(BeruType.footnoteMedium)
                            .foregroundStyle(BeruColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    ResultView(state: turn.answer, usesMarkdown: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if case .done(let text) = turn.answer, !text.isEmpty {
                        searchTurnActions(turn: turn, text: text)
                    }
                }
                .id(turn.id)
                if turn.id != appState.searchThread.last?.id {
                    DottedDivider()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var usesSearchMarkdown: Bool {
        appState.selectedActionID == EnhancementAction.searchID
    }

    @ViewBuilder
    var idlePlaceholder: some View {
        if !a11y.isAccessibilityTrusted {
            accessibilityPlaceholder
        } else {
            let needsSetup = appState.selectedActionID == EnhancementAction.searchID
                && !SettingsStore.shared.isConfigured(SettingsStore.shared.activeProvider)
            if needsSetup {
                providerSetupPlaceholder
            } else {
                regularIdlePlaceholder
            }
        }
    }

    var accessibilityPlaceholder: some View {
        VStack(spacing: BeruSpace.sm) {
            Text("Allow Accessibility")
                .font(BeruType.bodyMedium)
                .foregroundStyle(BeruColor.textPrimary)
            Text("Beru needs Accessibility to read and replace selected text in other apps.")
                .font(BeruType.footnote)
                .foregroundStyle(BeruColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            BeruGlassButton(
                title: "Open System Settings",
                prominent: true,
                size: .compact
            ) {
                Permissions.requestAccessibilityIfNeeded()
                Permissions.openAccessibilitySettings()
            }
            .padding(.top, BeruSpace.xxs)
        }
        .padding(.horizontal, BeruSpace.lg)
        .padding(.vertical, PanelMetrics.moduleInset)
        .frame(maxWidth: .infinity, minHeight: PanelMetrics.resultIdleMinHeight)
        .background(PanelDragRegion())
    }

    var regularIdlePlaceholder: some View {
        let copy = EnhancementAction.emptyCaptureCopy(actionID: appState.selectedActionID)
        return VStack(spacing: BeruSpace.xxs) {
            Text(copy.title)
                .font(BeruType.bodyMedium)
                .foregroundStyle(BeruColor.textPrimary)
            Text(copy.subtitle)
                .font(BeruType.footnote)
                .foregroundStyle(BeruColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, BeruSpace.lg)
        .padding(.vertical, PanelMetrics.moduleInset)
        .frame(maxWidth: .infinity, minHeight: PanelMetrics.resultIdleMinHeight)
        .background(PanelDragRegion())
    }

    var providerSetupPlaceholder: some View {
        VStack(spacing: BeruSpace.sm) {
            Text("Choose your AI model")
                .font(BeruType.bodyMedium)
                .foregroundStyle(BeruColor.textPrimary)
            Text("Connect an AI provider or choose a local model to start using Beru.")
                .font(BeruType.footnote)
                .foregroundStyle(BeruColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: BeruSpace.xs) {
                BeruGlassButton(
                    title: "Connect a provider",
                    prominent: true,
                    size: .compact
                ) {
                    engine.requestProviderSetup(preferLocal: false)
                }
                BeruButton(title: "Use a local model", size: .compact) {
                    engine.requestProviderSetup(preferLocal: true)
                }
            }
            .padding(.top, BeruSpace.xxs)
        }
        .padding(.horizontal, BeruSpace.lg)
        .padding(.vertical, PanelMetrics.moduleInset)
        .frame(maxWidth: .infinity, minHeight: PanelMetrics.resultIdleMinHeight)
        .background(PanelDragRegion())
    }

    var truncationBanner: some View {
        Text("Selection was truncated to \(PanelEngine.maxCapturedLength) characters")
            .font(BeruType.caption)
            .foregroundStyle(BeruColor.textSecondary)
            .padding(.bottom, BeruSpace.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    func diffResult(revised: String) -> some View {
        DiffView(
            ops: appState.diffs[appState.selectedActionID],
            revised: revised,
            showDiff: true,
            scrolls: false
        )
    }

    func errorView(message: String) -> some View {
        let actionID = appState.selectedActionID
        let fallbacks = SettingsStore.shared.fallbackProviders
        let showConnectCTA = appState.errorNeedsModelSetup.contains(actionID)
        return VStack(spacing: BeruSpace.sm) {
            Text(message)
                .beruPrintedText()
                .foregroundStyle(BeruColor.textSecondary)
                .multilineTextAlignment(.center)
            // Retry rows wrap: with fallbacks plus Connect to model the row
            // can outgrow the 420pt panel, and clipped actions are dead ends.
            WrapHStack(spacing: BeruSpace.xs, lineSpacing: BeruSpace.xs) {
                BeruButton(title: "Retry", size: .compact) {
                    engine.retry(actionID: actionID)
                }

                // Connect to model: 404 / unknown model — open Models so the
                // user can install or pick one instead of retrying blindly.
                if showConnectCTA {
                    BeruGlassButton(
                        title: "Connect to model",
                        prominent: true,
                        size: .compact
                    ) {
                        engine.requestProviderSetup(preferLocal: true)
                    }
                }

                // If another provider is configured, offer it here so a failed
                // request doesn't dead-end the user into opening Settings.
                ForEach(fallbacks, id: \.self) { kind in
                    BeruButton(title: fallbackLabel(for: kind), size: .compact) {
                        engine.retryWithProvider(kind, actionID: actionID)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BeruSpace.sm)
        // The retry row can wrap onto a second line once a fallback provider
        // and Connect to model are both present, so the window has to be told.
    }

    func copyReplyTone(_ tone: ReplyTone) {
        appState.selectedReplyTone = tone
        guard let text = ReplySuggestions.body(in: appState.replySuggestions, matching: tone) else { return }
        engine.copy(text: text)
    }

    func copyGrammarKind(_ kind: GrammarKind) {
        engine.applyGrammarKind(kind)
        guard let text = GrammarSuggestions.body(in: appState.grammarSuggestions, matching: kind) else { return }
        engine.copy(text: text)
    }

    /// Pins without dismissing and flashes the row check for the same beat
    /// the footer label used to show. Shared by search turns and both
    /// suggestion rows.
    func pinRowFlash(key: String, text: String?) {
        guard let text else { return }
        engine.pin(text: text)
        appState.pinnedRow = key
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            if appState.pinnedRow == key {
                appState.pinnedRow = nil
            }
        }
    }

    /// Short label for the "Try with [X]" button. Takes the first word of the
    /// provider's title, so "API (Groq, OpenAI, …)" reads as "Try with API".
    func fallbackLabel(for kind: ProviderKind) -> String {
        let title = kind.title
        let firstWord = title.split(separator: " ").first.map(String.init) ?? title
        return "Try with \(firstWord)"
    }
}
