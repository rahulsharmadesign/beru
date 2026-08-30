import Foundation

extension DictationService {
    /// What a mic press or dictate hotkey should do, given current TCC state.
    ///
    /// First use must ask via the system prompt, not Settings. Opening the
    /// dashboard before `requestAccess` steals the dialog and looks like a
    /// dead mic.
    enum MicPressIntent: Equatable {
        case stop
        case requestPermissionThenStart
        case start
        case openSettings
    }

    nonisolated static func intentForMicPress(
        isRecording: Bool,
        availability: Availability
    ) -> MicPressIntent {
        if isRecording { return .stop }
        switch availability {
        case .ready: return .start
        case .needsPermission: return .requestPermissionThenStart
        case .microphoneDenied, .speechDenied, .onDeviceUnavailable, .noRecognizer:
            return .openSettings
        }
    }
}

extension DictationService.Availability {
    /// Settings → Permissions badge. Needed covers not-yet-asked and denied.
    var permissionBadgeTitle: String {
        switch self {
        case .ready: return "Granted"
        case .needsPermission, .microphoneDenied, .speechDenied: return "Needed"
        case .onDeviceUnavailable, .noRecognizer: return "Unavailable"
        }
    }
}
