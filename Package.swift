// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ChatAPIClient",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ChatAPIClient",
            targets: ["ChatAPIClient"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ChatAPIClient",
            dependencies: [],
            path: "Sources/ChatAPIClient"
        ),
        .testTarget(
            name: "ChatAPIClientTests",
            dependencies: ["ChatAPIClient"],
            path: "Tests/ChatAPIClientTests"
        ),
    ]
)
