import AppKit
import SwiftUI

struct PanelView: View {
    @Bindable var appState: AppState
    let engine: PanelEngine
    var onLayoutHeights: ((PanelLayoutHeights) -> Void)?
    @FocusState var describeFieldFocused: Bool

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
            .reportsPanelBand(.chromeTop)
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)

            resultSlot

            composerColumn
                .reportsPanelBand(.chromeBottom)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
        }
        .padding(PanelMetrics.moduleInset)
        .frame(maxWidth: .infinity, alignment: .top)
        .ignoresSafeArea()
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
            perform(PanelKeyBinding.resolveEscape())
        }
        .onKeyPress(keys: [.return], phases: .down) { press in
            perform(
                PanelKeyBinding.resolveReturn(
                    modifiers: PanelKeyModifiers(press: press),
                    canSubmit: canSubmitDescribe,
                    hasAcceptableResult: appState.acceptedText() != nil
                )
            )
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "c123456789"), phases: .down) { press in
            guard let character = press.characters.first else { return .ignored }
            return perform(
                PanelKeyBinding.resolveCharacter(
                    character,
                    modifiers: PanelKeyModifiers(press: press),
                    tabCount: panelTabs.count
                )
            )
        }
    }

    /// Applies a resolved intent. Returns the `onKeyPress` disposition so an
    /// unclaimed key still reaches the focused control.
    @discardableResult
    func perform(_ intent: PanelKeyIntent) -> KeyPress.Result {
        switch intent {
        case .replace:
            performReplace()
        case .submit:
            submitDescribe()
        case .copy:
            performCopy()
        case .cancel:
            engine.cancel()
        case .selectTab(let index):
            let tabs = panelTabs
            guard index >= 1, index <= tabs.count else { return .ignored }
            selectTab(tabs[index - 1].id)
        case .pass:
            return .ignored
        }
        return .handled
    }

    /// Result band: intrinsic below the cap; fixed-height ScrollView at the cap
    /// so pinned chrome never leaves the window. `reportsPanelBand` measures the
    /// unconstrained card so a short seed window cannot lock the height.
    /// Search threads pin to the latest turn so follow-ups stay in view.
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
        guard let layout = PanelLayoutHeights.fromBands(
            top: bands[.chromeTop] ?? 0,
            bottom: bands[.chromeBottom] ?? 0,
            result: bands[.result] ?? 0
        ) else { return }
        onLayoutHeights?(layout)
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
