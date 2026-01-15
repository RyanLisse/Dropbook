# DropbookCLI

## OVERVIEW
CLI adapter for Dropbook, providing a human-readable interface for Dropbox operations via `DropbookCore`.

## STRUCTURE
```
Sources/DropbookCLI/
└── DropbookCLI.swift    ← Command dispatcher and handler implementations
```

## WHERE TO LOOK
- `dropbookCLI(service:args:)`: The main entry point for the CLI target, responsible for command routing.
- `DropbookCLIError`: Custom error types for command validation and execution failures.
- `run[Command]Command`: Private helper functions that translate CLI arguments into `DropboxService` calls.

## CONVENTIONS
- **Emoji Prefixes**: All user-facing output uses emoji prefixes to denote file types and operation status:
  - 📄 File
  - 📁 Folder
  - ✅ Success
  - ❌ Error
  - 🔍 Search result
- **Argument Handling**: Uses standard `CommandLine.arguments` (passed via `args`) and manual array slicing to handle subcommands and flags.
- **Error Reporting**: Catches `DropbookCLIError` at the top level to print standardized usage instructions and error messages.

## ANTI-PATTERNS
- **No Complex Logic**: All actual Dropbox API interaction must reside in `DropbookCore`. This module should only handle input/output.
- **Strict Error Wrapping**: Use `DropbookCLIError.commandExecutionFailed` to wrap underlying service errors to ensure consistent formatting.
- **Avoid Foundation Slicing**: Prefer `Array(args.dropFirst())` for subcommand argument passing to avoid `ArraySlice` indexing pitfalls.
