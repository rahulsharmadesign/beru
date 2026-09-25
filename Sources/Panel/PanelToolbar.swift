import AppKit
import SwiftUI

// The panel's top module: the Enhance / Grammar tabs, plus Grammar's style row.

extension PanelView {
    var toolbar: some View {
        VStack(alignment: .leading, spacing: EnhancifySpace.xs) {
            verbRow
            if appState.selectedActionID == EnhancementAction.grammarID {
                grammarStyleRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var hasCapturedText: Bool {
        !appState.capturedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var panelTabs: [EnhancementAction] {
        EnhancementAction.all
    }

    var verbRow: some View {
        HStack(spacing: EnhancifySpace.xs) {
            ForEach(panelTabs) { action in
                chip(for: action)
            }
        }
        .frame(height: EnhancifyMetrics.tabPillHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func selectTab(_ actionID: String) {
        guard actionID != appState.selectedActionID else { return }
        // Do not wrap selectAction in withAnimation — that re-lays out chrome
        // with the window. The chip row owns the highlight spring instead.
        appState.selectAction(actionID)
    }

    /// AppKit hit target: a SwiftUI `Button` on this row is stolen by
    /// window-drag, so the chip never selects. Highlight travel lives on
    /// the chip; do not wrap `selectAction` in `withAnimation`.
    func chip(for action: EnhancementAction) -> some View {
        PanelTabChip(
            title: action.name,
            icon: action.icon,
            isSelected: appState.selectedActionID == action.id,
            help: action.summary,
            highlightNamespace: tabHighlight
        ) {
            selectTab(action.id)
        }
    }
}

/// AppKit click target around a verb chip. A SwiftUI `Button` on this row
/// is stolen by window-drag — same reason Replace and the mic use `PanelHitCapsule`.
private struct PanelTabChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let help: String
    var highlightNamespace: Namespace.ID
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        PanelHitCapsule(help: help, accessibilityLabel: title, action: action) {
            EnhancifyGlassChip(
                title: title,
                icon: icon,
                isSelected: isSelected,
                isHovered: isHovered,
                highlightNamespace: highlightNamespace
            )
        }
        .onHover { isHovered = $0 }
        .enhancifyHoverEase(isHovered)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .frame(height: EnhancifyMetrics.tabPillHeight)
    }
}
