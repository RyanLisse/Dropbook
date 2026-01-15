# Refresh Token Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement robust OAuth 2.0 PKCE flow and refresh token support for Dropbook.

**Architecture:** 
Implement a CLI-based PKCE flow using `DropboxOAuthManager` to obtain credentials. Store credentials (access token, refresh token, expiry) in a secure JSON file (or Keychain abstraction). Update `DropboxService` to use `ShortLivedAccessTokenProvider` via `DropboxOAuthManager` for automatic proactive token refreshing.

**Tech Stack:** SwiftyDropbox (v10.2.4), Foundation, Swift 5.9+

---

### Task 1: Update Configuration & Models

**Files:**
- Modify: `Sources/DropbookCore/Config/DropbookConfig.swift`
- Create: `Sources/DropbookCore/Auth/TokenStorage.swift`

**Step 1: Write failing test (manual)**
Create `Tests/Manual/TestConfigLoad.swift` that tries to load a config with a refresh token but fails because `DropbookConfig` doesn't support the new fields structure or storage loading.

**Step 2: Update DropbookConfig**
Update `DropbookConfig` to include:
- `tokenExpirationTimestamp: TimeInterval?`
- `uid: String?`
- Helper method `loadFromStorage()` to read from `~/.dropbook/auth.json` (or similar).

**Step 3: Create TokenStorage**
Implement `TokenStorage` struct to handle saving/loading `DropboxAccessToken` data to/from disk securely (file permissions 600).

**Step 4: Commit**
```bash
git add Sources/DropbookCore/Config/DropbookConfig.swift Sources/DropbookCore/Auth/TokenStorage.swift
git commit -m "feat: add token storage and config updates"
```

### Task 2: Implement CLI OAuth Flow

**Files:**
- Create: `Sources/DropbookCLI/Commands/LoginCommand.swift`
- Modify: `Sources/DropbookCLI/DropbookCLI.swift`

**Step 1: Create Login Logic**
Implement `runLoginCommand` that:
1. Initializes `DropboxOAuthManager` with `CommandLineScopeRequest`.
2. Generates `authorizeUrl`.
3. Prints URL and prompts user for code.
4. Calls `handleRedirectURL` to exchange code for token.
5. Saves token to `TokenStorage`.

**Step 2: Register Command**
Add `login` case to `dropbookCLI` switch in `DropbookCLI.swift`.

**Step 3: Verify (Manual)**
Run `swift run dropbook login` and verify it generates a valid URL and saves the token on success.

**Step 4: Commit**
```bash
git add Sources/DropbookCLI/Commands/LoginCommand.swift Sources/DropbookCLI/DropbookCLI.swift
git commit -m "feat: add CLI login command with PKCE flow"
```

### Task 3: Update DropboxService for Refreshing

**Files:**
- Modify: `Sources/DropbookCore/Services/DropboxService.swift`

**Step 1: Update Authenticate**
Refactor `authenticate()` to:
1. Check for `refreshToken` in config.
2. If present, initialize `DropboxOAuthManager`.
3. Create `DropboxAccessToken` object from config.
4. Initialize `DropboxClient` with `DropboxOAuthManager` and `DropboxAccessToken` (enables proactive refresh).
5. Fallback to legacy `accessToken` only initialization if no refresh token.

**Step 2: Update AGENTS.md**
Remove the "Anti-Pattern" claiming SwiftyDropbox doesn't support refresh tokens.

**Step 3: Verify**
Run `swift run dropbook list` with an expired access token (but valid refresh token) and verify it succeeds (proactive refresh).

**Step 4: Commit**
```bash
git add Sources/DropbookCore/Services/DropboxService.swift AGENTS.md
git commit -m "feat: enable automatic token refreshing in DropboxService"
```

### Task 4: Cleanup & Documentation

**Files:**
- Modify: `CLAUDE.md`
- Modify: `dropbox-skill/SKILL.md`

**Step 1: Update Docs**
Update `CLAUDE.md` and `SKILL.md` to document the new `login` command and token storage location.

**Step 2: Commit**
```bash
git add CLAUDE.md dropbox-skill/SKILL.md
git commit -m "docs: update guides with OAuth flow"
```
