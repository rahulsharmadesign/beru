import AppKit
import AVFoundation
import Foundation
import Observation
import Speech
import os.log

private let logger = Logger(subsystem: "com.rahul.beru", category: "dictation")

/// Microphone capture and speech-to-text, on this Mac only.
///
/// **`SFSpeechRecognizer` sends audio to Apple's servers by default.** That is
/// the single most important thing about this file. Beru promises that
/// nothing about the user's activity leaves the device, and a recogniser left on
/// its defaults would break that promise invisibly — the transcription comes
/// back correct either way, so nothing in the UI would ever look wrong.
///
/// So `requiresOnDeviceRecognition` is set on every request, and recording is
/// refused outright when the device cannot do it locally. There is no server
/// fallback and no opt-in to add one later without deleting this comment.
@MainActor
@Observable
final class DictationService {
    static let shared = DictationService()

    /// Why the microphone cannot be used, or `.ready`.
    enum Availability: Equatable {
        case ready
        /// Neither permission asked for yet.
        case needsPermission
        case microphoneDenied
        case speechDenied
        /// The recogniser exists but cannot run locally, usually because the
        /// language has not been downloaded.
        case onDeviceUnavailable
        /// No recogniser for this locale at all.
        case noRecognizer

        var isReady: Bool { self == .ready }

        /// Names the setting that fixes it. "Speech recognition unavailable"
        /// tells someone nothing they can act on.
        var message: String? {
            switch self {
            case .ready:
                return nil
            case .needsPermission:
                return "Beru needs permission to use the microphone."
            case .microphoneDenied:
                return "Microphone access is off. Turn Beru on in System Settings › Privacy & Security › Microphone."
            case .speechDenied:
                return "Speech recognition is off. Turn Beru on in System Settings › Privacy & Security › Speech Recognition."
            case .onDeviceUnavailable:
                return "Dictation needs an on-device language. Add one in System Settings › Keyboard › Dictation — Beru will not send your voice to Apple."
            case .noRecognizer:
                return "macOS has no speech recogniser for this language."
            }
        }

        /// Opens the System Settings pane that actually fixes this state.
        func openSystemSettings() {
            switch self {
            case .speechDenied:
                Permissions.openSpeechRecognitionSettings()
            case .onDeviceUnavailable, .noRecognizer:
                Permissions.openKeyboardDictationSettings()
            default:
                Permissions.openMicrophoneSettings()
            }
        }
    }

    /// Longest single recording. A menu bar app runs all day, so the worst
    /// outcome here is a microphone left open silently; the cap bounds that even
    /// if a key-up is missed entirely.
    static let maximumDuration: Duration = .seconds(60)

    private(set) var isRecording = false
    /// What has been heard so far. Replaced by the final text when recording
    /// stops, and cleared when the next recording starts.
    private(set) var partialText = ""
    private(set) var availability: Availability = .needsPermission

    /// Called with each revision of the transcript, partial or final.
    var onText: ((String) -> Void)?

    private var recognizer: SFSpeechRecognizer?
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var capTask: Task<Void, Never>?
    /// Audio tap writes here so a restarted recognition request still receives buffers.
    private let sink = AudioSink()
    /// Text already finalized in this session. Live partials are shown on top.
    private var committedText = ""
    /// False once the user (or the duration cap) asks us to stop, so an in-flight
    /// `isFinal` callback cannot restart listening.
    private var shouldKeepListening = false
    /// Ignores callbacks from a recognition task we already replaced.
    private var recognitionGeneration = 0

    private final class AudioSink: @unchecked Sendable {
        private let lock = NSLock()
        private var request: SFSpeechAudioBufferRecognitionRequest?

        func setRequest(_ request: SFSpeechAudioBufferRecognitionRequest?) {
            lock.lock()
            self.request = request
            lock.unlock()
        }

        func append(_ buffer: AVAudioPCMBuffer) {
            lock.lock()
            request?.append(buffer)
            lock.unlock()
        }
    }

    private init() {
        recognizer = Self.preferredRecognizer()
        refreshAvailability()
    }

    /// Prefer a recognizer that can stay on-device. The no-argument
    /// `SFSpeechRecognizer()` follows the system locale, which is often one
    /// without a downloaded language pack — that looked like a dead mic.
    nonisolated static func preferredRecognizer() -> SFSpeechRecognizer? {
        var seen = Set<String>()
        var candidates: [SFSpeechRecognizer] = []
        var locales = [Locale.current, Locale(identifier: "en-US"), Locale(identifier: "en-GB")]
        if let defaultLocale = SFSpeechRecognizer()?.locale {
            locales.insert(defaultLocale, at: 0)
        }
        for locale in locales {
            guard seen.insert(locale.identifier).inserted,
                  let recognizer = SFSpeechRecognizer(locale: locale) else { continue }
            candidates.append(recognizer)
        }
        return candidates.first(where: { $0.isAvailable && $0.supportsOnDeviceRecognition })
            ?? candidates.first(where: { $0.isAvailable })
            ?? candidates.first
    }

    // MARK: - Availability

    /// Pure decision table, so the rules can be tested without a microphone,
    /// a recogniser, or a granted permission.
    ///
    /// Order matters: the on-device check comes last because it is only
    /// meaningful once both permissions are granted, and reporting it first
    /// would send someone to the Dictation settings when the real problem is a
    /// denied microphone.
    nonisolated static func resolveAvailability(
        microphone: AVAuthorizationStatus,
        speech: SFSpeechRecognizerAuthorizationStatus,
        hasRecognizer: Bool,
        supportsOnDevice: Bool
    ) -> Availability {
        guard hasRecognizer else { return .noRecognizer }
        if microphone == .denied || microphone == .restricted { return .microphoneDenied }
        if speech == .denied || speech == .restricted { return .speechDenied }
        if microphone == .notDetermined || speech == .notDetermined { return .needsPermission }
        guard supportsOnDevice else { return .onDeviceUnavailable }
        return .ready
    }

    func refreshAvailability() {
        if recognizer == nil || recognizer?.supportsOnDeviceRecognition != true {
            recognizer = Self.preferredRecognizer()
        }
        availability = Self.resolveAvailability(
            microphone: AVCaptureDevice.authorizationStatus(for: .audio),
            speech: SFSpeechRecognizer.authorizationStatus(),
            hasRecognizer: recognizer != nil,
            supportsOnDevice: recognizer?.supportsOnDeviceRecognition ?? false
        )
    }

    /// Asks for both permissions, microphone first.
    ///
    /// Activates the app first: Beru is an accessory process, and TCC dialogs
    /// do not appear in front of a non-activating panel.
    func requestPermissions() async {
        // Accessory processes often never surface TCC dialogs. Become a regular
        // app first so the prompt and System Settings can come to the front.
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        }
        // Requesting speech without NSSpeechRecognitionUsageDescription
        // terminates the process. No dialog, no log — it looks like a crash
        // the moment microphone access is granted and this method continues.
        let speechUsage = Bundle.main.object(forInfoDictionaryKey: "NSSpeechRecognitionUsageDescription") as? String
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined,
           let speechUsage, !speechUsage.isEmpty {
            await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { _ in continuation.resume() }
            }
        }
        refreshAvailability()
    }

    // MARK: - Recording

    /// Builds the recognition request.
    ///
    /// Factored out and `nonisolated` for one reason: so a test can assert
    /// `requiresOnDeviceRecognition` is set without needing audio hardware. That
    /// flag is the entire privacy guarantee.
    nonisolated static func makeRequest() -> SFSpeechAudioBufferRecognitionRequest {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        // Punctuation from speech ("comma", "full stop") is what makes a
        // dictated instruction usable without editing it afterwards.
        request.addsPunctuation = true
        return request
    }

    @discardableResult
    func start() -> Bool {
        guard !isRecording else { return true }
        refreshAvailability()
        guard availability.isReady, let recognizer else {
            logger.notice("dictation refused: not available")
            return false
        }

        committedText = ""
        partialText = ""
        let request = Self.makeRequest()
        self.request = request
        sink.setRequest(request)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        // A zero sample rate means no usable input device — installing a tap
        // with that format throws inside AVAudioEngine.
        guard format.sampleRate > 0 else {
            logger.notice("dictation refused: input device has no usable format")
            cleanUp()
            return false
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [sink] buffer, _ in
            sink.append(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            logger.notice("dictation could not start the audio engine")
            cleanUp()
            return false
        }

        shouldKeepListening = true
        beginRecognitionTask(with: recognizer, request: request)
        isRecording = true
        startCap()
        return true
    }

    func stop() {
        shouldKeepListening = false
        guard isRecording || request != nil else { return }
        cleanUp()
    }

    /// Stops recording and discards whatever was heard, for when the panel is
    /// dismissed mid-sentence and the text has nowhere to go.
    func cancel() {
        shouldKeepListening = false
        let hadText = !partialText.isEmpty
        cleanUp()
        if hadText { partialText = "" }
    }

    /// On-device recognition finalizes after a pause. Stopping there cut the
    /// session short ("partially working"). Keep the mic open and start a new
    /// task for the next utterance.
    private func beginRecognitionTask(
        with recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest
    ) {
        task?.cancel()
        recognitionGeneration += 1
        let generation = recognitionGeneration
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self, generation == self.recognitionGeneration else { return }
                self.handleRecognition(result: result, error: error)
            }
        }
    }

    private func handleRecognition(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result {
            let piece = result.bestTranscription.formattedString
            if result.isFinal {
                committedText = Self.joinTranscript(committed: committedText, live: piece)
                partialText = committedText
            } else {
                partialText = Self.joinTranscript(committed: committedText, live: piece)
            }
            onText?(partialText)
        }

        let utteranceEnded = result?.isFinal == true || error != nil
        guard utteranceEnded, shouldKeepListening, let recognizer else { return }
        let next = Self.makeRequest()
        self.request = next
        sink.setRequest(next)
        beginRecognitionTask(with: recognizer, request: next)
    }

    /// Partials are the current utterance; finals are committed. Some recognizers
    /// repeat the committed prefix inside the live string — don't double it.
    nonisolated static func joinTranscript(committed: String, live: String) -> String {
        let committed = committed.trimmingCharacters(in: .whitespacesAndNewlines)
        let live = live.trimmingCharacters(in: .whitespacesAndNewlines)
        if committed.isEmpty { return live }
        if live.isEmpty { return committed }
        if live.hasPrefix(committed) { return live }
        return committed + " " + live
    }

    private func cleanUp() {
        shouldKeepListening = false
        capTask?.cancel()
        capTask = nil
        if engine.isRunning {
            engine.stop()
        }
        // Always remove the tap, even if the engine never started: a tap left
        // installed makes the next start() throw.
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        request = nil
        sink.setRequest(nil)
        task?.cancel()
        task = nil
        recognitionGeneration += 1
        isRecording = false
        committedText = ""
    }

    /// Belt and braces against a missed key-up. `onKeyUp` is a global monitor
    /// and reliable, but a hung release must not leave the microphone live for
    /// the rest of the day.
    private func startCap() {
        capTask?.cancel()
        capTask = Task { [weak self] in
            try? await Task.sleep(for: Self.maximumDuration)
            guard !Task.isCancelled else { return }
            logger.notice("dictation hit its duration cap and stopped itself")
            self?.stop()
        }
    }

    // No `deinit` cleanup. It cannot touch main-actor state under strict
    // concurrency, and it would never run regardless — this is a singleton.
    // Nothing is leaked by its absence: the cap task holds `self` weakly, so a
    // deallocated service simply stops responding to it.
}
