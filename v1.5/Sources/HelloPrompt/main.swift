//
//  main.swift
//  HelloPrompt
//
//  程序入口 - 初始化应用并启动主循环
//  Copyright © 2025 HelloPrompt. All rights reserved.
//

import Foundation
import AppKit
import AVFoundation

// 初始化NSApplication
let app = NSApplication.shared
app.setActivationPolicy(.regular)

// 设置应用代理
let appDelegate = HelloPromptAppDelegate()
app.delegate = appDelegate

// 启动应用主循环
app.run()

// MARK: - 应用代理
@MainActor
class HelloPromptAppDelegate: NSObject, NSApplicationDelegate {
    
    private var appManager: RealAppManager?
    
    // MARK: - Application Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 首先初始化日志系统和配置管理器
        initializeCore()
        
        // 设置应用图标和基本信息
        setupApplicationInfo()
        
        // 检查是否需要首次配置
        let configManager = ConfigurationManager.shared
        if configManager.needsInitialSetup {
            LogManager.shared.info(.app, "检测到需要首次配置，显示配置界面")
            showFirstLaunchFlow()
        } else {
            LogManager.shared.info(.app, "配置已完成，直接启动应用")
            normalStartup()
        }
        
        LogManager.shared.info(.app, "Hello Prompt启动完成")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        LogManager.shared.info(.app, "Hello Prompt即将退出")
        
        // 清理资源
        cleanup()
        
        LogManager.shared.info(.app, "Hello Prompt已退出")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 不在最后一个窗口关闭时退出应用（保持后台运行）
        return false
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        LogManager.shared.debug(.app, "应用变为活跃状态")
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        LogManager.shared.debug(.app, "应用失去活跃状态")
    }
    
    // MARK: - Private Methods
    
    /// 设置应用基本信息
    private func setupApplicationInfo() {
        let _ = NSApplication.shared
        
        // 设置应用名称
        if let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String {
            LogManager.shared.info(.app, "应用名称", metadata: ["name": bundleName])
        }
        
        // 设置版本信息
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            LogManager.shared.info(.app, "版本信息", metadata: [
                "version": version,
                "build": build
            ])
        }
        
        // 防止应用在Dock中显示（可选）
        // app.setActivationPolicy(.accessory)
        
        LogManager.shared.info(.app, "应用信息设置完成")
    }
    
    /// 检查系统权限
    private func checkSystemPermissions() {
        LogManager.shared.info(.app, "检查系统权限")
        
        // 检查辅助功能权限
        let accessibilityEnabled = AXIsProcessTrusted()
        if !accessibilityEnabled {
            LogManager.shared.warning(.app, "辅助功能权限未启用", metadata: [
                "message": "需要在系统偏好设置 > 安全性与隐私 > 辅助功能中启用Hello Prompt"
            ])
            
            // 显示权限请求对话框
            showPermissionAlert()
        } else {
            LogManager.shared.info(.app, "辅助功能权限已启用")
        }
        
        // 检查麦克风权限
        checkMicrophonePermission()
        
        LogManager.shared.info(.app, "系统权限检查完成")
    }
    
    /// 检查麦克风权限
    private func checkMicrophonePermission() {
        // 在macOS上，我们使用AVCaptureDevice来检查麦克风权限
        let authStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch authStatus {
        case .authorized:
            LogManager.shared.info(.app, "麦克风权限已授予")
        case .denied, .restricted:
            LogManager.shared.warning(.app, "麦克风权限被拒绝")
            showMicrophonePermissionAlert()
        case .notDetermined:
            LogManager.shared.info(.app, "麦克风权限未确定，将在首次使用时请求")
        @unknown default:
            LogManager.shared.warning(.app, "未知的麦克风权限状态")
        }
    }
    
    /// 显示权限请求对话框
    private func showPermissionAlert() {
        // 不阻塞主线程，异步显示对话框
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "需要辅助功能权限"
            alert.informativeText = "Hello Prompt需要辅助功能权限来实现文本插入功能。您可以稍后在系统偏好设置中启用此权限。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "稍后设置")
            alert.addButton(withTitle: "打开系统偏好设置")
            
            // 使用beginSheetModal避免阻塞
            if let window = NSApp.mainWindow {
                alert.beginSheetModal(for: window) { response in
                    if response == .alertSecondButtonReturn {
                        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                        NSWorkspace.shared.open(url)
                    }
                }
            } else {
                let response = alert.runModal()
                if response == .alertSecondButtonReturn {
                    let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
    
    /// 显示麦克风权限对话框
    private func showMicrophonePermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "需要麦克风权限"
            alert.informativeText = "Hello Prompt需要麦克风权限来录制语音。请在系统偏好设置中启用此权限。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "打开系统偏好设置")
            alert.addButton(withTitle: "稍后设置")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // 打开系统偏好设置的隐私页面
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    /// 初始化核心系统
    private func initializeCore() {
        LogManager.shared.initialize(level: .debug)
        LogManager.shared.info(.app, "Hello Prompt启动")
        
        // 配置管理器会自动初始化
        let configManager = ConfigurationManager.shared
        LogManager.shared.info(.app, "配置管理器已初始化", metadata: [
            "isFirstLaunch": configManager.configuration.isFirstLaunch,
            "needsSetup": configManager.needsInitialSetup
        ])
    }
    
    /// 显示首次启动流程
    private func showFirstLaunchFlow() {
        LogManager.shared.info(.app, "显示首次启动流程")
        
        // 显示首次配置界面
        FirstLaunchWindowManager.shared.showFirstLaunch { [weak self] completed in
            if completed {
                self?.normalStartup()
            } else {
                // 用户取消了首次配置，退出应用
                NSApp.terminate(nil)
            }
        }
    }
    
    /// 正常启动流程
    private func normalStartup() {
        // 检查系统权限
        checkSystemPermissions()
        
        // 初始化应用管理器
        initializeAppManager()
        
        // 启动应用
        startApplication()
    }
    
    /// 初始化应用管理器
    private func initializeAppManager() {
        LogManager.shared.info(.app, "🚀 开始初始化应用管理器")
        
        let startTime = Date()
        appManager = RealAppManager()
        let initDuration = Date().timeIntervalSince(startTime)
        
        LogManager.shared.info(.app, "✅ 应用管理器初始化成功", metadata: [
            "initDuration": String(format: "%.3f秒", initDuration)
        ])
    }
    
    /// 启动应用
    private func startApplication() {
        guard let appManager = appManager else {
            LogManager.shared.error(.app, "应用管理器未初始化")
            return
        }
        
        LogManager.shared.info(.app, "🚀 启动Hello Prompt核心功能")
        
        // 使用Task确保异步启动不阻塞主线程
        Task { @MainActor in
            do {
                LogManager.shared.info(.app, "📋 开始异步启动应用管理器")
                let startTime = Date()
                
                // 启动应用管理器
                await appManager.startAsync()
                
                let startupDuration = Date().timeIntervalSince(startTime)
                LogManager.shared.info(.app, "✅ 应用管理器异步启动完成", metadata: [
                    "startupDuration": String(format: "%.3f秒", startupDuration)
                ])
                
                // 设置菜单栏
                LogManager.shared.info(.app, "📋 设置菜单栏")
                setupMenuBar()
                
                LogManager.shared.info(.app, "🎉 Hello Prompt核心功能启动完成")
                
            } catch {
                LogManager.shared.error(.app, "启动应用管理器失败", metadata: [
                    "error": error.localizedDescription
                ])
            }
        }
        
        // 立即设置菜单栏作为备用，确保基本功能可用
        LogManager.shared.info(.app, "📋 设置基础菜单栏")
        setupMenuBar()
    }
    
    /// 设置菜单栏
    private func setupMenuBar() {
        let mainMenu = NSMenu()
        
        // 应用菜单
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        
        appMenu.addItem(withTitle: "关于 Hello Prompt", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "设置...", action: #selector(showSettings), keyEquivalent: ",")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "隐藏 Hello Prompt", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "隐藏其他", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h").keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "显示全部", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "退出 Hello Prompt", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        // 控制菜单
        let controlMenuItem = NSMenuItem(title: "控制", action: nil, keyEquivalent: "")
        let controlMenu = NSMenu(title: "控制")
        
        controlMenu.addItem(withTitle: "开始录音", action: #selector(startRecording), keyEquivalent: "r")
        controlMenu.addItem(withTitle: "停止录音", action: #selector(stopRecording), keyEquivalent: "s")
        controlMenu.addItem(NSMenuItem.separator())
        controlMenu.addItem(withTitle: "显示悬浮球", action: #selector(toggleFloatingBall), keyEquivalent: "f")
        
        controlMenuItem.submenu = controlMenu
        mainMenu.addItem(controlMenuItem)
        
        // 帮助菜单
        let helpMenuItem = NSMenuItem(title: "帮助", action: nil, keyEquivalent: "")
        let helpMenu = NSMenu(title: "帮助")
        
        helpMenu.addItem(withTitle: "Hello Prompt 帮助", action: #selector(showHelp), keyEquivalent: "?")
        
        helpMenuItem.submenu = helpMenu
        mainMenu.addItem(helpMenuItem)
        
        NSApplication.shared.mainMenu = mainMenu
        
        LogManager.shared.info(.app, "菜单栏设置完成")
    }
    
    /// 清理资源
    private func cleanup() {
        LogManager.shared.info(.app, "清理应用资源")
        
        // 清理应用管理器
        appManager = nil
        
        LogManager.shared.info(.app, "应用资源清理完成")
    }
    
    // MARK: - Menu Actions
    
    @objc private func showAbout() {
        let aboutPanel = NSAlert()
        aboutPanel.messageText = "Hello Prompt"
        aboutPanel.informativeText = "语音转AI提示词工具\n\n版本：1.0.0\n构建：1\n\n© 2025 Hello Prompt. All rights reserved."
        aboutPanel.alertStyle = .informational
        aboutPanel.addButton(withTitle: "确定")
        aboutPanel.runModal()
        
        LogManager.shared.info(.app, "显示关于对话框")
    }
    
    @objc private func showSettings() {
        appManager?.showSettings()
        LogManager.shared.info(.app, "显示设置")
    }
    
    @objc private func startRecording() {
        appManager?.startRecording()
        LogManager.shared.info(.app, "菜单栏开始录音")
    }
    
    @objc private func stopRecording() {
        appManager?.stopRecording()
        LogManager.shared.info(.app, "菜单栏停止录音")
    }
    
    @objc private func toggleFloatingBall() {
        appManager?.toggleFloatingBall()
        LogManager.shared.info(.app, "菜单栏切换悬浮球")
    }
    
    @objc private func showHelp() {
        // 打开帮助URL或显示帮助对话框
        let helpAlert = NSAlert()
        helpAlert.messageText = "Hello Prompt 帮助"
        helpAlert.informativeText = """
        快捷键：
        • ⌘⇧⌥R - 开始/停止录音
        • ⌘⇧⌥S - 显示设置
        • ⌘⇧⌥F - 显示/隐藏悬浮球
        • ⌘⇧⌥U - 快速优化剪贴板文本
        
        使用方法：
        1. 点击悬浮球开始录音
        2. 说出要转换的语音内容
        3. 再次点击停止录音
        4. 选择使用识别结果或优化后的提示词
        
        权限要求：
        • 麦克风权限：录制语音
        • 辅助功能权限：插入文本到其他应用
        """
        helpAlert.alertStyle = .informational
        helpAlert.addButton(withTitle: "确定")
        helpAlert.runModal()
        
        LogManager.shared.info(.app, "显示帮助")
    }
}