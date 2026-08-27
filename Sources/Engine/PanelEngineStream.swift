import Foundation
import os

/// One request, fully resolved. `start` decides all of this up front; the stream
/// only reads it. They used to share a 405-line function and a dozen captured
/// locals, which is why the split needed a value to hand across.
struct PanelRequest {
    let actionID: String
    let actionName: String
    let role: ModelRole
    let provider: LLMProvider
    let systemPrompt: String
    let userMessage: String
    let capturedText: String
    /// What the user typed on this run, held so the recorded turn reflects the
    /// request rather than whatever the field says when the stream finishes.
    let threadInstruction: String
    let hostBundleID: String?
    let invocationID: UUID
    let attempt: Int
    let generation: Int
    let explainsChanges: Bool
    let isQuickSearch: Bool
}

// Running a request: consuming the stream, coalescing publishes, cleaning the
// output, and recording what happened.

extension PanelEngine {
    func runStream(_ request: PanelRequest) {
        let task = Task { [weak self] in
            self?.onStreamingStarted?()
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
                let stream = request.provider.stream(
                    system: request.systemPrompt,
                    user: request.userMessage,
                    role: request.role,
                    expectsRationale: request.explainsChanges
                )
                for try await chunk in stream {
                    guard case .content(let text) = chunk else {
                        // Reasoning must never reach the document. Surface it
                        // as a state so a thinking model doesn't look hung.
                        reasoningChunks += 1
                        if accumulated.isEmpty, reasoningChunks == 1 {
                            self.publish(.thinking, for: request.actionID, generation: request.generation)
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
                        engineLogger.notice("ttfb for \(request.actionID): \(Self.milliseconds(now - requestStart)) ms")
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
                        self.publish(.streaming(visible), for: request.actionID, generation: request.generation)
                    }
                }

                // A cancelled byte stream finishes cleanly rather than
                // throwing — the SSE reader swallows the error by design — so
                // "no content" here means superseded just as often as it means
                // the model said nothing. Check before interpreting it as a
                // failure, or every regenerate and every action switch logs a
                // phantom error and flashes one into the panel.
                guard !Task.isCancelled, self.isLive(request.generation, for: request.actionID) else {
                    engineLogger.notice("stream superseded for \(request.actionID)")
                    Self.recordOutcome(
                        .generationCancelled, invocationID: request.invocationID, actionID: request.actionID,
                        attempt: request.attempt, totalMs: Self.milliseconds(clock.now - requestStart),
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
                    input: request.capturedText
                )
                let totalMs = Self.milliseconds(clock.now - requestStart)
                let ttfbMs = firstTokenAt.map { Self.milliseconds($0 - requestStart) }
                engineLogger.notice("stream done for \(request.actionID), length = \(final.count), total = \(totalMs) ms, reasoning chunks discarded = \(reasoningChunks)")
                if final.isEmpty {
                    self.publish(
                        .error("The model returned an empty response — try Regenerate"),
                        for: request.actionID, generation: request.generation
                    )
                    Self.recordOutcome(
                        .generationFailed, invocationID: request.invocationID, actionID: request.actionID,
                        attempt: request.attempt, totalMs: totalMs, reasoningChunks: reasoningChunks,
                        errorMessage: "empty response"
                    )
                } else {
                    let savings = TokenSavings(input: request.capturedText, output: final)
                    self.appState.savings[request.actionID] = savings
                    // "Nothing needed fixing" and "the tool did nothing" look
                    // identical on screen, and the second reading is what makes
                    // people hit Regenerate until the model invents changes.
                    if final == request.capturedText.trimmingCharacters(in: .whitespacesAndNewlines) {
                        self.appState.cleanNotices.insert(request.actionID)
                    } else {
                        self.appState.cleanNotices.remove(request.actionID)
                    }
                    if let rationale, self.isLive(request.generation, for: request.actionID) {
                        self.appState.rationales[request.actionID] = rationale
                    }
                    if request.actionID == EnhancementAction.replyID,
                       self.isLive(request.generation, for: request.actionID) {
                        let policy = ReplyLanguagePolicy.analyze(request.capturedText)
                        let parsed = ReplySuggestions.parse(final)
                        self.appState.replySuggestions = parsed
                        if ReplyLanguagePolicy.repliesViolatePolicy(parsed, input: policy) {
                            self.appState.replyScriptNotices.insert(request.actionID)
                        } else {
                            self.appState.replyScriptNotices.remove(request.actionID)
                        }
                        if let first = parsed.first,
                           !parsed.contains(where: { $0.tone == self.appState.selectedReplyTone }) {
                            self.appState.selectedReplyTone = first.tone
                        }
                    }
                    self.publish(.done(final), for: request.actionID, generation: request.generation)
                    // Recorded only for a result that actually reached the
                    // panel. A superseded request.generation never became something the
                    // user saw, so it is not part of the conversation.
                    if self.isLive(request.generation, for: request.actionID) {
                        SessionThread.shared.record(
                            actionID: request.actionID,
                            actionName: request.actionName,
                            instruction: request.threadInstruction,
                            input: request.capturedText,
                            output: final,
                            bundleID: request.hostBundleID
                        )
                    }
                    if request.isQuickSearch, self.isLive(request.generation, for: request.actionID) {
                        self.appState.describeInstruction = ""
                    }
                    Self.recordOutcome(
                        .generationFinished, invocationID: request.invocationID, actionID: request.actionID,
                        attempt: request.attempt, ttfbMs: ttfbMs, totalMs: totalMs,
                        reasoningChunks: reasoningChunks, output: final, savings: savings,
                        rationale: rationale
                    )
                    // Every action gets a diff, not just Grammar: seeing what a
                    // tone rewrite actually touched is the point of the feature.
                    await self.computeDiff(actionID: request.actionID, original: request.capturedText, revised: final)
                }
            } catch is CancellationError {
                engineLogger.notice("stream cancelled for \(request.actionID)")
                Self.recordOutcome(
                    .generationCancelled, invocationID: request.invocationID, actionID: request.actionID,
                    attempt: request.attempt, totalMs: Self.milliseconds(clock.now - requestStart),
                    reasoningChunks: reasoningChunks, output: accumulated.isEmpty ? nil : accumulated
                )
            } catch let error as ProviderError {
                if case .cancelled = error { return }
                engineLogger.notice("stream failed for \(request.actionID): \(error.userMessage)")
                self.publish(.error(error.userMessage), for: request.actionID, generation: request.generation)
                self.appState.errorProviders[request.actionID] = SettingsStore.shared.activeProvider
                if error.needsModelSetup {
                    self.appState.errorNeedsModelSetup.insert(request.actionID)
                }
                Self.recordOutcome(
                    .generationFailed, invocationID: request.invocationID, actionID: request.actionID,
                    attempt: request.attempt, totalMs: Self.milliseconds(clock.now - requestStart),
                    reasoningChunks: reasoningChunks, errorMessage: error.userMessage
                )
            } catch {
                engineLogger.notice("stream failed for \(request.actionID): \(error.localizedDescription)")
                self.publish(.error(error.localizedDescription), for: request.actionID, generation: request.generation)
                self.appState.errorProviders[request.actionID] = SettingsStore.shared.activeProvider
                // localizedDescription only: NSError.userInfo can carry the
                // base URL, which may embed credentials.
                Self.recordOutcome(
                    .generationFailed, invocationID: request.invocationID, actionID: request.actionID,
                    attempt: request.attempt, totalMs: Self.milliseconds(clock.now - requestStart),
                    reasoningChunks: reasoningChunks, errorMessage: error.localizedDescription
                )
            }
        }
        appState.registerStreamTask(task, for: request.actionID)
    }
}
