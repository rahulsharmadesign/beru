import Foundation
import Observation

enum ProviderKind: String, CaseIterable, Codable {
    case ollama
    case anthropic
    case custom

    var title: String {
        switch self {
        case .ollama: return "Ollama (local)"
        case .anthropic: return "Anthropic"
        case .custom: return "API (Groq, OpenAI, …)"
        }
    }
}

/// One-click base URL + model defaults for common OpenAI-compatible hosts.
///
/// ## Groq Integration
/// Groq provides exceptionally fast inference (typically 200-500 tokens/second)
/// on their LPU (Language Processing Unit) infrastructure. The free tier offers
/// generous rate limits suitable for personal use:
/// - 30 requests/minute
/// - 14,400 requests/day
/// - 6,000 tokens/minute
///
/// For Beru's text enhancement use case, this is more than sufficient. The
/// `llama-3.3-70b-versatile` model provides excellent quality for prompt
/// engineering and grammar correction at Groq's signature speed.
enum CompatibleAPIPreset: String, CaseIterable, Identifiable {
    case groq
    case openAI
    case openRouter
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .groq: return "Groq"
        case .openAI: return "OpenAI"
        case .openRouter: return "OpenRouter"
        case .custom: return "Custom URL"
        }
    }

    var baseURL: String {
        switch self {
        case .groq: return "https://api.groq.com/openai/v1"
        case .openAI: return "https://api.openai.com/v1"
        case .openRouter: return "https://openrouter.ai/api/v1"
        case .custom: return ""
        }
    }

    /// Sensible default model id; user can edit after applying.
    /// Groq's llama-3.3-70b-versatile balances quality and speed for text
    /// enhancement tasks. Users on the free tier should stay within rate limits.
    var defaultModel: String {
        switch self {
        case .groq: return "llama-3.3-70b-versatile"
        case .openAI: return "gpt-4o-mini"
        case .openRouter: return "openai/gpt-4o-mini"
        case .custom: return ""
        }
    }
}

/// Persisted app settings. Everything here lives in UserDefaults except API
/// keys, which are stored in the Keychain and only referenced by account name.
@MainActor
@Observable
final class SettingsStore {
    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard

    var activeProvider: ProviderKind {
        didSet { defaults.set(activeProvider.rawValue, forKey: Keys.activeProvider) }
    }

    var ollamaBaseURL: String {
        didSet { defaults.set(ollamaBaseURL, forKey: Keys.ollamaBaseURL) }
    }
    var ollamaEnhanceModel: String {
        didSet { defaults.set(ollamaEnhanceModel, forKey: Keys.ollamaEnhanceModel) }
    }
    var ollamaGrammarModel: String {
        didSet { defaults.set(ollamaGrammarModel, forKey: Keys.ollamaGrammarModel) }
    }

    var customBaseURL: String {
        didSet { defaults.set(customBaseURL, forKey: Keys.customBaseURL) }
    }
    var customEnhanceModel: String {
        didSet { defaults.set(customEnhanceModel, forKey: Keys.customEnhanceModel) }
    }
    var customGrammarModel: String {
        didSet { defaults.set(customGrammarModel, forKey: Keys.customGrammarModel) }
    }

    var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }
    /// Local display name used only for Beru greetings and never sent by itself.
    var userName: String {
        didSet { defaults.set(userName, forKey: Keys.userName) }
    }
    // One of the twelve app-wide accent choices. Appearance itself always follows macOS.
    var primaryColorID: String {
        didSet { defaults.set(primaryColorID, forKey: PrimaryColor.storageKey) }
    }
    /// Action pre-selected on a fresh invocation (last-used still wins after
    /// first use).
    var defaultActionID: String {
        didSet { defaults.set(defaultActionID, forKey: Keys.defaultActionID) }
    }
    // A single "customSkillPrompt" used to live here and override the built-in
    // Enhance prompt. It is gone: a saved prompt is now a saved action, so the
    // chip's name describes the prompt that runs. `ActionRegistry` reads the old
    // key once to migrate it, then clears it.

    /// Records what you do to a local file so it can inform later tuning.
    /// Nothing is ever transmitted. Defaults to off — selected text can
    /// include secrets, so recording is an explicit choice.
    var usageLoggingEnabled: Bool {
        didSet { defaults.set(usageLoggingEnabled, forKey: Keys.usageLoggingEnabled) }
    }
    /// Asks the model to explain its most important change alongside the result.
    /// Costs a couple of hundred tokens and no extra round trip. Defaults to on.
    var explainChanges: Bool {
        didSet { defaults.set(explainChanges, forKey: Keys.explainChanges) }
    }
    /// How frosted the panel is, 0 (clear glass) to 1 (opaque enough to read
    /// anything over anything). 0.5 is the shipped balance.
    ///
    /// This is a preference rather than a constant because there is no single
    /// right answer: iOS can keep its glass extremely transparent because the
    /// backdrop is always a wallpaper the OS controls, while this panel floats
    /// over arbitrary app content. Clear glass over a dense document is
    /// unreadable; heavy frosting over a wallpaper is wasted. Only the person
    /// looking at it knows which they want.
    ///
    /// The panel reads this value once per invocation and injects it through
    /// `.environment(\.panelFrosting, …)`, so every glass module shares one
    /// value without subscribing to the full store. A live preview in General
    /// settings renders the same three-stop gradient the panel uses.
    var panelFrosting: Double {
        didSet { defaults.set(panelFrosting, forKey: Keys.panelFrosting) }
    }
    var historyRetentionDays: Int {
        didSet { defaults.set(historyRetentionDays, forKey: Keys.historyRetentionDays) }
    }
    var historyMaxMegabytes: Int {
        didSet { defaults.set(historyMaxMegabytes, forKey: Keys.historyMaxMegabytes) }
    }
    /// Most recently chosen prompt target, used when the host app has no
    /// remembered preference.
    var lastTargetID: String {
        didSet { defaults.set(lastTargetID, forKey: Keys.lastTargetID) }
    }
    /// Host bundle identifier to target id, so returning to an app restores
    /// the target that was used there last.
    var lastTargetByApp: [String: String] {
        didSet { defaults.set(lastTargetByApp, forKey: Keys.lastTargetByApp) }
    }

    private enum Keys {
        static let activeProvider = "activeProvider"
        static let ollamaBaseURL = "ollamaBaseURL"
        static let ollamaEnhanceModel = "ollamaEnhanceModel"
        static let ollamaGrammarModel = "ollamaGrammarModel"
        static let customBaseURL = "customBaseURL"
        static let customEnhanceModel = "customEnhanceModel"
        static let customGrammarModel = "customGrammarModel"
        static let launchAtLogin = "launchAtLogin"
        static let userName = "userName"
        static let primaryColorID = "primaryColorID"
        static let defaultActionID = "defaultActionID"
        static let usageLoggingEnabled = "usageLoggingEnabled"
        static let explainChanges = "explainChanges"
        static let panelFrosting = "panelFrosting"
        static let historyRetentionDays = "historyRetentionDays"
        static let historyMaxMegabytes = "historyMaxMegabytes"
        static let lastTargetID = "lastTargetID"
        static let lastTargetByApp = "lastTargetByApp"
        static let hasLaunchedBefore = "hasLaunchedBefore"
    }

    private init() {
        let hasLaunchedBefore = defaults.bool(forKey: Keys.hasLaunchedBefore)
        if !hasLaunchedBefore {
            // Dev default: zero-config free testing against local Ollama.
            defaults.set(ProviderKind.ollama.rawValue, forKey: Keys.activeProvider)
            defaults.set(true, forKey: Keys.hasLaunchedBefore)
        }

        activeProvider = defaults.string(forKey: Keys.activeProvider).flatMap(ProviderKind.init(rawValue:)) ?? .ollama
        ollamaBaseURL = defaults.string(forKey: Keys.ollamaBaseURL) ?? "http://localhost:11434/v1"
        ollamaEnhanceModel = defaults.string(forKey: Keys.ollamaEnhanceModel) ?? "qwen2.5:7b"
        // Same model for both roles by default: two different models make
        // Ollama swap weights in and out when the user switches tabs, which
        // costs seconds; one resident model serves both instantly.
        ollamaGrammarModel = defaults.string(forKey: Keys.ollamaGrammarModel) ?? "qwen2.5:7b"
        customBaseURL = defaults.string(forKey: Keys.customBaseURL) ?? ""
        customEnhanceModel = defaults.string(forKey: Keys.customEnhanceModel) ?? ""
        customGrammarModel = defaults.string(forKey: Keys.customGrammarModel) ?? ""
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        userName = defaults.string(forKey: Keys.userName) ?? ""
        primaryColorID = defaults.string(forKey: PrimaryColor.storageKey) ?? PrimaryColor.indigo.rawValue
        defaultActionID = defaults.string(forKey: Keys.defaultActionID) ?? EnhancementAction.grammarID
        // bool(forKey:) returns false for an unset key, which would silently
        // invert the intended default; check for presence explicitly.
        usageLoggingEnabled = defaults.object(forKey: Keys.usageLoggingEnabled) == nil
            ? false
            : defaults.bool(forKey: Keys.usageLoggingEnabled)
        KeychainStore.shared.upgradeStoredKeyAccessibility()
        explainChanges = defaults.object(forKey: Keys.explainChanges) == nil
            ? true
            : defaults.bool(forKey: Keys.explainChanges)
        panelFrosting = defaults.object(forKey: Keys.panelFrosting) == nil
            ? 0.5
            : min(1, max(0, defaults.double(forKey: Keys.panelFrosting)))
        let storedRetention = defaults.integer(forKey: Keys.historyRetentionDays)
        historyRetentionDays = storedRetention > 0 ? storedRetention : 90
        let storedMax = defaults.integer(forKey: Keys.historyMaxMegabytes)
        historyMaxMegabytes = storedMax > 0 ? storedMax : 200
        lastTargetID = defaults.string(forKey: Keys.lastTargetID) ?? TargetProfile.genericID
        lastTargetByApp = defaults.dictionary(forKey: Keys.lastTargetByApp) as? [String: String] ?? [:]
    }

    /// Whether a provider has everything it needs to answer a request, so the
    /// UI can show which options are actually usable.
    func isConfigured(_ kind: ProviderKind) -> Bool {
        switch kind {
        case .ollama:
            return !ollamaBaseURL.isEmpty && !ollamaEnhanceModel.isEmpty && !ollamaGrammarModel.isEmpty
        case .anthropic:
            return !(anthropicAPIKey ?? "").isEmpty
        case .custom:
            // Remote hosts (Groq, OpenAI, …) need a key; loopback servers often don't.
            let hasURL = !customBaseURL.isEmpty
            let hasModel = !customEnhanceModel.isEmpty && !customGrammarModel.isEmpty
            let loopback = customBaseURL.lowercased().contains("localhost")
                || customBaseURL.contains("127.0.0.1")
            let hasKey = !(customAPIKey ?? "").isEmpty
            return hasURL && hasModel && (loopback || hasKey)
        }
    }

    /// Providers other than the active one that are configured and could serve
    /// as a fallback. Used by the panel's error state to offer "Try with X".
    var fallbackProviders: [ProviderKind] {
        ProviderKind.allCases.filter { $0 != activeProvider && isConfigured($0) }
    }

    /// Switches provider. Kept separate from the property so callers can be
    /// notified and pre-load the newly selected local model.
    func selectProvider(_ kind: ProviderKind) {
        guard kind != activeProvider else { return }
        activeProvider = kind
        onProviderChanged?(kind)
    }

    /// Set by the coordinator to warm the newly selected provider's model.
    var onProviderChanged: ((ProviderKind) -> Void)?

    /// The concrete model id the active provider will use for a role. Recorded
    /// in the usage history so results can be attributed to a model later.
    func modelID(for role: ModelRole) -> String {
        switch activeProvider {
        case .ollama:
            return role == .enhance ? ollamaEnhanceModel : ollamaGrammarModel
        case .custom:
            return role == .enhance ? customEnhanceModel : customGrammarModel
        case .anthropic:
            return role == .enhance
                ? AnthropicProvider.Constants.enhanceModel
                : AnthropicProvider.Constants.grammarModel
        }
    }


    var anthropicAPIKey: String? {
        get { KeychainStore.shared.load(account: "anthropic") }
        set {
            if let newValue, !newValue.isEmpty {
                KeychainStore.shared.save(key: newValue, account: "anthropic")
            } else {
                KeychainStore.shared.delete(account: "anthropic")
            }
        }
    }

    var customAPIKey: String? {
        get { KeychainStore.shared.load(account: "custom") }
        set {
            if let newValue, !newValue.isEmpty {
                KeychainStore.shared.save(key: newValue, account: "custom")
            } else {
                KeychainStore.shared.delete(account: "custom")
            }
        }
    }
}
