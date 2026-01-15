# Dropbox Manager Skill

Manage Dropbox files via MCP server and CLI. Swift-native implementation using SwiftyDropbox SDK.

## Setup

### Prerequisites

```bash
# Clone and build Dropbook
git clone https://github.com/code-yeongyu/Dropbook.git
cd Dropbook
swift build
```

### Authentication

#### Option 1: OAuth Login (Recommended)

Use the interactive OAuth flow to authenticate:

```bash
export DROPBOX_APP_KEY="your_dropbox_app_key"
export DROPBOX_APP_SECRET="your_dropbox_app_secret"
swift run dropbook login
```

This will:
1. Open an authorization URL in your browser
2. Prompt you to paste the authorization code
3. Save access and refresh tokens to `~/.dropbook/auth.json`
4. Enable automatic token refreshing

#### Option 2: Environment Variables (Legacy)

```bash
export DROPBOX_APP_KEY="your_dropbox_app_key"
export DROPBOX_APP_SECRET="your_dropbox_app_secret"
export DROPBOX_ACCESS_TOKEN="your_dropbox_access_token"
```

**To generate an access token manually:**
1. Go to https://www.dropbox.com/developers/apps
2. Select your app or create a new one
3. Under "Permissions", enable required scopes:
   - `account_info.read`
   - `files.metadata.read`
   - `files.metadata.write`
   - `files.content.read`
   - `files.content.write`
4. Under "Settings" > "OAuth 2", generate an access token

**Note**: Manual tokens don't support automatic refreshing. Use OAuth login for production use.

## MCP Server (Recommended)

Start the MCP server:

```bash
./.build/debug/dropbook mcp
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
# List directory
swift run dropbook list /path

# Search files
swift run dropbook search "query" [path]

# Upload file
swift run dropbook upload /local/path /remote/path [--overwrite]

# Download file
swift run dropbook download /remote/path /local/path

# Start MCP server
swift run dropbook mcp
```

## MCP Client Configuration

### Claude Desktop

```json
{
  "mcpServers": {
    "dropbox": {
      "command": "/path/to/dropbook/.build/debug/dropbook",
      "args": ["mcp"],
      "env": {
        "DROPBOX_APP_KEY": "${DROPBOX_APP_KEY}",
        "DROPBOX_APP_SECRET": "${DROPBOX_APP_SECRET}",
        "DROPBOX_ACCESS_TOKEN": "${DROPBOX_ACCESS_TOKEN}"
      }
    }
  }
}
```

### Claude Code

Add to your CLAUDE.md:

```markdown
## Dropbox Integration

Use the `dropbox-skill` skill for file operations:

1. Ensure Dropbook is built: `cd /path/to/Dropbook && swift build`
2. Configure environment variables
3. The skill provides `list_directory`, `search`, `upload`, and `download` tools
```

## Error Handling

| Error | Cause | Solution |
|-------|-------|----------|
| `notConfigured` | Missing env vars | Set DROPBOX_APP_KEY, DROPBOX_APP_SECRET, DROPBOX_ACCESS_TOKEN |
| `invalidArguments` | Missing required params | Check tool parameters |
| `notFound` | Path doesn't exist | Use `list_directory` to verify paths |

## Architecture

```
Dropbook/
├── Sources/
│   ├── DropbookCore/     # Business logic (actor-based)
│   ├── DropbookCLI/      # CLI adapter
│   └── DropbookMCP/      # MCP server
└── Package.swift
```

## Best Practices

1. **Use MCP for agents** - More reliable for programmatic access
2. **Validate paths first** - Use `list_directory` before operations
3. **Handle errors gracefully** - Check responses for error fields
4. **Respect rate limits** - Add delays between bulk operations
5. **Use absolute paths** - Always provide full paths for file operations

## Dependencies

- **SwiftyDropbox**: Official Dropbox Swift SDK
- **MCP (swift-sdk)**: Model Context Protocol SDK

## See Also

- [Dropbook GitHub](https://github.com/code-yeongyu/Dropbook)
- [CLAUDE.md](../CLAUDE.md) - Full project documentation
- [Dropbox API Docs](https://www.dropbox.com/developers/documentation)
