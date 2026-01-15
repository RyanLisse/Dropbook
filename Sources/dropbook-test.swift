import Foundation
import DropbookCore

// Simple test without MCP
@main
struct DropbookTest {
    static func main() async throws {
        print("Testing Dropbook Service...")
        
        do {
            let config = try DropbookConfig.loadFromEnvironment()
            print("✅ Config loaded")
            
            let service = DropboxService(config: config)
            print("✅ Service created")
            
            // Try to authenticate
            try service.authenticate()
            print("✅ Authenticated")
            
            // Try to list files
            let items = try await service.listFiles(path: "")
            print("✅ Found \(items.count) items")
            
            for item in items {
                print("  - \(item.name)")
            }
        } catch {
            print("❌ Error: \(error.localizedDescription)")
            throw error
        }
    }
}
