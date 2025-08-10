// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MenuBarApp",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.15.0")
    ],
    products: [
        .executable(
            name: "MenuBarApp",
            targets: ["MenuBarApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "MenuBarApp",
            path: "Sources/MenuBarApp"
        ),
        .testTarget(
            name: "MenuBarAppTests",
            dependencies: [
                "MenuBarApp",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            path: "Tests/MenuBarAppTests"
        )
    ]
)