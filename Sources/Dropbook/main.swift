import Foundation
import DropbookCore
import DropbookCLI
import DropbookMCP

@main
struct Dropbook {
    static func main() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())

        do {
            if arguments.isEmpty {
                throw DropbookCLIError.missingCommand
            }

            let command = arguments[0]

            switch command {
            case "login":
                // Login doesn't need an authenticated service
                try await runLoginCommand()

            case "logout":
                // Logout doesn't need an authenticated service
                try await runLogoutCommand()

            case "mcp":
                // Run MCP server
                // Prefer stored tokens, fall back to environment variables
                let config: DropbookConfig
                do {
                    config = try DropbookConfig.loadFromStorage()
                } catch {
                    // Fall back to environment variables if storage not available
                    config = try DropbookConfig.loadFromEnvironment()
                }
                let service = DropboxService(config: config)
                let mcp = DropbookMCP(service: service)

                print("🚀 Starting Dropbook MCP Server...")
                try await mcp.serve()

            default:
                // Run CLI commands (list, search, upload, download)
                // These require authentication
                // Prefer stored tokens, fall back to environment variables
                let config: DropbookConfig
                do {
                    config = try DropbookConfig.loadFromStorage()
                } catch {
                    // Fall back to environment variables if storage not available
                    config = try DropbookConfig.loadFromEnvironment()
                }
                let service = DropboxService(config: config)
                try await dropbookCLI(service: service, args: arguments)
            }
        } catch {
            print("❌ Error: \(error.localizedDescription)")
            exit(1)
        }
    }
}
