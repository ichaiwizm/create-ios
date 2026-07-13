//
//  KeychainStore.swift
//  Create — State
//
//  CONTRACTS §4.3 : stockage du token PocketBase dans le Keychain (jamais UserDefaults).
//  API figée : save(token:) / load() / delete().
//

import Foundation
import Security

/// Coffre-fort minimal pour l'unique secret de l'app : le token Bearer PocketBase.
///
/// Utilise `kSecClassGenericPassword`, accessibilité `AfterFirstUnlock` (le token doit
/// survivre à un relaunch et rester lisible en tâche de fond pour le polling / push).
enum KeychainStore {

    private static let service = "com.wizycode.create"
    private static let account = "pb_auth_token"

    /// Enregistre (ou remplace) le token. Idempotent.
    static func save(token: String) {
        guard let data = token.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String:       data,
            kSecAttrAccessible as String:  kSecAttrAccessibleAfterFirstUnlock,
        ]

        // Update si présent, sinon add.
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(insert as CFDictionary, nil)
        }
    }

    /// Récupère le token stocké, ou `nil` si absent.
    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }

    /// Efface le token (déconnexion).
    static func delete() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
