import Foundation
import FoundationModels

/// What the on-device Apple model can actually do on *this* Mac.
///
/// The three failure modes are not interchangeable, and Beru's UI has to say
/// which one it is: an Intel Mac will never be eligible, an eligible Mac may
/// only have Apple Intelligence switched off, and a fresh enable is
/// `modelNotReady` until Apple's assets finish downloading.
///
/// Pure mapping from the framework's availability so it is unit-testable on a
/// Mac that has no Apple Intelligence at all.
enum AppleModelState: Equatable, Sendable {
    case ready
    case deviceNotEligible
    case intelligenceNotEnabled
    case modelNotReady

    var isReady: Bool { self == .ready }

    /// One line for a Settings row or the panel's empty state.
    var summary: String {
        switch self {
        case .ready:
            return "Apple on-device — nothing to install, nothing leaves this Mac"
        case .deviceNotEligible:
            return "This Mac doesn't support Apple Intelligence"
        case .intelligenceNotEnabled:
            return "Turn on Apple Intelligence in System Settings to use the on-device model"
        case .modelNotReady:
            return "Apple Intelligence is still getting ready — its model is downloading"
        }
    }

    /// Short badge label, Haze-metapill sized.
    var badge: String {
        switch self {
        case .ready: return "Ready"
        case .deviceNotEligible: return "Unsupported"
        case .intelligenceNotEnabled: return "Off"
        case .modelNotReady: return "Preparing"
        }
    }

    static func state(from availability: SystemLanguageModel.Availability) -> AppleModelState {
        switch availability {
        case .available:
            return .ready
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return .deviceNotEligible
            case .appleIntelligenceNotEnabled: return .intelligenceNotEnabled
            case .modelNotReady: return .modelNotReady
            @unknown default: return .deviceNotEligible
            }
        }
    }

    /// Live read. Local providers get this from a settings value; here the
    /// framework owns the answer.
    static func current() -> AppleModelState {
        state(from: SystemLanguageModel.default.availability)
    }

    /// Only `.ready` counts as configured. Beru's `isConfigured(.apple)` must
    /// use this so the panel can never open on a provider that will fail.
    static var isConfigured: Bool { current().isReady }
}

extension AppleModelState {
    /// How a non-ready state surfaces in Beru's error path.
    ///
    /// Nothing here returns `.modelUnavailable`: that case sets
    /// `needsModelSetup`, which makes Beru offer "Connect to model" — wrong for
    /// a provider the user cannot configure by typing a URL or a key.
    var providerError: ProviderError {
        switch self {
        case .ready:
            return .cancelled
        case .deviceNotEligible, .intelligenceNotEnabled:
            return .badResponse(summary)
        case .modelNotReady:
            return .connectionFailed("Apple Intelligence is still getting ready — try again in a moment")
        }
    }

    /// Maps a framework generation failure to Beru's error vocabulary.
    static func providerError(for error: Error) -> ProviderError {
        guard let generation = error as? LanguageModelSession.GenerationError else {
            if error is CancellationError { return .cancelled }
            return .connectionFailed(error.localizedDescription)
        }
        switch generation {
        case .exceededContextWindowSize:
            return .badResponse("Too long for the on-device model — select a shorter passage or switch provider")
        case .guardrailViolation:
            return .badResponse("Apple's on-device model declined this text — try another provider")
        case .unsupportedLanguageOrLocale:
            return .badResponse("Apple's on-device model doesn't cover this language yet — switch provider in Settings")
        case .assetsUnavailable:
            return .connectionFailed("Apple Intelligence is still getting ready — try again in a moment")
        case .rateLimited:
            return .rateLimited
        case .decodingFailure, .unsupportedGuide:
            return .badResponse("The on-device model returned an unusable result — try again")
        @unknown default:
            return .connectionFailed(error.localizedDescription)
        }
    }
}