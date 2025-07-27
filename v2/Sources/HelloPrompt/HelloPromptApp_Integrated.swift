//
//  HelloPromptApp_Integrated.swift
//  HelloPrompt
//
//  完全集成增强系统的应用入口
//  使用 EnhancedWorkflowManager, EnhancedPermissionManager, EnhancedAPIValidator, EnhancedLogManager
//

import SwiftUI
import AppKit
import KeyboardShortcuts
import Combine
import AVFAudio
import AVFoundation
import ApplicationServices

// MARK: - 主应用程序结构（完全集成版）
@main
struct HelloPromptApp_Integrated: App {
    
    // MARK: - 增强系统管理器
    @StateObject private var enhancedWorkflowManager: EnhancedWorkflowManager
    @StateObject private var enhancedPermissionManager: EnhancedPermissionManager = .shared
    @StateObject private var enhancedAPIValidator: EnhancedAPIValidator = .init()
    @StateObject private var enhancedLogger: EnhancedLogManager = .shared
    
    // MARK: - 传统系统（向后兼容）
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
    
    // MARK: - 工作流状态
    @State private var currentWorkflowState: WorkflowState = .idle
    @State private var workflowProgress: Double = 0.0
    @State private var workflowDescription: String = ""
    
    // MARK: - 应用委托
    @NSApplicationDelegateAdaptor(AppDelegate_Integrated.self) var appDelegate
    
    init() {
        // 创建增强工作流管理器
        let audioService = AudioService()
        let openAIService = OpenAIService()
        let configManager = AppConfigManager.shared
        let permissionManager = EnhancedPermissionManager.shared
        
        _enhancedWorkflowManager = StateObject(wrappedValue: EnhancedWorkflowManager(
            audioService: audioService,
            openAIService: openAIService,
            configManager: configManager,
            permissionManager: permissionManager
        ))
    }
    
    // MARK: - 主视图
    var body: some Scene {
        // 主设置窗口
        WindowGroup("Hello Prompt v2") {
            SettingsView()
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    setupApplication()
                }
        }
        .commands {
            appMenuCommands
        }
        .defaultSize(width: 800, height: 600)
        
        // 录音覆盖窗口
        WindowGroup("录音", id: "recording-overlay") {
            RecordingOverlayView(
                orbState: $orbState,
                audioLevel: $audioLevel,
                isVisible: $orbVisible,
                onCancel: {
                    cancelCurrentWorkflow()
                }
            )
            .frame(width: 200, height: 200)
            .background(Color.clear)
            .onAppear {
                configureRecordingWindow()
            }
        }
        .windowStyle(.plain)
        
        // 权限申请窗口
        WindowGroup("权限申请", id: "permission-request") {
            if enhancedPermissionManager.shouldShowPermissionWindow {
                PermissionRequestView(
                    onPermissionsGranted: {
                        enhancedLogger.info("HelloPromptApp_Integrated", "权限申请界面报告权限已授权")
                    },
                    onSkipped: {
                        enhancedLogger.info("HelloPromptApp_Integrated", "用户选择跳过权限申请")
                    }
                )
            } else {
                EmptyView()
            }
        }
        .windowResizability(.contentSize)
        
        // 新手引导窗口
        WindowGroup("新手引导", id: "onboarding-wizard") {
            if isShowingOnboarding {
                OnboardingWizardView(
                    onCompleted: {
                        isShowingOnboarding = false
                        enhancedLogger.userActionLog("新手引导已完成")
                        
                        // 标记已完成引导
                        UserDefaults.standard.set(true, forKey: "HelloPrompt_OnboardingCompleted")
                    },
                    onSkipped: {
                        isShowingOnboarding = false
                        enhancedLogger.userActionLog("用户跳过新手引导")
                    }
                )
            } else {
                EmptyView()
            }
        }
        .windowResizability(.contentSize)
        
        // 结果显示窗口
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
                startEnhancedWorkflow()
            }
            .keyboardShortcut("u", modifiers: [.control])
            
            Button("停止录音") {
                cancelCurrentWorkflow()
            }
            .keyboardShortcut(.escape, modifiers: [.option])
        }
    }
    
    // MARK: - 应用启动和初始化
    private func setupApplication() {
        enhancedLogger.startupLog("🚀 Hello Prompt v2 增强版应用启动", component: "HelloPromptApp_Integrated", details: [
            "version": HelloPromptApp_Integrated.appVersion,
            "build": HelloPromptApp_Integrated.buildNumber,
            "bundleId": HelloPromptApp_Integrated.bundleIdentifier,
            "enhanced_systems": true
        ])
        
        // 设置增强权限管理器回调
        setupEnhancedPermissionCallbacks()
        
        // 设置增强工作流管理器回调
        setupEnhancedWorkflowCallbacks()
        
        // 设置快捷键服务
        setupEnhancedHotkeyService()
        
        // 检查新手引导
        checkAndShowEnhancedOnboarding()
        
        // 初始化增强系统
        Task {
            await initializeEnhancedSystems()
        }
    }
    
    private func checkAndShowEnhancedOnboarding() {
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "HelloPrompt_OnboardingCompleted")
        
        if !hasCompletedOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.isShowingOnboarding = true
                enhancedLogger.userActionLog("首次启动，显示新手引导")
            }
        } else {
            enhancedLogger.info("HelloPromptApp_Integrated", "已完成新手引导，跳过")
        }
    }
    
    private func setupEnhancedPermissionCallbacks() {
        enhancedPermissionManager.onPermissionChanged = { event in
            enhancedLogger.info("HelloPromptApp_Integrated", "权限变化事件：\(event.type.displayName) \((event.oldStatus.statusText)) → \((event.newStatus.statusText))")
            
            // 权限授权后的处理
            if event.newStatus.isGranted && event.oldStatus != .granted {
                Task {
                    await handleEnhancedPermissionGranted(event.type)
                }
            }
        }
        
        enhancedPermissionManager.onAllPermissionsReady = {
            enhancedLogger.info("HelloPromptApp_Integrated", "🎉 所有必需权限已就绪")
        }
    }
    
    private func setupEnhancedWorkflowCallbacks() {
        enhancedWorkflowManager.onWorkflowStarted = { workflowId in
            enhancedLogger.userActionLog("🚀 增强工作流已启动", metadata: ["workflow_id": workflowId.uuidString])
            updateUIForWorkflowState(.recording)
        }
        
        enhancedWorkflowManager.onWorkflowCompleted = { result in
            enhancedLogger.info("HelloPromptApp_Integrated", "🎉 增强工作流完成", metadata: [
                "processing_time": result.processingTime,
                "transcribed_length": result.transcribedText.count,
                "optimized_length": result.optimizedText.count
            ])
            
            showEnhancedResult(result)
            updateUIForWorkflowState(.completed)
        }
        
        enhancedWorkflowManager.onWorkflowFailed = { error in
            enhancedLogger.error("HelloPromptApp_Integrated", "💥 增强工作流失败: \(error.localizedDescription)")
            updateUIForWorkflowState(.error)
        }
        
        enhancedWorkflowManager.onStateChanged = { oldState, newState in
            enhancedLogger.debug("HelloPromptApp_Integrated", "🔄 工作流状态: \(oldState.displayName) → \(newState.displayName)")
            
            // 同步UI状态
            DispatchQueue.main.async {
                self.currentWorkflowState = newState
                self.workflowProgress = enhancedWorkflowManager.progress
                self.workflowDescription = enhancedWorkflowManager.currentStepDescription
                self.orbVisible = enhancedWorkflowManager.overlayVisible
                
                // 更新悬浮球状态
                switch newState {
                case .idle:
                    self.orbState = .idle
                case .recording:
                    self.orbState = .recording
                case .processingAudio, .transcribing, .optimizing:
                    self.orbState = .processing
                case .displaying:
                    self.orbState = .success
                case .completed:
                    self.orbState = .idle
                case .error:
                    self.orbState = .error
                }
            }
        }
    }
    
    private func setupEnhancedHotkeyService() {
        enhancedLogger.info("HelloPromptApp_Integrated", "设置增强版Ctrl+U快捷键监听服务")
        
        // 设置快捷键回调使用增强工作流
        hotkeyService.onCtrlURecordingStart = {
            Task {
                await self.startEnhancedWorkflow()
            }
        }
        
        hotkeyService.onCtrlURecordingStop = {
            Task {
                await self.stopEnhancedWorkflow()
            }
        }
        
        enhancedLogger.info("HelloPromptApp_Integrated", "增强版快捷键服务设置完成")
    }
    
    @MainActor
    private func handleEnhancedPermissionGranted(_ type: PermissionType) async {
        enhancedLogger.info("HelloPromptApp_Integrated", "处理权限授权：\(type.displayName)")
        
        switch type {
        case .microphone:
            // 麦克风权限授权后，可以初始化音频服务
            try? await enhancedWorkflowManager.audioService.initialize()
            
        case .accessibility:
            // 辅助功能权限授权后，可以启用全局快捷键
            setupEnhancedGlobalHotkeys()
            hotkeyService.reinitializeEventTap()
            
        case .notification:
            enhancedLogger.info("HelloPromptApp_Integrated", "通知权限已授权")
        }
    }
    
    // MARK: - 增强系统初始化
    @MainActor
    private func initializeEnhancedSystems() async {
        enhancedLogger.info("HelloPromptApp_Integrated", "开始初始化增强系统")
        
        // 检查权限
        await enhancedPermissionManager.checkAllPermissionsEnhanced(reason: "应用启动")
        
        // 验证API配置
        await validateAPIConfiguration()
        
        // 设置全局快捷键（如果有辅助功能权限）
        if enhancedPermissionManager.permissionStates[.accessibility]?.status.isGranted == true {
            setupEnhancedGlobalHotkeys()
        }
        
        // 设置状态监听
        setupEnhancedStateObservation()
        
        enhancedLogger.info("HelloPromptApp_Integrated", "增强系统初始化完成")
    }
    
    // MARK: - API配置验证
    private func validateAPIConfiguration() async {
        enhancedLogger.info("HelloPromptApp_Integrated", "开始验证API配置")
        
        let apiKey = configManager.openAIAPIKey ?? ""
        let baseURL = configManager.openAIBaseURL
        
        guard !apiKey.isEmpty else {
            enhancedLogger.warning("HelloPromptApp_Integrated", "API密钥为空，跳过验证")
            return
        }
        
        let result = await enhancedAPIValidator.validateAPIConfiguration(
            apiKey: apiKey,
            baseURL: baseURL,
            organizationId: configManager.openAIOrganization
        )
        
        if result.isValid {
            enhancedLogger.info("HelloPromptApp_Integrated", "✅ API配置验证通过")
        } else {
            enhancedLogger.error("HelloPromptApp_Integrated", "❌ API配置验证失败: \(result.error?.localizedDescription ?? "未知错误")")
        }
    }
    
    // MARK: - 增强工作流管理
    
    /// 开始增强工作流
    private func startEnhancedWorkflow() {
        enhancedLogger.userActionLog("开始增强工作流")
        
        // 检查是否可以开始工作流
        let readiness = enhancedWorkflowManager.canStartWorkflow()
        guard readiness.canStart else {
            enhancedLogger.warning("HelloPromptApp_Integrated", "无法开始工作流: \(readiness.reason ?? "未知原因")")
            return
        }
        
        // 显示录音界面
        orbVisible = true
        
        Task {
            await enhancedWorkflowManager.startVoiceToTextWorkflow()
        }
    }
    
    /// 停止增强工作流
    private func stopEnhancedWorkflow() async {
        enhancedLogger.userActionLog("停止增强工作流")
        await enhancedWorkflowManager.cancelWorkflow()
    }
    
    /// 取消当前工作流
    private func cancelCurrentWorkflow() {
        Task {
            await enhancedWorkflowManager.cancelWorkflow()
        }
    }
    
    // MARK: - 快捷键设置
    private func setupEnhancedGlobalHotkeys() {
        let hotkeyHandlers: [HotkeyIdentifier: () -> Void] = [
            .startRecording: startEnhancedWorkflow,
            .stopRecording: cancelCurrentWorkflow,
            .retryRecording: retryEnhancedWorkflow,
            .insertResult: insertLastResult,
            .copyResult: copyLastResult,
            .showSettings: showSettings,
            .togglePause: togglePause,
            .cancelOperation: cancelOperation
        ]
        
        for (identifier, handler) in hotkeyHandlers {
            let defaultShortcut: KeyboardShortcut
            switch identifier {
            case .startRecording:
                defaultShortcut = KeyboardShortcut("u", modifiers: [.control])
            case .stopRecording:
                defaultShortcut = KeyboardShortcut(.escape, modifiers: [.option])
            default:
                defaultShortcut = KeyboardShortcut(.space, modifiers: [.control, .shift])
            }
            
            _ = hotkeyService.registerHotkey(identifier, shortcut: defaultShortcut, handler: handler)
        }
        
        enhancedLogger.info("HelloPromptApp_Integrated", "增强版全局快捷键已设置")
    }
    
    // MARK: - 状态监听
    private func setupEnhancedStateObservation() {
        // 监听工作流状态变化
        enhancedWorkflowManager.$currentState
            .receive(on: DispatchQueue.main)
            .sink { newState in
                updateUIForWorkflowState(newState)
            }
            .store(in: &appDelegate.cancellables)
        
        // 监听权限状态变化
        enhancedPermissionManager.$permissionStates
            .receive(on: DispatchQueue.main)
            .sink { states in
                let accessibilityGranted = states[.accessibility]?.status.isGranted ?? false
                let microphoneGranted = states[.microphone]?.status.isGranted ?? false
                
                enhancedLogger.debug("HelloPromptApp_Integrated", "权限状态更新 - 辅助功能: \(accessibilityGranted), 麦克风: \(microphoneGranted)")
                
                if accessibilityGranted && !hotkeyService.isEnabled {
                    enhancedLogger.info("HelloPromptApp_Integrated", "辅助功能权限已授权，重新初始化快捷键服务")
                    hotkeyService.reinitializeEventTap()
                }
                
                if microphoneGranted {
                    try? await enhancedWorkflowManager.audioService.initialize()
                }
            }
            .store(in: &appDelegate.cancellables)
        
        enhancedLogger.debug("HelloPromptApp_Integrated", "👁️ 增强状态观察器已设置")
    }
    
    private func updateUIForWorkflowState(_ state: WorkflowState) {
        currentWorkflowState = state
        
        switch state {
        case .idle:
            orbState = .idle
            orbVisible = false
        case .recording:
            orbState = .recording
            orbVisible = true
        case .processingAudio, .transcribing, .optimizing:
            orbState = .processing
            orbVisible = true
        case .displaying:
            orbState = .success
            orbVisible = true
        case .completed:
            orbState = .idle
            orbVisible = false
        case .error:
            orbState = .error
            orbVisible = false
        }
    }
    
    // MARK: - 结果处理
    private func showEnhancedResult(_ workflowResult: WorkflowResult) {
        let overlayResult = OverlayResult(
            originalText: workflowResult.transcribedText,
            optimizedText: workflowResult.optimizedText,
            confidence: 0.95,
            processingTime: workflowResult.processingTime,
            timestamp: Date()
        )
        
        currentResult = overlayResult
        showingResult = true
        
        enhancedLogger.info("HelloPromptApp_Integrated", """
            显示增强工作流结果:
            原始文本: \(workflowResult.transcribedText.prefix(50))...
            优化文本: \(workflowResult.optimizedText.prefix(50))...
            处理时间: \(String(format: "%.2f", workflowResult.processingTime))s
            """)
    }
    
    // MARK: - 操作处理
    private func retryEnhancedWorkflow() {
        Task {
            await enhancedWorkflowManager.forceReset()
            await enhancedWorkflowManager.startVoiceToTextWorkflow()
        }
    }
    
    private func insertLastResult() {
        Task {
            if let result = enhancedWorkflowManager.lastResult {
                let text = result.optimizedText
                await appManager.insertTextToActiveApplication()
                enhancedLogger.userActionLog("插入文本到当前应用", metadata: ["text_length": text.count])
            }
        }
    }
    
    private func copyLastResult() {
        if let result = enhancedWorkflowManager.lastResult {
            let text = result.optimizedText
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            
            enhancedLogger.userActionLog("复制结果到剪贴板", metadata: ["text_length": text.count])
        }
    }
    
    private func togglePause() {
        enhancedLogger.userActionLog("切换暂停状态")
    }
    
    private func cancelOperation() {
        cancelCurrentWorkflow()
    }
    
    // MARK: - UI控制
    private func showSettings() {
        isShowingSettings = true
        enhancedLogger.userActionLog("显示设置界面")
    }
    
    private func showOnboarding() {
        isShowingOnboarding = true
        enhancedLogger.userActionLog("显示新手引导")
    }
    
    private func showAbout() {
        let aboutPanel = NSAlert()
        aboutPanel.messageText = "Hello Prompt v2 (增强版)"
        aboutPanel.informativeText = """
        版本 2.0.0 (增强版)
        
        AI驱动的语音转提示词工具
        集成增强工作流、权限管理、API验证和日志系统
        
        © 2024 Hello Prompt Team
        """
        aboutPanel.alertStyle = .informational
        aboutPanel.addButton(withTitle: "确定")
        aboutPanel.runModal()
    }
    
    private func configureRecordingWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let recordingWindows = NSApp.windows.filter { window in
                window.title.contains("录音") || window.identifier?.rawValue == "recording-overlay"
            }
            
            for window in recordingWindows {
                window.level = .screenSaver
                window.backgroundColor = NSColor.clear
                window.isOpaque = false
                window.hasShadow = false
                window.ignoresMouseEvents = false
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                
                if let screen = NSScreen.main {
                    let screenRect = screen.visibleFrame
                    let windowRect = window.frame
                    let x = screenRect.midX - windowRect.width / 2
                    let y = screenRect.midY - windowRect.height / 2
                    window.setFrameOrigin(NSPoint(x: x, y: y))
                }
                
                if self.orbVisible {
                    window.orderFront(nil)
                    window.makeKey()
                } else {
                    window.orderOut(nil)
                }
            }
        }
    }
    
    private func configureResultWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let resultWindows = NSApp.windows.filter { window in
                window.title.contains("结果显示") || window.identifier?.rawValue == "result-overlay"
            }
            
            for window in resultWindows {
                window.level = .floating
                window.backgroundColor = NSColor.clear
                window.isOpaque = false
                window.hasShadow = true
                window.ignoresMouseEvents = false
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                
                if let screen = NSScreen.main {
                    let screenRect = screen.visibleFrame
                    let windowSize = CGSize(width: 600, height: 400)
                    let x = screenRect.midX - windowSize.width / 2
                    let y = screenRect.midY - windowSize.height / 2
                    window.setFrame(NSRect(origin: CGPoint(x: x, y: y), size: windowSize), display: true)
                }
                
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    // MARK: - 结果处理
    private func handleResultAction(_ action: OverlayAction, text: String) {
        enhancedLogger.userActionLog("处理结果操作: \(action.rawValue)")
        
        Task {
            switch action {
            case .insert:
                await appManager.insertTextToActiveApplication()
                
            case .copy:
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
                enhancedLogger.userActionLog("文本已复制到剪贴板", metadata: ["text_length": text.count])
                
            case .accept:
                await appManager.insertTextToActiveApplication()
                showingResult = false
                currentResult = nil
                
            case .close, .cancel:
                showingResult = false
                currentResult = nil
                
            default:
                enhancedLogger.debug("HelloPromptApp_Integrated", "未处理的操作: \(action.rawValue)")
            }
        }
    }
}

// MARK: - 应用委托（增强版）
class AppDelegate_Integrated: NSObject, NSApplicationDelegate, ObservableObject {
    var cancellables = Set<AnyCancellable>()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        EnhancedLogManager.shared.startupLog("增强版应用启动完成", component: "AppDelegate_Integrated")
        
        // 立即配置应用激活策略
        NSApp.setActivationPolicy(.regular)
        
        // 强制激活应用
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSApp.activate(ignoringOtherApps: true)
            self.showInitialInterface()
        }
    }
    
    @MainActor
    private func showInitialInterface() {
        let visibleWindows = NSApp.windows.filter { $0.isVisible }
        
        if visibleWindows.isEmpty {
            EnhancedLogManager.shared.info("AppDelegate_Integrated", "创建初始设置窗口")
            
            let settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            
            settingsWindow.title = "Hello Prompt v2 - 设置 (增强版)"
            settingsWindow.contentView = NSHostingView(rootView: SettingsView())
            settingsWindow.center()
            settingsWindow.makeKeyAndOrderFront(nil)
        } else {
            if let firstWindow = visibleWindows.first {
                firstWindow.makeKeyAndOrderFront(self)
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        EnhancedLogManager.shared.info("AppDelegate_Integrated", "应用即将退出")
        
        Task {
            await AppManager.shared.shutdown()
            EnhancedLogManager.shared.flush()
        }
        
        cancellables.removeAll()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            let settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow.title = "设置 (增强版)"
            settingsWindow.contentView = NSHostingView(rootView: SettingsView())
            settingsWindow.center()
            settingsWindow.makeKeyAndOrderFront(nil)
        }
        return true
    }
}

// MARK: - 应用信息扩展
extension HelloPromptApp_Integrated {
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.0"
    }
    
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "2"
    }
    
    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.helloprompt.app.enhanced"
    }
}