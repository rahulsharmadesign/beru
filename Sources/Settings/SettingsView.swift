import AppKit
import KeyboardShortcuts
import ServiceManagement
import SwiftUI

// The `SettingsView` that used to live here — an app-icon header over a
// six-tab `TabView`, sized to a fixed 460×430 window — is gone along with the
// `Settings` scene it filled. The dashboard's sidebar presents these same tabs
// now, so the container was the only part made redundant.
//
// The tabs themselves are unchanged and are no longer file-private, because
// `DashboardView` hosts them directly. Keeping them as the single definition of
// each control is the point: reimplementing them for the sidebar would have
// left two editors writing the same `SettingsStore` keys and drifting apart.

/// Provider rows used on Models. Same store as the rest of settings.
struct ProviderSettingsSections: View {
    @Bindable private var settings = SettingsStore.shared
    @State private var testState: TestState = .idle
    @State private var anthropicKey: String = ""
    @State private var customKey: String = ""
    @State private var apiPreset: CompatibleAPIPreset = .groq

    enum TestState: Equatable {
        case idle, testing, success, failure(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            SettingsSection(title: "Provider", subtitle: "Which backend Beru sends requests to.") {
                SettingsRow(
                    title: "Active provider",
                    caption: "Local Ollama stays on this Mac. Anthropic and API presets send requests to the host you configure."
                ) {
                    Picker("", selection: Binding(
                        get: { settings.activeProvider },
                        set: { settings.selectProvider($0) }
                    )) {
                        ForEach(ProviderKind.allCases, id: \.self) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .labelsHidden()
                    .accessibilityLabel("Active provider")
                    .pickerStyle(.menu)
                    .fixedSize()
                }
            }

            SettingsSection(title: "Configuration", subtitle: "Host, credentials, and model ids for the active provider.") {
                configurationRows
            }

            SettingsSection(title: "Connection", subtitle: "Verify the provider responds before you run.") {
                SettingsRow(title: "Test connection", caption: testCaption) {
                    HStack(spacing: 10) {
                        testStatusView
                        SettingsPillButton(title: "Test", enabled: testState != .testing) {
                            testConnection()
                        }
                    }
                }
            }
        }
        .onAppear {
            anthropicKey = settings.anthropicAPIKey ?? ""
            customKey = settings.customAPIKey ?? ""
            apiPreset = Self.detectPreset(baseURL: settings.customBaseURL)
            if settings.activeProvider == .custom, settings.customBaseURL.isEmpty {
                applyAPIPreset(.groq)
                apiPreset = .groq
            }
        }
        .onChange(of: settings.activeProvider) { _, kind in
            if kind == .custom, settings.customBaseURL.isEmpty {
                applyAPIPreset(.groq)
                apiPreset = .groq
            }
        }
        .onChange(of: anthropicKey) { _, newValue in
            settings.anthropicAPIKey = newValue
        }
        .onChange(of: customKey) { _, newValue in
            settings.customAPIKey = newValue
        }
        .onChange(of: settings.customEnhanceModel) { oldValue, newValue in
            if settings.customGrammarModel.isEmpty || settings.customGrammarModel == oldValue {
                settings.customGrammarModel = newValue
            }
        }
    }

    @ViewBuilder
    private var configurationRows: some View {
        switch settings.activeProvider {
        case .ollama:
            SettingsRow(title: "Base URL", caption: "Ollama or any compatible /v1 host.") {
                SettingsField(placeholder: "http://127.0.0.1:11434/v1", text: $settings.ollamaBaseURL, width: 260)
            }
            SettingsRow(title: "Enhance model") {
                SettingsField(placeholder: "qwen3:8b", text: $settings.ollamaEnhanceModel)
            }
            SettingsRow(title: "Grammar model") {
                SettingsField(placeholder: "qwen3:8b", text: $settings.ollamaGrammarModel)
            }
        case .anthropic:
            SettingsRow(title: "API key", caption: "Stored in the Keychain on this Mac.") {
                SettingsSecretField(placeholder: "sk-ant-…", text: $anthropicKey, width: 260)
            }
        case .custom:
            SettingsRow(
                title: "Preset",
                caption: "Groq, OpenAI, OpenRouter, LM Studio, or any OpenAI-compatible /v1 API."
            ) {
                Picker("", selection: $apiPreset) {
                    ForEach(CompatibleAPIPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .labelsHidden()
                .accessibilityLabel("API preset")
                .pickerStyle(.menu)
                .fixedSize()
                .onChange(of: apiPreset) { _, preset in
                    applyAPIPreset(preset)
                }
            }
            SettingsRow(title: "Base URL") {
                SettingsField(placeholder: "https://api.example.com/v1", text: $settings.customBaseURL, width: 260)
            }
            SettingsRow(title: "API key", caption: "Stored in the Keychain on this Mac.") {
                SettingsSecretField(placeholder: "sk-…", text: $customKey, width: 260)
            }
            SettingsRow(title: "Model") {
                SettingsField(placeholder: "Model id", text: $settings.customEnhanceModel)
            }
            SettingsRow(title: "Grammar model", caption: "Optional. Defaults to the same model.") {
                SettingsField(placeholder: "Optional", text: $settings.customGrammarModel)
            }
        }
    }

    private var testCaption: String {
        switch testState {
        case .idle: return "Sends a lightweight request to the selected provider."
        case .testing: return "Checking…"
        case .success: return "Connected."
        case .failure(let message): return message
        }
    }

    private func applyAPIPreset(_ preset: CompatibleAPIPreset) {
        guard preset != .custom else { return }
        settings.customBaseURL = preset.baseURL
        settings.customEnhanceModel = preset.defaultModel
        settings.customGrammarModel = preset.defaultModel
    }

    private static func detectPreset(baseURL: String) -> CompatibleAPIPreset {
        let url = baseURL.lowercased()
        if url.contains("api.groq.com") { return .groq }
        if url.contains("api.openai.com") { return .openAI }
        if url.contains("openrouter.ai") { return .openRouter }
        if url.isEmpty { return .groq }
        return .custom
    }

    @ViewBuilder
    private var testStatusView: some View {
        switch testState {
        case .idle:
            EmptyView()
        case .testing:
            ProgressView().controlSize(.small)
        case .success:
            BeruIcon(name: "circle-check", size: 16)
                .foregroundStyle(SettingsTheme.active)
        case .failure:
            BeruIcon(name: "circle-x", size: 16)
                .foregroundStyle(SettingsTheme.textSecondary)
        }
    }

    private func testConnection() {
        testState = .testing
        Task {
            let provider = ProviderRegistry.activeProvider(settings: settings)
            let result = await provider.testConnection()
            switch result {
            case .success:
                testState = .success
            case .failure(let error):
                testState = .failure(error.userMessage)
            }
        }
    }
}

struct GeneralSettingsTab: View {
    @Bindable private var settings = SettingsStore.shared

    var body: some View {
        SettingsPage(title: "General", subtitle: DashboardRoute.general.pageSubtitle) {
            SettingsSection(title: "Account", subtitle: "Profile details stored only on this Mac.") {
                SettingsRow(title: "Name", caption: "Used only for greetings on this Mac.") {
                    SettingsField(placeholder: "Your name", text: $settings.userName, alignment: .trailing)
                }
            }

            SettingsSection(title: "Accent", subtitle: "Primary color for selected controls and actions.") {
                SettingsRow(title: "Primary color", caption: "Selected controls, focus, and primary actions.") {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(22), spacing: 6), count: 6), spacing: 6) {
                        ForEach(PrimaryColor.allCases) { option in
                            Button {
                                settings.primaryColorID = option.rawValue
                            } label: {
                                ZStack {
                                    Circle().fill(option.color)
                                    if settings.primaryColorID == option.rawValue {
                                        BeruIcon(name: "check", size: 10)
                                            .foregroundStyle(option.selectedForeground)
                                    }
                                }
                                .frame(width: 18, height: 18)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(option.title)
                        }
                    }
                    .frame(width: 156, alignment: .trailing)
                }
            }

            SettingsSection(title: "Keyboard", subtitle: "Global shortcuts for opening Beru and dictation.") {
                SettingsRow(title: "Open Beru", caption: "Global hotkey. Select text first.") {
                    KeyboardShortcuts.Recorder(for: .invokeBeru)
                }
                SettingsRow(title: "Dictate", caption: "Opens Beru in Ask and starts listening. Press again, Escape, or the mic to stop.") {
                    KeyboardShortcuts.Recorder(for: .dictateToBeru)
                }
            }

            SettingsSection(title: "Startup", subtitle: "Launch behavior when you sign in.") {
                SettingsRow(title: "Run Beru at login", caption: "Start in the menu bar when you sign in.") {
                    SettingsSwitch(isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { enabled in
                            settings.launchAtLogin = enabled
                            applyLaunchAtLogin(enabled)
                        }
                    ), accessibilityLabel: "Run Beru at login")
                }
            }

            SettingsSection(title: "Panel", subtitle: "Default behavior for the floating composer.") {
                SettingsRow(title: "Default action", caption: "Used when enhancing the clipboard or a vault note.") {
                    Picker("", selection: $settings.defaultActionID) {
                        ForEach(ActionRegistry.shared.allActions) { action in
                            Text(action.name).tag(action.id)
                        }
                    }
                    .labelsHidden()
                    .accessibilityLabel("Default action")
                    .pickerStyle(.menu)
                    .fixedSize()
                }
                SettingsRow(
                    title: "Explain what changed",
                    caption: "A short rationale with the result. No extra round trip."
                ) {
                    SettingsSwitch(
                        isOn: $settings.explainChanges,
                        accessibilityLabel: "Explain what changed"
                    )
                }
            }
        }
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch { }
    }
}

struct HistorySettingsTab: View {
    @Bindable private var settings = SettingsStore.shared
    @State private var stats: UsageLogWriter.Stats?
    @State private var showClearConfirmation = false

    var body: some View {
        SettingsPage(title: "Data", subtitle: DashboardRoute.data.pageSubtitle) {
            SettingsSection(title: "Savings", subtitle: "Token estimates from accepted panel results.") {
                SavingsSummaryView(style: .plain)
            }

            SettingsSection(title: "Recording", subtitle: "Local usage history on this Mac.") {
                SettingsRow(
                    title: "Record usage on this Mac",
                    caption: "Off until you turn it on. Saves input and results locally. API keys are never recorded."
                ) {
                    SettingsSwitch(
                        isOn: $settings.usageLoggingEnabled,
                        accessibilityLabel: "Record usage on this Mac"
                    )
                }
                if let stats {
                    SettingsRow(title: "Entries") {
                        SettingsValue(text: "\(stats.entryCount)")
                    }
                    SettingsRow(title: "Size") {
                        SettingsValue(
                            text: ByteCountFormatter.string(fromByteCount: Int64(stats.totalBytes), countStyle: .file)
                        )
                    }
                    if let oldest = stats.oldestDate {
                        SettingsRow(title: "Oldest") {
                            SettingsValue(text: oldest.formatted(date: .abbreviated, time: .omitted))
                        }
                    }
                }
            }

            SettingsSection(title: "Retention", subtitle: "How long day-files are kept before deletion.") {
                SettingsRow(title: "Keep for", caption: "Whole day-files are deleted past this window.") {
                    Picker("", selection: $settings.historyRetentionDays) {
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                        Text("1 year").tag(365)
                        Text("Forever").tag(36_500)
                    }
                    .labelsHidden()
                    .accessibilityLabel("History retention")
                    .pickerStyle(.menu)
                    .fixedSize()
                }
            }

            SettingsSection(title: "Export", subtitle: "Browse or download recorded runs.") {
                SettingsRow(title: "Reveal in Finder", caption: "Opens the local history folder.") {
                    SettingsPillButton(title: "Reveal") {
                        let url = UsageLogWriter.shared.directoryURL
                        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
                SettingsRow(title: "Export JSONL") {
                    SettingsPillButton(title: "Export…", action: export)
                }
                SettingsRow(title: "Export CSV") {
                    SettingsPillButton(title: "Export…", action: exportCSV)
                }
            }

            SettingsSection(title: "Danger", subtitle: "Permanent actions that cannot be undone.") {
                SettingsRow(title: "Clear history", caption: "Deletes every recorded run. Cannot be undone.") {
                    SettingsPillButton(title: "Clear…", role: .destructive) {
                        showClearConfirmation = true
                    }
                }
            }
        }
        .task { await refreshStats() }
        .confirmationDialog(
            "Delete all recorded history?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    await UsageLogWriter.shared.clearAll()
                    await refreshStats()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    private func refreshStats() async {
        stats = await UsageLogWriter.shared.stats()
    }

    private func export() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "beru-history.jsonl"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            let data = await UsageLogWriter.shared.exportAll()
            try? data.write(to: url)
        }
    }

    /// Spreadsheet-friendly export of every session. Adds a CSV path alongside
    /// the raw JSONL so the history is usable by people who never want to see a
    /// JSON line.
    private func exportCSV() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "beru-history.csv"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            let runs = await UsageLogReader.shared.allRuns()
            let csv = Self.csv(from: runs)
            try? csv.data(using: .utf8)?.write(to: url)
        }
    }

    /// Rows for each session. Columns are what a spreadsheet user would filter
    /// for: when, which app, which action, which outcome, token accounting.
    private static func csv(from runs: [UsageRun]) -> String {
        var lines = [
            "Date,App,Action,Model,Outcome,Input chars,Output chars,Input tokens,Output tokens,Saved tokens,Generation count,Total ms,Input text,Output text"
        ]
        for run in runs {
            let date = run.startedAt.formatted(date: .abbreviated, time: .shortened)
            // Escape quotes and commas; cells that contain either get quoted.
            func cell(_ value: String?) -> String {
                guard let value, !value.isEmpty else { return "" }
                let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
                return escaped.contains(",") || escaped.contains("\n") ? "\"\(escaped)\"" : escaped
            }
            let tokens = [
                cell(run.hostAppName),
                cell(run.actionName),
                cell(run.model),
                cell(run.outcome.label),
                cell(run.inputText.count.description),
                cell(run.outputText.map { $0.count.description }),
                cell(run.inputTokens.map { $0.description }),
                cell(run.outputTokens.map { $0.description }),
                cell(run.savedTokens.map { $0.description }),
                cell(run.generationCount.description),
                cell(run.totalMs.map { $0.description }),
                cell(run.inputText),
                cell(run.outputText)
            ]
            lines.append("\(date),\(tokens.joined(separator: ","))")
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

struct PermissionsSettingsTab: View {
    @State private var isTrusted = Permissions.isAccessibilityTrusted()
    @State private var dictation = DictationService.shared

    var body: some View {
        SettingsPage(title: "Permissions", subtitle: DashboardRoute.permissions.pageSubtitle) {
            SettingsSection(title: "Accessibility", subtitle: "Required to read and replace text in other apps.") {
                SettingsRow(title: "Status", caption: "Required to read and replace selected text in other apps.") {
                    SettingsValue(text: isTrusted ? "Granted" : "Needed")
                }
                SettingsRow(title: "System Settings") {
                    SettingsPillButton(title: "Open") {
                        Permissions.openAccessibilitySettings()
                    }
                }
            }

            SettingsSection(title: "Dictation", subtitle: "On-device speech for panel instructions.") {
                SettingsRow(
                    title: "Status",
                    caption: dictation.availability.message
                        ?? "Speech is transcribed on this Mac. Beru will not fall back to Apple’s servers."
                ) {
                    SettingsValue(text: dictation.availability.isReady ? "Ready" : "Unavailable")
                }
                SettingsRow(title: dictation.availability == .needsPermission ? "Microphone" : "System Settings") {
                    if dictation.availability == .needsPermission {
                        SettingsPillButton(title: "Allow") {
                            Task { await dictation.requestPermissions() }
                        }
                    } else {
                        SettingsPillButton(title: "Open") {
                            Permissions.openPrivacySettings()
                        }
                    }
                }
            }
        }
        .task {
            while !Task.isCancelled {
                isTrusted = Permissions.isAccessibilityTrusted()
                dictation.refreshAvailability()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
}

// MARK: - About

/// Public identity for this build. Swap these URLs if the handles change.
enum BeruAbout {
    static let source = URL(string: "https://github.com/rahulsharmadesign/beru")!
    static let issues = URL(string: "https://github.com/rahulsharmadesign/beru/issues")!
    static let tip = URL(string: "https://razorpay.me/@rahulsharmadesign")!
}

struct AboutSettingsTab: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    private var copyright: String {
        let value = Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "© 2026 Rahul Sharma" : trimmed
    }

    var body: some View {
        SettingsPage(title: "About", subtitle: DashboardRoute.about.pageSubtitle) {
            identity

            SettingsSection(title: "This build") {
                SettingsRow(title: "Version") {
                    SettingsValue(text: "\(version) (\(build))", mono: true)
                }
                SettingsRow(title: "License", caption: copyright) {
                    SettingsValue(text: "MIT")
                }
            }

            SettingsSection(
                title: "Privacy",
                subtitle: "Beru does not phone home. Requests go only to the provider you configure."
            ) {
                SettingsFootnote(text: "No analytics, telemetry, or crash reporting. API keys stay in the Keychain. Usage history is off until you turn it on, and never leaves this Mac.")
            }

            SettingsSection(title: "Support", subtitle: "Optional. Nothing here is required to use Beru.") {
                SettingsRow(
                    title: "Send a tip",
                    caption: "Made with love, late-night curiosity, and an AI companion that never runs out of tokens."
                ) {
                    SettingsPrimaryButton(title: "Razorpay") {
                        NSWorkspace.shared.open(BeruAbout.tip)
                    }
                }
                SettingsRow(
                    title: "Source",
                    caption: "Code, license, and release notes."
                ) {
                    SettingsPillButton(title: "GitHub") {
                        NSWorkspace.shared.open(BeruAbout.source)
                    }
                }
                SettingsRow(
                    title: "Contact",
                    caption: "Bugs, ideas, and questions. GitHub issues is the inbox."
                ) {
                    SettingsPillButton(title: "Open") {
                        NSWorkspace.shared.open(BeruAbout.issues)
                    }
                }
            }
        }
    }

    private var identity: some View {
        HStack(alignment: .center, spacing: 16) {
            Image("BrandMark")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text("Beru")
                    .font(BeruSans.pageTitle)
                    .foregroundStyle(SettingsTheme.textPrimary)
                Text("A menu bar utility that refines selected text in any app.")
                    .font(BeruSans.rowCaption)
                    .foregroundStyle(SettingsTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Beru, a menu bar utility that refines selected text in any app.")
    }
}
