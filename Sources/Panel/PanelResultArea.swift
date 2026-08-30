import AppKit
import SwiftUI

// The result module and every state it can be in: idle, provider setup,
// missing accessibility, streaming, diff, notices and errors.

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
        .padding(PanelMetrics.moduleInset)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .glassModule(scrim: .content)
    }

    @ViewBuilder
    var resultArea: some View {
        let state = appState.resultState(for: appState.selectedActionID)
        VStack(alignment: .trailing, spacing: 0) {
            if appState.selectedActionID == EnhancementAction.replyID,
               case .done = state,
               !appState.replySuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    if appState.replyScriptNotices.contains(appState.selectedActionID) {
                        noticeLine("Replies used the wrong language or script — try Regenerate to match the message")
                    }
                    ReplySuggestionsView(
                        suggestions: appState.replySuggestions,
                        selected: appState.selectedReplyTone,
                        onSelect: { appState.selectedReplyTone = $0 }
                    )
                }
            } else if appState.selectedActionID == EnhancementAction.searchID {
                if appState.searchThread.isEmpty {
                    idlePlaceholder
                } else {
                    searchThreadList
                }
            } else if case .done = state,
               appState.cleanNotices.contains(appState.selectedActionID) {
                VStack(alignment: .leading, spacing: 0) {
                    noticeLine(
                        appState.selectedActionID == EnhancementAction.grammarID
                            ? "No spelling, grammar or punctuation errors found — your text is unchanged"
                            : "The model returned your text unchanged"
                    )
                    ResultView(state: state, usesMarkdown: usesSearchMarkdown)
                }
            } else if case .done(let revised) = state,
                      appState.diffs[appState.selectedActionID] != nil {
                diffResult(revised: revised)
            } else if case .done = state,
                      appState.heavyRewriteNotices.contains(appState.selectedActionID) {
                VStack(alignment: .leading, spacing: 0) {
                    rewrittenNotice
                    ResultView(state: state, usesMarkdown: usesSearchMarkdown)
                }
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
        .frame(maxWidth: .infinity, minHeight: PanelMetrics.resultIdleMinHeight)
        // Do not `.id` the tab or animate this swap: that scaled the result
        // copy and, with the window animator, sheared the close strip and composer.
        .animation(nil, value: appState.selectedActionID)
    }

    /// Stacked Search Q&As for this panel open. Window grows to the 75% cap;
    /// then `panelResultScrollHeight` scrolls this list — chrome stays pinned.
    var searchThreadList: some View {
        VStack(alignment: .leading, spacing: BeruSpace.lg) {
            ForEach(appState.searchThread) { turn in
                VStack(alignment: .leading, spacing: BeruSpace.xs) {
                    Text(turn.question)
                        .font(BeruType.footnoteMedium)
                        .foregroundStyle(BeruColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                    ResultView(state: turn.answer, usesMarkdown: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .id(turn.id)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var usesSearchMarkdown: Bool {
        appState.selectedActionID == EnhancementAction.searchID
    }

    @ViewBuilder
    var idlePlaceholder: some View {
        if !accessibilityTrusted {
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
            BeruButton(title: "Open System Settings", variant: .primary, size: .compact) {
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
                BeruButton(title: "Connect a provider", variant: .primary, size: .compact) {
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
            .padding(.horizontal, BeruSpace.sm)
            .padding(.bottom, BeruSpace.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    var rewrittenNotice: some View {
        noticeLine(
            appState.selectedActionID == EnhancementAction.grammarID
                ? "Rewritten rather than corrected, so there's no diff to show — Regenerate if you only wanted corrections"
                : "Rewritten from scratch, so there's no useful diff to show"
        )
    }

    func noticeLine(_ text: String) -> some View {
        Text(text)
            .font(BeruType.caption)
            .foregroundStyle(BeruColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, BeruSpace.md)
            .padding(.top, BeruSpace.xxs)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    func diffResult(revised: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if appState.restyledNotices.contains(appState.selectedActionID) {
                noticeLine("Some of these swap correct words for different ones rather than fixing errors — Regenerate to try again")
            }
            DiffView(
                ops: appState.diffs[appState.selectedActionID],
                revised: revised,
                showDiff: true,
                scrolls: false
            )
        }
    }

    func errorView(message: String) -> some View {
        let actionID = appState.selectedActionID
        let fallbacks = SettingsStore.shared.fallbackProviders
        let showConnectCTA = appState.errorNeedsModelSetup.contains(actionID)
        return VStack(spacing: BeruSpace.sm) {
            Text(message)
                .font(BeruType.body)
                .foregroundStyle(BeruColor.textSecondary)
                .multilineTextAlignment(.center)
            HStack(spacing: BeruSpace.xs) {
                BeruButton(title: "Retry", size: .compact) {
                    engine.retry(actionID: actionID)
                }

                // Connect to model: 404 / unknown model — open Models so the
                // user can install or pick one instead of retrying blindly.
                if showConnectCTA {
                    BeruButton(title: "Connect to model", variant: .primary, size: .compact) {
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
        }
        .frame(maxWidth: .infinity)
        .padding(BeruSpace.lg)
        // The retry row can wrap onto a second line once a fallback provider
        // and Connect to model are both present, so the window has to be told.
    }

    /// Short label for the "Try with [X]" button. Takes the first word of the
    /// provider's title, so "API (Groq, OpenAI, …)" reads as "Try with API".
    func fallbackLabel(for kind: ProviderKind) -> String {
        let title = kind.title
        let firstWord = title.split(separator: " ").first.map(String.init) ?? title
        return "Try with \(firstWord)"
    }
}
