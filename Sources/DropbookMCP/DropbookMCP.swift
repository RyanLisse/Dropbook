import Foundation
import DropbookCore
import MCP

#if canImport(System)
    import System
#endif

/// Dropbook MCP server
public actor DropbookMCP {
    private let service: DropboxService
    private var server: Server?

    public init(service: DropboxService) {
        self.service = service
    }

    /// Start the MCP server
    public func serve() async throws {
        // Create server with info and capabilities (matching test pattern)
        server = Server(
            name: "dropbook",
            version: "1.0.0",
            capabilities: .init(
                prompts: .init(),
                resources: .init(),
                tools: .init()
            )
        )

        guard let server = server else {
            throw MCPError.serverInitializationFailed
        }

        fputs("✅ Server created\n", stderr)

        // Register handlers - matching test pattern
        await server.withMethodHandler(ListTools.self) { _ in
            let tools: [Tool] = [
                Tool(
                    name: "list_directory",
                    description: "List files and folders in a Dropbox directory",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "path": ["type": "string", "description": "Path to list (default: root)"]
                        ]
                    ]
                ),
                Tool(
                    name: "search",
                    description: "Search for files in Dropbox by name or content",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "query": ["type": "string", "description": "Search query"],
                            "path": ["type": "string", "description": "Path to search in (default: root)"]
                        ],
                        "required": ["query"]
                    ]
                ),
                Tool(
                    name: "upload",
                    description: "Upload a local file to Dropbox",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "localPath": ["type": "string", "description": "Absolute path to local file"],
                            "remotePath": ["type": "string", "description": "Destination path in Dropbox (e.g., /folder/file.txt)"],
                            "overwrite": ["type": "boolean", "description": "Overwrite if file exists (default: false)"]
                        ],
                        "required": ["localPath", "remotePath"]
                    ]
                ),
                Tool(
                    name: "download",
                    description: "Download a file from Dropbox to local filesystem",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "remotePath": ["type": "string", "description": "File path in Dropbox"],
                            "localPath": ["type": "string", "description": "Absolute local destination path"]
                        ],
                        "required": ["remotePath", "localPath"]
                    ]
                ),
                Tool(
                    name: "delete",
                    description: "Delete a file or folder from Dropbox (moves to trash)",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "path": ["type": "string", "description": "Path to delete in Dropbox"]
                        ],
                        "required": ["path"]
                    ]
                ),
                Tool(
                    name: "get_account_info",
                    description: "Get Dropbox account information (name, email)",
                    inputSchema: [
                        "type": "object",
                        "properties": [:]
                    ]
                ),
                Tool(
                    name: "read_file",
                    description: "Read and return the contents of a text file from Dropbox",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "path": ["type": "string", "description": "Path to file in Dropbox"]
                        ],
                        "required": ["path"]
                    ]
                )
            ]

            return ListTools.Result(tools: tools)
        }

        // Register CallTool handler
        await server.withMethodHandler(CallTool.self) { [weak self] request in
            guard let self = self else {
                throw MCPError.serverInitializationFailed
            }

            let toolName = request.name
            let args = request.arguments

            do {
                let content: [Tool.Content] = try await self.handleToolCall(name: toolName, arguments: args)
                return CallTool.Result(content: content)
            } catch {
                return CallTool.Result(
                    content: [Tool.Content.text("Error: \(error.localizedDescription)")],
                    isError: true
                )
            }
        }

        // Start server with stdio transport (no parameters = uses stdin/stdout)
        let transport = StdioTransport()
        try await server.start(transport: transport)

        // Keep process alive - using a never-ending task
        try await Task.sleep(nanoseconds: UInt64.max)
    }

    /// Handle individual tool calls
    private func handleToolCall(name: String, arguments: [String: Value]?) async throws -> [Tool.Content] {
        guard let arguments = arguments else {
            throw MCPError.invalidArguments("No arguments provided")
        }

        switch name {
        case "list_directory":
            return try await handleListDirectory(arguments: arguments)

        case "search":
            return try await handleSearch(arguments: arguments)

        case "upload":
            return try await handleUpload(arguments: arguments)

        case "download":
            return try await handleDownload(arguments: arguments)

        case "delete":
            return try await handleDelete(arguments: arguments)

        case "get_account_info":
            return try await handleGetAccountInfo()

        case "read_file":
            return try await handleReadFile(arguments: arguments)

        default:
            throw MCPError.unknownTool(name)
        }
    }

    // MARK: - Tool Handlers

    private func handleListDirectory(arguments: [String: Value]) async throws -> [Tool.Content] {
        let path = extractString(from: arguments["path"]) ?? ""

        let items = try await service.listFiles(path: path)

        var files: [[String: Any]] = []

        for item in items {
            switch item.type {
            case .file:
                var file: [String: Any] = [
                    "type": "file",
                    "id": item.id,
                    "name": item.name,
                    "path": item.path
                ]
                if let size = item.size {
                    file["size"] = size
                }
                if let modified = item.modified {
                    file["modified"] = ISO8601DateFormatter().string(from: modified)
                }
                files.append(file)

            case .folder:
                files.append([
                    "type": "folder",
                    "id": item.id,
                    "name": item.name,
                    "path": item.path
                ])
            }
        }

        let result: [String: Any] = ["files": files]
        let data = try JSONSerialization.data(withJSONObject: result)
        let json = String(data: data, encoding: .utf8) ?? "{}"

        return [Tool.Content.text(json)]
    }

    private func handleSearch(arguments: [String: Value]) async throws -> [Tool.Content] {
        guard let query = extractString(from: arguments["query"]) else {
            throw MCPError.invalidArguments("Missing required parameter: query")
        }

        let path = extractString(from: arguments["path"]) ?? ""

        let results = try await service.search(query: query, path: path)

        var matches: [[String: Any]] = []

        for result in results {
            let metadata: [String: Any]
            switch result.metadata.type {
            case .file:
                var file: [String: Any] = [
                    "type": "file",
                    "id": result.metadata.id,
                    "name": result.metadata.name,
                    "path": result.metadata.path
                ]
                if let size = result.metadata.size {
                    file["size"] = size
                }
                if let modified = result.metadata.modified {
                    file["modified"] = ISO8601DateFormatter().string(from: modified)
                }
                metadata = file

            case .folder:
                metadata = [
                    "type": "folder",
                    "id": result.metadata.id,
                    "name": result.metadata.name,
                    "path": result.metadata.path
                ]
            }

            matches.append([
                "matchType": result.matchType.rawValue,
                "metadata": metadata
            ])
        }

        let result: [String: Any] = [
            "count": results.count,
            "results": matches
        ]

        let data = try JSONSerialization.data(withJSONObject: result)
        let json = String(data: data, encoding: .utf8) ?? "{}"

        return [Tool.Content.text(json)]
    }

    private func handleUpload(arguments: [String: Value]) async throws -> [Tool.Content] {
        guard let localPath = extractString(from: arguments["localPath"]),
              let remotePath = extractString(from: arguments["remotePath"]) else {
            throw MCPError.invalidArguments("Missing required parameters")
        }

        let overwrite = extractBool(from: arguments["overwrite"]) ?? false

        let item = try await service.uploadFile(
            localPath: localPath,
            remotePath: remotePath,
            overwrite: overwrite
        )

        var result: [String: Any] = [
            "uploaded": true,
            "name": item.name,
            "path": item.path
        ]

        if let size = item.size {
            result["size"] = size
        }

        let data = try JSONSerialization.data(withJSONObject: result)
        let json = String(data: data, encoding: .utf8) ?? "{}"

        return [Tool.Content.text(json)]
    }

    private func handleDownload(arguments: [String: Value]) async throws -> [Tool.Content] {
        guard let remotePath = extractString(from: arguments["remotePath"]),
              let localPath = extractString(from: arguments["localPath"]) else {
            throw MCPError.invalidArguments("Missing required parameters")
        }

        try await service.downloadFile(remotePath: remotePath, localPath: localPath)

        let result: [String: Any] = [
            "downloaded": true,
            "to": localPath
        ]

        let data = try JSONSerialization.data(withJSONObject: result)
        let json = String(data: data, encoding: .utf8) ?? "{}"

        return [Tool.Content.text(json)]
    }

    private func handleDelete(arguments: [String: Value]) async throws -> [Tool.Content] {
        guard let path = extractString(from: arguments["path"]) else {
            throw MCPError.invalidArguments("Missing required parameter: path")
        }

        try await service.delete(path: path)

        let result: [String: Any] = [
            "deleted": true,
            "path": path
        ]

        let data = try JSONSerialization.data(withJSONObject: result)
        let json = String(data: data, encoding: .utf8) ?? "{}"

        return [Tool.Content.text(json)]
    }

    private func handleGetAccountInfo() async throws -> [Tool.Content] {
        let info = try await service.getAccountInfo()

        let result: [String: Any] = [
            "name": info.name,
            "email": info.email
        ]

        let data = try JSONSerialization.data(withJSONObject: result)
        let json = String(data: data, encoding: .utf8) ?? "{}"

        return [Tool.Content.text(json)]
    }

    private func handleReadFile(arguments: [String: Value]) async throws -> [Tool.Content] {
        guard let path = extractString(from: arguments["path"]) else {
            throw MCPError.invalidArguments("Missing required parameter: path")
        }

        let fileData = try await service.downloadData(remotePath: path)

        guard let content = String(data: fileData, encoding: .utf8) else {
            throw MCPError.invalidOperation("File is not valid UTF-8 text")
        }

        return [Tool.Content.text(content)]
    }

    // MARK: - Value Extraction Helpers

    private func extractString(from value: Value?) -> String? {
        guard let value = value else { return nil }
        switch value {
        case .string(let s): return s
        default: return nil
        }
    }

    private func extractBool(from value: Value?) -> Bool? {
        guard let value = value else { return nil }
        switch value {
        case .bool(let b): return b
        default: return nil
        }
    }
}

// MARK: - MCP Error Types

public enum MCPError: Error, LocalizedError {
    case serverInitializationFailed
    case unknownTool(String)
    case invalidArguments(String)
    case invalidOperation(String)
    case toolExecutionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .serverInitializationFailed:
            return "Failed to initialize MCP server"
        case .unknownTool(let name):
            return "Unknown tool: \(name)"
        case .invalidArguments(let message):
            return "Invalid arguments: \(message)"
        case .invalidOperation(let message):
            return "Invalid operation: \(message)"
        case .toolExecutionFailed(let message):
            return "Tool execution failed: \(message)"
        }
    }
}