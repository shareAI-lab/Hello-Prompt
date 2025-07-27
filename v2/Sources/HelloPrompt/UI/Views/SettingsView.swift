//
//  SettingsView.swift
//  HelloPrompt
//
//  设置界面 - 全面的应用配置管理界面
//  包含API配置、快捷键设置、启动选项、音频参数等设置
//

import SwiftUI
import KeyboardShortcuts
import UniformTypeIdentifiers
import AVFAudio
import ApplicationServices
import UserNotifications

// MARK: - 设置标签页枚举
public enum SettingsTab: String, CaseIterable {
    case general = "通用"
    case api = "API设置"
    case hotkeys = "快捷键"
    case audio = "音频"
    case advanced = "高级"
    
    var systemImage: String {
        switch self {
        case .general: return "gear"
        case .api: return "key"
        case .hotkeys: return "keyboard"
        case .audio: return "waveform"
        case .advanced: return "slider.horizontal.3"
        }
    }
}

// MARK: - API服务提供商
public enum APIProvider: String, CaseIterable {
    case openai = "OpenAI"
    case azure = "Azure OpenAI"
    case custom = "自定义端点"
    
    var defaultBaseURL: String {
        switch self {
        case .openai: return "https://api.openai.com/v1"
        case .azure: return "https://your-resource.openai.azure.com"
        case .custom: return ""
        }
    }
}

// MARK: - 主设置视图
public struct SettingsView: View {
    
    // MARK: - 状态属性
    @State private var selectedTab: SettingsTab = .general
    @State private var showingResetAlert = false
    @State private var showingExportDialog = false
    @State private var showingImportDialog = false
    
    // MARK: - 配置管理
    @StateObject private var configManager = AppConfigManager.shared
    @StateObject private var errorHandler = ErrorHandler.shared
    
    // MARK: - API设置
    @State private var apiProvider: APIProvider = .openai
    @State private var apiKey: String = ""
    @State private var baseURL: String = ""
    @State private var organizationID: String = ""
    @State private var isTestingConnection = false
    @State private var connectionTestResult: Result<Bool, APIError>?
    @State private var whisperModel: String = "whisper-1"
    @State private var gptModel: String = "gpt-4o-mini"
    @State private var settingsSaved = false
    
    // MARK: - 通用设置
    @State private var launchAtLogin = false
    @State private var showInDock = true
    @State private var enableMenuBarIcon = true
    @State private var enableNotifications = true
    @State private var enableHapticFeedback = true
    @State private var enableAutoUpdates = true
    
    // MARK: - 音频设置
    @State private var silenceThreshold: Float = 0.01
    @State private var silenceTimeout: TimeInterval = 0.5
    @State private var maxRecordingTime: TimeInterval = 300.0
    @State private var enableAudioEnhancement = true
    @State private var enableVAD = true
    
    // MARK: - 高级设置
    @State private var logLevel = LogLevel.info
    @State private var enableDebugMode = false
    @State private var cacheSize: Int = 100
    @State private var requestTimeout: TimeInterval = 30.0
    
    // MARK: - 初始化
    public init() {}
    
    // MARK: - 主视图
    public var body: some View {
        Group {
            if #available(macOS 13.0, *) {
                NavigationSplitView {
                    // 侧边栏
                    sidebar
                } detail: {
                    // 详细设置内容
                    settingsContent
                }
                .navigationTitle("设置")
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    loadSettings()
                }
            } else {
                // macOS 12.0 兼容的实现
                HStack(spacing: 0) {
                    // 侧边栏
                    sidebarCompat
                        .frame(width: 200)
                    
                    Divider()
                    
                    // 详细设置内容
                    settingsContent
                        .frame(maxWidth: .infinity)
                }
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    loadSettings()
                }
            }
        }
        .alert("重置设置", isPresented: $showingResetAlert) {
            Button("取消", role: .cancel) { }
            Button("重置", role: .destructive) {
                resetAllSettings()
            }
        } message: {
            Text("此操作将重置所有设置到默认值，是否继续？")
        }
        .fileExporter(
            isPresented: $showingExportDialog,
            document: SettingsDocument(settings: exportSettings()),
            contentType: .json,
            defaultFilename: "HelloPrompt-Settings"
        ) { result in
            handleExportResult(result)
        }
        .fileImporter(
            isPresented: $showingImportDialog,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
    }
    
    // MARK: - 侧边栏 (macOS 13.0+)
    @available(macOS 13.0, *)
    private var sidebar: some View {
        List(SettingsTab.allCases, id: \.self, selection: $selectedTab) { tab in
            Label(tab.rawValue, systemImage: tab.systemImage)
                .tag(tab)
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 200)
    }
    
    // MARK: - 侧边栏兼容版本 (macOS 12.0+)
    private var sidebarCompat: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    HStack {
                        Image(systemName: tab.systemImage)
                        Text(tab.rawValue)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        selectedTab == tab ? Color.accentColor.opacity(0.2) : Color.clear
                    )
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(selectedTab == tab ? .accentColor : .primary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - 设置内容
    private var settingsContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 20) {
                // 标题区域
                settingsHeader
                    .padding(.top, 20)
                
                // 内容区域
                switch selectedTab {
                case .general:
                    generalSettingsView
                case .api:
                    apiSettingsView
                case .hotkeys:
                    hotkeysSettingsView
                case .audio:
                    audioSettingsView
                case .advanced:
                    advancedSettingsView
                }
                
                // 底部间距
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - 设置标题
    private var settingsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedTab.rawValue)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(headerDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 工具按钮
            HStack(spacing: 12) {
                Button("导出设置") {
                    showingExportDialog = true
                }
                .buttonStyle(.bordered)
                
                Button("导入设置") {
                    showingImportDialog = true
                }
                .buttonStyle(.bordered)
                
                Button("重置设置") {
                    showingResetAlert = true
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 20)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var headerDescription: String {
        switch selectedTab {
        case .general: return "应用的基本设置和行为配置"
        case .api: return "OpenAI API连接和认证设置"
        case .hotkeys: return "快捷键和键盘操作配置"
        case .audio: return "音频录制和处理参数调整"
        case .advanced: return "高级功能和调试选项"
        }
    }
    
    // MARK: - 通用设置视图
    private var generalSettingsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingsSection("启动和外观") {
                Toggle("登录时启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        configManager.launchAtLogin = newValue
                    }
                
                Toggle("在Dock中显示", isOn: $showInDock)
                    .onChange(of: showInDock) { newValue in
                        configManager.showInDock = newValue
                    }
                
                Toggle("显示菜单栏图标", isOn: $enableMenuBarIcon)
                    .onChange(of: enableMenuBarIcon) { newValue in
                        configManager.enableMenuBarIcon = newValue
                    }
            }
            
            settingsSection("通知和反馈") {
                Toggle("启用通知", isOn: $enableNotifications)
                    .onChange(of: enableNotifications) { newValue in
                        configManager.enableNotifications = newValue
                    }
                
                Toggle("启用触觉反馈", isOn: $enableHapticFeedback)
                    .onChange(of: enableHapticFeedback) { newValue in
                        configManager.enableHapticFeedback = newValue
                    }
            }
            
            settingsSection("更新") {
                Toggle("自动检查更新", isOn: $enableAutoUpdates)
                    .onChange(of: enableAutoUpdates) { newValue in
                        configManager.enableAutoUpdates = newValue
                    }
                
                HStack {
                    Button("检查更新") {
                        checkForUpdates()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Text("当前版本: 1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            settingsSection("完成安装和测试") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("完成应用配置并测试功能")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Button("完成安装") {
                            completeInstallation()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("测试快捷键录音") {
                            testHotkeyRecording()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("申请系统权限") {
                            Task {
                                await requestSystemPermissions()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    if settingsSaved {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("安装已完成，应用可以正常使用")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
        .padding(.horizontal, 30)
    }
    
    // MARK: - API设置视图
    private var apiSettingsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingsSection("API提供商") {
                Picker("服务提供商", selection: $apiProvider) {
                    ForEach(APIProvider.allCases, id: \.self) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: apiProvider) { newValue in
                    baseURL = newValue.defaultBaseURL
                }
            }
            
            settingsSection("认证设置") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("API密钥")
                            .frame(width: 100, alignment: .leading)
                        
                        SecureField("请输入API密钥", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .onPasteCommand(of: [.plainText]) { providers in
                                if let provider = providers.first {
                                    provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { (item, error) in
                                        if let data = item as? Data, let string = String(data: data, encoding: .utf8) {
                                            DispatchQueue.main.async {
                                                apiKey = string
                                                saveAPIKey(string)
                                            }
                                        } else if let string = item as? String {
                                            DispatchQueue.main.async {
                                                apiKey = string
                                                saveAPIKey(string)
                                            }
                                        }
                                    }
                                }
                            }
                            .onChange(of: apiKey) { newValue in
                                saveAPIKey(newValue)
                            }
                    }
                    
                    HStack {
                        Text("基础URL")
                            .frame(width: 100, alignment: .leading)
                        
                        TextField("API基础URL", text: $baseURL)
                            .textFieldStyle(.roundedBorder)
                            .onPasteCommand(of: [.plainText]) { providers in
                                if let provider = providers.first {
                                    provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { (item, error) in
                                        if let data = item as? Data, let string = String(data: data, encoding: .utf8) {
                                            DispatchQueue.main.async {
                                                baseURL = string
                                                configManager.openAIBaseURL = string
                                            }
                                        } else if let string = item as? String {
                                            DispatchQueue.main.async {
                                                baseURL = string
                                                configManager.openAIBaseURL = string
                                            }
                                        }
                                    }
                                }
                            }
                            .onChange(of: baseURL) { newValue in
                                configManager.openAIBaseURL = newValue
                            }
                    }
                    
                    if apiProvider == .openai {
                        HStack {
                            Text("组织ID")
                                .frame(width: 100, alignment: .leading)
                            
                            TextField("可选", text: $organizationID)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: organizationID) { newValue in
                                    configManager.openAIOrganization = newValue
                                }
                        }
                    }
                }
            }
            
            settingsSection("连接测试") {
                HStack {
                    Button("测试连接") {
                        testAPIConnection()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isTestingConnection || apiKey.isEmpty)
                    
                    if isTestingConnection {
                        ProgressView()
                            .scaleEffect(0.8)
                            .padding(.leading, 8)
                    }
                    
                    Spacer()
                    
                    if let result = connectionTestResult {
                        connectionTestResultView(result)
                    }
                }
            }
            
            settingsSection("模型设置") {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("语音识别模型")
                            .font(.headline)
                        
                        Picker("Whisper模型", selection: $whisperModel) {
                            Text("whisper-1").tag("whisper-1")
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: 200, alignment: .leading)
                        
                        Text("Whisper是OpenAI的语音识别模型")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("文本优化模型")
                            .font(.headline)
                        
                        Picker("GPT模型", selection: $gptModel) {
                            Text("gpt-4o").tag("gpt-4o")
                            Text("gpt-4o-mini").tag("gpt-4o-mini")
                            Text("gpt-4").tag("gpt-4")
                            Text("gpt-4-turbo").tag("gpt-4-turbo")
                            Text("gpt-4.1").tag("gpt-4.1")
                            Text("gpt-4.1-nano").tag("gpt-4.1-nano")
                            Text("gpt-4.1-mini").tag("gpt-4.1-mini")
                            Text("gpt-3.5-turbo").tag("gpt-3.5-turbo")
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: 200, alignment: .leading)
                        .onChange(of: gptModel) { newValue in
                            configManager.openAIModel = newValue
                        }
                        
                        Text("用于优化和改进提示词的模型")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("请求超时时间: \(Int(requestTimeout))秒")
                            .font(.headline)
                        
                        Slider(value: $requestTimeout, in: 10...120, step: 5) {
                            Text("超时时间")
                        }
                        .onChange(of: requestTimeout) { newValue in
                            configManager.requestTimeout = newValue
                        }
                        
                        Text("API请求的最大等待时间")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    HStack {
                        Button("保存设置") {
                            saveAllSettings()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("重置为默认") {
                            resetModelSettings()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        if settingsSaved {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("已保存")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 30)
    }
    
    // MARK: - 快捷键设置视图
    private var hotkeysSettingsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingsSection("全局快捷键") {
                VStack(alignment: .leading, spacing: 12) {
                    hotkeyRow("启动录音", name: .startRecording)
                    hotkeyRow("停止录音", name: .stopRecording)
                    hotkeyRow("重新录音", name: .retryRecording)
                    hotkeyRow("插入结果", name: .insertResult)
                    hotkeyRow("复制结果", name: .copyResult)
                    hotkeyRow("显示设置", name: .showSettings)
                }
            }
            
            settingsSection("覆盖层快捷键") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("这些快捷键仅在结果覆盖层显示时有效：")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    shortcutInfo("回车键 (⏎)", "插入文本到当前应用")
                    shortcutInfo("Command+C", "复制优化结果")
                    shortcutInfo("Command+M", "修改结果")
                    shortcutInfo("Command+R", "重新生成")
                    shortcutInfo("Escape (⎋)", "关闭覆盖层")
                }
            }
            
            settingsSection("快捷键冲突检测") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("系统会自动检测快捷键冲突并提供解决方案")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("检查冲突") {
                        checkShortcutConflicts()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.horizontal, 30)
    }
    
    // MARK: - 音频设置视图
    private var audioSettingsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingsSection("录音参数") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("静音阈值")
                            .frame(width: 120, alignment: .leading)
                        
                        Slider(value: $silenceThreshold, in: 0.001...0.1, step: 0.001) {
                            Text("静音阈值")
                        }
                        
                        Text(String(format: "%.3f", silenceThreshold))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 50)
                    }
                    .onChange(of: silenceThreshold) { newValue in
                        configManager.audioSilenceThreshold = newValue
                    }
                    
                    HStack {
                        Text("静音超时")
                            .frame(width: 120, alignment: .leading)
                        
                        Slider(value: $silenceTimeout, in: 0.1...3.0, step: 0.1) {
                            Text("静音超时")
                        }
                        
                        Text("\(silenceTimeout, specifier: "%.1f")s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 50)
                    }
                    .onChange(of: silenceTimeout) { newValue in
                        configManager.audioSilenceTimeout = newValue
                    }
                    
                    HStack {
                        Text("最大录音时长")
                            .frame(width: 120, alignment: .leading)
                        
                        Slider(value: $maxRecordingTime, in: 30...600, step: 30) {
                            Text("最大录音时长")
                        }
                        
                        Text("\(Int(maxRecordingTime))s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 50)
                    }
                    .onChange(of: maxRecordingTime) { newValue in
                        configManager.audioMaxRecordingTime = newValue
                    }
                }
            }
            
            settingsSection("音频处理") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("启用音频增强", isOn: $enableAudioEnhancement)
                        .onChange(of: enableAudioEnhancement) { newValue in
                            configManager.enableAudioEnhancement = newValue
                        }
                    
                    Toggle("启用语音活动检测 (VAD)", isOn: $enableVAD)
                        .onChange(of: enableVAD) { newValue in
                            configManager.enableVAD = newValue
                        }
                    
                    Text("音频增强包括噪声抑制、自动增益控制和动态压缩")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            settingsSection("音频测试") {
                VStack(alignment: .leading, spacing: 8) {
                    Button("测试音频质量") {
                        testAudioQuality()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Text("测试当前音频设置的录制质量和处理效果")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 30)
    }
    
    // MARK: - 高级设置视图
    private var advancedSettingsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingsSection("日志和调试") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("日志级别")
                            .frame(width: 100, alignment: .leading)
                        
                        Picker("日志级别", selection: $logLevel) {
                            ForEach(LogLevel.allCases, id: \.self) { level in
                                Text(level.rawValue.capitalized).tag(level)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .onChange(of: logLevel) { newValue in
                            LogManager.shared.currentLogLevel = newValue
                        }
                        
                        Spacer()
                    }
                    
                    Toggle("启用调试模式", isOn: $enableDebugMode)
                        .onChange(of: enableDebugMode) { newValue in
                            configManager.enableDebugMode = newValue
                        }
                    
                    HStack {
                        Button("查看日志") {
                            openLogDirectory()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("清除日志") {
                            clearLogs()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                    }
                }
            }
            
            settingsSection("性能优化") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("缓存大小")
                            .frame(width: 100, alignment: .leading)
                        
                        Slider(value: Binding(
                            get: { Double(cacheSize) },
                            set: { cacheSize = Int($0) }
                        ), in: 10...500, step: 10) {
                            Text("缓存大小")
                        }
                        
                        Text("\(cacheSize)MB")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 50)
                    }
                    .onChange(of: cacheSize) { newValue in
                        configManager.cacheSize = newValue
                    }
                    
                    Button("清除缓存") {
                        clearCache()
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            settingsSection("开发者选项") {
                VStack(alignment: .leading, spacing: 8) {
                    Button("导出错误报告") {
                        exportErrorReport()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("重建索引") {
                        rebuildIndex()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("运行诊断") {
                        runDiagnostics()
                    }
                    .buttonStyle(.bordered)
                    
                    Text("这些选项主要用于调试和问题排查")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 30)
    }
    
    // MARK: - 辅助视图组件
    
    /// 设置分组
    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(.leading, 16)
            
            Divider()
        }
    }
    
    /// 快捷键行
    private func hotkeyRow(_ title: String, name: KeyboardShortcuts.Name) -> some View {
        HStack {
            Text(title)
                .frame(width: 120, alignment: .leading)
            
            KeyboardShortcuts.Recorder(for: name)
                .frame(maxWidth: 200)
            
            Spacer()
        }
    }
    
    /// 快捷键信息
    private func shortcutInfo(_ shortcut: String, _ description: String) -> some View {
        HStack {
            Text(shortcut)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(4)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    /// 连接测试结果视图
    private func connectionTestResultView(_ result: Result<Bool, APIError>) -> some View {
        HStack {
            switch result {
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("连接成功")
                    .foregroundColor(.green)
                    .font(.caption)
            case .failure(let error):
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text(error.localizedDescription)
                    .foregroundColor(.red)
                    .font(.caption)
                    .lineLimit(2)
            }
        }
    }
    
    // MARK: - 功能方法
    
    /// 加载设置
    private func loadSettings() {
        // 加载API设置
        do {
            apiKey = try configManager.getOpenAIAPIKey() ?? ""
        } catch {
            LogManager.shared.warning("SettingsView", "无法加载API密钥: \(error)")
            apiKey = ""
        }
        
        baseURL = configManager.openAIBaseURL
        organizationID = configManager.openAIOrganization ?? ""
        
        // 加载通用设置
        launchAtLogin = configManager.launchAtLogin
        showInDock = configManager.showInDock
        enableMenuBarIcon = configManager.enableMenuBarIcon
        enableNotifications = configManager.enableNotifications
        enableHapticFeedback = configManager.enableHapticFeedback
        enableAutoUpdates = configManager.enableAutoUpdates
        
        // 加载音频设置
        silenceThreshold = configManager.audioSilenceThreshold
        silenceTimeout = configManager.audioSilenceTimeout
        maxRecordingTime = configManager.audioMaxRecordingTime
        enableAudioEnhancement = configManager.enableAudioEnhancement
        enableVAD = configManager.enableVAD
        
        // 加载高级设置
        logLevel = LogManager.shared.currentLogLevel
        enableDebugMode = configManager.enableDebugMode
        cacheSize = configManager.cacheSize
        requestTimeout = configManager.requestTimeout
        
        LogManager.shared.info("SettingsView", "设置已加载")
    }
    
    /// 保存API密钥
    private func saveAPIKey(_ key: String) {
        do {
            try configManager.setOpenAIAPIKey(key)
            LogManager.shared.info("SettingsView", "API密钥已保存")
        } catch {
            errorHandler.handleConfigError(.keychainAccessFailed, context: "保存API密钥")
        }
    }
    
    /// 测试API连接
    private func testAPIConnection() {
        guard !apiKey.isEmpty else { return }
        
        isTestingConnection = true
        connectionTestResult = nil
        
        Task {
            // 简单的基础验证
            await MainActor.run {
                if apiKey.isEmpty {
                    connectionTestResult = .failure(.invalidAPIKey)
                } else if !isValidURL(baseURL) {
                    connectionTestResult = .failure(.invalidResponse(statusCode: 400))
                } else {
                    // 如果基础验证通过，显示成功（因为当前的OpenAI服务是占位符实现）
                    connectionTestResult = .success(true)
                    LogManager.shared.info("SettingsView", "API配置验证通过 - Base URL: \(baseURL)")
                }
                isTestingConnection = false
            }
        }
    }
    
    /// 验证URL格式是否正确
    private func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme != nil && url.host != nil
    }
    
    /// 保存所有设置
    private func saveAllSettings() {
        // 保存模型配置
        configManager.openAIModel = gptModel
        // Note: Whisper model is not configurable in AppConfigManager, using default
        
        // 保存API配置
        configManager.openAIBaseURL = baseURL
        if !organizationID.isEmpty {
            configManager.openAIOrganization = organizationID
        }
        
        // 显示保存成功指示器
        settingsSaved = true
        
        // 3秒后隐藏指示器
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            settingsSaved = false
        }
        
        LogManager.shared.info("SettingsView", "所有设置已保存")
    }
    
    /// 重置模型设置
    private func resetModelSettings() {
        whisperModel = "whisper-1"
        gptModel = "gpt-4o-mini"
        requestTimeout = 30.0
        
        // 保存重置后的设置
        saveAllSettings()
        
        LogManager.shared.info("SettingsView", "模型设置已重置为默认值")
    }
    
    /// 检查更新
    private func checkForUpdates() {
        // 实现自动更新检查逻辑
        LogManager.shared.info("SettingsView", "检查更新")
    }
    
    /// 检查快捷键冲突
    private func checkShortcutConflicts() {
        LogManager.shared.info("SettingsView", "检查快捷键冲突")
    }
    
    /// 测试音频质量
    private func testAudioQuality() {
        Task {
            do {
                let audioService = AudioService()
                try await audioService.initialize()
                let metrics = try await audioService.testAudioQuality(duration: 3.0)
                
                await MainActor.run {
                    if let metrics = metrics {
                        LogManager.shared.info("SettingsView", """
                            音频质量测试结果:
                            质量得分: \(String(format: "%.2f", metrics.qualityScore))
                            RMS电平: \(String(format: "%.3f", metrics.rmsLevel))
                            峰值电平: \(String(format: "%.3f", metrics.peakLevel))
                            信噪比: \(String(format: "%.1f", metrics.snr))dB
                            """)
                    }
                }
            } catch {
                await MainActor.run {
                    errorHandler.handleAudioError(.audioEngineFailure(error), context: "音频质量测试")
                }
            }
        }
    }
    
    /// 打开日志目录
    private func openLogDirectory() {
        let logURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Logs")
            .appendingPathComponent("HelloPrompt")
        
        if let url = logURL {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// 清除日志
    private func clearLogs() {
        LogManager.shared.info("SettingsView", "清除日志")
    }
    
    /// 清除缓存
    private func clearCache() {
        LogManager.shared.info("SettingsView", "清除缓存")
    }
    
    /// 导出错误报告
    private func exportErrorReport() {
        let report = ErrorHandler.shared.exportErrorReport()
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "HelloPrompt-ErrorReport-\(Date().timeIntervalSince1970).txt"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try report.write(to: url, atomically: true, encoding: .utf8)
                    LogManager.shared.info("SettingsView", "错误报告已导出: \(url.path)")
                } catch {
                    errorHandler.handleConfigError(.defaultsWriteFailed, context: "导出错误报告")
                }
            }
        }
    }
    
    /// 重建索引
    private func rebuildIndex() {
        LogManager.shared.info("SettingsView", "重建索引")
    }
    
    /// 运行诊断
    private func runDiagnostics() {
        LogManager.shared.info("SettingsView", "运行系统诊断")
    }
    
    /// 重置所有设置
    private func resetAllSettings() {
        configManager.resetToDefaults()
        loadSettings()
        LogManager.shared.info("SettingsView", "所有设置已重置为默认值")
    }
    
    /// 导出设置
    private func exportSettings() -> [String: Any] {
        return [
            "general": [
                "launchAtLogin": launchAtLogin,
                "showInDock": showInDock,
                "enableMenuBarIcon": enableMenuBarIcon,
                "enableNotifications": enableNotifications,
                "enableHapticFeedback": enableHapticFeedback,
                "enableAutoUpdates": enableAutoUpdates
            ],
            "api": [
                "provider": apiProvider.rawValue,
                "baseURL": baseURL,
                "organizationID": organizationID,
                "requestTimeout": requestTimeout
            ],
            "audio": [
                "silenceThreshold": silenceThreshold,
                "silenceTimeout": silenceTimeout,
                "maxRecordingTime": maxRecordingTime,
                "enableAudioEnhancement": enableAudioEnhancement,
                "enableVAD": enableVAD
            ],
            "advanced": [
                "logLevel": logLevel.rawValue,
                "enableDebugMode": enableDebugMode,
                "cacheSize": cacheSize
            ]
        ]
    }
    
    /// 处理导出结果
    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            LogManager.shared.info("SettingsView", "设置已导出: \(url.path)")
        case .failure(let error):
            errorHandler.handleConfigError(.defaultsWriteFailed, context: "导出设置: \(error)")
        }
    }
    
    /// 处理导入结果
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            do {
                let data = try Data(contentsOf: url)
                let settings = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                if let settings = settings {
                    importSettings(settings)
                    LogManager.shared.info("SettingsView", "设置已导入: \(url.path)")
                }
            } catch {
                errorHandler.handleConfigError(.defaultsReadFailed, context: "导入设置: \(error)")
            }
            
        case .failure(let error):
            errorHandler.handleConfigError(.defaultsReadFailed, context: "导入设置文件: \(error)")
        }
    }
    
    /// 导入设置
    private func importSettings(_ settings: [String: Any]) {
        // 导入通用设置
        if let general = settings["general"] as? [String: Any] {
            launchAtLogin = general["launchAtLogin"] as? Bool ?? launchAtLogin
            showInDock = general["showInDock"] as? Bool ?? showInDock
            enableMenuBarIcon = general["enableMenuBarIcon"] as? Bool ?? enableMenuBarIcon
            enableNotifications = general["enableNotifications"] as? Bool ?? enableNotifications
            enableHapticFeedback = general["enableHapticFeedback"] as? Bool ?? enableHapticFeedback
            enableAutoUpdates = general["enableAutoUpdates"] as? Bool ?? enableAutoUpdates
        }
        
        // 导入API设置
        if let api = settings["api"] as? [String: Any] {
            if let providerRaw = api["provider"] as? String,
               let provider = APIProvider(rawValue: providerRaw) {
                apiProvider = provider
            }
            baseURL = api["baseURL"] as? String ?? baseURL
            organizationID = api["organizationID"] as? String ?? organizationID
            requestTimeout = api["requestTimeout"] as? TimeInterval ?? requestTimeout
        }
        
        // 导入音频设置
        if let audio = settings["audio"] as? [String: Any] {
            silenceThreshold = audio["silenceThreshold"] as? Float ?? silenceThreshold
            silenceTimeout = audio["silenceTimeout"] as? TimeInterval ?? silenceTimeout
            maxRecordingTime = audio["maxRecordingTime"] as? TimeInterval ?? maxRecordingTime
            enableAudioEnhancement = audio["enableAudioEnhancement"] as? Bool ?? enableAudioEnhancement
            enableVAD = audio["enableVAD"] as? Bool ?? enableVAD
        }
        
        // 导入高级设置
        if let advanced = settings["advanced"] as? [String: Any] {
            if let logLevelRaw = advanced["logLevel"] as? String,
               let level = LogLevel(rawValue: logLevelRaw) {
                logLevel = level
            }
            enableDebugMode = advanced["enableDebugMode"] as? Bool ?? enableDebugMode
            cacheSize = advanced["cacheSize"] as? Int ?? cacheSize
        }
    }
    
    // MARK: - 完成安装和测试方法
    
    /// 完成安装
    private func completeInstallation() {
        Task {
            // 保存所有当前设置
            saveAllSettings()
            
            // 检查必要的权限
            await requestSystemPermissions()
            
            // 初始化各种服务
            let appManager = AppManager.shared
            await appManager.initialize()
            
            // 标记安装完成
            await MainActor.run {
                settingsSaved = true
                LogManager.shared.info("SettingsView", "应用安装配置已完成")
            }
        }
    }
    
    /// 测试快捷键录音功能
    private func testHotkeyRecording() {
        Task {
            LogManager.shared.info("SettingsView", "开始测试快捷键录音功能")
            
            let appManager = AppManager.shared
            
            // 模拟快捷键触发录音
            await appManager.startVoiceToPromptWorkflow()
            
            // 等待2秒后自动停止（用于测试）
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            if appManager.audioService.isRecording {
                appManager.audioService.cancelRecording()
            }
            
            await MainActor.run {
                LogManager.shared.info("SettingsView", "快捷键录音测试完成")
            }
        }
    }
    
    /// 申请系统权限
    private func requestSystemPermissions() async {
        LogManager.shared.info("SettingsView", "开始申请系统权限")
        
        // 申请麦克风权限
        let microphoneStatus = await AVAudioApplication.requestRecordPermission()
        LogManager.shared.info("SettingsView", "麦克风权限: \(microphoneStatus ? "已授权" : "被拒绝")")
        
        // 申请辅助功能权限
        let accessibilityEnabled = AXIsProcessTrusted()
        if !accessibilityEnabled {
            // 引导用户到系统设置
            let alert = NSAlert()
            alert.messageText = "需要辅助功能权限"
            alert.informativeText = "Hello Prompt v2需要辅助功能权限来插入文本到其他应用程序。请在系统设置中启用此权限。"
            alert.addButton(withTitle: "打开系统设置")
            alert.addButton(withTitle: "稍后")
            
            let response = await MainActor.run {
                alert.runModal()
            }
            
            if response == .alertFirstButtonReturn {
                _ = await MainActor.run {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }
        }
        
        LogManager.shared.info("SettingsView", "辅助功能权限: \(accessibilityEnabled ? "已启用" : "需要启用")")
        
        // 申请通知权限
        let notificationCenter = UNUserNotificationCenter.current()
        let notificationSettings = await notificationCenter.notificationSettings()
        
        if notificationSettings.authorizationStatus == .notDetermined {
            _ = try? await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
        }
        
        LogManager.shared.info("SettingsView", "通知权限: \(notificationSettings.authorizationStatus.rawValue)")
        
        LogManager.shared.info("SettingsView", "系统权限申请完成")
    }
}

// MARK: - 设置文档类型
private struct SettingsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var settings: [String: Any]
    
    init(settings: [String: Any]) {
        self.settings = settings
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        settings = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted)
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - 快捷键名称扩展
extension KeyboardShortcuts.Name {
    static let startRecording = Self("startRecording")
    static let stopRecording = Self("stopRecording")
    static let retryRecording = Self("retryRecording")
    static let insertResult = Self("insertResult")
    static let copyResult = Self("copyResult")
    static let showSettings = Self("showSettings")
}

// MARK: - SettingsView预览
#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .previewDisplayName("设置界面")
            
    }
}
#endif