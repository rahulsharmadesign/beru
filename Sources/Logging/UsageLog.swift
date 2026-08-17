import Foundation

/// Main-actor façade over the history writer. Recording is fire-and-forget:
/// events are stamped and handed to a single AsyncStream whose one consumer
/// guarantees they reach disk in the order they happened. Nothing here blocks
/// the UI or the token stream.
@MainActor
enum UsageLog {
    private static var seq = 0
    private static var continuation: AsyncStream<UsageEvent>.Continuation?
    private static var pump: Task<Void, Never>?

    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static func start() {
        guard pump == nil else { return }
        let (stream, continuation) = AsyncStream<UsageEvent>.makeStream(
            bufferingPolicy: .bufferingNewest(1000)
        )
        Self.continuation = continuation
        // Exactly one consumer: a task per event would let the OS interleave
        // writes and scramble the order.
        pump = Task.detached(priority: .utility) {
            for await event in stream {
                await UsageLogWriter.shared.append(event)
            }
        }

        let retention = SettingsStore.shared.historyRetentionDays
        let maxBytes = SettingsStore.shared.historyMaxMegabytes * 1_000_000
        Task.detached(priority: .background) {
            await UsageLogWriter.shared.enforceRetention(retentionDays: retention, maxBytes: maxBytes)
        }
    }

    /// The builder is not run at all when logging is off, so a disabled log
    /// costs nothing beyond a boolean check.
    static func record(_ build: () -> UsageEvent) {
        guard SettingsStore.shared.usageLoggingEnabled else { return }
        seq += 1
        var event = build()
        event.seq = seq
        event.ts = timestampFormatter.string(from: Date())
        event.appVersion = appVersion
        continuation?.yield(event)
    }

    static func digest(_ text: String) -> String {
        UsageLogWriter.digest(text)
    }
}
