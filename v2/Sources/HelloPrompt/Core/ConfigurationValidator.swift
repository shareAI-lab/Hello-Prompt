//
//  ConfigurationValidator.swift
//  HelloPrompt
//
//  配置验证器 - 验证关键参数和系统配置
//  确保应用在正确的配置下运行
//

import Foundation
import AVFoundation

// MARK: - 配置验证结果
public struct ValidationResult {
    public let isValid: Bool
    public let errors: [ValidationError]
    public let warnings: [ValidationWarning]
    
    public var hasErrors: Bool { !errors.isEmpty }
    public var hasWarnings: Bool { !warnings.isEmpty }
}

// MARK: - 验证错误类型
public struct ValidationError {
    public let category: ValidationCategory
    public let message: String
    public let suggestion: String?
    
    public init(category: ValidationCategory, message: String, suggestion: String? = nil) {
        self.category = category
        self.message = message
        self.suggestion = suggestion
    }
}

// MARK: - 验证警告类型
public struct ValidationWarning {
    public let category: ValidationCategory
    public let message: String
    public let impact: WarningImpact
    
    public init(category: ValidationCategory, message: String, impact: WarningImpact) {
        self.category = category
        self.message = message
        self.impact = impact
    }
}

// MARK: - 验证分类
public enum ValidationCategory: String, CaseIterable {
    case api = "API配置"
    case audio = "音频配置"
    case system = "系统要求"
    case permissions = "权限配置"
    case performance = "性能配置"
    case security = "安全配置"
}

// MARK: - 警告影响级别
public enum WarningImpact: String, CaseIterable {
    case low = "低"
    case medium = "中"
    case high = "高"
    
    var color: String {
        switch self {
        case .low: return "yellow"
        case .medium: return "orange"
        case .high: return "red"
        }
    }
}

// MARK: - 配置验证器主类
@MainActor
public final class ConfigurationValidator: ObservableObject {
    
    // MARK: - 单例
    public static let shared = ConfigurationValidator()
    
    // MARK: - 发布属性
    @Published public var lastValidationResult: ValidationResult?
    @Published public var isValidating = false
    
    // MARK: - 私有属性
    private let configManager = AppConfigManager.shared
    private let permissionManager = PermissionManager.shared
    private let memoryManager = MemoryManager.shared
    
    // MARK: - 初始化
    private init() {
        LogManager.shared.info("ConfigurationValidator", "配置验证器初始化完成")
    }
    
    // MARK: - 主要验证方法
    
    /// 执行完整的配置验证
    public func validateAllConfigurations() async -> ValidationResult {
        isValidating = true
        defer { isValidating = false }
        
        LogManager.shared.info("ConfigurationValidator", "开始完整配置验证")
        
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        // 1. API配置验证
        let apiResults = await validateAPIConfiguration()
        errors.append(contentsOf: apiResults.errors)
        warnings.append(contentsOf: apiResults.warnings)
        
        // 2. 音频配置验证
        let audioResults = await validateAudioConfiguration()
        errors.append(contentsOf: audioResults.errors)
        warnings.append(contentsOf: audioResults.warnings)
        
        // 3. 系统要求验证
        let systemResults = validateSystemRequirements()
        errors.append(contentsOf: systemResults.errors)
        warnings.append(contentsOf: systemResults.warnings)
        
        // 4. 权限配置验证
        let permissionResults = await validatePermissions()
        errors.append(contentsOf: permissionResults.errors)
        warnings.append(contentsOf: permissionResults.warnings)
        
        // 5. 性能配置验证
        let performanceResults = validatePerformanceConfiguration()
        errors.append(contentsOf: performanceResults.errors)
        warnings.append(contentsOf: performanceResults.warnings)
        
        // 6. 安全配置验证
        let securityResults = validateSecurityConfiguration()
        errors.append(contentsOf: securityResults.errors)
        warnings.append(contentsOf: securityResults.warnings)
        
        let result = ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
        
        lastValidationResult = result
        
        LogManager.shared.info("ConfigurationValidator", """
            配置验证完成 - 
            有效: \(result.isValid)
            错误: \(errors.count)
            警告: \(warnings.count)
            """)
        
        return result
    }
    
    // MARK: - 具体验证方法
    
    /// 验证API配置
    private func validateAPIConfiguration() async -> (errors: [ValidationError], warnings: [ValidationWarning]) {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        // 检查API密钥
        let apiKey = (try? configManager.getOpenAIAPIKey()) ?? ""
        if apiKey.isEmpty {
            errors.append(ValidationError(
                category: .api,
                message: "OpenAI API密钥未配置",
                suggestion: "请在设置中配置有效的OpenAI API密钥"
            ))
        } else if !isValidAPIKey(apiKey) {
            errors.append(ValidationError(
                category: .api,
                message: "OpenAI API密钥格式不正确",
                suggestion: "API密钥应以'sk-'开头且长度大于50字符"
            ))
        }
        
        // 检查Base URL
        let baseURL = configManager.openAIBaseURL
        if !isValidURL(baseURL) {
            warnings.append(ValidationWarning(
                category: .api,
                message: "Base URL格式可能不正确: \(baseURL)",
                impact: .medium
            ))
        }
        
        // 检查模型配置
        let model = configManager.openAIModel
        if !isSupportedModel(model) {
            warnings.append(ValidationWarning(
                category: .api,
                message: "使用的模型'\(model)'可能不被完全支持",
                impact: .low
            ))
        }
        
        // 检查网络连接
        if apiKey.isNotEmpty {
            let networkResult = await testNetworkConnectivity()
            if !networkResult {
                warnings.append(ValidationWarning(
                    category: .api,
                    message: "无法连接到OpenAI API服务",
                    impact: .high
                ))
            }
        }
        
        return (errors, warnings)
    }
    
    /// 验证音频配置
    private func validateAudioConfiguration() async -> (errors: [ValidationError], warnings: [ValidationWarning]) {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        // 检查音频设备
        let audioSession = AVAudioSession.sharedInstance()
        
        // 检查输入设备
        guard let currentRoute = audioSession.currentRoute.inputs.first else {
            errors.append(ValidationError(
                category: .audio,
                message: "未检测到音频输入设备",
                suggestion: "请确保麦克风已连接并正常工作"
            ))
            return (errors, warnings)
        }
        
        // 检查采样率支持
        let supportedSampleRates = [16000.0, 44100.0, 48000.0]
        let currentSampleRate = audioSession.sampleRate
        
        if !supportedSampleRates.contains(currentSampleRate) {
            warnings.append(ValidationWarning(
                category: .audio,
                message: "当前采样率\(currentSampleRate)Hz可能不是最优选择",
                impact: .medium
            ))
        }
        
        // 检查音频格式
        let channelCount = audioSession.inputNumberOfChannels
        if channelCount > 1 {
            warnings.append(ValidationWarning(
                category: .audio,
                message: "检测到多声道输入，将转换为单声道",
                impact: .low
            ))
        }
        
        return (errors, warnings)
    }
    
    /// 验证系统要求
    private func validateSystemRequirements() -> (errors: [ValidationError], warnings: [ValidationWarning]) {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        let processInfo = ProcessInfo.processInfo
        
        // 检查macOS版本
        let osVersion = processInfo.operatingSystemVersion
        let minimumVersion = OperatingSystemVersion(majorVersion: 13, minorVersion: 0, patchVersion: 0)
        
        if !processInfo.isOperatingSystemAtLeast(minimumVersion) {
            errors.append(ValidationError(
                category: .system,
                message: "macOS版本过低，当前版本: \(osVersion.majorVersion).\(osVersion.minorVersion)",
                suggestion: "请升级到macOS 13.0或更高版本"
            ))
        }
        
        // 检查内存
        let physicalMemory = processInfo.physicalMemory
        let memoryGB = Double(physicalMemory) / (1024 * 1024 * 1024)
        
        if memoryGB < 4.0 {
            warnings.append(ValidationWarning(
                category: .system,
                message: "可用内存较少: \(String(format: "%.1f", memoryGB))GB",
                impact: .medium
            ))
        }
        
        // 检查磁盘空间
        if let diskSpace = getAvailableDiskSpace() {
            let diskSpaceGB = Double(diskSpace) / (1024 * 1024 * 1024)
            if diskSpaceGB < 1.0 {
                warnings.append(ValidationWarning(
                    category: .system,
                    message: "可用磁盘空间不足: \(String(format: "%.1f", diskSpaceGB))GB",
                    impact: .high
                ))
            }
        }
        
        return (errors, warnings)
    }
    
    /// 验证权限配置
    private func validatePermissions() async -> (errors: [ValidationError], warnings: [ValidationWarning]) {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        // 检查麦克风权限
        let microphoneStatus = await permissionManager.checkMicrophonePermission()
        if !microphoneStatus {
            errors.append(ValidationError(
                category: .permissions,
                message: "缺少麦克风权限",
                suggestion: "请在系统偏好设置中授予麦克风访问权限"
            ))
        }
        
        // 检查辅助功能权限
        let accessibilityStatus = permissionManager.checkAccessibilityPermission()
        if !accessibilityStatus {
            warnings.append(ValidationWarning(
                category: .permissions,
                message: "缺少辅助功能权限，文本插入功能可能受限",
                impact: .high
            ))
        }
        
        // 检查通知权限
        let notificationStatus = await permissionManager.checkNotificationPermission()
        if !notificationStatus {
            warnings.append(ValidationWarning(
                category: .permissions,
                message: "缺少通知权限，无法显示系统通知",
                impact: .low
            ))
        }
        
        return (errors, warnings)
    }
    
    /// 验证性能配置
    private func validatePerformanceConfiguration() -> (errors: [ValidationError], warnings: [ValidationWarning]) {
        let errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        // 检查内存使用情况
        let memoryStats = memoryManager.getMemoryStats()
        if let currentUsageStr = memoryStats["currentUsageMB"] as? String,
           let currentUsage = Double(currentUsageStr),
           currentUsage > 500 {
            warnings.append(ValidationWarning(
                category: .performance,
                message: "当前内存使用较高: \(currentUsageStr)MB",
                impact: .medium
            ))
        }
        
        // 检查音频缓冲区设置
        let audioBufferStats = AudioBufferPool.shared.getMemoryUsage()
        if audioBufferStats.totalBuffers > 50 {
            warnings.append(ValidationWarning(
                category: .performance,
                message: "音频缓冲区数量较多: \(audioBufferStats.totalBuffers)个",
                impact: .low
            ))
        }
        
        return (errors, warnings)
    }
    
    /// 验证安全配置
    private func validateSecurityConfiguration() -> (errors: [ValidationError], warnings: [ValidationWarning]) {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        // 检查Keychain访问
        let keychainStatus = testKeychainAccess()
        if !keychainStatus {
            errors.append(ValidationError(
                category: .security,
                message: "无法访问Keychain存储",
                suggestion: "请检查应用权限和Keychain服务状态"
            ))
        }
        
        // 检查网络安全
        let baseURL = configManager.openAIBaseURL
        if !baseURL.hasPrefix("https://") {
            warnings.append(ValidationWarning(
                category: .security,
                message: "API基础URL未使用HTTPS协议",
                impact: .high
            ))
        }
        
        // 检查日志安全
        let logLevel = LogManager.shared.currentLogLevel
        if logLevel == .debug {
            warnings.append(ValidationWarning(
                category: .security,
                message: "当前使用调试日志级别，可能记录敏感信息",
                impact: .medium
            ))
        }
        
        return (errors, warnings)
    }
    
    // MARK: - 辅助验证方法
    
    private func isValidAPIKey(_ key: String) -> Bool {
        return key.hasPrefix("sk-") && key.count >= 51
    }
    
    private func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme != nil && url.host != nil
    }
    
    private func isSupportedModel(_ model: String) -> Bool {
        let supportedModels = ["gpt-4o-mini", "gpt-4o", "gpt-4-turbo", "gpt-4", "gpt-3.5-turbo"]
        return supportedModels.contains(model)
    }
    
    private func testNetworkConnectivity() async -> Bool {
        // 简单的连通性测试
        guard let url = URL(string: configManager.openAIBaseURL) else { return false }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    private func getAvailableDiskSpace() -> UInt64? {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        do {
            let values = try homeURL.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            return values.volumeAvailableCapacity.map(UInt64.init)
        } catch {
            return nil
        }
    }
    
    private func testKeychainAccess() -> Bool {
        // 测试Keychain读写访问
        let testKey = "HelloPrompt_ConfigTest"
        let testValue = "test_value"
        
        // 尝试写入
        let writeStatus = SecKeychainAddGenericPassword(
            nil,
            UInt32(testKey.count), testKey,
            UInt32(testKey.count), testKey,
            UInt32(testValue.count), testValue,
            nil
        )
        
        // 清理测试数据
        SecKeychainFindGenericPassword(
            nil,
            UInt32(testKey.count), testKey,
            UInt32(testKey.count), testKey,
            nil, nil, nil
        )
        
        return writeStatus == errSecSuccess || writeStatus == errSecDuplicateItem
    }
    
    // MARK: - 验证报告
    
    /// 生成验证报告
    public func generateValidationReport() -> String {
        guard let result = lastValidationResult else {
            return "尚未执行配置验证"
        }
        
        var report = "# Hello Prompt v2 配置验证报告\n\n"
        
        // 总体状态
        report += "## 总体状态\n"
        report += "- **验证状态**: \(result.isValid ? "✅ 通过" : "❌ 失败")\n"
        report += "- **错误数量**: \(result.errors.count)\n"
        report += "- **警告数量**: \(result.warnings.count)\n\n"
        
        // 错误详情
        if !result.errors.isEmpty {
            report += "## 🚨 错误详情\n\n"
            for error in result.errors {
                report += "### \(error.category.rawValue)\n"
                report += "- **问题**: \(error.message)\n"
                if let suggestion = error.suggestion {
                    report += "- **建议**: \(suggestion)\n"
                }
                report += "\n"
            }
        }
        
        // 警告详情
        if !result.warnings.isEmpty {
            report += "## ⚠️ 警告详情\n\n"
            for warning in result.warnings {
                let impactIcon = warning.impact == .high ? "🔴" : 
                                warning.impact == .medium ? "🟡" : "🟢"
                report += "### \(warning.category.rawValue) \(impactIcon)\n"
                report += "- **问题**: \(warning.message)\n"
                report += "- **影响级别**: \(warning.impact.rawValue)\n\n"
            }
        }
        
        // 验证建议
        if result.isValid && result.warnings.isEmpty {
            report += "## 🎉 验证通过\n\n"
            report += "所有配置验证通过，应用已准备就绪！\n"
        } else {
            report += "## 📋 下一步行动\n\n"
            if !result.errors.isEmpty {
                report += "1. **必须修复错误**: 请优先解决所有错误项目\n"
            }
            if !result.warnings.isEmpty {
                report += "2. **建议处理警告**: 特别是高影响级别的警告\n"
            }
        }
        
        return report
    }
}

// MARK: - String扩展
extension String {
    var isNotEmpty: Bool {
        return !isEmpty
    }
}