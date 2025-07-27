// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "HelloPrompt",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "HelloPrompt", targets: ["HelloPrompt"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "HelloPrompt",
            dependencies: [],
            path: "Sources/HelloPrompt",
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "HelloPromptTests",
            dependencies: ["HelloPrompt"],
            path: "Tests"
        )
    ]
)