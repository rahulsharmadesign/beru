import AppKit
import SwiftUI

// The bottom half: instruction field, send button, target and provider
// pickers, and the footer actions.

extension PanelView {
    // MARK: - Footer / composer

    var hasFinishedResult: Bool {
        if case .done = appState.resultState(for: appState.selectedActionID) { return true }
        return false
    }

    /// Outcome strip sits behind the composer and only appears once a result
    /// is in — and stays, dimmed, while that result reloads, so Regenerate
    /// does not collapse the chrome and bounce the composer mid-refresh.
    ///
    /// Search, Grammar, and Reply have no strip: turns and rows own every
    /// outcome. Their shell mounts only for result-level info with no row
    /// home (write-back toast, applied context). Enhance and the verb tabs
    /// keep a plain leading icon row — no glass, no overlap.
    ///
    /// The slot is always `footerMinHeight` so Search → Enhance cannot grow
    /// the window when the icons appear (the reverse shrink is already frozen).
    var composerColumn: some View {
        VStack(spacing: 0) {
            footerSlot
            intentField
                .frame(maxWidth: .infinity)
                .glassModule(
                    radius: PanelMetrics.composerRadius,
                    focusRing: describeFieldFocused,
                    scrim: .well
                )
                .overlay { firstRunBeamOverlay }
                .frame(maxWidth: .infinity)
                .clipped()
                .fixedSize(horizontal: false, vertical: true)
                // Collapsed to zero height, not removed: the text view stays
                // the panel's first responder, so Escape, ⌘↩ and Tab keep
                // working, and typing lands in it and expands it.
                .frame(height: composerCollapsed ? 0 : nil, alignment: .top)
                .clipped()
                .accessibilityHidden(composerCollapsed)
                .zIndex(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            toastFallbackOverlay
        }
        .animation(nil, value: hasFinishedResult)
        .animation(nil, value: appState.selectedActionID)
    }

    /// Keeps chrome height stable across tabs. Empty on Search / Grammar /
    /// Reply; filled on Enhance once a result is in.
    var footerSlot: some View {
        ZStack {
            if showsFooter {
                footer
                    .opacity(footerReloading ? 0.5 : 1)
            } else if let hint = footerHint, !toastVisible {
                hintLine(hint)
            }
        }
        .frame(height: PanelMetrics.footerMinHeight)
        .frame(maxWidth: .infinity)
    }

    /// Transient confirmations ("Replaced in …", "Pinned") never resize the
    /// chrome. Tabs with a footer show the text inline while the icon row
    /// and savings hide for the 0.8s confirmation (that chrome is dead — the
    /// panel dismisses when the toast clears). Grammar/Reply have no
    /// footer, so the toast floats over the composer spacer zone instead,
    /// ignoring clicks so the pill and mic stay usable beneath it.
    @ViewBuilder
    var toastFallbackOverlay: some View {
        Group {
            if toastVisible && !showsFooter {
                    toastText
                    .padding(.horizontal, BeruSpace.sm)
                    .padding(.vertical, BeruSpace.xxs)
                    .beruOverlayCapsule()
                    .padding(.bottom, BeruSpace.xl)
                    .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.15), value: toastVisible)
    }

    @ViewBuilder
    var toastText: some View {
        if let replaced = appState.replacedFeedback {
            Text(replaced)
                .font(BeruType.footnote)
                .foregroundStyle(BeruColor.textSecondary)
                .lineLimit(1)
                .accessibilityAddTraits(.updatesFrequently)
        } else if appState.pinnedFeedback {
            Text("Pinned")
                .font(BeruType.footnote)
                .foregroundStyle(BeruColor.textSecondary)
                .lineLimit(1)
        }
    }

    var toastVisible: Bool {
        appState.replacedFeedback != nil || appState.pinnedFeedback
    }

    var showsFooter: Bool {
        appState.showsFooter(for: appState.selectedActionID)
    }

    /// A finished result currently reloading. Footer actions self-guard
    /// (copy/pin/replace/vote need `.done` text; `retry` refuses a live
    /// run), so dimming is the only treatment the strip needs.
    var footerReloading: Bool {
        showsFooter && !hasFinishedResult
    }

    var footer: some View {
        HStack(spacing: BeruSpace.xs) {
            footerPrimaryAction

            if !toastVisible {
                footerActions
            }

            Spacer(minLength: 0)

            if toastVisible {
                toastText
                    .transition(.opacity)
            } else {
                if showsTokenSavings, let savings = appState.savings[appState.selectedActionID] {
                    SavingsPill(savings: savings)
                        .transition(.opacity)
                }

                if let provenance = contextProvenance {
                    Text(provenance)
                        .font(BeruType.captionMedium)
                        .foregroundStyle(BeruColor.textSecondary)
                        .lineLimit(1)
                        .help("Local context applied to this result")
                }
            }
        }
        .padding(.horizontal, PanelMetrics.moduleInset)
        .frame(height: PanelMetrics.footerMinHeight, alignment: .center)
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.15), value: toastVisible)
    }

    /// Write-back first and left-aligned: Replace (Insert on Reply, Apply
    /// on a vault note) matches the copy-row type color. The token pill
    /// sits far right as a side note.
    /// Clicks travel through `PanelHitCapsule`: window-drag swallows plain
    /// buttons here.
    @ViewBuilder
    var footerPrimaryAction: some View {
        if !isSearchTab && !isGrammar && !isSmartReply && showsHostWriteAction {
            PanelHitCapsule(
                help: primaryFooterHoverHelp,
                accessibilityLabel: primaryFooterTitle,
                showsHelpPill: true,
                // Leading element of the footer row: a centered pill hangs
                // past the panel's left inset and the hosting view crops it.
                helpAnchor: .leading
            ) {
                performReplace()
            } label: {
                ZStack {
                    BeruGlassButton(
                        title: primaryFooterTitle,
                        secondary: true,
                        size: .compact,
                        leadingIcon: "replace"
                    ) {}
                    .opacity(appState.replacedFeedback != nil ? 0 : 1)
                    BeruLoader.compact()
                        .frame(width: BeruMetrics.roundButtonSm, height: BeruMetrics.roundButtonSm)
                        .opacity(appState.replacedFeedback != nil ? 1 : 0)
                }
                .animation(.easeOut(duration: 0.15), value: appState.replacedFeedback != nil)
            }
        }
    }

    /// Icon-only outcome row. Only Enhance and the verb tabs have one:
    /// Search turns, Grammar rows, and Reply rows own every outcome, so
    /// those tabs render nothing here. Clicks still travel through
    /// `PanelHitCapsule`: window-drag swallows plain buttons here.
    @ViewBuilder
    var footerActions: some View {
        if isSearchTab {
            // Turns own copy, regenerate, votes, and pin.
            EmptyView()
        } else if isGrammar || isSmartReply {
            // Rows own copy, regenerate, votes, write-back, and pin.
            EmptyView()
        } else {
            let actionID = appState.selectedActionID
            let vote = appState.resultFeedback[actionID]
            PanelHitCapsule(
                help: appState.copiedFeedback ? "Copied" : "Copy response",
                accessibilityLabel: appState.copiedFeedback ? "Copied" : "Copy",
                showsHelpPill: true
            ) {
                performCopy()
            } label: {
                SearchActionButton(
                    icon: appState.copiedFeedback ? "check" : "copy",
                    help: appState.copiedFeedback ? "Copied" : "Copy response",
                    tint: appState.copiedFeedback ? BeruColor.positive : nil
                ) {}
                .animation(.easeOut(duration: 0.15), value: appState.copiedFeedback)
            }
            PanelHitCapsule(
                help: "Regenerate",
                accessibilityLabel: "Regenerate",
                showsHelpPill: true
            ) {
                engine.retry(actionID: actionID)
            } label: {
                SearchActionButton(icon: "rotate-cw", help: "Regenerate") {}
            }
            if composerCollapsed {
                PanelHitCapsule(
                    help: "Refine (⌘L, or just type)",
                    accessibilityLabel: "Refine",
                    showsHelpPill: true
                ) {
                    composerExpanded = true
                } label: {
                    SearchActionButton(icon: "message-square", help: "Refine (⌘L, or just type)") {}
                }
            }
            PanelHitCapsule(
                help: "Good result",
                accessibilityLabel: "Like",
                showsHelpPill: true
            ) {
                setResultVoteFooter(liked: true)
            } label: {
                SearchActionButton(icon: "thumbs-up", help: "Good result", active: vote == true) {}
            }
            PanelHitCapsule(
                help: "Bad result",
                accessibilityLabel: "Dislike",
                showsHelpPill: true
            ) {
                setResultVoteFooter(liked: false)
            } label: {
                SearchActionButton(icon: "thumbs-down", help: "Bad result", active: vote == false) {}
            }
            PanelHitCapsule(
                help: appState.pinnedFeedback ? "Pinned" : "Pin",
                accessibilityLabel: appState.pinnedFeedback ? "Pinned" : "Pin",
                showsHelpPill: true
            ) {
                performPin()
            } label: {
                SearchActionButton(
                    icon: appState.pinnedFeedback ? "check" : "pin",
                    help: "Pin",
                    tint: appState.pinnedFeedback ? BeruColor.positive : nil
                ) {}
            }
        }
    }

    var isErrorState: Bool {
        if case .error = appState.resultState(for: appState.selectedActionID) { return true }
        return false
    }

    var intentField: some View {
        VStack(alignment: .leading, spacing: BeruSpace.sm) {
            HStack(alignment: .top, spacing: BeruSpace.xs) {
                BeruIcon(
                    name: appState.isQuickSearch ? "search" : "sparkles",
                    size: 16
                )
                .foregroundStyle(BeruColor.textSecondary)
                ZStack(alignment: .topLeading) {
                    if appState.describeInstruction.isEmpty {
                        Text(composerPlaceholder)
                            .font(BeruType.body)
                            .foregroundStyle(BeruColor.textSecondary)
                            .lineLimit(1)
                    }
                    ComposerTextField(
                        text: $appState.describeInstruction,
                        isFocused: describeFieldFocused,
                        onSubmit: { submitDescribe() },
                        onTab: {
                            if case .handled = perform(resolveTabIntent()) { return true }
                            return false
                        },
                        onFocusChange: { describeFieldFocused = $0 }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .clipped()
                }
            }
            HStack(spacing: PanelMetrics.moduleInset) {
                if targetPickerVisible {
                    targetMenu
                } else {
                    providerMenu
                }
                // Mic and send ride the trailing edge; the provider/target
                // pill owns the leading edge. Regenerate lives on the
                // outcome row (Enhance) or on Search / Grammar / Reply rows.
                Spacer(minLength: 0)
                DictationButton(onNeedsPermission: { engine.requestDictationPermission() })
                sendButton
            }
            .frame(maxWidth: .infinity)
        }
        // Search mode swaps the icon, placeholder and the target/provider menu.
        // Scoped here so the composer card's own frame is not part of it.
        .animation(nil, value: appState.isQuickSearch)
        .padding(.horizontal, PanelMetrics.moduleInset)
        .padding(.top, PanelMetrics.moduleInset)
        .padding(.bottom, BeruSpace.xs)
        .frame(minHeight: PanelMetrics.composerMinHeight, alignment: .center)
        .frame(maxWidth: .infinity)
    }

    var composerPlaceholder: String {
        let hasCapture = !appState.capturedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return EnhancementAction.composerPlaceholder(
            actionID: appState.selectedActionID,
            hasCapture: hasCapture,
            isQuickSearch: appState.isQuickSearch,
            targetName: targetRegistry.profile(withID: appState.selectedTargetID)?.name
        )
    }

    var canSubmitDescribe: Bool {
        return !appState.describeInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func submitDescribe() {
        if appState.selectedActionID == EnhancementAction.searchID || appState.isQuickSearch {
            engine.runQuickSearch(query: appState.describeInstruction)
        } else {
            engine.runDescribe(instruction: appState.describeInstruction)
        }
    }

    var targetPickerVisible: Bool {
        guard !appState.isQuickSearch,
              let action = registry.action(withID: appState.selectedActionID) else { return false }
        return Prompts.targetApplies(
            actionID: action.id, role: action.role, usesBuiltInPrompt: action.isBuiltIn
        )
    }

    func selectTarget(_ targetID: String) {
        guard targetID != appState.selectedTargetID else { return }
        appState.selectTarget(targetID)
        let actionID = appState.selectedActionID
        appState.results.removeValue(forKey: actionID)
        engine.startIfNeeded(actionID: actionID)
    }

    func performReplace() {
        guard let text = appState.acceptedText() else { return }
        engine.replace(text: text)
    }

    func performCopy() {
        guard let text = appState.acceptedText() else { return }
        engine.copy(text: text)
    }

    func performPin() {
        guard let text = appState.acceptedText() else { return }
        engine.pin(text: text)
    }
}
