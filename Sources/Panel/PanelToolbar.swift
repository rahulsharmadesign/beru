import AppKit
import SwiftUI

// The panel's top module: verb chips, plus the prior-turn chip when it
// can change the next result.

extension PanelView {
    // MARK: - Toolbar (verbs + context)

    /// Verb chips. The prior-turn chip renders only when it has content:
    /// reserving its height while hidden left a phantom gap above the
    /// result. Tab switches resize in the same frame per the frozen height
    /// contract, so no reservation is needed.
    var toolbar: some View {
        VStack(alignment: .leading, spacing: BeruSpace.xs) {
            verbRow
            if priorTurnCount > 0 {
                sessionContextChip
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(nil, value: priorTurnCount)
    }

    var hasCapturedText: Bool {
        !appState.capturedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// AI Search is pinned first. Registry skills follow. Instruction only
    /// appears while a one-off describe is active.
    var panelTabs: [EnhancementAction] {
        var tabs = [EnhancementAction.search]
        if appState.selectedActionID == EnhancementAction.describeID {
            tabs.append(EnhancementAction.describe)
        }
        tabs.append(contentsOf: registry.allActions)
        return tabs
    }

    var verbRow: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BeruSpace.xs) {
                    ForEach(panelTabs) { action in
                        chip(for: action)
                            .id(action.id)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: BeruMetrics.tabPillHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Webpage → Summarize (and similar) land on a chip past the fold;
            // bring the active tab into view without a manual swipe.
            .onAppear {
                scrollChipIntoView(proxy)
                // The appear-scroll can commit while first layout is still
                // settling and silently miss. Re-assert after settle so a
                // stale offset can never stick on default open.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    scrollChipIntoView(proxy)
                }
            }
            .onChange(of: appState.selectedActionID) { _, _ in
                scrollChipIntoView(proxy)
            }
            .onChange(of: appState.panelSessionID) { _, _ in
                scrollChipIntoView(proxy)
            }
            // The panel host is reused across invocations, so a scrolled row
            // can outlive the session that scrolled it. Re-center on every
            // show — this is what left AI Search cropped on default open.
            .onChange(of: appState.isPanelVisible) { _, visible in
                if visible {
                    scrollChipIntoView(proxy)
                }
            }
        }
    }

    func scrollChipIntoView(_ proxy: ScrollViewProxy) {
        let tabs = panelTabs
        let id = appState.selectedActionID
        // Edge tabs pin to their edge: centering the first chip resolves to
        // a negative offset that sticks as a crop instead of clamping to zero.
        let anchor: UnitPoint =
            id == tabs.first?.id ? .leading
            : id == tabs.last?.id ? .trailing : .center
        DispatchQueue.main.async {
            // Instant scroll, never animated: wrapping scrollTo in
            // withAnimation leaked an animated transaction onto the chip
            // fills, fading unselected backgrounds and strokes mid-switch.
            proxy.scrollTo(id, anchor: anchor)
        }
    }

    func selectTab(_ actionID: String) {
        guard actionID != appState.selectedActionID else { return }
        // Do not wrap selectAction in withAnimation — that re-lays out chrome
        // with the window. Selection cross-dissolves on each chip instead.
        appState.selectAction(actionID)
    }

    /// AppKit hit target: a SwiftUI `Button` on this row is stolen by
    /// window-drag, so the chip never selects. Selection dissolve lives on
    /// the chip; do not wrap `selectAction` in `withAnimation`.
    func chip(for action: EnhancementAction) -> some View {
        PanelTabChip(
            title: action.name,
            icon: action.icon,
            isSelected: appState.selectedActionID == action.id,
            help: action.summary
        ) {
            selectTab(action.id)
        }
    }

    /// Says when prior turns are shaping this request, and lets you drop them.
    ///
    /// Context that silently changes the output is the kind that makes a tool
    /// feel unpredictable, so this is visible whenever it applies rather than
    /// hidden in settings — and clicking it clears the thread, which is the
    /// thing you want the instant a result looks contaminated.
    @ViewBuilder
    var sessionContextChip: some View {
        let turns = priorTurnCount
        if turns > 0 {
            Button {
                thread.clear()
            } label: {
                Text(turns == 1 ? "Using 1 prior turn" : "Using \(turns) prior turns")
                    .font(BeruType.captionMedium)
                    .foregroundStyle(BeruColor.textSecondary)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .help("This request can build on your last \(turns) in this app. Click to forget them.")
            .accessibilityLabel("Using \(turns) prior turns. Activate to clear.")
        }
    }

    var priorTurnCount: Int {
        guard settings.sessionContextEnabled,
              Prompts.threadApplies(actionID: appState.selectedActionID) else { return 0 }
        return thread.turns(forBundleID: appState.hostBundleID).count
    }
}

/// AppKit click target around a verb chip. A SwiftUI `Button` on this row
/// is stolen by window-drag — same reason Replace and the mic use `PanelHitCapsule`.
private struct PanelTabChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let help: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        PanelHitCapsule(help: help, accessibilityLabel: title, action: action) {
            BeruGlassChip(
                title: title,
                icon: icon,
                isSelected: isSelected,
                isHovered: isHovered
            )
        }
        .onHover { isHovered = $0 }
        .beruHoverEase(isHovered)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .frame(height: BeruMetrics.tabPillHeight)
    }
}
