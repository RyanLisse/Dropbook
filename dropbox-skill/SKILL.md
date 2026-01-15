# Dropbox Manager Skill

Manage Dropbox files via MCP server and CLI. Swift-native implementation using SwiftyDropbox SDK with OAuth 2.0 PKCE and secure Keychain token storage.

## Setup

### Prerequisites

```bash
# Clone and build Dropbook
git clone https://github.com/RyanLisse/Dropbook.git
cd Dropbook
make build
```

### Authentication

#### Option 1: OAuth Login with Keychain (Recommended)

Use the interactive OAuth flow with secure Keychain storage:

```bash
export DROPBOX_APP_KEY="your_dropbox_app_key"
export DROPBOX_APP_SECRET="your_dropbox_app_secret"
make login
# or: swift run dropbook login
```

This will:
1. Generate PKCE code verifier and challenge (SHA256, RFC 7636)
2. Open an authorization URL with state parameter (CSRF protection)
3. Prompt you to paste the authorization code
4. Exchange code for access and refresh tokens
5. **Save tokens to macOS Keychain** (hardware-backed encryption)
6. Fall back to `~/.dropbook/auth.json` if Keychain unavailable
7. Enable automatic token refreshing

**Security Features (RFC 9700 compliant):**
- PKCE with S256 challenge method
- State parameter for CSRF protection
- Keychain storage with `kSecAttrAccessibleWhenUnlocked`
- CryptoKit for cryptographic operations

#### Option 2: Environment Variables (Legacy)

```bash
export DROPBOX_APP_KEY="your_dropbox_app_key"
export DROPBOX_APP_SECRET="your_dropbox_app_secret"
export DROPBOX_ACCESS_TOKEN="your_dropbox_access_token"
```

**Note**: Manual tokens don't support automatic refreshing. Use OAuth login for production use.

### Logout

Clear stored tokens from both Keychain and file storage:

```bash
make logout
# or: swift run dropbook logout
```

## MCP Server (Recommended)

Start the MCP server:

```bash
make mcp
# or: ./.build/debug/dropbook mcp
```

### MCP Tools

| Tool | Description |
|------|-------------|
| `list_directory` | List files and folders in a Dropbox directory |
| `search` | Search for files by name or content |
| `upload` | Upload a file to Dropbox |
| `download` | Download a file from Dropbox |

#### list_directory

List files and folders in a Dropbox directory.

**Parameters:**
- `path` (string, optional): Directory path. Default: "/"

**Response:**
```json
{
  "files": [
    {"type": "file", "name": "doc.pdf", "path": "/Docs/doc.pdf", "size": 1024},
    {"type": "folder", "name": "Projects", "path": "/Projects"}
  ]
}
```

#### search

Search for files by name or content.

**Parameters:**
- `query` (string, required): Search term
- `path` (string, optional): Path to search within. Default: "/"

**Response:**
```json
{
  "count": 2,
  "results": [
    {"matchType": "filename", "metadata": {"name": "report.pdf", "path": "/Docs/report.pdf"}}
  ]
}
```

#### upload

Upload a file to Dropbox.

**Parameters:**
- `localPath` (string, required): Absolute path to local file
- `remotePath` (string, required): Destination in Dropbox
- `overwrite` (boolean, optional): Replace if exists. Default: false

**Response:**
```json
{
  "uploaded": true,
  "name": "file.txt",
  "path": "/Uploads/file.txt",
  "size": 5000
}
```

#### download

Download a file from Dropbox.

**Parameters:**
- `remotePath` (string, required): File path in Dropbox
- `localPath` (string, required): Local destination path

**Response:**
```json
{
  "downloaded": true,
  "to": "/tmp/report.pdf"
}
```

## CLI Commands

```bash
# Authentication
make login                 # OAuth login with Keychain storage
make logout                # Clear stored tokens

# File operations
make list                  # List root directory
swift run dropbook list /path

# Search files
swift run dropbook search "query" [path]

# Upload file
swift run dropbook upload /local/path /remote/path [--overwrite]

# Download file
swift run dropbook download /remote/path /local/path

# Start MCP server
make mcp
```

## MCP Client Configuration

### Claude Code (Project-level)

The project includes a `.mcp.json` file that configures the MCP server:

```json
{
  "mcpServers": {
    "dropbox": {
      "command": "/path/to/Dropbook/.build/debug/dropbook",
      "args": ["mcp"],
      "env": {
        "DROPBOX_APP_KEY": "${DROPBOX_APP_KEY}",
        "DROPBOX_APP_SECRET": "${DROPBOX_APP_SECRET}"
      }
    }
  }
}
```

Enable project MCP servers in Claude Code settings.json:
```json
{
  "enableAllProjectMcpServers": true
}
```

### Claude Desktop

```json
{
  "mcpServers": {
    "dropbox": {
      "command": "/path/to/dropbook/.build/debug/dropbook",
      "args": ["mcp"],
      "env": {
        "DROPBOX_APP_KEY": "${DROPBOX_APP_KEY}",
        "DROPBOX_APP_SECRET": "${DROPBOX_APP_SECRET}"
      }
    }
  }
}
```

## Error Handling

| Error | Cause | Solution |
|-------|-------|----------|
| `notConfigured` | Missing env vars | Set DROPBOX_APP_KEY, DROPBOX_APP_SECRET |
| `invalidArguments` | Missing required params | Check tool parameters |
| `notFound` | Path doesn't exist | Use `list_directory` to verify paths |
| `itemNotFound` | No token in Keychain | Run `make login` to authenticate |

## Architecture

```
Dropbook/
├── Sources/
│   ├── DropbookCore/           # Business logic (actor-based)
│   │   ├── Auth/               # Keychain & file token storage
│   │   ├── Config/             # Configuration management
│   │   ├── Models/             # Domain models
│   │   └── Services/           # DropboxService actor
│   ├── DropbookCLI/            # CLI adapter
│   │   └── Commands/           # Login, logout, file commands
│   └── DropbookMCP/            # MCP server
├── dropbox-skill/              # Skill documentation
├── Makefile                    # Build automation
├── .mcp.json                   # MCP server configuration
└── Package.swift
```

## Best Practices

1. **Use OAuth login** - Secure Keychain storage with automatic token refresh
2. **Use MCP for agents** - More reliable for programmatic access
3. **Validate paths first** - Use `list_directory` before operations
4. **Handle errors gracefully** - Check responses for error fields
5. **Respect rate limits** - Add delays between bulk operations
6. **Use absolute paths** - Always provide full paths for file operations

## Security

- **Keychain Storage**: Tokens stored with hardware-backed encryption
- **PKCE**: Proof Key for Code Exchange prevents authorization code interception
- **State Parameter**: CSRF protection for OAuth flow
- **Token Refresh**: Automatic refresh before expiration
- **CryptoKit**: Modern Swift cryptographic library

## Dependencies

- **SwiftyDropbox** (v10.2.4+): Official Dropbox Swift SDK
- **MCP (swift-sdk)**: Model Context Protocol SDK
- **CryptoKit**: Apple's cryptographic framework

## See Also

- [Dropbook GitHub](https://github.com/RyanLisse/Dropbook)
- [CLAUDE.md](../CLAUDE.md) - Full project documentation
- [Dropbox API Docs](https://www.dropbox.com/developers/documentation)
- [RFC 7636 - PKCE](https://datatracker.ietf.org/doc/html/rfc7636)
- [RFC 9700 - OAuth 2.0 Security Best Practices](https://datatracker.ietf.org/doc/html/rfc9700)
