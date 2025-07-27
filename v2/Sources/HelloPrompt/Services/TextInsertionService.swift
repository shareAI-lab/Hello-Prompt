//
//  TextInsertionService.swift
//  HelloPrompt
//
//  文本插入服务 - 统一的文本插入接口
//  整合ContextDetector功能，提供简洁的API
//

import Foundation
import AppKit
import ApplicationServices

// MARK: - 插入模式枚举
public enum TextInsertionMode: String, CaseIterable {
    case replace = "替换"      // 替换当前选中的文本
    case append = "追加"       // 在当前光标位置追加文本
    case prepend = "前置"      // 在当前光标位置前插入文本
    
    var description: String {
        switch self {
        case .replace:
            return "替换当前选中的文本"
        case .append:
            return "在光标位置后追加文本"
        case .prepend:
            return "在光标位置前插入文本"
        }
    }
}

// MARK: - 插入配置
public struct TextInsertionConfig {
    let mode: TextInsertionMode
    let preserveClipboard: Bool
    let autoRestoreFocus: Bool
    let insertDelay: TimeInterval
    
    public init(
        mode: TextInsertionMode = .append,
        preserveClipboard: Bool = true,
        autoRestoreFocus: Bool = true,
        insertDelay: TimeInterval = 0.1
    ) {
        self.mode = mode
        self.preserveClipboard = preserveClipboard
        self.autoRestoreFocus = autoRestoreFocus
        self.insertDelay = insertDelay
    }
    
    public static let `default` = TextInsertionConfig()
}

// MARK: - 主文本插入服务类
@MainActor
public final class TextInsertionService: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var isInserting = false
    @Published public var lastInsertionResult: TextInsertionResult?
    @Published public var supportedApplications: [String] = []
    
    // MARK: - Private Properties
    private let contextDetector: ContextDetector
    private let logManager = LogManager.shared
    
    // MARK: - 初始化
    public init() {
        self.contextDetector = ContextDetector()
        
        // 启动上下文监控
        contextDetector.startMonitoring()
        
        // 加载支持的应用列表
        loadSupportedApplications()
        
        logManager.info("TextInsertionService", "文本插入服务初始化完成")
    }
    
    deinit {
        // Note: Can't call MainActor-isolated methods from deinit
        // Monitoring will be cleaned up by the system
    }
    
    /// 清理资源
    public func cleanup() {
        contextDetector.stopMonitoring()
        logManager.info("TextInsertionService", "文本插入服务已清理")
    }
    
    // MARK: - 公共API
    
    /// 插入文本到活跃应用
    public func insertText(_ text: String, config: TextInsertionConfig = .default) async -> TextInsertionResult {
        guard !text.isEmpty else {
            let error = NSError(domain: "TextInsertionService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "文本内容为空"
            ])
            return TextInsertionResult(
                success: false,
                strategy: .universal,
                insertedText: text,
                targetApplication: "unknown",
                duration: 0,
                error: error
            )
        }
        
        isInserting = true
        defer { isInserting = false }
        
        logManager.info("TextInsertionService", """
            开始文本插入:
            文本长度: \(text.count)
            插入模式: \(config.mode.rawValue)
            目标应用: \(contextDetector.currentApplication?.localizedName ?? "未知")
            """)
        
        // 检查权限
        if !contextDetector.hasAccessibilityPermission {
            let permissionGranted = contextDetector.requestAccessibilityPermission()
            if !permissionGranted {
                let error = NSError(domain: "TextInsertionService", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "缺少辅助功能权限"
                ])
                return TextInsertionResult(
                    success: false,
                    strategy: .universal,
                    insertedText: text,
                    targetApplication: contextDetector.currentApplication?.localizedName ?? "unknown",
                    duration: 0,
                    error: error
                )
            }
        }
        
        // 根据插入模式处理文本
        let processedText = preprocessText(text, mode: config.mode)
        
        // 执行插入
        let result = await contextDetector.insertText(processedText)
        lastInsertionResult = result
        
        // 记录结果
        logManager.info("TextInsertionService", """
            文本插入完成:
            成功: \(result.success)
            策略: \(result.strategy.rawValue)
            目标应用: \(result.targetApplication)
            耗时: \(String(format: "%.3f", result.duration))s
            """)
        
        if let error = result.error {
            logManager.error("TextInsertionService", "插入失败: \(error)")
        }
        
        return result
    }
    
    /// 测试文本插入功能
    public func testTextInsertion() async -> Bool {
        let testText = "📝 Hello Prompt v2 文本插入测试 - \(Date().timeIntervalSince1970)"
        let result = await insertText(testText)
        
        logManager.info("TextInsertionService", """
            文本插入测试结果:
            成功: \(result.success)
            策略: \(result.strategy.rawValue)
            目标应用: \(result.targetApplication)
            """)
        
        return result.success
    }
    
    /// 检查当前应用是否支持文本插入
    public func canInsertText() -> Bool {
        return contextDetector.canInsertText
    }
    
    /// 获取当前应用信息
    public func getCurrentApplicationInfo() -> ApplicationInfo? {
        return contextDetector.currentApplication
    }
    
    /// 获取应用上下文
    public func getApplicationContext() -> String {
        return contextDetector.getApplicationContext()
    }
    
    /// 获取插入能力信息
    public func getInsertionCapabilities() -> [String: Any] {
        return contextDetector.getInsertionCapabilities()
    }
    
    // MARK: - 文本处理
    private func preprocessText(_ text: String, mode: TextInsertionMode) -> String {
        switch mode {
        case .replace:
            // 替换模式：直接返回文本
            return text
        case .append:
            // 追加模式：确保前面有适当的间隔
            return text
        case .prepend:
            // 前置模式：确保后面有适当的间隔
            return text + " "
        }
    }
    
    // MARK: - 应用支持检查
    private func loadSupportedApplications() {
        // 从ContextDetector获取支持的应用列表
        let knownApps = [
            "Visual Studio Code", "Xcode", "Sublime Text", "TextEdit",
            "Safari", "Chrome", "Firefox", "Terminal", "iTerm",
            "Microsoft Word", "Pages", "WeChat", "Slack"
        ]
        
        supportedApplications = knownApps
        
        logManager.debug("TextInsertionService", "加载了\(supportedApplications.count)个支持的应用")
    }
    
    // MARK: - 权限和状态检查
    
    /// 检查系统权限状态
    public func checkPermissions() -> [String: Bool] {
        return [
            "accessibility": contextDetector.hasAccessibilityPermission,
            "monitoring": contextDetector.isMonitoring
        ]
    }
    
    /// 请求所需权限
    public func requestPermissions() async -> Bool {
        let accessibilityGranted = contextDetector.requestAccessibilityPermission()
        
        if accessibilityGranted && !contextDetector.isMonitoring {
            contextDetector.startMonitoring()
        }
        
        return accessibilityGranted
    }
    
    // MARK: - 高级功能
    
    /// 插入格式化文本
    public func insertFormattedText(_ text: String, format: TextFormat = .plain) async -> TextInsertionResult {
        let formattedText = applyTextFormat(text, format: format)
        return await insertText(formattedText)
    }
    
    /// 批量插入文本
    public func insertMultipleTexts(_ texts: [String], config: TextInsertionConfig = .default) async -> [TextInsertionResult] {
        var results: [TextInsertionResult] = []
        
        for (index, text) in texts.enumerated() {
            let result = await insertText(text, config: config)
            results.append(result)
            
            // 如果失败，停止后续插入
            if !result.success {
                logManager.warning("TextInsertionService", "批量插入在第\(index + 1)项失败，停止后续操作")
                break
            }
            
            // 批量插入时增加延迟
            if index < texts.count - 1 {
                try? await Task.sleep(nanoseconds: UInt64(config.insertDelay * 1_000_000_000))
            }
        }
        
        logManager.info("TextInsertionService", "批量插入完成: \(results.filter(\.success).count)/\(texts.count) 成功")
        
        return results
    }
}

// MARK: - 文本格式枚举
public enum TextFormat: String, CaseIterable {
    case plain = "纯文本"
    case markdown = "Markdown"
    case code = "代码"
    case quote = "引用"
    
    var prefix: String {
        switch self {
        case .plain: return ""
        case .markdown: return ""
        case .code: return "```\n"
        case .quote: return "> "
        }
    }
    
    var suffix: String {
        switch self {
        case .plain: return ""
        case .markdown: return ""
        case .code: return "\n```"
        case .quote: return ""
        }
    }
}

// MARK: - 文本格式化扩展
extension TextInsertionService {
    
    /// 应用文本格式
    private func applyTextFormat(_ text: String, format: TextFormat) -> String {
        switch format {
        case .plain:
            return text
        case .markdown:
            return text // Markdown格式保持原样
        case .code:
            return "```\n\(text)\n```"
        case .quote:
            let lines = text.components(separatedBy: .newlines)
            return lines.map { "> \($0)" }.joined(separator: "\n")
        }
    }
}

// MARK: - 便捷方法扩展
extension TextInsertionService {
    
    /// 快速插入文本（默认配置）
    public func quickInsert(_ text: String) async -> Bool {
        let result = await insertText(text)
        return result.success
    }
    
    /// 安全插入文本（带错误处理）
    public func safeInsert(_ text: String) async -> (success: Bool, error: String?) {
        let result = await insertText(text)
        return (result.success, result.error?.localizedDescription)
    }
    
    /// 插入代码块
    public func insertCodeBlock(_ code: String, language: String = "") async -> Bool {
        let codeBlock = language.isEmpty ? 
            "```\n\(code)\n```" : 
            "```\(language)\n\(code)\n```"
        
        let result = await insertText(codeBlock)
        return result.success
    }
    
    /// 插入引用文本
    public func insertQuote(_ text: String, author: String? = nil) async -> Bool {
        var quote = text.components(separatedBy: .newlines)
            .map { "> \($0)" }
            .joined(separator: "\n")
        
        if let author = author {
            quote += "\n\n— \(author)"
        }
        
        let result = await insertText(quote)
        return result.success
    }
}