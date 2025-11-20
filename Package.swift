// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Photon",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Photon",
            targets: ["Photon"]
        ),
    ],
    dependencies: [
        // Add dependencies here if needed
    ],
    targets: [
        .executableTarget(
            name: "Photon",
            dependencies: [],
            path: "Sources",
            exclude: ["Bridge/typescript-bridge.ts"]
        ),
    ]
)

