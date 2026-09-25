import AppKit
import SwiftUI

struct PanelView: View {
    @Bindable var appState: AppState
    let engine: PanelEngine
    var onLayoutHeights: ((PanelLayoutHeights) -> Void)?
    @FocusState var describeFieldFocused: Bool

    @Bindable var targetRegistry = TargetRegistry.shared
    @Bindable var a11y = AccessibilityPreferences.shared
    @Bindable var settings = SettingsStore.shared
    @Bindable var appearance = AppearanceObserver.shared
    /// AppKit anchors behind the composer pills. `NSMenu.popUp` needs a view
    /// in the panel window to attach to; the holders carry it without ever
    /// invalidating SwiftUI state.
    @State var targetAnchor = MenuAnchorHolder()
    @State var providerAnchor = MenuAnchorHolder()
    @State var styleAnchor = MenuAnchorHolder()
    /// Shared by verb chips so the accent fill can travel between them.
    @Namespace var tabHighlight
    /// Set by ⌘L or the Refine button to show the collapsed composer. Reset
    /// on every open because the view is re-identified per panel session.
    @State var composerExpanded = false
    /// Result shows clean text with changed words lightly marked; this flips
    /// it to the full red/green diff. Per panel open.
    @State var showsFullDiff = false
    /// Last measured chrome bands, used to center idle copy in leftover height.
    @State var chromeTopHeight: CGFloat = 0
    @State var chromeBottomHeight: CGFloat = 0

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
            .overlay {
                if showsIdlePlaceholderOnly && !idleIsCompact {
                    idlePlaceholder(fillsBand: false)
                        .padding(.horizontal, PanelMetrics.moduleInset)
                        .offset(y: idleCopyOffsetY)
                        .allowsHitTesting(idlePlaceholderIsInteractive)
                }
            }
            .ignoresSafeArea()
            .tint(EnhancifyColor.accent)
            .id(appState.panelSessionID)
            .onPreferenceChange(PanelBandHeightKey.self, perform: publishLayoutHeights)
            .onChange(of: appState.selectedActionID) { _, actionID in
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
            // Tab / Shift-Tab: Enhance ⇄ Grammar. Reaches here when the
            // composer is not focused; the composer forwards its own Tab via
            // `onTab`, since an NSTextView consumes Tab before SwiftUI sees it.
            .onKeyPress(keys: [.tab], phases: .down) { _ in
                perform(resolveTabIntent())
            }
            .onKeyPress(characters: CharacterSet(charactersIn: "cl123456789"), phases: .down) { press in
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

    func resolveTabIntent() -> PanelKeyIntent {
        PanelKeyBinding.resolveTab(
            currentActionID: appState.selectedActionID,
            availableActionIDs: Set(panelTabs.map(\.id))
        )
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
        case .switchAction(let id):
            selectTab(id)
        case .showComposer:
            guard composerCollapsed else { return .ignored }
            composerExpanded = true
        case .pass:
            return .ignored
        }
        return .handled
    }

    /// Result band: intrinsic below the cap; fixed-height ScrollView at the cap
    /// so pinned chrome never leaves the window. `reportsPanelBand` measures the
    /// unconstrained card so a short seed window cannot lock the height.
    @ViewBuilder
    var resultSlot: some View {
        if showsIdlePlaceholderOnly {
            // Reserve the idle band for window sizing. The copy itself is
            // overlaid on the leftover gap between chips and composer so it
            // stays centered when the window is taller than chrome + idle.
            Color.clear
                .frame(height: idleIsCompact ? PanelMetrics.resultIdleCompactHeight : PanelMetrics.resultIdleMinHeight)
                .frame(maxWidth: .infinity)
                .reportsPanelBand(.result)
        } else {
            let measured = resultModule.reportsPanelBand(.result)

            if let scrollHeight = appState.panelResultScrollHeight {
                ScrollView {
                    measured
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: scrollHeight)
                .frame(maxWidth: .infinity)
            } else {
                measured
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    func publishLayoutHeights(_ bands: [PanelHeightBand: CGFloat]) {
        chromeTopHeight = bands[.chromeTop] ?? 0
        chromeBottomHeight = bands[.chromeBottom] ?? 0
        PanelControllerTrace.band("bands top=\(bands[.chromeTop] ?? -1) bottom=\(bands[.chromeBottom] ?? -1) result=\(bands[.result] ?? -1)")
        guard let layout = PanelLayoutHeights.fromBands(
            top: bands[.chromeTop] ?? 0,
            bottom: bands[.chromeBottom] ?? 0,
            result: bands[.result] ?? 0
        ) else { return }
        onLayoutHeights?(layout)
    }

    var closeStrip: some View {
        HStack(spacing: EnhancifySpace.xxs) {
            PanelCloseDot { engine.cancel() }
            Spacer(minLength: 0)
            PanelUpdateButton()
            PanelSettingsLink { engine.openSettings() }
        }
        .frame(height: PanelMetrics.closeStripHeight)
        .background(PanelDragRegion())
    }

    /// Nothing to show yet: no selection and no run. Drawn in a window
    /// overlay so leftover height after a tall response still centers it
    /// between chips and composer.
    var showsIdlePlaceholderOnly: Bool {
        guard case .idle = appState.resultState(for: appState.selectedActionID) else {
            return false
        }
        return !hasCapturedText
    }

    /// The composer is the empty state, so the idle band collapses to a
    /// sliver. Setup and Accessibility notices still get the full band —
    /// they need the room.
    var idleIsCompact: Bool {
        a11y.isAccessibilityTrusted
            && SettingsStore.shared.isConfigured(SettingsStore.shared.activeProvider)
    }

    /// Shift from the window center into the gap between top chrome and composer.
    var idleCopyOffsetY: CGFloat {
        let top = PanelMetrics.moduleInset + chromeTopHeight + PanelMetrics.moduleSpacing
        let bottom = PanelMetrics.moduleSpacing + chromeBottomHeight + PanelMetrics.moduleInset
        return (top - bottom) / 2
    }

    /// The notices carry buttons (Open System Settings, Connect a provider).
    var idlePlaceholderIsInteractive: Bool {
        !idleIsCompact
    }
}
