import AppKit
import SwiftUI

struct PanelView: View {
    @Bindable var appState: AppState
    let engine: PanelEngine
    let onHeightChange: (CGFloat) -> Void
    @FocusState private var describeFieldFocused: Bool
    @State private var registry = ActionRegistry.shared
    @State private var chipFrames: [String: CGRect] = [:]
    @State private var accessibilityTrusted = Permissions.isAccessibilityTrusted()
    private var targetRegistry = TargetRegistry.shared
    private var a11y = AccessibilityPreferences.shared

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
        // The frosting value is read from SettingsStore here and injected via
        // the environment so every glass module shares one value without each
        // subscribing to the full observable store. When the dashboard slider
        // changes frosting while the panel is visible, the re-render is cheap:
        // only gradient fills change, not layout or text content.
        let frosting = SettingsStore.shared.panelFrosting
        let _ = SettingsStore.shared.primaryColorID
        let _ = SettingsStore.shared.activeProvider
        let _ = AppearanceObserver.shared.signature

        VStack(spacing: 0) {
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
        .background(BrandColors.canvas)
        .background(PanelDragRegion())
        .environment(\.panelFrosting, frosting)
        .tint(BrandColors.accentColor)
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
    private var closeStrip: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            PanelUpdateButton()
            PanelCloseDot { engine.cancel() }
        }
        .padding(.trailing, 4)
        .frame(height: PanelMetrics.closeStripHeight)
        .background(PanelDragRegion())
    }

    // MARK: - Toolbar (verbs + context)

    /// Single top module: verb chips + one quiet metadata line.
    private var toolbar: some View {
        VStack(alignment: .leading, spacing: 8) {
            verbRow
            if !appState.isQuickSearch || hasCapturedText {
                contextLine
                    .transition(.opacity)
            }
        }
        .padding(PanelMetrics.moduleInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PanelDragRegion())
        .animation(tabAnimation, value: appState.selectedActionID)
    }

    private var hasCapturedText: Bool {
        !appState.capturedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// AI Search is pinned first. Registry skills follow. Instruction only
    /// appears while a one-off describe is active.
    private var panelTabs: [EnhancementAction] {
        var tabs = [EnhancementAction.search]
        if appState.selectedActionID == EnhancementAction.describeID {
            tabs.append(EnhancementAction.describe)
        }
        tabs.append(contentsOf: registry.allActions)
        return tabs
    }

    private var verbRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                tabSelectionPill
                HStack(spacing: 6) {
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
    private var tabSelectionPill: some View {
        if let frame = chipFrames[appState.selectedActionID] {
            Capsule()
                .fill(BrandColors.accentColor)
                .frame(width: frame.width, height: frame.height)
                .offset(x: frame.minX, y: frame.minY)
                .shadow(
                    color: a11y.reduceTransparency ? .clear : BrandColors.accentColor.opacity(0.18),
                    radius: 5,
                    y: 2
                )
                .allowsHitTesting(false)
        }
    }

    private var tabAnimation: Animation {
        a11y.reduceMotion
            ? .easeOut(duration: 0.12)
            : .easeInOut(duration: 0.28)
    }

    private func selectTab(_ actionID: String) {
        withAnimation(tabAnimation) {
            appState.selectAction(actionID)
        }
    }

    private func chip(for action: EnhancementAction) -> some View {
        let isSelected = appState.selectedActionID == action.id
        return Button {
            selectTab(action.id)
        } label: {
            BeruLabel(title: action.name, icon: action.icon, iconSize: 14, strokeWidth: 2)
                .labelStyle(.titleAndIcon)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
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
    private var contextLine: some View {
        HStack(spacing: 6) {
            Text(contextSummary)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            if appState.clipboardText != nil {
                Button {
                    appState.includeClipboard.toggle()
                } label: {
                    Text(appState.includeClipboard ? "Clipboard ✓" : "Clipboard")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(appState.includeClipboard ? BrandColors.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .help(appState.includeClipboard
                      ? "Clipboard will be sent as reference"
                      : "Include clipboard as reference")
            }
        }
    }

    private var contextSummary: String {
        let app = appState.hostAppName ?? "Mac"
        let trimmed = appState.capturedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "\(app) · No text selected"
        }
        return "\(app) · \(trimmed.count) characters"
    }

    // MARK: - Result

    private var resultModule: some View {
        VStack(alignment: .leading, spacing: 0) {
            if appState.truncationNotice {
                truncationBanner.contributesPanelHeight()
            }
            resultArea
            if let rationale = appState.rationales[appState.selectedActionID],
               case .done = appState.resultState(for: appState.selectedActionID) {
                RationaleNote(text: rationale)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(tabAnimation, value: appState.selectedActionID)
        .glassModule(scrim: .content)
    }

    @ViewBuilder
    private var resultArea: some View {
        let state = appState.resultState(for: appState.selectedActionID)
        VStack(alignment: .trailing, spacing: 0) {
            if case .done = state,
               appState.cleanNotices.contains(appState.selectedActionID) {
                VStack(alignment: .leading, spacing: 0) {
                    noticeLine(
                        appState.selectedActionID == EnhancementAction.grammarID
                            ? "No spelling, grammar or punctuation errors found — your text is unchanged"
                            : "The model returned your text unchanged"
                    )
                    ResultView(state: state)
                }
            } else if case .done(let revised) = state,
                      appState.diffs[appState.selectedActionID] != nil {
                diffResult(revised: revised)
            } else if case .done = state,
                      appState.heavyRewriteNotices.contains(appState.selectedActionID) {
                VStack(alignment: .leading, spacing: 0) {
                    rewrittenNotice
                    ResultView(state: state)
                }
            } else if case .error(let message) = state {
                errorView(message: message)
            } else if case .idle = state,
                      appState.selectedActionID == EnhancementAction.describeID
                        || appState.selectedActionID == EnhancementAction.searchID
                        || appState.capturedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                idlePlaceholder
            } else {
                ResultView(state: state)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .id(appState.selectedActionID)
        .transition(.opacity)
    }

    @ViewBuilder
    private var idlePlaceholder: some View {
        if !accessibilityTrusted {
            accessibilityPlaceholder
        } else {
            let needsSetup = appState.selectedActionID == EnhancementAction.searchID
                && !SettingsStore.shared.isConfigured(SettingsStore.shared.activeProvider)
            if needsSetup {
                providerSetupPlaceholder
            } else {
                regularIdlePlaceholder
            }
        }
    }

    private var accessibilityPlaceholder: some View {
        VStack(spacing: 10) {
            Text("Allow Accessibility")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary.opacity(0.85))
            Text("Beru needs Accessibility to read and replace selected text in other apps.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open System Settings") {
                Permissions.requestAccessibilityIfNeeded()
                Permissions.openAccessibilitySettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PanelDragRegion())
    }

    private var regularIdlePlaceholder: some View {
        let actionID = appState.selectedActionID
        let name = registry.action(withID: actionID)?.name
            ?? (actionID == EnhancementAction.searchID ? "AI Search" : "This action")
        let copy = EnhancementAction.emptyCaptureCopy(actionID: actionID, actionName: name)
        return VStack(spacing: 6) {
            Text(copy.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary.opacity(0.85))
            Text(copy.subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PanelDragRegion())
    }

    private var providerSetupPlaceholder: some View {
        VStack(spacing: 10) {
            Text("Choose your AI model")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary.opacity(0.85))
            Text("Connect an AI provider or choose a local model to start using Beru.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 8) {
                Button("Connect a provider") {
                    engine.requestProviderSetup(preferLocal: false)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                Button("Use a local model") {
                    engine.requestProviderSetup(preferLocal: true)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PanelDragRegion())
    }

    private var truncationBanner: some View {
        Text("Selection was truncated to \(PanelEngine.maxCapturedLength) characters")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rewrittenNotice: some View {
        noticeLine(
            appState.selectedActionID == EnhancementAction.grammarID
                ? "Rewritten rather than corrected, so there's no diff to show — Regenerate if you only wanted corrections"
                : "Rewritten from scratch, so there's no useful diff to show"
        )
    }

    private func noticeLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contributesPanelHeight()
    }

    @ViewBuilder
    private func diffResult(revised: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if appState.restyledNotices.contains(appState.selectedActionID) {
                noticeLine("Some of these swap correct words for different ones rather than fixing errors — Regenerate to try again")
            }
            DiffView(
                ops: appState.diffs[appState.selectedActionID],
                revised: revised,
                showDiff: true
            )
        }
    }

    private func errorView(message: String) -> some View {
        let actionID = appState.selectedActionID
        let fallbacks = SettingsStore.shared.fallbackProviders
        return VStack(spacing: 10) {
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                Button("Retry") { engine.retry(actionID: actionID) }
                    .controlSize(.small)

                // If another provider is configured, offer it here so a failed
                // request doesn't dead-end the user into opening Settings.
                ForEach(fallbacks, id: \.self) { kind in
                    Button(fallbackLabel(for: kind)) {
                        engine.retryWithProvider(kind, actionID: actionID)
                    }
                    .controlSize(.small)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    /// Short label for the "Try with [X]" button. Takes the first word of the
    /// provider's title, so "API (Groq, OpenAI, …)" reads as "Try with API".
    private func fallbackLabel(for kind: ProviderKind) -> String {
        let title = kind.title
        let firstWord = title.split(separator: " ").first.map(String.init) ?? title
        return "Try with \(firstWord)"
    }

    // MARK: - Footer / composer

    private var hasFinishedResult: Bool {
        if case .done = appState.resultState(for: appState.selectedActionID) { return true }
        return false
    }

    /// Outcome strip sits behind the composer and only appears once a result
    /// is in — token pill plus Replace / Copy / Pin, no dismiss control.
    private var composerColumn: some View {
        VStack(spacing: hasFinishedResult ? -PanelMetrics.composerOverlap : 0) {
            if hasFinishedResult {
                footer
                    .glassModule()
                    .fixedSize(horizontal: false, vertical: true)
                    .zIndex(0)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            intentField
                .glassModule(radius: PanelMetrics.composerRadius, focusRing: describeFieldFocused)
                .fixedSize(horizontal: false, vertical: true)
                .zIndex(1)
        }
        .animation(tabAnimation, value: hasFinishedResult)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if let savings = appState.savings[appState.selectedActionID] {
                SavingsPill(savings: savings)
                    .transition(.opacity)
            }

            if let provenance = contextProvenance {
                Text(provenance)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help("Local context applied to this result")
            }
            Spacer()

            if appState.copiedFeedback {
                Text("Copied")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }

            if appState.pinnedFeedback {
                Text("Pinned")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }

            Button(appState.vaultNoteID == nil ? "Replace" : "Apply") { performReplace() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help(
                    appState.vaultNoteID == nil
                        ? "Replace the selection (Cmd-Return)"
                        : "Write this result back into the vault note (Cmd-Return)"
                )

            Button("Copy") { performCopy() }
                .buttonStyle(.bordered)
                .controlSize(.small)

            Button("Pin") { performPin() }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Save this result in the vault")
        }
        .padding(.horizontal, PanelMetrics.moduleInset)
        .padding(.top, 6)
        .padding(.bottom, PanelMetrics.composerOverlap + 6)
        .frame(minHeight: PanelMetrics.footerMinHeight, alignment: .center)
        .frame(maxWidth: .infinity)
    }

    private var contextProvenance: String? {
        guard let context = appState.contextApplications[appState.selectedActionID] else { return nil }
        if let playbook = context.playbook { return "Playbook: \(playbook.name)" }
        if !context.rules.isEmpty { return "Rules: \(context.rules.count)" }
        if let workspace = context.workspace, workspace.hasMemory { return "Workspace: \(workspace.name)" }
        return context.glossary.isEmpty ? nil : "Glossary"
    }

    private var isErrorState: Bool {
        if case .error = appState.resultState(for: appState.selectedActionID) { return true }
        return false
    }

    private var intentField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                BeruIcon(
                    name: appState.isQuickSearch ? "search" : "sparkles",
                    size: 16
                )
                .foregroundStyle(.secondary)
                TextField(composerPlaceholder, text: $appState.describeInstruction)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($describeFieldFocused)
                    .onSubmit { submitDescribe() }
            }
            HStack(spacing: 8) {
                if targetPickerVisible {
                    targetMenu
                } else {
                    providerMenu
                }
                PanelIconHitButton(
                    icon: "rotate-cw",
                    help: "Regenerate",
                    hint: "Run this action again on the same input",
                    enabled: hasFinishedResult || isErrorState
                ) {
                    engine.retry(actionID: appState.selectedActionID)
                }
                Spacer(minLength: 8)
                DictationButton(onNeedsPermission: { engine.requestDictationPermission() })
                sendButton
            }
        }
        .padding(.horizontal, PanelMetrics.moduleInset)
        .padding(.vertical, 8)
        .frame(minHeight: PanelMetrics.composerMinHeight, alignment: .center)
        .frame(maxWidth: .infinity)
        .animation(tabAnimation, value: appState.isQuickSearch)
    }

    private var sendButton: some View {
        Button {
            guard canSubmitDescribe else { return }
            submitDescribe()
        } label: {
            ZStack {
                Circle()
                    .fill(canSubmitDescribe ? BrandColors.accentColor : Color.primary.opacity(0.14))
                BeruIcon(name: "arrow-up", size: 15, strokeWidth: 2.4)
                    .foregroundStyle(canSubmitDescribe ? Color.white : Color.secondary)
            }
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.12), value: canSubmitDescribe)
        .help("Run this intent")
        .accessibilityLabel("Run this intent")
        .accessibilityHint("Send the instruction to Beru")
    }

    private var composerPlaceholder: String {
        if appState.isQuickSearch || appState.selectedActionID == EnhancementAction.searchID {
            return "Ask a question…"
        }
        if appState.capturedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Or type a question to search…"
        }
        return "Optional instruction for this action…"
    }

    private var canSubmitDescribe: Bool {
        !appState.describeInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submitDescribe() {
        if appState.selectedActionID == EnhancementAction.searchID || appState.isQuickSearch {
            engine.runQuickSearch(query: appState.describeInstruction)
        } else {
            engine.runDescribe(instruction: appState.describeInstruction)
        }
    }

    private var targetPickerVisible: Bool {
        guard !appState.isQuickSearch,
              let action = registry.action(withID: appState.selectedActionID) else { return false }
        return Prompts.targetApplies(
            actionID: action.id, role: action.role, usesBuiltInPrompt: action.isBuiltIn
        )
    }

    private var targetMenu: some View {
        let active = targetRegistry.profile(withID: appState.selectedTargetID)
        return composerPickerPill(
            icon: active?.icon ?? "circle-dashed",
            title: active?.name ?? "Generic",
            help: "Which AI this prompt is written for",
            accessibilityLabel: "Target, \(active?.name ?? "Generic")",
            accessibilityHint: "Choose which AI this prompt is written for",
            action: presentTargetMenu
        )
    }

    private var providerMenu: some View {
        let kind = SettingsStore.shared.activeProvider
        return composerPickerPill(
            icon: kind.composerIcon,
            title: kind.composerTitle,
            help: "Change the active provider",
            accessibilityLabel: "Active provider, \(kind.title)",
            accessibilityHint: "Choose which AI provider Beru sends requests to",
            action: presentProviderMenu
        )
    }

    private func composerPickerPill(
        icon: String,
        title: String,
        help: String,
        accessibilityLabel: String,
        accessibilityHint: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                BeruIcon(name: icon, size: 12, strokeWidth: 2)
                    .foregroundStyle(BrandColors.accentColor)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                BeruIcon(name: "chevron-down", size: 10, strokeWidth: 2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background {
                Capsule()
                    .fill(Color.primary.opacity(0.05))
                    .overlay(Capsule().strokeBorder(BrandColors.border, lineWidth: 1))
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .help(help)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    /// `NSMenu.popUp` works in a non-activating panel. SwiftUI `Menu` does not —
    /// the control draws, but the menu never appears, so the picker looks dead.
    private func presentTargetMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let selectedID = appState.selectedTargetID
        TargetMenuRelay.shared.onPick = { id in
            selectTarget(id)
        }
        for profile in targetRegistry.profiles {
            let item = NSMenuItem(
                title: profile.name,
                action: #selector(TargetMenuRelay.pick(_:)),
                keyEquivalent: ""
            )
            item.target = TargetMenuRelay.shared
            item.representedObject = profile.id
            item.state = profile.id == selectedID ? .on : .off
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    private func presentProviderMenu() {
        let settings = SettingsStore.shared
        let menu = NSMenu()
        menu.autoenablesItems = false
        let selected = settings.activeProvider
        PanelProviderMenuRelay.shared.onPick = { kind in
            settings.selectProvider(kind)
        }
        for kind in ProviderKind.allCases {
            let item = NSMenuItem(
                title: kind.title,
                action: #selector(PanelProviderMenuRelay.pick(_:)),
                keyEquivalent: ""
            )
            item.target = PanelProviderMenuRelay.shared
            item.representedObject = kind.rawValue
            item.state = kind == selected ? .on : .off
            item.isEnabled = settings.isConfigured(kind)
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    private func selectTarget(_ targetID: String) {
        guard targetID != appState.selectedTargetID else { return }
        appState.selectTarget(targetID)
        let actionID = appState.selectedActionID
        appState.results.removeValue(forKey: actionID)
        engine.startIfNeeded(actionID: actionID)
    }

    private func performReplace() {
        guard case .done(let text) = appState.resultState(for: appState.selectedActionID) else { return }
        engine.replace(text: text)
    }

    private func performCopy() {
        guard case .done(let text) = appState.resultState(for: appState.selectedActionID) else { return }
        engine.copy(text: text)
    }

    private func performPin() {
        guard case .done(let text) = appState.resultState(for: appState.selectedActionID) else { return }
        engine.pin(text: text)
    }
}

/// Target of `NSMenuItem` actions. SwiftUI views cannot be `@objc` targets.
private final class TargetMenuRelay: NSObject {
    static let shared = TargetMenuRelay()
    var onPick: ((String) -> Void)?

    @objc func pick(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        onPick?(id)
    }
}

private final class PanelProviderMenuRelay: NSObject {
    static let shared = PanelProviderMenuRelay()
    var onPick: ((ProviderKind) -> Void)?

    @objc func pick(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let kind = ProviderKind(rawValue: raw) else { return }
        onPick?(kind)
    }
}

private extension ProviderKind {
    var composerTitle: String {
        switch self {
        case .ollama: return "Ollama"
        case .anthropic: return "Anthropic"
        case .custom: return "API"
        }
    }

    var composerIcon: String {
        switch self {
        case .ollama: return "cpu"
        case .anthropic: return "sparkle"
        case .custom: return "cloud"
        }
    }
}

/// Solid Update pill, left of the close disc. Hidden unless a newer release exists.
private struct PanelUpdateButton: View {
    @State private var updates = AppUpdateService.shared

    var body: some View {
        if updates.showsUpdateButton {
            ZStack {
                DictationPressView {
                    guard !updates.isBusy else { return }
                    updates.install()
                }
                Text(updates.buttonTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(BrandColors.accentColor))
                    .allowsHitTesting(false)
            }
            .fixedSize()
            .help(updates.availableVersion.map { "Install Beru \($0)" } ?? "Install the latest Beru")
            .accessibilityLabel("Update")
            .accessibilityAddTraits(.isButton)
        }
    }
}

/// AppKit click target so the panel's window-drag hit test leaves footer icons
/// alone — the same reason the mic is an `NSView` instead of a SwiftUI `Button`.
private struct PanelIconHitButton: View {
    let icon: String
    let help: String
    var hint: String = ""
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        ZStack {
            DictationPressView(onToggle: { if enabled { action() } })
            BeruIcon(name: icon, size: 16)
                .foregroundStyle(.primary)
                .opacity(enabled ? 1 : 0.35)
                .allowsHitTesting(false)
        }
        .frame(width: 28, height: 28)
        .contentShape(Rectangle())
        .help(help)
        .accessibilityLabel(help)
        .accessibilityHint(hint)
        .accessibilityAddTraits(.isButton)
    }
}

private struct ChipFramesKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

/// Empty chrome that reports itself as the window-move target. Sits behind
/// chips and text so those keep their clicks.
private struct PanelDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = WindowMoveView()
        view.autoresizingMask = [.width, .height]
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class WindowMoveView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDown(with event: NSEvent) {
        beruBeginWindowDrag(with: event)
    }
}
