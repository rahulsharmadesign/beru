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
            action: presentToneMenu
        )
    }

    func presentToneMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let selected = appState.selectedReplyTone
        TargetMenuRelay.shared.onPick = { raw in
            guard let tone = ReplyTone(rawValue: raw) else { return }
            appState.selectedReplyTone = tone
        }
        for tone in ReplyTone.allCases {
            let item = NSMenuItem(
                title: tone.title,
                action: #selector(TargetMenuRelay.pick(_:)),
                keyEquivalent: ""
            )
            item.target = TargetMenuRelay.shared
            item.representedObject = tone.rawValue
            item.state = tone == selected ? .on : .off
            if !appState.replySuggestions.isEmpty {
                item.isEnabled = appState.replySuggestions.contains { $0.tone == tone }
            }
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    var isPromptBusy: Bool {
        switch appState.resultState(for: appState.selectedActionID) {
        case .loading, .thinking, .streaming: return true
        default: return false
        }
    }

    var sendButton: some View {
        Button(action: submitIfReady) {
            ZStack {
                Circle()
                    .fill(canSubmitDescribe ? BeruColor.accent : BeruColor.disabledFill)
                if isPromptBusy {
                    BeruLoader(tint: canSubmitDescribe ? BeruColor.onAccent : BeruColor.textSecondary)
                } else {
                    BeruIcon(name: "arrow-up", size: 15, strokeWidth: 2.4)
                        .foregroundStyle(canSubmitDescribe ? BeruColor.onAccent : BeruColor.textSecondary)
                }
            }
            .frame(width: BeruMetrics.hitTarget, height: BeruMetrics.hitTarget)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isPromptBusy)
        .help("Run this intent")
        .accessibilityLabel(isPromptBusy ? "Loading" : "Run this intent")
        .accessibilityHint("Send the instruction to Beru")
    }

    func submitIfReady() {
        guard canSubmitDescribe, !isPromptBusy else { return }
        submitDescribe()
    }
}
