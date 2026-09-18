import SwiftUI

/// Local models: what Ollama has installed, whether each one fits Beru's text
/// roles, and one tap to point Beru at one. Downloading lives outside Beru —
/// the Ollama app and `ollama pull <id>` in Terminal show the file variants
/// and sizes an in-app installer cannot, which is how wrong models got
/// installed with no questions asked.
struct ModelsView: View {
    @Bindable private var settings = SettingsStore.shared
    @State private var installed: [OllamaAdmin.Model] = []
    @State private var listState: ListState = .loading
    @State private var serverReachable = false

    private enum ListState: Equatable {
        case loading
        case ready
        case unreachable(String)
        case notOllama
    }

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
            }
            ProviderSettingsSections()
        }
        .task(id: "\(settings.activeProvider.rawValue)|\(settings.ollamaBaseURL)") {
            await refresh()
            while !Task.isCancelled, settings.activeProvider == .ollama, !serverReachable {
                try? await Task.sleep(for: .seconds(2))
                await refresh(showLoading: false)
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
                    caption: "Model listing needs an Ollama-style /v1 base URL."
                ) {
                    SettingsValue(text: "Unavailable")
                }
            case .unreachable(let host):
                SettingsRow(
                    title: "Server",
                    caption: "Start Ollama (`ollama serve`), then pick a model below. Pull new ones with `ollama pull <id>` in Terminal."
                ) {
                    SettingsValue(text: host)
                }
            case .ready where installed.isEmpty:
                SettingsRow(
                    title: "Installed models",
                    caption: "Server is running, but nothing is installed yet. Pull one with `ollama pull \(RecommendedOllamaModel.defaultID)` in Terminal."
                ) {
                    SettingsValue(text: "None")
                }
            case .ready:
                ForEach(installed) { model in
                    SettingsRow(
                        title: model.name,
                        caption: modelCaption(model)
                    ) {
                        if isActiveModel(model.name) {
                            SettingsValue(text: "In use")
                        } else {
                            SettingsPillButton(title: "Use") {
                                settings.ollamaEnhanceModel = model.name
                                settings.ollamaGrammarModel = model.name
                            }
                        }
                    }
                }
            }
        }
    }

    /// One model serves both roles: two ids make Ollama swap weights on every
    /// tab switch, so "Use" always points both at the same model.
    private func isActiveModel(_ name: String) -> Bool {
        settings.ollamaEnhanceModel == name && settings.ollamaGrammarModel == name
    }

    /// Warns when a text role runs on a vision/embedding/speech model or on a
    /// model too small for the jobs, with a one-tap move to the first
    /// installed text model. Nothing renders when both roles are well served.
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
        if isActiveModel(model.name) { parts.append("Enhance, Grammar") }
        if let warning = OllamaModelFit.fit(for: model.name).warning {
            parts.append(warning)
        }
        return parts.joined(separator: " · ")
    }

    private func refresh(showLoading: Bool = true) async {
        guard settings.activeProvider == .ollama else { return }
        guard OllamaAdmin.nativeRoot(from: settings.ollamaBaseURL) != nil else {
            listState = .notOllama
            serverReachable = false
            return
        }
        if showLoading { listState = .loading }
        var reachable = false
        do {
            installed = try await admin.installedModels()
            listState = .ready
            reachable = true
        } catch let error as OllamaAdmin.AdminError {
            if case .unreachable = error {
                listState = .unreachable(adminHostLabel)
            } else {
                listState = .notOllama
            }
        } catch {
            listState = .unreachable(adminHostLabel)
        }
        serverReachable = reachable
    }

    private var adminHostLabel: String {
        guard let root = OllamaAdmin.nativeRoot(from: settings.ollamaBaseURL),
              let host = root.host else { return "the server" }
        return root.port.map { "\(host):\($0)" } ?? host
    }
}
