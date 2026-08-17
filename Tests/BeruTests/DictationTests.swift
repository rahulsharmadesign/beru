import KeyboardShortcuts
import AVFoundation
import Speech
import XCTest
@testable import Beru

/// Dictation's correctness is mostly a privacy property, so that is what these
/// mainly test.
final class DictationTests: XCTestCase {
    // MARK: - The privacy guarantee

    /// The whole feature rests on this one flag.
    ///
    /// `SFSpeechAudioBufferRecognitionRequest` defaults to server-based
    /// recognition, which uploads the audio to Apple. The transcript comes back
    /// correct either way, so nothing in the app would ever look wrong — this
    /// test is the only thing standing between a working feature and a silent
    /// breach of "nothing about the user's activity may ever leave the device".
    func testEveryRequestIsForcedOnDevice() {
        for _ in 0..<3 {
            XCTAssertTrue(
                DictationService.makeRequest().requiresOnDeviceRecognition,
                "a request escaped without on-device recognition forced"
            )
        }
    }

    func testRequestsPartialResultsSoTheFieldFillsAsYouSpeak() {
        XCTAssertTrue(DictationService.makeRequest().shouldReportPartialResults)
    }

    /// Dictated punctuation is what makes an instruction usable without editing
    /// it afterwards.
    func testRequestAddsPunctuation() {
        XCTAssertTrue(DictationService.makeRequest().addsPunctuation)
    }

    // MARK: - Availability rules

    private func resolve(
        mic: AVAuthorizationStatus = .authorized,
        speech: SFSpeechRecognizerAuthorizationStatus = .authorized,
        hasRecognizer: Bool = true,
        onDevice: Bool = true
    ) -> DictationService.Availability {
        DictationService.resolveAvailability(
            microphone: mic,
            speech: speech,
            hasRecognizer: hasRecognizer,
            supportsOnDevice: onDevice
        )
    }

    func testEverythingGrantedAndLocalIsReady() {
        XCTAssertEqual(resolve(), .ready)
    }

    /// The refusal that keeps the promise. Granted permissions plus no local
    /// language must never resolve to ready, because ready means recording, and
    /// recording without on-device support is the failure this is all built to
    /// prevent.
    func testGrantedButNotLocalRefuses() {
        XCTAssertEqual(resolve(onDevice: false), .onDeviceUnavailable)
        XCTAssertNotEqual(resolve(onDevice: false), .ready)
    }

    func testDeniedPermissionsAreReportedSeparately() {
        XCTAssertEqual(resolve(mic: .denied), .microphoneDenied)
        XCTAssertEqual(resolve(mic: .restricted), .microphoneDenied)
        XCTAssertEqual(resolve(speech: .denied), .speechDenied)
        XCTAssertEqual(resolve(speech: .restricted), .speechDenied)
    }

    func testUndecidedPermissionsAskRatherThanFail() {
        XCTAssertEqual(resolve(mic: .notDetermined), .needsPermission)
        XCTAssertEqual(resolve(speech: .notDetermined), .needsPermission)
    }

    /// A denied microphone must not be reported as a missing language. Sending
    /// someone to Keyboard › Dictation when the real problem is Privacy ›
    /// Microphone wastes their time on the wrong settings pane.
    func testADeniedMicrophoneOutranksAMissingLanguage() {
        XCTAssertEqual(resolve(mic: .denied, onDevice: false), .microphoneDenied)
        XCTAssertEqual(resolve(speech: .denied, onDevice: false), .speechDenied)
    }

    func testNoRecognizerOutranksEverything() {
        XCTAssertEqual(
            resolve(mic: .denied, speech: .denied, hasRecognizer: false, onDevice: false),
            .noRecognizer
        )
    }

    // MARK: - What the user is told

    /// Every failure names the setting that fixes it. "Unavailable" on its own
    /// is the kind of message that produces a bug report instead of a fix.
    func testEveryUnavailableStateNamesItsFix() {
        let cases: [DictationService.Availability] = [
            .needsPermission, .microphoneDenied, .speechDenied, .onDeviceUnavailable, .noRecognizer
        ]
        for state in cases {
            guard let message = state.message else {
                return XCTFail("\(state) has no message")
            }
            XCTAssertFalse(message.isEmpty)
            XCTAssertTrue(
                message.contains("System Settings") || message.contains("permission") || message.contains("macOS"),
                "\(state) does not tell the user where to go: \(message)"
            )
        }
        XCTAssertNil(DictationService.Availability.ready.message)
    }

    /// The on-device refusal is the one place the promise is explained, so it
    /// has to point at Dictation rather than the Privacy pane, and say why.
    func testTheOnDeviceRefusalPointsAtTheDictationSetting() {
        let message = DictationService.Availability.onDeviceUnavailable.message ?? ""
        XCTAssertTrue(message.contains("Dictation"))
        XCTAssertTrue(message.lowercased().contains("not send"))
    }

    func testOnlyReadyIsReady() {
        XCTAssertTrue(DictationService.Availability.ready.isReady)
        for state: DictationService.Availability in
            [.needsPermission, .microphoneDenied, .speechDenied, .onDeviceUnavailable, .noRecognizer] {
            XCTAssertFalse(state.isReady, "\(state) must not be treated as ready")
        }
    }

    // MARK: - Dictate shortcut, scoped to the panel

    /// Space is the default hold key and is also an ordinary character in
    /// "Describe your change". If a bare Space were always swallowed, the
    /// instruction field could not type a space at all — so it only dictates
    /// while there is nothing to type a space into.
    func testBareSpaceDictatesOnlyWhileTheFieldIsEmpty() {
        let space = KeyboardShortcuts.Shortcut(.space)
        XCTAssertTrue(PushToTalkMonitor.shouldStartDictation(hasText: false, shortcut: space))
        XCTAssertFalse(
            PushToTalkMonitor.shouldStartDictation(hasText: true, shortcut: space),
            "a bare Space must reach the field once there is text to type into"
        )
    }

    /// A shortcut with a modifier is not a character anyone types, so it always
    /// dictates and never has to yield to the field.
    func testAModifiedShortcutAlwaysDictates() {
        for shortcut in [
            KeyboardShortcuts.Shortcut(.space, modifiers: [.option]),
            KeyboardShortcuts.Shortcut(.d, modifiers: [.command, .shift]),
            KeyboardShortcuts.Shortcut(.l, modifiers: [.control, .option, .command])
        ] {
            XCTAssertTrue(PushToTalkMonitor.shouldStartDictation(hasText: false, shortcut: shortcut))
            XCTAssertTrue(
                PushToTalkMonitor.shouldStartDictation(hasText: true, shortcut: shortcut),
                "\(shortcut) carries a modifier and should not defer to the field"
            )
        }
    }

    /// A bare letter has the same problem as Space and gets the same treatment,
    /// so the rule is about modifiers rather than about Space specifically.
    func testAnyUnmodifiedKeyDefersToTypedText() {
        let bareKey = KeyboardShortcuts.Shortcut(.d)
        XCTAssertTrue(PushToTalkMonitor.shouldStartDictation(hasText: false, shortcut: bareKey))
        XCTAssertFalse(PushToTalkMonitor.shouldStartDictation(hasText: true, shortcut: bareKey))
    }

    /// Default is Control-Option-Command-L, stored without a global registration
    /// so a user who later picks a bare character cannot steal it system-wide.
    func testTheDefaultDictateShortcutIsControlOptionCommandL() {
        let shortcut = KeyboardShortcuts.getShortcut(for: .dictateToBeru)
        XCTAssertEqual(shortcut?.carbonKeyCode, KeyboardShortcuts.Key.l.rawValue)
        XCTAssertEqual(shortcut?.modifiers, [.control, .option, .command])
    }

    func testJoinTranscriptDoesNotDoubleTheCommittedPrefix() {
        XCTAssertEqual(DictationService.joinTranscript(committed: "", live: "hello"), "hello")
        XCTAssertEqual(DictationService.joinTranscript(committed: "hello", live: "world"), "hello world")
        XCTAssertEqual(
            DictationService.joinTranscript(committed: "hello", live: "hello world"),
            "hello world"
        )
    }

    // MARK: - Not leaving the microphone open

    /// A menu bar app runs all day, so an unbounded recording is the worst
    /// failure mode available. The cap has to be short enough to matter and
    /// long enough to dictate a real instruction.
    func testRecordingIsCappedToSomethingSane() {
        XCTAssertGreaterThanOrEqual(DictationService.maximumDuration, .seconds(20))
        XCTAssertLessThanOrEqual(DictationService.maximumDuration, .seconds(120))
    }

    /// Starting is refused unless availability says ready, so a denied or
    /// server-only machine cannot open the microphone at all.
    @MainActor
    func testStartRefusesWhenNotAvailable() throws {
        let service = DictationService.shared
        service.refreshAvailability()
        guard !service.availability.isReady else {
            throw XCTSkip("This machine can dictate; the refusal path needs an unavailable one.")
        }
        XCTAssertFalse(service.start())
        XCTAssertFalse(service.isRecording)
    }
}
