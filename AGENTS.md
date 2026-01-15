# PROJECT KNOWLEDGE BASE

**Generated:** 2026-01-15 12:42
**Branch:** local-dev

## OVERVIEW

Swift CLI + MCP server for Dropbox file operations. Three interfaces: CLI (interactive), Library (DropbookCore), MCP (AI tools).

## STRUCTURE

```
./AGENTS.md          ← You are here
CLAUDE.md            ← Full project docs (read this first)
Package.swift        ← SPM config, Swift 6 features
Sources/
├── Dropbook/        ← Entry point (main.swift)
├── DropbookCore/    ← Business logic (actor-based)
├── DropbookCLI/     ← CLI adapter
└── DropbookMCP/     ← MCP server adapter
scripts/             ← Shell scripts (hardcoded paths ⚠️)
```

## WHERE TO LOOK

| Task | Location |
|------|----------|
| Add CLI command | `Sources/DropbookCLI/DropbookCLI.swift` |
| Add MCP tool | `Sources/DropbookMCP/DropbookMCP.swift` |
| Dropbox API logic | `Sources/DropbookCore/Services/DropboxService.swift` |
| Domain models | `Sources/DropbookCore/Models/DropboxItem.swift` |
| Config loading | `Sources/DropbookCore/Config/DropbookConfig.swift` |

## ANTI-PATTERNS (THIS PROJECT)

- **NEVER** leak `SwiftyDropbox` types outside `DropbookCore` — convert to `DropboxItem`
- **DO NOT** call service methods without `await` — all are `async`
- **DO NOT** init `DropboxService` in MCP mode until first tool call
- **NEVER** hardcode credentials — load from env vars
- **DO NOT** use HTTP/WebSocket for MCP — stdio only

## CONVENTIONS

- **StrictConcurrency**: All targets enable `StrictConcurrency`
- **Upcoming features**: `ExistentialAny`, `NonisolatedNonsendingByDefault`
- **Actor isolation**: `DropboxService` and `DropbookMCP` are actors
- **Emoji output**: CLI uses emoji prefixes for feedback
- **Error types**: `DropboxError`, `MCPError`, `DropbookCLIError`

## COMMANDS

```bash
swift build                    # Debug build
swift build -c release         # Release build
swift run dropbook login       # OAuth login (saves tokens)
swift run dropbook list /path  # CLI list
swift run dropbook search "q"  # CLI search
swift run dropbook upload src dst
swift run dropbook download src dst
swift run dropbook mcp         # MCP server (stdio)
```

## NOTES

- OAuth 2.0 with PKCE and refresh tokens fully supported
- Tokens stored in `~/.dropbook/auth.json` (file permissions 600)
- Automatic token refreshing via `DropboxOAuthManager`
- No automated tests — manual via `scripts/test-mcp.sh`
- Scripts contain hardcoded `/Users/shelton/` paths ⚠️
- Orphaned file: `Sources/dropbook-test.swift` (not in any target)
- Empty dir: `Sources/DropbookMCP/handlers/`
