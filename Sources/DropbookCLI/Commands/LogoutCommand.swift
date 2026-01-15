import Foundation
import DropbookCore

// MARK: - Logout Command

/// Clear stored OAuth tokens from all storage locations
public func runLogoutCommand() async throws {
    print("🔓 Dropbook Logout")
    print("==================\n")

    var clearedKeychain = false
    var clearedFile = false

    // Clear from Keychain
    #if os(macOS) || os(iOS)
    do {
        let keychain = KeychainTokenStorage()
        if keychain.exists() {
            try keychain.delete()
            clearedKeychain = true
            print("✅ Cleared tokens from Keychain")
        }
    } catch {
        print("⚠️  Failed to clear Keychain: \(error.localizedDescription)")
    }
    #endif

    // Clear from file storage
    do {
        let storage = try TokenStorage()
        if storage.exists() {
            try storage.delete()
            clearedFile = true
            print("✅ Cleared tokens from ~/.dropbook/auth.json")
        }
    } catch {
        print("⚠️  Failed to clear file storage: \(error.localizedDescription)")
    }

    if clearedKeychain || clearedFile {
        print("\n🔒 Successfully logged out!")
        print("💡 Run 'dropbook login' to authenticate again")
    } else {
        print("ℹ️  No stored credentials found")
    }
}
