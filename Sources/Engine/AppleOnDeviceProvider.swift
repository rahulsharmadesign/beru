import Foundation
import FoundationModels

/// Beru's provider over Apple's on-device model (Foundation Models framework).
///
/// Nothing leaves the Mac, there is no key, no base URL, no model id, and no
/// download — which is what makes it a candidate for Beru's *default* provider.
/// Everything provider-specific is confined to this file; the caller sees the
/// same `LLMProvider` it already has.
///
/// Concurrency notes (Beru builds with `SWIFT_STRICT_CONCURRENCY: complete`):
/// - `LanguageModelSession` is a non-Sendable class, so it is created *inside*
///   the streaming task and never stored. That is why this type is a stateless
///   struct and safe to hand across actors.
/// - `SystemLanguageModel.default` is Sendable, so reading availability from any
///   context is fine.
struct AppleOnDeviceProvider: LLMProvider {

    // MARK: - Streaming

    func stream(
        system: String,
        user: String,
        role: ModelRole,
        expectsRationale: Bool,
        actionID: String
    ) -> AsyncThrowingStream<StreamChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let state = AppleModelState.current()
                    guard state.isReady else { throw state.providerError }

                    let budget = PromptBudget.onDevice(
                        system: system,
                        role: role,
                        expectsRationale: expectsRationale,
                        input: user
                    )
                    let clamp = budget.clamp(user)

                    let session = LanguageModelSession(instructions: system)
                    let options = AppleGeneration.options(
                        for: role,
                        actionID: actionID,
                        maxOutputTokens: budget.outputTokens
                    )
                    let stream = session.streamResponse(to: clamp.text, options: options)
                    var accumulator = DeltaAccumulator()
                    for try await snapshot in stream {
                        if Task.isCancelled { break }
                        // Snapshots are cumulative; Beru appends deltas.
                        if let delta = accumulator.delta(forCumulative: snapshot.content) {
                            continuation.yield(.content(delta))
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: ProviderError.cancelled)
                } catch {
                    continuation.finish(throwing: AppleModelState.providerError(for: error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Availability

    /// Availability, not a network probe: there is nothing to reach.
    func testConnection() async -> Result<Void, ProviderError> {
        let state = AppleModelState.current()
        return state.isReady ? .success(()) : .failure(state.providerError)
    }

    // MARK: - Warm-up

    /// `prewarm` is the whole point here: the first real request otherwise pays
    /// the on-device model load, which is seconds — visible as a stalled panel.
    func warmUp(role: ModelRole) async {
        let state = AppleModelState.current()
        guard state.isReady else { return }
        let system = role == .grammar ? Prompts.grammar : Prompts.enhance
        let session = LanguageModelSession(instructions: system)
        session.prewarm()
    }

    // MARK: - Identity for usage attribution

    /// The concrete string `SettingsStore.modelID(for:)` reports for either
    /// role. Apple's model has no model id to report — the system owns it —
    /// so this is the constant Beru's usage history attributes to it.
    static let modelID = "apple-on-device"

    // MARK: - Real token counts

    /// Apple's tokenizer, for the places Beru currently guesses (the token pill,
    /// and calibrating `TokenEstimate`). Lives on the model (macOS 26.4+), not
    /// the session — which is why this is a separate static instead of a session
    /// method. Returns nil when the model is not usable, so callers fall back
    /// to the estimate.
    @available(macOS 26.4, *)
    static func measuredTokens(for text: String) async -> Int? {
        guard AppleModelState.isConfigured else { return nil }
        return try? await SystemLanguageModel.default.tokenCount(for: text)
    }

    /// Version-safe entry for call sites that must compile on macOS 26.0–26.3:
    /// first tries the real tokenizer, falls back to the estimate.
    static func measuredTokensIfAvailable(for text: String) async -> Int? {
        if #available(macOS 26.4, *) {
            return await measuredTokens(for: text)
        }
        return TokenEstimate.tokens(in: text)
    }
}

/// Sampling and output caps for the on-device model, kept separate from the
/// streaming code so the mapping is unit-testable without a model.
enum AppleGeneration {
    /// Deterministic or lightly varied. Beru's own tuning decides which.
    enum Sampling: Equatable, Sendable {
        case deterministic
        case temperature(Double)
    }

    static func sampling(for role: ModelRole, actionID: String) -> Sampling {
        let temperature = ProviderTuning.temperature(for: role, actionID: actionID)
        // Temperature 0 means "must not vary": Grammar has exactly one right
        // answer, so it gets greedy decoding rather than temperature 0 — Apple
        // documents greedy as the deterministic mode.
        return temperature == 0 ? .deterministic : .temperature(temperature)
    }

    static func options(
        for role: ModelRole,
        actionID: String,
        maxOutputTokens: Int
    ) -> GenerationOptions {
        switch sampling(for: role, actionID: actionID) {
        case .deterministic:
            return GenerationOptions(sampling: .greedy, maximumResponseTokens: maxOutputTokens)
        case .temperature(let value):
            return GenerationOptions(temperature: value, maximumResponseTokens: maxOutputTokens)
        }
    }
}