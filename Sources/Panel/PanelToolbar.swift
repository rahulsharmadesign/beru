import AppKit
import SwiftUI

// The panel's top module: verb chips and the one quiet context line.

extension PanelView {
    // MARK: - Toolbar (verbs + context)

    /// Single top module: verb chips + one quiet metadata line.
    var toolbar: some View {
        VStack(alignment: .leading, spacing: BeruSpace.xs) {
            verbRow
            if !appState.isQuickSearch || hasCapturedText {
                contextLine
                    .transition(.opacity)
            }
        }
        // Scoped to the stack that holds the conditional context line. Applied
        // after padding and the drag region it also animated the module's
        // chrome, so switching tabs relaid out the whole toolbar card.
        .animation(tabAnimation, value: appState.selectedActionID)
        .padding(PanelMetrics.moduleInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PanelDragRegion())
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
        ScrollView(.horizontal, showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                tabSelectionPill
                HStack(spacing: BeruSpace.xs) {
                    ForEach(panelTabs) { action in
                        chip(for: action)
                    }
                }
            }
            .coordinateSpace(name: "verbRow")
            .onPreferenceChange(ChipFramesKey.self) { chipFrames = $0 }
        }
        .frame(height: PanelMetrics.chipRowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    var tabSelectionPill: some View {
        if let frame = chipFrames[appState.selectedActionID] {
            Capsule()
                .fill(BeruColor.accent)
                .frame(width: frame.width, height: frame.height)
                .offset(x: frame.minX, y: frame.minY)
                .shadow(
                    color: a11y.reduceTransparency ? .clear : BeruColor.accent.opacity(0.18),
                    radius: BeruSpace.xxs,
                    y: BeruSpace.hair
                )
                .allowsHitTesting(false)
        }
    }

    var tabAnimation: Animation {
        a11y.reduceMotion
            ? .easeOut(duration: 0.12)
            : .easeInOut(duration: 0.28)
    }

    func selectTab(_ actionID: String) {
        withAnimation(tabAnimation) {
            appState.selectAction(actionID)
        }
    }

    func chip(for action: EnhancementAction) -> some View {
        let isSelected = appState.selectedActionID == action.id
        return Button {
            selectTab(action.id)
        } label: {
            BeruLabel(title: action.name, icon: action.icon, iconSize: 14, strokeWidth: 2)
                .labelStyle(.titleAndIcon)
                .font(isSelected ? BeruType.footnoteSemibold : BeruType.footnoteMedium)
                .glassChip(selected: isSelected)
                .background {
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ChipFramesKey.self,
                            value: [action.id: geo.frame(in: .named("verbRow"))]
                        )
                    }
                }
        }
        .buttonStyle(.plain)
        .help(action.summary)
    }

    /// Context as caption text — not a second chip row competing with verbs.
    var contextLine: some View {
        HStack(spacing: BeruSpace.xs) {
            Text(contextSummary)
                .font(BeruType.caption)
                .foregroundStyle(BeruColor.textSecondary)
                .lineLimit(1)
            Spacer(minLength: BeruSpace.xs)
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

    var contextSummary: String {
        let app = appState.hostAppName ?? "Mac"
        let trimmed = appState.capturedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "\(app) · No text selected"
        }
        return "\(app) · \(trimmed.count) characters"
    }
}
