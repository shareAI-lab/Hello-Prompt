//
//  ContextDetector.swift
//  HelloPrompt
//
//  上下文检测器 - 检测当前活跃应用、光标位置并实现智能文本插入
//  支持主流macOS应用和通用文本插入策略
//

import Foundation
import AppKit
import ApplicationServices
import Combine

// MARK: - 应用信息结构
public struct ApplicationInfo {
    let bundleIdentifier: String
    let localizedName: String
    let processIdentifier: pid_t
    let isActive: Bool
    let windowTitle: String?
    let applicationCategory: ApplicationCategory
    
    var supportLevel: TextInsertionSupport {
        ApplicationRegistry.shared.getSupportLevel(for: bundleIdentifier)
    }
}

// MARK: - 应用分类
public enum ApplicationCategory: String, CaseIterable {
    case codeEditor = "代码编辑器"
    case textEditor = "文本编辑器"
    case browser = "浏览器"
    case terminal = "终端"
    case office = "办公软件"
    case chat = "聊天软件"
    case unknown = "未知"
    
    var insertionStrategy: TextInsertionStrategy {
        switch self {
        case .codeEditor:
            return .accessibility
        case .textEditor:
            return .accessibility
        case .browser:
            return .clipboard
        case .terminal:
            return .clipboard
        case .office:
            return .accessibility
        case .chat:
            return .clipboard
        case .unknown:
            return .universal
        }
    }
}

// MARK: - 文本插入支持级别
public enum TextInsertionSupport: String, CaseIterable {
    case full = "完全支持"        // 支持光标定位和直接插入
    case partial = "部分支持"     // 支持剪贴板插入
    case limited = "有限支持"     // 仅支持基本插入
    case unsupported = "不支持"   // 不支持文本插入
}

// MARK: - 文本插入策略
public enum TextInsertionStrategy: String, CaseIterable {
    case accessibility = "辅助功能"  // 使用Accessibility API
    case clipboard = "剪贴板"        // 使用剪贴板 + 粘贴快捷键
    case applescript = "AppleScript" // 使用AppleScript自动化
    case universal = "通用策略"      // 多种策略组合
}

// MARK: - 应用注册表
private class ApplicationRegistry {
    static let shared = ApplicationRegistry()
    
    private let supportedApplications: [String: (ApplicationCategory, TextInsertionSupport)] = [
        // 代码编辑器
        "com.microsoft.VSCode": (.codeEditor, .full),
        "com.apple.dt.Xcode": (.codeEditor, .full),
        "com.sublimetext.4": (.textEditor, .full),
        "com.jetbrains.intellij": (.codeEditor, .full),
        "com.github.atom": (.codeEditor, .partial),
        "com.vim.MacVim": (.textEditor, .full),
        
        // 文本编辑器
        "com.apple.TextEdit": (.textEditor, .full),
        "com.coteditor.CotEditor": (.textEditor, .full),
        "com.typora.typora": (.textEditor, .full),
        "md.obsidian": (.textEditor, .full),
        
        // 浏览器
        "com.google.Chrome": (.browser, .partial),
        "com.apple.Safari": (.browser, .partial),
        "org.mozilla.firefox": (.browser, .partial),
        "com.microsoft.edgemac": (.browser, .partial),
        
        // 终端
        "com.apple.Terminal": (.terminal, .partial),
        "com.googlecode.iterm2": (.terminal, .partial),
        "com.github.wez.wezterm": (.terminal, .partial),
        
        // 办公软件
        "com.microsoft.Word": (.office, .full),
        "com.apple.Pages": (.office, .full),
        "com.microsoft.Powerpoint": (.office, .full),
        "com.apple.Keynote": (.office, .full),
        
        // 聊天软件
        "com.tencent.xinWeChat": (.chat, .partial),
        "com.microsoft.teams": (.chat, .partial),
        "com.slack.Slack": (.chat, .partial),
        "us.zoom.xos": (.chat, .partial)
    ]
    
    func getSupportLevel(for bundleID: String) -> TextInsertionSupport {
        return supportedApplications[bundleID]?.1 ?? .limited
    }
    
    func getCategory(for bundleID: String) -> ApplicationCategory {
        return supportedApplications[bundleID]?.0 ?? .unknown
    }
}

// MARK: - 光标位置信息
public struct CursorPosition {
    let x: CGFloat
    let y: CGFloat
    let isValid: Bool
    let textFieldInfo: TextFieldInfo?
}

public struct TextFieldInfo {
    let frame: CGRect
    let value: String
    let selectedRange: NSRange
    let isEditable: Bool
}

// MARK: - 文本插入结果
public struct TextInsertionResult {
    let success: Bool
    let strategy: TextInsertionStrategy
    let insertedText: String
    let targetApplication: String
    let duration: TimeInterval
    let error: Error?
}

// MARK: - 主上下文检测器类
@MainActor
public final class ContextDetector: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var currentApplication: ApplicationInfo?
    @Published public var cursorPosition: CursorPosition?
    @Published public var isMonitoring = false
    @Published public var hasAccessibilityPermission = false
    
    // MARK: - Private Properties
    private var applicationObserver: NSObjectProtocol?
    private var cursorUpdateTimer: Timer?
    private let workspace = NSWorkspace.shared
    
    // 权限和状态
    private var accessibilityPermissionGranted = false
    private var lastActiveApplication: NSRunningApplication?
    
    // MARK: - 初始化
    public init() {
        checkAccessibilityPermission()
        setupApplicationObserver()
        
        LogManager.shared.info("ContextDetector", "上下文检测器初始化完成")
    }
    
    deinit {
        // Note: Can't call MainActor-isolated methods from deinit
        // Monitoring will be cleaned up by the system
    }
    
    // MARK: - 权限管理
    private func checkAccessibilityPermission() {
        accessibilityPermissionGranted = AXIsProcessTrusted()
        hasAccessibilityPermission = accessibilityPermissionGranted
        
        if !accessibilityPermissionGranted {
            LogManager.shared.warning("ContextDetector", "缺少辅助功能权限")
        } else {
            LogManager.shared.info("ContextDetector", "辅助功能权限已授权")
        }
    }
    
    public func requestAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        accessibilityPermissionGranted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        hasAccessibilityPermission = accessibilityPermissionGranted
        
        if accessibilityPermissionGranted {
            LogManager.shared.info("ContextDetector", "辅助功能权限获取成功")
        }
        
        return accessibilityPermissionGranted
    }
    
    // MARK: - 监控控制
    public func startMonitoring() {
        guard !isMonitoring else { return }
        
        if !accessibilityPermissionGranted {
            _ = requestAccessibilityPermission()
        }
        
        isMonitoring = true
        updateCurrentApplication()
        startCursorTracking()
        
        LogManager.shared.info("ContextDetector", "开始监控应用上下文")
    }
    
    public func stopMonitoring() {
        isMonitoring = false
        stopCursorTracking()
        
        LogManager.shared.info("ContextDetector", "停止监控应用上下文")
    }
    
    // MARK: - 应用监控
    private func setupApplicationObserver() {
        applicationObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleApplicationActivation(notification)
            }
        }
    }
    
    private func handleApplicationActivation(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        lastActiveApplication = app
        updateCurrentApplication()
        
        LogManager.shared.debug("ContextDetector", """
            应用切换: \(app.localizedName ?? "未知应用")
            Bundle ID: \(app.bundleIdentifier ?? "unknown")
            """)
    }
    
    private func updateCurrentApplication() {
        guard let app = workspace.frontmostApplication else {
            currentApplication = nil
            return
        }
        
        let bundleID = app.bundleIdentifier ?? "unknown"
        let category = ApplicationRegistry.shared.getCategory(for: bundleID)
        
        // 获取窗口标题
        let windowTitle = getActiveWindowTitle(for: app)
        
        currentApplication = ApplicationInfo(
            bundleIdentifier: bundleID,
            localizedName: app.localizedName ?? "未知应用",
            processIdentifier: app.processIdentifier,
            isActive: true,
            windowTitle: windowTitle,
            applicationCategory: category
        )
        
        LogManager.shared.debug("ContextDetector", """
            当前应用更新:
            应用: \(currentApplication?.localizedName ?? "nil")
            类别: \(category.rawValue)
            支持级别: \(currentApplication?.supportLevel.rawValue ?? "nil")
            """)
    }
    
    private func getActiveWindowTitle(for app: NSRunningApplication) -> String? {
        guard accessibilityPermissionGranted else { return nil }
        
        let appRef = AXUIElementCreateApplication(app.processIdentifier)
        var windowRef: CFTypeRef?
        
        let result = AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &windowRef)
        
        if result == .success, let window = windowRef {
            var titleRef: CFTypeRef?
            let titleResult = AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &titleRef)
            
            if titleResult == .success, let title = titleRef as? String {
                return title
            }
        }
        
        return nil
    }
    
    // MARK: - 光标跟踪
    private func startCursorTracking() {
        guard accessibilityPermissionGranted else { return }
        
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCursorPosition()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        cursorUpdateTimer = timer
    }
    
    private func stopCursorTracking() {
        cursorUpdateTimer?.invalidate()
        cursorUpdateTimer = nil
    }
    
    private func updateCursorPosition() {
        guard let app = workspace.frontmostApplication else {
            cursorPosition = nil
            return
        }
        
        let position = getCurrentCursorPosition(for: app)
        cursorPosition = position
    }
    
    private func getCurrentCursorPosition(for app: NSRunningApplication) -> CursorPosition? {
        guard accessibilityPermissionGranted else {
            return CursorPosition(x: 0, y: 0, isValid: false, textFieldInfo: nil)
        }
        
        let appRef = AXUIElementCreateApplication(app.processIdentifier)
        var focusedElement: CFTypeRef?
        
        let result = AXUIElementCopyAttributeValue(appRef, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        guard result == .success, let element = focusedElement else {
            return CursorPosition(x: 0, y: 0, isValid: false, textFieldInfo: nil)
        }
        
        // 获取文本框信息
        let textFieldInfo = getTextFieldInfo(from: element as! AXUIElement)
        
        // 获取光标位置
        var positionRef: CFTypeRef?
        let positionResult = AXUIElementCopyAttributeValue(element as! AXUIElement, kAXPositionAttribute as CFString, &positionRef)
        
        if positionResult == .success, let positionValue = positionRef {
            var point = CGPoint.zero
            if AXValueGetValue(positionValue as! AXValue, .cgPoint, &point) {
                return CursorPosition(
                    x: point.x,
                    y: point.y,
                    isValid: true,
                    textFieldInfo: textFieldInfo
                )
            }
        }
        
        return CursorPosition(x: 0, y: 0, isValid: false, textFieldInfo: textFieldInfo)
    }
    
    private func getTextFieldInfo(from element: AXUIElement) -> TextFieldInfo? {
        // 获取文本框框架
        var frameRef: CFTypeRef?
        let frameResult = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &frameRef)
        
        var frame = CGRect.zero
        if frameResult == .success, let frameValue = frameRef {
            AXValueGetValue(frameValue as! AXValue, .cgRect, &frame)
        }
        
        // 获取文本内容
        var valueRef: CFTypeRef?
        let valueResult = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef)
        
        let value = (valueResult == .success) ? (valueRef as? String ?? "") : ""
        
        // 获取选中范围
        var rangeRef: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef)
        
        var selectedRange = NSRange(location: 0, length: 0)
        if rangeResult == .success, let rangeValue = rangeRef {
            var cfRange = CFRange()
            if AXValueGetValue(rangeValue as! AXValue, .cfRange, &cfRange) {
                selectedRange = NSRange(location: cfRange.location, length: cfRange.length)
            }
        }
        
        // 检查是否可编辑
        var editableRef: CFTypeRef?
        let editableResult = AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &editableRef)
        let isEditable = (editableResult == .success) ? (editableRef as? Bool ?? false) : false
        
        return TextFieldInfo(
            frame: frame,
            value: value,
            selectedRange: selectedRange,
            isEditable: isEditable
        )
    }
    
    // MARK: - 文本插入
    public func insertText(_ text: String) async -> TextInsertionResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        guard let appInfo = currentApplication else {
            return TextInsertionResult(
                success: false,
                strategy: .universal,
                insertedText: text,
                targetApplication: "unknown",
                duration: 0,
                error: UIError.windowCreationFailed
            )
        }
        
        let strategy = appInfo.applicationCategory.insertionStrategy
        
        LogManager.shared.info("ContextDetector", """
            开始文本插入:
            目标应用: \(appInfo.localizedName)
            策略: \(strategy.rawValue)
            文本长度: \(text.count)
            """)
        
        do {
            let success = try await performTextInsertion(text, using: strategy, for: appInfo)
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            let result = TextInsertionResult(
                success: success,
                strategy: strategy,
                insertedText: text,
                targetApplication: appInfo.localizedName,
                duration: duration,
                error: nil
            )
            
            LogManager.shared.info("ContextDetector", """
                文本插入完成:
                成功: \(success)
                耗时: \(String(format: "%.3f", duration))s
                """)
            
            return result
            
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            LogManager.shared.error("ContextDetector", "文本插入失败: \(error)")
            
            return TextInsertionResult(
                success: false,
                strategy: strategy,
                insertedText: text,
                targetApplication: appInfo.localizedName,
                duration: duration,
                error: error
            )
        }
    }
    
    private func performTextInsertion(_ text: String, using strategy: TextInsertionStrategy, for appInfo: ApplicationInfo) async throws -> Bool {
        switch strategy {
        case .accessibility:
            return try await insertUsingAccessibility(text, for: appInfo)
        case .clipboard:
            return try await insertUsingClipboard(text, for: appInfo)
        case .applescript:
            return try await insertUsingAppleScript(text, for: appInfo)
        case .universal:
            return try await insertUsingUniversalStrategy(text, for: appInfo)
        }
    }
    
    // MARK: - 插入策略实现
    
    /// 使用Accessibility API插入文本
    private func insertUsingAccessibility(_ text: String, for appInfo: ApplicationInfo) async throws -> Bool {
        guard accessibilityPermissionGranted else {
            throw UIError.accessibilityPermissionDenied
        }
        
        guard let app = NSRunningApplication(processIdentifier: appInfo.processIdentifier) else {
            throw UIError.windowCreationFailed
        }
        
        let appRef = AXUIElementCreateApplication(app.processIdentifier)
        var focusedElement: CFTypeRef?
        
        let result = AXUIElementCopyAttributeValue(appRef, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        guard result == .success, let element = focusedElement else {
            throw UIError.overlayDisplayFailed
        }
        
        // 获取当前文本和选中范围
        var currentValueRef: CFTypeRef?
        let valueResult = AXUIElementCopyAttributeValue(element as! AXUIElement, kAXValueAttribute as CFString, &currentValueRef)
        
        let currentValue = (valueResult == .success) ? (currentValueRef as? String ?? "") : ""
        
        var rangeRef: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextRangeAttribute as CFString, &rangeRef)
        
        var insertionPoint = currentValue.count
        if rangeResult == .success, let rangeValue = rangeRef {
            var cfRange = CFRange()
            if AXValueGetValue(rangeValue as! AXValue, .cfRange, &cfRange) {
                insertionPoint = cfRange.location
            }
        }
        
        // 构建新文本
        let newValue = String(currentValue.prefix(insertionPoint)) + text + String(currentValue.dropFirst(insertionPoint))
        
        // 设置新文本
        let setResult = AXUIElementSetAttributeValue(element as! AXUIElement, kAXValueAttribute as CFString, newValue as CFString)
        
        if setResult == .success {
            // 设置光标位置到插入文本后
            let newCursorPosition = insertionPoint + text.count
            var newRange = CFRange(location: newCursorPosition, length: 0)
            
            let rangeValue = AXValueCreate(.cfRange, &newRange)
            AXUIElementSetAttributeValue(element as! AXUIElement, kAXSelectedTextRangeAttribute as CFString, rangeValue!)
            
            return true
        }
        
        return false
    }
    
    /// 使用剪贴板插入文本
    private func insertUsingClipboard(_ text: String, for appInfo: ApplicationInfo) async throws -> Bool {
        // 保存当前剪贴板内容
        let pasteboard = NSPasteboard.general
        let originalContent = pasteboard.string(forType: .string)
        
        defer {
            // 恢复原始剪贴板内容
            if let original = originalContent {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    pasteboard.clearContents()
                    pasteboard.setString(original, forType: .string)
                }
            }
        }
        
        // 将文本复制到剪贴板
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // 等待剪贴板更新
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // 发送粘贴快捷键
        let success = sendPasteShortcut()
        
        return success
    }
    
    /// 使用AppleScript插入文本
    private func insertUsingAppleScript(_ text: String, for appInfo: ApplicationInfo) async throws -> Bool {
        let escapedText = text.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "\(appInfo.localizedName)"
            activate
            delay 0.1
            tell application "System Events"
                keystroke "\(escapedText)"
            end tell
        end tell
        """
        
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        let result = appleScript?.executeAndReturnError(&error)
        
        if let error = error {
            LogManager.shared.error("ContextDetector", "AppleScript执行失败: \(error)")
            return false
        }
        
        return result != nil
    }
    
    /// 通用插入策略 (多种方法组合)
    private func insertUsingUniversalStrategy(_ text: String, for appInfo: ApplicationInfo) async throws -> Bool {
        // 首先尝试Accessibility API
        if accessibilityPermissionGranted {
            do {
                if try await insertUsingAccessibility(text, for: appInfo) {
                    return true
                }
            } catch {
                LogManager.shared.debug("ContextDetector", "Accessibility方式失败，尝试剪贴板方式")
            }
        }
        
        // 然后尝试剪贴板方式
        do {
            if try await insertUsingClipboard(text, for: appInfo) {
                return true
            }
        } catch {
            LogManager.shared.debug("ContextDetector", "剪贴板方式失败，尝试AppleScript方式")
        }
        
        // 最后尝试AppleScript
        return try await insertUsingAppleScript(text, for: appInfo)
    }
    
    // MARK: - 辅助方法
    private func sendPasteShortcut() -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        
        // 创建Cmd+V按键事件
        guard let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true),  // Cmd键
              let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),     // V键
              let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false),
              let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false) else {
            return false
        }
        
        // 设置修饰键
        vDown.flags = .maskCommand
        vUp.flags = .maskCommand
        
        // 发送事件序列
        cmdDown.post(tap: .cghidEventTap)
        vDown.post(tap: .cghidEventTap)
        vUp.post(tap: .cghidEventTap)
        cmdUp.post(tap: .cghidEventTap)
        
        return true
    }
    
    // MARK: - 应用上下文分析
    public func getApplicationContext() -> String {
        guard let appInfo = currentApplication else {
            return "未知应用环境"
        }
        
        var context = "当前应用: \(appInfo.localizedName)"
        
        if let windowTitle = appInfo.windowTitle, !windowTitle.isEmpty {
            context += "\n窗口标题: \(windowTitle)"
        }
        
        context += "\n应用类别: \(appInfo.applicationCategory.rawValue)"
        context += "\n支持级别: \(appInfo.supportLevel.rawValue)"
        
        // 根据应用类别添加特定上下文
        switch appInfo.applicationCategory {
        case .codeEditor:
            context += "\n适合代码生成和技术文档编写"
        case .textEditor:
            context += "\n适合文本编辑和内容创作"
        case .browser:
            context += "\n适合网页内容和表单填写"
        case .terminal:
            context += "\n适合命令行操作和脚本编写"
        case .office:
            context += "\n适合办公文档和商务内容"
        case .chat:
            context += "\n适合即时通讯和社交内容"
        case .unknown:
            context += "\n通用文本插入环境"
        }
        
        return context
    }
    
    public func getInsertionCapabilities() -> [String: Any] {
        guard let appInfo = currentApplication else {
            return ["status": "no_active_app"]
        }
        
        return [
            "application": appInfo.localizedName,
            "bundleId": appInfo.bundleIdentifier,
            "category": appInfo.applicationCategory.rawValue,
            "supportLevel": appInfo.supportLevel.rawValue,
            "strategy": appInfo.applicationCategory.insertionStrategy.rawValue,
            "hasAccessibility": accessibilityPermissionGranted,
            "hasCursorInfo": cursorPosition?.isValid ?? false,
            "isTextFieldFocused": cursorPosition?.textFieldInfo?.isEditable ?? false
        ]
    }
    
    // MARK: - 测试方法
    public func testTextInsertion() async -> Bool {
        let testText = "Hello, this is a test from HelloPrompt!"
        let result = await insertText(testText)
        
        LogManager.shared.info("ContextDetector", """
            文本插入测试完成:
            成功: \(result.success)
            策略: \(result.strategy.rawValue)
            目标应用: \(result.targetApplication)
            耗时: \(String(format: "%.3f", result.duration))s
            """)
        
        return result.success
    }
}

// MARK: - ContextDetector扩展 - 便捷方法
extension ContextDetector {
    
    /// 检查是否可以插入文本
    public var canInsertText: Bool {
        guard let appInfo = currentApplication else { return false }
        return appInfo.supportLevel != .unsupported
    }
    
    /// 获取推荐的插入策略
    public var recommendedStrategy: TextInsertionStrategy? {
        return currentApplication?.applicationCategory.insertionStrategy
    }
    
    /// 是否有文本框焦点
    public var hasTextFieldFocus: Bool {
        return cursorPosition?.textFieldInfo?.isEditable ?? false
    }
}