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
    /// AppKit anchors behind the composer pills. `NSMenu.popUp` needs a view
    /// in the panel window to attach to; the holders carry it without ever
    /// invalidating SwiftUI state.
    @State var targetAnchor = MenuAnchorHolder()
    @State var providerAnchor = MenuAnchorHolder()
    @State var toneAnchor = MenuAnchorHolder()
    /// Search answer showing the copied check. Resets after a beat.
    @State var copiedTurnID: UUID? = nil
    /// Identity of the composer first-run beam lap. Regenerated whenever the
    /// beam should run again (fresh open, or returning to the AI Search tab).
    @State var beamRunID = UUID()

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

        // Color.clear fills the hosting view. After a tall tab, leftover height
        // sits between the result and the composer so the input does not jump.
        // A flexible max-height frame is banned here (panel_infinite_height guard).
        Color.clear
            .glassSlabBackground()
            .background(PanelDragRegion())
            .overlay(alignment: .top) {
                VStack(spacing: PanelMetrics.moduleSpacing) {
                    VStack(spacing: PanelMetrics.moduleSpacing) {
                        closeStrip
                        toolbar
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .reportsPanelBand(.chromeTop)
                    .fixedSize(horizontal: false, vertical: true)

                    resultSlot
                }
                .padding(.top, PanelMetrics.moduleInset)
                .padding(.horizontal, PanelMetrics.moduleInset)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .overlay(alignment: .bottom) {
                composerColumn
                    .reportsPanelBand(.chromeBottom)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, PanelMetrics.moduleInset)
                    .padding(.bottom, PanelMetrics.moduleInset)
                    .padding(.top, PanelMetrics.moduleSpacing)
            }
            .ignoresSafeArea()
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
                        hasAcceptableResult: appState.acceptedText() != nil,
                        allowsReplace: showsHostWriteAction
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
                // Cap touchdown mounts a fresh ScrollView at offset zero —
                // without this the thread flashes its first turn ("jump to
                // the top") until the next chunk scrolls down. Pin instantly.
                .onAppear {
                    scrollSearchThreadToLatest(proxy, animated: false)
                }
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
                .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    func scrollSearchThreadToLatest(_ proxy: ScrollViewProxy, animated: Bool = true) {
        guard appState.selectedActionID == EnhancementAction.searchID,
              let last = appState.searchThread.last else { return }
        let animation: Animation? = (animated && !a11y.reduceMotion) ? .easeOut(duration: 0.15) : nil
        DispatchQueue.main.async {
            withAnimation(animation) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    func publishLayoutHeights(_ bands: [PanelHeightBand: CGFloat]) {
        PanelControllerTrace.band("bands top=\(bands[.chromeTop] ?? -1) bottom=\(bands[.chromeBottom] ?? -1) result=\(bands[.result] ?? -1)")
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
