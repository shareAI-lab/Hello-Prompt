// swift-tools-version: 5.10
//
//  Package.swift
//  HelloPrompt
//
//  Hello Prompt v2 - 极简的macOS语音到AI提示词转换工具
//  专业音频处理 + OpenAI集成 + 美观UI设计
//

import PackageDescription

let package = Package(
    name: "HelloPromptV2",
    platforms: [
        .macOS(.v12)  // 支持 macOS 12.0+
    ],
    products: [
        .executable(
            name: "HelloPromptV2",
            targets: ["HelloPrompt"]
        )
    ],
    dependencies: [
        // 音频处理增强框架
        .package(url: "https://github.com/AudioKit/AudioKit.git", from: "5.6.0"),
        
        // 全局键盘快捷键支持
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "1.14.0"),
        
        // 用户配置安全存储
        .package(url: "https://github.com/sindresorhus/Defaults.git", from: "7.1.0"),
        
        // OpenAI API 官方客户端
        .package(url: "https://github.com/MacPaw/OpenAI.git", from: "0.2.4"),
        
        // 异步工具库
        .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "HelloPrompt",
            dependencies: [
                // 音频处理依赖
                .product(name: "AudioKit", package: "AudioKit"),
                
                // 快捷键管理
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                
                // 配置管理
                .product(name: "Defaults", package: "Defaults"),
                
                // OpenAI API
                .product(name: "OpenAI", package: "OpenAI"),
                
                // 异步算法
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
            ],
            path: "Sources/HelloPrompt",
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableUpcomingFeature("ConciseMagicFile"),
                .enableUpcomingFeature("ForwardTrailingClosures"),
                .enableUpcomingFeature("ImplicitOpenExistentials"),
                // 暂时禁用严格并发检查以兼容Swift 6语法
                .unsafeFlags(["-Xfrontend", "-disable-availability-checking"]),
                .define("SWIFT_STRICT_CONCURRENCY_MINIMAL")
            ]
        ),
        .testTarget(
            name: "HelloPromptTests",
            dependencies: [
                "HelloPrompt"
            ],
            path: "Tests/HelloPromptTests"
        )
    ]
)