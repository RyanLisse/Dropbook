import Foundation

// MARK: - Dropbook Config

/// Configuration for Dropbook
public struct DropbookConfig: Sendable {
    public let appKey: String
    public let appSecret: String
    public let accessToken: String?
    public let refreshToken: String?
    public let tokenExpirationTimestamp: TimeInterval?
    public let uid: String?

    public init(
        appKey: String,
        appSecret: String,
        accessToken: String? = nil,
        refreshToken: String? = nil,
        tokenExpirationTimestamp: TimeInterval? = nil,
        uid: String? = nil
    ) {
        self.appKey = appKey
        self.appSecret = appSecret
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenExpirationTimestamp = tokenExpirationTimestamp
        self.uid = uid
    }

    /// Load config from environment variables
    public static func loadFromEnvironment() throws -> DropbookConfig {
        guard let appKey = ProcessInfo.processInfo.environment["DROPBOX_APP_KEY"] else {
            throw DropboxError.notConfigured
        }

        guard let appSecret = ProcessInfo.processInfo.environment["DROPBOX_APP_SECRET"] else {
            throw DropboxError.notConfigured
        }

        let accessToken = ProcessInfo.processInfo.environment["DROPBOX_ACCESS_TOKEN"]
        let refreshToken = ProcessInfo.processInfo.environment["DROPBOX_REFRESH_TOKEN"]

        return DropbookConfig(
            appKey: appKey,
            appSecret: appSecret,
            accessToken: accessToken,
            refreshToken: refreshToken
        )
    }

    /// Load config from storage (prefers Keychain, falls back to file)
    public static func loadFromStorage() throws -> DropbookConfig {
        guard let appKey = ProcessInfo.processInfo.environment["DROPBOX_APP_KEY"],
              let appSecret = ProcessInfo.processInfo.environment["DROPBOX_APP_SECRET"] else {
            throw DropboxError.notConfigured
        }

        // Try Keychain first (more secure)
        #if os(macOS) || os(iOS)
        if let tokenData = try? loadFromKeychain() {
            return DropbookConfig(
                appKey: appKey,
                appSecret: appSecret,
                accessToken: tokenData.accessToken,
                refreshToken: tokenData.refreshToken,
                tokenExpirationTimestamp: tokenData.expirationTimestamp,
                uid: tokenData.uid
            )
        }
        #endif

        // Fall back to file storage
        return try loadFromFile(appKey: appKey, appSecret: appSecret)
    }

    /// Load config from Keychain (macOS/iOS only)
    #if os(macOS) || os(iOS)
    public static func loadFromKeychain() throws -> StoredTokenData {
        let keychain = KeychainTokenStorage()
        return try keychain.load()
    }
    #endif

    /// Load config from file storage
    private static func loadFromFile(appKey: String, appSecret: String) throws -> DropbookConfig {
        let fileManager = FileManager.default
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let dropbookDir = homeDir.appendingPathComponent(".dropbook")
        let authFile = dropbookDir.appendingPathComponent("auth.json")

        guard fileManager.fileExists(atPath: authFile.path) else {
            throw DropboxError.notConfigured
        }

        let data = try Data(contentsOf: authFile)
        let decoder = JSONDecoder()
        let tokenData = try decoder.decode(TokenData.self, from: data)

        return DropbookConfig(
            appKey: appKey,
            appSecret: appSecret,
            accessToken: tokenData.accessToken,
            refreshToken: tokenData.refreshToken,
            tokenExpirationTimestamp: tokenData.expirationTimestamp,
            uid: tokenData.uid
        )
    }
}

// MARK: - Token Data

private struct TokenData: Codable {
    let accessToken: String
    let refreshToken: String?
    let expirationTimestamp: TimeInterval?
    let uid: String?
}
