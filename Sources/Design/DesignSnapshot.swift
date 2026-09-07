#if DEBUG
import AppKit
import SwiftUI
import KeyboardShortcuts

// Offscreen render harness for visual QA. Launch the app with
// BERU_SNAPSHOT_DIR=<dir> to write PNGs of the shared components in both
// appearances, then quit. Lives in Design so it can size with tokens and
// render any component without feature stores. Not compiled in release.

@MainActor
enum DesignSnapshot {
    static func runIfRequested() {
        guard let dir = ProcessInfo.processInfo.environment["BERU_SNAPSHOT_DIR"] else { return }
        let root = URL(fileURLWithPath: dir)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            render(catalog, name: "controls-dark", appearance: .darkAqua, to: root)
            render(catalog, name: "controls-light", appearance: .aqua, to: root)
            render(rowsCatalog, name: "rows-dark", appearance: .darkAqua, to: root)
            render(rowsCatalog, name: "rows-light", appearance: .aqua, to: root)
            renderPage("general-dark", appearance: .darkAqua, to: root) { GeneralSettingsTab() }
            renderPage("permissions-dark", appearance: .darkAqua, to: root) { PermissionsSettingsTab() }
            renderPage("models-dark", appearance: .darkAqua, to: root) { ModelsView() }
            renderPage("data-dark", appearance: .darkAqua, to: root) { HistorySettingsTab() }
            renderPage("about-dark", appearance: .darkAqua, to: root) { AboutSettingsTab() }
            renderPage("actions-dark", appearance: .darkAqua, to: root) { ActionsView() }
            renderPage("targets-dark", appearance: .darkAqua, to: root) { TargetsView() }
            if ProcessInfo.processInfo.environment["BERU_SNAPSHOT_MENU"] != nil {
                openMenuAndCapture(to: root)
            }
            panelOverflowProbe(to: root)
        }
    }

    /// Repro probe: the real PanelView with a two-turn search thread inside a
    /// fixed frame, logging the band heights the controller would receive.
    /// Answers whether the measured ideal under-reports the real content.
    private static func panelOverflowProbe(to root: URL) {
        let appState = AppState()
        appState.selectedActionID = EnhancementAction.searchID
        appState.searchThread = [
            SearchThreadTurn(
                question: "what makes a good cup of coffee",
                answer: .done(
                    "Good coffee comes from balance: fresh beans roasted within the last month, " +
                    "ground just before brewing, water at 90-96 degrees C, and a ratio near 1:16. " +
                    "Brew method matters too - pour-over for clarity, immersion for body. " +
                    "Freshness dominates every other variable by a wide margin."
                )
            ),
            SearchThreadTurn(
                question: "what makes a bad one",
                answer: .done(
                    "Bad coffee is usually stale beans, a grind that is wrong for the method, " +
                    "water that is too hot or too cold, or a ratio that drifts. Bitterness comes " +
                    "from over-extraction, sourness from under-extraction, and staleness flattens " +
                    "everything into a papery, cardboard cup."
                )
            ),
        ]
        let engine = PanelEngine(appState: appState) {}
        var logged = "panel bands: "
        let view = PanelView(appState: appState, engine: engine, onLayoutHeights: { layout in
            logged += "controller<= chrome=\(Int(layout.chrome)) result=\(Int(layout.result)) ideal=\(Int(layout.ideal)); "
        })
            .onPreferenceChange(PanelBandHeightKey.self) { bands in
                let top = Int(bands[.chromeTop] ?? -1)
                let bottom = Int(bands[.chromeBottom] ?? -1)
                let result = Int(bands[.result] ?? -1)
                logged += "prefs[top=\(top) bottom=\(bottom) result=\(result)]; "
            }
        let seed = snap(view.frame(width: 420, height: 430).background(BeruColor.panelGradient))
        render(seed, name: "panel-seed", appearance: .darkAqua, to: root)
        let cap = snap(view.frame(width: 420, height: 900).background(BeruColor.panelGradient))
        render(cap, name: "panel-cap", appearance: .darkAqua, to: root)
        // Band callbacks arrive via DispatchQueue.main.async; give them a beat.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let logURL = root.appendingPathComponent("panel-bands.txt")
            try? logged.write(to: logURL, atomically: true, encoding: .utf8)
            exit(0)
        }
    }

    /// Open a real dropdown popup and snapshot the menu window, so the popup
    /// UI can be reviewed like every other component. Exits when done.
    private static func openMenuAndCapture(to root: URL) {
        let anchor = DropdownAnchorView(frame: NSRect(x: 40, y: 120, width: 180, height: BeruMetrics.pillHeight))
        let window = NSWindow(
            contentRect: NSRect(x: 80, y: 80, width: 420, height: 220),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "Beru"
        window.contentView?.addSubview(anchor)
        window.makeKeyAndOrderFront(nil)
        let capture = Timer(timeInterval: 0.8, repeats: false) { _ in
            for window in NSApp.windows {
                let kind = String(describing: type(of: window))
                guard kind.contains("DropdownPopup"), let content = window.contentView else { continue }
                content.layoutSubtreeIfNeeded()
                guard let rep = content.bitmapImageRepForCachingDisplay(in: content.bounds) else { continue }
                content.cacheDisplay(in: content.bounds, to: rep)
                if let png = rep.representation(using: .png, properties: [:]) {
                    try? png.write(to: root.appendingPathComponent("menu-open.png"))
                }
                break
            }
            exit(0)
        }
        RunLoop.main.add(capture, forMode: .common)
        anchor.open(
            [
                DropdownItem(title: "30 days", isOn: true) {},
                DropdownItem(title: "90 days") {},
                DropdownItem(title: "1 year") {},
                DropdownItem(title: "Forever") {},
            ],
            preferred: 0
        )
    }

    /// Render a real dashboard page at detail-pane size.
    private static func renderPage(
        _ name: String,
        appearance: NSAppearance.Name,
        to root: URL,
        @ViewBuilder page: () -> some View
    ) {
        let view = snap(
            page()
                .frame(width: BeruMetrics.windowWidth - BeruMetrics.sidebarWidth, height: 700)
                .background(BeruColor.canvas)
        )
        render(view, name: name, appearance: appearance, to: root)
    }

    private static func render(_ view: NSView, name: String, appearance: NSAppearance.Name, to root: URL) {
        view.appearance = NSAppearance(named: appearance)
        view.layoutSubtreeIfNeeded()
        let size = view.fittingSize
        // Host in an offscreen window: AppKit-backed views (List tables,
        // recorders) only draw their full hierarchy when a window owns them.
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = view
        view.frame = NSRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        // Deferred SwiftUI state writes (band preferences, async layout
        // callbacks) only flush in a visible window.
        window.orderFront(nil)
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: root.appendingPathComponent("\(name).png"))
    }

    private static func snap(_ content: some View) -> NSView {
        NSHostingView(rootView: AnyView(content))
    }

    // MARK: - Catalogs

    private static var catalog: NSView {
        snap(
            VStack(alignment: .leading, spacing: BeruSpace.lg) {
                VStack(alignment: .leading, spacing: BeruSpace.sm) {
                    Text("Menu picker").font(BeruType.section)
                    HStack(spacing: BeruSpace.md) {
                        SettingsMenuPicker(
                            selection: .constant("grammar"),
                            options: [
                                SettingsPickerOption(value: "grammar", title: "Grammar"),
                                SettingsPickerOption(value: "enhance", title: "Enhance Prompt"),
                            ],
                            accessibilityLabel: "Default action"
                        )
                        SettingsMenuPill(
                            label: "Any action",
                            items: [
                                DropdownItem(title: "Any action", isOn: true) {},
                                DropdownItem(title: "Grammar") {},
                            ]
                        )
                        SettingsOverflowMenu(
                            title: "More",
                            items: [
                                DropdownItem(title: "Import") {},
                                DropdownItem(title: "Export") {},
                            ]
                        )
                        SettingsSegmented(
                            selection: .constant("notes"),
                            options: [
                                SettingsPickerOption(value: "notes", title: "Notes"),
                                SettingsPickerOption(value: "pins", title: "Pins"),
                            ],
                            accessibilityLabel: "Pane"
                        )
                    }
                }

                VStack(alignment: .leading, spacing: BeruSpace.sm) {
                    Text("Buttons").font(BeruType.section)
                    HStack(spacing: BeruSpace.md) {
                        SettingsPrimaryButton(title: "Check", icon: "sparkles") {}
                        SettingsPillButton(title: "Reveal", leadingIcon: "folder") {}
                        SettingsPillButton(title: "Export", leadingIcon: "square.and.arrow.up") {}
                        SettingsPillButton(title: "Clear…", role: .destructive) {}
                    }
                }

                VStack(alignment: .leading, spacing: BeruSpace.sm) {
                    Text("Fields").font(BeruType.section)
                    HStack(spacing: BeruSpace.md) {
                        SettingsField(placeholder: "Your name", text: .constant("Rahul"))
                        SettingsSecretField(placeholder: "sk-ant-…", text: .constant("secret"))
                        SettingsSearchField(text: .constant(""))
                    }
                    SettingsShortcutRecorder(name: .invokeBeru)
                }

                VStack(alignment: .leading, spacing: BeruSpace.sm) {
                    Text("Chips").font(BeruType.section)
                    HStack(spacing: BeruSpace.md) {
                        BeruChip(icon: "wand-sparkles", title: "Fix grammar")
                        BeruChip(icon: "messages-square", title: "Write replies")
                        BeruKbd(text: "⌃⌥⌘P")
                        BeruKbd(text: "⌃⌥⌘P", tone: .onAccent)
                    }
                }

                VStack(alignment: .leading, spacing: BeruSpace.sm) {
                    Text("Status").font(BeruType.section)
                    SettingsStatusCard(
                        icon: "accessibility",
                        title: "Accessibility",
                        badgeTitle: "Granted",
                        isPositive: true,
                        message: "Required to read and replace text in other apps."
                    ) {
                        SettingsPillButton(title: "Open") {}
                    }
                    SettingsStatusCard(
                        icon: "mic",
                        title: "Dictation",
                        badgeTitle: "Needed",
                        isPositive: false,
                        message: "Speech is transcribed on this Mac."
                    ) {
                        SettingsPrimaryButton(title: "Grant") {}
                    }
                }

                VStack(alignment: .leading, spacing: BeruSpace.sm) {
                    Text("Pixel loaders").font(BeruType.section)
                    HStack(spacing: BeruSpace.lg) {
                        PixelGridLoader(variant: .drive)
                        PixelGridLoader(variant: .dots)
                        PixelGridLoader(variant: .orbit)
                        PixelLoadingState(label: "Thinking…")
                    }
                }

                VStack(alignment: .leading, spacing: BeruSpace.sm) {
                    Text("Accent swatches").font(BeruType.section)
                    SettingsAccentSwatches(selection: .constant(.indigo))
                }

                HStack(spacing: BeruSpace.lg) {
                    ForEach([(BorderBeamPalette.mono, 0.4), (BorderBeamPalette.colorful, 0.6)], id: \.0) { pair in
                        ZStack {
                            RoundedRectangle(cornerRadius: BeruRadius.lg, style: .continuous)
                                .fill(BeruColor.panelSolid)
                            BorderBeam(
                                shape: BeruRadius.shape(BeruRadius.lg),
                                palette: pair.0,
                                strength: pair.1
                            )
                        }
                        .frame(width: 160, height: 90)
                    }
                }

                SettingsSection(title: "Danger", subtitle: "Permanent actions that cannot be undone.", tone: .danger) {
                    SettingsRow(title: "Clear history") {
                        SettingsPillButton(title: "Clear…", role: .destructive) {}
                    }
                }
            }
            .padding(BeruSpace.lg)
            .frame(width: BeruMetrics.formMaxWidth)
            .background(BeruColor.canvas)
        )
    }

    private static var rowsCatalog: NSView {
        let selection = Binding<String?>(get: { nil }, set: { _ in })
        let picked = Binding<String?>(get: { "note-1" }, set: { _ in })
        return snap(
            List {
                Section("Rows unselected") {
                    ForEach(0..<3, id: \.self) { index in
                        WorkspaceListRow(
                            title: index == 0 ? "Run" : "Enhance Prompt",
                            subtitle: index == 0 ? nil : "Rewrite your rough idea into a clear, effective prompt for an AI.",
                            icon: index == 0 ? "history" : "sparkles",
                            accessory: { Text("11:47 PM") }
                        )
                        .workspaceRowSelection(selection, value: "row-\(index)", isSelected: false)
                    }
                }
                Section("Rows selected") {
                    WorkspaceListRow(
                        title: "Welcome",
                        subtitle: "# Welcome to your vault",
                        icon: "sticky-note",
                        accessory: { Text("4 days, 1 hr ago") }
                    )
                    .workspaceRowSelection(picked, value: "note-1", isSelected: true)
                    WorkspaceListRow(
                        title: "Second note",
                        subtitle: "Another note body line",
                        icon: "sticky-note",
                        accessory: { Text("2 days") }
                    )
                    .workspaceRowSelection(picked, value: "note-2", isSelected: false)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .frame(width: BeruMetrics.workspaceListWidth + BeruSpace.xl, height: 420)
            .background(BeruColor.canvas)
        )
    }
}

#endif
