// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "xtraqtivCore",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "xtraqtivCore",
            targets: ["xtraqtivCore"]),
    ],
    dependencies: [
        // Dependencies on other packages.
        .package(
            url: "https://github.com/evernote/evernote-cloud-sdk-ios",
            branch: "master"
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        .target(
            name: "xtraqtivCore",
            dependencies: [
                .product(name: "EvernoteSDK", package: "evernote-cloud-sdk-ios")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "xtraqtivCoreTests",
            dependencies: ["xtraqtivCore"],
            path: "Tests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)

