//
//  HotkeyService.swift
//  HelloPrompt
//
//  现代化全局快捷键管理 - 使用NSEvent和CGEvent替代Carbon API
//  支持快捷键注册、冲突检测、现代事件处理
//

import Foundation
import SwiftUI
import AppKit
import ApplicationServices

// 使用Models/HotkeyModels.swift中定义的类型

// MARK: - Carbon常量定义（为了兼容性）
private let cmdKey: UInt32 = 256
private let shiftKey: UInt32 = 512
private let optionKey: UInt32 = 2048
private let controlKey: UInt32 = 4096

// MARK: - 主快捷键服务类
@MainActor
public final class HotkeyService: NSObject, ObservableObject {
    
    // MARK: - 单例实例
    public static let shared = HotkeyService()
    
    // MARK: - Published Properties
    @Published public var isEnabled = true
    @Published public var registeredHotkeys: [HotkeyIdentifier: KeyboardShortcut] = [:]
    @Published public var conflicts: [HotkeyConflict] = []
    
    // MARK: - 私有属性
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let hotkeyQueue = DispatchQueue(label: "com.helloprompt.hotkey", qos: .userInitiated)
    
    // 现代化快捷键监听
    private var monitoredHotkeys: [HotkeyIdentifier: NSEvent.EventTypeMask] = [:]
    private var hotkeyHandlers: [HotkeyIdentifier: () -> Void] = [:]
    
    // Ctrl+U按住监听相关
    private var isCtrlUPressed = false
    private var ctrlUPressStartTime: Date?
    private let minimumPressDuration: TimeInterval = 0.2 // 最小按压时间200ms
    
    // Ctrl+U按住回调
    var onCtrlURecordingStart: (() -> Void)?
    var onCtrlURecordingStop: (() -> Void)?
    
    // MARK: - 初始化
    private override init() {
        super.init()
        LogManager.shared.startupLog("🎯 HotkeyService 初始化开始", component: "HotkeyService")
        
        LogManager.shared.hotkeyLog("设置现代化事件监听器", details: ["phase": "init"])
        setupModernEventTap()
        
        LogManager.shared.hotkeyLog("设置Ctrl+U按住监听", details: ["phase": "init"])
        setupCtrlUPressHoldMonitoring()
        
        LogManager.shared.hotkeyLog("加载存储的快捷键", details: ["phase": "init"])
        loadStoredHotkeys()
        
        LogManager.shared.startupLog("✅ HotkeyService 初始化完成", component: "HotkeyService", details: [
            "isEnabled": isEnabled,
            "registeredCount": registeredHotkeys.count
        ])
    }
    
    deinit {
        // 清理时避免访问MainActor属性
        // cleanup() 需要MainActor上下文，在deinit中不安全调用
        LogManager.shared.info("HotkeyService", "快捷键服务正在销毁")
    }
    
    // MARK: - 公共方法
    
    /// 注册快捷键
    public func registerHotkey(
        _ identifier: HotkeyIdentifier,
        shortcut: KeyboardShortcut,
        handler: @escaping () -> Void
    ) -> Bool {
        LogManager.shared.hotkeyLog("🔧 尝试注册快捷键", details: [
            "identifier": identifier.rawValue,
            "shortcut": shortcut.displayText,
            "isEnabled": isEnabled
        ])
        
        guard isEnabled else {
            LogManager.shared.hotkeyLog("❌ 快捷键服务已禁用，注册失败", level: .error, details: [
                "identifier": identifier.rawValue
            ])
            return false
        }
        
        LogManager.shared.hotkeyLog("✅ 快捷键服务已启用，继续注册", details: [
            "identifier": identifier.rawValue,
            "shortcut": shortcut.displayText
        ])
        
        // 检查冲突
        LogManager.shared.hotkeyLog("🔍 检查快捷键冲突", details: [
            "shortcut": shortcut.displayText
        ])
        let conflicts = detectConflicts(for: shortcut)
        if !conflicts.isEmpty {
            LogManager.shared.hotkeyLog("⚠️ 发现快捷键冲突", level: .warning, details: [
                "shortcut": shortcut.displayText,
                "conflictCount": conflicts.count
            ])
            self.conflicts.append(contentsOf: conflicts)
        } else {
            LogManager.shared.hotkeyLog("✅ 无快捷键冲突", details: [
                "shortcut": shortcut.displayText
            ])
        }
        
        // 注销已存在的快捷键
        if registeredHotkeys[identifier] != nil {
            LogManager.shared.hotkeyLog("🔄 注销已存在的快捷键", details: [
                "identifier": identifier.rawValue
            ])
            _ = unregisterHotkey(identifier)
        }
        
        // 注册新快捷键
        LogManager.shared.hotkeyLog("🚀 开始注册新快捷键", details: [
            "identifier": identifier.rawValue,
            "shortcut": shortcut.displayText
        ])
        
        return hotkeyQueue.sync { () -> Bool in
            LogManager.shared.hotkeyLog("🔧 使用现代API注册快捷键", details: [
                "identifier": identifier.rawValue,
                "keyCode": shortcut.carbonKeyCode,
                "modifiers": shortcut.displayText
            ])
            
            // 使用现代化方式注册快捷键
            let success = registerModernHotkey(identifier, shortcut: shortcut, handler: handler)
            
            LogManager.shared.hotkeyLog("📊 现代API注册结果", details: [
                "identifier": identifier.rawValue,
                "success": success,
                "method": "CGEvent.tapCreate + NSEvent"
            ])
            
            if success {
                LogManager.shared.hotkeyLog("✅ 快捷键注册成功", details: [
                    "identifier": identifier.rawValue,
                    "shortcut": shortcut.displayText,
                    "api": "Modern NSEvent/CGEvent"
                ])
                
                Task { @MainActor in
                    self.registeredHotkeys[identifier] = shortcut
                    self.hotkeyHandlers[identifier] = handler
                }
                return true
            } else {
                LogManager.shared.error("HotkeyService", "现代API注册快捷键失败: \(identifier.rawValue)")
                return false
            }
        }
    }
    
    /// 注销快捷键
    public func unregisterHotkey(_ identifier: HotkeyIdentifier) -> Bool {
        LogManager.shared.info("HotkeyService", "注销快捷键: \(identifier.rawValue)")
        
        return hotkeyQueue.sync { () -> Bool in
            guard self.registeredHotkeys[identifier] != nil else {
                return false
            }
            
            let success = unregisterModernHotkey(identifier)
            if success {
                Task { @MainActor in
                    self.registeredHotkeys.removeValue(forKey: identifier)
                    self.hotkeyHandlers.removeValue(forKey: identifier)
                }
                self.monitoredHotkeys.removeValue(forKey: identifier)
                return true
            } else {
                LogManager.shared.error("HotkeyService", "现代API注销快捷键失败: \(identifier.rawValue)")
                return false
            }
        }
    }
    
    /// 获取所有已注册的快捷键
    public func getAllRegisteredHotkeys() -> [HotkeyIdentifier: KeyboardShortcut] {
        return registeredHotkeys
    }
    
    /// 检查快捷键是否已注册
    public func isHotkeyRegistered(_ identifier: HotkeyIdentifier) -> Bool {
        return registeredHotkeys[identifier] != nil
    }
    
    /// 启用或禁用快捷键服务
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        LogManager.shared.info("HotkeyService", "快捷键服务\(enabled ? "启用" : "禁用")")
        
        if !enabled {
            // 禁用时注销所有快捷键
            for identifier in registeredHotkeys.keys {
                _ = unregisterHotkey(identifier)
            }
        }
    }
    
    /// 重置为默认快捷键
    public func resetToDefaults() {
        LogManager.shared.info("HotkeyService", "重置快捷键为默认值")
        
        // 清除所有现有快捷键
        for identifier in registeredHotkeys.keys {
            _ = unregisterHotkey(identifier)
        }
        
        // 注册默认快捷键
        for identifier in HotkeyIdentifier.allCases {
            if let defaultShortcut = identifier.defaultShortcut {
                _ = registerHotkey(identifier, shortcut: defaultShortcut) {
                    // 默认处理器（需要外部设置具体处理逻辑）
                    LogManager.shared.info("HotkeyService", "触发默认快捷键: \(identifier.rawValue)")
                }
            }
        }
        
        saveHotkeysToDefaults()
    }
    
    /// 重新初始化事件监听器（权限授权后调用）
    public func reinitializeEventTap() {
        LogManager.shared.info("HotkeyService", "重新初始化事件监听器开始")
        
        // 先清理现有监听器
        cleanupEventTap()
        
        // 验证权限状态
        guard AXIsProcessTrusted() else {
            LogManager.shared.error("HotkeyService", "重新初始化失败：辅助功能权限仍未授权")
            isEnabled = false
            return
        }
        
        // 重新设置监听器，使用增强版本
        Task {
            await setupEnhancedEventTap()
        }
        isEnabled = true
        
        LogManager.shared.info("HotkeyService", "事件监听器重新初始化完成，状态：\(isEnabled)")
    }
    
    /// 清理事件监听器资源
    private func cleanupEventTap() {
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFRelease(eventTap)
            self.eventTap = nil
        }
    }
    
    /// 清理资源
    public func cleanup() {
        LogManager.shared.info("HotkeyService", "开始清理快捷键服务")
        
        // 注销所有快捷键
        for identifier in registeredHotkeys.keys {
            _ = unregisterHotkey(identifier)
        }
        
        // 移除现代化事件监听器
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFRelease(eventTap)
            self.eventTap = nil
        }
        
        conflicts.removeAll()
        LogManager.shared.info("HotkeyService", "快捷键服务清理完成")
    }
    
    // MARK: - 现代化事件处理方法
    
    /// 设置现代化CGEvent事件监听器
    private func setupModernEventTap() {
        Task {
            LogManager.shared.hotkeyLog("🚀 创建现代化事件监听器", details: ["method": "CGEvent.tapCreate"])
            
            // 检查辅助功能权限
            guard self.hasAccessibilityPermission() else {
                LogManager.shared.error("HotkeyService", "辅助功能权限未授权，无法创建事件监听器")
                LogManager.shared.error("HotkeyService", "Ctrl+U按住监听功能将无法使用，请在系统偏好设置中授权辅助功能权限")
                await MainActor.run {
                    // 设置权限缺失标志，UI可以据此显示权限提示
                    self.isEnabled = false
                }
                return
            }
            
            // 使用增强版本创建事件监听器
            await setupEnhancedEventTap()
        }
    }
    
    /// 增强版事件监听器设置，包含重试机制
    private func setupEnhancedEventTap() async {
        LogManager.shared.info("HotkeyService", "开始设置增强版事件监听器")
        
        // 创建事件监听器时增加错误处理和重试
        guard let eventTap = createEventTapWithRetry() else {
            LogManager.shared.error("HotkeyService", "无法创建事件监听器，即使权限已授权")
            await MainActor.run {
                self.isEnabled = false
            }
            return
        }
            
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        // 在MainActor上保存引用
        await MainActor.run {
            self.eventTap = eventTap
            self.runLoopSource = runLoopSource
            self.isEnabled = true
        }
        
        LogManager.shared.info("HotkeyService", "增强版事件监听器设置成功")
    }
    
    /// 创建事件监听器并支持重试机制
    private func createEventTapWithRetry(maxRetries: Int = 3) -> CFMachPort? {
        LogManager.shared.info("HotkeyService", "开始创建事件监听器，最大重试次数：\(maxRetries)")
        
        for attempt in 1...maxRetries {
            let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
            
            let eventTap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: CGEventMask(eventMask),
                callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                    let service = Unmanaged<HotkeyService>.fromOpaque(refcon!).takeUnretainedValue()
                    return service.handleModernEvent(proxy: proxy, type: type, event: event)
                },
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            )
            
            if eventTap != nil {
                LogManager.shared.info("HotkeyService", "事件监听器创建成功，尝试次数: \(attempt)")
                return eventTap
            }
            
            LogManager.shared.warning("HotkeyService", "事件监听器创建失败，尝试次数: \(attempt)")
            
            // 短暂延迟后重试
            if attempt < maxRetries {
                Thread.sleep(forTimeInterval: 0.1 * Double(attempt))
            }
        }
        
        LogManager.shared.error("HotkeyService", "事件监听器创建失败，已达最大重试次数")
        return nil
    }
    
    /// 设置Ctrl+U按住监听
    private func setupCtrlUPressHoldMonitoring() {
        LogManager.shared.hotkeyLog("⌨️ 设置Ctrl+U按住监听", details: [
            "minimumPressDuration": minimumPressDuration,
            "method": "CGEvent monitoring"
        ])
        
        // Ctrl+U按住会通过handleModernEvent处理
        LogManager.shared.info("HotkeyService", "Ctrl+U按住监听已设置")
    }
    
    /// 现代化事件处理器
    private nonisolated func handleModernEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        
        // 检查是否是U键事件 (keycode=32)
        if keyCode == 32 {
            if type == .keyDown && flags.contains(.maskControl) {
                // Ctrl+U按下
                handleCtrlUKeyDown()
            } else if type == .keyUp {
                // U键松开 (不检查Ctrl状态，因为用户可能先松开Ctrl)
                handleCtrlUKeyUp()
            }
        }
        
        // 检查其他注册的快捷键（只处理keyDown）
        if type == .keyDown {
            Task { @MainActor in
                for (identifier, shortcut) in self.registeredHotkeys {
                    if Int32(keyCode) == shortcut.carbonKeyCode && self.matchesModifiers(flags, shortcut.carbonModifierFlags) {
                        LogManager.shared.hotkeyLog("🎯 触发快捷键", details: [
                            "identifier": identifier.rawValue,
                            "keyCode": keyCode,
                            "modifiers": flags.rawValue
                        ])
                        
                        self.hotkeyHandlers[identifier]?()
                        break
                    }
                }
            }
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    /// 处理Ctrl+U按下
    private nonisolated func handleCtrlUKeyDown() {
        Task { @MainActor in
            guard !self.isCtrlUPressed else { return } // 防止重复按下
            
            self.isCtrlUPressed = true
            self.ctrlUPressStartTime = Date()
            
            LogManager.shared.hotkeyLog("🎯 Ctrl+U按下", details: [
                "timestamp": Date().timeIntervalSince1970
            ])
            
            let minimumDuration = self.minimumPressDuration
            
            // 延迟启动录音，防止意外触发
            Task {
                try? await Task.sleep(nanoseconds: UInt64(minimumDuration * 1_000_000_000))
                
                // 检查是否仍在按压状态
                await MainActor.run {
                    if self.isCtrlUPressed {
                        LogManager.shared.info("HotkeyService", "✅ Ctrl+U按住触发录音开始")
                        self.onCtrlURecordingStart?()
                    }
                }
            }
        }
    }
    
    /// 处理Ctrl+U松开
    private nonisolated func handleCtrlUKeyUp() {
        Task { @MainActor in
            guard self.isCtrlUPressed else { return } // 防止重复松开
            
            LogManager.shared.hotkeyLog("🎯 Ctrl+U松开", details: [
                "timestamp": Date().timeIntervalSince1970
            ])
            
            // 检查按压时长
            if let startTime = self.ctrlUPressStartTime {
                let pressDuration = Date().timeIntervalSince(startTime)
                
                if pressDuration < self.minimumPressDuration {
                    LogManager.shared.hotkeyLog("⚠️ Ctrl+U按压时间过短", level: .warning, details: [
                        "duration": String(format: "%.3f", pressDuration),
                        "minimum": String(format: "%.3f", self.minimumPressDuration)
                    ])
                    self.isCtrlUPressed = false
                    self.ctrlUPressStartTime = nil
                    return
                }
            }
            
            LogManager.shared.info("HotkeyService", "✅ Ctrl+U松开触发录音停止")
            self.onCtrlURecordingStop?()
            
            self.isCtrlUPressed = false
            self.ctrlUPressStartTime = nil
        }
    }
    
    // MARK: - 现代化快捷键注册辅助方法
    
    /// 注册现代化快捷键
    private func registerModernHotkey(_ identifier: HotkeyIdentifier, shortcut: KeyboardShortcut, handler: @escaping () -> Void) -> Bool {
        LogManager.shared.hotkeyLog("📝 注册现代化快捷键", details: [
            "identifier": identifier.rawValue,
            "shortcut": shortcut.displayText
        ])
        
        // 保存处理器
        hotkeyHandlers[identifier] = handler
        monitoredHotkeys[identifier] = NSEvent.EventTypeMask.keyDown
        
        LogManager.shared.info("HotkeyService", "现代化快捷键注册成功: \(identifier.rawValue)")
        return true
    }
    
    /// 注销现代化快捷键
    private func unregisterModernHotkey(_ identifier: HotkeyIdentifier) -> Bool {
        LogManager.shared.hotkeyLog("🗑️ 注销现代化快捷键", details: [
            "identifier": identifier.rawValue
        ])
        
        hotkeyHandlers.removeValue(forKey: identifier)
        monitoredHotkeys.removeValue(forKey: identifier)
        
        LogManager.shared.info("HotkeyService", "现代化快捷键注销成功: \(identifier.rawValue)")
        return true
    }
    
    /// 检查辅助功能权限
    private nonisolated func hasAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    /// 匹配修饰键
    private nonisolated func matchesModifiers(_ eventFlags: CGEventFlags, _ targetModifiers: Int32) -> Bool {
        var matches = true
        
        if (targetModifiers & Int32(cmdKey)) != 0 {
            matches = matches && eventFlags.contains(.maskCommand)
        }
        if (targetModifiers & Int32(shiftKey)) != 0 {
            matches = matches && eventFlags.contains(.maskShift)
        }
        if (targetModifiers & Int32(optionKey)) != 0 {
            matches = matches && eventFlags.contains(.maskAlternate)
        }
        if (targetModifiers & Int32(controlKey)) != 0 {
            matches = matches && eventFlags.contains(.maskControl)
        }
        
        return matches
    }
    
    /// 检测快捷键冲突
    private func detectConflicts(for shortcut: KeyboardShortcut) -> [HotkeyConflict] {
        var conflicts: [HotkeyConflict] = []
        
        // 检查系统内置快捷键
        let systemConflicts = checkSystemHotkeyConflicts(shortcut)
        conflicts.append(contentsOf: systemConflicts)
        
        // 检查已注册的快捷键
        for (identifier, existingShortcut) in registeredHotkeys {
            if existingShortcut.key == shortcut.key && existingShortcut.modifiers == shortcut.modifiers {
                let conflict = HotkeyConflict(
                    shortcut: shortcut,
                    conflictingIdentifiers: [identifier],
                    systemConflicts: []
                )
                conflicts.append(conflict)
            }
        }
        
        return conflicts
    }
    
    /// 检查系统快捷键冲突
    private func checkSystemHotkeyConflicts(_ shortcut: KeyboardShortcut) -> [HotkeyConflict] {
        var conflicts: [HotkeyConflict] = []
        
        // 检查一些常见的系统快捷键
        let systemShortcuts: [(KeyboardShortcut, String, String)] = [
            (KeyboardShortcut(.space, modifiers: [.command]), "Spotlight", "显示Spotlight搜索"),
            (KeyboardShortcut(.tab, modifiers: [.command]), "System", "应用切换"),
            // 临时注释掉有问题的KeyEquivalent
            // (KeyboardShortcut(.q, modifiers: [.command]), "System", "退出应用"),
            // (KeyboardShortcut(.w, modifiers: [.command]), "System", "关闭窗口"),
            // (KeyboardShortcut(.m, modifiers: [.command]), "System", "最小化窗口"),
            // (KeyboardShortcut(.h, modifiers: [.command]), "System", "隐藏应用"),
        ]
        
        for (systemShortcut, app, function) in systemShortcuts {
            if systemShortcut.key == shortcut.key && systemShortcut.modifiers == shortcut.modifiers {
                // 创建系统快捷键冲突
                let systemConflict = SystemHotkeyConflict(
                    application: app,
                    function: function,
                    canOverride: false
                )
                let conflict = HotkeyConflict(
                    shortcut: shortcut,
                    conflictingIdentifiers: [],
                    systemConflicts: [systemConflict]
                )
                conflicts.append(conflict)
            }
        }
        
        return conflicts
    }
    
    /// 从UserDefaults加载存储的快捷键
    private func loadStoredHotkeys() {
        let defaults = UserDefaults.standard
        
        for identifier in HotkeyIdentifier.allCases {
            let key = "hotkey_\(identifier.rawValue)"
            
            if let data = defaults.data(forKey: key),
               let shortcut = try? JSONDecoder().decode(KeyboardShortcut.self, from: data) {
                registeredHotkeys[identifier] = shortcut
                LogManager.shared.debug("HotkeyService", "加载存储的快捷键: \(identifier.rawValue) -> \(shortcut.displayText)")
            }
        }
    }
    
    /// 保存快捷键到UserDefaults
    private func saveHotkeysToDefaults() {
        let defaults = UserDefaults.standard
        
        for (identifier, shortcut) in registeredHotkeys {
            let key = "hotkey_\(identifier.rawValue)"
            
            if let data = try? JSONEncoder().encode(shortcut) {
                defaults.set(data, forKey: key)
                LogManager.shared.debug("HotkeyService", "保存快捷键: \(identifier.rawValue) -> \(shortcut.displayText)")
            }
        }
    }
}

// 使用Models/HotkeyModels.swift中定义的KeyboardShortcut扩展