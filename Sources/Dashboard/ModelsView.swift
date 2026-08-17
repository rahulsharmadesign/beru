import SwiftUI

struct ModelsView: View {
    @Bindable private var settings = SettingsStore.shared
    @State private var installed: [OllamaAdmin.Model] = []
    @State private var listState: ListState = .loading
    @State private var pulling: String?
    @State private var pullProgress: OllamaAdmin.PullProgress?
    @State private var pullError: String?
    @State private var pullTask: Task<Void, Never>?

    private enum ListState: Equatable {
        case loading
        case ready
        case unreachable(String)
        case notOllama
    }

    private static let recommended: [(name: String, size: String, note: String)] = [
        ("qwen3:8b", "~5 GB", "Default. Reasoning suppressed automatically."),
        ("qwen2.5:7b", "~4.7 GB", "No reasoning pass; slightly faster first token."),
        ("llama3.2:3b", "~2 GB", "Small and quick; less reliable on structure.")
    ]

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
        .task(id: "\(settings.activeProvider.rawValue)|\(settings.ollamaBaseURL)") { await refresh() }
        .onDisappear { pullTask?.cancel() }
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
                SettingsRow(title: "Server", caption: "Start Ollama, then refresh.") {
                    SettingsValue(text: host)
                }
                SettingsRow(title: "Retry") {
                    SettingsPillButton(title: "Refresh") { Task { await refresh() } }
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
            ForEach(Self.recommended, id: \.name) { item in
                let isInstalled = installed.contains { $0.name == item.name }
                let isPulling = pulling == item.name
                SettingsRow(title: item.name, caption: installCaption(item, isPulling: isPulling)) {
                    if isInstalled {
                        SettingsValue(text: "Installed")
                    } else if isPulling {
                        SettingsPillButton(title: "Cancel", action: cancelPull)
                    } else {
                        SettingsPillButton(
                            title: "Install",
                            enabled: pulling == nil && listState == .ready
                        ) {
                            startPull(item.name)
                        }
                    }
                }
            }
            if let pullError {
                SettingsRow(title: "Install failed", caption: pullError) {
                    SettingsValue(text: "Error")
                }
            }
        }
    }

    private func installCaption(
        _ item: (name: String, size: String, note: String),
        isPulling: Bool
    ) -> String {
        if isPulling { return pullStatusLine }
        return "\(item.size) · \(item.note)"
    }

    private func rolesUsing(_ name: String) -> [String] {
        var roles: [String] = []
        if settings.ollamaEnhanceModel == name { roles.append("Enhance") }
        if settings.ollamaGrammarModel == name { roles.append("Grammar") }
        return roles
    }

    private var pullStatusLine: String {
        guard let progress = pullProgress else { return "Starting…" }
        guard let completed = progress.completed, let total = progress.total, total > 0 else {
            return progress.status.isEmpty ? "Working…" : progress.status
        }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .decimal
        return "\(formatter.string(fromByteCount: completed)) of \(formatter.string(fromByteCount: total))"
    }

    private func refresh() async {
        guard settings.activeProvider == .ollama else { return }
        guard OllamaAdmin.nativeRoot(from: settings.ollamaBaseURL) != nil else {
            listState = .notOllama
            return
        }
        listState = .loading
        do {
            installed = try await admin.installedModels()
            listState = .ready
        } catch let error as OllamaAdmin.AdminError {
            if case .unreachable(let host) = error {
                listState = .unreachable(host)
            } else {
                listState = .notOllama
            }
        } catch {
            listState = .unreachable("the server")
        }
    }

    private func startPull(_ name: String) {
        pullError = nil
        pulling = name
        pullProgress = nil
        let admin = admin
        pullTask = Task {
            do {
                for try await progress in admin.pull(model: name) {
                    pullProgress = progress
                }
                await refresh()
            } catch {
                pullError = error.localizedDescription
            }
            pulling = nil
            pullProgress = nil
        }
    }

    private func cancelPull() {
        pullTask?.cancel()
        pullTask = nil
        pulling = nil
        pullProgress = nil
    }
}
