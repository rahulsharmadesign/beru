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

        // Snapshot before persist: promoting composer-as-source clears the field.
        let composerSnapshot = instruction ?? appState.describeInstruction
        let resolved = EnhancementAction.resolveInput(
            actionID: actionID,
            capturedText: appState.capturedText,
            composerText: composerSnapshot
        )
        let isQuickSearch = actionID == EnhancementAction.searchID
        // Verb skills need material to work on. Search and the intent bar may
        // run on an empty capture — the question or instruction is the job.
        // Typed composer text counts as that material when nothing was selected.
        if !EnhancementAction.allowsEmptyCapture(actionID),
           resolved.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appState.setResult(.idle, for: actionID)
            return
        }

        var capturedText = resolved.sourceText
        if resolved.usedComposerAsSource {
            if capturedText.count > Self.maxCapturedLength {
                capturedText = String(capturedText.prefix(Self.maxCapturedLength))
                appState.truncationNotice = true
            }
            appState.capturedText = capturedText
            appState.describeInstruction = ""
        }
        let capturedEmpty = capturedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        /// Recorded in the history so a surprising result can be traced back to
        /// the prompt that produced it.
        let usedCustomSkillPrompt = !usesBuiltInPrompt

        let generation = beginGeneration(for: actionID)
        if actionID == EnhancementAction.searchID {
            appState.beginSearchTurn(
                question: resolved.extraInstruction,
                regenerating: previousResult != nil
            )
        }
        appState.setResult(.loading, for: actionID)
        appState.resultFeedback.removeValue(forKey: actionID)
        if actionID == EnhancementAction.grammarID {
            // Fresh triple, fresh ballots: a vote on the old Corrected must
            // not stick to the new one.
            appState.grammarVote.removeAll()
        }
        if actionID == EnhancementAction.replyID {
            appState.replyVote.removeAll()
        }
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
            let question = resolved.extraInstruction
            // Follow-up context rides the USER message: small models resolve
            // "From when?" against a conversation they can see next to the
            // question far better than against a system-side history block.
            // The system-side thread block stays off for Search.
            // The whole thread rides along — every completed Q&A for this
            // app, oldest first, stored whole — so a follow-up at turn 6 can
            // still resolve against turns 1 and 2. storageCap is the only
            // guard; a long session costs a longer input on every turn.
            let priorTurns = SessionThread.shared.turns(forBundleID: appState.hostBundleID)
            if appState.hostBundleID == nil {
                engineLogger.notice("search follow-up with nil hostBundleID — no transcript attached")
            } else if appState.searchThread.count > 1, priorTurns.isEmpty {
                engineLogger.notice(
                    "search follow-up without transcript — prior turn still streaming or host changed"
                )
            }
            let transcript = Self.searchTranscript(turns: priorTurns)
            var message = ""
            if !transcript.isEmpty {
                message += "Earlier in this conversation:\n\(transcript)\n\n"
            }
            if capturedEmpty {
                message += question
            } else {
                message += Prompts.userMessage(
                    capturedText: capturedText,
                    clipboardText: clipboardForRequest
                ) + "\n\nQuestion:\n\(question)"
            }
            userMessage = message
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
            let extra = resolved.extraInstruction
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
                // Search turns only feed Search. A question-and-answer is the
                // wrong kind of history for prompt enhancement: small models
                // read the previous answer as the thing to keep answering and
                // produce an answer-shaped result instead of an enhanced prompt.
                .filter { actionID == EnhancementAction.searchID || $0.actionID != EnhancementAction.searchID }
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
        // Search question or rewrite extras — empty when the composer was the source.
        let threadInstruction = resolved.extraInstruction
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

    /// The full Q&A transcript attached to a Search follow-up, oldest first
    /// so the conversation reads in order. Turns with no recorded answer are
    /// skipped — a question that produced nothing is not context.
    static func searchTranscript(turns: [SessionThread.Turn]) -> String {
        turns
            .compactMap { turn -> String? in
                guard !turn.output.isEmpty else { return nil }
                return "Q: \(turn.instruction)\nA: \(turn.output)"
            }
            .joined(separator: "\n\n")
    }

    /// Retries the current action with a specific provider, switching the active
    /// provider for this run. Used by the panel's "Try with [X]" error action so
    /// a failed provider doesn't dead-end the user into Settings.
    func retryWithProvider(_ kind: ProviderKind, actionID: String) {
        SettingsStore.shared.selectProvider(kind)
        start(actionID: actionID)
    }
}
