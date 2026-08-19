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
        SettingsPage(title: "Models", subtitle: DashboardRoute.models.pageSubtitle) {
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
        SettingsSection(title: "On this Mac", subtitle: "Models installed on the local Ollama server.") {
            switch listState {
            case .loading:
                SettingsRow(title: "Installed models", caption: "Looking for models on the local server.") {
                    ProgressView().controlSize(.small)
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
                        caption: model.bytes > 0
                            ? [model.sizeDescription, rolesUsing(model.name).joined(separator: ", ")]
                                .filter { !$0.isEmpty }
                                .joined(separator: " · ")
                            : rolesUsing(model.name).joined(separator: ", ")
                    ) {
                        Menu {
                            Button("Enhance") { settings.ollamaEnhanceModel = model.name }
                            Button("Grammar") { settings.ollamaGrammarModel = model.name }
                            Button("Both") {
                                settings.ollamaEnhanceModel = model.name
                                settings.ollamaGrammarModel = model.name
                            }
                        } label: {
                            Text("Use for")
                                .font(BeruSans.control)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background {
                                    Capsule()
                                        .strokeBorder(SettingsTheme.border, lineWidth: 1)
                                        .background(Capsule().fill(Color.primary.opacity(0.03)))
                                }
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var installSection: some View {
        SettingsSection(title: "Install a model", subtitle: "Recommended downloads for local inference.") {
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
