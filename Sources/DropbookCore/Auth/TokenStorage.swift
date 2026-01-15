import Foundation
import SwiftyDropbox

/// Token storage for persisting Dropbox OAuth tokens
public struct TokenStorage: Sendable {
    private let storageDirectory: URL
    private let authFilePath: URL

    public init() throws {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        storageDirectory = homeDir.appendingPathComponent(".dropbook")
        authFilePath = storageDirectory.appendingPathComponent("auth.json")

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: storageDirectory.path) {
            try FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        }
    }

    /// Save token to storage
    public func save(token: DropboxAccessToken) throws {
        let tokenData = StoredTokenData(
            accessToken: token.accessToken,
            refreshToken: token.refreshToken,
            expirationTimestamp: token.tokenExpirationTimestamp,
            uid: token.uid
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(tokenData)

        // Write with secure permissions (600)
        try data.write(to: authFilePath, options: .atomic)
        try setSecurePermissions()
    }

    /// Load token from storage
    public func load() throws -> StoredTokenData {
        guard FileManager.default.fileExists(atPath: authFilePath.path) else {
            throw DropboxError.notConfigured
        }

        let data = try Data(contentsOf: authFilePath)
        let decoder = JSONDecoder()
        return try decoder.decode(StoredTokenData.self, from: data)
    }

    /// Delete stored token
    public func delete() throws {
        if FileManager.default.fileExists(atPath: authFilePath.path) {
            try FileManager.default.removeItem(at: authFilePath)
        }
    }

    /// Check if token exists
    public func exists() -> Bool {
        return FileManager.default.fileExists(atPath: authFilePath.path)
    }

    /// Set secure file permissions (600 - owner read/write only)
    private func setSecurePermissions() throws {
        #if os(macOS) || os(Linux)
        let attributes = [FileAttributeKey.posixPermissions: 0o600]
        try FileManager.default.setAttributes(attributes, ofItemAtPath: authFilePath.path)
        #endif
    }
}

// MARK: - Stored Token Data

public struct StoredTokenData: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let expirationTimestamp: TimeInterval?
    public let uid: String?

    public init(accessToken: String, refreshToken: String?, expirationTimestamp: TimeInterval?, uid: String?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expirationTimestamp = expirationTimestamp
        self.uid = uid
    }
}
