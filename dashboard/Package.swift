// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AIFWDashboard",
    platforms: [.macOS(.v13)],
    products: [
        .executable(
            name: "aifw-dashboard",
            targets: ["AIFWDashboard"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AIFWDashboard",
            dependencies: [],
            path: "Sources"
        )
    ]
)
