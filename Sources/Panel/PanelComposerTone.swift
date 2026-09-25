import AppKit
import SwiftUI

// Footer and composer policy: the write-back action, busy state, and send.

extension PanelView {

    var primaryFooterTitle: String { "Replace" }

    /// Short hover pill for the primary footer action.
    var primaryFooterHoverHelp: String { "Replace selection" }

    var isPromptBusy: Bool {
        switch appState.resultState(for: appState.selectedActionID) {
        case .loading, .thinking, .streaming: return true
        default: return false
        }
    }

    var sendButton: some View {
        PanelHitCapsule(
            help: isPromptBusy ? "Working…" : "Run this intent",
            accessibilityLabel: isPromptBusy ? "Working…" : "Send"
        ) {
            submitIfReady()
        } label: {
            EnhancifyFilledCircleButton(
                icon: "arrow-up",
                enabled: canSubmitDescribe && !isPromptBusy,
                help: isPromptBusy ? "Working…" : "Run this intent"
            ) {}
        }
        .accessibilityHint("Send the instruction to Enhancify")
    }

    func submitIfReady() {
        guard canSubmitDescribe, !isPromptBusy else { return }
        submitDescribe()
    }
}

extension ProviderKind {
    var composerTitle: String {
        switch self {
        case .ollama: return "Ollama"
        case .anthropic: return "Anthropic"
        case .custom: return "API"
        case .apple: return "Apple"
        }
    }

    var composerIcon: String {
        switch self {
        case .ollama: return "cpu"
        case .anthropic: return "sparkle"
        case .custom: return "cloud"
        case .apple: return "memory"
        }
    }
}
