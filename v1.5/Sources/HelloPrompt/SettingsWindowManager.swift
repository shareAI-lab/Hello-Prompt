//
//  SettingsWindowManager.swift
//  HelloPrompt
//
//  设置窗口管理器 - AppKit窗口包装SwiftUI设置界面
//  Copyright © 2025 HelloPrompt. All rights reserved.
//

import Foundation
import AppKit
import SwiftUI

// MARK: - 设置窗口管理器
@MainActor
class SettingsWindowManager: NSObject {
    static let shared = SettingsWindowManager()
    
    private var settingsWindow: NSWindow?
    private var hostingController: NSHostingController<SettingsView>?
    
    private override init() {
        super.init()
        LogManager.shared.info(.app, "SettingsWindowManager初始化完成")
    }
    
    /// 显示设置窗口
    func showSettings() {
        if settingsWindow == nil {
            createSettingsWindow()
        }
        
        guard let window = settingsWindow else {
            LogManager.shared.error(.app, "设置窗口创建失败")
            return
        }
        
        // 将窗口置于屏幕中央
        window.center()
        
        // 显示窗口并激活应用
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        LogManager.shared.info(.app, "设置窗口已显示")
    }
    
    /// 隐藏设置窗口
    func hideSettings() {
        settingsWindow?.orderOut(nil)
        LogManager.shared.info(.app, "设置窗口已隐藏")
    }
    
    /// 关闭设置窗口
    func closeSettings() {
        settingsWindow?.close()
        settingsWindow = nil
        hostingController = nil
        LogManager.shared.info(.app, "设置窗口已关闭")
    }
    
    // MARK: - Private Methods
    
    /// 创建设置窗口
    private func createSettingsWindow() {
        // 创建SwiftUI视图
        let settingsView = SettingsView()
        hostingController = NSHostingController(rootView: settingsView)
        
        guard let hostingController = hostingController else {
            LogManager.shared.error(.app, "HostingController创建失败")
            return
        }
        
        // 创建窗口
        settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        guard let window = settingsWindow else {
            LogManager.shared.error(.app, "设置窗口创建失败")
            return
        }
        
        // 配置窗口属性
        window.contentViewController = hostingController
        window.title = "Hello Prompt 设置"
        window.minSize = NSSize(width: 500, height: 400)
        window.maxSize = NSSize(width: 800, height: 600)
        
        // 设置窗口图标
        if let appIcon = NSApp.applicationIconImage {
            window.representedURL = nil
            window.standardWindowButton(.documentIconButton)?.image = appIcon
        }
        
        // 设置窗口委托
        window.delegate = self
        
        // 设置窗口级别（普通窗口）
        window.level = .normal
        
        // 允许窗口在空间之间移动
        window.collectionBehavior = [.moveToActiveSpace]
        
        LogManager.shared.info(.app, "设置窗口创建完成", metadata: [
            "size": "600x500",
            "resizable": true,
            "hasDelegate": true
        ])
    }
}

// MARK: - 窗口委托
extension SettingsWindowManager: NSWindowDelegate {
    
    func windowWillClose(_ notification: Notification) {
        LogManager.shared.info(.app, "设置窗口即将关闭")
        
        // 保存配置
        ConfigurationManager.shared.saveConfiguration()
        
        // 清理资源
        settingsWindow = nil
        hostingController = nil
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        LogManager.shared.debug(.app, "设置窗口变为主窗口")
    }
    
    func windowDidResignKey(_ notification: Notification) {
        LogManager.shared.debug(.app, "设置窗口失去主窗口状态")
    }
    
    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        
        LogManager.shared.debug(.app, "设置窗口大小变化", metadata: [
            "newSize": "\(Int(window.frame.width))x\(Int(window.frame.height))"
        ])
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // 总是允许关闭
        return true
    }
}

// MARK: - 开机自启动管理器
@MainActor
class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()
    
    private let launchAgentURL: URL
    private let bundleIdentifier = "com.helloprompt.app"
    
    private init() {
        let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let launchAgentsURL = libraryURL.appendingPathComponent("LaunchAgents")
        launchAgentURL = launchAgentsURL.appendingPathComponent("\(bundleIdentifier).plist")
        
        // 确保LaunchAgents目录存在
        try? FileManager.default.createDirectory(at: launchAgentsURL, withIntermediateDirectories: true)
    }
    
    /// 启用开机自启动
    func enable() {
        guard let executablePath = Bundle.main.executablePath else {
            LogManager.shared.error(.app, "无法获取应用可执行文件路径")
            return
        }
        
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(bundleIdentifier)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(executablePath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
        </dict>
        </plist>
        """
        
        do {
            try plistContent.write(to: launchAgentURL, atomically: true, encoding: .utf8)
            
            // 加载LaunchAgent
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["load", launchAgentURL.path]
            
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                LogManager.shared.info(.app, "开机自启动已启用")
            } else {
                LogManager.shared.error(.app, "开机自启动启用失败", metadata: [
                    "exitCode": process.terminationStatus
                ])
            }
            
        } catch {
            LogManager.shared.error(.app, "开机自启动配置失败", metadata: [
                "error": error.localizedDescription
            ])
        }
    }
    
    /// 禁用开机自启动
    func disable() {
        // 卸载LaunchAgent
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["unload", launchAgentURL.path]
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            LogManager.shared.warning(.app, "LaunchAgent卸载失败", metadata: [
                "error": error.localizedDescription
            ])
        }
        
        // 删除plist文件
        do {
            if FileManager.default.fileExists(atPath: launchAgentURL.path) {
                try FileManager.default.removeItem(at: launchAgentURL)
                LogManager.shared.info(.app, "开机自启动已禁用")
            }
        } catch {
            LogManager.shared.error(.app, "LaunchAgent文件删除失败", metadata: [
                "error": error.localizedDescription
            ])
        }
    }
    
    /// 检查是否已启用开机自启动
    var isEnabled: Bool {
        return FileManager.default.fileExists(atPath: launchAgentURL.path)
    }
}