//
//  ConfigurationManager.swift
//  HelloPrompt
//
//  配置管理系统 - 统一管理用户设置、API配置、快捷键等
//  Copyright © 2025 HelloPrompt. All rights reserved.
//

import Foundation
import Security
import CoreGraphics

// MARK: - 配置项定义
struct AppConfiguration: Codable, Equatable {
    // OpenAI API配置
    var openAIAPIKey: String = ""
    var openAIBaseURL: String = "https://api.openai.com/v1"
    var whisperModel: String = "whisper-1"
    var gptModel: String = "gpt-4o"
    
    // 快捷键配置
    var recordingShortcut: ModernShortcutConfig = ModernShortcutConfig(id: "recording", keyCode: 15, modifiers: [.command, .shift, .option])
    var settingsShortcut: ModernShortcutConfig = ModernShortcutConfig(id: "settings", keyCode: 1, modifiers: [.command, .shift, .option])
    var floatingBallShortcut: ModernShortcutConfig = ModernShortcutConfig(id: "floating_ball", keyCode: 3, modifiers: [.command, .shift, .option])
    var quickOptimizeShortcut: ModernShortcutConfig = ModernShortcutConfig(id: "quick_optimize", keyCode: 32, modifiers: [.command, .shift, .option])
    
    // 音频配置
    var vadThreshold: Float = 0.02
    var vadSilenceDuration: Double = 1.0
    var audioQuality: AudioQuality = .standard
    
    // UI配置
    var floatingBallPosition: CGPoint = CGPoint(x: 100, y: 100)
    var floatingBallAlwaysOnTop: Bool = true
    var showFloatingBallOnStartup: Bool = true
    
    // 系统配置
    var launchAtLogin: Bool = false
    var enableLogging: Bool = true
    var logLevel: ConfigLogLevel = .info
    
    // 首次运行标记
    var isFirstLaunch: Bool = true
    var hasConfiguredAPI: Bool = false
    var hasGrantedPermissions: Bool = false
}

// MARK: - 现代快捷键配置
struct ModernShortcutConfig: Codable, Equatable {
    let id: String
    var keyCode: Int64
    var modifiers: KeyModifiers
    var isEnabled: Bool = true
    
    var name: String {
        switch id {
        case "recording": return "开始录音"
        case "settings": return "显示设置"
        case "floating_ball": return "切换悬浮球"
        case "quick_optimize": return "快速优化"
        default: return "未知功能"
        }
    }
    
    var displayName: String {
        let keyName = KeyCodeHelper.keyName(for: keyCode)
        let modifierSymbols = modifiers.symbols
        return "\(modifierSymbols)\(keyName)"
    }
}

// MARK: - 按键修饰符
struct KeyModifiers: OptionSet, Codable {
    let rawValue: UInt
    
    static let command = KeyModifiers(rawValue: 1 << 0)
    static let shift = KeyModifiers(rawValue: 1 << 1)
    static let option = KeyModifiers(rawValue: 1 << 2)
    static let control = KeyModifiers(rawValue: 1 << 3)
    
    var symbols: String {
        var result = ""
        if contains(.command) { result += "⌘" }
        if contains(.shift) { result += "⇧" }
        if contains(.option) { result += "⌥" }
        if contains(.control) { result += "⌃" }
        return result
    }
    
    var cgEventFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if contains(.command) { flags.insert(.maskCommand) }
        if contains(.shift) { flags.insert(.maskShift) }
        if contains(.option) { flags.insert(.maskAlternate) }
        if contains(.control) { flags.insert(.maskControl) }
        return flags
    }
}

// MARK: - 音频质量枚举
enum AudioQuality: String, CaseIterable, Codable {
    case low = "low"
    case standard = "standard"
    case high = "high"
    
    var sampleRate: Double {
        switch self {
        case .low: return 8000
        case .standard: return 16000
        case .high: return 44100
        }
    }
    
    var displayName: String {
        switch self {
        case .low: return "低质量 (8kHz)"
        case .standard: return "标准质量 (16kHz)"
        case .high: return "高质量 (44kHz)"
        }
    }
}

// MARK: - 配置日志级别枚举
enum ConfigLogLevel: String, CaseIterable, Codable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    
    var displayName: String {
        switch self {
        case .debug: return "调试"
        case .info: return "信息"
        case .warning: return "警告"
        case .error: return "错误"
        }
    }
}

// MARK: - 配置管理器
@MainActor
class ConfigurationManager: ObservableObject {
    static let shared = ConfigurationManager()
    
    @Published var configuration = AppConfiguration()
    
    private let userDefaults = UserDefaults.standard
    private let keychain = KeychainManager.shared
    
    // UserDefaults键名
    private enum Keys {
        static let configuration = "app_configuration"
        static let firstLaunch = "is_first_launch"
        static let hasConfiguredAPI = "has_configured_api"
        static let hasGrantedPermissions = "has_granted_permissions"
    }
    
    // Keychain键名
    private enum KeychainKeys {
        static let openAIAPIKey = "openai_api_key"
    }
    
    private init() {
        loadConfiguration()
        LogManager.shared.info(.app, "配置管理器初始化完成")
    }
    
    // MARK: - 配置加载
    private func loadConfiguration() {
        // 加载基础配置
        if let data = userDefaults.data(forKey: Keys.configuration),
           let decoded = try? JSONDecoder().decode(AppConfiguration.self, from: data) {
            configuration = decoded
        }
        
        // 加载敏感信息
        configuration.openAIAPIKey = keychain.get(key: KeychainKeys.openAIAPIKey) ?? ""
        
        // 加载首次运行标记
        configuration.isFirstLaunch = userDefaults.object(forKey: Keys.firstLaunch) == nil
        configuration.hasConfiguredAPI = userDefaults.bool(forKey: Keys.hasConfiguredAPI)
        configuration.hasGrantedPermissions = userDefaults.bool(forKey: Keys.hasGrantedPermissions)
        
        LogManager.shared.info(.app, "配置加载完成", metadata: [
            "isFirstLaunch": configuration.isFirstLaunch,
            "hasConfiguredAPI": configuration.hasConfiguredAPI,
            "hasGrantedPermissions": configuration.hasGrantedPermissions
        ])
    }
    
    // MARK: - 配置保存
    func saveConfiguration() {
        // 保存基础配置
        if let encoded = try? JSONEncoder().encode(configuration) {
            userDefaults.set(encoded, forKey: Keys.configuration)
        }
        
        // 保存敏感信息
        if !configuration.openAIAPIKey.isEmpty {
            keychain.set(key: KeychainKeys.openAIAPIKey, value: configuration.openAIAPIKey)
        }
        
        // 保存首次运行标记
        userDefaults.set(!configuration.isFirstLaunch, forKey: Keys.firstLaunch)
        userDefaults.set(configuration.hasConfiguredAPI, forKey: Keys.hasConfiguredAPI)
        userDefaults.set(configuration.hasGrantedPermissions, forKey: Keys.hasGrantedPermissions)
        
        LogManager.shared.info(.app, "配置保存完成")
    }
    
    // MARK: - API配置
    func updateAPIConfiguration(apiKey: String, baseURL: String? = nil) {
        configuration.openAIAPIKey = apiKey
        if let baseURL = baseURL {
            configuration.openAIBaseURL = baseURL
        }
        configuration.hasConfiguredAPI = !apiKey.isEmpty
        saveConfiguration()
        
        LogManager.shared.info(.app, "API配置已更新", metadata: [
            "hasAPIKey": !apiKey.isEmpty,
            "baseURL": configuration.openAIBaseURL
        ])
    }
    
    // MARK: - 模型配置
    func updateModelConfiguration(whisperModel: String? = nil, gptModel: String? = nil) {
        if let whisperModel = whisperModel {
            configuration.whisperModel = whisperModel
        }
        if let gptModel = gptModel {
            configuration.gptModel = gptModel
        }
        saveConfiguration()
        
        LogManager.shared.info(.app, "模型配置已更新", metadata: [
            "whisperModel": configuration.whisperModel,
            "gptModel": configuration.gptModel
        ])
    }
    
    // MARK: - 快捷键配置
    func updateShortcut(_ shortcutId: String, keyCode: Int64, modifiers: KeyModifiers) {
        switch shortcutId {
        case "recording":
            configuration.recordingShortcut.keyCode = keyCode
            configuration.recordingShortcut.modifiers = modifiers
        case "settings":
            configuration.settingsShortcut.keyCode = keyCode
            configuration.settingsShortcut.modifiers = modifiers
        case "floating_ball":
            configuration.floatingBallShortcut.keyCode = keyCode
            configuration.floatingBallShortcut.modifiers = modifiers
        case "quick_optimize":
            configuration.quickOptimizeShortcut.keyCode = keyCode
            configuration.quickOptimizeShortcut.modifiers = modifiers
        default:
            LogManager.shared.warning(.app, "未知的快捷键ID", metadata: ["id": shortcutId])
            return
        }
        
        saveConfiguration()
        LogManager.shared.info(.app, "快捷键配置已更新", metadata: [
            "id": shortcutId,
            "keyCode": keyCode,
            "modifiers": modifiers.rawValue
        ])
    }
    
    // MARK: - 首次运行配置
    func completeFirstLaunch() {
        configuration.isFirstLaunch = false
        saveConfiguration()
        LogManager.shared.info(.app, "首次运行配置完成")
    }
    
    func markAPIConfigured() {
        configuration.hasConfiguredAPI = true
        saveConfiguration()
    }
    
    func markPermissionsGranted() {
        configuration.hasGrantedPermissions = true
        saveConfiguration()
    }
    
    // MARK: - 验证配置
    var isValidConfiguration: Bool {
        return !configuration.openAIAPIKey.isEmpty && 
               !configuration.openAIBaseURL.isEmpty &&
               configuration.hasConfiguredAPI
    }
    
    var needsInitialSetup: Bool {
        // 检查是否需要首次设置：API未配置或首次启动
        return configuration.isFirstLaunch || !configuration.hasConfiguredAPI || configuration.openAIAPIKey.isEmpty
    }
    
    // MARK: - 获取所有快捷键
    func getAllShortcuts() -> [ModernShortcutConfig] {
        return [
            configuration.recordingShortcut,
            configuration.settingsShortcut,
            configuration.floatingBallShortcut,
            configuration.quickOptimizeShortcut
        ]
    }
    
    // MARK: - 重置配置
    func resetToDefaults() {
        configuration = AppConfiguration()
        keychain.delete(key: KeychainKeys.openAIAPIKey)
        userDefaults.removeObject(forKey: Keys.configuration)
        userDefaults.removeObject(forKey: Keys.firstLaunch)
        userDefaults.removeObject(forKey: Keys.hasConfiguredAPI)
        userDefaults.removeObject(forKey: Keys.hasGrantedPermissions)
        
        LogManager.shared.info(.app, "配置已重置为默认值")
    }
    
    // MARK: - 配置导入导出
    
    /// 导出配置到文件
    func exportConfiguration(to url: URL) throws {
        // 创建导出配置结构（不包含敏感信息）
        let exportConfig = ExportableConfiguration(
            // API配置 - 不导出API密钥
            openAIBaseURL: configuration.openAIBaseURL,
            whisperModel: configuration.whisperModel,
            gptModel: configuration.gptModel,
            
            // 快捷键配置
            recordingShortcut: configuration.recordingShortcut,
            settingsShortcut: configuration.settingsShortcut,
            floatingBallShortcut: configuration.floatingBallShortcut,
            quickOptimizeShortcut: configuration.quickOptimizeShortcut,
            
            // 音频配置
            vadThreshold: configuration.vadThreshold,
            vadSilenceDuration: configuration.vadSilenceDuration,
            audioQuality: configuration.audioQuality,
            
            // UI配置
            floatingBallAlwaysOnTop: configuration.floatingBallAlwaysOnTop,
            showFloatingBallOnStartup: configuration.showFloatingBallOnStartup,
            
            // 系统配置
            launchAtLogin: configuration.launchAtLogin,
            enableLogging: configuration.enableLogging,
            logLevel: configuration.logLevel,
            
            // 元数据
            exportDate: Date(),
            appVersion: "1.0.0"
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(exportConfig)
        try data.write(to: url)
        
        LogManager.shared.info(.app, "配置导出成功", metadata: [
            "filePath": url.path,
            "fileSize": data.count
        ])
    }
    
    /// 从文件导入配置
    func importConfiguration(from url: URL) throws {
        let data = try Data(contentsOf: url)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let importConfig = try decoder.decode(ExportableConfiguration.self, from: data)
        
        // 验证导入的配置
        try validateImportedConfiguration(importConfig)
        
        // 应用导入的配置（不覆盖敏感信息）
        configuration.openAIBaseURL = importConfig.openAIBaseURL
        configuration.whisperModel = importConfig.whisperModel
        configuration.gptModel = importConfig.gptModel
        
        configuration.recordingShortcut = importConfig.recordingShortcut
        configuration.settingsShortcut = importConfig.settingsShortcut
        configuration.floatingBallShortcut = importConfig.floatingBallShortcut
        configuration.quickOptimizeShortcut = importConfig.quickOptimizeShortcut
        
        configuration.vadThreshold = importConfig.vadThreshold
        configuration.vadSilenceDuration = importConfig.vadSilenceDuration
        configuration.audioQuality = importConfig.audioQuality
        
        configuration.floatingBallAlwaysOnTop = importConfig.floatingBallAlwaysOnTop
        configuration.showFloatingBallOnStartup = importConfig.showFloatingBallOnStartup
        
        configuration.launchAtLogin = importConfig.launchAtLogin
        configuration.enableLogging = importConfig.enableLogging
        configuration.logLevel = importConfig.logLevel
        
        // 保存更新后的配置
        saveConfiguration()
        
        LogManager.shared.info(.app, "配置导入成功", metadata: [
            "filePath": url.path,
            "exportDate": importConfig.exportDate.description,
            "appVersion": importConfig.appVersion
        ])
    }
    
    /// 验证导入的配置
    private func validateImportedConfiguration(_ config: ExportableConfiguration) throws {
        // 验证基本URL格式
        guard URL(string: config.openAIBaseURL) != nil else {
            throw ConfigurationError.invalidBaseURL
        }
        
        // 验证VAD参数范围
        guard config.vadThreshold >= 0.001 && config.vadThreshold <= 0.1 else {
            throw ConfigurationError.invalidVADThreshold
        }
        
        guard config.vadSilenceDuration >= 0.5 && config.vadSilenceDuration <= 5.0 else {
            throw ConfigurationError.invalidSilenceDuration
        }
        
        LogManager.shared.info(.app, "导入配置验证通过")
    }
}

// MARK: - Keychain管理器
@MainActor
class KeychainManager {
    static let shared = KeychainManager()
    
    private let serviceName = "com.helloprompt.app"
    
    private init() {}
    
    func set(key: String, value: String) {
        guard let data = value.data(using: .utf8) else {
            LogManager.shared.error(.app, "无法将字符串转换为UTF-8数据", metadata: [
                "key": key,
                "stringLength": value.count
            ])
            return
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // 删除现有项目
        SecItemDelete(query as CFDictionary)
        
        // 添加新项目
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            LogManager.shared.error(.app, "Keychain存储失败", metadata: [
                "key": key,
                "status": status
            ])
        }
    }
    
    func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        
        return nil
    }
    
    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - 按键代码辅助工具
class KeyCodeHelper {
    static func keyName(for keyCode: Int64) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 49: return "Space"
        case 51: return "Delete"
        case 53: return "Escape"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default: return "Key(\(keyCode))"
        }
    }
}

// MARK: - 可导出配置结构
struct ExportableConfiguration: Codable {
    // API配置（不包含密钥）
    let openAIBaseURL: String
    let whisperModel: String
    let gptModel: String
    
    // 快捷键配置
    let recordingShortcut: ModernShortcutConfig
    let settingsShortcut: ModernShortcutConfig
    let floatingBallShortcut: ModernShortcutConfig
    let quickOptimizeShortcut: ModernShortcutConfig
    
    // 音频配置
    let vadThreshold: Float
    let vadSilenceDuration: Double
    let audioQuality: AudioQuality
    
    // UI配置
    let floatingBallAlwaysOnTop: Bool
    let showFloatingBallOnStartup: Bool
    
    // 系统配置
    let launchAtLogin: Bool
    let enableLogging: Bool
    let logLevel: ConfigLogLevel
    
    // 元数据
    let exportDate: Date
    let appVersion: String
}

// MARK: - 配置错误类型
enum ConfigurationError: LocalizedError {
    case invalidBaseURL
    case invalidVADThreshold
    case invalidSilenceDuration
    case fileNotFound
    case invalidFormat
    case incompatibleVersion
    
    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "无效的API基础URL"
        case .invalidVADThreshold:
            return "VAD阈值超出有效范围(0.001-0.1)"
        case .invalidSilenceDuration:
            return "静音时长超出有效范围(0.5-5.0秒)"
        case .fileNotFound:
            return "配置文件未找到"
        case .invalidFormat:
            return "配置文件格式无效"
        case .incompatibleVersion:
            return "配置文件版本不兼容"
        }
    }
}