import AppKit
import SwiftUI

// Footer policy for the composer: which chips write back into the host,
// which show the token pill, Smart Reply's tone menu, and Insert vs Replace.

extension PanelView {
    var isSmartReply: Bool {
        appState.selectedActionID == EnhancementAction.replyID
    }

    /// Search is ask-and-take-away: Copy / Pin only. Rewrite chips keep
    /// Replace (or Insert / Apply) and the token pill.
    var isSearchTab: Bool {
        appState.selectedActionID == EnhancementAction.searchID || appState.isQuickSearch
    }

    var showsHostWriteAction: Bool { !isSearchTab }

    var isGrammar: Bool {
        appState.selectedActionID == EnhancementAction.grammarID
    }

    /// Savings is "this rewrite is cheaper to paste into an AI". Search,
    /// Smart Reply, and Grammar are not tighter prompts — Grammar's number
    /// reads as a correction count.
    var showsTokenSavings: Bool { !isSearchTab && !isSmartReply && !isGrammar }

    var primaryFooterTitle: String {
        if appState.vaultNoteID != nil { return "Apply" }
        return isSmartReply ? "Insert" : "Replace"
    }

    var primaryFooterHelp: String {
        if appState.vaultNoteID != nil {
            return "Write this result back into the vault note (Cmd-Return)"
        }
        if isSmartReply {
            return "Paste this reply into the focused field (Cmd-Return)"
        }
        return "Replace the selection (Cmd-Return)"
    }

    var toneMenu: some View {
        composerPickerPill(
            icon: "corner-up-left",
            title: appState.selectedReplyTone.title,
            help: "Which of the six replies to insert",
            accessibilityLabel: "Reply tone, \(appState.selectedReplyTone.title)",
            accessibilityHint: "Choose which generated reply to insert or copy",
            isOpen: openMenuID == PanelMenuID.tone,
            action: { toggleMenu(PanelMenuID.tone) }
        )
        .menuAnchor(PanelMenuID.tone)
    }

    var isPromptBusy: Bool {
        switch appState.resultState(for: appState.selectedActionID) {
        case .loading, .thinking, .streaming: return true
        default: return false
        }
    }

    /// Fresh AI Search open: beam the composer as the "type here" affordance
    /// until the first question runs.
    var showsFirstRunBeam: Bool {
        appState.selectedActionID == EnhancementAction.searchID
            && appState.searchThread.isEmpty
            && !isPromptBusy
    }

    /// The beam overlay for `showsFirstRunBeam`, scoped to this subtree so the
    /// fade transition cannot leak onto chips (see PanelToolbar's leak note).
    var firstRunBeamOverlay: some View {
        Group {
            if showsFirstRunBeam {
                BorderBeam(
                    shape: RoundedRectangle(
                        cornerRadius: PanelMetrics.composerRadius,
                        style: .continuous
                    ),
                    palette: .mono,
                    loops: 1
                )
                .id(beamRunID)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: showsFirstRunBeam)
        .onChange(of: showsFirstRunBeam) { _, showing in
            if showing { beamRunID = UUID() }
        }
        .onChange(of: appState.selectedActionID) { _, _ in
            if showsFirstRunBeam { beamRunID = UUID() }
        }
    }

    var sendButton: some View {
        Button(action: submitIfReady) {
            Circle()
                .fill(canSubmitDescribe ? AnyShapeStyle(BeruColor.accentGradient) : AnyShapeStyle(BeruColor.disabledFill))
                .overlay {
                    BeruIcon(name: "arrow-up", size: BeruMetrics.iconSize, strokeWidth: 2.4)
                        .foregroundStyle(canSubmitDescribe ? BeruColor.onAccent : BeruColor.textSecondary)
                }
                .frame(width: BeruMetrics.roundButton, height: BeruMetrics.roundButton)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isPromptBusy)
        .help(isPromptBusy ? "Working…" : "Run this intent")
        .accessibilityLabel(isPromptBusy ? "Working" : "Run this intent")
        .accessibilityHint("Send the instruction to Beru")
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
        }
    }

    var composerIcon: String {
        switch self {
        case .ollama: return "cpu"
        case .anthropic: return "sparkle"
        case .custom: return "cloud"
        }
    }
}
