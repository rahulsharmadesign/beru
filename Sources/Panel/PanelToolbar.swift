import AppKit
import SwiftUI

// The panel's top module: verb chips and the one quiet context line.

extension PanelView {
    // MARK: - Toolbar (verbs + context)

    /// Verb chips + quiet metadata. Context line always occupies height
    /// (opacity only) so Search ↔ skill does not change toolbar size mid-frame
    /// and crop the composer before the window can grow.
    var toolbar: some View {
        VStack(alignment: .leading, spacing: BeruSpace.xs) {
            verbRow
            contextLine
                .opacity(showsContextLine ? 1 : 0)
                .accessibilityHidden(!showsContextLine)
                // Keep context from animating height; do not nil the chip row.
                .animation(nil, value: appState.selectedActionID)
                .animation(nil, value: appState.isQuickSearch)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            }
            .frame(height: BeruMetrics.tabPillHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Webpage → Summarize (and similar) land on a chip past the fold;
            // bring the active tab into view without a manual swipe.
            .onAppear { scrollChipIntoView(proxy) }
            .onChange(of: appState.selectedActionID) { _, _ in
                scrollChipIntoView(proxy)
            }
            .onChange(of: appState.panelSessionID) { _, _ in
                scrollChipIntoView(proxy)
            }
        }
    }

    func scrollChipIntoView(_ proxy: ScrollViewProxy) {
        let id = appState.selectedActionID
        let animated = !a11y.reduceMotion
        DispatchQueue.main.async {
            withAnimation(animated ? .easeOut(duration: 0.2) : nil) {
                proxy.scrollTo(id, anchor: .center)
            }
        }
    }

    /// Selection morph. Scoped to the chip so the window does not re-layout.
    var tabMorph: Animation {
        a11y.reduceMotion
            ? .easeOut(duration: 0.12)
            : .easeOut(duration: 0.32)
    }

    func selectTab(_ actionID: String) {
        guard actionID != appState.selectedActionID else { return }
        withAnimation(tabMorph) {
            appState.selectAction(actionID)
        }
    }

    func chip(for action: EnhancementAction) -> some View {
        let isSelected = appState.selectedActionID == action.id
        let label = BeruLabel(title: action.name, icon: action.icon, iconSize: 14, strokeWidth: 2)
            .labelStyle(.titleAndIcon)
            .font(BeruType.footnoteMedium)
            .foregroundStyle(isSelected ? BeruColor.onAccent : BeruColor.textPrimary)

        return Button { selectTab(action.id) } label: {
            label
                .padding(.horizontal, BeruSpace.sm)
                .frame(height: BeruMetrics.tabPillHeight)
                .contentShape(Capsule())
                .background {
                    chipFill(selected: isSelected)
                }
        }
        .buttonStyle(.plain)
        .frame(height: BeruMetrics.tabPillHeight)
        .animation(tabMorph, value: isSelected)
        .help(action.summary)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// One sliding accent pill. Idle chips keep a hairline so the row stays
    /// readable; the fill is a single matched-geometry source.
    func chipFill(selected: Bool) -> some View {
        ZStack {
            Capsule()
                .strokeBorder(selected ? Color.clear : BeruColor.border, lineWidth: 0.75)
            if selected {
                Capsule()
                    .fill(BeruColor.accent)
                    .matchedGeometryEffect(id: "tab-selection", in: tabGlass)
            }
        }
    }

    /// Context as caption text — not a second chip row competing with verbs.
    var contextLine: some View {
        HStack(spacing: BeruSpace.xs) {
            Text(contextSummary)
                .font(BeruType.caption)
                .foregroundStyle(BeruColor.textSecondary)
                .lineLimit(1)
            Spacer(minLength: BeruSpace.xs)
            sessionContextChip
            if appState.clipboardText != nil {
                Button {
                    appState.includeClipboard.toggle()
                } label: {
                    Text(appState.includeClipboard ? "Clipboard ✓" : "Clipboard")
                        .font(BeruType.captionMedium)
                        .foregroundStyle(appState.includeClipboard ? BeruColor.accent : BeruColor.textSecondary)
                }
                .buttonStyle(.plain)
                .help(appState.includeClipboard
                      ? "Clipboard will be sent as reference"
                      : "Include clipboard as reference")
            }
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

    var contextSummary: String {
        let name = EnhancementAction.resolvedName(
            actionID: appState.selectedActionID,
            registryName: registry.action(withID: appState.selectedActionID)?.name
        )
        let count = appState.capturedText.trimmingCharacters(in: .whitespacesAndNewlines).count
        return EnhancementAction.contextSummary(
            actionName: name,
            hostAppName: appState.hostAppName,
            characterCount: count
        )
    }
}
