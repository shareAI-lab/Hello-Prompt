//
//  ModernGlobalShortcuts.swift
//  HelloPrompt
//
//  现代化全局快捷键管理器 - 使用CGEventTap实现，兼容macOS 2025
//  Copyright © 2025 HelloPrompt. All rights reserved.
//

import Foundation
import AppKit
import Carbon

// MARK: - 现代快捷键配置
struct ModernShortcutEntry {
    let id: String
    let name: String
    let keyCode: Int64
    let modifierFlags: CGEventFlags
    let description: String
    
    init(id: String, name: String, keyCode: Int64, modifierFlags: CGEventFlags, description: String) {
        self.id = id
        self.name = name
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
        self.description = description
    }
    
    /// 创建简化的快捷键配置（使用简单的 Command+U）
    static func createModernDefaults() -> [ModernShortcutEntry] {
        return [
            ModernShortcutEntry(
                id: "start_recording",
                name: "语音录制",
                keyCode: 46, // M key
                modifierFlags: [.maskControl],
                description: "⌃M - 开始/停止语音录制和转换"
            )
        ]
    }
}

// MARK: - 现代快捷键事件处理协议
@MainActor
protocol ModernGlobalShortcutsDelegate: AnyObject {
    func modernGlobalShortcuts(_ shortcuts: ModernGlobalShortcuts, didTrigger shortcutId: String)
    func modernGlobalShortcuts(_ shortcuts: ModernGlobalShortcuts, didFailToSetup error: Error)
}

// MARK: - 现代全局快捷键管理器
@MainActor
class ModernGlobalShortcuts: NSObject {
    
    // MARK: - Properties
    weak var delegate: ModernGlobalShortcutsDelegate?
    
    private var shortcuts: [String: ModernShortcutEntry] = [:]
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isEnabled = false
    private var permissionRetryTimer: Timer?
    
    // MARK: - Initialization
    override init() {
        super.init()
        
        LogManager.shared.info(.shortcuts, "ModernGlobalShortcuts基础初始化")
        
        // 加载现代化快捷键配置
        loadModernShortcuts()
        
        // 异步完成初始化
        Task { @MainActor in
            await completeInitializationAsync()
        }
    }
    
    deinit {
        cleanupSync()
    }
    
    // MARK: - Public Methods
    
    /// 检查输入监控权限
    func checkInputMonitoringPermission() -> Bool {
        // 检查Input Monitoring权限
        let permission = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        let hasPermission = permission
        
        LogManager.shared.info(.shortcuts, "输入监控权限检查", metadata: [
            "hasPermission": hasPermission,
            "rawStatus": permission
        ])
        
        return hasPermission
    }
    
    /// 请求输入监控权限
    func requestInputMonitoringPermission() {
        LogManager.shared.info(.shortcuts, "主动请求输入监控权限")
        
        // 主动请求权限
        let _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        
        // 如果权限未授予，延迟显示引导界面
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !IOHIDRequestAccess(kIOHIDRequestTypeListenEvent) {
                self.showPermissionAlert()
            }
        }
    }
    
    /// 启用现代化快捷键
    func enable() {
        guard !isEnabled else {
            LogManager.shared.warning(.shortcuts, "快捷键已启用，跳过重复启用")
            return
        }
        
        LogManager.shared.info(.shortcuts, "启用现代化全局快捷键")
        
        // 主动请求权限
        requestInputMonitoringPermission()
        
        LogManager.shared.info(.shortcuts, "快捷键配置", metadata: [
            "shortcut": "Ctrl+M",
            "keyCode": 46,
            "description": "开始/停止语音录制和转换"
        ])
        
        // 检查权限
        guard checkInputMonitoringPermission() else {
            LogManager.shared.warning(.shortcuts, "缺少输入监控权限，将在权限授予后自动启用")
            
            // 启动定期重试机制
            startPermissionRetryTimer()
            
            // 不将权限缺失视为错误，而是等待用户授权
            return
        }
        
        // 设置事件监听
        setupEventTap()
        
        isEnabled = true
        
        // 成功启用后停止重试定时器
        stopPermissionRetryTimer()
        
        LogManager.shared.info(.shortcuts, "现代化全局快捷键启用成功")
    }
    
    /// 禁用快捷键
    func disable() {
        guard isEnabled else { return }
        
        cleanup()
        isEnabled = false
        
        LogManager.shared.info(.shortcuts, "禁用现代化全局快捷键")
    }
    
    /// 获取所有快捷键配置
    func getAllShortcuts() -> [ModernShortcutEntry] {
        return Array(shortcuts.values).sorted { $0.name < $1.name }
    }
    
    /// 重新尝试启用（用于权限授予后）
    func retryEnable() {
        LogManager.shared.info(.shortcuts, "重新尝试启用快捷键")
        
        // 如果已经启用，停止重试定时器
        if isEnabled {
            stopPermissionRetryTimer()
            return
        }
        
        // 检查权限状态
        if checkInputMonitoringPermission() {
            LogManager.shared.info(.shortcuts, "检测到权限已授予，启用快捷键")
            enable()
            stopPermissionRetryTimer()
        }
    }
    
    /// 获取当前启用状态
    var isEnabledStatus: Bool {
        return isEnabled
    }
    
    // MARK: - Private Methods
    
    /// 异步完成初始化
    private func completeInitializationAsync() async {
        LogManager.shared.info(.shortcuts, "⌨️ 快捷键: 开始异步初始化")
        
        await Task.yield() // 让出控制权
        
        // 异步检查权限（不阻塞初始化）
        let hasPermission = checkInputMonitoringPermission()
        
        LogManager.shared.info(.shortcuts, "✅ 快捷键: 异步初始化完成", metadata: [
            "hasPermission": hasPermission
        ])
    }
    
    /// 加载现代化快捷键配置
    private func loadModernShortcuts() {
        let modernConfigs = ModernShortcutEntry.createModernDefaults()
        
        for config in modernConfigs {
            shortcuts[config.id] = config
        }
        
        LogManager.shared.info(.shortcuts, "加载现代化快捷键配置", metadata: [
            "count": modernConfigs.count
        ])
    }
    
    /// 启动权限重试定时器
    private func startPermissionRetryTimer() {
        // 停止现有定时器
        permissionRetryTimer?.invalidate()
        
        LogManager.shared.info(.shortcuts, "启动权限重试定时器")
        
        // 每30秒检查一次权限状态
        permissionRetryTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.retryEnable()
            }
        }
    }
    
    /// 停止权限重试定时器
    private func stopPermissionRetryTimer() {
        permissionRetryTimer?.invalidate()
        permissionRetryTimer = nil
        LogManager.shared.info(.shortcuts, "停止权限重试定时器")
    }
    
    /// 设置CGEventTap事件监听
    private func setupEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        
        // 创建事件监听回调
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            return ModernGlobalShortcuts.handleGlobalEvent(
                proxy: proxy,
                type: type,
                event: event,
                refcon: refcon
            )
        }
        
        // 创建事件监听
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        
        guard let eventTap = eventTap else {
            LogManager.shared.error(.shortcuts, "创建事件监听失败")
            let error = ModernGlobalShortcutsError.eventTapCreationFailed
            delegate?.modernGlobalShortcuts(self, didFailToSetup: error)
            return
        }
        
        // 创建RunLoop源
        runLoopSource = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault,
            eventTap,
            0
        )
        
        guard let runLoopSource = runLoopSource else {
            LogManager.shared.error(.shortcuts, "创建RunLoop源失败")
            return
        }
        
        // 添加到当前RunLoop
        CFRunLoopAddSource(
            CFRunLoopGetCurrent(),
            runLoopSource,
            .commonModes
        )
        
        // 启用事件监听
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        LogManager.shared.info(.shortcuts, "CGEventTap事件监听设置成功")
    }
    
    /// 静态事件处理函数
    private static func handleGlobalEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent,
        refcon: UnsafeMutableRawPointer?
    ) -> Unmanaged<CGEvent>? {
        
        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }
        
        guard let refcon = refcon else {
            return Unmanaged.passUnretained(event)
        }
        
        let shortcutsManager = Unmanaged<ModernGlobalShortcuts>.fromOpaque(refcon).takeUnretainedValue()
        
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        
        // 检查是否匹配任何快捷键
        for (shortcutId, config) in shortcutsManager.shortcuts {
            if keyCode == config.keyCode && flags.contains(config.modifierFlags) {
                // 匹配的快捷键，在主线程处理
                Task { @MainActor in
                    shortcutsManager.handleShortcutTriggered(shortcutId)
                }
                
                // 消费事件，防止传递给其他应用
                return nil
            }
        }
        
        // 不匹配任何快捷键，传递事件
        return Unmanaged.passUnretained(event)
    }
    
    /// 处理快捷键触发
    private func handleShortcutTriggered(_ shortcutId: String) {
        guard let config = shortcuts[shortcutId] else { return }
        
        LogManager.shared.info(.shortcuts, "现代快捷键触发", metadata: [
            "id": shortcutId,
            "name": config.name,
            "description": config.description
        ])
        
        delegate?.modernGlobalShortcuts(self, didTrigger: shortcutId)
    }
    
    /// 显示权限请求对话框（非阻塞）
    private func showPermissionAlert() {
        // 使用异步方式显示对话框，不阻塞初始化
        Task { @MainActor in
            let alert = NSAlert()
            alert.messageText = "Hello Prompt 需要输入监控权限"
            alert.informativeText = """
            为了使用 Ctrl+M 全局快捷键，需要授予输入监控权限。
            
            操作步骤：
            1. 点击"打开系统设置"按钮
            2. 在"隐私与安全性 > 输入监控"中找到 Hello Prompt
            3. 勾选启用 Hello Prompt
            4. 回到应用中按 Ctrl+M 测试快捷键
            
            注意：无需重启应用，权限授予后快捷键将立即生效。
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "打开系统设置")
            alert.addButton(withTitle: "稍后设置")
            
            // 异步显示对话框
            if let window = NSApp.mainWindow ?? NSApp.keyWindow {
                alert.beginSheetModal(for: window) { response in
                    if response == .alertFirstButtonReturn {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_InputMonitoring") {
                            NSWorkspace.shared.open(url)
                        }
                        
                        // 5秒后重新尝试启用快捷键
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                            self.retryEnable()
                        }
                    }
                }
            } else {
                // 如果没有窗口，使用runModal
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_InputMonitoring") {
                        NSWorkspace.shared.open(url)
                    }
                    
                    // 5秒后重新尝试启用快捷键
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        self.retryEnable()
                    }
                }
            }
        }
    }
    
    /// 清理资源
    private func cleanup() {
        // 禁用事件监听
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        
        // 移除RunLoop源
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(
                CFRunLoopGetCurrent(),
                runLoopSource,
                .commonModes
            )
            self.runLoopSource = nil
        }
        
        // 释放事件监听
        if let eventTap = eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        
        LogManager.shared.info(.shortcuts, "现代化快捷键资源清理完成")
    }
    
    /// 同步清理方法，用于deinit
    nonisolated private func cleanupSync() {
        Task { @MainActor in
            cleanup()
        }
    }
}

// MARK: - 现代快捷键错误类型
enum ModernGlobalShortcutsError: LocalizedError {
    case missingInputMonitoringPermission
    case eventTapCreationFailed
    case runLoopSourceCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .missingInputMonitoringPermission:
            return "缺少输入监控权限，请在系统偏好设置 > 安全性与隐私 > 隐私 > 输入监控中启用Hello Prompt"
        case .eventTapCreationFailed:
            return "创建事件监听失败，可能需要重新授权权限"
        case .runLoopSourceCreationFailed:
            return "创建RunLoop源失败"
        }
    }
}