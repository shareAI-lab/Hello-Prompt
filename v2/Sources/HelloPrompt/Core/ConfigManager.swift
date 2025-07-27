//
//  ConfigManager.swift
//  HelloPrompt
//
//  Hello Prompt - 极简的macOS语音到AI提示词转换工具
//  专业配置管理 + 安全存储 + API配置
//

import Foundation
import Security
import Defaults
import OpenAI
import KeyboardShortcuts
import Combine

// MARK: - Configuration Keys Extension
extension Defaults.Keys {
    // API 配置
    static let openAIBaseURL = Key<String>("openAIBaseURL", default: "https://api.openai.com")
    static let openAIOrganization = Key<String?>("openAIOrganization", default: nil)
    static let openAIModel = Key<String>("openAIModel", default: "gpt-4-turbo-preview")
    static let maxTokens = Key<Int>("maxTokens", default: 2048)
    static let temperature = Key<Double>("temperature", default: 0.7)
    static let systemPrompt = Key<String>("systemPrompt", default: "You are a helpful AI assistant that processes voice input and provides clear, concise responses.")
    
    // 用户界面设置
    static let windowAlwaysOnTop = Key<Bool>("windowAlwaysOnTop", default: false)
    static let showMenuBarIcon = Key<Bool>("showMenuBarIcon", default: true)
    static let launchAtLogin = Key<Bool>("launchAtLogin", default: false)
    static let showWelcomeScreen = Key<Bool>("showWelcomeScreen", default: true)
    static let showInDock = Key<Bool>("showInDock", default: true)
    static let enableMenuBarIcon = Key<Bool>("enableMenuBarIcon", default: true)
    static let enableNotifications = Key<Bool>("enableNotifications", default: true)
    static let enableHapticFeedback = Key<Bool>("enableHapticFeedback", default: true)
    static let enableAutoUpdates = Key<Bool>("enableAutoUpdates", default: true)
    
    // 音频设置
    static let audioInputDevice = Key<String?>("audioInputDevice", default: nil)
    static let audioSampleRate = Key<Double>("audioSampleRate", default: 44100)
    static let audioChannels = Key<Int>("audioChannels", default: 1)
    static let noiseReduction = Key<Bool>("noiseReduction", default: true)
    static let autoGainControl = Key<Bool>("autoGainControl", default: true)
    static let audioSilenceThreshold = Key<Float>("audioSilenceThreshold", default: 0.01)
    static let audioSilenceTimeout = Key<Double>("audioSilenceTimeout", default: 0.5)
    static let audioMaxRecordingTime = Key<Double>("audioMaxRecordingTime", default: 300.0)
    static let enableAudioEnhancement = Key<Bool>("enableAudioEnhancement", default: true)
    static let enableVAD = Key<Bool>("enableVAD", default: true)
    
    // 快捷键设置 - 存储为字符串，避免序列化问题
    static let recordingShortcutName = Key<String?>("recordingShortcutName", default: "recordingShortcut")
    static let stopRecordingShortcutName = Key<String?>("stopRecordingShortcutName", default: "stopRecordingShortcut")
    static let toggleWindowShortcutName = Key<String?>("toggleWindowShortcutName", default: "toggleWindowShortcut")
    
    // 高级设置
    static let enableLogging = Key<Bool>("enableLogging", default: true)
    static let logLevel = Key<String>("logLevel", default: "info")
    static let configVersion = Key<String>("configVersion", default: "1.0.0")
    static let cacheSize = Key<Int>("cacheSize", default: 100)
    static let requestTimeout = Key<Double>("requestTimeout", default: 30.0)
    static let enableDebugMode = Key<Bool>("enableDebugMode", default: false)
}

// MARK: - KeychainService
/// 安全的Keychain存储服务
class KeychainService {
    private let service = "com.shareai-lab.hello-prompt"
    
    enum KeychainError: LocalizedError {
        case itemNotFound
        case duplicateItem
        case invalidData
        case unexpectedStatus(OSStatus)
        
        var errorDescription: String? {
            switch self {
            case .itemNotFound:
                return "Keychain item not found"
            case .duplicateItem:
                return "Duplicate keychain item"
            case .invalidData:
                return "Invalid keychain data"
            case .unexpectedStatus(let status):
                return "Keychain error: \(status)"
            }
        }
    }
    
    /// 保存字符串到Keychain
    func save(_ value: String, for key: String) throws {
        // 加强数据完整性验证
        let data = value.data(using: .utf8) ?? Data()
        
        // 验证编码是否成功
        guard String(data: data, encoding: .utf8) == value else {
            throw KeychainError.invalidData
        }
        
        // 验证数据不为空
        guard !data.isEmpty else {
            throw KeychainError.invalidData
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // 删除已存在的项目
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    /// 从Keychain读取字符串
    func load(for key: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }
        
        guard let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        
        return value
    }
    
    /// 删除Keychain项目
    func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    /// 检查Keychain项目是否存在
    func exists(for key: String) -> Bool {
        do {
            _ = try load(for: key)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - AppConfigManager
/// 应用配置管理器 - 负责应用程序的所有配置管理
@MainActor
public class AppConfigManager: ObservableObject {
    public static let shared = AppConfigManager()
    
    private let keychain = KeychainService()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Keychain Keys
    private enum KeychainKeys {
        static let openAIAPIKey = "openai_api_key"
        static let customAPIKey = "custom_api_key"
        static let encryptionKey = "app_encryption_key"
    }
    
    // MARK: - Published Properties
    @Published var isConfigured = false
    @Published var apiConnectionStatus: APIConnectionStatus = .unknown
    @Published var configurationValid = false
    
    // MARK: - API Connection Status
    enum APIConnectionStatus {
        case unknown
        case connecting
        case connected
        case failed(Error)
        
        var isConnected: Bool {
            switch self {
            case .connected:
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        setupDefaultShortcuts()
        validateConfiguration()
        observeConfigurationChanges()
    }
    
    // MARK: - API Key Management
    
    /// 设置OpenAI API密钥
    func setOpenAIAPIKey(_ apiKey: String) throws {
        // 增强验证
        guard !apiKey.isEmpty && apiKey.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10 else {
            throw ConfigurationError.invalidAPIKey
        }
        
        let cleanedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 日志记录（不显示完整密钥）
        print("[ConfigManager] 设置API Key: \(cleanedAPIKey.prefix(8))...\(cleanedAPIKey.suffix(4))")
        
        try keychain.save(cleanedAPIKey, for: KeychainKeys.openAIAPIKey)
        
        // 立即更新OpenAI服务配置
        Task {
            AppManager.shared.openAIService.configureFromSettings()
        }
        
        validateConfiguration()
    }
    
    /// 获取OpenAI API密钥
    func getOpenAIAPIKey() throws -> String? {
        do {
            let apiKey = try keychain.load(for: KeychainKeys.openAIAPIKey)
            
            // 添加详细日志
            if !apiKey.isEmpty {
                print("[ConfigManager] API Key读取成功: 长度=\(apiKey.count), 前缀=\(apiKey.prefix(8))...")
            } else {
                print("[ConfigManager] 警告：API Key为空")
            }
            
            return apiKey
        } catch KeychainService.KeychainError.itemNotFound {
            print("[ConfigManager] API Key未找到")
            return nil
        } catch {
            print("[ConfigManager] API Key读取失败: \(error)")
            throw error
        }
    }
    
    /// 设置自定义API密钥
    func setCustomAPIKey(_ apiKey: String) throws {
        guard !apiKey.isEmpty else {
            throw ConfigurationError.invalidAPIKey
        }
        
        try keychain.save(apiKey, for: KeychainKeys.customAPIKey)
        validateConfiguration()
    }
    
    /// 获取自定义API密钥
    func getCustomAPIKey() -> String? {
        do {
            return try keychain.load(for: KeychainKeys.customAPIKey)
        } catch {
            return nil
        }
    }
    
    /// 删除API密钥
    func deleteAPIKey(type: APIKeyType) throws {
        let key = type == .openAI ? KeychainKeys.openAIAPIKey : KeychainKeys.customAPIKey
        try keychain.delete(for: key)
        validateConfiguration()
    }
    
    enum APIKeyType {
        case openAI
        case custom
    }
    
    // MARK: - Configuration Properties
    
    /// OpenAI基础URL
    var openAIBaseURL: String {
        get { Defaults[.openAIBaseURL] }
        set { Defaults[.openAIBaseURL] = newValue }
    }
    
    /// OpenAI组织ID
    var openAIOrganization: String? {
        get { Defaults[.openAIOrganization] }
        set { Defaults[.openAIOrganization] = newValue }
    }
    
    /// OpenAI模型
    var openAIModel: String {
        get { Defaults[.openAIModel] }
        set { Defaults[.openAIModel] = newValue }
    }
    
    /// 最大Token数
    var maxTokens: Int {
        get { Defaults[.maxTokens] }
        set { Defaults[.maxTokens] = newValue }
    }
    
    /// 温度参数
    var temperature: Double {
        get { Defaults[.temperature] }
        set { Defaults[.temperature] = newValue }
    }
    
    /// 系统提示词
    var systemPrompt: String {
        get { Defaults[.systemPrompt] }
        set { Defaults[.systemPrompt] = newValue }
    }
    
    /// 窗口总是置顶
    var windowAlwaysOnTop: Bool {
        get { Defaults[.windowAlwaysOnTop] }
        set { Defaults[.windowAlwaysOnTop] = newValue }
    }
    
    /// 显示菜单栏图标
    var showMenuBarIcon: Bool {
        get { Defaults[.showMenuBarIcon] }
        set { Defaults[.showMenuBarIcon] = newValue }
    }
    
    /// 开机启动
    var launchAtLogin: Bool {
        get { Defaults[.launchAtLogin] }
        set { Defaults[.launchAtLogin] = newValue }
    }
    
    /// 显示欢迎屏幕
    var showWelcomeScreen: Bool {
        get { Defaults[.showWelcomeScreen] }
        set { Defaults[.showWelcomeScreen] = newValue }
    }
    
    /// 音频设备
    var audioInputDevice: String? {
        get { Defaults[.audioInputDevice] }
        set { Defaults[.audioInputDevice] = newValue }
    }
    
    /// 音频采样率
    var audioSampleRate: Double {
        get { Defaults[.audioSampleRate] }
        set { Defaults[.audioSampleRate] = newValue }
    }
    
    /// 音频声道数
    var audioChannels: Int {
        get { Defaults[.audioChannels] }
        set { Defaults[.audioChannels] = newValue }
    }
    
    /// 噪声抑制
    var noiseReduction: Bool {
        get { Defaults[.noiseReduction] }
        set { Defaults[.noiseReduction] = newValue }
    }
    
    /// 自动增益控制
    var autoGainControl: Bool {
        get { Defaults[.autoGainControl] }
        set { Defaults[.autoGainControl] = newValue }
    }
    
    /// 启用日志
    var enableLogging: Bool {
        get { Defaults[.enableLogging] }
        set { Defaults[.enableLogging] = newValue }
    }
    
    /// 日志级别
    var logLevel: String {
        get { Defaults[.logLevel] }
        set { Defaults[.logLevel] = newValue }
    }
    
    /// 缓存大小
    var cacheSize: Int {
        get { Defaults[.cacheSize] }
        set { Defaults[.cacheSize] = newValue }
    }
    
    /// 请求超时时间
    var requestTimeout: TimeInterval {
        get { Defaults[.requestTimeout] }
        set { Defaults[.requestTimeout] = newValue }
    }
    
    /// 调试模式
    var enableDebugMode: Bool {
        get { Defaults[.enableDebugMode] }
        set { Defaults[.enableDebugMode] = newValue }
    }
    
    /// 音频静音阈值
    var audioSilenceThreshold: Float {
        get { Defaults[.audioSilenceThreshold] }
        set { Defaults[.audioSilenceThreshold] = newValue }
    }
    
    /// 音频静音超时时间
    var audioSilenceTimeout: TimeInterval {
        get { Defaults[.audioSilenceTimeout] }
        set { Defaults[.audioSilenceTimeout] = newValue }
    }
    
    /// 最大录音时间
    var audioMaxRecordingTime: TimeInterval {
        get { Defaults[.audioMaxRecordingTime] }
        set { Defaults[.audioMaxRecordingTime] = newValue }
    }
    
    /// 启用音频增强
    var enableAudioEnhancement: Bool {
        get { Defaults[.enableAudioEnhancement] }
        set { Defaults[.enableAudioEnhancement] = newValue }
    }
    
    /// 启用语音活动检测
    var enableVAD: Bool {
        get { Defaults[.enableVAD] }
        set { Defaults[.enableVAD] = newValue }
    }
    
    /// 在Dock中显示
    var showInDock: Bool {
        get { Defaults[.showInDock] }
        set { Defaults[.showInDock] = newValue }
    }
    
    /// 启用菜单栏图标
    var enableMenuBarIcon: Bool {
        get { Defaults[.enableMenuBarIcon] }
        set { Defaults[.enableMenuBarIcon] = newValue }
    }
    
    /// 启用通知
    var enableNotifications: Bool {
        get { Defaults[.enableNotifications] }
        set { Defaults[.enableNotifications] = newValue }
    }
    
    /// 启用触觉反馈
    var enableHapticFeedback: Bool {
        get { Defaults[.enableHapticFeedback] }
        set { Defaults[.enableHapticFeedback] = newValue }
    }
    
    /// 启用自动更新
    var enableAutoUpdates: Bool {
        get { Defaults[.enableAutoUpdates] }
        set { Defaults[.enableAutoUpdates] = newValue }
    }
    
    // MARK: - Configuration Validation
    
    enum ConfigurationError: LocalizedError {
        case invalidAPIKey
        case invalidBaseURL
        case missingConfiguration
        case connectionFailed
        
        var errorDescription: String? {
            switch self {
            case .invalidAPIKey:
                return "Invalid API key provided"
            case .invalidBaseURL:
                return "Invalid base URL"
            case .missingConfiguration:
                return "Missing required configuration"
            case .connectionFailed:
                return "Failed to connect to API"
            }
        }
    }
    
    /// 验证配置有效性
    private func validateConfiguration() {
        do {
            let apiKey = try getOpenAIAPIKey()
            let hasValidAPIKey = apiKey != nil && !apiKey!.isEmpty && apiKey!.count >= 10
            let hasValidURL = URL(string: openAIBaseURL) != nil
            
            configurationValid = hasValidAPIKey && hasValidURL
            isConfigured = configurationValid
            
            print("[ConfigManager] 配置验证结果: API Key=\(hasValidAPIKey), URL=\(hasValidURL), 整体=\(configurationValid)")
        } catch {
            print("[ConfigManager] 配置验证失败: \(error)")
            configurationValid = false
            isConfigured = false
        }
    }
    
    /// 实时验证API Key格式
    public func validateAPIKeyFormat(_ apiKey: String) -> Bool {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 放宽验证条件，支持更多API Key格式
        let isValidLength = trimmedKey.count >= 10 && trimmedKey.count <= 200
        let containsNoSpaces = !trimmedKey.contains(" ")
        let containsNoNewlines = !trimmedKey.contains("\n")
        let isNotEmpty = !trimmedKey.isEmpty
        
        return isValidLength && containsNoSpaces && containsNoNewlines && isNotEmpty
    }
    
    /// 测试API连接
    func testAPIConnection() async -> Result<Bool, Error> {
        guard let apiKey = (try? getOpenAIAPIKey()) ?? getCustomAPIKey() else {
            print("[ConfigManager] API连接测试失败：API Key不存在")
            return .failure(ConfigurationError.invalidAPIKey)
        }
        
        // 验证API Key格式
        guard validateAPIKeyFormat(apiKey) else {
            print("[ConfigManager] API连接测试失败：API Key格式无效")
            return .failure(ConfigurationError.invalidAPIKey)
        }
        
        guard let baseURL = URL(string: openAIBaseURL) else {
            print("[ConfigManager] API连接测试失败：Base URL无效")
            return .failure(ConfigurationError.invalidBaseURL)
        }
        
        await MainActor.run {
            self.apiConnectionStatus = .connecting
        }
        
        print("[ConfigManager] 开始API连接测试")
        print("[ConfigManager] API Key: \(apiKey.prefix(8))...\(apiKey.suffix(4))")
        print("[ConfigManager] Base URL: \(openAIBaseURL)")
        
        do {
            let configuration = OpenAI.Configuration(
                token: apiKey,
                host: baseURL.host ?? "api.openai.com",
                scheme: baseURL.scheme ?? "https",
                timeoutInterval: 10.0
            )
            
            let openAI = OpenAI(configuration: configuration)
            
            // 测试连接 - 获取模型列表
            let models = try await openAI.models()
            print("[ConfigManager] API连接测试成功，可用模型数量: \(models.data.count)")
            
            await MainActor.run {
                self.apiConnectionStatus = .connected
            }
            
            return .success(true)
            
        } catch {
            print("[ConfigManager] API连接测试失败: \(error)")
            
            await MainActor.run {
                self.apiConnectionStatus = .failed(error)
            }
            
            return .failure(error)
        }
    }
    
    /// 强制刷新配置状态
    public func refreshConfiguration() {
        validateConfiguration()
        
        // 通知OpenAI服务更新配置
        Task {
            AppManager.shared.openAIService.configureFromSettings()
        }
    }
    
    // MARK: - Configuration Import/Export
    
    struct ConfigurationExport: Codable {
        let version: String
        let openAIBaseURL: String
        let openAIModel: String
        let maxTokens: Int
        let temperature: Double
        let systemPrompt: String
        let windowAlwaysOnTop: Bool
        let showMenuBarIcon: Bool
        let launchAtLogin: Bool
        let audioSampleRate: Double
        let audioChannels: Int
        let noiseReduction: Bool
        let autoGainControl: Bool
        let enableLogging: Bool
        let logLevel: String
        let exportDate: Date
    }
    
    /// 导出配置
    func exportConfiguration() -> ConfigurationExport {
        return ConfigurationExport(
            version: Defaults[.configVersion],
            openAIBaseURL: openAIBaseURL,
            openAIModel: openAIModel,
            maxTokens: maxTokens,
            temperature: temperature,
            systemPrompt: systemPrompt,
            windowAlwaysOnTop: windowAlwaysOnTop,
            showMenuBarIcon: showMenuBarIcon,
            launchAtLogin: launchAtLogin,
            audioSampleRate: audioSampleRate,
            audioChannels: audioChannels,
            noiseReduction: noiseReduction,
            autoGainControl: autoGainControl,
            enableLogging: enableLogging,
            logLevel: logLevel,
            exportDate: Date()
        )
    }
    
    /// 导入配置
    func importConfiguration(_ config: ConfigurationExport) {
        openAIBaseURL = config.openAIBaseURL
        openAIModel = config.openAIModel
        maxTokens = config.maxTokens
        temperature = config.temperature
        systemPrompt = config.systemPrompt
        windowAlwaysOnTop = config.windowAlwaysOnTop
        showMenuBarIcon = config.showMenuBarIcon
        launchAtLogin = config.launchAtLogin
        audioSampleRate = config.audioSampleRate
        audioChannels = config.audioChannels
        noiseReduction = config.noiseReduction
        autoGainControl = config.autoGainControl
        enableLogging = config.enableLogging
        logLevel = config.logLevel
        
        validateConfiguration()
    }
    
    /// 重置为默认配置
    func resetToDefaults() {
        // 删除所有Keychain存储的密钥
        try? keychain.delete(for: KeychainKeys.openAIAPIKey)
        try? keychain.delete(for: KeychainKeys.customAPIKey)
        
        // 重置所有Defaults
        Defaults.reset(.openAIBaseURL, .openAIModel, .maxTokens, .temperature, .systemPrompt)
        Defaults.reset(.windowAlwaysOnTop, .showMenuBarIcon, .launchAtLogin, .showWelcomeScreen)
        Defaults.reset(.audioInputDevice, .audioSampleRate, .audioChannels, .noiseReduction, .autoGainControl)
        Defaults.reset(.enableLogging, .logLevel)
        
        validateConfiguration()
    }
    
    // MARK: - Private Methods
    
    /// 设置默认快捷键
    private func setupDefaultShortcuts() {
        // 确保快捷键名称已设置
        if Defaults[.recordingShortcutName] == nil {
            Defaults[.recordingShortcutName] = "recordingShortcut"
        }
        
        if Defaults[.stopRecordingShortcutName] == nil {
            Defaults[.stopRecordingShortcutName] = "stopRecordingShortcut"
        }
        
        if Defaults[.toggleWindowShortcutName] == nil {
            Defaults[.toggleWindowShortcutName] = "toggleWindowShortcut"
        }
    }
    
    /// 监听配置变更
    private func observeConfigurationChanges() {
        // 监听所有Defaults变更
        Defaults.publisher(keys: .openAIBaseURL, .openAIModel, .maxTokens, .temperature)
            .sink { [weak self] _ in
                self?.validateConfiguration()
            }
            .store(in: &cancellables)
        
        // 监听UI相关设置变更
        Defaults.publisher(keys: .windowAlwaysOnTop, .showMenuBarIcon, .launchAtLogin)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // 监听音频设置变更
        Defaults.publisher(keys: .audioInputDevice, .audioSampleRate, .audioChannels, .noiseReduction, .autoGainControl)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}

// MARK: - Extensions

extension AppConfigManager {
    /// 获取OpenAI配置
    func getOpenAIConfiguration() -> OpenAI.Configuration? {
        guard let apiKey = (try? getOpenAIAPIKey()) ?? getCustomAPIKey(),
              let baseURL = URL(string: openAIBaseURL) else {
            return nil
        }
        
        return OpenAI.Configuration(
            token: apiKey,
            host: baseURL.host ?? "api.openai.com",
            scheme: baseURL.scheme ?? "https"
        )
    }
    
    /// 获取音频配置
    func getAudioConfiguration() -> AudioConfiguration {
        return AudioConfiguration(
            inputDevice: audioInputDevice,
            sampleRate: audioSampleRate,
            channels: audioChannels,
            noiseReduction: noiseReduction,
            autoGainControl: autoGainControl
        )
    }
}

// MARK: - Supporting Types

struct AudioConfiguration {
    let inputDevice: String?
    let sampleRate: Double
    let channels: Int
    let noiseReduction: Bool
    let autoGainControl: Bool
}

