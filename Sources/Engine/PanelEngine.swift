import AppKit
import Foundation
import os.log

private let logger = Logger(subsystem: "com.rahul.beru", category: "engine")

/// Orchestrates capture -> LLM streaming -> replace/copy for the floating panel.
/// UI-agnostic: PanelView drives it, AppState holds the state it produces.
@MainActor
final class PanelEngine {
    static let maxCapturedLength = 8000

    private let appState: AppState
    private let onDismiss: () -> Void
    /// Notified when no stream is in flight, so the panel may shrink to fit.
    var onStreamingEnded: (() -> Void)?

    /// Set by the coordinator to open the dashboard's Permissions screen.
    ///
    /// The panel cannot ask for microphone access itself: it is a
    /// non-activating window in an accessory process, so the system dialog may
    /// never come to the front. The request has to be made from a real window.
    var onRequestDictationPermission: (() -> Void)?

    func requestDictationPermission() {
        onRequestDictationPermission?()
    }
    private let powerActivity = PowerActivity()
    private var lastDescribeInstruction: String?
    /// Regeneration count per action within the current invocation.
    private var attempts: [String: Int] = [:]

    /// Monotonic for the life of the process, never reset: a token that came
    /// round again could let a task cancelled in a previous invocation write
    /// into the current one.
    private var generationCounter = 0
    /// The generation whose writes are still wanted, per action.
    private var liveGeneration: [String: Int] = [:]

    /// Called when a new panel session begins, so attempt numbering restarts.
    func resetForNewInvocation() {
        attempts.removeAll()
        // Nothing from the previous session is live any more. Clearing rather
        // than reassigning matters: an in-flight task holds a token that now
        // matches no entry, so it can no longer publish.
        liveGeneration.removeAll()
        lastDescribeInstruction = nil
    }

    private func beginGeneration(for actionID: String) -> Int {
        generationCounter += 1
        liveGeneration[actionID] = generationCounter
        return generationCounter
    }

    private func isLive(_ generation: Int, for actionID: String) -> Bool {
        liveGeneration[actionID] == generation
    }

    /// Writes result state only while this generation is still the live one.
    ///
    /// A superseded stream ends with nothing accumulated, which is
    /// indistinguishable from a genuinely empty model response — without this
    /// guard it paints "empty response" over the run that replaced it, and the
    /// panel shows an error while a perfectly good result is still streaming.
    private func publish(_ state: ResultState, for actionID: String, generation: Int) {
        guard isLive(generation, for: actionID) else { return }
        appState.setResult(state, for: actionID)
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
    private static let streamPublishInterval: Duration = .milliseconds(100)

    private func start(actionID: String, previousResult: String? = nil, instruction: String? = nil) {
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
            appState.setResult(.error("Add text or dictate first"), for: actionID)
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
                        logger.notice("ttfb for \(actionID): \(Self.milliseconds(now - requestStart)) ms")
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
                    logger.notice("stream superseded for \(actionID)")
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
                logger.notice("stream done for \(actionID), length = \(final.count), total = \(totalMs) ms, reasoning chunks discarded = \(reasoningChunks)")
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
                logger.notice("stream cancelled for \(actionID)")
                Self.recordOutcome(
                    .generationCancelled, invocationID: invocationID, actionID: actionID,
                    attempt: attempt, totalMs: Self.milliseconds(clock.now - requestStart),
                    reasoningChunks: reasoningChunks, output: accumulated.isEmpty ? nil : accumulated
                )
            } catch let error as ProviderError {
                if case .cancelled = error { return }
                logger.notice("stream failed for \(actionID): \(error.userMessage)")
                self.publish(.error(error.userMessage), for: actionID, generation: generation)
                self.appState.errorProviders[actionID] = SettingsStore.shared.activeProvider
                Self.recordOutcome(
                    .generationFailed, invocationID: invocationID, actionID: actionID,
                    attempt: attempt, totalMs: Self.milliseconds(clock.now - requestStart),
                    reasoningChunks: reasoningChunks, errorMessage: error.userMessage
                )
            } catch {
                logger.notice("stream failed for \(actionID): \(error.localizedDescription)")
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
    /// How much of the result must survive from the original for a diff to be
    /// worth rendering (see `WordDiff.retentionRatio`).
    ///
    /// An inline diff communicates by showing a mostly-intact document with the
    /// changes marked. Once little is shared there is no skeleton left, so the
    /// renderer interleaves two unrelated documents word by word and emits things
    /// like `Can<context>` and `I need theThe` — output that looks corrupted even
    /// though the result is perfectly correct. Enhance hits this routinely, since
    /// rewriting into a structured prompt shares almost no wording with the input.
    ///
    /// Calibrated against measured values rather than guessed: a single typo
    /// retains 0.55, a short grammar pass 0.52, a long one 0.80, a tone rewrite
    /// 0.48 — while the reported XML-structure rewrite retained 0.27 and a total
    /// rewrite 0.06. 0.4 sits in the gap with margin on both sides.
    static let diffLegibilityFloor = 0.4

    private func computeDiff(actionID: String, original: String, revised: String) async {
        // Transform verbs are new documents, not edits of the selection. Skip
        // before the LCS work — and before we could store a "legible" diff that
        // still reads as corrupted interleaved text.
        guard EnhancementAction.showsInlineDiff(for: actionID) else { return }

        let ops = await Task.detached(priority: .userInitiated) {
            WordDiff.diff(original: original, revised: revised)
        }.value
        // The result may have been superseded while the diff ran; a diff
        // attached to text that is no longer on screen would highlight the
        // wrong words.
        guard case .done(revised) = appState.resultState(for: actionID) else { return }

        // A diff of identical text is all `.equal` — nothing to highlight, and
        // storing it would hide the "nothing needed fixing" notice behind an
        // apparently-empty diff view.
        let hasChanges = ops.contains {
            switch $0 {
            case .insertion, .deletion: return true
            case .equal: return false
            }
        }
        guard hasChanges else { return }

        guard WordDiff.retentionRatio(ops) >= Self.diffLegibilityFloor else {
            // Leave the diff unset so the plain result renders, and say why —
            // silently dropping it would look like the diff had failed.
            appState.heavyRewriteNotices.insert(actionID)
            return
        }
        appState.diffs[actionID] = ops

        // Grammar may only replace a word with a corrected spelling of it. When
        // most of its substitutions are unrelated words, the model paraphrased —
        // and it should say so rather than pass a rewrite off as a correction.
        if actionID == EnhancementAction.grammarID,
           WordDiff.paraphraseScore(ops) > Self.grammarParaphraseCeiling {
            appState.restyledNotices.insert(actionID)
        }
    }

    /// Above this share of unrelated word substitutions, Grammar has rewritten
    /// rather than corrected. Corrections cluster near 0 (every replacement is a
    /// near-miss of the original word); the reported paraphrase scored 1.0.
    static let grammarParaphraseCeiling = 0.4

    /// Separates the result from its explanation.
    ///
    /// MUST run in the engine, before `.done(...)` — never in the view. Replace
    /// pastes the result string verbatim into the user's document, so a split
    /// that happened at render time would eventually paste "here's why I
    /// changed your wording" into somebody's Slack message.
    ///
    /// An unterminated opening tag (cancelled or truncated stream) still counts
    /// as a split: everything from the tag onward becomes the rationale, so the
    /// markup cannot survive into the result under any circumstances.
    static func splitRationale(_ text: String) -> (result: String, rationale: String?) {
        guard let open = text.range(of: Prompts.rationaleOpenTag) else {
            return (text, nil)
        }
        let result = String(text[..<open.lowerBound])
        var rationale = String(text[open.upperBound...])
        if let close = rationale.range(of: Prompts.rationaleCloseTag) {
            rationale = String(rationale[..<close.lowerBound])
        }
        let trimmed = rationale.trimmingCharacters(in: .whitespacesAndNewlines)
        return (
            result.trimmingCharacters(in: .whitespacesAndNewlines),
            trimmed.isEmpty ? nil : trimmed
        )
    }

    /// The portion of a partial stream that is safe to display. Drops anything
    /// from the rationale tag onward, and also any incomplete prefix of it, so
    /// the user never watches "<wh" appear and then vanish mid-stream.
    static func visibleWhileStreaming(_ text: String) -> String {
        if let open = text.range(of: Prompts.rationaleOpenTag) {
            return String(text[..<open.lowerBound])
        }
        var partial = Prompts.rationaleOpenTag.dropLast()
        while !partial.isEmpty {
            if text.hasSuffix(partial) {
                return String(text.dropLast(partial.count))
            }
            partial = partial.dropLast()
        }
        return text
    }

    /// Container tags a model added that the user never wrote.
    ///
    /// Replace pastes the result into the document the text came from, so a
    /// `<context>…</context><task>…</task>` skeleton lands in the middle of
    /// someone's writing. The Claude target no longer asks for tags, but a
    /// prompt instruction is a probability and this is a one-way write into a
    /// real document, so the guarantee is made structurally as well.
    ///
    /// Only tags absent from the input are removed. Someone enhancing text that
    /// genuinely discusses `<task>`, or a prompt they deliberately tagged
    /// themselves, must get their own markup back untouched — the rule is the
    /// same one the target fragments follow: never remove what the user supplied.
    ///
    /// Container names only. `<b>`, `<div>` and the like are left alone: those
    /// appear in text about code, where they are content rather than scaffolding.
    nonisolated static let scaffoldingTags = ["context", "task", "document", "instructions", "examples", "example"]

    /// `nonisolated` so the rule is testable off the main actor, like the
    /// wrapping strip it composes with.
    nonisolated static func strippedScaffolding(_ text: String, input: String) -> String {
        var result = text
        for tag in scaffoldingTags {
            for form in ["<\(tag)>", "</\(tag)>"] {
                // Present in the input means the user wrote it; leave it.
                guard !input.localizedCaseInsensitiveContains(form) else { continue }
                guard result.localizedCaseInsensitiveContains(form) else { continue }
                // Drop the tag and, when it sat alone, the line it occupied, so
                // removing it does not leave a blank gap mid-paragraph.
                result = result.replacingOccurrences(
                    of: "^[ \t]*\(form)[ \t]*\n?",
                    with: "",
                    options: [.regularExpression, .caseInsensitive]
                )
                result = result.replacingOccurrences(
                    of: "\n[ \t]*\(form)[ \t]*(?=\n|$)",
                    with: "",
                    options: [.regularExpression, .caseInsensitive]
                )
                result = result.replacingOccurrences(
                    of: form, with: "", options: [.caseInsensitive]
                )
            }
        }
        // Collapse the runs of blank lines that removal can leave behind.
        result = result.replacingOccurrences(
            of: "\n{3,}", with: "\n\n", options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Models occasionally wrap output in code fences or quotes despite the
    /// prompt forbidding it; strip a single wrapping layer deterministically.
    ///
    /// The marker case now matters on every action, not just Grammar: the
    /// captured text always arrives wrapped, so any model that echoes its input
    /// framing echoes the markers with it.
    nonisolated static func strippedWrapping(_ text: String) -> String {
        var result = text
        if result.hasPrefix(Prompts.textOpenTag), result.hasSuffix(Prompts.textCloseTag) {
            result = String(
                result.dropFirst(Prompts.textOpenTag.count).dropLast(Prompts.textCloseTag.count)
            ).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if result.hasPrefix("```"), result.hasSuffix("```"), result.count > 6 {
            var lines = result.components(separatedBy: "\n")
            if lines.count >= 2 {
                lines.removeFirst()
                if lines.last?.trimmingCharacters(in: .whitespaces) == "```" {
                    lines.removeLast()
                }
                result = lines.joined(separator: "\n")
            }
        }
        for (open, close) in [("\"", "\""), ("\u{201C}", "\u{201D}")] {
            if result.hasPrefix(open), result.hasSuffix(close), result.count > 2 {
                result = String(result.dropFirst().dropLast())
                break
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Search answers are shown as plain text, so ATX headings (`### Yes`)
    /// would print as hashes. Strip only the heading markers; keep the words.
    nonisolated static func strippedSearchChrome(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n").map { line -> String in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("#") else { return line }
            let hashes = trimmed.prefix { $0 == "#" }.count
            guard (1...6).contains(hashes) else { return line }
            let rest = trimmed.dropFirst(hashes)
            guard rest.first?.isWhitespace == true else { return line }
            return rest.trimmingCharacters(in: .whitespaces)
        }
        return lines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Builds a generation-outcome history record. Output text is stored only
    /// here (once per generation); terminal events reference it by digest.
    private static func recordOutcome(
        _ kind: UsageEventKind,
        invocationID: UUID,
        actionID: String,
        attempt: Int,
        ttfbMs: Int? = nil,
        totalMs: Int,
        reasoningChunks: Int,
        output: String? = nil,
        savings: TokenSavings? = nil,
        rationale: String? = nil,
        errorMessage: String? = nil
    ) {
        UsageLog.record {
            UsageEvent(
                invocationID: invocationID,
                kind: kind,
                actionID: actionID,
                attempt: attempt,
                outputText: output,
                outputChars: output?.count,
                outputDigest: output.map { UsageLog.digest($0) },
                inputTokens: savings?.inputTokens,
                outputTokens: savings?.outputTokens,
                savedTokens: savings?.savedTokens,
                rationale: rationale,
                ttfbMs: ttfbMs,
                totalMs: totalMs,
                reasoningChunks: reasoningChunks,
                errorMessage: errorMessage
            )
        }
    }

    private static func milliseconds(_ duration: Duration) -> Int {
        Int(duration.components.seconds) * 1000 +
            Int(duration.components.attoseconds / 1_000_000_000_000_000)
    }

    func replace(text: String) {
        // Grab everything the record needs before dismiss clears it.
        let target = appState.capturedElement
        let vaultNoteID = appState.vaultNoteID
        recordDecision(.replaced, text: text)
        onDismiss()
        if let vaultNoteID {
            VaultStore.shared.applyResult(text, toNoteID: vaultNoteID)
            return
        }
        Task {
            // Let the panel finish resigning key status so the host app is
            // the keystroke recipient again; otherwise a simulated Cmd-V can
            // land on our own (still-ordered-in) panel.
            try? await Task.sleep(for: .milliseconds(250))
            await TextReplace.replaceSelection(with: text, target: target)
        }
    }

    func copy(text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        recordDecision(.copied, text: text)
        appState.copiedFeedback = true
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            appState.copiedFeedback = false
            onDismiss()
        }
    }

    /// Saves the finished result into the vault pin board without dismissing.
    func pin(text: String) {
        let title = String(text.prefix(72))
            .replacingOccurrences(of: "\n", with: " ")
        VaultStore.shared.pinResult(
            title: title,
            body: text,
            actionID: appState.selectedActionID,
            noteID: appState.vaultNoteID
        )
        appState.pinnedFeedback = true
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            appState.pinnedFeedback = false
        }
    }

    func cancel() {
        var resultText: String?
        if case .done(let text) = appState.resultState(for: appState.selectedActionID) {
            resultText = text
        }
        recordDecision(.dismissed, text: resultText)
        lastDescribeInstruction = nil
        onDismiss()
    }

    /// Records a terminal user decision. Must be called BEFORE onDismiss(),
    /// which clears the results, captured text, and savings this reads from.
    /// Carries only a length and digest — the full output was already stored
    /// once by the generation record it refers to.
    ///
    /// This is also where lifetime savings are credited: taking the result is
    /// what makes the saving real, so Replace and Copy count and a dismissal
    /// does not.
    private func recordDecision(_ kind: UsageEventKind, text: String?) {
        let actionID = appState.selectedActionID
        let invocationID = appState.invocationID
        let attempt = attempts[actionID]
        let accepted = kind == .replaced || kind == .copied
        let savings = accepted ? appState.savings[actionID] : nil
        let cumulative = savings.map { SavingsStore.shared.record($0) }
        if let savings {
            logger.notice(
                "accepted \(actionID) via \(kind.rawValue): saved \(savings.savedTokens) est. tokens, lifetime \(cumulative ?? 0)"
            )
        }
        UsageLog.record {
            UsageEvent(
                invocationID: invocationID,
                kind: kind,
                actionID: actionID,
                targetID: appState.selectedTargetID,
                attempt: attempt,
                outputChars: text?.count,
                outputDigest: text.map { UsageLog.digest($0) },
                inputTokens: savings?.inputTokens,
                outputTokens: savings?.outputTokens,
                savedTokens: savings?.savedTokens,
                cumulativeSavedTokens: cumulative,
                hadResult: text != nil
            )
        }
    }
}
