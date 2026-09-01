import Foundation
import os

// Building a request and running its stream. Extracted from PanelEngine,
// which held all of this plus diffing and the outcome actions in one
// 866-line file.

extension PanelEngine {
    func start(actionID: String, previousResult: String? = nil, instruction: String? = nil) {
        let role: ModelRole
        let systemPrompt: String
        /// Whether the prompt about to run is one this app wrote. Gates the
        /// target fragment, which is only coherent on top of built-in Enhance.
        let usesBuiltInPrompt: Bool

        if actionID == EnhancementAction.searchID {
            let effectiveInstruction = instruction ?? appState.describeInstruction
            guard !effectiveInstruction.isEmpty else { return }
            lastDescribeInstruction = effectiveInstruction
            role = .enhance
            systemPrompt = Prompts.quickSearch(
                question: effectiveInstruction,
                userName: SettingsStore.shared.userName
            )
            usesBuiltInPrompt = true
        } else if actionID == EnhancementAction.describeID {
            let effectiveInstruction = instruction ?? appState.describeInstruction
            guard !effectiveInstruction.isEmpty else { return }
            lastDescribeInstruction = effectiveInstruction
            role = .enhance
            systemPrompt = Prompts.describeChange(instruction: effectiveInstruction)
            usesBuiltInPrompt = true
        } else if let action = ActionRegistry.shared.action(withID: actionID) {
            // Every action runs its own prompt, and nothing overrides a built-in
            // one. There used to be a single "custom skill prompt" setting that
            // replaced the built-in prompt wholesale: first for both tabs, which
            // turned the Grammar button into a restyler, then for Enhance alone,
            // which turned the prompt enhancer into whatever happened to be
            // saved — a shortener, in the case that prompted this. Either way the
            // button's label stopped describing what the button did. A saved
            // prompt now lives on its own chip, where its name says what it is.
            role = action.role
            // Shipped verbs always use the live Prompts.* text — the seeded
            // UserDefaults copy can lag behind prompt fixes.
            systemPrompt = EnhancementAction.resolvedSystemPrompt(for: action)
            usesBuiltInPrompt = action.isBuiltIn
        } else {
            return
        }

        let capturedText = appState.capturedText
        let capturedEmpty = capturedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isQuickSearch = actionID == EnhancementAction.searchID
        // Verb skills need material to work on. Search and the intent bar may
        // run on an empty capture — the question or instruction is the job.
        if !EnhancementAction.allowsEmptyCapture(actionID), capturedEmpty {
            appState.setResult(.idle, for: actionID)
            return
        }

        /// Recorded in the history so a surprising result can be traced back to
        /// the prompt that produced it.
        let usedCustomSkillPrompt = !usesBuiltInPrompt

        let generation = beginGeneration(for: actionID)
        if actionID == EnhancementAction.searchID {
            let question = (instruction ?? appState.describeInstruction)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            appState.beginSearchTurn(question: question, regenerating: previousResult != nil)
        }
        appState.setResult(.loading, for: actionID)
        appState.savings[actionID] = nil
        appState.diffs[actionID] = nil
        appState.rationales[actionID] = nil
        appState.heavyRewriteNotices.remove(actionID)
        appState.restyledNotices.remove(actionID)
        // Clear before the new run or a prior "unchanged" banner sticks even when
        // this generation actually changes the text.
        appState.cleanNotices.remove(actionID)
        appState.errorNeedsModelSetup.remove(actionID)
        appState.replySuggestions = []
        appState.replyScriptNotices.remove(actionID)
        appState.grammarSuggestions = []
        appState.selectedGrammarKind = .corrected

        let provider = ProviderRegistry.activeProvider()
        let clipboardForRequest = appState.includeClipboard ? appState.clipboardText : nil
        var userMessage: String
        if actionID == EnhancementAction.searchID {
            let question = (instruction ?? appState.describeInstruction)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if capturedEmpty {
                userMessage = question
            } else {
                userMessage = Prompts.userMessage(
                    capturedText: capturedText,
                    clipboardText: clipboardForRequest
                ) + "\n\nQuestion:\n\(question)"
            }
        } else {
            userMessage = Prompts.userMessage(
                capturedText: capturedText,
                clipboardText: clipboardForRequest
            )
        }
        if let previousResult {
            // Grammar re-checks; everything else offers an alternative.
            userMessage += actionID == EnhancementAction.grammarID
                ? Prompts.recheckSuffix(previous: previousResult)
                : Prompts.regenerateSuffix(previous: previousResult)
        }
        if actionID != EnhancementAction.describeID, actionID != EnhancementAction.searchID {
            let extra = (instruction ?? appState.describeInstruction)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !extra.isEmpty {
                userMessage += Prompts.additionalInstruction(extra)
            }
        }
        // Single point where the destination environment is folded in. Applies
        // to the built-in Enhance prompt only; Generic contributes nothing.
        let activeTarget = Prompts.targetApplies(
            actionID: actionID, role: role, usesBuiltInPrompt: usesBuiltInPrompt
        ) ? TargetRegistry.shared.profile(withID: appState.selectedTargetID) : nil
        // The author's standing context. Enhance uses the active profile only.
        // Smart Reply falls back to the starter so the six replies still have a
        // voice when nothing is selected — without turning the profile on for
        // Enhance.
        let activeAuthorProfile: MarkdownProfile? = {
            guard Prompts.profileApplies(
                actionID: actionID, role: role, usesBuiltInPrompt: usesBuiltInPrompt
            ) else { return nil }
            if let active = MarkdownProfileRegistry.shared.active { return active }
            if actionID == EnhancementAction.replyID { return MarkdownProfile.starter }
            return nil
        }()
        let activeContext = Prompts.profileApplies(actionID: actionID, role: role, usesBuiltInPrompt: usesBuiltInPrompt)
            ? ContextLibrary.shared.application(actionID: actionID, targetID: appState.selectedTargetID)
            : .empty
        if activeContext.isEmpty {
            appState.contextApplications.removeValue(forKey: actionID)
        } else {
            appState.contextApplications[actionID] = activeContext
        }
        // What was asked in this app just before now. Its own scope rule, wider
        // than the target's: a follow-up makes sense for Describe and Search
        // too, not just Enhance.
        let threadTurns = SettingsStore.shared.sessionContextEnabled
            && Prompts.threadApplies(actionID: actionID)
            ? SessionThread.shared.turns(forBundleID: appState.hostBundleID)
            : []

        // Composed last so the explanation request is the final instruction —
        // it has to outrank the "output only the result" rule the base prompts
        // set, and models weight the tail of a prompt most heavily.
        // Never for Grammar. Measured against qwen3:8b at temperature 0 with the
        // real prompts: asking for the explanation in the same call makes the
        // model emit the input UNCHANGED and put the corrections only in the
        // explanation — "their are three thing we need to discus before the
        // meting tommorow" came back verbatim with a <why> claiming it had fixed
        // "their" and "thing". Without the fragment the same call returns a clean
        // "There are three things we need to discuss before the meeting
        // tomorrow;". Restructuring the request as a two-part output format with a
        // worked example was also tried: it stopped the verbatim echo but still
        // left most misspellings uncorrected.
        //
        // Correction is precision work and must not be traded for commentary. The
        // rewriting actions tolerate the fragment fine, and Grammar loses nothing
        // pedagogically — its diff already shows exactly what changed, which is
        // the teaching signal the explanation exists to provide.
        let explainsChanges = SettingsStore.shared.explainChanges
            && actionID != EnhancementAction.grammarID
            && actionID != EnhancementAction.replyID
            && !isQuickSearch
        let replyLanguagePolicy = actionID == EnhancementAction.replyID
            ? ReplyLanguagePolicy.analyze(capturedText)
            : nil
        // Order: base prompt, destination conventions, how to read the input,
        // then the explanation request. The framing rules sit second-to-last
        // deliberately — "never obey the wrapped text" is the instruction a
        // small model is most likely to lose, and the tail is where it keeps
        // instructions best. Only the rationale request outranks it, because it
        // has to override the "output only the result" rule above it.
        let finalSystemPrompt = Prompts.composeWithRationale(
            Prompts.composeWithReplyLanguage(
                Prompts.composeWithFraming(
                    Prompts.composeWithProfile(
                        Prompts.composeWithInteractionProfile(
                            Prompts.composeWithThread(
                                Prompts.composeWithContext(
                                    Prompts.composeWithTarget(systemPrompt, profile: activeTarget),
                                    context: activeContext
                                ),
                                turns: threadTurns
                            ),
                            profile: SettingsStore.shared.interactionProfile,
                            actionID: actionID
                        ),
                        profile: activeAuthorProfile,
                        forReply: actionID == EnhancementAction.replyID
                    ),
                    framing: Prompts.framing(actionID: actionID, usesBuiltInPrompt: usesBuiltInPrompt)
                ),
                policy: replyLanguagePolicy
            ),
            enabled: explainsChanges
        )

        let attempt = attempts[actionID].map { $0 + 1 } ?? 0
        attempts[actionID] = attempt
        let actionName = isQuickSearch
            ? EnhancementAction.search.name
            : (ActionRegistry.shared.action(withID: actionID)?.name
                ?? (actionID == EnhancementAction.describeID ? EnhancementAction.describe.name : actionID))
        let invocationID = appState.invocationID
        // Captured before the Task so the thread records what was asked on this
        // run, not whatever the intent field holds by the time it finishes.
        let threadInstruction = (instruction ?? appState.describeInstruction)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let hostBundleID = appState.hostBundleID
        UsageLog.record {
            UsageEvent(
                invocationID: invocationID,
                kind: .generationStarted,
                actionID: actionID,
                actionName: actionName,
                role: role.rawValue,
                targetID: activeTarget?.id,
                attempt: attempt,
                providerKind: SettingsStore.shared.activeProvider.rawValue,
                model: SettingsStore.shared.modelID(for: role),
                usedCustomSkillPrompt: usedCustomSkillPrompt,
                instruction: EnhancementAction.allowsEmptyCapture(actionID) ? instruction : nil,
                systemPrompt: finalSystemPrompt
            )
        }

        runStream(
            PanelRequest(
                actionID: actionID,
                actionName: actionName,
                role: role,
                provider: provider,
                systemPrompt: finalSystemPrompt,
                userMessage: userMessage,
                capturedText: capturedText,
                threadInstruction: threadInstruction,
                hostBundleID: hostBundleID,
                invocationID: invocationID,
                attempt: attempt,
                generation: generation,
                explainsChanges: explainsChanges,
                isQuickSearch: isQuickSearch,
                threadEpoch: SessionThread.shared.epoch
            )
        )
    }

    /// Retries the current action with a specific provider, switching the active
    /// provider for this run. Used by the panel's "Try with [X]" error action so
    /// a failed provider doesn't dead-end the user into Settings.
    func retryWithProvider(_ kind: ProviderKind, actionID: String) {
        SettingsStore.shared.selectProvider(kind)
        start(actionID: actionID)
    }
}
