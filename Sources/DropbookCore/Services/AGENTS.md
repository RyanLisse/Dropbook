# DROPBOOK SERVICES

## OVERVIEW

Core business logic layer for Dropbox operations, implemented as a thread-safe Swift actor.

## STRUCTURE

```
./AGENTS.md             ← You are here
DropboxService.swift    ← Main service actor (async operations)
```

## WHERE TO LOOK

| Logic Area | Method / Location |
|------------|-------------------|
| Lazy Auth | `getClient() -> authenticate()` |
| File Listing | `listFiles(path:)` |
| Search | `search(query:path:)` |
| Uploads | `uploadFile(localPath:remotePath:overwrite:)` |
| Downloads | `downloadFile()` / `downloadData()` |
| Account Info | `getAccountInfo()` |

## CONVENTIONS

- **Actor-Based**: `DropboxService` is an actor; all public methods are `async` and must be `await`ed.
- **Lazy Initialization**: The `DropboxClient` is not initialized until the first API call via `getClient()`.
- **Model Conversion**: All `SwiftyDropbox` types are converted to `DropboxItem` domain models within this layer.
- **Path Handling**: Root is represented by an empty string `""` or `"/"` depending on the operation.

## ANTI-PATTERNS

- **NEVER** expose `SwiftyDropbox` types to callers (CLI/MCP).
- **DO NOT** manually initialize `DropboxClient` outside of `authenticate()`.
- **AVOID** synchronous file system calls inside actor methods; use `Data(contentsOf:)` or `write(to:)` judiciously.
- **AVOID** manual token refresh logic: `DropboxService.authenticate()` handles refresh tokens automatically via `DropboxOAuthManager` when both access and refresh tokens are present.
