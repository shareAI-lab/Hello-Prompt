//
//  CGEventTapShortcuts.swift
//  HelloPrompt
//
//  基于CGEventTap的全局快捷键替代实现 - 现代化的全局快捷键解决方案
//  Copyright © 2025 HelloPrompt. All rights reserved.
//

import Foundation
import AppKit
import Carbon

/// 基于CGEventTap的全局快捷键管理器
@MainActor
class CGEventTapShortcuts: NSObject {
    
    // MARK: - Properties
    weak var delegate: GlobalShortcutsDelegate?
    
    private var shortcuts: [String: ShortcutConfig] = [:]
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isEnabled = false
    private var hasInputMonitoringPermission = false
    
    // MARK: - Initialization
    override init() {
        super.init()
        
        LogManager.shared.info(.shortcuts, "CGEventTapShortcuts初始化")
        
        // 检查权限
        checkInputMonitoringPermission()
        
        // 加载默认快捷键配置
        loadDefaultShortcuts()
        
        // 设置事件监听
        if hasInputMonitoringPermission {
            setupEventTap()
        } else {
            LogManager.shared.warning(.shortcuts, "缺少Input Monitoring权限，无法使用CGEventTap")
        }
    }
    
    deinit {
        cleanupSync()
    }
    
    // MARK: - Public Methods
    
    /// 启用快捷键
    func enable() {
        guard !isEnabled else { return }
        guard hasInputMonitoringPermission else {
            LogManager.shared.warning(.shortcuts, "缺少Input Monitoring权限，无法启用CGEventTap快捷键")
            return
        }
        
        isEnabled = true
        
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
            LogManager.shared.info(.shortcuts, "启用CGEventTap全局快捷键")
        }
    }
    
    /// 禁用快捷键
    func disable() {
        guard isEnabled else { return }
        
        isEnabled = false
        
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            LogManager.shared.info(.shortcuts, "禁用CGEventTap全局快捷键")
        }
    }
    
    /// 注册所有快捷键
    func registerAllShortcuts() {
        guard hasInputMonitoringPermission else {
            LogManager.shared.warning(.shortcuts, "缺少Input Monitoring权限")
            return
        }
        
        LogManager.shared.info(.shortcuts, "CGEventTap快捷键配置完成", metadata: [
            "shortcutCount": shortcuts.count,
            "enabled": isEnabled
        ])
    }
    
    /// 更新快捷键配置
    func updateShortcut(_ config: ShortcutConfig) {
        shortcuts[config.id] = config
        
        LogManager.shared.info(.shortcuts, "更新CGEventTap快捷键配置", metadata: [
            "id": config.id,
            "name": config.name
        ])
    }
    
    /// 获取所有快捷键配置
    func getAllShortcuts() -> [ShortcutConfig] {
        return Array(shortcuts.values).sorted { $0.name < $1.name }
    }
    
    /// 获取快捷键配置
    func getShortcut(_ shortcutId: String) -> ShortcutConfig? {
        return shortcuts[shortcutId]
    }
    
    /// 检查快捷键是否可用
    func isShortcutAvailable(_ keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) -> Bool {
        // CGEventTap方式下，所有快捷键都是"可用"的，因为我们在应用层面进行过滤
        return true
    }
    
    // MARK: - Private Methods
    
    /// 检查Input Monitoring权限
    private func checkInputMonitoringPermission() {
        // 方法1：尝试预检权限
        if CGPreflightListenEventAccess() {
            hasInputMonitoringPermission = true
            LogManager.shared.info(.shortcuts, "CGEventTap权限预检通过")
        } else {
            // 方法2：尝试创建事件监听器测试权限
            let testMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { _ in }
            
            if testMonitor != nil {
                NSEvent.removeMonitor(testMonitor!)
                hasInputMonitoringPermission = true
                LogManager.shared.info(.shortcuts, "Input Monitoring权限已授予")
            } else {
                hasInputMonitoringPermission = false
                LogManager.shared.warning(.shortcuts, "缺少Input Monitoring权限")
                
                // 请求权限
                requestInputMonitoringPermission()
            }
        }
    }
    
    /// 请求Input Monitoring权限
    private func requestInputMonitoringPermission() {
        let alert = NSAlert()
        alert.messageText = "需要Input Monitoring权限"
        alert.informativeText = """
        Hello Prompt需要"输入监控"权限来注册全局快捷键。
        
        请在系统偏好设置 > 安全性与隐私 > 隐私 > 输入监控中启用Hello Prompt。
        
        启用后请重启应用。
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开系统偏好设置")
        alert.addButton(withTitle: "稍后设置")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
            NSWorkspace.shared.open(url)
        }
    }
    
    /// 设置事件监听
    private func setupEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        
        // 创建事件监听器
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                return CGEventTapShortcuts.eventTapCallback(proxy: proxy, type: type, event: event, refcon: refcon)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        
        guard let eventTap = eventTap else {
            LogManager.shared.error(.shortcuts, "CGEventTap创建失败")
            return
        }
        
        // 创建运行循环源
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        
        guard let runLoopSource = runLoopSource else {
            LogManager.shared.error(.shortcuts, "RunLoopSource创建失败")
            return
        }
        
        // 添加到运行循环
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        
        LogManager.shared.info(.shortcuts, "CGEventTap设置完成")
    }
    
    /// 事件监听回调
    private static func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
        
        guard let refcon = refcon else {
            return Unmanaged.passRetained(event)
        }
        
        let shortcuts = Unmanaged<CGEventTapShortcuts>.fromOpaque(refcon).takeUnretainedValue()
        
        // 检查是否是键盘按下事件
        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }
        
        // 获取按键信息
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        
        // 转换CGEventFlags到NSEvent.ModifierFlags
        let modifierFlags = shortcuts.convertCGEventFlags(flags)
        
        // 检查是否匹配我们的快捷键
        for (shortcutId, config) in shortcuts.shortcuts {
            if config.keyCode == keyCode && config.modifierFlags == modifierFlags {
                // 匹配成功，触发快捷键
                Task { @MainActor in
                    shortcuts.handleShortcutTriggered(shortcutId)
                }
                
                // 消费这个事件，不传递给其他应用
                return nil
            }
        }
        
        // 不匹配，传递给其他应用
        return Unmanaged.passRetained(event)
    }
    
    /// 转换CGEventFlags到NSEvent.ModifierFlags
    private func convertCGEventFlags(_ flags: CGEventFlags) -> NSEvent.ModifierFlags {
        var modifierFlags: NSEvent.ModifierFlags = []
        
        if flags.contains(.maskCommand) {
            modifierFlags.insert(.command)
        }
        if flags.contains(.maskAlternate) {
            modifierFlags.insert(.option)
        }
        if flags.contains(.maskShift) {
            modifierFlags.insert(.shift)
        }
        if flags.contains(.maskControl) {
            modifierFlags.insert(.control)
        }
        
        return modifierFlags
    }
    
    /// 加载默认快捷键配置
    private func loadDefaultShortcuts() {
        let defaultConfigs = ShortcutConfig.createDefaults()
        
        for config in defaultConfigs {
            shortcuts[config.id] = config
        }
        
        LogManager.shared.info(.shortcuts, "加载CGEventTap默认快捷键配置", metadata: [
            "count": defaultConfigs.count
        ])
    }
    
    /// 处理快捷键触发
    private func handleShortcutTriggered(_ shortcutId: String) {
        guard let config = shortcuts[shortcutId] else { return }
        
        LogManager.shared.info(.shortcuts, "CGEventTap快捷键触发", metadata: [
            "id": shortcutId,
            "name": config.name,
            "description": config.description
        ])
        
        delegate?.globalShortcuts(GlobalShortcuts(), didTrigger: shortcutId)
    }
    
    /// 清理资源
    private func cleanup() {
        // 禁用事件监听
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        
        // 移除运行循环源
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        
        // 清理事件监听器
        if let eventTap = eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        
        LogManager.shared.info(.shortcuts, "CGEventTapShortcuts资源清理完成")
    }
    
    /// 同步清理方法，用于deinit
    nonisolated private func cleanupSync() {
        Task { @MainActor in
            cleanup()
        }
    }
}

// MARK: - 权限检查扩展
extension CGEventTapShortcuts {
    
    /// 检查是否有Input Monitoring权限
    static func hasInputMonitoringPermission() -> Bool {
        // 方法1：预检权限
        if CGPreflightListenEventAccess() {
            return true
        }
        
        // 方法2：尝试创建全局监听器
        let monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { _ in }
        
        if monitor != nil {
            NSEvent.removeMonitor(monitor!)
            return true
        }
        
        return false
    }
    
    /// 请求Input Monitoring权限
    static func requestInputMonitoringPermission() {
        // 这会触发系统权限对话框
        _ = CGRequestListenEventAccess()
    }
    
    /// 打开系统偏好设置的隐私页面
    static func openPrivacySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        NSWorkspace.shared.open(url)
    }
}

// MARK: - 混合实现管理器
@MainActor
class HybridGlobalShortcuts: NSObject {
    
    // MARK: - Properties
    weak var delegate: GlobalShortcutsDelegate?
    
    private var carbonShortcuts: GlobalShortcuts?
    private var cgEventTapShortcuts: CGEventTapShortcuts?
    private var currentImplementation: String = "carbon"
    
    // MARK: - Initialization
    override init() {
        super.init()
        
        LogManager.shared.info(.shortcuts, "混合全局快捷键管理器初始化")
        
        // 优先尝试Carbon实现
        setupImplementation()
    }
    
    // MARK: - Public Methods
    
    /// 启用快捷键
    func enable() {
        switch currentImplementation {
        case "carbon":
            carbonShortcuts?.enable()
        case "cgeventtap":
            cgEventTapShortcuts?.enable()
        default:
            break
        }
    }
    
    /// 禁用快捷键
    func disable() {
        carbonShortcuts?.disable()
        cgEventTapShortcuts?.disable()
    }
    
    /// 注册所有快捷键
    func registerAllShortcuts() {
        switch currentImplementation {
        case "carbon":
            carbonShortcuts?.registerAllShortcuts()
        case "cgeventtap":
            cgEventTapShortcuts?.registerAllShortcuts()
        default:
            break
        }
    }
    
    /// 获取当前实现方式
    func getCurrentImplementation() -> String {
        return currentImplementation
    }
    
    /// 切换到CGEventTap实现
    func switchToCGEventTap() {
        carbonShortcuts?.disable()
        carbonShortcuts = nil
        
        currentImplementation = "cgeventtap"
        
        cgEventTapShortcuts = CGEventTapShortcuts()
        cgEventTapShortcuts?.delegate = delegate
        cgEventTapShortcuts?.enable()
        
        LogManager.shared.info(.shortcuts, "切换到CGEventTap实现")
    }
    
    /// 切换回Carbon实现
    func switchToCarbon() {
        cgEventTapShortcuts?.disable()
        cgEventTapShortcuts = nil
        
        currentImplementation = "carbon"
        
        carbonShortcuts = GlobalShortcuts()
        carbonShortcuts?.delegate = delegate
        carbonShortcuts?.enable()
        
        LogManager.shared.info(.shortcuts, "切换回Carbon实现")
    }
    
    // MARK: - Private Methods
    
    /// 设置实现方式
    private func setupImplementation() {
        // 首先尝试Carbon实现
        carbonShortcuts = GlobalShortcuts()
        carbonShortcuts?.delegate = self
        
        // 检查Carbon是否工作
        let testConfig = ShortcutConfig(
            id: "test",
            name: "测试",
            keyCode: 96, // F5
            modifierFlags: [],
            description: "测试快捷键"
        )
        
        // 尝试注册测试快捷键
        let available = carbonShortcuts?.isShortcutAvailable(testConfig.keyCode, modifierFlags: testConfig.modifierFlags) ?? false
        
        if available {
            currentImplementation = "carbon"
            LogManager.shared.info(.shortcuts, "使用Carbon实现")
        } else {
            // Carbon失败，尝试CGEventTap
            if CGEventTapShortcuts.hasInputMonitoringPermission() {
                switchToCGEventTap()
            } else {
                LogManager.shared.warning(.shortcuts, "两种实现都不可用", metadata: [
                    "carbon": "失败",
                    "cgeventtap": "缺少权限"
                ])
            }
        }
    }
}

// MARK: - HybridGlobalShortcuts Delegate
extension HybridGlobalShortcuts: GlobalShortcutsDelegate {
    
    func globalShortcuts(_ shortcuts: GlobalShortcuts, didTrigger shortcutId: String) {
        delegate?.globalShortcuts(shortcuts, didTrigger: shortcutId)
    }
    
    func globalShortcuts(_ shortcuts: GlobalShortcuts, didFailToRegister shortcutId: String, error: Error) {
        delegate?.globalShortcuts(shortcuts, didFailToRegister: shortcutId, error: error)
        
        // 如果Carbon注册失败，尝试切换到CGEventTap
        if currentImplementation == "carbon" && CGEventTapShortcuts.hasInputMonitoringPermission() {
            LogManager.shared.info(.shortcuts, "Carbon注册失败，尝试切换到CGEventTap")
            switchToCGEventTap()
            registerAllShortcuts()
        }
    }
}