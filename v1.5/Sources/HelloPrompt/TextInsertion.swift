//
//  TextInsertion.swift
//  HelloPrompt
//
//  文本插入服务 - 实现多应用支持、光标定位、剪贴板操作
//  Copyright © 2025 HelloPrompt. All rights reserved.
//

import Foundation
import AppKit
import ApplicationServices

// MARK: - 插入模式
enum TextInsertionMode {
    case clipboard      // 通过剪贴板插入
    case accessibility  // 通过辅助功能API插入
    case keystroke     // 通过模拟按键插入
    case direct        // 直接API插入（支持的应用）
}

// MARK: - 插入配置
struct TextInsertionConfig {
    let mode: TextInsertionMode
    let preserveClipboard: Bool        // 是否保留原剪贴板内容
    let replaceSelection: Bool         // 是否替换当前选中内容
    let addLineBreaks: Bool           // 是否在插入前后添加换行
    let trimWhitespace: Bool          // 是否清理首尾空白
    let timeout: TimeInterval         // 插入超时时间
    
    static let `default` = TextInsertionConfig(
        mode: .clipboard,
        preserveClipboard: true,
        replaceSelection: true,
        addLineBreaks: false,
        trimWhitespace: true,
        timeout: 5.0
    )
}

// MARK: - 应用信息
struct AppInfo {
    let bundleId: String
    let name: String
    let pid: pid_t
    let isActive: Bool
    let supportsAccessibility: Bool
    let insertionMode: TextInsertionMode
}

// MARK: - 插入结果
struct InsertionResult {
    let success: Bool
    let targetApp: AppInfo
    let insertedText: String
    let mode: TextInsertionMode
    let duration: TimeInterval
    let error: Error?
}

// MARK: - 文本插入代理协议
@MainActor
protocol TextInsertionDelegate: AnyObject {
    func textInsertion(_ service: TextInsertion, willInsertText text: String, to app: AppInfo)
    func textInsertion(_ service: TextInsertion, didCompleteInsertion result: InsertionResult)
    func textInsertion(_ service: TextInsertion, didFailWithError error: Error)
}

// MARK: - 文本插入服务主类
@MainActor
class TextInsertion: NSObject {
    
    // MARK: - Properties
    weak var delegate: TextInsertionDelegate?
    
    private var defaultConfig: TextInsertionConfig
    private var appSpecificConfigs: [String: TextInsertionConfig] = [:]
    private var originalClipboardContent: String?
    
    // 支持的应用列表及其最优插入模式
    private let supportedApps: [String: TextInsertionMode] = [
        "com.apple.dt.Xcode": .accessibility,
        "com.microsoft.VSCode": .accessibility,
        "com.jetbrains.intellij": .accessibility,
        "com.apple.TextEdit": .clipboard,
        "com.apple.Notes": .clipboard,
        "com.tinyspeck.slackmacgap": .clipboard,
        "com.apple.mail": .clipboard,
        "com.google.Chrome": .keystroke,
        "com.apple.Safari": .keystroke,
        "com.notion.id": .clipboard,
        "com.microsoft.Word": .clipboard
    ]
    
    // MARK: - Initialization
    init(config: TextInsertionConfig = .default) {
        self.defaultConfig = config
        super.init()
        
        LogManager.shared.info(.textInsertion, "TextInsertion初始化", metadata: [
            "defaultMode": "\(config.mode)",
            "preserveClipboard": config.preserveClipboard,
            "supportedAppsCount": supportedApps.count
        ])
        
        // 请求辅助功能权限
        requestAccessibilityPermission()
        
        // 设置应用特定配置
        setupAppSpecificConfigs()
    }
    
    // MARK: - Public Methods
    
    /// 插入文本到当前活跃应用
    func insertText(_ text: String, config: TextInsertionConfig? = nil) async {
        let effectiveConfig = config ?? defaultConfig
        
        LogManager.shared.info(.textInsertion, "开始文本插入", metadata: [
            "textLength": text.count,
            "mode": "\(effectiveConfig.mode)",
            "preserveClipboard": effectiveConfig.preserveClipboard
        ])
        
        let startTime = Date()
        
        do {
            // 获取当前活跃应用信息
            let currentApp = try getCurrentApp()
            
            LogManager.shared.info(.textInsertion, "目标应用识别", metadata: [
                "bundleId": currentApp.bundleId,
                "name": currentApp.name,
                "pid": currentApp.pid,
                "supportsAccessibility": currentApp.supportsAccessibility
            ])
            
            // 通知代理即将插入
            delegate?.textInsertion(self, willInsertText: text, to: currentApp)
            
            // 预处理文本
            let processedText = preprocessText(text, config: effectiveConfig)
            
            // 根据应用选择最佳插入模式
            let optimalMode = determineOptimalMode(for: currentApp, preferredMode: effectiveConfig.mode)
            let finalConfig = TextInsertionConfig(
                mode: optimalMode,
                preserveClipboard: effectiveConfig.preserveClipboard,
                replaceSelection: effectiveConfig.replaceSelection,
                addLineBreaks: effectiveConfig.addLineBreaks,
                trimWhitespace: effectiveConfig.trimWhitespace,
                timeout: effectiveConfig.timeout
            )
            
            // 执行插入
            try await performInsertion(processedText, to: currentApp, config: finalConfig)
            
            let duration = Date().timeIntervalSince(startTime)
            
            // 创建成功结果
            let result = InsertionResult(
                success: true,
                targetApp: currentApp,
                insertedText: processedText,
                mode: optimalMode,
                duration: duration,
                error: nil
            )
            
            LogManager.shared.info(.textInsertion, "文本插入成功", metadata: [
                "duration": String(format: "%.3fs", duration),
                "mode": "\(optimalMode)",
                "textLength": processedText.count,
                "targetApp": currentApp.name
            ])
            
            delegate?.textInsertion(self, didCompleteInsertion: result)
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            
            LogManager.shared.trackError(error, context: "文本插入", recoveryAction: "检查辅助功能权限或目标应用状态")
            
            // 创建失败结果
            let result = InsertionResult(
                success: false,
                targetApp: AppInfo(bundleId: "", name: "Unknown", pid: 0, isActive: false, supportsAccessibility: false, insertionMode: .clipboard),
                insertedText: text,
                mode: effectiveConfig.mode,
                duration: duration,
                error: error
            )
            
            delegate?.textInsertion(self, didCompleteInsertion: result)
            delegate?.textInsertion(self, didFailWithError: error)
        }
    }
    
    /// 获取支持的应用列表
    func getSupportedApps() -> [String: TextInsertionMode] {
        return supportedApps
    }
    
    /// 设置应用特定配置
    func setAppConfig(_ bundleId: String, config: TextInsertionConfig) {
        appSpecificConfigs[bundleId] = config
        
        LogManager.shared.info(.textInsertion, "设置应用特定配置", metadata: [
            "bundleId": bundleId,
            "mode": "\(config.mode)"
        ])
    }
    
    /// 获取应用特定配置
    func getAppConfig(_ bundleId: String) -> TextInsertionConfig {
        return appSpecificConfigs[bundleId] ?? defaultConfig
    }
    
    /// 检查辅助功能权限
    nonisolated func checkAccessibilityPermission() -> Bool {
        let enabled = AXIsProcessTrusted()
        
        Task { @MainActor in
            LogManager.shared.debug(.textInsertion, "辅助功能权限检查", metadata: [
                "enabled": enabled
            ])
        }
        
        return enabled
    }
    
    // MARK: - Private Methods
    
    /// 请求辅助功能权限
    nonisolated private func requestAccessibilityPermission() {
        if !checkAccessibilityPermission() {
            // 使用字符串常量避开并发安全问题
            let options: NSDictionary = ["AXTrustedCheckOptionPrompt": true]
            let enabled = AXIsProcessTrustedWithOptions(options)
            
            Task { @MainActor in
                LogManager.shared.info(.textInsertion, "请求辅助功能权限", metadata: [
                    "enabled": enabled
                ])
            }
        }
    }
    
    /// 设置应用特定配置
    private func setupAppSpecificConfigs() {
        // Xcode - 使用辅助功能API
        appSpecificConfigs["com.apple.dt.Xcode"] = TextInsertionConfig(
            mode: .accessibility,
            preserveClipboard: true,
            replaceSelection: true,
            addLineBreaks: false,
            trimWhitespace: true,
            timeout: 3.0
        )
        
        // 浏览器 - 使用键盘模拟
        let browserConfig = TextInsertionConfig(
            mode: .keystroke,
            preserveClipboard: true,
            replaceSelection: true,
            addLineBreaks: false,
            trimWhitespace: true,
            timeout: 5.0
        )
        
        appSpecificConfigs["com.google.Chrome"] = browserConfig
        appSpecificConfigs["com.apple.Safari"] = browserConfig
        appSpecificConfigs["com.mozilla.firefox"] = browserConfig
        
        LogManager.shared.info(.textInsertion, "应用特定配置设置完成", metadata: [
            "configCount": appSpecificConfigs.count
        ])
    }
    
    /// 获取当前活跃应用
    private func getCurrentApp() throws -> AppInfo {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            throw TextInsertionError.noActiveApplication
        }
        
        let bundleId = frontmostApp.bundleIdentifier ?? ""
        let name = frontmostApp.localizedName ?? "Unknown"
        let pid = frontmostApp.processIdentifier
        let supportsAccessibility = checkAccessibilityPermission()
        let insertionMode = supportedApps[bundleId] ?? defaultConfig.mode
        
        return AppInfo(
            bundleId: bundleId,
            name: name,
            pid: pid,
            isActive: true,
            supportsAccessibility: supportsAccessibility,
            insertionMode: insertionMode
        )
    }
    
    /// 预处理文本
    private func preprocessText(_ text: String, config: TextInsertionConfig) -> String {
        var processedText = text
        
        // 清理首尾空白
        if config.trimWhitespace {
            processedText = processedText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 添加换行符
        if config.addLineBreaks {
            processedText = "\n\(processedText)\n"
        }
        
        LogManager.shared.debug(.textInsertion, "文本预处理", metadata: [
            "originalLength": text.count,
            "processedLength": processedText.count,
            "trimmed": config.trimWhitespace,
            "addedLineBreaks": config.addLineBreaks
        ])
        
        return processedText
    }
    
    /// 确定最佳插入模式
    private func determineOptimalMode(for app: AppInfo, preferredMode: TextInsertionMode) -> TextInsertionMode {
        // 检查应用特定的优化模式
        if let appMode = supportedApps[app.bundleId] {
            LogManager.shared.debug(.textInsertion, "使用应用优化模式", metadata: [
                "bundleId": app.bundleId,
                "mode": "\(appMode)"
            ])
            return appMode
        }
        
        // 检查辅助功能权限
        if preferredMode == .accessibility && !app.supportsAccessibility {
            LogManager.shared.warning(.textInsertion, "辅助功能不可用，降级到剪贴板模式")
            return .clipboard
        }
        
        return preferredMode
    }
    
    /// 执行插入操作
    private func performInsertion(_ text: String, to app: AppInfo, config: TextInsertionConfig) async throws {
        switch config.mode {
        case .clipboard:
            try await insertViaClipboard(text, config: config)
        case .accessibility:
            try await insertViaAccessibility(text, to: app, config: config)
        case .keystroke:
            try await insertViaKeystroke(text, config: config)
        case .direct:
            try await insertViaDirect(text, to: app, config: config)
        }
    }
    
    /// 通过剪贴板插入
    private func insertViaClipboard(_ text: String, config: TextInsertionConfig) async throws {
        let pasteboard = NSPasteboard.general
        
        // 保存原始剪贴板内容
        if config.preserveClipboard {
            originalClipboardContent = pasteboard.string(forType: .string)
        }
        
        // 设置新内容到剪贴板
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // 等待剪贴板更新
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // 模拟 Cmd+V 粘贴
        let source = CGEventSource(stateID: .hidSystemState)
        
        let keyDownV = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true) // V key
        let keyUpV = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        
        keyDownV?.flags = .maskCommand
        keyUpV?.flags = .maskCommand
        
        keyDownV?.post(tap: .cghidEventTap)
        keyUpV?.post(tap: .cghidEventTap)
        
        // 等待粘贴完成
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // 恢复原始剪贴板内容
        if config.preserveClipboard, let original = originalClipboardContent {
            pasteboard.clearContents()
            pasteboard.setString(original, forType: .string)
        }
        
        LogManager.shared.debug(.textInsertion, "剪贴板插入完成", metadata: [
            "textLength": text.count,
            "preserved": config.preserveClipboard
        ])
    }
    
    /// 通过辅助功能API插入
    private func insertViaAccessibility(_ text: String, to app: AppInfo, config: TextInsertionConfig) async throws {
        guard checkAccessibilityPermission() else {
            throw TextInsertionError.accessibilityPermissionDenied
        }
        
        let appRef = AXUIElementCreateApplication(app.pid)
        
        // 获取焦点元素
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appRef, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        guard result == AXError.success, let element = focusedElement else {
            throw TextInsertionError.noFocusedElement
        }
        
        let focusedUIElement = element as! AXUIElement // Force cast since we know this is correct
        
        // 如果需要替换选中内容，先获取当前选中文本
        if config.replaceSelection {
            var selectedText: CFTypeRef?
            AXUIElementCopyAttributeValue(focusedUIElement, kAXSelectedTextAttribute as CFString, &selectedText)
        }
        
        // 插入文本
        let insertResult = AXUIElementSetAttributeValue(focusedUIElement, kAXSelectedTextAttribute as CFString, text as CFString)
        
        if insertResult != AXError.success {
            throw TextInsertionError.accessibilityInsertionFailed(insertResult)
        }
        
        LogManager.shared.debug(.textInsertion, "辅助功能插入完成", metadata: [
            "textLength": text.count,
            "result": "\(insertResult)"
        ])
    }
    
    /// 通过键盘模拟插入
    private func insertViaKeystroke(_ text: String, config: TextInsertionConfig) async throws {
        let source = CGEventSource(stateID: .hidSystemState)
        
        // 如果需要替换选中内容，先全选
        if config.replaceSelection {
            // Cmd+A 全选
            let keyDownA = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) // A key
            let keyUpA = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            
            keyDownA?.flags = .maskCommand
            keyUpA?.flags = .maskCommand
            
            keyDownA?.post(tap: .cghidEventTap)
            keyUpA?.post(tap: .cghidEventTap)
            
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
        
        // 逐字符输入
        for char in text {
            guard let unicodeScalar = char.unicodeScalars.first else { continue }
            let keyCode = UInt16(unicodeScalar.value)
            
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
            
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
            
            // 短暂延迟以确保字符正确输入
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        LogManager.shared.debug(.textInsertion, "键盘模拟插入完成", metadata: [
            "textLength": text.count,
            "characterCount": text.count
        ])
    }
    
    /// 通过直接API插入（特定应用）
    private func insertViaDirect(_ text: String, to app: AppInfo, config: TextInsertionConfig) async throws {
        // 目前暂不支持直接API插入，降级到剪贴板模式
        LogManager.shared.warning(.textInsertion, "直接API插入暂不支持，降级到剪贴板模式")
        try await insertViaClipboard(text, config: config)
    }
}

// MARK: - 文本插入错误类型
enum TextInsertionError: LocalizedError {
    case noActiveApplication
    case accessibilityPermissionDenied
    case noFocusedElement
    case accessibilityInsertionFailed(AXError)
    case clipboardOperationFailed
    case insertionTimeout
    case unsupportedApplication(String)
    
    var errorDescription: String? {
        switch self {
        case .noActiveApplication:
            return "没有活跃的应用程序"
        case .accessibilityPermissionDenied:
            return "辅助功能权限被拒绝"
        case .noFocusedElement:
            return "没有找到焦点输入元素"
        case .accessibilityInsertionFailed(let error):
            return "辅助功能插入失败: \(error)"
        case .clipboardOperationFailed:
            return "剪贴板操作失败"
        case .insertionTimeout:
            return "文本插入超时"
        case .unsupportedApplication(let bundleId):
            return "不支持的应用程序: \(bundleId)"
        }
    }
}

// MARK: - 扩展功能
extension TextInsertion {
    
    /// 获取当前光标位置的上下文文本
    func getCurrentContext() async -> String? {
        guard checkAccessibilityPermission() else { return nil }
        
        do {
            let app = try getCurrentApp()
            let appRef = AXUIElementCreateApplication(app.pid)
            
            var focusedElement: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appRef, kAXFocusedUIElementAttribute as CFString, &focusedElement)
            
            guard result == AXError.success, let element = focusedElement else { return nil }
            
            let focusedUIElement = element as! AXUIElement // Force cast since we know this is correct
            
            // 尝试获取当前文本内容
            var value: CFTypeRef?
            let valueResult = AXUIElementCopyAttributeValue(focusedUIElement, kAXValueAttribute as CFString, &value)
            
            if valueResult == AXError.success, let textValue = value as? String {
                return textValue
            }
            
        } catch {
            LogManager.shared.debug(.textInsertion, "获取上下文失败", metadata: [
                "error": error.localizedDescription
            ])
        }
        
        return nil
    }
    
    /// 检查目标应用是否支持特定插入模式
    func supportsMode(_ mode: TextInsertionMode, for bundleId: String) -> Bool {
        switch mode {
        case .clipboard:
            return true // 所有应用都支持剪贴板
        case .accessibility:
            return checkAccessibilityPermission()
        case .keystroke:
            return true // 大多数应用支持键盘输入
        case .direct:
            return supportedApps[bundleId] == .direct
        }
    }
    
    /// 获取推荐的插入模式
    func getRecommendedMode(for bundleId: String) -> TextInsertionMode {
        return supportedApps[bundleId] ?? .clipboard
    }
}