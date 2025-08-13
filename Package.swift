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
        )
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.15.0"),
        .package(url: "https://github.com/apollographql/apollo-ios", from: "1.7.0")
    ],
    targets: [
        .executableTarget(
            name: "MenuBarApp",
            dependencies: [
                .product(name: "Apollo", package: "apollo-ios"),
                .product(name: "ApolloAPI", package: "apollo-ios")
            ],
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