//
//  HelloPromptApp_Simple.swift
//  HelloPrompt
//
//  简化版应用入口 - 避免SwiftUI兼容性问题
//

import SwiftUI
import AppKit
import KeyboardShortcuts
import Combine
import AVFAudio
import AVFoundation
import ApplicationServices

// MARK: - 主应用程序结构（简化版）
@main
struct HelloPromptApp: App {
    
    // MARK: - 应用状态管理
    @StateObject private var appManager = AppManager.shared
    @StateObject private var configManager = AppConfigManager.shared
    @StateObject private var errorHandler = ErrorHandler.shared
    @StateObject private var hotkeyService = HotkeyService.shared
    @StateObject private var launchAgentManager = LaunchAgentManager.shared
    
    // MARK: - UI状态
    @State private var isShowingSettings = false
    @State private var isShowingAbout = false
    @State private var isShowingOnboarding = false
    @State private var orbState: OrbState = .idle
    @State private var showingResult = false
    @State private var currentResult: OverlayResult?
    @State private var audioLevel: Float = 0.0
    @State private var orbVisible = false
    
    // MARK: - 权限管理
    @StateObject private var permissionManager = PermissionManager.shared
    
    // MARK: - 应用委托
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // MARK: - 主视图
    var body: some Scene {
        // 主设置窗口 - 默认显示
        WindowGroup("Hello Prompt v2") {
            SettingsView()
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    LogManager.shared.info("HelloPromptApp", "设置窗口已显示")
                    configureWindowForSettings()
                    setupApplication()
                }
        }
        .commands {
            appMenuCommands
        }
        .defaultSize(width: 800, height: 600)
        
        // 录音覆盖窗口 - 始终在顶层显示
        WindowGroup("录音", id: "recording-overlay") {
            RecordingOverlayView(
                orbState: $orbState,
                audioLevel: $audioLevel,
                isVisible: $orbVisible,
                onCancel: {
                    stopRecording()
                }
            )
            .frame(width: 200, height: 200)
            .background(Color.clear)
            .onAppear {
                configureRecordingWindow()
            }
        }
        .windowStyle(.plain)
        
        // 权限申请窗口 - 根据智能权限管理器状态显示
        WindowGroup("权限申请", id: "permission-request") {
            if permissionManager.shouldShowPermissionWindow {
                PermissionRequestView(
                    onPermissionsGranted: {
                        // 权限管理器会自动检测权限变化
                        LogManager.shared.info("HelloPromptApp", "权限申请界面报告权限已授权")
                    },
                    onSkipped: {
                        // 用户选择跳过，不强制要求权限
                        LogManager.shared.info("HelloPromptApp", "用户选择跳过权限申请")
                    }
                )
            } else {
                EmptyView()
            }
        }
        .windowResizability(.contentSize)
        
        // 新手引导窗口 - 综合设置引导
        WindowGroup("新手引导", id: "onboarding-wizard") {
            if isShowingOnboarding {
                OnboardingWizardView(
                    onCompleted: {
                        isShowingOnboarding = false
                        LogManager.shared.info("HelloPromptApp", "新手引导已完成")
                        
                        // 标记已完成引导
                        UserDefaults.standard.set(true, forKey: "HelloPrompt_OnboardingCompleted")
                    },
                    onSkipped: {
                        isShowingOnboarding = false
                        LogManager.shared.info("HelloPromptApp", "用户跳过新手引导")
                    }
                )
            } else {
                EmptyView()
            }
        }
        .windowResizability(.contentSize)
        
        // 结果显示窗口 - 显示优化后的提示词结果
        WindowGroup("结果显示", id: "result-overlay") {
            if showingResult, currentResult != nil {
                ResultOverlay(
                    result: $currentResult,
                    isShowing: $showingResult,
                    onAction: { action, text in
                        handleResultAction(action, text: text)
                    },
                    onClose: {
                        showingResult = false
                        currentResult = nil
                    },
                    enableAnimations: true,
                    allowEditing: true,
                    showKeyboardHints: true
                )
                .onAppear {
                    configureResultWindow()
                }
            } else {
                EmptyView()
            }
        }
        .windowStyle(.plain)
    }
    
    // MARK: - 应用菜单命令
    @CommandsBuilder
    private var appMenuCommands: some Commands {
        CommandGroup(after: .appInfo) {
            Button("关于 Hello Prompt v2") {
                showAbout()
            }
            .keyboardShortcut("a", modifiers: .command)
        }
        
        CommandGroup(after: .appSettings) {
            Button("偏好设置...") {
                showSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
            
            Button("新手引导...") {
                showOnboarding()
            }
            .keyboardShortcut("?", modifiers: .command)
        }
        
        CommandGroup(after: .help) {
            Button("开始录音") {
                startRecording()
            }
            .keyboardShortcut("u", modifiers: [.control])
            
            Button("停止录音") {
                stopRecording()
            }
            .keyboardShortcut(.escape, modifiers: [.option])
            .disabled(!appManager.audioService.isRecording)
        }
    }
    
    // MARK: - 应用启动和初始化
    
    private func setupApplication() {
        LogManager.shared.startupLog("🚀 Hello Prompt v2 应用启动开始", component: "HelloPromptApp", details: [
            "version": HelloPromptApp.appVersion,
            "build": HelloPromptApp.buildNumber,
            "bundleId": HelloPromptApp.bundleIdentifier
        ])
        
        // 配置应用外观
        LogManager.shared.startupLog("🎨 配置应用外观", component: "HelloPromptApp")
        configureAppearance()
        
        // 设置权限管理器回调
        LogManager.shared.startupLog("🔐 设置权限管理器回调", component: "HelloPromptApp")
        setupPermissionCallbacks()
        
        // 设置 Ctrl+U连按监听服务
        LogManager.shared.startupLog("⌨️ 设置 Ctrl+U连按监听服务", component: "HelloPromptApp")
        setupCtrlUHotkeyService()
        
        // 检查是否需要显示新手引导
        LogManager.shared.startupLog("📚 检查新手引导", component: "HelloPromptApp")
        checkAndShowOnboarding()
        
        // 初始化服务
        LogManager.shared.startupLog("⚙️ 开始初始化服务", component: "HelloPromptApp")
        Task { @MainActor in
            await initializeServices()
        }
    }
    
    private func checkAndShowOnboarding() {
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "HelloPrompt_OnboardingCompleted")
        
        if !hasCompletedOnboarding {
            // 首次启动，显示新手引导
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.isShowingOnboarding = true
                LogManager.shared.info("HelloPromptApp", "首次启动，显示新手引导")
            }
        } else {
            LogManager.shared.info("HelloPromptApp", "已完成新手引导，跳过")
        }
    }
    
    private func setupPermissionCallbacks() {
        // 监听权限变化事件
        permissionManager.onPermissionChanged = { event in
            LogManager.shared.info("HelloPromptApp", "权限变化事件：\(event.type.rawValue) \(event.oldStatus.statusText) -> \(event.newStatus.statusText)")
            
            // 权限授权后的处理
            if event.newStatus == .granted && event.oldStatus != .granted {
                Task { @MainActor in
                    await self.handlePermissionGranted(event.type)
                }
            }
        }
    }
    
    @MainActor
    private func handlePermissionGranted(_ type: PermissionType) async {
        LogManager.shared.info("HelloPromptApp", "处理权限授权：\(type.rawValue)")
        
        switch type {
        case .microphone:
            // 麦克风权限授权后，可以初始化音频服务
            try? await appManager.audioService.initialize()
            
        case .accessibility:
            // 辅助功能权限授权后，可以启用全局快捷键
            setupGlobalHotkeys()
            
            // 重新初始化HotkeyService的事件监听器
            hotkeyService.reinitializeEventTap()
            
        case .notification:
            // 通知权限授权后，可以启用系统通知
            LogManager.shared.info("HelloPromptApp", "通知权限已授权")
        }
    }
    
    private func setupCtrlUHotkeyService() {
        LogManager.shared.info("HelloPromptApp", "设置 Ctrl+U按住监听服务")
        
        // 设置录音开始回调
        hotkeyService.onCtrlURecordingStart = {
            Task { @MainActor in
                self.startCtrlURecording()
            }
        }
        
        // 设置录音停止回调
        hotkeyService.onCtrlURecordingStop = {
            Task { @MainActor in
                self.stopCtrlURecording()
            }
        }
        
        LogManager.shared.info("HelloPromptApp", "Ctrl+U按住监听服务设置完成")
    }
    
    private func configureAppearance() {
        // 设置应用图标
        if let icon = NSImage(named: "AppIcon") {
            NSApplication.shared.applicationIconImage = icon
        }
        
        // 配置窗口外观
        if let appearance = NSAppearance(named: .aqua) {
            NSApplication.shared.appearance = appearance
        }
    }
    
    @MainActor
    private func initializeServices() async {
        LogManager.shared.info("HelloPromptApp", "开始初始化应用服务")
        
        // 检查系统权限（使用新的权限管理器）
        await permissionManager.checkAllPermissions(reason: "应用启动")
        
        // 初始化应用管理器
        await appManager.initialize()
        
        // 设置快捷键处理（如果有辅助功能权限）
        if permissionManager.hasPermission(.accessibility) {
            setupGlobalHotkeys()
        }
        
        // 设置应用状态监听
        setupStateObservation()
        
        // 检查开机自启动设置
        if configManager.launchAtLogin {
            _ = await launchAgentManager.enableLaunchAtLogin()
        }
        
        LogManager.shared.info("HelloPromptApp", "应用服务初始化完成")
    }
    
    // MARK: - 快捷键设置
    
    private func setupGlobalHotkeys() {
        let hotkeyHandlers: [HotkeyIdentifier: () -> Void] = [
            .startRecording: startRecording,
            .stopRecording: stopRecording,
            .retryRecording: retryRecording,
            .insertResult: insertLastResult,
            .copyResult: copyLastResult,
            .showSettings: showSettings,
            .togglePause: togglePause,
            .cancelOperation: cancelOperation
        ]
        
        // 为每个快捷键注册默认键盘组合（简化实现）
        for (identifier, handler) in hotkeyHandlers {
            // 创建默认的快捷键组合（这里可以根据需要配置）
            let defaultShortcut: KeyboardShortcut
            switch identifier {
            case .startRecording:
                defaultShortcut = KeyboardShortcut("u", modifiers: [.control])
            case .stopRecording:
                defaultShortcut = KeyboardShortcut(.escape, modifiers: [.option])
            default:
                // 其他快捷键暂时使用默认组合
                defaultShortcut = KeyboardShortcut(.space, modifiers: [.control, .shift])
            }
            
            _ = hotkeyService.registerHotkey(identifier, shortcut: defaultShortcut, handler: handler)
        }
        
        LogManager.shared.info("HelloPromptApp", "全局快捷键已设置")
    }
    
    // MARK: - 状态监听
    
    private func setupStateObservation() {
        setupBasicStateObservation()
        setupEnhancedStateObservation()
    }
    
    private func setupBasicStateObservation() {
        // 监听应用状态变化
        appManager.$appState
            .receive(on: DispatchQueue.main)
            .sink { newState in
                updateOrbState(for: newState)
            }
            .store(in: &appDelegate.cancellables)
        
        // 监听音频电平变化
        appManager.audioService.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { level in
                audioLevel = level
            }
            .store(in: &appDelegate.cancellables)
        
        // 监听优化结果
        appManager.$lastOptimizationResult
            .receive(on: DispatchQueue.main)
            .sink { optimizationResult in
                if let result = optimizationResult {
                    showResult(result)
                }
            }
            .store(in: &appDelegate.cancellables)
    }
    
    /// 增强状态监听，包括权限和快捷键状态
    private func setupEnhancedStateObservation() {
        // 监听HotkeyService状态变化
        hotkeyService.$isEnabled
            .receive(on: DispatchQueue.main)
            .sink { isEnabled in
                if !isEnabled {
                    LogManager.shared.warning("HelloPromptApp", "Ctrl+U快捷键服务失效")
                }
            }
            .store(in: &appDelegate.cancellables)
        
        // 监听权限状态变化
        permissionManager.$permissionStates
            .receive(on: DispatchQueue.main)
            .sink { states in
                let accessibilityGranted = states[.accessibility]?.isGranted ?? false
                let microphoneGranted = states[.microphone]?.isGranted ?? false
                
                LogManager.shared.debug("HelloPromptApp", "权限状态更新 - 辅助功能: \(accessibilityGranted), 麦克风: \(microphoneGranted)")
                
                // 辅助功能权限被授权但快捷键服务未启用
                if accessibilityGranted && !hotkeyService.isEnabled {
                    LogManager.shared.info("HelloPromptApp", "辅助功能权限已授权，重新初始化快捷键服务")
                    hotkeyService.reinitializeEventTap()
                }
                
                // 麦克风权限被授权后初始化音频服务
                if microphoneGranted && !appManager.audioService.isInitialized {
                    Task {
                        try? await appManager.audioService.initialize()
                    }
                }
            }
            .store(in: &appDelegate.cancellables)
        
        // 监听配置状态变化
        configManager.$configurationValid
            .receive(on: DispatchQueue.main)
            .sink { isValid in
                LogManager.shared.debug("HelloPromptApp", "配置状态变化: \(isValid)")
                if isValid {
                    // 配置有效时，立即更新OpenAI服务
                    appManager.openAIService.configureFromSettings()
                }
            }
            .store(in: &appDelegate.cancellables)
    }
    
    /// 显示快捷键服务警告
    private func showHotkeyServiceWarning() {
        // 可以在这里显示用户友好的警告信息
        LogManager.shared.warning("HelloPromptApp", "Ctrl+U快捷键功能暂时不可用，请检查辅助功能权限")
    }
    
    private func updateOrbState(for appState: AppState) {
        switch appState {
        case .idle:
            orbState = .idle
            orbVisible = false
        case .listening:
            orbState = .listening
            orbVisible = true
        case .recording:
            orbState = .recording
            orbVisible = true
        case .processing:
            orbState = .processing
            orbVisible = true
        case .presenting:
            orbState = .result
            orbVisible = false // 显示结果覆盖层而不是光球
        case .error:
            orbState = .error
            orbVisible = true
        default:
            orbState = .idle
            orbVisible = false
        }
    }
    
    // MARK: - 操作处理
    
    @State private var lastRecordingTriggerTime: Date = .distantPast
    
    private func startRecording() {
        let now = Date()
        // 防止快捷键重复触发（500ms内的重复触发被忽略）
        if now.timeIntervalSince(lastRecordingTriggerTime) < 0.5 {
            LogManager.shared.warning("HelloPromptApp", "快捷键重复触发被忽略，距离上次触发: \(now.timeIntervalSince(lastRecordingTriggerTime))s")
            return
        }
        lastRecordingTriggerTime = now
        
        LogManager.shared.info("HelloPromptApp", "🎙️ 快捷键触发：开始录音")
        
        // 强制刷新权限状态并检查
        Task {
            await permissionManager.immediatePermissionCheck()
            
            // 重新检查核心权限状态
            if !permissionManager.corePermissionsGranted {
                LogManager.shared.warning("HelloPromptApp", "核心权限未授权，无法开始录音")
                LogManager.shared.debug("HelloPromptApp", "麦克风权限状态: \(permissionManager.hasPermission(.microphone))")
                
                // 如果麦克风权限也没有，尝试申请
                if !permissionManager.hasPermission(.microphone) {
                    _ = await permissionManager.requestPermission(.microphone)
                }
                
                await permissionManager.checkAllPermissions(reason: "录音请求")
                return
            }
            
            LogManager.shared.info("HelloPromptApp", "核心权限检查通过，开始录音流程")
        }
        
        // 检查当前应用状态，如果正在录音则忽略
        if appManager.appState == .recording || appManager.appState == .processing {
            LogManager.shared.warning("HelloPromptApp", "应用正在工作中，忽略快捷键触发，当前状态: \(appManager.appState)")
            return
        }
        
        // 强制重置应用状态以确保可以开始录音
        Task {
            await appManager.resetApplicationState()
            
            // 显示录音窗口
            await MainActor.run {
                orbState = .listening
                orbVisible = true
                LogManager.shared.info("HelloPromptApp", "🎯 显示录音界面，orbVisible=\(orbVisible)")
                
                // 强制显示录音窗口
                showRecordingWindow()
            }
            
            // 启动录音工作流
            LogManager.shared.info("HelloPromptApp", "🚀 启动录音工作流")
            await appManager.startVoiceToPromptWorkflow()
        }
    }
    
    private func stopRecording() {
        if appManager.audioService.isRecording {
            appManager.audioService.cancelRecording()
        }
    }
    
    private func retryRecording() {
        Task {
            await appManager.resetApplicationState()
            await appManager.startVoiceToPromptWorkflow()
        }
    }
    
    private func insertLastResult() {
        Task {
            await appManager.insertTextToActiveApplication()
        }
    }
    
    private func copyLastResult() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(appManager.lastResult, forType: .string)
        
        LogManager.shared.info("HelloPromptApp", "结果已复制到剪贴板")
    }
    
    private func togglePause() {
        Task {
            if appManager.appState == .suspended {
                await appManager.resume()
            } else {
                await appManager.suspend()
            }
        }
    }
    
    private func cancelOperation() {
        appManager.cancelCurrentWorkflow()
    }
    
    // MARK: - Ctrl+U按住录音控制
    
    private func startCtrlURecording() {
        LogManager.shared.info("HelloPromptApp", "🎙️ Ctrl+U按下触发：开始录音")
        
        // 检查前置条件
        guard permissionManager.corePermissionsGranted else {
            LogManager.shared.error("HelloPromptApp", "Ctrl+U录音失败：核心权限未授权")
            return
        }
        
        guard configManager.configurationValid else {
            LogManager.shared.error("HelloPromptApp", "Ctrl+U录音失败：OpenAI配置无效")
            return
        }
        
        // 检查当前应用状态，如枟正在工作则忽略
        if appManager.appState == .recording || appManager.appState == .processing {
            LogManager.shared.warning("HelloPromptApp", "应用正在工作中，忽略 Ctrl+U触发，当前状态: \(appManager.appState)")
            return
        }
        
        // 显示录音窗口
        orbVisible = true
        orbState = .listening
        showRecordingWindow()
        
        Task {
            // 强制重置应用状态以确保可以开始录音
            await appManager.resetApplicationState()
            
            LogManager.shared.info("HelloPromptApp", "🚀 启动 Ctrl+U录音工作流")
            await appManager.startVoiceToPromptWorkflow()
        }
    }
    
    private func stopCtrlURecording() {
        LogManager.shared.info("HelloPromptApp", "🛑 Ctrl+U松开触发：停止录音")
        
        Task {
            // 检查是否正在录音
            if appManager.audioService.isRecording {
                LogManager.shared.info("HelloPromptApp", "停止 Ctrl+U录音")
                
                // 直接调用AudioService的停止方法，让AppManager的工作流程自然完成
                try? await appManager.audioService.stopRecording()
                
                // 更新UI状态为处理中
                await MainActor.run {
                    orbState = .processing
                    // 保持orbVisible = true，让用户看到处理进度
                    LogManager.shared.info("HelloPromptApp", "Ctrl+U录音停止，切换到处理状态，等待ASR+LLM处理")
                    
                    // 在录音停止后，给用户一个视觉反馈
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // 如果在短时间内没有进入处理状态，可能是录音太短或失败
                        if self.appManager.appState == .idle {
                            LogManager.shared.warning("HelloPromptApp", "Ctrl+U录音停止后应用状态仍为idle，可能录音时间过短")
                            self.orbVisible = false
                        }
                    }
                }
            } else {
                LogManager.shared.warning("HelloPromptApp", "Ctrl+U松开时应用并未在录音状态")
                // 如果不在录音状态，直接隐藏悬浮球
                await MainActor.run {
                    orbVisible = false
                    orbState = .idle
                }
            }
        }
    }
    
    
    // MARK: - UI控制
    
    private func showSettings() {
        isShowingSettings = true
        
        // 打开设置窗口
        if let window = NSApp.windows.first(where: { $0.title == "设置" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // 创建新的设置窗口
            let settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow.title = "设置"
            settingsWindow.contentView = NSHostingView(rootView: SettingsView())
            settingsWindow.center()
            settingsWindow.makeKeyAndOrderFront(nil)
        }
    }
    
    private func showOnboarding() {
        isShowingOnboarding = true
        LogManager.shared.info("HelloPromptApp", "手动显示新手引导")
    }
    
    private func showAbout() {
        let aboutPanel = NSAlert()
        aboutPanel.messageText = "Hello Prompt v2"
        aboutPanel.informativeText = """
        版本 1.0.0
        
        AI驱动的语音转提示词工具
        
        © 2024 Hello Prompt Team
        """
        aboutPanel.alertStyle = .informational
        aboutPanel.addButton(withTitle: "确定")
        aboutPanel.runModal()
    }
    
    private func showResult(_ optimizationResult: OptimizationResult) {
        let overlayResult = OverlayResult(
            originalText: optimizationResult.originalText,
            optimizedText: optimizationResult.optimizedPrompt,
            improvements: optimizationResult.improvements,
            processingTime: optimizationResult.processingTime,
            context: getCurrentApplicationContext()
        )
        
        currentResult = overlayResult
        showingResult = true
        
        LogManager.shared.info("HelloPromptApp", """
            显示优化结果:
            原始文本: \(optimizationResult.originalText.prefix(50))...
            优化文本: \(optimizationResult.optimizedPrompt.prefix(50))...
            改进点: \(optimizationResult.improvements.count)
            处理时间: \(String(format: "%.2f", optimizationResult.processingTime))s
            """)
    }
    
    private func showRecordingWindow() {
        LogManager.shared.info("HelloPromptApp", "🚪 强制显示录音窗口")
        
        DispatchQueue.main.async {
            // 先查找是否已存在录音窗口
            let recordingWindow = NSApp.windows.first { window in
                window.title.contains("录音") || window.identifier?.rawValue == "recording-overlay"
            }
            
            if let window = recordingWindow {
                LogManager.shared.info("HelloPromptApp", "📱 找到已存在的录音窗口，激活它")
                window.level = .screenSaver
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                NSApp.activate(ignoringOtherApps: true)
            } else {
                LogManager.shared.warning("HelloPromptApp", "⚠️ 未找到录音窗口，手动创建")
                
                // 手动创建录音窗口
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 300, height: 300),
                    styleMask: [.borderless],
                    backing: .buffered,
                    defer: false
                )
                
                window.title = "录音覆盖"
                window.identifier = NSUserInterfaceItemIdentifier("recording-overlay")
                window.backgroundColor = NSColor.clear
                window.isOpaque = false
                window.hasShadow = false
                window.level = .screenSaver
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                
                // 居中显示
                if let screen = NSScreen.main {
                    let screenRect = screen.visibleFrame
                    let x = screenRect.midX - 150
                    let y = screenRect.midY - 150
                    window.setFrameOrigin(NSPoint(x: x, y: y))
                }
                
                // 设置内容视图
                let hostingView = NSHostingView(rootView: RecordingOverlayView(
                    orbState: self.$orbState,
                    audioLevel: self.$audioLevel,
                    isVisible: self.$orbVisible,
                    onCancel: self.stopRecording
                ))
                window.contentView = hostingView
                
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                NSApp.activate(ignoringOtherApps: true)
                
                LogManager.shared.info("HelloPromptApp", "✅ 手动创建录音窗口完成")
            }
        }
    }
    
    private func configureWindowForSettings() {
        // 配置设置窗口的特性
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApp.keyWindow {
                window.titlebarAppearsTransparent = false
                window.toolbarStyle = .unified
            }
        }
    }
    
    private func configureRecordingWindow() {
        // 配置录音窗口 - 置于顶层，无边框，透明背景
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // 查找所有可能的录音窗口
            let recordingWindows = NSApp.windows.filter { window in
                window.title.contains("录音") || window.identifier?.rawValue == "recording-overlay"
            }
            
            for window in recordingWindows {
                LogManager.shared.info("HelloPromptApp", "配置录音窗口: \(window.title), ID: \(window.windowNumber)")
                
                window.level = .screenSaver  // 始终在顶层
                window.backgroundColor = NSColor.clear
                window.isOpaque = false
                window.hasShadow = false
                window.ignoresMouseEvents = false
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                
                // 居中显示
                if let screen = NSScreen.main {
                    let screenRect = screen.visibleFrame
                    let windowRect = window.frame
                    let x = screenRect.midX - windowRect.width / 2
                    let y = screenRect.midY - windowRect.height / 2
                    window.setFrameOrigin(NSPoint(x: x, y: y))
                }
                
                LogManager.shared.info("HelloPromptApp", "录音窗口配置完成")
                
                // 根据状态决定是否显示窗口
                if self.orbVisible {
                    window.orderFront(nil)
                    window.makeKey()
                    LogManager.shared.info("HelloPromptApp", "录音窗口已显示")
                } else {
                    window.orderOut(nil)
                }
            }
            
            if recordingWindows.isEmpty {
                LogManager.shared.warning("HelloPromptApp", "未找到任何录音窗口")
            }
        }
    }
    
    // MARK: - 结果处理方法
    
    /// 处理结果覆盖层的操作
    private func handleResultAction(_ action: OverlayAction, text: String) {
        LogManager.shared.info("HelloPromptApp", "处理结果操作: \(action.rawValue)")
        
        Task {
            switch action {
            case .insert:
                // 更新AppManager的lastResult为当前编辑的文本，然后插入
                appManager.lastResult = text
                await appManager.insertTextToActiveApplication()
                
            case .copy:
                // 复制到剪贴板
                copyTextToClipboard(text)
                
            case .paste:
                // 粘贴操作 - 简化实现
                LogManager.shared.info("HelloPromptApp", "执行粘贴操作")
                
            case .edit:
                // 编辑操作 - 简化实现
                LogManager.shared.info("HelloPromptApp", "执行编辑操作")
                
            case .save:
                // 保存操作 - 简化实现
                LogManager.shared.info("HelloPromptApp", "执行保存操作")
                
            case .share:
                // 分享操作 - 简化实现
                LogManager.shared.info("HelloPromptApp", "执行分享操作")
                
            case .retry:
                // 重试操作
                await regenerateResult()
                
            case .optimize:
                // 重新优化操作
                await regenerateResult()
                
            case .cancel:
                // 取消操作
                showingResult = false
                currentResult = nil
                
            case .accept:
                // 接受操作 - 插入文本
                appManager.lastResult = text
                await appManager.insertTextToActiveApplication()
                showingResult = false
                currentResult = nil
                
            case .reject:
                // 拒绝操作 - 关闭覆盖层
                showingResult = false
                currentResult = nil
                
            case .modify:
                // 更新当前提示词为编辑后的文本，然后开始修改工作流程
                appManager.lastResult = text
                await appManager.startVoiceModificationWorkflow()
                
            case .regenerate:
                // 重新生成结果
                await regenerateResult()
                
            case .close:
                // 关闭覆盖层
                showingResult = false
                currentResult = nil
            }
        }
    }
    
    /// 复制文本到剪贴板
    private func copyTextToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        LogManager.shared.info("HelloPromptApp", "文本已复制到剪贴板: \(text.prefix(50))...")
    }
    
    /// 重新生成结果
    private func regenerateResult() async {
        guard !appManager.currentPrompt.isEmpty else {
            LogManager.shared.warning("HelloPromptApp", "无法重新生成：原始提示词为空")
            return
        }
        
        // 暂时关闭结果显示
        showingResult = false
        
        // 重新启动语音转换工作流程
        await appManager.startVoiceToPromptWorkflow()
    }
    
    /// 配置结果显示窗口
    private func configureResultWindow() {
        LogManager.shared.info("HelloPromptApp", "配置结果显示窗口")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // 查找结果显示窗口
            let resultWindows = NSApp.windows.filter { window in
                window.title.contains("结果显示") || window.identifier?.rawValue == "result-overlay"
            }
            
            for window in resultWindows {
                LogManager.shared.info("HelloPromptApp", "配置结果窗口: \(window.title)")
                
                window.level = .floating  // 浮动在其他窗口之上
                window.backgroundColor = NSColor.clear
                window.isOpaque = false
                window.hasShadow = true
                window.ignoresMouseEvents = false
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                
                // 居中显示
                if let screen = NSScreen.main {
                    let screenRect = screen.visibleFrame
                    let windowSize = CGSize(width: 600, height: 400) // 默认展开模式大小
                    let x = screenRect.midX - windowSize.width / 2
                    let y = screenRect.midY - windowSize.height / 2
                    window.setFrame(NSRect(origin: CGPoint(x: x, y: y), size: windowSize), display: true)
                }
                
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                NSApp.activate(ignoringOtherApps: true)
                
                LogManager.shared.info("HelloPromptApp", "结果窗口配置完成并显示")
            }
        }
    }
    
    private func getCurrentApplicationContext() -> String {
        return appManager.textInsertionService.getApplicationContext()
    }
}

// MARK: - 应用委托
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var cancellables = Set<AnyCancellable>()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        LogManager.shared.info("AppDelegate", "应用启动完成")
        
        // 立即配置应用激活策略 - 关键修复
        NSApp.setActivationPolicy(.regular)
        LogManager.shared.info("AppDelegate", "设置应用激活策略为regular")
        
        // 强制激活应用并显示界面
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSApp.activate(ignoringOtherApps: true)
            self.showInitialInterface()
            LogManager.shared.info("AppDelegate", "应用已激活并尝试显示界面")
        }
    }
    
    @MainActor
    private func configureActivationPolicy() {
        // 始终使用regular策略确保GUI正常显示
        NSApp.setActivationPolicy(.regular)
        
        // 根据配置决定Dock显示
        if !AppConfigManager.shared.showInDock {
            // 如果不想在Dock显示，可以通过其他方式隐藏，但保持regular策略
            LogManager.shared.info("AppDelegate", "应用配置为不在Dock显示，但保持regular激活策略")
        }
    }
    
    
    private func showInitialInterface() {
        LogManager.shared.info("AppDelegate", "检查并创建初始界面")
        
        // 检查是否有可见窗口
        let visibleWindows = NSApp.windows.filter { $0.isVisible }
        
        if visibleWindows.isEmpty {
            LogManager.shared.info("AppDelegate", "没有发现可见窗口，创建设置窗口")
            
            // 创建设置窗口
            let settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            
            settingsWindow.title = "Hello Prompt v2 - 设置"
            settingsWindow.contentView = NSHostingView(rootView: SettingsView())
            
            // 居中显示
            settingsWindow.center()
            
            // 强制显示窗口
            settingsWindow.makeKeyAndOrderFront(nil)
            settingsWindow.orderFrontRegardless()
            
            LogManager.shared.info("AppDelegate", "设置窗口已创建并显示")
        } else {
            LogManager.shared.info("AppDelegate", "找到 \(visibleWindows.count) 个可见窗口")
            
            // 激活第一个可见窗口
            if let firstWindow = visibleWindows.first {
                firstWindow.makeKeyAndOrderFront(self)
                LogManager.shared.info("AppDelegate", "激活了现有窗口: \(firstWindow.title)")
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        LogManager.shared.info("AppDelegate", "应用即将退出")
        
        // 清理资源
        Task {
            await AppManager.shared.shutdown()
        }
        
        // 取消所有订阅
        cancellables.removeAll()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 当应用被重新激活时显示设置窗口
        if !flag {
            // 创建设置窗口
            let settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow.title = "设置"
            settingsWindow.contentView = NSHostingView(rootView: SettingsView())
            settingsWindow.center()
            settingsWindow.makeKeyAndOrderFront(nil)
        }
        return true
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

// MARK: - 应用信息
extension HelloPromptApp {
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.helloprompt.app"
    }
}