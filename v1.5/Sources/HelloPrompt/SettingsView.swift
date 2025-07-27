//
//  SettingsView.swift
//  HelloPrompt
//
//  SwiftUI设置界面 - 用户配置管理界面
//  Copyright © 2025 HelloPrompt. All rights reserved.
//

import SwiftUI
import AppKit

// MARK: - 主设置视图
struct SettingsView: View {
    @StateObject private var configManager = ConfigurationManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            BasicSettingsView()
                .tabItem {
                    Label("基础设置", systemImage: "gear")
                }
                .tag(0)
            
            APISettingsView()
                .tabItem {
                    Label("API配置", systemImage: "key.fill")
                }
                .tag(1)
            
            ShortcutSettingsView()
                .tabItem {
                    Label("快捷键", systemImage: "keyboard")
                }
                .tag(2)
            
            AdvancedSettingsView()
                .tabItem {
                    Label("高级设置", systemImage: "slider.horizontal.3")
                }
                .tag(3)
            
            AboutView()
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
                .tag(4)
        }
        .frame(width: 600, height: 500)
        .navigationTitle("Hello Prompt 设置")
    }
}

// MARK: - 基础设置视图
struct BasicSettingsView: View {
    @StateObject private var configManager = ConfigurationManager.shared
    
    var body: some View {
        Form {
            Section("应用行为") {
                Toggle("开机自动启动", isOn: $configManager.configuration.launchAtLogin)
                    .onTapGesture {
                        handleLaunchAtLoginToggle()
                    }
                
                Toggle("启动时显示悬浮球", isOn: $configManager.configuration.showFloatingBallOnStartup)
                
                Toggle("悬浮球始终在最前", isOn: $configManager.configuration.floatingBallAlwaysOnTop)
            }
            
            Section("音频设置") {
                Picker("音频质量", selection: $configManager.configuration.audioQuality) {
                    ForEach(AudioQuality.allCases, id: \.self) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                VStack(alignment: .leading) {
                    Text("VAD静音阈值: \(String(format: "%.3f", configManager.configuration.vadThreshold))")
                    Slider(value: $configManager.configuration.vadThreshold, in: 0.001...0.1, step: 0.001)
                }
                
                VStack(alignment: .leading) {
                    Text("静音检测时长: \(String(format: "%.1f", configManager.configuration.vadSilenceDuration))秒")
                    Slider(value: $configManager.configuration.vadSilenceDuration, in: 0.5...5.0, step: 0.1)
                }
            }
            
            Section("日志设置") {
                Toggle("启用日志记录", isOn: $configManager.configuration.enableLogging)
                
                Picker("日志级别", selection: $configManager.configuration.logLevel) {
                    ForEach(ConfigLogLevel.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .disabled(!configManager.configuration.enableLogging)
            }
            
            Spacer()
            
            HStack {
                Spacer()
                
                Button("重置为默认设置") {
                    showResetConfirmation()
                }
                .foregroundColor(.red)
                
                Button("保存设置") {
                    configManager.saveConfiguration()
                    showSaveSuccess()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        // Configuration auto-saves through @Published
    }
    
    private func handleLaunchAtLoginToggle() {
        Task { @MainActor in
            if configManager.configuration.launchAtLogin {
                LaunchAtLoginManager.shared.enable()
            } else {
                LaunchAtLoginManager.shared.disable()
            }
            configManager.saveConfiguration()
        }
    }
    
    private func showResetConfirmation() {
        let alert = NSAlert()
        alert.messageText = "重置设置"
        alert.informativeText = "确定要将所有设置重置为默认值吗？此操作不可撤销。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "重置")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            configManager.resetToDefaults()
        }
    }
    
    private func showSaveSuccess() {
        // 显示保存成功提示
        let alert = NSAlert()
        alert.messageText = "设置已保存"
        alert.informativeText = "您的设置已成功保存。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
}

// MARK: - API设置视图
struct APISettingsView: View {
    @StateObject private var configManager = ConfigurationManager.shared
    @State private var apiKey: String = ""
    @State private var baseURL: String = ""
    @State private var showAPIKey: Bool = false
    @State private var testingAPI: Bool = false
    @State private var testResult: String = ""
    
    var body: some View {
        Form {
            Section("OpenAI API配置") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("API密钥")
                        Spacer()
                        Button(showAPIKey ? "隐藏" : "显示") {
                            showAPIKey.toggle()
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.blue)
                    }
                    
                    HStack {
                        if showAPIKey {
                            TextField("输入OpenAI API密钥", text: $apiKey)
                        } else {
                            SecureField("输入OpenAI API密钥", text: $apiKey)
                        }
                        
                        Button("测试") {
                            testAPIConnection()
                        }
                        .disabled(apiKey.isEmpty || testingAPI)
                        .buttonStyle(.bordered)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("API基础URL")
                    TextField("https://api.openai.com/v1", text: $baseURL)
                        .textFieldStyle(.roundedBorder)
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Whisper模型")
                        Picker("", selection: $configManager.configuration.whisperModel) {
                            Text("whisper-1").tag("whisper-1")
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 150)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading) {
                        Text("GPT模型")
                        Picker("", selection: $configManager.configuration.gptModel) {
                            Text("gpt-4o").tag("gpt-4o")
                            Text("gpt-4").tag("gpt-4")
                            Text("gpt-3.5-turbo").tag("gpt-3.5-turbo")
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 150)
                    }
                }
            }
            
            Section("API状态") {
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: configManager.isValidConfiguration ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(configManager.isValidConfiguration ? .green : .red)
                        
                        Text(configManager.isValidConfiguration ? "API配置有效" : "API配置无效")
                            .foregroundColor(configManager.isValidConfiguration ? .green : .red)
                    }
                    
                    if !testResult.isEmpty {
                        Text(testResult)
                            .font(.caption)
                            .foregroundColor(testResult.contains("成功") ? .green : .red)
                            .padding(.top, 4)
                    }
                    
                    if testingAPI {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.5)
                            Text("正在测试API连接...")
                                .font(.caption)
                        }
                    }
                }
            }
            
            Spacer()
            
            HStack {
                Link("获取API密钥", destination: URL(string: "https://platform.openai.com/api-keys")!)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Button("保存API配置") {
                    saveAPIConfiguration()
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKey.isEmpty || baseURL.isEmpty)
            }
        }
        .padding()
        .onAppear {
            loadAPIConfiguration()
        }
    }
    
    private func loadAPIConfiguration() {
        apiKey = configManager.configuration.openAIAPIKey
        baseURL = configManager.configuration.openAIBaseURL
    }
    
    private func saveAPIConfiguration() {
        configManager.updateAPIConfiguration(apiKey: apiKey, baseURL: baseURL)
        testResult = "配置已保存"
        
        // 通知应用管理器更新配置
        NotificationCenter.default.post(name: .configurationUpdated, object: nil)
    }
    
    private func testAPIConnection() {
        testingAPI = true
        testResult = ""
        
        Task {
            do {
                let config = OpenAIConfig(
                    apiKey: apiKey,
                    baseURL: baseURL,
                    whisperModel: configManager.configuration.whisperModel,
                    gptModel: configManager.configuration.gptModel
                )
                
                let openAIService = OpenAIService(config: config)
                let result = try await openAIService.testConnection()
                
                await MainActor.run {
                    if result.success {
                        testResult = "✅ \(result.message) (响应时间: \(String(format: "%.2f", result.responseTime * 1000))ms)"
                    } else {
                        testResult = "❌ \(result.message)"
                    }
                    testingAPI = false
                }
                
            } catch {
                await MainActor.run {
                    testResult = "❌ 连接失败: \(error.localizedDescription)"
                    testingAPI = false
                }
            }
        }
    }
}

// MARK: - 快捷键设置视图
struct ShortcutSettingsView: View {
    @StateObject private var configManager = ConfigurationManager.shared
    @State private var selectedShortcut: String? = nil
    @State private var recordingKeypress: Bool = false
    @State private var showingRecorder: Bool = false
    @State private var recordingShortcutId: String = ""
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("全局快捷键设置")
                .font(.title2)
                .padding(.bottom)
            
            List {
                ForEach(configManager.getAllShortcuts(), id: \.id) { shortcut in
                    ShortcutRowView(
                        shortcut: shortcut,
                        isSelected: selectedShortcut == shortcut.id,
                        onSelect: { selectedShortcut = shortcut.id },
                        onEdit: { editShortcut(shortcut) }
                    )
                }
            }
            
            Spacer()
            
            VStack(alignment: .leading) {
                Text("提示:")
                    .font(.headline)
                
                Text("• 避免与系统快捷键冲突")
                Text("• 推荐使用Command+Shift+Option组合")
                Text("• 单击\"编辑\"按钮并按下新的快捷键组合")
                Text("• 按ESC键取消录制")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .sheet(isPresented: $showingRecorder) {
            ShortcutRecorderView(
                shortcutId: recordingShortcutId,
                currentShortcut: getCurrentShortcut(for: recordingShortcutId),
                onSave: { shortcutId, keyCode, modifiers in
                    configManager.updateShortcut(shortcutId, keyCode: keyCode, modifiers: modifiers)
                    showingRecorder = false
                    
                    // 通知系统重新注册快捷键
                    NotificationCenter.default.post(name: .shortcutsChanged, object: nil)
                },
                onCancel: {
                    showingRecorder = false
                }
            )
        }
    }
    
    private func editShortcut(_ shortcut: ModernShortcutConfig) {
        recordingShortcutId = shortcut.id
        showingRecorder = true
    }
    
    private func getCurrentShortcut(for id: String) -> ModernShortcutConfig? {
        return configManager.getAllShortcuts().first { $0.id == id }
    }
}

// MARK: - 快捷键行视图
struct ShortcutRowView: View {
    let shortcut: ModernShortcutConfig
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(shortcut.name)
                    .font(.headline)
                Text(functionName(for: shortcut.id))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(shortcut.displayName)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(4)
            
            Button("编辑") {
                onEdit()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(4)
        .onTapGesture {
            onSelect()
        }
    }
    
    private func functionName(for shortcutId: String) -> String {
        switch shortcutId {
        case "recording": return "开始/停止录音"
        case "settings": return "显示设置界面"
        case "floating_ball": return "显示/隐藏悬浮球"
        case "quick_optimize": return "快速优化剪贴板文本"
        default: return "未知功能"
        }
    }
}

// MARK: - 高级设置视图
struct AdvancedSettingsView: View {
    @StateObject private var configManager = ConfigurationManager.shared
    
    var body: some View {
        Form {
            Section("性能设置") {
                VStack(alignment: .leading) {
                    Text("网络超时时间: \(Int(configManager.configuration.openAIBaseURL.isEmpty ? 30 : 30))秒")
                    // 这里可以添加更多高级配置选项
                }
            }
            
            Section("配置管理") {
                HStack {
                    Button("导出配置") {
                        exportConfiguration()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("导入配置") {
                        importConfiguration()
                    }
                    .buttonStyle(.bordered)
                }
                
                Text("配置文件不包含API密钥等敏感信息，可安全分享")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("调试选项") {
                Toggle("详细日志记录", isOn: .constant(configManager.configuration.logLevel == .debug))
                    .disabled(true) // 通过日志级别控制
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("日志文件统计")
                        .font(.headline)
                    
                    LogStatisticsView()
                        .padding(.leading, 10)
                }
                
                HStack {
                    Button("打开日志文件夹") {
                        openLogsFolder()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("导出日志") {
                        exportLogs()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("清除所有日志") {
                        clearLogs()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
            }
            
            Section("权限管理") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("麦克风权限")
                        Text(checkMicrophonePermission() ? "已授权" : "未授权")
                            .font(.caption)
                            .foregroundColor(checkMicrophonePermission() ? .green : .red)
                    }
                    
                    Spacer()
                    
                    if !checkMicrophonePermission() {
                        Button("申请权限") {
                            requestMicrophonePermission()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("输入监控权限")
                        Text(checkInputMonitoringPermission() ? "已授权" : "未授权")
                            .font(.caption)
                            .foregroundColor(checkInputMonitoringPermission() ? .green : .red)
                    }
                    
                    Spacer()
                    
                    if !checkInputMonitoringPermission() {
                        Button("打开系统设置") {
                            openInputMonitoringSettings()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("辅助功能权限")
                        Text(checkAccessibilityPermission() ? "已授权" : "未授权")
                            .font(.caption)
                            .foregroundColor(checkAccessibilityPermission() ? .green : .red)
                    }
                    
                    Spacer()
                    
                    if !checkAccessibilityPermission() {
                        Button("打开系统设置") {
                            openAccessibilitySettings()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding()
    }
    
    private func exportLogs() {
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "HelloPrompt-日志-\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none))"
        savePanel.title = "导出日志文件"
        savePanel.message = "选择保存位置"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try LogManager.shared.exportLogs(to: url)
                    
                    let alert = NSAlert()
                    alert.messageText = "日志导出成功"
                    alert.informativeText = "日志文件已保存到：\(url.path)"
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "确定")
                    alert.runModal()
                    
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "日志导出失败"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .critical
                    alert.addButton(withTitle: "确定")
                    alert.runModal()
                }
            }
        }
    }
    
    private func openLogsFolder() {
        LogManager.shared.openLogDirectory()
    }
    
    private func clearLogs() {
        let statistics = LogManager.shared.getLogStatistics()
        
        let alert = NSAlert()
        alert.messageText = "清除日志"
        alert.informativeText = "确定要清除所有日志文件吗？\n\n当前共有 \(statistics.fileCount) 个日志文件，总大小 \(statistics.totalSizeFormatted)。此操作不可撤销。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "清除")
        alert.addButton(withTitle: "取消")
        
        if alert.runModal() == .alertFirstButtonReturn {
            LogManager.shared.clearAllLogs()
            
            // 显示清除成功提示
            let successAlert = NSAlert()
            successAlert.messageText = "日志清除完成"
            successAlert.informativeText = "所有日志文件已成功清除。"
            successAlert.alertStyle = .informational
            successAlert.addButton(withTitle: "确定")
            successAlert.runModal()
        }
    }
    
    private func checkMicrophonePermission() -> Bool {
        return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }
    
    private func checkInputMonitoringPermission() -> Bool {
        return IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }
    
    private func checkAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }
    
    private func requestMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            // 权限结果处理
        }
    }
    
    private func openInputMonitoringSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        NSWorkspace.shared.open(url)
    }
    
    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    
    private func exportConfiguration() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "HelloPrompt-配置-\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)).json"
        savePanel.title = "导出配置文件"
        savePanel.message = "选择保存位置"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try configManager.exportConfiguration(to: url)
                    
                    let alert = NSAlert()
                    alert.messageText = "配置导出成功"
                    alert.informativeText = "配置文件已保存到：\(url.path)"
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "确定")
                    alert.runModal()
                    
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "配置导出失败"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .critical
                    alert.addButton(withTitle: "确定")
                    alert.runModal()
                }
            }
        }
    }
    
    private func importConfiguration() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        openPanel.title = "导入配置文件"
        openPanel.message = "选择要导入的配置文件"
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                do {
                    try configManager.importConfiguration(from: url)
                    
                    let alert = NSAlert()
                    alert.messageText = "配置导入成功"
                    alert.informativeText = "配置已成功导入并应用。某些更改可能需要重启应用才能生效。"
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "确定")
                    alert.runModal()
                    
                    // 通知系统配置已更新
                    NotificationCenter.default.post(name: .configurationUpdated, object: nil)
                    
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "配置导入失败"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .critical
                    alert.addButton(withTitle: "确定")
                    alert.runModal()
                }
            }
        }
    }
}

// MARK: - 关于视图
struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.fill")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                Text("Hello Prompt")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("语音转AI提示词工具")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("版本 1.0.0 (1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("功能特性:")
                    .font(.headline)
                
                Text("• 智能语音识别")
                Text("• AI提示词优化")
                Text("• 全局快捷键支持")
                Text("• 多应用文本插入")
                Text("• 现代化界面设计")
            }
            .font(.body)
            
            Spacer()
            
            VStack(spacing: 8) {
                Text("© 2025 Hello Prompt. All rights reserved.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Link("项目主页", destination: URL(string: "https://github.com/helloprompt/helloprompt")!)
                    Text("•")
                        .foregroundColor(.secondary)
                    Link("使用指南", destination: URL(string: "https://helloprompt.app/guide")!)
                    Text("•")
                        .foregroundColor(.secondary)
                    Link("问题反馈", destination: URL(string: "https://github.com/helloprompt/helloprompt/issues")!)
                }
                .font(.caption)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 快捷键录制视图
struct ShortcutRecorderView: View {
    let shortcutId: String
    let currentShortcut: ModernShortcutConfig?
    let onSave: (String, Int64, KeyModifiers) -> Void
    let onCancel: () -> Void
    
    @State private var isRecording: Bool = false
    @State private var recordedKeyCode: Int64 = 0
    @State private var recordedModifiers: KeyModifiers = []
    @State private var conflictMessage: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("设置快捷键")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("为 \"\(currentShortcut?.name ?? "未知功能")\" 设置新的快捷键")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack {
                if let current = currentShortcut {
                    Text("当前快捷键: \(current.displayName)")
                        .font(.body)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Rectangle()
                    .fill(isRecording ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                    .frame(height: 100)
                    .overlay(
                        VStack {
                            if isRecording {
                                Text("按下新的快捷键组合...")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                
                                if recordedKeyCode != 0 {
                                    Text(KeyCodeHelper.keyName(for: recordedKeyCode))
                                        .font(.system(.title, design: .monospaced))
                                        .fontWeight(.bold)
                                    
                                    Text("修饰键: \(recordedModifiers.symbols)")
                                        .font(.caption)
                                }
                                
                                Text("按ESC取消")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("点击开始录制")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    )
                    .cornerRadius(8)
                    .onTapGesture {
                        startRecording()
                    }
                
                if !conflictMessage.isEmpty {
                    Text(conflictMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            HStack(spacing: 20) {
                Button("取消") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                
                Button("保存") {
                    if recordedKeyCode != 0 && !recordedModifiers.isEmpty {
                        onSave(shortcutId, recordedKeyCode, recordedModifiers)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(recordedKeyCode == 0 || recordedModifiers.isEmpty)
            }
        }
        .padding(30)
        .frame(width: 400, height: 300)
        .background(Color(NSColor.windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.keyDownNotification)) { notification in
            if isRecording {
                handleKeyDown(notification)
            }
        }
    }
    
    private func startRecording() {
        isRecording = true
        recordedKeyCode = 0
        recordedModifiers = []
        conflictMessage = ""
        
        // 创建一个监听全局键盘事件的监听器
        let _ = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handleGlobalKeyEvent(event)
        }
        
        // 保存monitor引用以便后续移除
        // 这里简化处理，实际应用中需要更完善的生命周期管理
    }
    
    private func handleKeyDown(_ notification: Notification) {
        guard let event = notification.object as? NSEvent else { return }
        handleGlobalKeyEvent(event)
    }
    
    private func handleGlobalKeyEvent(_ event: NSEvent) {
        guard isRecording else { return }
        
        if event.type == .keyDown {
            let keyCode = Int64(event.keyCode)
            let modifiers = keyModifiersFromNSEvent(event)
            
            // 如果按下ESC，取消录制
            if keyCode == 53 { // ESC key
                isRecording = false
                return
            }
            
            // 忽略单独的修饰键
            if isModifierKey(keyCode) {
                return
            }
            
            recordedKeyCode = keyCode
            recordedModifiers = modifiers
            
            // 检查冲突
            checkConflicts()
            
            isRecording = false
        }
    }
    
    private func keyModifiersFromNSEvent(_ event: NSEvent) -> KeyModifiers {
        var modifiers: KeyModifiers = []
        
        if event.modifierFlags.contains(.command) {
            modifiers.insert(.command)
        }
        if event.modifierFlags.contains(.shift) {
            modifiers.insert(.shift)
        }
        if event.modifierFlags.contains(.option) {
            modifiers.insert(.option)
        }
        if event.modifierFlags.contains(.control) {
            modifiers.insert(.control)
        }
        
        return modifiers
    }
    
    private func isModifierKey(_ keyCode: Int64) -> Bool {
        let modifierKeyCodes: [Int64] = [54, 55, 56, 57, 58, 59, 60, 61, 62] // Command, Shift, Option, Control keys
        return modifierKeyCodes.contains(keyCode)
    }
    
    private func checkConflicts() {
        // 检查与现有快捷键的冲突
        let existingShortcuts = ConfigurationManager.shared.getAllShortcuts()
        
        for shortcut in existingShortcuts {
            if shortcut.id != shortcutId && 
               shortcut.keyCode == recordedKeyCode && 
               shortcut.modifiers == recordedModifiers {
                conflictMessage = "与现有快捷键 \"\(shortcut.name)\" 冲突"
                return
            }
        }
        
        // 检查与系统快捷键的基本冲突
        if recordedModifiers.isEmpty {
            conflictMessage = "请使用修饰键组合"
            return
        }
        
        conflictMessage = ""
    }
}

// MARK: - 通知扩展
extension Notification.Name {
    static let configurationUpdated = Notification.Name("configurationUpdated")
    static let shortcutsChanged = Notification.Name("shortcutsChanged")
}

// MARK: - NSEvent扩展用于全局键盘监听
extension NSApplication {
    static let keyDownNotification = Notification.Name("NSApplicationKeyDown")
}

// MARK: - 日志统计视图
struct LogStatisticsView: View {
    @State private var statistics = LogStatistics(fileCount: 0, totalSize: 0, oldestFileDate: nil, newestFileDate: nil)
    @State private var refreshTimer: Timer?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("文件数量：")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(statistics.fileCount) 个")
            }
            
            HStack {
                Text("总大小：")
                    .foregroundColor(.secondary)
                Spacer()
                Text(statistics.totalSizeFormatted)
            }
            
            HStack {
                Text("日期范围：")
                    .foregroundColor(.secondary)
                Spacer()
                Text(statistics.dateRangeDescription)
            }
        }
        .font(.caption)
        .onAppear {
            updateStatistics()
            startRefreshTimer()
        }
        .onDisappear {
            stopRefreshTimer()
        }
    }
    
    private func updateStatistics() {
        statistics = LogManager.shared.getLogStatistics()
    }
    
    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { @MainActor in
                updateStatistics()
            }
        }
    }
    
    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - 导入AVFoundation用于权限检查
import AVFoundation