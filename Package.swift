// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Dropbook",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "DropbookCore", targets: ["DropbookCore"]),
        .executable(name: "dropbook", targets: ["dropbook"]),
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", branch: "main"),
        .package(url: "https://github.com/dropbox/SwiftyDropbox.git", from: "10.2.4"),
    ],
    targets: [
        // Core library - framework-agnostic
        .target(
            name: "DropbookCore",
            dependencies: [
                .product(name: "SwiftyDropbox", package: "SwiftyDropbox"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ]
        ),

        // CLI module
        .target(
            name: "DropbookCLI",
            dependencies: [
                "DropbookCore",
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ]
        ),

        // MCP server module
        .target(
            name: "DropbookMCP",
            dependencies: [
                "DropbookCore",
                .product(name: "MCP", package: "swift-sdk"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ]
        ),

        // Main executable
        .executableTarget(
            name: "dropbook",
            dependencies: [
                "DropbookCLI",
                "DropbookMCP",
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ]
        ),
    ]
)
