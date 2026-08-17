import Foundation
import Security

/// Thin wrapper around the Keychain Services API for storing provider API keys.
/// This is the ONLY place in the app allowed to persist secret material.
final class KeychainStore {
    static let shared = KeychainStore()

    private let service = "com.beru.api"

    private init() {}

    func save(key: String, account: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }
        delete(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    func delete(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Re-saves known provider keys still stored with a weaker accessibility
    /// class. No-op when the item is already `WhenUnlockedThisDeviceOnly` or
    /// the keychain is unavailable (for example before first unlock).
    func upgradeStoredKeyAccessibility() {
        for account in ["anthropic", "custom"] {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecReturnAttributes as String: true,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            guard status == errSecSuccess,
                  let item = result as? [String: Any],
                  let data = item[kSecValueData as String] as? Data,
                  let key = String(data: data, encoding: .utf8),
                  !key.isEmpty else { continue }
            if item[kSecAttrAccessible as String] as? String
                == (kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String) {
                continue
            }
            _ = save(key: key, account: account)
        }
    }
}
