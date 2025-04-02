// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "xtraqtivApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "xtraqtivApp",
            targets: ["xtraqtivApp"]
        ),
    ],
    dependencies: [
        .package(path: "../xtraqtivCore"),
    ],
    targets: [
        .executableTarget(
            name: "xtraqtivApp",
            dependencies: [
                .product(name: "xtraqtivCore", package: "xtraqtivCore")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "xtraqtivAppTests",
            dependencies: ["xtraqtivApp"]
        ),
    ]
)

