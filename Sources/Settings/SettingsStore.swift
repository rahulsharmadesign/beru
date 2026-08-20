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
/// For Beru's text enhancement use case, this is more than sufficient. Groq
/// retired `llama-3.3-70b-versatile` on 16 Aug 2026; `openai/gpt-oss-120b`
/// is the production replacement.
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
    var defaultModel: String {
        switch self {
        case .groq: return "openai/gpt-oss-120b"
        case .openAI: return "gpt-4o-mini"
        case .openRouter: return "openai/gpt-4o-mini"
        case .custom: return ""
        }
    }

    /// Groq ids that 404 as of the 16 Aug 2026 deprecation. Existing installs
    /// that still have these saved are rewritten to `defaultModel`.
    static let retiredGroqModels: Set<String> = [
        "llama-3.3-70b-versatile",
        "llama-3.1-8b-instant",
        "llama-3.1-70b-versatile",
        "llama3-70b-8192",
        "llama3-8b-8192"
    ]
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

    /// First-run Get Started has been finished or dismissed after Accessibility.
    var hasCompletedGetStarted: Bool {
        didSet { defaults.set(hasCompletedGetStarted, forKey: Keys.hasCompletedGetStarted) }
    }

    /// One-time settings sidebar Tip card above About has been dismissed.
    var hasDismissedSettingsTip: Bool {
        didSet { defaults.set(hasDismissedSettingsTip, forKey: Keys.hasDismissedSettingsTip) }
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
        static let hasCompletedGetStarted = "hasCompletedGetStarted"
        static let hasDismissedSettingsTip = "hasDismissedSettingsTip"
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
        var enhanceModel = defaults.string(forKey: Keys.customEnhanceModel) ?? ""
        var grammarModel = defaults.string(forKey: Keys.customGrammarModel) ?? ""
        if CompatibleAPIPreset.retiredGroqModels.contains(enhanceModel) {
            enhanceModel = CompatibleAPIPreset.groq.defaultModel
            defaults.set(enhanceModel, forKey: Keys.customEnhanceModel)
        }
        if CompatibleAPIPreset.retiredGroqModels.contains(grammarModel) {
            grammarModel = CompatibleAPIPreset.groq.defaultModel
            defaults.set(grammarModel, forKey: Keys.customGrammarModel)
        }
        customEnhanceModel = enhanceModel
        customGrammarModel = grammarModel
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        userName = defaults.string(forKey: Keys.userName) ?? ""
        primaryColorID = defaults.string(forKey: PrimaryColor.storageKey) ?? PrimaryColor.indigo.rawValue
        defaultActionID = defaults.string(forKey: Keys.defaultActionID) ?? EnhancementAction.grammarID
        // bool(forKey:) returns false for an unset key, which would silently
        // invert the intended default; check for presence explicitly.
        usageLoggingEnabled = defaults.object(forKey: Keys.usageLoggingEnabled) == nil
            ? false
            : defaults.bool(forKey: Keys.usageLoggingEnabled)
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
        hasCompletedGetStarted = defaults.bool(forKey: Keys.hasCompletedGetStarted)
        hasDismissedSettingsTip = defaults.bool(forKey: Keys.hasDismissedSettingsTip)
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
        get { cachedKey(\.anthropicKeyCache, account: "anthropic") }
        set { storeKey(newValue, cache: \.anthropicKeyCache, account: "anthropic") }
    }

    var customAPIKey: String? {
        get { cachedKey(\.customKeyCache, account: "custom") }
        set { storeKey(newValue, cache: \.customKeyCache, account: "custom") }
    }

    private var anthropicKeyCache: KeyCache = .unloaded
    private var customKeyCache: KeyCache = .unloaded

    private enum KeyCache: Equatable {
        case unloaded
        case loaded(String?)
    }

    private func cachedKey(_ keyPath: ReferenceWritableKeyPath<SettingsStore, KeyCache>, account: String) -> String? {
        if case .loaded(let value) = self[keyPath: keyPath] { return value }
        let value = KeychainStore.shared.load(account: account)
        self[keyPath: keyPath] = .loaded(value)
        return value
    }

    private func storeKey(_ newValue: String?, cache: ReferenceWritableKeyPath<SettingsStore, KeyCache>, account: String) {
        let normalized = newValue.flatMap { $0.isEmpty ? nil : $0 }
        if case .loaded(let current) = self[keyPath: cache], current == normalized { return }
        self[keyPath: cache] = .loaded(normalized)
        if let normalized {
            _ = KeychainStore.shared.save(key: normalized, account: account)
        } else {
            _ = KeychainStore.shared.delete(account: account)
        }
    }
}
