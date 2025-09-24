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
    dependencies: [
        .package(url: "https://github.com/socketio/socket.io-client-swift", from: "16.0.0")
    ],
    targets: [
        .target(
            name: "ChatAPIClient",
            dependencies: [
                .product(name: "SocketIO", package: "socket.io-client-swift")
            ],
            path: "Sources/ChatAPIClient"
        ),
        .testTarget(
            name: "ChatAPIClientTests",
            dependencies: ["ChatAPIClient"],
            path: "Tests/ChatAPIClientTests"
        ),
    ]
)
