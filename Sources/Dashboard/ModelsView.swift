import SwiftUI

struct ModelsView: View {
    @Bindable private var settings = SettingsStore.shared
    @Bindable private var pull = OllamaPullService.shared
    @State private var installed: [OllamaAdmin.Model] = []
    @State private var listState: ListState = .loading
    @State private var setupState: OllamaSetupState = .notInstalled

    private enum ListState: Equatable {
        case loading
        case ready
        case unreachable(String)
        case notOllama
    }

    private static let recommended = RecommendedOllamaModel.all

    private var admin: OllamaAdmin {
        OllamaAdmin(baseURL: settings.ollamaBaseURL)
    }

    var body: some View {
        SettingsPage(
            title: DashboardRoute.models.title,
            subtitle: DashboardRoute.models.pageSubtitle,
            icon: DashboardRoute.models.lucideIcon
        ) {
            if settings.activeProvider == .ollama {
                localSection
                installSection
            }
            ProviderSettingsSections()
        }
        .task(id: "\(settings.activeProvider.rawValue)|\(settings.ollamaBaseURL)") {
            await refresh()
            while !Task.isCancelled, settings.activeProvider == .ollama, setupState != .running {
                try? await Task.sleep(for: .seconds(2))
                await refresh(showLoading: false)
            }
        }
        // Pulls live on OllamaPullService so leaving this page does not cancel them.
        .onChange(of: pull.pulling) { wasPulling, isPulling in
            if wasPulling != nil, isPulling == nil {
                Task { await refresh() }
            }
        }
    }

    @ViewBuilder
    private var localSection: some View {
        if settings.activeProvider == .ollama, listState == .ready {
            modelFitBanner
        }
        SettingsSection(title: "On this Mac") {
            switch listState {
            case .loading:
                SettingsRow(title: "Installed models", caption: "Looking for models on the local server.") {
                    BeruLoader.compact()
                }
            case .notOllama:
                SettingsRow(
                    title: "Installed models",
                    caption: "Model management needs an Ollama-style /v1 base URL."
                ) {
                    SettingsValue(text: "Unavailable")
                }
            case .unreachable(let host):
                SettingsRow(
                    title: "Server",
                    caption: "Install or open Ollama below, then pick a model."
                ) {
                    SettingsValue(text: host)
                }
            case .ready where installed.isEmpty:
                SettingsRow(
                    title: "Installed models",
                    caption: "Server is running, but nothing is installed yet."
                ) {
                    SettingsValue(text: "None")
                }
            case .ready:
                ForEach(installed) { model in
                    SettingsRow(
                        title: model.name,
                        caption: modelCaption(model)
                    ) {
                        SettingsOverflowMenu(
                            title: "Use for",
                            items: [
                                DropdownItem(
                                    title: "Enhance",
                                    isOn: settings.ollamaEnhanceModel == model.name
                                ) { settings.ollamaEnhanceModel = model.name },
                                DropdownItem(
                                    title: "Grammar",
                                    isOn: settings.ollamaGrammarModel == model.name
                                ) { settings.ollamaGrammarModel = model.name },
                                DropdownItem(
                                    title: "Both",
                                    isOn: settings.ollamaEnhanceModel == model.name
                                        && settings.ollamaGrammarModel == model.name
                                ) {
                                    settings.ollamaEnhanceModel = model.name
                                    settings.ollamaGrammarModel = model.name
                                },
                            ]
                        )
                    }
                }
            }
        }
    }

    /// Warns when a text role runs on a vision/embedding/speech model, with a
    /// one-tap move to the first installed text model. Nothing renders when
    /// both roles are well served.
    @ViewBuilder
    private var modelFitBanner: some View {
        let weakRoles = OllamaModelFit.weakRoles(
            enhanceModel: settings.ollamaEnhanceModel,
            grammarModel: settings.ollamaGrammarModel
        )
        if !weakRoles.isEmpty {
            let offender = settings.ollamaEnhanceModel.isEmpty
                ? settings.ollamaGrammarModel
                : settings.ollamaEnhanceModel
            let noun = OllamaModelFit.fit(for: offender).articleNoun ?? "a weak model for text"
            SettingsStatusCard(
                icon: "info",
                title: "Weak model for \(weakRoles.joined(separator: " + "))",
                badgeTitle: "Check",
                isPositive: false,
                message: "\(offender) is \(noun), so replies, corrections, and enhanced prompts will be poor."
            ) {
                if let suggestion = suggestedTextModel {
                    SettingsPillButton(title: "Use \(suggestion) for Both") {
                        settings.ollamaEnhanceModel = suggestion
                        settings.ollamaGrammarModel = suggestion
                    }
                }
            }
        }
    }

    /// First installed model fit for text roles, if it is not already serving
    /// both of them.
    private var suggestedTextModel: String? {
        installed.first {
            OllamaModelFit.fit(for: $0.name) == .good
                && (settings.ollamaEnhanceModel != $0.name
                    || settings.ollamaGrammarModel != $0.name)
        }?.name
    }

    private func modelCaption(_ model: OllamaAdmin.Model) -> String {
        var parts: [String] = []
        if model.bytes > 0 { parts.append(model.sizeDescription) }
        let roles = rolesUsing(model.name)
        if !roles.isEmpty { parts.append(roles.joined(separator: ", ")) }
        if let warning = OllamaModelFit.fit(for: model.name).warning {
            parts.append(warning)
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var installSection: some View {
        SettingsSection(title: "Install a model") {
            SettingsRow(title: "Ollama", caption: setupCaption) {
                switch setupState {
                case .notInstalled:
                    SettingsPrimaryButton(title: "Download Ollama") {
                        OllamaSetup.openDownloadPage()
                    }
                case .installedNotRunning:
                    SettingsPrimaryButton(title: "Open Ollama") {
                        try? OllamaSetup.launchApp()
                    }
                case .running:
                    SettingsValue(text: "Running")
                }
            }

            ForEach(Self.recommended) { item in
                let isInstalled = installed.contains {
                    $0.name == item.name || $0.name.hasPrefix(item.name + "-")
                }
                let isPulling = pull.pulling == item.name
                SettingsRow(title: item.title, caption: installCaption(item, isPulling: isPulling)) {
                    if isInstalled {
                        SettingsValue(text: "Installed")
                    } else if isPulling {
                        SettingsPillButton(title: "Cancel", action: pull.cancel)
                    } else {
                        SettingsPillButton(
                            title: "Install",
                            enabled: pull.pulling == nil && (listState == .ready || setupState == .running)
                        ) {
                            pull.start(name: item.name, baseURL: settings.ollamaBaseURL)
                        }
                    }
                }
            }
            if let pullError = pull.error {
                SettingsRow(title: "Install failed", caption: pullError) {
                    SettingsValue(text: "Error")
                }
            }
        }
    }

    private var setupCaption: String {
        switch setupState {
        case .notInstalled:
            return "Download and install Ollama once, then come back here."
        case .installedNotRunning:
            return "Ollama is installed. Open it to start the local server."
        case .running:
            return "Local server is running. Pick a model below."
        }
    }

    private func installCaption(
        _ item: RecommendedOllamaModel,
        isPulling: Bool
    ) -> String {
        if isPulling { return pullStatusLine }
        return "\(item.name) · \(item.caption)"
    }

    private func rolesUsing(_ name: String) -> [String] {
        var roles: [String] = []
        if settings.ollamaEnhanceModel == name { roles.append("Enhance") }
        if settings.ollamaGrammarModel == name { roles.append("Grammar") }
        return roles
    }

    private var pullStatusLine: String {
        guard let progress = pull.progress else { return "Starting…" }
        guard let completed = progress.completed, let total = progress.total, total > 0 else {
            return progress.status.isEmpty ? "Working…" : progress.status
        }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .decimal
        return "\(formatter.string(fromByteCount: completed)) of \(formatter.string(fromByteCount: total))"
    }

    private func refresh(showLoading: Bool = true) async {
        guard settings.activeProvider == .ollama else { return }
        guard OllamaAdmin.nativeRoot(from: settings.ollamaBaseURL) != nil else {
            listState = .notOllama
            setupState = OllamaSetup.resolve(serverReachable: false)
            return
        }
        if showLoading { listState = .loading }
        var serverReachable = false
        do {
            installed = try await admin.installedModels()
            listState = .ready
            serverReachable = true
        } catch let error as OllamaAdmin.AdminError {
            if case .unreachable = error {
                listState = .unreachable(adminHostLabel)
            } else {
                listState = .notOllama
            }
        } catch {
            listState = .unreachable(adminHostLabel)
        }
        setupState = OllamaSetup.resolve(serverReachable: serverReachable)
    }

    private var adminHostLabel: String {
        guard let root = OllamaAdmin.nativeRoot(from: settings.ollamaBaseURL),
              let host = root.host else { return "the server" }
        return root.port.map { "\(host):\($0)" } ?? host
    }
}
