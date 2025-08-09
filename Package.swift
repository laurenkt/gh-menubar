// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MenuBarApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "MenuBarApp",
            targets: ["MenuBarApp"]
        ),
        .executable(
            name: "MenuBarAppTests",
            targets: ["MenuBarAppTests"]
        )
    ],
    targets: [
        .executableTarget(
            name: "MenuBarApp",
            path: "Sources/MenuBarApp"
        ),
        .executableTarget(
            name: "MenuBarAppTests",
            path: "Tests/MenuBarAppTests"
        )
    ]
)