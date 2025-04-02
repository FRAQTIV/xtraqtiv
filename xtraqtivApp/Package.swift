// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ExtraqtivApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "ExtraqtivApp",
            targets: ["ExtraqtivApp"]
        ),
    ],
    dependencies: [
        .package(path: "../ExtraqtivCore"),
    ],
    targets: [
        .executableTarget(
            name: "ExtraqtivApp",
            dependencies: [
                .product(name: "ExtraqtivCore", package: "ExtraqtivCore")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ExtraqtivAppTests",
            dependencies: ["ExtraqtivApp"]
        ),
    ]
)

