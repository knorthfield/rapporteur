import Foundation
import Security

/// Keeps the GitHub token in the Keychain.
struct Keychain: Sendable {
    var service = "com.krisnorthfield.rapporteur"
    private let account = "github-token"

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    func readToken() -> String? {
        var query = query
        query[kSecReturnData as String] = true
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func saveToken(_ token: String) {
        deleteToken()
        var query = query
        query[kSecValueData as String] = Data(token.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(query as CFDictionary, nil)
    }

    func deleteToken() {
        SecItemDelete(query as CFDictionary)
    }
}
