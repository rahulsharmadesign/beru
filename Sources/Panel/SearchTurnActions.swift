import AppKit
import SwiftUI

// Per-turn actions for the AI Search thread: icon-only copy, regenerate,
// like/dislike votes, and pin. Appears on done answers only — never
// mid-stream. Copy stays pasteboard-local so the thread survives it.
// The tab footer is gone; turns own every outcome.

extension PanelView {
    /// Icon-only row under each answered turn.
    func searchTurnActions(turn: SearchThreadTurn, text: String) -> some View {
        let vote = appState.searchFeedback[turn.id]
        let copied = copiedTurnID == turn.id
        let pinned = appState.pinnedRow == turn.id.uuidString
        return HStack(spacing: BeruSpace.hair) {
            SearchActionButton(
                icon: copied ? "check" : "copy",
                help: copied ? "Copied" : "Copy this answer",
                tint: copied ? BeruColor.positive : nil
            ) {
                copySearchTurn(text: text, id: turn.id)
            }
            SearchActionButton(icon: "rotate-cw", help: "Regenerate this answer") {
                engine.regenerateSearchTurn(id: turn.id)
            }
            SearchActionButton(
                icon: "thumbs-up",
                help: "Good answer — helps Beru learn",
                active: vote == true
            ) {
                setSearchVote(turn, liked: true)
            }
            SearchActionButton(
                icon: "thumbs-down",
                help: "Bad answer — helps Beru learn",
                active: vote == false
            ) {
                setSearchVote(turn, liked: false)
            }
            SearchActionButton(
                icon: pinned ? "check" : "pin",
                help: pinned ? "Pinned" : "Pin this answer",
                tint: pinned ? BeruColor.positive : nil
            ) {
                pinSearchTurn(text: text, id: turn.id)
            }
        }
        .padding(.top, BeruSpace.xxs)
    }

    /// Pin without dismissing; the row flashes a check like grammar rows.
    func pinSearchTurn(text: String, id: UUID) {
        engine.pin(text: text)
        appState.pinnedRow = id.uuidString
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            if appState.pinnedRow == id.uuidString {
                appState.pinnedRow = nil
            }
        }
    }

    /// Pasteboard-only copy: the footer Copy dismisses the panel, which a
    /// thread must survive.
    func copySearchTurn(text: String, id: UUID) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedTurnID = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if copiedTurnID == id {
                copiedTurnID = nil
            }
        }
    }

    /// Tapping the active vote clears it; switching sides moves it. Every new
    /// vote is logged as training signal.
    func setSearchVote(_ turn: SearchThreadTurn, liked: Bool) {
        if appState.searchFeedback[turn.id] == liked {
            appState.searchFeedback.removeValue(forKey: turn.id)
        } else {
            appState.searchFeedback[turn.id] = liked
            if case .done(let text) = turn.answer {
                engine.recordResultVote(
                    actionID: EnhancementAction.searchID,
                    liked: liked,
                    text: text,
                    question: turn.question
                )
            }
        }
    }
}

/// Icon-only action with a hover wash and no chrome. The shared outcome
/// control: search turn rows and the footer row both use it.
struct SearchActionButton: View {
    let icon: String
    let help: String
    var tint: Color? = nil
    var active: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            BeruIcon(name: icon, size: BeruMetrics.iconSize)
                .foregroundStyle(tint ?? (active ? BeruColor.accent : BeruColor.textSecondary))
                .frame(width: BeruMetrics.roundButtonSm, height: BeruMetrics.roundButtonSm)
                .background {
                    BeruRadius.shape(BeruRadius.sm)
                        .fill(isHovered ? BeruColor.hoverFill : .clear)
                }
                .contentShape(BeruRadius.shape(BeruRadius.sm))
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .accessibilityAddTraits(active ? .isSelected : [])
        .onHover { isHovered = $0 }
.beruHoverEase(isHovered)
    }
}
