import Foundation

// MARK: - Dropbox Item

/// Represents a file or folder in Dropbox
public struct DropboxItem: Codable, Sendable {
    public let type: ItemType
    public let id: String
    public let name: String
    public let path: String
    public let size: Int64?
    public let modified: Date?
    public let contentHash: String?

    public enum ItemType: String, Codable, Sendable {
        case file
        case folder
    }

    public init(id: String, name: String, path: String, size: Int64? = nil, modified: Date? = nil, contentHash: String? = nil, type: ItemType) {
        self.id = id
        self.name = name
        self.path = path
        self.size = size
        self.modified = modified
        self.contentHash = contentHash
        self.type = type
    }

    // Convenience initializers
    public static func file(id: String, name: String, path: String, size: Int64, modified: Date, contentHash: String? = nil) -> DropboxItem {
        DropboxItem(id: id, name: name, path: path, size: size, modified: modified, contentHash: contentHash, type: .file)
    }

    public static func folder(id: String, name: String, path: String) -> DropboxItem {
        DropboxItem(id: id, name: name, path: path, type: .folder)
    }
}

// MARK: - Search Result

public struct SearchResult: Codable, Sendable {
    public let matchType: MatchType
    public let metadata: DropboxItem
    public let score: Double?

    public enum MatchType: String, Codable, Sendable {
        case filename = "FILENAME"
        case content = "CONTENT"
        case both = "BOTH"
    }
}

// MARK: - Error Types

public enum DropboxError: Error, LocalizedError, Sendable {
    case notConfigured
    case authenticationFailed
    case networkError(String)
    case invalidResponse
    case fileNotFound(String)
    case uploadFailed(String)
    case downloadFailed(String)
    case invalidPath(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Dropbox client not configured. Please authenticate first."
        case .authenticationFailed:
            return "Authentication failed. Please check your credentials."
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid response from Dropbox API."
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case .invalidPath(let path):
            return "Invalid path: \(path)"
        }
    }
}
