# OAuth2 Optimization Plan

**Based on:** RFC 9700, OAuth 2.1, OWASP Best Practices, p2/OAuth2 patterns

---

## Task 1: Keychain-Based Token Storage

**Files:**
- Create: `Sources/DropbookCore/Auth/KeychainTokenStorage.swift`
- Modify: `Sources/DropbookCore/Auth/TokenStorage.swift` (make protocol-based)

**Implementation:**
1. Create `TokenStorageProtocol` for abstraction
2. Implement `KeychainTokenStorage` using Security framework
3. Use `kSecAttrAccessibleWhenUnlocked` for macOS CLI access
4. Fallback to file storage on Linux

---

## Task 2: Add CSRF Protection via State Parameter

**Files:**
- Modify: `Sources/DropbookCLI/Commands/LoginCommand.swift`

**Implementation:**
1. Generate cryptographically secure state parameter
2. Include state in authorization URL
3. Validate state when user provides code (optional for CLI - user validates visually)

---

## Task 3: Modernize Crypto with CryptoKit

**Files:**
- Modify: `Sources/DropbookCLI/Commands/LoginCommand.swift`

**Implementation:**
1. Replace CommonCrypto with CryptoKit
2. Use `SHA256.hash(data:)` for PKCE challenge
3. Use `SymmetricKey` for secure random generation

---

## Task 4: Add Logout Command

**Files:**
- Create: `Sources/DropbookCLI/Commands/LogoutCommand.swift`
- Modify: `Sources/DropbookCLI/DropbookCLI.swift`

**Implementation:**
1. Clear tokens from storage (Keychain or file)
2. Optional: Revoke token via Dropbox API
3. Register `logout` command in CLI

---

## Task 5: Enhanced Error Handling

**Files:**
- Modify: `Sources/DropbookCore/Models/DropboxError.swift`
- Modify: `Sources/DropbookCLI/Commands/LoginCommand.swift`

**Implementation:**
1. Add specific OAuth error types
2. Parse Dropbox OAuth error responses
3. Provide actionable error messages

---
