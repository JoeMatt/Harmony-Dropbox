// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Harmony-Dropbox",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "Harmony-Dropbox",
            targets: ["Harmony-Dropbox"]
        ),
        .library(
            name: "Harmony-Dropbox-Dynamic",
            type: .dynamic,
            targets: ["Harmony-Dropbox"]
        ),
        .library(
            name: "Harmony-Dropbox-Static",
            type: .static,
            targets: ["Harmony-Dropbox"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/dropbox/SwiftyDropbox.git", from: "9.1.0"),
         .package(url: "https://github.com/JoeMatt/Harmony.git", from: "1.0.0")
//        .package(path: "../Harmony")
    ],
    targets: [
        .target(
            name: "Harmony-Dropbox",
            dependencies: ["SwiftyDropbox", "Harmony"]
        )
    ]
)
