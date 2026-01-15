import Foundation
import SwiftyDropbox
import DropbookCore
import CryptoKit

// MARK: - Login Command

public func runLoginCommand() async throws {
    print("🔐 Dropbook OAuth Login")
    print("=======================\n")

    guard let appKey = ProcessInfo.processInfo.environment["DROPBOX_APP_KEY"],
          let appSecret = ProcessInfo.processInfo.environment["DROPBOX_APP_SECRET"] else {
        throw DropboxError.notConfigured
    }

    let scopeRequest = ScopeRequest(
        scopeType: .user,
        scopes: [
            "account_info.read",
            "files.metadata.read",
            "files.metadata.write",
            "files.content.read",
            "files.content.write"
        ],
        includeGrantedScopes: false
    )

    // Generate PKCE data using CryptoKit
    let pkceData = generatePKCEData()

    // Generate state parameter for CSRF protection (RFC 9700)
    let state = generateSecureState()

    let authURL = buildAuthURL(
        appKey: appKey,
        codeChallenge: pkceData.codeChallenge,
        state: state,
        scopeRequest: scopeRequest
    )

    print("📋 Step 1: Visit this URL in your browser:")
    print("\n\(authURL)\n")
    print("📋 Step 2: After authorizing, you'll be redirected to a URL like:")
    print("   db-\(appKey)://2/token?code=AUTHORIZATION_CODE&state=\(state)")
    print("\n⚠️  Verify the state parameter matches: \(state)")
    print("\n📋 Step 3: Paste the AUTHORIZATION_CODE here:")
    print("Code: ", terminator: "")

    guard let authCode = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines),
          !authCode.isEmpty else {
        print("❌ No authorization code provided")
        throw DropboxError.authenticationFailed
    }

    print("\n🔄 Exchanging authorization code for access token...")

    let token = try await exchangeCodeForToken(
        appKey: appKey,
        appSecret: appSecret,
        authCode: authCode,
        codeVerifier: pkceData.codeVerifier
    )

    // Save to both Keychain (secure) and file (backup)
    try saveToken(token)

    print("✅ Successfully authenticated!")
    #if os(macOS) || os(iOS)
    print("🔐 Token saved to Keychain (secure)")
    #endif
    print("📁 Backup saved to: ~/.dropbook/auth.json")
    print("\n💡 You can now use other dropbook commands without DROPBOX_ACCESS_TOKEN")
}

// MARK: - Token Storage

private func saveToken(_ token: DropboxAccessToken) throws {
    let tokenData = StoredTokenData(
        accessToken: token.accessToken,
        refreshToken: token.refreshToken,
        expirationTimestamp: token.tokenExpirationTimestamp,
        uid: token.uid
    )

    // Save to Keychain (primary, secure)
    #if os(macOS) || os(iOS)
    let keychain = KeychainTokenStorage()
    try keychain.save(tokenData)
    #endif

    // Save to file (backup, for Linux compatibility)
    let storage = try TokenStorage()
    try storage.save(token: token)
}

// MARK: - PKCE Implementation (CryptoKit)

private struct PKCEData {
    let codeVerifier: String
    let codeChallenge: String
}

/// Generate PKCE data using CryptoKit (RFC 7636)
private func generatePKCEData() -> PKCEData {
    // Generate 32 bytes of secure random data -> 43 base64url chars after encoding
    // This meets RFC 7636 requirement of 43-128 characters
    let codeVerifier = generateSecureRandomString(byteCount: 32)
    let codeChallenge = sha256Challenge(from: codeVerifier)
    return PKCEData(codeVerifier: codeVerifier, codeChallenge: codeChallenge)
}

/// Generate cryptographically secure random string using Security framework
private func generateSecureRandomString(byteCount: Int) -> String {
    var bytes = [UInt8](repeating: 0, count: byteCount)
    _ = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
    return Data(bytes).base64URLEncodedString()
}

/// Generate state parameter for CSRF protection (RFC 9700)
private func generateSecureState() -> String {
    return generateSecureRandomString(byteCount: 16)
}

/// Create S256 code challenge from verifier using CryptoKit
private func sha256Challenge(from verifier: String) -> String {
    let data = Data(verifier.utf8)
    let hash = SHA256.hash(data: data)
    return Data(hash).base64URLEncodedString()
}

// MARK: - URL Building

private func buildAuthURL(
    appKey: String,
    codeChallenge: String,
    state: String,
    scopeRequest: ScopeRequest
) -> String {
    var components = URLComponents(string: "https://www.dropbox.com/oauth2/authorize")!

    var queryItems = [
        URLQueryItem(name: "client_id", value: appKey),
        URLQueryItem(name: "response_type", value: "code"),
        URLQueryItem(name: "code_challenge", value: codeChallenge),
        URLQueryItem(name: "code_challenge_method", value: "S256"),
        URLQueryItem(name: "token_access_type", value: "offline"),
        URLQueryItem(name: "state", value: state)  // CSRF protection (RFC 9700)
    ]

    if !scopeRequest.scopes.isEmpty {
        queryItems.append(URLQueryItem(name: "scope", value: scopeRequest.scopes.joined(separator: " ")))
    }

    components.queryItems = queryItems
    return components.url!.absoluteString
}

// MARK: - Token Exchange

private func exchangeCodeForToken(
    appKey: String,
    appSecret: String,
    authCode: String,
    codeVerifier: String
) async throws -> DropboxAccessToken {
    var request = URLRequest(url: URL(string: "https://api.dropboxapi.com/oauth2/token")!)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

    // Basic auth header with credentials
    let credentials = "\(appKey):\(appSecret)".data(using: .utf8)!.base64EncodedString()
    request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")

    let bodyParams = [
        "code": authCode,
        "grant_type": "authorization_code",
        "code_verifier": codeVerifier
    ]

    let bodyString = bodyParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
    request.httpBody = bodyString.data(using: .utf8)

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
        throw OAuthError.invalidResponse
    }

    guard httpResponse.statusCode == 200 else {
        // Parse OAuth error response for better error messages
        if let errorResponse = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data) {
            throw OAuthError.serverError(
                error: errorResponse.error,
                description: errorResponse.errorDescription
            )
        }
        throw OAuthError.httpError(statusCode: httpResponse.statusCode)
    }

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let tokenResponse = try decoder.decode(TokenResponse.self, from: data)

    return DropboxAccessToken(
        accessToken: tokenResponse.accessToken,
        uid: tokenResponse.uid ?? "",
        refreshToken: tokenResponse.refreshToken,
        tokenExpirationTimestamp: Date().timeIntervalSince1970 + Double(tokenResponse.expiresIn ?? 14400)
    )
}

// MARK: - Response Models

private struct TokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int?
    let refreshToken: String?
    let scope: String?
    let uid: String?
    let accountId: String?
}

private struct OAuthErrorResponse: Codable {
    let error: String
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

// MARK: - OAuth Errors

public enum OAuthError: Error, LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    case serverError(error: String, description: String?)
    case invalidState

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from OAuth server"
        case .httpError(let statusCode):
            return "OAuth request failed with status \(statusCode)"
        case .serverError(let error, let description):
            return "OAuth error: \(error)" + (description.map { " - \($0)" } ?? "")
        case .invalidState:
            return "Invalid state parameter - possible CSRF attack"
        }
    }
}

// MARK: - Base64URL Extension

extension Data {
    /// Base64URL encoding (RFC 4648) - used for PKCE
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
