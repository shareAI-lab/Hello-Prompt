//
//  ConfigManagerExample.swift
//  HelloPrompt
//
//  Hello Prompt - 极简的macOS语音到AI提示词转换工具
//  ConfigManager使用示例和最佳实践
//

import Foundation
import SwiftUI

// MARK: - ConfigManager使用示例

/// 演示如何在应用程序中使用ConfigManager
@MainActor
class ConfigManagerExample: ObservableObject {
    private let configManager = AppConfigManager.shared
    private let shortcutManager = ShortcutManager.shared
    
    // MARK: - API配置示例
    
    /// 设置OpenAI API配置的示例
    func setupAPIConfiguration() async {
        do {
            // 1. 设置API密钥（安全存储在Keychain中）
            try configManager.setOpenAIAPIKey("sk-your-openai-api-key-here")
            
            // 2. 配置API参数
            configManager.openAIBaseURL = "https://api.openai.com"
            configManager.openAIModel = "gpt-4-turbo-preview"
            configManager.maxTokens = 2048
            configManager.temperature = 0.7
            
            // 3. 设置系统提示词
            configManager.systemPrompt = "You are a helpful AI assistant specialized in processing voice input and converting it to clear, actionable prompts."
            
            // 4. 测试API连接
            let result = await configManager.testAPIConnection()
            switch result {
            case .success(let isConnected):
                print("API连接测试成功: \(isConnected)")
            case .failure(let error):
                print("API连接测试失败: \(error.localizedDescription)")
            }
            
        } catch {
            print("设置API配置失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 用户界面配置示例
    
    /// 配置用户界面设置的示例
    func setupUIConfiguration() {
        // 窗口设置
        configManager.windowAlwaysOnTop = true
        configManager.showMenuBarIcon = true
        configManager.launchAtLogin = false
        
        // 首次使用体验
        configManager.showWelcomeScreen = false
        
        print("界面配置已更新")
    }
    
    // MARK: - 音频配置示例
    
    /// 配置音频设置的示例
    func setupAudioConfiguration() {
        // 音频基础设置
        configManager.audioSampleRate = 44100
        configManager.audioChannels = 1
        
        // 音频处理设置
        configManager.noiseReduction = true
        configManager.autoGainControl = true
        
        // 如果有特定的音频设备，可以设置
        // configManager.audioInputDevice = "Built-in Microphone"
        
        print("音频配置已更新")
        
        // 获取音频配置用于AudioKit
        let audioConfig = configManager.getAudioConfiguration()
        print("当前音频配置: \(audioConfig)")
    }
    
    // MARK: - 快捷键配置示例
    
    /// 配置快捷键的示例
    func setupShortcutConfiguration() {
        // 获取当前快捷键设置
        if let recordingShortcut = shortcutManager.getRecordingShortcut() {
            print("当前录音快捷键: \(recordingShortcut)")
        }
        
        if let stopRecordingShortcut = shortcutManager.getStopRecordingShortcut() {
            print("当前停止录音快捷键: \(stopRecordingShortcut)")
        }
        
        if let toggleWindowShortcut = shortcutManager.getToggleWindowShortcut() {
            print("当前切换窗口快捷键: \(toggleWindowShortcut)")
        }
        
        // 启用所有快捷键
        shortcutManager.enableAllShortcuts()
    }
    
    // MARK: - 配置导入导出示例
    
    /// 导出配置的示例
    func exportConfigurationExample() {
        let exportedConfig = configManager.exportConfiguration()
        
        // 可以将配置保存为JSON文件或传输给其他设备
        do {
            let jsonData = try JSONEncoder().encode(exportedConfig)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            print("导出的配置: \(jsonString)")
            
            // 保存到文件
            let documentsPath = FileManager.default.urls(for: .documentDirectory, 
                                                        in: .userDomainMask).first!
            let configURL = documentsPath.appendingPathComponent("hello-prompt-config.json")
            try jsonData.write(to: configURL)
            print("配置已保存到: \(configURL.path)")
            
        } catch {
            print("导出配置失败: \(error.localizedDescription)")
        }
    }
    
    /// 导入配置的示例
    func importConfigurationExample() {
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, 
                                                        in: .userDomainMask).first!
            let configURL = documentsPath.appendingPathComponent("hello-prompt-config.json")
            
            let jsonData = try Data(contentsOf: configURL)
            let importedConfig = try JSONDecoder().decode(AppConfigManager.ConfigurationExport.self, 
                                                         from: jsonData)
            
            configManager.importConfiguration(importedConfig)
            print("配置导入成功")
            
        } catch {
            print("导入配置失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 配置重置示例
    
    /// 重置配置的示例
    func resetConfigurationExample() {
        // 重置所有配置到默认值
        configManager.resetToDefaults()
        
        // 重置快捷键
        shortcutManager.resetToDefaults()
        
        print("所有配置已重置为默认值")
    }
    
    // MARK: - 配置监听示例
    
    /// 监听配置变更的示例
    func observeConfigurationChanges() {
        // ConfigManager已经实现了配置变更的自动监听
        // 当配置发生变化时，会自动更新相关的UI和状态
        
        print("配置监听已启用")
        print("当前配置状态:")
        print("- 已配置: \(configManager.isConfigured)")
        print("- 配置有效: \(configManager.configurationValid)")
        print("- API连接状态: \(configManager.apiConnectionStatus)")
    }
}

// MARK: - SwiftUI集成示例

/// 演示如何在SwiftUI视图中使用ConfigManager
struct ConfigurationView: View {
    @StateObject private var configManager = AppConfigManager.shared
    @State private var apiKey = ""
    @State private var baseURL = ""
    @State private var model = ""
    
    var body: some View {
        Form {
            Section("API设置") {
                SecureField("API密钥", text: $apiKey)
                    .onSubmit {
                        Task {
                            try? configManager.setOpenAIAPIKey(apiKey)
                        }
                    }
                
                TextField("Base URL", text: $baseURL)
                    .onSubmit {
                        configManager.openAIBaseURL = baseURL
                    }
                
                TextField("模型", text: $model)
                    .onSubmit {
                        configManager.openAIModel = model
                    }
                
                Button("测试连接") {
                    Task {
                        let _ = await configManager.testAPIConnection()
                    }
                }
                .disabled(!configManager.configurationValid)
            }
            
            Section("界面设置") {
                Toggle("窗口总是置顶", isOn: Binding(
                    get: { configManager.windowAlwaysOnTop },
                    set: { configManager.windowAlwaysOnTop = $0 }
                ))
                
                Toggle("显示菜单栏图标", isOn: Binding(
                    get: { configManager.showMenuBarIcon },
                    set: { configManager.showMenuBarIcon = $0 }
                ))
                
                Toggle("开机启动", isOn: Binding(
                    get: { configManager.launchAtLogin },
                    set: { configManager.launchAtLogin = $0 }
                ))
            }
            
            Section("状态") {
                HStack {
                    Text("配置状态:")
                    Spacer()
                    Text(configManager.isConfigured ? "已配置" : "未配置")
                        .foregroundColor(configManager.isConfigured ? .green : .red)
                }
                
                HStack {
                    Text("API连接:")
                    Spacer()
                    Text(connectionStatusText)
                        .foregroundColor(connectionStatusColor)
                }
            }
        }
        .onAppear {
            loadCurrentConfiguration()
        }
    }
    
    private var connectionStatusText: String {
        switch configManager.apiConnectionStatus {
        case .unknown:
            return "未知"
        case .connecting:
            return "连接中..."
        case .connected:
            return "已连接"
        case .failed(_):
            return "连接失败"
        }
    }
    
    private var connectionStatusColor: Color {
        switch configManager.apiConnectionStatus {
        case .unknown:
            return .gray
        case .connecting:
            return .blue
        case .connected:
            return .green
        case .failed(_):
            return .red
        }
    }
    
    private func loadCurrentConfiguration() {
        apiKey = (try? configManager.getOpenAIAPIKey()) ?? ""
        baseURL = configManager.openAIBaseURL
        model = configManager.openAIModel
    }
}

// MARK: - 最佳实践说明

/*
 ConfigManager使用最佳实践:
 
 1. 安全性:
    - API密钥等敏感信息自动存储在Keychain中
    - 配置文件导出时不包含敏感信息
    - 使用安全的默认配置
 
 2. 性能:
    - 配置读取使用缓存，访问高效
    - 配置变更通知机制，避免轮询
    - 异步API连接测试，不阻塞UI
 
 3. 用户体验:
    - 配置验证和错误提示
    - 支持配置导入导出和备份
    - 快捷键管理集成
 
 4. 代码组织:
    - 单例模式，全局访问方便
    - ObservableObject，与SwiftUI完美集成
    - 类型安全的配置项定义
 
 5. 错误处理:
    - 所有配置操作都有适当的错误处理
    - 网络连接测试包含超时和重试机制
    - 配置迁移和兼容性处理
 */