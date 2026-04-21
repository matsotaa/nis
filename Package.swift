// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NIS",
    platforms: [
        .iOS(.v15),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "NIS",
            targets: ["NIS"]
        ),
    ],
    targets: [
        .target(
            name: "NIS"),
        .testTarget(
            name: "NISTests",
            dependencies: ["NIS"]
        ),
    ]
)
