# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Dropbook is a Swift command-line tool and MCP (Model Context Protocol) server that provides programmatic access to Dropbox. It has three distinct interfaces:

1. **CLI** - Command-line interface for interactive Dropbox file operations
2. **Library** - Swift package (`DropbookCore`) for embedding in other projects
3. **MCP Server** - Exposes Dropbox operations as tools for AI assistants via the Model Context Protocol

## Architecture

Dropbook follows a layered architecture with clear separation of concerns:

```
┌─────────────────────────────────────┐
│  Executable (dropbook)              │
│  Entry point: Sources/Dropbook/     │
└─────────────────────────────────────┘
            ↓
┌─────────────────────────────────────┐
│  CLI + MCP Interfaces (Adapters)    │
│  - DropbookCLI: Command parsing     │
│  - DropbookMCP: MCP tool handlers   │
└─────────────────────────────────────┘
            ↓
┌─────────────────────────────────────┐
│  DropbookCore (Business Logic)      │
│  - DropboxService: Actor-based API  │
│  - DropboxItem: Domain models       │
│  - Configuration management         │
└─────────────────────────────────────┘
            ↓
┌─────────────────────────────────────┐
│  SwiftyDropbox SDK                  │
│  Third-party Dropbox client         │
└─────────────────────────────────────┘
```

### Key Components

**DropbookCore** (public library):
- `DropboxService` (actor): Main service for Dropbox operations. All Dropbox API calls go through here. Uses Swift's actor model for thread safety.
- `DropboxItem`/`SearchResult`: Domain models representing Dropbox files and search results
- `DropbookConfig`: Configuration struct loaded from environment variables (DROPBOX_APP_KEY, DROPBOX_APP_SECRET, DROPBOX_ACCESS_TOKEN, DROPBOX_REFRESH_TOKEN)

**DropbookCLI**:
- Command dispatcher for CLI mode
- Argument parsing for `list`, `search`, `upload`, `download` commands
- Human-readable output formatting

**DropbookMCP**:
- MCP server implementation (`DropbookMCP` actor)
- Tool definitions: `list_directory`, `search`, `upload`, `download`
- JSON response serialization for MCP protocol

**main.swift** (entry point):
- Routes to either CLI or MCP based on command-line arguments
- Handles configuration loading and service initialization

## Agent Integration

### Dropbox Skill

Use the `dropbox-skill` for file operations.

**Location**: `dropbox-skill/`
**Configuration**: See `dropbox-skill/SKILL.md`

**Capabilities**:
- `list_directory`: List files and folders
- `search`: Find files by name/content
- `upload`: Upload local files to Dropbox
- `download`: Download remote files

**To Load Skill**:
1. Ensure Dropbook is built: `swift build`
2. Set environment variables (`DROPBOX_APP_KEY`, etc.)
3. Start server via MCP: `.build/debug/dropbook mcp`

## Build & Development

### Build
```bash
swift build
```

Build artifacts go to `.build/debug/dropbook` (or `.build/release/` for release builds).

### Run CLI Commands
```bash
# Option 1: Use OAuth login (recommended)
export DROPBOX_APP_KEY="your_app_key"
export DROPBOX_APP_SECRET="your_app_secret"
swift run dropbook login  # Interactive OAuth flow, saves tokens to ~/.dropbook/auth.json

# Option 2: Use environment variables (legacy)
export DROPBOX_APP_KEY="your_app_key"
export DROPBOX_APP_SECRET="your_app_secret"
export DROPBOX_ACCESS_TOKEN="your_access_token"

# Run commands (works with either option)
swift run dropbook list /path
swift run dropbook search "query"
swift run dropbook upload localfile /remote/path
swift run dropbook download /remote/path localfile
```

### Run MCP Server
```bash
# Start the server (connects to stdin/stdout)
swift run dropbook mcp
```

The MCP server communicates via JSON-RPC 2.0 over stdio (no additional parameters needed).

### Run Tests
No automated tests currently exist. The `scripts/test-mcp.sh` script provides manual testing:
```bash
bash scripts/test-mcp.sh
```

## Authentication

Dropbook supports two authentication methods:

### OAuth 2.0 with PKCE (Recommended)

The `login` command implements OAuth 2.0 Authorization Code Flow with PKCE (Proof Key for Code Exchange), following RFC 9700 best practices:

```bash
export DROPBOX_APP_KEY="your_app_key"
export DROPBOX_APP_SECRET="your_app_secret"
swift run dropbook login
```

This will:
1. Generate a PKCE code verifier and challenge using CryptoKit (SHA256/S256)
2. Generate a state parameter for CSRF protection (RFC 9700)
3. Print an authorization URL for you to visit
4. Prompt you to paste the authorization code
5. Exchange the code for access and refresh tokens
6. Save tokens to **macOS Keychain** (primary, secure) and `~/.dropbook/auth.json` (backup)

**Token Storage Priority**:
1. **Keychain** (macOS/iOS): Hardware-backed encryption via `kSecAttrAccessibleWhenUnlocked`
2. **File** (`~/.dropbook/auth.json`): Backup storage with permissions 600, Linux compatibility

**Automatic Refresh**: When using tokens from storage, `DropboxService` automatically initializes `DropboxOAuthManager` to handle token refreshing. SwiftyDropbox will proactively refresh the access token before it expires.

**Logout**: To clear stored tokens:
```bash
swift run dropbook logout  # Clears both Keychain and file storage
```

### Environment Variables (Legacy)

For backward compatibility, you can still use environment variables:

```bash
export DROPBOX_APP_KEY="your_app_key"
export DROPBOX_APP_SECRET="your_app_secret"
export DROPBOX_ACCESS_TOKEN="your_long_lived_token"
```

This method doesn't support automatic token refreshing.

## Swift Configuration & Concurrency

The project uses strict Swift concurrency checking and upcoming features:

- **StrictConcurrency**: Enabled across all targets
- **ExistentialAny**: Upcoming feature enabled for explicit `any Type` syntax
- **NonisolatedNonsendingByDefault**: Upcoming feature for safer data isolation

**Key Pattern**: `DropboxService` is an actor, ensuring thread-safe access to Dropbox client state. All service methods are `async` and must be awaited.

## Dependencies

- **SwiftyDropbox** (v10.2.4+): Official Dropbox SDK for Swift
- **swift-sdk** (main branch): Model Context Protocol SDK for MCP implementation
- **swift-log**: Logging framework (available via dependencies)

## Configuration

Dropbook requires these environment variables:

**Required:**
- `DROPBOX_APP_KEY`: Dropbox app key
- `DROPBOX_APP_SECRET`: Dropbox app secret

**Optional (for legacy mode):**
- `DROPBOX_ACCESS_TOKEN`: Bearer token for API calls
- `DROPBOX_REFRESH_TOKEN`: Refresh token (used with access token for automatic refreshing)

**Recommended**: Use `swift run dropbook login` to authenticate via OAuth and store tokens in `~/.dropbook/auth.json`. This provides automatic token refreshing.

The `DropbookConfig.loadFromEnvironment()` method reads environment variables, while `DropbookConfig.loadFromStorage()` reads from the token storage file. Missing required variables throw `DropboxError.notConfigured`.

## Key Patterns & Design Decisions

**Actor-based Concurrency**: `DropboxService` uses Swift actors for safe concurrent access to the Dropbox client.

**Lazy Authentication**: The Dropbox client is initialized on first use via `getClient()`, which calls `authenticate()` if needed. This allows the service to be created before credentials are validated.

**Model Conversions**: SwiftyDropbox types (e.g., `Files.FileMetadata`) are converted to domain models (`DropboxItem`) at the service layer. This isolates the core library from third-party SDK changes.

**MCP Tool Definitions**: Tools are defined in the `ListTools` handler with JSON schemas. Arguments are type-extracted from `[String: Value]` using helper functions (`extractString`, `extractBool`).

**Error Handling**: Domain-specific errors (`DropboxError`, `MCPError`, `DropbookCLIError`) provide context. CLI commands catch these and display user-friendly messages.

## Testing & Scripts

- `scripts/run-mcp.sh`: Starts the MCP server with environment loaded from `~/.clawdbot/dropbox.env`
- `scripts/test-mcp.sh`: Manual integration test that sends JSON-RPC messages to the server

These scripts have hardcoded paths to `/Users/shelton/Developer/Dropbook/` and need updates for other environments.

## Common Development Tasks

**Adding a New CLI Command:**
1. Add handler function to `DropbookCLI.swift` (follow pattern of `runListCommand`)
2. Add case in `dropbookCLI()` switch statement
3. Update usage string with new command

**Adding a New MCP Tool:**
1. Add `Tool` definition in `ListTools` handler (DropbookMCP.swift)
2. Add case in `handleToolCall()` switch statement
3. Implement handler function (follow pattern of `handleListDirectory`)
4. Extract arguments and call service methods

**Modifying DropboxService:**
1. Add new public async method to `DropboxService` actor
2. Use `getClient()` to access the Dropbox API
3. Convert SwiftyDropbox types to domain models before returning
4. Throw `DropboxError` for error cases

## File Structure

```
Sources/
├── Dropbook/              # Main executable entry point
│   └── main.swift
├── DropbookCore/          # Public library
│   ├── Services/
│   │   └── DropboxService.swift
│   ├── Models/
│   │   └── DropboxItem.swift
│   ├── Config/
│   │   └── DropbookConfig.swift
│   └── Auth/
│       ├── TokenStorage.swift         # File-based token storage
│       └── KeychainTokenStorage.swift # Keychain-based secure storage
├── DropbookCLI/           # CLI interface
│   ├── DropbookCLI.swift
│   └── Commands/
│       ├── LoginCommand.swift   # OAuth PKCE flow
│       └── LogoutCommand.swift  # Token cleanup
└── DropbookMCP/           # MCP interface
    └── DropbookMCP.swift
```

## Notes for Future Development

- No test suite exists yet; manual testing via scripts is the current approach
- MCP server uses stdio transport (no HTTP/WebSocket support currently)
- All CLI output uses emoji prefixes for visual feedback
- OAuth 2.0 with PKCE and refresh tokens fully supported via DropboxOAuthManager
