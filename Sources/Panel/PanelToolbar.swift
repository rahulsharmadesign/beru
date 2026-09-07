import AppKit
import SwiftUI

// The panel's top module: verb chips and the one quiet context line.

extension PanelView {
    // MARK: - Toolbar (verbs + context)

    /// Verb chips + quiet metadata. The context line renders only when it
    /// has content: reserving its height while hidden left a ~22pt phantom
    /// gap above the result card in the AI Search tab. Tab switches resize
    /// in the same frame per the frozen height contract, so no reservation
    /// is needed.
    var toolbar: some View {
        VStack(alignment: .leading, spacing: BeruSpace.xs) {
            verbRow
            if showsContextLine {
                contextLine
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(nil, value: showsContextLine)
    }

    var showsContextLine: Bool {
        !appState.isQuickSearch || hasCapturedText
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
        // with the window. Selection cross-fades on each chip instead.
        openMenuID = nil
        appState.selectAction(actionID)
        // One-shot pop: bounce out, then settle back to 1.00. Skipped under
        // Reduce Motion, where selection is an instant swap.
        if !a11y.reduceMotion {
            chipPopID = actionID
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                if chipPopID == actionID {
                    chipPopID = nil
                }
            }
        }
    }

    /// Selection lives on the chip itself: a 0.25s ease melts the gradient
    /// and text color while the chip bounces to 1.04 on a 0.5s overshoot
    /// and settles back to the original 1.00 — the `.pill` CSS motion
    /// (`0.34, 1.56, 0.64, 1`), mapped to the Haze gradient instead of
    /// orange. Render-only: layout (and the frozen height contract) never
    /// moves.
    func chip(for action: EnhancementAction) -> some View {
        let isSelected = appState.selectedActionID == action.id
        let label = BeruLabel(title: action.name, icon: action.icon, iconSize: 14, strokeWidth: 2)
            .labelStyle(.titleAndIcon)
            .font(BeruType.footnoteMedium)
            .foregroundStyle(isSelected ? BeruColor.onAccent : BeruColor.textPrimary)
            .animation(chipColorEase, value: isSelected)

        return Button { selectTab(action.id) } label: {
            label
                .padding(.horizontal, BeruSpace.sm)
                .frame(height: BeruMetrics.tabPillHeight)
                .contentShape(Capsule())
                .background {
                    // Layered fills, not a conditional fill: SwiftUI cannot
                    // interpolate a gradient into a solid color, so swapping
                    // `.fill()` styles snapped instantly with no visible
                    // transition. Fading the gradient layer's opacity melts
                    // selection from chip to chip instead.
                    Capsule()
                        .fill(BeruColor.subtleFill)
                        .overlay {
                            Capsule()
                                .fill(BeruColor.accentGradient)
                                .opacity(isSelected ? 1 : 0)
                                .animation(chipColorEase, value: isSelected)
                        }
                        .overlay {
                            Capsule().strokeBorder(isSelected ? Color.clear : BeruColor.border, lineWidth: 1)
                        }
                }
                .scaleEffect(chipPopID == action.id ? 1.04 : 1)
                .animation(chipPopMorph, value: [chipPopID == action.id, isSelected])
        }
        .buttonStyle(.plain)
        .frame(height: BeruMetrics.tabPillHeight)
        .help(action.summary)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Pill pop: overshoot scale on select, matching the `.pill` CSS
    /// `transform 0.5s cubic-bezier(0.34, 1.56, 0.64, 1)`.
    var chipPopMorph: Animation {
        a11y.reduceMotion
            ? .easeOut(duration: 0.12)
            : .timingCurve(0.34, 1.56, 0.64, 1, duration: 0.5)
    }

    /// Pill tint: gradient and text color over 0.25s ease, like the CSS
    /// `background 0.25s ease, color 0.25s ease`.
    var chipColorEase: Animation {
        a11y.reduceMotion ? .easeOut(duration: 0.12) : .easeOut(duration: 0.25)
    }

    /// Character count only — the action name, host app, and clipboard
    /// toggle used to crowd this line. Context as caption text, left aligned.
    var contextLine: some View {
        HStack(spacing: BeruSpace.xxs) {
            Text(characterCountSummary)
                .font(BeruType.caption)
                .foregroundStyle(BeruColor.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            sessionContextChip
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

    var characterCountSummary: String {
        let count = appState.capturedText.trimmingCharacters(in: .whitespacesAndNewlines).count
        return count == 1 ? "1 character" : "\(count) characters"
    }
}
