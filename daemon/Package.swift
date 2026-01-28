// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AIFW",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "AIFW",
            targets: ["AIFW"]
        ),
        .executable(
            name: "aifw-daemon",
            targets: ["aifw-daemon"]
        ),
        .executable(
            name: "test-prompt",
            targets: ["test-prompt"]
        )
    ],
    targets: [
        // Library target - contains all core functionality
        .target(
            name: "AIFW",
            dependencies: [],
            path: "Sources/AIFW",
            linkerSettings: [
                .linkedLibrary("EndpointSecurity"),
                .linkedLibrary("bsm")
            ]
        ),

        // Executable target - daemon entry point
        .executableTarget(
            name: "aifw-daemon",
            dependencies: ["AIFW"],
            path: "Sources/aifw-daemon"
        ),

        // Test prompt utility
        .executableTarget(
            name: "test-prompt",
            dependencies: ["AIFW"],
            path: "Sources/test-prompt"
        ),

        // Test target
        .testTarget(
            name: "AIFWTests",
            dependencies: ["AIFW"],
            path: "Tests/AIFWTests"
        )
    ]
)
