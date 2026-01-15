import Foundation
import Security

/// Keychain-based token storage for secure credential persistence
/// Uses macOS/iOS Keychain Services API with hardware-backed encryption
public struct KeychainTokenStorage: Sendable {
    private let service: String
    private let account: String

    public init(service: String = "com.dropbook.oauth", account: String = "dropbox-tokens") {
        self.service = service
        self.account = account
    }

    // MARK: - Public API

    /// Save token data to Keychain
    public func save(_ tokenData: StoredTokenData) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(tokenData)

        // Delete existing item first (update pattern)
        try? delete()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unableToSave(status: status)
        }
    }

    /// Load token data from Keychain
    public func load() throws -> StoredTokenData {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unableToLoad(status: status)
        }

        guard let data = result as? Data else {
            throw KeychainError.unexpectedData
        }

        let decoder = JSONDecoder()
        return try decoder.decode(StoredTokenData.self, from: data)
    }

    /// Delete token from Keychain
    public func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unableToDelete(status: status)
        }
    }

    /// Check if token exists in Keychain
    public func exists() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}

// MARK: - Keychain Errors

public enum KeychainError: Error, LocalizedError {
    case itemNotFound
    case unexpectedData
    case unableToSave(status: OSStatus)
    case unableToLoad(status: OSStatus)
    case unableToDelete(status: OSStatus)

    public var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "No token found in Keychain. Run 'dropbook login' first."
        case .unexpectedData:
            return "Unexpected data format in Keychain"
        case .unableToSave(let status):
            return "Unable to save to Keychain (status: \(status))"
        case .unableToLoad(let status):
            return "Unable to load from Keychain (status: \(status))"
        case .unableToDelete(let status):
            return "Unable to delete from Keychain (status: \(status))"
        }
    }
}
