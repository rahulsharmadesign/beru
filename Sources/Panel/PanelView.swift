import AppKit
import SwiftUI

struct PanelView: View {
    @Bindable var appState: AppState
    let engine: PanelEngine
    let onHeightChange: (CGFloat) -> Void
    @FocusState var describeFieldFocused: Bool
    @State var chipFrames: [String: CGRect] = [:]
    @State var accessibilityTrusted = Permissions.isAccessibilityTrusted()

    // Every shared singleton this view reads is @Bindable. Two of these used to
    // be plain stored properties, which reads the current value but never
    // subscribes, so editing an action or toggling an accessibility preference
    // could leave the panel showing stale chips until something else redrew it.
    @Bindable var registry = ActionRegistry.shared
    @Bindable var targetRegistry = TargetRegistry.shared
    @Bindable var a11y = AccessibilityPreferences.shared
    @Bindable var settings = SettingsStore.shared
    @Bindable var appearance = AppearanceObserver.shared

    init(appState: AppState, engine: PanelEngine, onHeightChange: @escaping (CGFloat) -> Void = { _ in }) {
        self.appState = appState
        self.engine = engine
        self.onHeightChange = onHeightChange
    }

    var body: some View {
        // One composition: toolbar (verbs + quiet context) → result → outcomes → composer.
        // Chips live inside a chrome module with real inset so they never kiss the
        // rounded window edge (that was the "broken top" look).
        //
        // Observation only invalidates on values read while body runs. The
        // accent and the active provider are read further down by .tint and the
        // provider pill, but nothing in the tree reads the system appearance,
        // and the panel paints AppKit-backed surfaces that must follow it. This
        // read is the subscription, so a light/dark switch repaints the panel.
        _ = appearance.signature

        return VStack(spacing: 0) {
            closeStrip
                .contributesPanelHeight()
            VStack(spacing: PanelMetrics.moduleSpacing) {
                toolbar
                    .glassModule()
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                    .contributesPanelHeight()
                resultModule
                composerColumn
                    .layoutPriority(1)
                    .contributesPanelHeight()
            }
        }
        .background(BeruColor.canvas)
        .background(PanelDragRegion())
        .tint(BeruColor.accent)
        .onPreferenceChange(PanelHeightKey.self) { total in
            onHeightChange(total + PanelMetrics.moduleChromeHeight)
        }
        .frame(minHeight: PanelMetrics.minHeight, maxHeight: .infinity)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .id(appState.panelSessionID)
        .onChange(of: appState.selectedActionID) { _, actionID in
            guard actionID != EnhancementAction.describeID,
                  actionID != EnhancementAction.searchID else { return }
            engine.startIfNeeded(actionID: actionID)
        }
        .onKeyPress(.escape) {
            engine.cancel()
            return .handled
        }
        .task {
            while !Task.isCancelled {
                accessibilityTrusted = Permissions.isAccessibilityTrusted()
                try? await Task.sleep(for: .seconds(1))
            }
        }
        .onKeyPress(keys: [.return], phases: .down) { press in
            if press.modifiers.contains(.command) {
                performReplace()
                return .handled
            }
            if canSubmitDescribe {
                submitDescribe()
                return .handled
            }
            performReplace()
            return .handled
        }
        .onKeyPress(keys: ["c"], phases: .down) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            performCopy()
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "123456789"), phases: .down) { press in
            guard press.modifiers.contains(.command),
                  let digit = press.characters.first?.wholeNumberValue else { return .ignored }
            let tabs = panelTabs
            guard digit >= 1, digit <= tabs.count else { return .ignored }
            selectTab(tabs[digit - 1].id)
            return .handled
        }
    }

    // MARK: - Close strip

    /// Outer-frame chrome matching the widget mock: red close sits above the
    /// inner cards, on the right, not over the chips.
    var closeStrip: some View {
        HStack(spacing: BeruSpace.xs) {
            Spacer(minLength: 0)
            PanelUpdateButton()
            PanelCloseDot { engine.cancel() }
        }
        .padding(.trailing, BeruSpace.xxs)
        .frame(height: PanelMetrics.closeStripHeight)
        .background(PanelDragRegion())
    }
}
