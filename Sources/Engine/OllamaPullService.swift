import Foundation
import Observation

/// Process-lived Ollama pull so Install keeps downloading after leaving Models.
@MainActor
@Observable
final class OllamaPullService {
    static let shared = OllamaPullService()

    private(set) var pulling: String?
    private(set) var progress: OllamaAdmin.PullProgress?
    private(set) var error: String?

    private var pullTask: Task<Void, Never>?
    private var generation = 0
    private var lastProgressPublish: ContinuousClock.Instant?
    private let powerActivity = PowerActivity()

    private init() {}

    func start(name: String, baseURL: String) {
        pullTask?.cancel()
        generation += 1
        let gen = generation
        error = nil
        pulling = name
        progress = nil
        lastProgressPublish = nil
        let admin = OllamaAdmin(baseURL: baseURL)
        powerActivity.pullBegan()
        pullTask = Task { [weak self] in
            guard let self else { return }
            defer { self.complete(generation: gen) }
            do {
                for try await progress in admin.pull(model: name) {
                    if Task.isCancelled { return }
                    self.publishProgress(progress)
                }
                if Task.isCancelled { return }
                self.applyModelIfDefaults(name)
            } catch is CancellationError {
                return
            } catch {
                if !Task.isCancelled {
                    self.error = error.localizedDescription
                }
            }
        }
    }

    /// Ollama emits many NDJSON lines per second; publishing each one re-lays
    /// out the Models page. Cap UI updates so Settings stays responsive.
    private func publishProgress(_ progress: OllamaAdmin.PullProgress) {
        if progress.isDone {
            self.progress = progress
            lastProgressPublish = nil
            return
        }
        let now = ContinuousClock.now
        if let last = lastProgressPublish, now - last < .milliseconds(250) {
            return
        }
        lastProgressPublish = now
        self.progress = progress
    }

    func cancel() {
        guard pulling != nil || pullTask != nil else { return }
        pullTask?.cancel()
        generation += 1
        pulling = nil
        progress = nil
        pullTask = nil
    }

    private func complete(generation gen: Int) {
        powerActivity.pullEnded()
        guard generation == gen else { return }
        pulling = nil
        progress = nil
        pullTask = nil
    }

    /// If the user is still on the shipped defaults, assign the model they just
    /// installed so the widget can use it without a second trip to Settings.
    private func applyModelIfDefaults(_ name: String) {
        let settings = SettingsStore.shared
        if settings.ollamaEnhanceModel == RecommendedOllamaModel.defaultID {
            settings.ollamaEnhanceModel = name
        }
        if settings.ollamaGrammarModel == RecommendedOllamaModel.defaultID {
            settings.ollamaGrammarModel = name
        }
    }
}
