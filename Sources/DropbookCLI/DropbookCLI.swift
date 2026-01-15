import Foundation
import DropbookCore

public enum DropbookCLIError: Error, LocalizedError {
    case missingCommand
    case invalidCommand(String)
    case missingArgument(String)
    case commandExecutionFailed(any Error)

    public var errorDescription: String? {
        switch self {
        case .missingCommand:
            return "No command specified. Use: login|logout|list|search|upload|download|mcp"
        case .invalidCommand(let cmd):
            return "Unknown command: \(cmd)"
        case .missingArgument(let arg):
            return "Missing argument: \(arg)"
        case .commandExecutionFailed(let error):
            return error.localizedDescription
        }
    }
}

public func dropbookCLI(service: DropboxService, args: [String]) async throws {
    do {
        if args.isEmpty {
            throw DropbookCLIError.missingCommand
        }

        let command = args[0]

        switch command {
        case "login":
            try await runLoginCommand()

        case "logout":
            try await runLogoutCommand()

        case "list":
            try await runListCommand(service: service, arguments: Array(args.dropFirst()))

        case "search":
            try await runSearchCommand(service: service, arguments: Array(args.dropFirst()))

        case "upload":
            try await runUploadCommand(service: service, arguments: Array(args.dropFirst()))

        case "download":
            try await runDownloadCommand(service: service, arguments: Array(args.dropFirst()))

        case "mcp":
            print("Use 'dropbook mcp' to start MCP server mode")
            exit(0)

        default:
            throw DropbookCLIError.invalidCommand(command)
        }
    } catch let error as DropbookCLIError {
        print("❌ Error: \(error.localizedDescription)")
        print("\nUsage:")
        print("  dropbook login                 - Authenticate with Dropbox OAuth")
        print("  dropbook logout                - Clear stored OAuth tokens")
        print("  dropbook list [path]           - List files in Dropbox")
        print("  dropbook search <query> [path]  - Search for files")
        print("  dropbook upload <local> <remote> [--overwrite]  - Upload a file")
        print("  dropbook download <remote> <local> - Download a file")
        print("  dropbook mcp                   - Start MCP server")
        exit(1)
    }
}

// MARK: - Command Handlers

private func runListCommand(service: DropboxService, arguments: [String]) async throws {
    let path = arguments.first ?? ""

    let items = try await service.listFiles(path: path)

    for item in items {
        switch item.type {
        case .file:
            if let size = item.size {
                let sizeFormatted = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
                print("📄 \(item.name) (\(sizeFormatted))")
            } else {
                print("📄 \(item.name)")
            }
        case .folder:
            print("📁 \(item.name)/")
        }
    }
}

private func runSearchCommand(service: DropboxService, arguments: [String]) async throws {
    guard let query = arguments.first else {
        throw DropbookCLIError.missingArgument("query")
    }

    let path = arguments.count > 1 ? arguments[1] : ""

    let results = try await service.search(query: query, path: path)

    if results.isEmpty {
        print("No results found for '\(query)'")
    } else {
        print("Found \(results.count) result(s):")
        for (index, result) in results.enumerated() {
            let prefix = switch result.matchType {
            case .filename: "📝"
            case .content: "📄"
            case .both: "🔍"
            }
            print("\(prefix) [\(index + 1)] \(result.metadata.path)")
        }
    }
}

private func runUploadCommand(service: DropboxService, arguments: [String]) async throws {
    guard let localPath = arguments.first else {
        throw DropbookCLIError.missingArgument("local path")
    }

    guard let remotePath = arguments.count > 1 ? arguments[1] : nil else {
        throw DropbookCLIError.missingArgument("remote path")
    }

    let overwrite = arguments.contains("--overwrite")

    let item = try await service.uploadFile(
        localPath: localPath,
        remotePath: remotePath,
        overwrite: overwrite
    )

    switch item.type {
    case .file:
        if let size = item.size {
            let sizeFormatted = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            print("✅ Uploaded: \(item.name) (\(sizeFormatted))")
        } else {
            print("✅ Uploaded: \(item.name)")
        }
    case .folder:
        print("❌ Cannot upload folders")
    }
}

private func runDownloadCommand(service: DropboxService, arguments: [String]) async throws {
    guard let remotePath = arguments.first else {
        throw DropbookCLIError.missingArgument("remote path")
    }

    guard let localPath = arguments.count > 1 ? arguments[1] : nil else {
        throw DropbookCLIError.missingArgument("local path")
    }

    try await service.downloadFile(remotePath: remotePath, localPath: localPath)
    print("✅ Downloaded to: \(localPath)")
}
