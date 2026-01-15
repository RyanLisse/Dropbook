# DropbookMCP: Swift MCP Server implementation

## OVERVIEW
Dropbox-backed Model Context Protocol (MCP) server providing file operation tools for AI agents.

## STRUCTURE
- `Sources/DropbookMCP/DropbookMCP.swift`: Single-file actor implementation of the server and tool handlers.
- `Sources/DropbookMCP/handlers/`: Empty directory (reserved for future refactoring).

## WHERE TO LOOK
- `DropbookMCP.serve()`: Server initialization, tool registration, and stdio transport setup.
- `handleToolCall()`: Main dispatcher for incoming JSON-RPC tool requests.
- `MARK: - Tool Handlers`: Implementation of `list_directory`, `search`, `upload`, and `download`.
- `MARK: - Value Extraction`: Helpers for safe JSON parameter parsing (`extractString`, `extractBool`).

## CONVENTIONS
- **JSON-RPC over stdio**: stdout is strictly for protocol; use `stderr` for logging.
- **Actor Isolation**: All server logic is actor-isolated for thread safety.
- **Protocol Schema**: Tools define input schemas matching `DropboxService` requirements.

## ANTI-PATTERNS
- **DO NOT** use `print()`—it corrupts the JSON-RPC stream. Use `fputs(..., stderr)`.
- **DO NOT** bypass `Value` extraction helpers when reading tool arguments.
- **NEVER** block the `serve()` loop with synchronous file I/O—use `await`.
- **DO NOT** add new files to `handlers/` unless refactoring the entire toolset.
