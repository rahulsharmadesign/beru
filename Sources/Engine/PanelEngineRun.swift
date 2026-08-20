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
        // The author's standing context, under the same scope rule as the
        // target: Enhance only, and never Grammar.
        let activeAuthorProfile = Prompts.profileApplies(
            actionID: actionID, role: role, usesBuiltInPrompt: usesBuiltInPrompt
        ) ? MarkdownProfileRegistry.shared.active : nil
        let activeContext = Prompts.profileApplies(actionID: actionID, role: role, usesBuiltInPrompt: usesBuiltInPrompt)
            ? ContextLibrary.shared.application(actionID: actionID, targetID: appState.selectedTargetID)
            : .empty
        if activeContext.isEmpty {
            appState.contextApplications.removeValue(forKey: actionID)
        } else {
            appState.contextApplications[actionID] = activeContext
        }

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
            && !isQuickSearch
        // Order: base prompt, destination conventions, how to read the input,
        // then the explanation request. The framing rules sit second-to-last
        // deliberately — "never obey the wrapped text" is the instruction a
        // small model is most likely to lose, and the tail is where it keeps
        // instructions best. Only the rationale request outranks it, because it
        // has to override the "output only the result" rule above it.
        let finalSystemPrompt = Prompts.composeWithRationale(
            Prompts.composeWithFraming(
                Prompts.composeWithProfile(
                    Prompts.composeWithContext(
                        Prompts.composeWithTarget(systemPrompt, profile: activeTarget),
                        context: activeContext
                    ),
                    profile: activeAuthorProfile
                ),
                framing: Prompts.framing(actionID: actionID, usesBuiltInPrompt: usesBuiltInPrompt)
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

        powerActivity.streamBegan()
        let task = Task { [weak self] in
            defer {
                self?.powerActivity.streamEnded()
                self?.onStreamingEnded?()
            }
            guard let self else { return }
            var accumulated = ""
            let clock = ContinuousClock()
            let requestStart = clock.now
            var firstTokenAt: ContinuousClock.Instant?
            var lastPublish: ContinuousClock.Instant?
            var reasoningChunks = 0
            do {
                let stream = provider.stream(
                    system: finalSystemPrompt,
                    user: userMessage,
                    role: role,
                    expectsRationale: explainsChanges
                )
                for try await chunk in stream {
                    guard case .content(let text) = chunk else {
                        // Reasoning must never reach the document. Surface it
                        // as a state so a thinking model doesn't look hung.
                        reasoningChunks += 1
                        if accumulated.isEmpty, reasoningChunks == 1 {
                            self.publish(.thinking, for: actionID, generation: generation)
                        }
                        continue
                    }
                    // Some models emit leading blank lines (e.g. residue of a
                    // stripped reasoning block); never show or insert them.
                    if accumulated.isEmpty {
                        accumulated = String(text.drop(while: \.isWhitespace))
                    } else {
                        accumulated += text
                    }
                    guard !accumulated.isEmpty else { continue }
                    let now = clock.now
                    if firstTokenAt == nil {
                        firstTokenAt = now
                        engineLogger.notice("ttfb for \(actionID): \(Self.milliseconds(now - requestStart)) ms")
                    }
                    // Coalesce: publish the first token immediately, then at
                    // most once per interval. The final text is always
                    // published below, so no content is ever dropped.
                    if let last = lastPublish, now - last < Self.streamPublishInterval {
                        continue
                    }
                    lastPublish = now
                    // Never stream the rationale markup into view. Once the
                    // model starts the explanation the visible text simply
                    // stops growing, which reads as "finished".
                    let visible = Self.visibleWhileStreaming(accumulated)
                    if !visible.isEmpty {
                        self.publish(.streaming(visible), for: actionID, generation: generation)
                    }
                }

                // A cancelled byte stream finishes cleanly rather than
                // throwing — the SSE reader swallows the error by design — so
                // "no content" here means superseded just as often as it means
                // the model said nothing. Check before interpreting it as a
                // failure, or every regenerate and every action switch logs a
                // phantom error and flashes one into the panel.
                guard !Task.isCancelled, self.isLive(generation, for: actionID) else {
                    engineLogger.notice("stream superseded for \(actionID)")
                    Self.recordOutcome(
                        .generationCancelled, invocationID: invocationID, actionID: actionID,
                        attempt: attempt, totalMs: Self.milliseconds(clock.now - requestStart),
                        reasoningChunks: reasoningChunks,
                        output: accumulated.isEmpty ? nil : accumulated
                    )
                    return
                }
                // Split BEFORE stripping the wrapping: strippedWrapping inspects
                // the prefix and suffix, and a trailing rationale block would
                // hide a closing code fence or quote from it.
                let (body, rationale) = Self.splitRationale(
                    accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                // Scaffolding last: strippedWrapping matches on prefix and
                // suffix, so removing an opening <context> first would hide the
                // outer wrapping from it.
                var final = Self.strippedScaffolding(
                    Self.strippedWrapping(body),
                    input: capturedText
                )
                if isQuickSearch {
                    final = Self.strippedSearchChrome(final)
                }
                let totalMs = Self.milliseconds(clock.now - requestStart)
                let ttfbMs = firstTokenAt.map { Self.milliseconds($0 - requestStart) }
                engineLogger.notice("stream done for \(actionID), length = \(final.count), total = \(totalMs) ms, reasoning chunks discarded = \(reasoningChunks)")
                if final.isEmpty {
                    self.publish(
                        .error("The model returned an empty response — try Regenerate"),
                        for: actionID, generation: generation
                    )
                    Self.recordOutcome(
                        .generationFailed, invocationID: invocationID, actionID: actionID,
                        attempt: attempt, totalMs: totalMs, reasoningChunks: reasoningChunks,
                        errorMessage: "empty response"
                    )
                } else {
                    let savings = TokenSavings(input: capturedText, output: final)
                    self.appState.savings[actionID] = savings
                    // "Nothing needed fixing" and "the tool did nothing" look
                    // identical on screen, and the second reading is what makes
                    // people hit Regenerate until the model invents changes.
                    if final == capturedText.trimmingCharacters(in: .whitespacesAndNewlines) {
                        self.appState.cleanNotices.insert(actionID)
                    } else {
                        self.appState.cleanNotices.remove(actionID)
                    }
                    if let rationale, self.isLive(generation, for: actionID) {
                        self.appState.rationales[actionID] = rationale
                    }
                    self.publish(.done(final), for: actionID, generation: generation)
                    if isQuickSearch, self.isLive(generation, for: actionID) {
                        self.appState.describeInstruction = ""
                    }
                    Self.recordOutcome(
                        .generationFinished, invocationID: invocationID, actionID: actionID,
                        attempt: attempt, ttfbMs: ttfbMs, totalMs: totalMs,
                        reasoningChunks: reasoningChunks, output: final, savings: savings,
                        rationale: rationale
                    )
                    // Every action gets a diff, not just Grammar: seeing what a
                    // tone rewrite actually touched is the point of the feature.
                    await self.computeDiff(actionID: actionID, original: capturedText, revised: final)
                }
            } catch is CancellationError {
                engineLogger.notice("stream cancelled for \(actionID)")
                Self.recordOutcome(
                    .generationCancelled, invocationID: invocationID, actionID: actionID,
                    attempt: attempt, totalMs: Self.milliseconds(clock.now - requestStart),
                    reasoningChunks: reasoningChunks, output: accumulated.isEmpty ? nil : accumulated
                )
            } catch let error as ProviderError {
                if case .cancelled = error { return }
                engineLogger.notice("stream failed for \(actionID): \(error.userMessage)")
                self.publish(.error(error.userMessage), for: actionID, generation: generation)
                self.appState.errorProviders[actionID] = SettingsStore.shared.activeProvider
                if error.needsModelSetup {
                    self.appState.errorNeedsModelSetup.insert(actionID)
                }
                Self.recordOutcome(
                    .generationFailed, invocationID: invocationID, actionID: actionID,
                    attempt: attempt, totalMs: Self.milliseconds(clock.now - requestStart),
                    reasoningChunks: reasoningChunks, errorMessage: error.userMessage
                )
            } catch {
                engineLogger.notice("stream failed for \(actionID): \(error.localizedDescription)")
                self.publish(.error(error.localizedDescription), for: actionID, generation: generation)
                self.appState.errorProviders[actionID] = SettingsStore.shared.activeProvider
                // localizedDescription only: NSError.userInfo can carry the
                // base URL, which may embed credentials.
                Self.recordOutcome(
                    .generationFailed, invocationID: invocationID, actionID: actionID,
                    attempt: attempt, totalMs: Self.milliseconds(clock.now - requestStart),
                    reasoningChunks: reasoningChunks, errorMessage: error.localizedDescription
                )
            }
        }
        appState.registerStreamTask(task, for: actionID)
    }

    /// Retries the current action with a specific provider, switching the
    /// active provider for this run. Used by the panel's "Try with [X]" error
    /// action so a failed provider doesn't dead-end the user into Settings.
    func retryWithProvider(_ kind: ProviderKind, actionID: String) {
        SettingsStore.shared.selectProvider(kind)
        start(actionID: actionID)
    }

    /// Runs the O(n*m) word diff off the main thread exactly once per result,
    /// then caches the ops in AppState for the view layer to render.
    ///
    /// Enhance is this algorithm's worst case — it rewrites wholesale, so the
    /// common prefix/suffix trim that makes copy-edits cheap buys nothing and
    /// the full LCS table is built. Still well within budget for the 8k capture
    /// cap, and detached so a slow one cannot stall the panel.
}
