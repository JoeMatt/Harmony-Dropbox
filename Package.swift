// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Harmony-Dropbox",
    platforms: [
        .iOS(.v12),
        .tvOS(.v12),
        .macCatalyst(.v13),
        .macOS(.v12),
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
        .package(url: "https://github.com/JoeMatt/Roxas.git", from: "1.2.0"),
        .package(url: "https://github.com/JoeMatt/Harmony.git", from: "1.2.4"),
//        .package(path: "../Harmony"),
    ],
    targets: [
        .target(
            name: "Harmony-Dropbox",
            dependencies: ["SwiftyDropbox", "Harmony"]
        ),
        .executableTarget(
            name: "Harmony-DropboxExample",
            dependencies: [
                "Harmony-Dropbox",
                .product(name: "HarmonyExample", package: "Harmony"),
                .product(name: "RoxasUI", package: "Roxas", condition: .when(platforms: [.iOS, .tvOS, .macCatalyst])),
            ],
            linkerSettings: [
                .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS, .macCatalyst])),
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
                .linkedFramework("Cocoa", .when(platforms: [.macOS])),
                .linkedFramework("CoreData"),
            ]
        ),
        .testTarget(
            name: "Harmony-DropboxTests",
            dependencies: ["Harmony"]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
