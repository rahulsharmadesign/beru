import AppKit
import SwiftUI

struct PanelView: View {
    @Bindable var appState: AppState
    let engine: PanelEngine
    var onLayoutHeights: ((PanelLayoutHeights) -> Void)?
    @FocusState var describeFieldFocused: Bool
    @State var accessibilityTrusted = Permissions.isAccessibilityTrusted()

    @Bindable var registry = ActionRegistry.shared
    @Bindable var targetRegistry = TargetRegistry.shared
    @Bindable var a11y = AccessibilityPreferences.shared
    @Bindable var settings = SettingsStore.shared
    @Bindable var appearance = AppearanceObserver.shared
    @Bindable var thread = SessionThread.shared
    @Namespace var tabGlass

    init(
        appState: AppState,
        engine: PanelEngine,
        onLayoutHeights: ((PanelLayoutHeights) -> Void)? = nil
    ) {
        self.appState = appState
        self.engine = engine
        self.onLayoutHeights = onLayoutHeights
    }

    var body: some View {
        // Freeze: close + chips + composer pinned. Result grows with text, then
        // scrolls once the window hits 75% of the visible screen height.
        let _ = appearance.signature

        VStack(spacing: PanelMetrics.moduleSpacing) {
            VStack(spacing: PanelMetrics.moduleSpacing) {
                closeStrip
                toolbar
                    .fixedSize(horizontal: false, vertical: true)
            }
            .fixedSize(horizontal: false, vertical: true)
            .reportsPanelBand(.chromeTop)

            resultSlot

            composerColumn
                .fixedSize(horizontal: false, vertical: true)
                .reportsPanelBand(.chromeBottom)
        }
        .padding(PanelMetrics.moduleInset)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(PanelDragRegion())
        .tint(BeruColor.accent)
        .id(appState.panelSessionID)
        .onPreferenceChange(PanelBandHeightKey.self, perform: publishLayoutHeights)
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

    /// Result band: intrinsic below the cap; fixed-height ScrollView at the cap
    /// so pinned chrome never leaves the window. Search threads pin to the
    /// latest turn so follow-ups stay in view as the stack grows.
    @ViewBuilder
    var resultSlot: some View {
        let measured = resultModule.reportsPanelBand(.result)

        if let scrollHeight = appState.panelResultScrollHeight {
            ScrollViewReader { proxy in
                ScrollView {
                    measured
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: scrollHeight)
                .frame(maxWidth: .infinity)
                .onChange(of: appState.searchThread.count) { _, _ in
                    scrollSearchThreadToLatest(proxy)
                }
                .onChange(of: appState.resultState(for: EnhancementAction.searchID)) { _, _ in
                    scrollSearchThreadToLatest(proxy)
                }
            }
        } else {
            measured
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    func scrollSearchThreadToLatest(_ proxy: ScrollViewProxy) {
        guard appState.selectedActionID == EnhancementAction.searchID,
              let last = appState.searchThread.last else { return }
        DispatchQueue.main.async {
            withAnimation(a11y.reduceMotion ? nil : .easeOut(duration: 0.15)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    func publishLayoutHeights(_ bands: [PanelHeightBand: CGFloat]) {
        let top = bands[.chromeTop] ?? 0
        let bottom = bands[.chromeBottom] ?? 0
        let result = bands[.result] ?? 0
        // Outer padding + the two spacings flanking the result slot.
        let chrome = PanelMetrics.moduleInset * 2
            + top
            + bottom
            + PanelMetrics.moduleSpacing * 2
        guard chrome > PanelMetrics.moduleInset || result > 1 else { return }
        onLayoutHeights?(PanelLayoutHeights(chrome: chrome, result: result))
    }

    var closeStrip: some View {
        HStack(spacing: BeruSpace.xxs) {
            PanelCloseDot { engine.cancel() }
            Spacer(minLength: 0)
            PanelUpdateButton()
            PanelSettingsLink { engine.openSettings() }
        }
        .frame(height: PanelMetrics.closeStripHeight)
        .background(PanelDragRegion())
    }
}
