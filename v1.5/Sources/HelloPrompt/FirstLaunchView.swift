//
//  FirstLaunchView.swift
//  HelloPrompt
//
//  首次启动配置界面 - SwiftUI实现用户引导流程
//  Copyright © 2025 HelloPrompt. All rights reserved.
//

import SwiftUI
import AppKit
import AVFoundation

// MARK: - 首次启动主视图
struct FirstLaunchView: View {
    @StateObject private var viewModel = FirstLaunchViewModel()
    @State private var currentStep = 0
    
    let onCompletion: (Bool) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 头部区域
            headerView
            
            // 内容区域 - 添加滚动支持
            TabView(selection: $currentStep) {
                ScrollView {
                    WelcomeStepView()
                        .padding(.vertical, 20)
                }
                .tag(0)
                
                ScrollView {
                    PermissionsStepView(viewModel: viewModel)
                        .padding(.vertical, 20)
                }
                .tag(1)
                
                ScrollView {
                    APIConfigStepView(viewModel: viewModel)
                        .padding(.vertical, 20)
                }
                .tag(2)
                
                ScrollView {
                    CompletionStepView()
                        .padding(.vertical, 20)
                }
                .tag(3)
            }
            .tabViewStyle(.automatic)
            
            // 底部导航区域
            footerView
        }
        .frame(width: 600, height: 500)
        .background(Color(.windowBackgroundColor))
    }
    
    // MARK: - 头部视图
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "mic.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            Text("Hello Prompt")
                .font(.title)
                .fontWeight(.bold)
            
            Text("语音转AI提示词工具")
                .font(.headline)
                .foregroundColor(.secondary)
            
            // 进度指示器
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
    }
    
    // MARK: - 底部导航视图
    private var footerView: some View {
        HStack {
            Button("退出") {
                onCompletion(false)
            }
            .foregroundColor(.red)
            
            Spacer()
            
            if currentStep > 0 {
                Button("上一步") {
                    withAnimation {
                        currentStep -= 1
                    }
                }
            }
            
            Button(currentStep == 3 ? "完成" : "下一步") {
                if currentStep == 3 {
                    completeSetup()
                } else {
                    withAnimation {
                        currentStep += 1
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canProceedToNextStep)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
    }
    
    // MARK: - 辅助属性
    private var canProceedToNextStep: Bool {
        switch currentStep {
        case 0: return true // 欢迎页面总是可以继续
        case 1: return viewModel.hasRequiredPermissions // 权限页面需要权限
        case 2: return viewModel.hasValidAPIConfig // API配置页面需要有效配置
        case 3: return true // 完成页面总是可以完成
        default: return false
        }
    }
    
    private func completeSetup() {
        viewModel.completeSetup()
        onCompletion(true)
    }
}

// MARK: - 欢迎步骤视图
struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("欢迎使用 Hello Prompt")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "mic.fill", title: "智能语音识别", description: "使用OpenAI Whisper进行高精度语音转文字")
                FeatureRow(icon: "brain.head.profile", title: "AI提示词优化", description: "GPT-4智能优化你的提示词，提高AI对话效果")
                FeatureRow(icon: "keyboard", title: "全局快捷键", description: "Command+U 快速启动语音录制")
                FeatureRow(icon: "arrow.up.doc.on.clipboard", title: "智能文本插入", description: "支持各种应用的文本插入，无缝集成工作流")
            }
            
            Text("接下来我们将引导您完成初始配置")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
    }
}

// MARK: - 功能特性行
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - 权限步骤视图
struct PermissionsStepView: View {
    @ObservedObject var viewModel: FirstLaunchViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("授予必要权限")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Hello Prompt需要以下权限才能正常工作：")
                .font(.body)
                .foregroundColor(.secondary)
            
            VStack(spacing: 16) {
                PermissionRow(
                    icon: "mic.fill",
                    title: "麦克风权限",
                    description: "用于录制语音进行识别",
                    status: viewModel.microphonePermissionStatus,
                    onRequest: { viewModel.requestMicrophonePermission() }
                )
                
                PermissionRow(
                    icon: "keyboard",
                    title: "输入监控权限",
                    description: "用于全局快捷键功能",
                    status: viewModel.inputMonitoringPermissionStatus,
                    onRequest: { viewModel.openInputMonitoringSettings() }
                )
                
                PermissionRow(
                    icon: "hand.point.up.braille.fill",
                    title: "辅助功能权限",
                    description: "用于文本插入功能",
                    status: viewModel.accessibilityPermissionStatus,
                    onRequest: { viewModel.openAccessibilitySettings() }
                )
            }
            
            if !viewModel.hasRequiredPermissions {
                VStack(spacing: 12) {
                    Text("请授予上述权限后继续。某些权限需要在系统设置中手动启用。")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                    
                    Button("刷新权限状态") {
                        viewModel.refreshPermissionStatus()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
    }
}

// MARK: - 权限行视图
struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let status: PermissionStatus
    let onRequest: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack {
                statusIcon
                
                if status != .authorized {
                    Button("授权") {
                        onRequest()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .authorized:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .denied:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        case .notDetermined:
            Image(systemName: "questionmark.circle.fill")
                .foregroundColor(.orange)
        }
    }
}

// MARK: - API配置步骤视图
struct APIConfigStepView: View {
    @ObservedObject var viewModel: FirstLaunchViewModel
    @State private var apiKey: String = ""
    @State private var baseURL: String = "https://api.openai.com/v1"
    @State private var whisperModel: String = "whisper-1"
    @State private var gptModel: String = "gpt-4o"
    @State private var showAPIKey: Bool = false
    @State private var testingAPI: Bool = false
    @State private var testResult: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("配置OpenAI API")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Hello Prompt使用OpenAI的服务进行语音识别和文本优化")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                VStack(alignment: .leading) {
                    HStack {
                        Text("API密钥")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(showAPIKey ? "隐藏" : "显示") {
                            showAPIKey.toggle()
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Group {
                            if showAPIKey {
                                TextField("sk-...", text: $apiKey)
                                    .onPasteCommand(of: [.plainText]) { providers in
                                        providers.first?.loadObject(ofClass: NSString.self) { object, error in
                                            if let string = object as? String {
                                                DispatchQueue.main.async {
                                                    apiKey = string.trimmingCharacters(in: .whitespacesAndNewlines)
                                                }
                                            }
                                        }
                                    }
                            } else {
                                SecureField("sk-...", text: $apiKey)
                                    .onPasteCommand(of: [.plainText]) { providers in
                                        providers.first?.loadObject(ofClass: NSString.self) { object, error in
                                            if let string = object as? String {
                                                DispatchQueue.main.async {
                                                    apiKey = string.trimmingCharacters(in: .whitespacesAndNewlines)
                                                }
                                            }
                                        }
                                    }
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        
                        Button("测试") {
                            testAPIKey()
                        }
                        .disabled(apiKey.isEmpty || testingAPI)
                        .buttonStyle(.bordered)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("API基础URL")
                        .font(.headline)
                    
                    TextField("https://api.openai.com/v1", text: $baseURL)
                        .textFieldStyle(.roundedBorder)
                        .onPasteCommand(of: [.plainText]) { providers in
                            providers.first?.loadObject(ofClass: NSString.self) { object, error in
                                if let string = object as? String {
                                    DispatchQueue.main.async {
                                        baseURL = string.trimmingCharacters(in: .whitespacesAndNewlines)
                                    }
                                }
                            }
                        }
                }
                
                // 模型配置
                VStack(alignment: .leading, spacing: 8) {
                    Text("模型配置")
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Whisper模型")
                                .font(.subheadline)
                            Picker("Whisper模型", selection: $whisperModel) {
                                Text("whisper-1").tag("whisper-1")
                            }
                            .pickerStyle(.menu)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading) {
                            Text("GPT模型")
                                .font(.subheadline)
                            Picker("GPT模型", selection: $gptModel) {
                                Text("gpt-4").tag("gpt-4")
                                Text("gpt-4o").tag("gpt-4o")
                                Text("gpt-4o-mini").tag("gpt-4o-mini")
                                Text("gpt-3.5-turbo").tag("gpt-3.5-turbo")
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }
                
                if !testResult.isEmpty {
                    HStack {
                        Image(systemName: testResult.contains("成功") ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(testResult.contains("成功") ? .green : .red)
                        
                        Text(testResult)
                            .font(.caption)
                            .foregroundColor(testResult.contains("成功") ? .green : .red)
                    }
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
            
            VStack(alignment: .leading, spacing: 8) {
                Text("如何获取API密钥：")
                    .font(.headline)
                
                Text("1. 访问 platform.openai.com")
                Text("2. 注册或登录账户")
                Text("3. 前往API Keys页面")
                Text("4. 创建新的API密钥")
                
                Link("前往OpenAI平台", destination: URL(string: "https://platform.openai.com/api-keys")!)
                    .foregroundColor(.blue)
            }
            .font(.caption)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        // Compatibility with older macOS versions
        .onAppear {
            // Setup observers for text changes if needed
        }
    }
    
    private func testAPIKey() {
        testingAPI = true
        testResult = "正在测试连接..."
        
        Task {
            do {
                // 创建测试请求
                guard let url = URL(string: "\(baseURL)/models") else {
                    await MainActor.run {
                        testResult = "❌ 基础URL格式错误"
                        testingAPI = false
                    }
                    return
                }
                
                var request = URLRequest(url: url)
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.timeoutInterval = 10.0
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                await MainActor.run {
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode == 200 {
                            testResult = "✅ API连接测试成功"
                            viewModel.updateAPIConfig(apiKey: apiKey, baseURL: baseURL)
                            viewModel.updateModelConfig(whisperModel: whisperModel, gptModel: gptModel)
                        } else if httpResponse.statusCode == 401 {
                            testResult = "❌ API密钥无效"
                        } else {
                            testResult = "❌ 服务器响应错误 (\(httpResponse.statusCode))"
                        }
                    } else {
                        testResult = "❌ 网络连接失败"
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

// MARK: - 完成步骤视图
struct CompletionStepView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("配置完成！")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Hello Prompt已准备就绪")
                .font(.body)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("快捷键提醒：")
                    .font(.headline)
                
                ShortcutHintRow(keys: "⌘U", description: "开始/停止语音录制和转换")
                
                Button("测试快捷键录音") {
                    testShortcutRecording()
                }
                .buttonStyle(.borderedProminent)
                
                Text("现在您可以在任何应用中使用 Command+U 来启动语音录制功能了！")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
        }
    }
    
    private func testShortcutRecording() {
        // 显示提示，让用户知道测试开始了
        let alert = NSAlert()
        alert.messageText = "快捷键测试"
        alert.informativeText = "请在5秒内按下 Command+U 来测试快捷键是否工作正常。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "开始测试")
        alert.runModal()
        
        // 这里可以添加实际的测试逻辑
    }
}

// MARK: - 快捷键提示行
struct ShortcutHintRow: View {
    let keys: String
    let description: String
    
    var body: some View {
        HStack {
            Text(keys)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(4)
            
            Text(description)
                .font(.body)
            
            Spacer()
        }
    }
}

// MARK: - 权限状态枚举
enum PermissionStatus {
    case notDetermined
    case denied
    case authorized
    
    var rawValue: String {
        switch self {
        case .notDetermined: return "notDetermined"
        case .denied: return "denied"
        case .authorized: return "authorized"
        }
    }
}

// MARK: - 首次启动视图模型
@MainActor
class FirstLaunchViewModel: ObservableObject {
    @Published var microphonePermissionStatus: PermissionStatus = .notDetermined
    @Published var inputMonitoringPermissionStatus: PermissionStatus = .notDetermined
    @Published var accessibilityPermissionStatus: PermissionStatus = .notDetermined
    @Published var hasValidAPIConfig: Bool = false
    
    private let configManager = ConfigurationManager.shared
    private var permissionCheckTimer: Timer?
    private var appNotificationObserver: NSObjectProtocol?
    
    init() {
        updatePermissionStatus()
        setupPermissionMonitoring()
    }
    
    deinit {
        // Note: In Swift 6, we can't access actor-isolated properties from deinit
        // The cleanup will happen when the actor is deinitialized
        // Timer and observer cleanup will be handled by the system
    }
    
    /// Cleanup method to be called explicitly when needed
    func cleanup() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
        if let observer = appNotificationObserver {
            NotificationCenter.default.removeObserver(observer)
            appNotificationObserver = nil
        }
        LogManager.shared.info(.app, "FirstLaunchViewModel清理完成")
    }
    
    var hasRequiredPermissions: Bool {
        return microphonePermissionStatus == .authorized &&
               inputMonitoringPermissionStatus == .authorized &&
               accessibilityPermissionStatus == .authorized
    }
    
    private func setupPermissionMonitoring() {
        do {
            // 添加应用状态监听
            appNotificationObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.updatePermissionStatus()
                }
            }
            
            // 定期检查权限状态（每3秒）
            permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] timer in
                // 检查 timer 是否仍然有效
                guard timer.isValid else {
                    // 移除日志，因为并发问题
                    return
                }
                
                Task { @MainActor in
                    self?.updatePermissionStatus()
                }
            }
            
            LogManager.shared.info(.app, "权限监控已启动", metadata: [
                "timerInterval": 3.0,
                "hasObserver": appNotificationObserver != nil,
                "hasTimer": permissionCheckTimer != nil
            ])
            
        } catch {
            LogManager.shared.error(.app, "权限监控设置失败", metadata: [
                "error": error.localizedDescription
            ])
        }
    }
    
    func updatePermissionStatus() {
        let previousState = hasRequiredPermissions
        
        // 麦克风权限 - 使用保护性编程防止 API 调用失败
        let previousMicrophoneStatus = microphonePermissionStatus
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        switch micStatus {
        case .authorized:
            microphonePermissionStatus = .authorized
        case .denied, .restricted:
            microphonePermissionStatus = .denied
        case .notDetermined:
            microphonePermissionStatus = .notDetermined
        @unknown default:
            microphonePermissionStatus = .notDetermined
            LogManager.shared.warning(.app, "未知的麦克风权限状态", metadata: ["status": "\(micStatus)"])
        }
        
        // 输入监控权限 - 安全调用系统 API
        let previousInputMonitoringStatus = inputMonitoringPermissionStatus
        let inputMonitoringResult = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        inputMonitoringPermissionStatus = inputMonitoringResult ? .authorized : .denied
        
        // 辅助功能权限 - 安全调用系统 API  
        let previousAccessibilityStatus = accessibilityPermissionStatus
        let accessibilityResult = AXIsProcessTrusted()
        accessibilityPermissionStatus = accessibilityResult ? .authorized : .denied
        
        // 记录权限状态变化
        let currentState = hasRequiredPermissions
        if previousState != currentState {
            LogManager.shared.info(.app, "权限状态发生变化", metadata: [
                "previousState": previousState,
                "currentState": currentState,
                "microphoneStatus": microphonePermissionStatus.rawValue,
                "inputMonitoringStatus": inputMonitoringPermissionStatus.rawValue,
                "accessibilityStatus": accessibilityPermissionStatus.rawValue
            ])
            
            // 更新配置管理器中的权限状态
            if currentState {
                configManager.markPermissionsGranted()
            }
        }
        
        // 记录个别权限状态变化
        if previousMicrophoneStatus != microphonePermissionStatus {
            LogManager.shared.info(.app, "麦克风权限状态变化", metadata: [
                "from": previousMicrophoneStatus.rawValue,
                "to": microphonePermissionStatus.rawValue
            ])
        }
        
        if previousInputMonitoringStatus != inputMonitoringPermissionStatus {
            LogManager.shared.info(.app, "输入监控权限状态变化", metadata: [
                "from": previousInputMonitoringStatus.rawValue,
                "to": inputMonitoringPermissionStatus.rawValue
            ])
        }
        
        if previousAccessibilityStatus != accessibilityPermissionStatus {
            LogManager.shared.info(.app, "辅助功能权限状态变化", metadata: [
                "from": previousAccessibilityStatus.rawValue,
                "to": accessibilityPermissionStatus.rawValue
            ])
        }
    }
    
    func requestMicrophonePermission() {
        LogManager.shared.info(.app, "请求麦克风权限")
        
        // 检查当前权限状态
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        guard currentStatus == .notDetermined else {
            LogManager.shared.info(.app, "麦克风权限已决定", metadata: ["status": "\(currentStatus)"])
            updatePermissionStatus()
            return
        }
        
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            Task { @MainActor in
                LogManager.shared.info(.app, "麦克风权限请求完成", metadata: ["granted": granted])
                self?.updatePermissionStatus()
            }
        }
    }
    
    func openInputMonitoringSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else {
            LogManager.shared.error(.app, "无法创建输入监控设置URL")
            return
        }
        NSWorkspace.shared.open(url)
        
        // 延迟检查权限状态，给用户时间授权
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            Task { @MainActor in
                self.updatePermissionStatus()
            }
        }
    }
    
    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            LogManager.shared.error(.app, "无法创建辅助功能设置URL")
            return
        }
        NSWorkspace.shared.open(url)
        
        // 延迟检查权限状态，给用户时间授权
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            Task { @MainActor in
                self.updatePermissionStatus()
            }
        }
    }
    
    /// 手动刷新权限状态 - 用于调试和手动触发
    func refreshPermissionStatus() {
        updatePermissionStatus()
        LogManager.shared.info(.app, "手动刷新权限状态")
    }
    
    func updateAPIConfig(apiKey: String, baseURL: String) {
        configManager.updateAPIConfiguration(apiKey: apiKey, baseURL: baseURL)
        hasValidAPIConfig = !apiKey.isEmpty && apiKey.hasPrefix("sk-")
    }
    
    func updateModelConfig(whisperModel: String, gptModel: String) {
        configManager.updateModelConfiguration(whisperModel: whisperModel, gptModel: gptModel)
    }
    
    func completeSetup() {
        configManager.completeFirstLaunch()
        configManager.markPermissionsGranted()
        LogManager.shared.info(.app, "首次启动配置完成")
    }
}

// MARK: - 首次启动窗口管理器
@MainActor
class FirstLaunchWindowManager: NSObject {
    static let shared = FirstLaunchWindowManager()
    
    private var firstLaunchWindow: NSWindow?
    private var completion: ((Bool) -> Void)?
    
    private override init() {
        super.init()
    }
    
    func showFirstLaunch(completion: @escaping (Bool) -> Void) {
        self.completion = completion
        
        let firstLaunchView = FirstLaunchView { [weak self] completed in
            self?.completion?(completed)
            self?.closeFirstLaunch()
        }
        
        let hostingController = NSHostingController(rootView: firstLaunchView)
        
        firstLaunchWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        firstLaunchWindow?.contentViewController = hostingController
        firstLaunchWindow?.title = "Hello Prompt 初始配置"
        firstLaunchWindow?.center()
        firstLaunchWindow?.makeKeyAndOrderFront(nil)
        firstLaunchWindow?.delegate = self
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func closeFirstLaunch() {
        firstLaunchWindow?.close()
        firstLaunchWindow = nil
        completion = nil
    }
}

// MARK: - 窗口委托
extension FirstLaunchWindowManager: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        completion?(false)
        return true
    }
}