// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "WorkerflowMac",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "WorkerflowMac", targets: ["WorkerflowMac"])
    ],
    targets: [
        .target(
            name: "WorkerflowMacCore",
            path: "Sources/WorkerflowMacCore"
        ),
        .executableTarget(
            name: "WorkerflowMac",
            dependencies: ["WorkerflowMacCore"],
            path: "Sources/WorkerflowMac"
        ),
        .testTarget(
            name: "WorkerflowMacCoreTests",
            dependencies: ["WorkerflowMacCore"],
            path: "Tests/WorkerflowMacCoreTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
