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

    /// The string `SettingsStore.modelID(for:)` reports for either role.
    /// Apple's model has no model id of its own — the system owns it.
    static let modelID = "apple-on-device"
}

/// Sampling and output caps for the on-device model, kept separate from the
/// streaming code so the mapping is unit-testable without a model.
enum AppleGeneration {
    /// Deterministic or lightly varied. Beru's own tuning decides which.
    enum Sampling: Equatable, Sendable {
        case deterministic
        case temperature(Double)
    }

    /// Grammar's three-in-one call needs variation *between* its rows, and
    /// Apple's 3B-class model collapses clearer/tighter into near-verbatim
    /// echoes under greedy decoding (measured with Beru's exact prompt:
    /// identical triple on clean input). At temperature 0.7 the same prompt
    /// yields genuinely different rows with corrections intact — also
    /// measured, on error-filled input — so Grammar alone opts out of greedy
    /// on this provider. Every other role keeps Beru's shared tuning.
    static let grammarTemperature = 0.7

    static func sampling(for role: ModelRole, actionID: String) -> Sampling {
        if role == .grammar { return .temperature(grammarTemperature) }
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