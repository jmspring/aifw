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
        )
    ],
    targets: [
        // Library target - contains all core functionality
        .target(
            name: "AIFW",
            dependencies: [],
            path: "Sources/AIFW"
        ),

        // Executable target - daemon entry point
        .executableTarget(
            name: "aifw-daemon",
            dependencies: ["AIFW"],
            path: "Sources/aifw-daemon"
        ),

        // Test target
        .testTarget(
            name: "AIFWTests",
            dependencies: ["AIFW"],
            path: "Tests/AIFWTests"
        )
    ]
)
