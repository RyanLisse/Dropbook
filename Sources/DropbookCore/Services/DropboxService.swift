import Foundation
import SwiftyDropbox

/// Dropbox service for file operations
public actor DropboxService {
    private let config: DropbookConfig
    private var client: DropboxClient?
    private var oauthManager: DropboxOAuthManager?

    public init(config: DropbookConfig) {
        self.config = config
    }

    // MARK: - Authentication

    /// Initialize Dropbox client
    public func authenticate() throws {
        if let refreshToken = config.refreshToken,
           let accessToken = config.accessToken,
           let expirationTimestamp = config.tokenExpirationTimestamp,
           let uid = config.uid {
            let dropboxToken = DropboxAccessToken(
                accessToken: accessToken,
                uid: uid,
                refreshToken: refreshToken,
                tokenExpirationTimestamp: expirationTimestamp
            )

            let manager = DropboxOAuthManager(
                appKey: config.appKey,
                secureStorageAccess: SecureStorageAccessDefaultImpl()
            )
            self.oauthManager = manager

            client = DropboxClient(
                accessToken: dropboxToken,
                dropboxOauthManager: manager
            )
        } else if let accessToken = config.accessToken {
            client = DropboxClient(accessToken: accessToken)
        } else {
            throw DropboxError.notConfigured
        }
    }

    /// Get the authenticated client
    public func getClient() throws -> DropboxClient {
        guard let client = client else {
            try authenticate()
            return try getClient()
        }
        return client
    }

    // MARK: - List Files

    /// List files in a directory
    public func listFiles(path: String = "") async throws -> [DropboxItem] {
        let client = try getClient()

        let response = try await client.files.listFolder(path: path).response()

        var items: [DropboxItem] = []

        for entry in response.entries {
            switch entry {
            case let file as SwiftyDropbox.Files.FileMetadata:
                items.append(DropboxItem.file(
                    id: file.id,
                    name: file.name,
                    path: file.pathDisplay ?? "",
                    size: Int64(file.size ?? 0),
                    modified: file.serverModified,
                    contentHash: file.contentHash
                ))
            case let folder as SwiftyDropbox.Files.FolderMetadata:
                items.append(DropboxItem.folder(
                    id: folder.id,
                    name: folder.name,
                    path: folder.pathDisplay ?? ""
                ))
            default:
                break
            }
        }

        return items
    }

    // MARK: - Search

    /// Search for files
    public func search(query: String, path: String = "") async throws -> [SearchResult] {
        let client = try getClient()

        let response = try await client.files.searchV2(
            query: query,
            options: SwiftyDropbox.Files.SearchOptions(
                path: path.isEmpty ? "/" : path,
                maxResults: 100
            )
        ).response()

        var results: [SearchResult] = []

        for match in response.matches {
            // Extract the actual Metadata from MetadataV2 enum
            let metadata: SwiftyDropbox.Files.Metadata
            switch match.metadata {
            case .metadata(let m):
                metadata = m
            case .other:
                continue
            }

            // Convert match type
            let matchType: SearchResult.MatchType
            switch match.matchType {
            case .filename:
                matchType = .filename
            case .fileContent:
                matchType = .content
            case .filenameAndContent:
                matchType = .both
            case .imageContent:
                matchType = .filename  // Treat image content as filename match
            case .other, nil:
                matchType = .filename
            }

            // Extract file/folder metadata
            switch metadata {
            case let file as SwiftyDropbox.Files.FileMetadata:
                let item = DropboxItem.file(
                    id: file.id,
                    name: file.name,
                    path: file.pathDisplay ?? "",
                    size: Int64(file.size),
                    modified: file.serverModified,
                    contentHash: file.contentHash
                )
                results.append(SearchResult(
                    matchType: matchType,
                    metadata: item,
                    score: nil
                ))
            case let folder as SwiftyDropbox.Files.FolderMetadata:
                let item = DropboxItem.folder(
                    id: folder.id,
                    name: folder.name,
                    path: folder.pathDisplay ?? ""
                )
                results.append(SearchResult(
                    matchType: matchType,
                    metadata: item,
                    score: nil
                ))
            case is SwiftyDropbox.Files.DeletedMetadata:
                // Skip deleted items
                continue
            default:
                break
            }
        }

        return results
    }

    // MARK: - Upload

    /// Upload a file to Dropbox
    public func uploadFile(localPath: String, remotePath: String, overwrite: Bool = false) async throws -> DropboxItem {
        let client = try getClient()

        let fileData = try Data(contentsOf: URL(fileURLWithPath: localPath))
        let mode: SwiftyDropbox.Files.WriteMode = overwrite ? .overwrite : .add

        let response = try await client.files.upload(path: remotePath, mode: mode, input: fileData).response()

        return DropboxItem.file(
            id: response.id,
            name: response.name,
            path: response.pathDisplay ?? "",
            size: Int64(response.size),
            modified: response.serverModified,
            contentHash: response.contentHash
        )
    }

    // MARK: - Download

    /// Download a file from Dropbox
    public func downloadFile(remotePath: String, localPath: String) async throws {
        let client = try getClient()

        let (_, data) = try await client.files.download(path: remotePath).response()

        try data.write(to: URL(fileURLWithPath: localPath))
    }

    /// Download a file and return its data
    public func downloadData(remotePath: String) async throws -> Data {
        let client = try getClient()

        let (_, data) = try await client.files.download(path: remotePath).response()

        return data
    }

    // MARK: - Delete

    /// Delete a file or folder
    public func delete(path: String) async throws {
        let client = try getClient()

        _ = try await client.files.deleteV2(path: path).response()
    }

    // MARK: - Get Account Info

    /// Get account information
    public func getAccountInfo() async throws -> (name: String, email: String) {
        let client = try getClient()

        let response = try await client.users.getCurrentAccount().response()

        return (
            name: response.name.displayName,
            email: response.email
        )
    }
}
