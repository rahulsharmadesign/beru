import Foundation
import Observation

/// Persisted app settings. Everything here lives in UserDefaults except API
/// keys, which are stored in the Keychain and only referenced by account name.
@MainActor
@Observable
final class SettingsStore {
    static let shared = SettingsStore()

    /// Injectable so the defaults and migrations below can be tested against a
    /// scratch domain. The app only ever uses `shared`, on `.standard`.
    private let defaults: UserDefaults

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
    /// Lets Enhance, Describe and Search see your last few turns in the same
    /// app, so a follow-up like "shorter" has something to refer to. Defaults to
    /// on: only the preference is persisted, never the turns themselves, which
    /// live in memory and die with the process.
    var sessionContextEnabled: Bool {
        didSet {
            defaults.set(sessionContextEnabled, forKey: Keys.sessionContextEnabled)
            // Turning it off should take effect now, not on the next app switch.
            if !sessionContextEnabled { SessionThread.shared.clear() }
        }
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
        static let sessionContextEnabled = "sessionContextEnabled"
        static let historyRetentionDays = "historyRetentionDays"
        static let historyMaxMegabytes = "historyMaxMegabytes"
        static let lastTargetID = "lastTargetID"
        static let lastTargetByApp = "lastTargetByApp"
        static let hasLaunchedBefore = "hasLaunchedBefore"
        static let hasCompletedGetStarted = "hasCompletedGetStarted"
        static let hasDismissedSettingsTip = "hasDismissedSettingsTip"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let hasLaunchedBefore = defaults.bool(forKey: Keys.hasLaunchedBefore)
        if !hasLaunchedBefore {
            // Dev default: zero-config free testing against local Ollama.
            defaults.set(ProviderKind.ollama.rawValue, forKey: Keys.activeProvider)
            defaults.set(true, forKey: Keys.hasLaunchedBefore)
        }

        activeProvider = defaults.string(forKey: Keys.activeProvider).flatMap(ProviderKind.init(rawValue:)) ?? .ollama
        ollamaBaseURL = defaults.string(forKey: Keys.ollamaBaseURL) ?? "http://localhost:11434/v1"
        ollamaEnhanceModel = defaults.string(forKey: Keys.ollamaEnhanceModel)
            ?? RecommendedOllamaModel.defaultID
        // Same model for both roles by default: two different models make
        // Ollama swap weights in and out when the user switches tabs, which
        // costs seconds; one resident model serves both instantly.
        ollamaGrammarModel = defaults.string(forKey: Keys.ollamaGrammarModel)
            ?? RecommendedOllamaModel.defaultID
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
        sessionContextEnabled = defaults.object(forKey: Keys.sessionContextEnabled) == nil
            ? true
            : defaults.bool(forKey: Keys.sessionContextEnabled)
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
