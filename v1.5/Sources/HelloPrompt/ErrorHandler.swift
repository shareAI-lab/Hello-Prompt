//
//  ErrorHandler.swift
//  HelloPrompt
//
//  增强错误处理系统 - 提供用户友好提示和自动恢复机制
//  Copyright © 2025 HelloPrompt. All rights reserved.
//

import Foundation
import AppKit

// MARK: - 应用错误类型
enum AppError: LocalizedError {
    case audioPermissionDenied
    case microphoneNotAvailable
    case openAIAPIKeyMissing
    case openAIAPIKeyInvalid
    case networkConnectionFailed
    case audioRecordingFailed(underlying: Error)
    case speechRecognitionFailed(underlying: Error)
    case textInsertionFailed(underlying: Error)
    case configurationLoadFailed(underlying: Error)
    case shortcutRegistrationFailed(underlying: Error)
    case unknownError(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .audioPermissionDenied:
            return "麦克风权限被拒绝，请在系统偏好设置中允许 Hello Prompt 访问麦克风"
        case .microphoneNotAvailable:
            return "未检测到可用的麦克风设备"
        case .openAIAPIKeyMissing:
            return "OpenAI API 密钥未配置，请在设置中添加 API 密钥"
        case .openAIAPIKeyInvalid:
            return "OpenAI API 密钥无效，请检查密钥是否正确"
        case .networkConnectionFailed:
            return "网络连接失败，请检查网络连接后重试"
        case .audioRecordingFailed(let error):
            return "音频录制失败：\(error.localizedDescription)"
        case .speechRecognitionFailed(let error):
            return "语音识别失败：\(error.localizedDescription)"
        case .textInsertionFailed(let error):
            return "文本插入失败：\(error.localizedDescription)"
        case .configurationLoadFailed(let error):
            return "配置加载失败：\(error.localizedDescription)"
        case .shortcutRegistrationFailed(let error):
            return "快捷键注册失败：\(error.localizedDescription)"
        case .unknownError(let error):
            return "未知错误：\(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .audioPermissionDenied:
            return "前往 系统偏好设置 > 安全性与隐私 > 隐私 > 麦克风，确保 Hello Prompt 已被勾选授权"
        case .microphoneNotAvailable:
            return "检查以下项目：\n• 麦克风设备是否正确连接\n• 其他应用是否正在占用麦克风\n• 在系统偏好设置中选择正确的输入设备"
        case .openAIAPIKeyMissing:
            return "需要配置 OpenAI API 密钥：\n• 访问 platform.openai.com 获取 API 密钥\n• 在设置页面的 API 配置中输入密钥\n• 点击\"测试连接\"确保配置正确"
        case .openAIAPIKeyInvalid:
            return "API 密钥可能存在问题：\n• 检查密钥是否完整（以 sk- 开头）\n• 确认密钥在 OpenAI 平台上仍然有效\n• 检查账户是否有足够的使用配额"
        case .networkConnectionFailed:
            return "网络连接问题排查：\n• 检查网络连接是否正常\n• 确认防火墙没有阻止应用访问网络\n• 如使用VPN，尝试更换节点或暂时关闭"
        case .audioRecordingFailed:
            return "录音失败的可能原因：\n• 麦克风权限未授权\n• 音频设备被其他应用占用\n• 系统音频服务异常，尝试重启音频服务"
        case .speechRecognitionFailed:
            return "语音识别失败的解决方案：\n• 确认网络连接稳定\n• 检查 API 密钥和配额\n• 录音环境过于嘈杂时可能影响识别准确率"
        case .textInsertionFailed:
            return "文本插入失败的处理方法：\n• 在系统偏好设置中开启辅助功能权限\n• 确认目标应用支持文本输入\n• 尝试手动复制粘贴作为备选方案"
        case .configurationLoadFailed:
            return "配置文件可能损坏：\n• 尝试重新启动应用\n• 考虑重置配置到默认状态\n• 如果问题持续，联系技术支持"
        case .shortcutRegistrationFailed:
            return "快捷键注册问题：\n• 前往系统偏好设置开启输入监控权限\n• 检查快捷键是否与系统或其他应用冲突\n• 尝试更换快捷键组合"
        case .unknownError:
            return "通用故障排除步骤：\n• 重启 Hello Prompt 应用\n• 检查系统日志获取更多信息\n• 更新到最新版本\n• 联系技术支持并提供错误详情"
        }
    }
    
    var canAutoRecover: Bool {
        switch self {
        case .networkConnectionFailed, .speechRecognitionFailed, .audioRecordingFailed:
            return true
        default:
            return false
        }
    }
}

// MARK: - 错误恢复动作
enum ErrorRecoveryAction: Equatable {
    case retry
    case openSettings
    case configureAPI
    case resetConfiguration
    case openSystemPreferences(String)
    case cancel
    
    var title: String {
        switch self {
        case .retry:
            return "重试"
        case .openSettings:
            return "打开设置"
        case .configureAPI:
            return "配置API"
        case .resetConfiguration:
            return "重置配置"
        case .openSystemPreferences:
            return "打开系统设置"
        case .cancel:
            return "取消"
        }
    }
}

// MARK: - 错误处理器代理
@MainActor
protocol ErrorHandlerDelegate: AnyObject {
    func errorHandler(_ handler: ErrorHandler, shouldRetry error: AppError) -> Bool
    func errorHandler(_ handler: ErrorHandler, didRecover error: AppError)
    func errorHandler(_ handler: ErrorHandler, failedToRecover error: AppError)
}

// MARK: - 增强错误处理器
@MainActor
class ErrorHandler: NSObject {
    static let shared = ErrorHandler()
    
    weak var delegate: ErrorHandlerDelegate?
    
    private var errorCount: [String: Int] = [:]
    private let maxRetryCount = 3
    private let retryDelay: TimeInterval = 2.0
    
    private override init() {
        super.init()
        LogManager.shared.info(.app, "ErrorHandler初始化完成")
    }
    
    // MARK: - Public Methods
    
    /// 处理错误
    func handle(_ error: Error, context: String = "") {
        let appError = convertToAppError(error)
        let errorKey = "\(appError.localizedDescription)_\(context)"
        
        LogManager.shared.error(.app, "处理错误", metadata: [
            "error": appError.localizedDescription,
            "context": context,
            "canAutoRecover": appError.canAutoRecover
        ])
        
        // 增加错误计数
        errorCount[errorKey] = (errorCount[errorKey] ?? 0) + 1
        
        // 尝试自动恢复
        if appError.canAutoRecover && errorCount[errorKey, default: 0] <= maxRetryCount {
            attemptAutoRecovery(appError, context: context)
        } else {
            showErrorDialog(appError, context: context)
        }
    }
    
    /// 清除错误计数
    func clearErrorCount(for context: String = "") {
        if context.isEmpty {
            errorCount.removeAll()
        } else {
            let keysToRemove = errorCount.keys.filter { $0.contains(context) }
            keysToRemove.forEach { errorCount.removeValue(forKey: $0) }
        }
        
        LogManager.shared.info(.app, "清除错误计数", metadata: ["context": context])
    }
    
    // MARK: - Private Methods
    
    /// 将通用错误转换为应用错误
    private func convertToAppError(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        
        let description = error.localizedDescription.lowercased()
        
        // 检查具体的错误类型
        if let audioError = error as? AudioServiceError {
            return convertAudioServiceError(audioError)
        }
        
        if let openAIError = error as? OpenAIServiceError {
            return convertOpenAIServiceError(openAIError)
        }
        
        if let configError = error as? ConfigurationError {
            return convertConfigurationError(configError)
        }
        
        // 基于错误描述进行智能识别
        if description.contains("permission") || description.contains("authorization") || 
           description.contains("denied") || description.contains("access") {
            if description.contains("microphone") || description.contains("audio") {
                return .audioPermissionDenied
            }
        }
        
        if description.contains("network") || description.contains("connection") || 
           description.contains("timeout") || description.contains("unreachable") {
            return .networkConnectionFailed
        }
        
        if description.contains("api") && (description.contains("key") || description.contains("token")) {
            if description.contains("missing") || description.contains("empty") {
                return .openAIAPIKeyMissing
            } else {
                return .openAIAPIKeyInvalid
            }
        }
        
        if description.contains("audio") || description.contains("recording") || 
           description.contains("microphone") {
            return .audioRecordingFailed(underlying: error)
        }
        
        if description.contains("speech") || description.contains("recognition") || 
           description.contains("transcription") {
            return .speechRecognitionFailed(underlying: error)
        }
        
        if description.contains("text") && description.contains("insert") {
            return .textInsertionFailed(underlying: error)
        }
        
        if description.contains("configuration") || description.contains("config") {
            return .configurationLoadFailed(underlying: error)
        }
        
        if description.contains("shortcut") || description.contains("hotkey") {
            return .shortcutRegistrationFailed(underlying: error)
        }
        
        return .unknownError(underlying: error)
    }
    
    /// 转换音频服务错误
    private func convertAudioServiceError(_ error: AudioServiceError) -> AppError {
        switch error {
        case .permissionDenied:
            return .audioPermissionDenied
        case .audioEngineFailure, .recordingFailed, .invalidAudioFormat:
            return .audioRecordingFailed(underlying: error)
        case .maxDurationReached:
            return .audioRecordingFailed(underlying: error)
        }
    }
    
    /// 转换OpenAI服务错误
    private func convertOpenAIServiceError(_ error: OpenAIServiceError) -> AppError {
        switch error {
        case .invalidAPIKey:
            return .openAIAPIKeyInvalid
        case .networkError:
            return .networkConnectionFailed
        case .apiError(let code, _):
            if code == 401 {
                return .openAIAPIKeyInvalid
            } else if code == 429 || code == 503 {
                return .networkConnectionFailed
            } else {
                return .speechRecognitionFailed(underlying: error)
            }
        case .invalidResponse, .emptyResponse, .invalidJsonResponse:
            return .speechRecognitionFailed(underlying: error)
        case .rateLimitExceeded, .quotaExceeded:
            return .openAIAPIKeyInvalid
        case .emptyTranscription, .invalidTranscription, .lowConfidence, .lowQualityTranscription:
            return .speechRecognitionFailed(underlying: error)
        }
    }
    
    /// 转换配置错误
    private func convertConfigurationError(_ error: ConfigurationError) -> AppError {
        return .configurationLoadFailed(underlying: error)
    }
    
    /// 尝试自动恢复
    private func attemptAutoRecovery(_ error: AppError, context: String) {
        LogManager.shared.info(.app, "尝试自动恢复", metadata: [
            "error": error.localizedDescription,
            "context": context
        ])
        
        Task {
            try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
            
            let shouldRetry = delegate?.errorHandler(self, shouldRetry: error) ?? true
            if shouldRetry {
                LogManager.shared.info(.app, "自动恢复成功", metadata: ["error": error.localizedDescription])
                delegate?.errorHandler(self, didRecover: error)
            } else {
                LogManager.shared.warning(.app, "自动恢复失败", metadata: ["error": error.localizedDescription])
                delegate?.errorHandler(self, failedToRecover: error)
                showErrorDialog(error, context: context)
            }
        }
    }
    
    /// 显示错误对话框
    private func showErrorDialog(_ error: AppError, context: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = getErrorTitle(for: error)
        alert.informativeText = error.localizedDescription
        
        // 添加恢复建议
        if let recoverySuggestion = error.recoverySuggestion {
            alert.informativeText += "\n\n💡 解决方案：\n\(recoverySuggestion)"
        }
        
        // 添加上下文信息
        if !context.isEmpty {
            alert.informativeText += "\n\n📍 发生位置：\(context)"
        }
        
        // 添加操作按钮
        let actions = getRecoveryActions(for: error)
        for action in actions {
            alert.addButton(withTitle: action.title)
        }
        
        // 设置默认和取消按钮
        if let firstButton = alert.buttons.first {
            firstButton.keyEquivalent = "\r" // Enter键
        }
        if let lastButton = alert.buttons.last, actions.contains(.cancel) {
            lastButton.keyEquivalent = "\u{1b}" // Escape键
        }
        
        // 显示对话框并处理响应
        let response = alert.runModal()
        if response.rawValue >= NSApplication.ModalResponse.alertFirstButtonReturn.rawValue {
            let actionIndex = Int(response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue)
            if actionIndex < actions.count {
                handleRecoveryAction(actions[actionIndex], for: error)
            }
        }
        
        LogManager.shared.info(.app, "显示错误对话框", metadata: [
            "error": error.localizedDescription,
            "context": context,
            "actionsCount": actions.count,
            "title": getErrorTitle(for: error)
        ])
    }
    
    /// 获取错误标题
    private func getErrorTitle(for error: AppError) -> String {
        switch error {
        case .audioPermissionDenied:
            return "需要麦克风权限"
        case .microphoneNotAvailable:
            return "麦克风设备不可用"
        case .openAIAPIKeyMissing:
            return "未配置 API 密钥"
        case .openAIAPIKeyInvalid:
            return "API 密钥无效"
        case .networkConnectionFailed:
            return "网络连接失败"
        case .audioRecordingFailed:
            return "录音功能异常"
        case .speechRecognitionFailed:
            return "语音识别失败"
        case .textInsertionFailed:
            return "文本插入失败"
        case .configurationLoadFailed:
            return "配置加载失败"
        case .shortcutRegistrationFailed:
            return "快捷键注册失败"
        case .unknownError:
            return "应用遇到未知错误"
        }
    }
    
    /// 获取恢复动作
    private func getRecoveryActions(for error: AppError) -> [ErrorRecoveryAction] {
        switch error {
        case .audioPermissionDenied:
            return [.openSystemPreferences("Privacy_Microphone"), .cancel]
        case .microphoneNotAvailable:
            return [.retry, .openSettings, .cancel]
        case .openAIAPIKeyMissing, .openAIAPIKeyInvalid:
            return [.configureAPI, .cancel]
        case .networkConnectionFailed:
            return [.retry, .cancel]
        case .configurationLoadFailed:
            return [.resetConfiguration, .retry, .cancel]
        case .shortcutRegistrationFailed:
            return [.openSystemPreferences("Privacy_InputMonitoring"), .openSettings, .cancel]
        default:
            return [.retry, .openSettings, .cancel]
        }
    }
    
    /// 处理恢复动作
    private func handleRecoveryAction(_ action: ErrorRecoveryAction, for error: AppError) {
        LogManager.shared.info(.app, "执行恢复动作", metadata: [
            "action": action.title,
            "error": error.localizedDescription
        ])
        
        switch action {
        case .retry:
            clearErrorCount()
            let _ = delegate?.errorHandler(self, shouldRetry: error)
            
        case .openSettings:
            SettingsWindowManager.shared.showSettings()
            
        case .configureAPI:
            SettingsWindowManager.shared.showSettings()
            // TODO: 直接导航到API配置页面
            
        case .resetConfiguration:
            showResetConfigurationConfirmation()
            
        case .openSystemPreferences(let pane):
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!
            NSWorkspace.shared.open(url)
            
        case .cancel:
            break
        }
    }
    
    /// 显示重置配置确认对话框
    private func showResetConfigurationConfirmation() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "重置配置"
        alert.informativeText = "确定要重置所有配置到默认状态吗？这将清除您的API密钥和所有自定义设置。"
        alert.addButton(withTitle: "重置")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            ConfigurationManager.shared.resetToDefaults()
            
            LogManager.shared.info(.app, "用户确认重置配置")
            
            // 显示重置成功提示
            let successAlert = NSAlert()
            successAlert.alertStyle = .informational
            successAlert.messageText = "配置重置完成"
            successAlert.informativeText = "所有配置已重置为默认值，请重新配置API密钥。"
            successAlert.addButton(withTitle: "确定")
            successAlert.runModal()
        }
    }
    
    /// 获取错误统计
    func getErrorStatistics() -> [String: Int] {
        return errorCount
    }
}

// MARK: - 错误处理扩展
extension ErrorHandler {
    
    /// 处理音频相关错误
    func handleAudioError(_ error: Error, context: String = "音频处理") {
        handle(error, context: context)
    }
    
    /// 处理网络相关错误
    func handleNetworkError(_ error: Error, context: String = "网络请求") {
        handle(error, context: context)
    }
    
    /// 处理配置相关错误
    func handleConfigurationError(_ error: Error, context: String = "配置管理") {
        handle(error, context: context)
    }
    
    /// 处理权限相关错误
    func handlePermissionError(_ error: Error, context: String = "权限检查") {
        handle(error, context: context)
    }
}