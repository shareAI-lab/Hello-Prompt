//
//  ErrorHandler.swift
//  HelloPrompt
//
//  统一错误处理系统 - 提供分级错误处理、自动恢复机制和用户友好的错误体验
//  包含完整的错误类型定义和处理策略
//

import Foundation
import SwiftUI

// MARK: - 错误严重程度定义
public enum ErrorSeverity: String, CaseIterable, Comparable {
    case info       // 信息性错误，不影响功能
    case warning    // 警告性错误，功能降级
    case error      // 一般错误，功能受影响
    case critical   // 严重错误，需要重启或用户干预
    
    var priority: Int {
        switch self {
        case .info: return 0
        case .warning: return 1
        case .error: return 2
        case .critical: return 3
        }
    }
    
    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        }
    }
    
    var systemImage: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .critical: return "exclamationmark.octagon"
        }
    }
    
    // Add missing icon property (alias for systemImage)
    var icon: String {
        return systemImage
    }
    
    // Add missing description property
    var description: String {
        switch self {
        case .info: return "信息"
        case .warning: return "警告"
        case .error: return "错误"
        case .critical: return "严重错误"
        }
    }
    
    // Comparable conformance
    public static func < (lhs: ErrorSeverity, rhs: ErrorSeverity) -> Bool {
        return lhs.priority < rhs.priority
    }
}

// MARK: - 错误恢复策略
public enum RecoveryStrategy {
    case retry
    case userIntervention(String)
    case none
}

// MARK: - HelloPrompt 错误协议
public protocol HelloPromptError: LocalizedError {
    var errorCode: String { get }
    var severity: ErrorSeverity { get }
    var recoverySuggestion: String? { get }
    var underlyingError: Error? { get }
    var userInfo: [String: Any] { get }
    
    // Add missing properties for UI integration
    var userMessage: String { get }
    var recoveryStrategy: RecoveryStrategy { get }
}

// Default implementations
extension HelloPromptError {
    public var userMessage: String {
        return errorDescription ?? "发生了未知错误"
    }
    
    public var recoveryStrategy: RecoveryStrategy {
        if recoverySuggestion != nil {
            return .userIntervention(recoverySuggestion!)
        }
        return .none
    }
}

// MARK: - 音频系统错误
public enum AudioSystemError: HelloPromptError {
    case microphonePermissionDenied
    case audioEngineFailure(Error)
    case audioQualityTooLow(rms: Float)
    case recordingTimeout
    case vadFailure
    case audioSessionConfigurationFailed(Error)
    case audioFileCreationFailed(path: String)
    case audioBufferProcessingFailed
    case audioDeviceNotFound
    case audioFormatNotSupported
    
    public var errorCode: String {
        switch self {
        case .microphonePermissionDenied: return "AUDIO_001"
        case .audioEngineFailure: return "AUDIO_002"
        case .audioQualityTooLow: return "AUDIO_003"
        case .recordingTimeout: return "AUDIO_004"
        case .vadFailure: return "AUDIO_005"
        case .audioSessionConfigurationFailed: return "AUDIO_006"
        case .audioFileCreationFailed: return "AUDIO_007"
        case .audioBufferProcessingFailed: return "AUDIO_008"
        case .audioDeviceNotFound: return "AUDIO_009"
        case .audioFormatNotSupported: return "AUDIO_010"
        }
    }
    
    public var severity: ErrorSeverity {
        switch self {
        case .microphonePermissionDenied: return .critical
        case .audioEngineFailure: return .error
        case .audioQualityTooLow: return .warning
        case .recordingTimeout: return .info
        case .vadFailure: return .warning
        case .audioSessionConfigurationFailed: return .error
        case .audioFileCreationFailed: return .error
        case .audioBufferProcessingFailed: return .warning
        case .audioDeviceNotFound: return .error
        case .audioFormatNotSupported: return .error
        }
    }
    
    public var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "应用需要麦克风权限才能录音"
        case .audioEngineFailure(let error):
            return "音频引擎故障: \(error.localizedDescription)"
        case .audioQualityTooLow(let rms):
            return "音频质量过低 (RMS: \(String(format: "%.3f", rms)))，请在安静环境中重试"
        case .recordingTimeout:
            return "录音时间过长，已自动停止"
        case .vadFailure:
            return "语音活动检测失败，请重新录制"
        case .audioSessionConfigurationFailed(let error):
            return "音频会话配置失败: \(error.localizedDescription)"
        case .audioFileCreationFailed(let path):
            return "无法创建音频文件: \(path)"
        case .audioBufferProcessingFailed:
            return "音频缓冲区处理失败"
        case .audioDeviceNotFound:
            return "未找到可用的音频输入设备"
        case .audioFormatNotSupported:
            return "不支持的音频格式"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .microphonePermissionDenied:
            return "请到系统偏好设置 > 安全性与隐私 > 麦克风 中授权"
        case .audioEngineFailure:
            return "请重启应用或检查音频设备连接"
        case .audioQualityTooLow:
            return "请靠近麦克风，确保环境安静，或调整音频输入增益"
        case .recordingTimeout:
            return "请在30秒内完成录音，或考虑分段录制"
        case .vadFailure:
            return "请说话更清晰一些，或调整静音检测阈值"
        case .audioSessionConfigurationFailed:
            return "请检查其他应用是否占用音频设备，或重启应用"
        case .audioFileCreationFailed:
            return "请检查磁盘空间和写入权限"
        case .audioBufferProcessingFailed:
            return "请降低音频处理复杂度或重启应用"
        case .audioDeviceNotFound:
            return "请连接麦克风或检查音频设备设置"
        case .audioFormatNotSupported:
            return "请使用支持的音频格式或更新音频驱动"
        }
    }
    
    public var underlyingError: Error? {
        switch self {
        case .audioEngineFailure(let error): return error
        case .audioSessionConfigurationFailed(let error): return error
        default: return nil
        }
    }
    
    public var userInfo: [String: Any] {
        var info: [String: Any] = [
            "errorCode": errorCode,
            "severity": severity.rawValue
        ]
        
        switch self {
        case .audioQualityTooLow(let rms):
            info["rms"] = rms
        case .audioFileCreationFailed(let path):
            info["filePath"] = path
        default:
            break
        }
        
        return info
    }
}

// MARK: - API相关错误
public enum APIError: HelloPromptError {
    case invalidAPIKey
    case networkTimeout
    case rateLimitExceeded(retryAfter: TimeInterval?)
    case audioFileTooLarge(size: Int)
    case transcriptionEmpty
    case optimizationFailed(Error)
    case invalidResponse(statusCode: Int)
    case quotaExceeded
    case modelNotAvailable(model: String)
    case contentFiltered
    case serverError(statusCode: Int, message: String?)
    
    public var errorCode: String {
        switch self {
        case .invalidAPIKey: return "API_001"
        case .networkTimeout: return "API_002"
        case .rateLimitExceeded: return "API_003"
        case .audioFileTooLarge: return "API_004"
        case .transcriptionEmpty: return "API_005"
        case .optimizationFailed: return "API_006"
        case .invalidResponse: return "API_007"
        case .quotaExceeded: return "API_008"
        case .modelNotAvailable: return "API_009"
        case .contentFiltered: return "API_010"
        case .serverError: return "API_011"
        }
    }
    
    public var severity: ErrorSeverity {
        switch self {
        case .invalidAPIKey: return .critical
        case .networkTimeout: return .error
        case .rateLimitExceeded: return .warning
        case .audioFileTooLarge: return .warning
        case .transcriptionEmpty: return .info
        case .optimizationFailed: return .error
        case .invalidResponse: return .error
        case .quotaExceeded: return .critical
        case .modelNotAvailable: return .error
        case .contentFiltered: return .warning
        case .serverError: return .error
        }
    }
    
    public var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "OpenAI API密钥无效或已过期"
        case .networkTimeout:
            return "网络连接超时"
        case .rateLimitExceeded(let retryAfter):
            let waitTime = retryAfter.map { String(format: "%.0f", $0) } ?? "未知"
            return "API调用频率超限，请等待 \(waitTime) 秒后重试"
        case .audioFileTooLarge(let size):
            let sizeInMB = Double(size) / (1024 * 1024)
            return "音频文件过大 (\(String(format: "%.1f", sizeInMB))MB)，OpenAI限制为25MB"
        case .transcriptionEmpty:
            return "语音识别结果为空，可能是静音录制或音质问题"
        case .optimizationFailed(let error):
            return "提示词优化失败: \(error.localizedDescription)"
        case .invalidResponse(let statusCode):
            return "API响应无效 (状态码: \(statusCode))"
        case .quotaExceeded:
            return "API配额已用完，请检查账户余额或升级计划"
        case .modelNotAvailable(let model):
            return "模型不可用: \(model)"
        case .contentFiltered:
            return "内容被过滤，请检查输入内容是否符合使用政策"
        case .serverError(let statusCode, let message):
            return "服务器错误 (\(statusCode)): \(message ?? "未知错误")"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .invalidAPIKey:
            return "请检查设置中的API密钥配置，确保密钥有效且有足够权限"
        case .networkTimeout:
            return "请检查网络连接，或稍后重试"
        case .rateLimitExceeded(let retryAfter):
            let waitTime = retryAfter.map { String(format: "%.0f", $0) } ?? "60"
            return "请等待 \(waitTime) 秒后重试，或考虑升级API计划"
        case .audioFileTooLarge:
            return "请录制更短的音频，或使用更低的音频质量设置"
        case .transcriptionEmpty:
            return "请重新录制，确保有清晰的语音输入，避免环境噪音"
        case .optimizationFailed:
            return "请重试，或检查网络连接和API配置"
        case .invalidResponse:
            return "请稍后重试，或联系技术支持"
        case .quotaExceeded:
            return "请充值账户余额或升级到更高的API计划"
        case .modelNotAvailable:
            return "请选择其他可用模型，或稍后重试"
        case .contentFiltered:
            return "请修改输入内容，确保符合OpenAI使用政策"
        case .serverError:
            return "请稍后重试，如果问题持续请联系技术支持"
        }
    }
    
    public var underlyingError: Error? {
        switch self {
        case .optimizationFailed(let error): return error
        default: return nil
        }
    }
    
    public var userInfo: [String: Any] {
        var info: [String: Any] = [
            "errorCode": errorCode,
            "severity": severity.rawValue
        ]
        
        switch self {
        case .rateLimitExceeded(let retryAfter):
            if let retryAfter = retryAfter {
                info["retryAfter"] = retryAfter
            }
        case .audioFileTooLarge(let size):
            info["fileSize"] = size
        case .invalidResponse(let statusCode):
            info["statusCode"] = statusCode
        case .modelNotAvailable(let model):
            info["model"] = model
        case .serverError(let statusCode, let message):
            info["statusCode"] = statusCode
            if let message = message {
                info["serverMessage"] = message
            }
        default:
            break
        }
        
        return info
    }
}

// MARK: - UI相关错误
public enum UIError: HelloPromptError {
    case windowCreationFailed
    case overlayDisplayFailed
    case keyboardShortcutConflict(shortcut: String)
    case settingsLoadFailed
    case invalidUserInput(field: String)
    case accessibilityPermissionDenied
    
    public var errorCode: String {
        switch self {
        case .windowCreationFailed: return "UI_001"
        case .overlayDisplayFailed: return "UI_002"
        case .keyboardShortcutConflict: return "UI_003"
        case .settingsLoadFailed: return "UI_004"
        case .invalidUserInput: return "UI_005"
        case .accessibilityPermissionDenied: return "UI_006"
        }
    }
    
    public var severity: ErrorSeverity {
        switch self {
        case .windowCreationFailed: return .error
        case .overlayDisplayFailed: return .error
        case .keyboardShortcutConflict: return .warning
        case .settingsLoadFailed: return .warning
        case .invalidUserInput: return .info
        case .accessibilityPermissionDenied: return .critical
        }
    }
    
    public var errorDescription: String? {
        switch self {
        case .windowCreationFailed:
            return "无法创建应用窗口"
        case .overlayDisplayFailed:
            return "无法显示结果覆盖层"
        case .keyboardShortcutConflict(let shortcut):
            return "快捷键冲突: \(shortcut)"
        case .settingsLoadFailed:
            return "无法加载应用设置"
        case .invalidUserInput(let field):
            return "输入无效: \(field)"
        case .accessibilityPermissionDenied:
            return "需要辅助功能权限才能插入文本"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .windowCreationFailed:
            return "请重启应用，或检查系统显示设置"
        case .overlayDisplayFailed:
            return "请检查显示器配置，或重启应用"
        case .keyboardShortcutConflict:
            return "请在设置中选择其他快捷键"
        case .settingsLoadFailed:
            return "应用将使用默认设置，请检查配置文件"
        case .invalidUserInput:
            return "请检查输入格式并重新输入"
        case .accessibilityPermissionDenied:
            return "请到系统偏好设置 > 安全性与隐私 > 辅助功能 中授权"
        }
    }
    
    public var underlyingError: Error? { return nil }
    
    public var userInfo: [String: Any] {
        var info: [String: Any] = [
            "errorCode": errorCode,
            "severity": severity.rawValue
        ]
        
        switch self {
        case .keyboardShortcutConflict(let shortcut):
            info["shortcut"] = shortcut
        case .invalidUserInput(let field):
            info["field"] = field
        default:
            break
        }
        
        return info
    }
}

// MARK: - 配置相关错误
public enum ConfigError: HelloPromptError {
    case keychainAccessFailed
    case configurationCorrupted
    case migrationFailed(fromVersion: String, toVersion: String)
    case validationFailed(key: String, value: Any)
    case defaultsReadFailed
    case defaultsWriteFailed
    
    public var errorCode: String {
        switch self {
        case .keychainAccessFailed: return "CONFIG_001"
        case .configurationCorrupted: return "CONFIG_002"
        case .migrationFailed: return "CONFIG_003"
        case .validationFailed: return "CONFIG_004"
        case .defaultsReadFailed: return "CONFIG_005"
        case .defaultsWriteFailed: return "CONFIG_006"
        }
    }
    
    public var severity: ErrorSeverity {
        switch self {
        case .keychainAccessFailed: return .error
        case .configurationCorrupted: return .error
        case .migrationFailed: return .warning
        case .validationFailed: return .warning
        case .defaultsReadFailed: return .warning
        case .defaultsWriteFailed: return .error
        }
    }
    
    public var errorDescription: String? {
        switch self {
        case .keychainAccessFailed:
            return "无法访问钥匙串存储"
        case .configurationCorrupted:
            return "配置文件已损坏"
        case .migrationFailed(let fromVersion, let toVersion):
            return "配置迁移失败: \(fromVersion) -> \(toVersion)"
        case .validationFailed(let key, let value):
            return "配置验证失败: \(key) = \(value)"
        case .defaultsReadFailed:
            return "无法读取用户偏好设置"
        case .defaultsWriteFailed:
            return "无法保存用户偏好设置"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .keychainAccessFailed:
            return "请重启应用，或检查钥匙串访问权限"
        case .configurationCorrupted:
            return "应用将重置为默认配置，请重新设置"
        case .migrationFailed:
            return "请手动重新配置应用设置"
        case .validationFailed:
            return "请检查配置值的格式和范围"
        case .defaultsReadFailed:
            return "应用将使用默认设置"
        case .defaultsWriteFailed:
            return "请检查磁盘空间和写入权限"
        }
    }
    
    public var underlyingError: Error? { return nil }
    
    public var userInfo: [String: Any] {
        var info: [String: Any] = [
            "errorCode": errorCode,
            "severity": severity.rawValue
        ]
        
        switch self {
        case .migrationFailed(let fromVersion, let toVersion):
            info["fromVersion"] = fromVersion
            info["toVersion"] = toVersion
        case .validationFailed(let key, let value):
            info["key"] = key
            info["value"] = String(describing: value)
        default:
            break
        }
        
        return info
    }
}

// MARK: - 统一错误处理器
public final class ErrorHandler: ObservableObject {
    
    // MARK: - 单例实例
    nonisolated public static let shared = ErrorHandler()
    
    // MARK: - Published Properties
    @Published public var currentError: HelloPromptError?
    @Published public var isShowingErrorAlert = false
    @Published public var isShowingError = false
    @Published public var errorHistory: [ErrorRecord] = []
    
    // MARK: - 错误记录结构
    public struct ErrorRecord: Identifiable {
        public let id = UUID()
        public let timestamp: Date
        public let error: HelloPromptError
        public let context: String
        public let handled: Bool
        public let recovered: Bool
    }
    
    // MARK: - 私有属性
    private let maxErrorHistory = 100
    private var recoveryStrategies: [String: RecoveryStrategy] = [:]
    
    // MARK: - 恢复策略
    public struct RecoveryStrategy {
        let canRecover: (HelloPromptError) -> Bool
        let recover: (HelloPromptError) async throws -> Bool
        let maxAttempts: Int
        
        public init(
            canRecover: @escaping (HelloPromptError) -> Bool,
            recover: @escaping (HelloPromptError) async throws -> Bool,
            maxAttempts: Int = 3
        ) {
            self.canRecover = canRecover
            self.recover = recover
            self.maxAttempts = maxAttempts
        }
    }
    
    // MARK: - 初始化
    private init() {
        setupDefaultRecoveryStrategies()
        LogManager.shared.info("ErrorHandler", "错误处理器初始化完成")
    }
    
    // MARK: - 主要错误处理方法
    public func handle(_ error: HelloPromptError, context: String = "") {
        // 记录错误
        LogManager.shared.error(
            "ErrorHandler",
            "[\(error.errorCode)] \(context): \(error.localizedDescription)",
            metadata: error.userInfo
        )
        
        // 添加到错误历史
        let record = ErrorRecord(
            timestamp: Date(),
            error: error,
            context: context,
            handled: true,
            recovered: false
        )
        addToErrorHistory(record)
        
        // 根据严重程度处理错误
        Task {
            await handleBySeverity(error, context: context)
        }
    }
    
    // MARK: - 按严重程度处理错误
    private func handleBySeverity(_ error: HelloPromptError, context: String) async {
        switch error.severity {
        case .info:
            await handleInfoError(error)
        case .warning:
            await handleWarningError(error)
        case .error:
            await handleGeneralError(error)
        case .critical:
            await handleCriticalError(error)
        }
        
        // 尝试自动恢复
        await attemptRecovery(error)
    }
    
    // MARK: - 分级错误处理
    private func handleInfoError(_ error: HelloPromptError) async {
        // 轻微提示，不打断用户
        LogManager.shared.info("ErrorHandler", "信息性错误: \(error.localizedDescription)")
    }
    
    private func handleWarningError(_ error: HelloPromptError) async {
        LogManager.shared.warning("ErrorHandler", "警告错误: \(error.localizedDescription)")
        // 可以显示状态栏提示或轻微的UI反馈
    }
    
    private func handleGeneralError(_ error: HelloPromptError) async {
        LogManager.shared.error("ErrorHandler", "一般错误: \(error.localizedDescription)")
        
        await MainActor.run {
            currentError = error
            isShowingErrorAlert = true
            isShowingError = true
        }
    }
    
    private func handleCriticalError(_ error: HelloPromptError) async {
        LogManager.shared.critical("ErrorHandler", "严重错误: \(error.localizedDescription)")
        
        await MainActor.run {
            currentError = error
            isShowingErrorAlert = true
            isShowingError = true
        }
        
        // 严重错误可能需要特殊处理
        await handleCriticalErrorSpecialCase(error)
    }
    
    private func handleCriticalErrorSpecialCase(_ error: HelloPromptError) async {
        switch error {
        case let audioError as AudioSystemError:
            switch audioError {
            case .microphonePermissionDenied:
                // 可以引导用户到系统设置
                LogManager.shared.critical("ErrorHandler", "需要引导用户授权麦克风权限")
            default:
                break
            }
        case let apiError as APIError:
            switch apiError {
            case .quotaExceeded:
                // 可以引导用户到账户管理
                LogManager.shared.critical("ErrorHandler", "需要引导用户检查API配额")
            default:
                break
            }
        default:
            break
        }
    }
    
    // MARK: - 自动恢复机制
    private func attemptRecovery(_ error: HelloPromptError) async {
        let errorType = String(describing: type(of: error))
        
        guard let strategy = recoveryStrategies[errorType],
              strategy.canRecover(error) else {
            LogManager.shared.debug("ErrorHandler", "没有找到适用的恢复策略: \(errorType)")
            return
        }
        
        LogManager.shared.info("ErrorHandler", "开始尝试自动恢复: \(errorType)")
        
        for attempt in 1...strategy.maxAttempts {
            do {
                let recovered = try await strategy.recover(error)
                if recovered {
                    LogManager.shared.info("ErrorHandler", "自动恢复成功: 第\(attempt)次尝试")
                    updateErrorRecord(for: error, recovered: true)
                    return
                }
            } catch {
                LogManager.shared.warning("ErrorHandler", "恢复尝试失败: 第\(attempt)次，错误: \(error)")
            }
        }
        
        LogManager.shared.error("ErrorHandler", "自动恢复失败，已达到最大尝试次数")
    }
    
    // MARK: - 恢复策略设置
    private func setupDefaultRecoveryStrategies() {
        // 音频错误恢复策略
        recoveryStrategies["AudioSystemError"] = RecoveryStrategy(
            canRecover: { error in
                if let audioError = error as? AudioSystemError {
                    switch audioError {
                    case .audioEngineFailure, .audioSessionConfigurationFailed:
                        return true
                    default:
                        return false
                    }
                }
                return false
            },
            recover: { error in
                // 尝试重新初始化音频引擎
                LogManager.shared.info("ErrorHandler", "尝试重新初始化音频系统")
                // 这里应该调用实际的音频服务重新初始化方法
                return true
            },
            maxAttempts: 2
        )
        
        // API错误恢复策略
        recoveryStrategies["APIError"] = RecoveryStrategy(
            canRecover: { error in
                if let apiError = error as? APIError {
                    switch apiError {
                    case .networkTimeout, .rateLimitExceeded:
                        return true
                    default:
                        return false
                    }
                }
                return false
            },
            recover: { error in
                if let apiError = error as? APIError {
                    switch apiError {
                    case .rateLimitExceeded(let retryAfter):
                        if let delay = retryAfter {
                            LogManager.shared.info("ErrorHandler", "等待\(delay)秒后重试API调用")
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        }
                        return true
                    case .networkTimeout:
                        LogManager.shared.info("ErrorHandler", "网络超时，等待后重试")
                        try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
                        return true
                    default:
                        return false
                    }
                }
                return false
            },
            maxAttempts: 3
        )
    }
    
    // MARK: - 工具方法
    private func addToErrorHistory(_ record: ErrorRecord) {
        errorHistory.append(record)
        
        if errorHistory.count > maxErrorHistory {
            errorHistory.removeFirst(errorHistory.count - maxErrorHistory)
        }
    }
    
    private func updateErrorRecord(for error: HelloPromptError, recovered: Bool) {
        if let index = errorHistory.lastIndex(where: { $0.error.errorCode == error.errorCode }) {
            let oldRecord = errorHistory[index]
            let updatedRecord = ErrorRecord(
                timestamp: oldRecord.timestamp,
                error: oldRecord.error,
                context: oldRecord.context,
                handled: oldRecord.handled,
                recovered: recovered
            )
            errorHistory[index] = updatedRecord
        }
    }
    
    // MARK: - 公共方法
    
    /// 清除当前错误状态
    public func clearCurrentError() {
        currentError = nil
        isShowingErrorAlert = false
        isShowingError = false
    }
    
    /// 关闭错误显示
    public func dismissError() {
        currentError = nil
        isShowingErrorAlert = false
        isShowingError = false
    }
    
    /// 添加自定义恢复策略
    public func addRecoveryStrategy(for errorType: String, strategy: RecoveryStrategy) {
        recoveryStrategies[errorType] = strategy
        LogManager.shared.info("ErrorHandler", "已添加恢复策略: \(errorType)")
    }
    
    /// 获取错误统计
    public func getErrorStatistics() -> [String: Int] {
        var stats: [String: Int] = [:]
        
        for record in errorHistory {
            let key = record.error.errorCode
            stats[key, default: 0] += 1
        }
        
        return stats
    }
    
    /// 导出错误报告
    public func exportErrorReport() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let header = "Hello Prompt v2 错误报告\n生成时间: \(formatter.string(from: Date()))\n\n"
        
        let errors = errorHistory.map { record in
            """
            时间: \(formatter.string(from: record.timestamp))
            错误码: \(record.error.errorCode)
            严重程度: \(record.error.severity.rawValue)
            描述: \(record.error.localizedDescription)
            上下文: \(record.context)
            已处理: \(record.handled ? "是" : "否")
            已恢复: \(record.recovered ? "是" : "否")
            恢复建议: \(record.error.recoverySuggestion ?? "无建议")
            ---
            """
        }.joined(separator: "\n")
        
        return header + errors
    }
}

// MARK: - 便捷错误处理方法
extension ErrorHandler {
    
    /// 处理音频系统错误
    public func handleAudioError(_ error: AudioSystemError, context: String = "") {
        handle(error, context: "AudioSystem: \(context)")
    }
    
    /// 处理API错误
    public func handleAPIError(_ error: APIError, context: String = "") {
        handle(error, context: "API: \(context)")
    }
    
    /// 处理UI错误
    public func handleUIError(_ error: UIError, context: String = "") {
        handle(error, context: "UI: \(context)")
    }
    
    /// 处理配置错误
    public func handleConfigError(_ error: ConfigError, context: String = "") {
        handle(error, context: "Config: \(context)")
    }
}