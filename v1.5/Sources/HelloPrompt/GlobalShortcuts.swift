//
//  GlobalShortcuts.swift
//  HelloPrompt
//
//  全局快捷键管理 - 实现系统级快捷键响应和自定义配置
//  Copyright © 2025 HelloPrompt. All rights reserved.
//

import Foundation
import AppKit
import Carbon

// MARK: - 快捷键配置
struct ShortcutConfig {
    let id: String
    let name: String
    let keyCode: UInt16
    let modifierFlags: NSEvent.ModifierFlags
    let description: String
    
    init(id: String, name: String, keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags, description: String) {
        self.id = id
        self.name = name
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
        self.description = description
    }
    
    /// 创建默认快捷键配置
    static func createDefaults() -> [ShortcutConfig] {
        return [
            ShortcutConfig(
                id: "start_recording",
                name: "开始录音",
                keyCode: 96, // F5 key
                modifierFlags: [],
                description: "F5 - 开始/停止录音"
            ),
            ShortcutConfig(
                id: "show_settings",
                name: "显示设置",
                keyCode: 97, // F6 key
                modifierFlags: [],
                description: "F6 - 显示设置面板"
            ),
            ShortcutConfig(
                id: "toggle_floating_ball",
                name: "切换悬浮球",
                keyCode: 98, // F7 key
                modifierFlags: [],
                description: "F7 - 显示/隐藏悬浮球"
            ),
            ShortcutConfig(
                id: "quick_optimize",
                name: "快速优化",
                keyCode: 99, // F8 key
                modifierFlags: [],
                description: "F8 - 优化剪贴板中的文本"
            )
        ]
    }
    
    /// 创建原始快捷键配置（作为备选）
    static func createLegacyDefaults() -> [ShortcutConfig] {
        return [
            ShortcutConfig(
                id: "start_recording",
                name: "开始录音",
                keyCode: 15, // R key
                modifierFlags: [.command, .control],
                description: "⌘⌃R - 开始/停止录音"
            ),
            ShortcutConfig(
                id: "show_settings",
                name: "显示设置",
                keyCode: 43, // comma key (,)
                modifierFlags: [.command, .option],
                description: "⌘⌥, - 显示设置面板"
            ),
            ShortcutConfig(
                id: "toggle_floating_ball",
                name: "切换悬浮球",
                keyCode: 3, // F key
                modifierFlags: [.command, .control],
                description: "⌘⌃F - 显示/隐藏悬浮球"
            ),
            ShortcutConfig(
                id: "quick_optimize",
                name: "快速优化",
                keyCode: 32, // U key
                modifierFlags: [.command, .control],
                description: "⌘⌃U - 优化剪贴板中的文本"
            )
        ]
    }
}

// MARK: - 快捷键事件处理协议
@MainActor
protocol GlobalShortcutsDelegate: AnyObject {
    func globalShortcuts(_ shortcuts: GlobalShortcuts, didTrigger shortcutId: String)
    func globalShortcuts(_ shortcuts: GlobalShortcuts, didFailToRegister shortcutId: String, error: Error)
}

// MARK: - 全局快捷键管理器
@MainActor
class GlobalShortcuts: NSObject {
    
    // MARK: - Properties
    weak var delegate: GlobalShortcutsDelegate?
    
    private var shortcuts: [String: ShortcutConfig] = [:]
    private var registeredHotKeys: [String: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    private var isEnabled = true
    
    // MARK: - Initialization
    override init() {
        super.init()
        
        LogManager.shared.info(.shortcuts, "GlobalShortcuts初始化")
        
        // 加载默认快捷键配置
        loadDefaultShortcuts()
        
        // 设置事件处理器
        setupEventHandler()
        
        // 监听应用激活状态
        setupApplicationObservers()
    }
    
    deinit {
        cleanupSync()
    }
    
    // MARK: - Public Methods
    
    /// 注册所有快捷键
    func registerAllShortcuts() {
        guard isEnabled else {
            LogManager.shared.warning(.shortcuts, "快捷键已禁用，跳过注册")
            return
        }
        
        LogManager.shared.info(.shortcuts, "开始注册全局快捷键", metadata: [
            "shortcutCount": shortcuts.count
        ])
        
        for (_, config) in shortcuts {
            registerShortcut(config)
        }
    }
    
    /// 注册单个快捷键
    func registerShortcut(_ config: ShortcutConfig) {
        guard isEnabled else { return }
        
        // 如果已经注册，先注销
        unregisterShortcut(config.id)
        
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: fourCharCode("HLPT"), id: UInt32(config.id.hashValue))
        
        let carbonModifiers = convertModifierFlags(config.modifierFlags)
        
        LogManager.shared.debug(.shortcuts, "尝试注册快捷键", metadata: [
            "id": config.id,
            "name": config.name,
            "keyCode": config.keyCode,
            "carbonModifiers": carbonModifiers,
            "nsModifiers": config.modifierFlags.rawValue,
            "signature": "HLPT",
            "hotKeyId": UInt32(config.id.hashValue)
        ])
        
        let status = RegisterEventHotKey(
            UInt32(config.keyCode),
            UInt32(carbonModifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr, let hotKey = hotKeyRef {
            registeredHotKeys[config.id] = hotKey
            
            LogManager.shared.info(.shortcuts, "快捷键注册成功", metadata: [
                "id": config.id,
                "name": config.name,
                "description": config.description,
                "keyCode": config.keyCode,
                "modifiers": config.modifierFlags.rawValue,
                "hotKeyRef": String(describing: hotKey)
            ])
        } else {
            let error = GlobalShortcutsError.registrationFailed(status)
            
            LogManager.shared.error(.shortcuts, "快捷键注册失败", metadata: [
                "id": config.id,
                "name": config.name,
                "keyCode": config.keyCode,
                "modifiers": config.modifierFlags.rawValue,
                "status": status,
                "errorDescription": getOSStatusDescription(status),
                "possibleCause": analyzRegistrationFailure(keyCode: config.keyCode, modifiers: carbonModifiers, status: status)
            ])
            
            LogManager.shared.trackError(error, context: "注册快捷键: \(config.name)", recoveryAction: "检查快捷键是否被其他应用占用或使用替代快捷键")
            delegate?.globalShortcuts(self, didFailToRegister: config.id, error: error)
        }
    }
    
    /// 注销单个快捷键
    func unregisterShortcut(_ shortcutId: String) {
        guard let hotKeyRef = registeredHotKeys[shortcutId] else { return }
        
        let status = UnregisterEventHotKey(hotKeyRef)
        registeredHotKeys.removeValue(forKey: shortcutId)
        
        if status == noErr {
            LogManager.shared.info(.shortcuts, "快捷键注销成功", metadata: [
                "id": shortcutId
            ])
        } else {
            LogManager.shared.warning(.shortcuts, "快捷键注销失败", metadata: [
                "id": shortcutId,
                "status": status
            ])
        }
    }
    
    /// 注销所有快捷键
    func unregisterAllShortcuts() {
        LogManager.shared.info(.shortcuts, "注销所有快捷键", metadata: [
            "registeredCount": registeredHotKeys.count
        ])
        
        for shortcutId in registeredHotKeys.keys {
            unregisterShortcut(shortcutId)
        }
    }
    
    /// 启用快捷键
    func enable() {
        guard !isEnabled else { return }
        
        isEnabled = true
        registerAllShortcuts()
        
        LogManager.shared.info(.shortcuts, "启用全局快捷键")
    }
    
    /// 禁用快捷键
    func disable() {
        guard isEnabled else { return }
        
        isEnabled = false
        unregisterAllShortcuts()
        
        LogManager.shared.info(.shortcuts, "禁用全局快捷键")
    }
    
    /// 更新快捷键配置
    func updateShortcut(_ config: ShortcutConfig) {
        shortcuts[config.id] = config
        
        if isEnabled {
            registerShortcut(config)
        }
        
        LogManager.shared.info(.shortcuts, "更新快捷键配置", metadata: [
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
        // 创建临时快捷键ID
        let tempID = EventHotKeyID(signature: fourCharCode("TEST"), id: 9999)
        var tempHotKeyRef: EventHotKeyRef?
        
        let carbonModifiers = convertModifierFlags(modifierFlags)
        
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(carbonModifiers),
            tempID,
            GetApplicationEventTarget(),
            0,
            &tempHotKeyRef
        )
        
        // 立即注销测试快捷键
        if let hotKey = tempHotKeyRef {
            UnregisterEventHotKey(hotKey)
        }
        
        let available = status == noErr
        
        LogManager.shared.debug(.shortcuts, "检查快捷键可用性", metadata: [
            "keyCode": keyCode,
            "modifiers": modifierFlags.rawValue,
            "available": available,
            "status": status
        ])
        
        return available
    }
    
    // MARK: - Private Methods
    
    /// 加载默认快捷键配置
    private func loadDefaultShortcuts() {
        let defaultConfigs = ShortcutConfig.createDefaults()
        
        for config in defaultConfigs {
            shortcuts[config.id] = config
        }
        
        LogManager.shared.info(.shortcuts, "加载默认快捷键配置", metadata: [
            "count": defaultConfigs.count
        ])
    }
    
    /// 设置事件处理器
    private func setupEventHandler() {
        let eventSpec = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        ]
        
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (handler, event, userData) -> OSStatus in
                return GlobalShortcuts.handleHotKeyEvent(handler, event, userData)
            },
            1,
            eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        
        if status == noErr {
            LogManager.shared.info(.shortcuts, "事件处理器安装成功")
        } else {
            LogManager.shared.error(.shortcuts, "事件处理器安装失败", metadata: [
                "status": status
            ])
        }
    }
    
    /// 设置应用状态监听
    private func setupApplicationObservers() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        
        // 应用激活
        notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor [weak self] in
                self?.handleApplicationActivation(app)
            }
        }
        
        // 应用退到后台
        notificationCenter.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor [weak self] in
                self?.handleApplicationDeactivation(app)
            }
        }
        
        LogManager.shared.info(.shortcuts, "应用状态监听器设置完成")
    }
    
    /// 处理应用激活
    private func handleApplicationActivation(_ app: NSRunningApplication?) {
        guard let app = app else { return }
        
        LogManager.shared.debug(.shortcuts, "应用激活", metadata: [
            "bundleId": app.bundleIdentifier ?? "unknown",
            "appName": app.localizedName ?? "unknown"
        ])
        
        // 可以根据激活的应用调整快捷键行为
        adjustShortcutsForApplication(app)
    }
    
    /// 处理应用退到后台
    private func handleApplicationDeactivation(_ app: NSRunningApplication?) {
        guard let app = app else { return }
        
        LogManager.shared.debug(.shortcuts, "应用退到后台", metadata: [
            "bundleId": app.bundleIdentifier ?? "unknown",
            "appName": app.localizedName ?? "unknown"
        ])
    }
    
    /// 根据当前应用调整快捷键
    private func adjustShortcutsForApplication(_ app: NSRunningApplication) {
        // 在某些应用中可能需要禁用或调整快捷键
        // 例如在游戏中可能需要临时禁用
        
        let bundleId = app.bundleIdentifier ?? ""
        
        // 游戏应用列表（示例）
        let gameApps = [
            "com.apple.Arcade",
            "com.epicgames.EpicGamesLauncher",
            "com.valvesoftware.steam"
        ]
        
        if gameApps.contains(bundleId) {
            LogManager.shared.info(.shortcuts, "检测到游戏应用，考虑调整快捷键行为", metadata: [
                "app": app.localizedName ?? "unknown"
            ])
            // 可以选择暂时禁用某些快捷键
        }
    }
    
    /// 转换修饰键标志
    private func convertModifierFlags(_ modifierFlags: NSEvent.ModifierFlags) -> UInt32 {
        var carbonModifiers: UInt32 = 0
        
        if modifierFlags.contains(.command) {
            carbonModifiers |= UInt32(cmdKey)
        }
        if modifierFlags.contains(.option) {
            carbonModifiers |= UInt32(optionKey)
        }
        if modifierFlags.contains(.shift) {
            carbonModifiers |= UInt32(shiftKey)
        }
        if modifierFlags.contains(.control) {
            carbonModifiers |= UInt32(controlKey)
        }
        
        return carbonModifiers
    }
    
    /// 创建四字符代码
    private func fourCharCode(_ string: String) -> OSType {
        let data = string.data(using: .utf8) ?? Data()
        let bytes = data.prefix(4)
        var result: OSType = 0
        
        for (index, byte) in bytes.enumerated() {
            result |= OSType(byte) << (8 * (3 - index))
        }
        
        return result
    }
    
    /// 静态事件处理函数
    private static func handleHotKeyEvent(_ handler: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
        guard let userData = userData else { return OSStatus(eventNotHandledErr) }
        
        let shortcuts = Unmanaged<GlobalShortcuts>.fromOpaque(userData).takeUnretainedValue()
        
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        
        guard status == noErr else {
            return OSStatus(eventNotHandledErr)
        }
        
        // 查找对应的快捷键配置
        for (shortcutId, _) in shortcuts.shortcuts {
            if UInt32(shortcutId.hashValue) == hotKeyID.id {
                Task { @MainActor in
                    shortcuts.handleShortcutTriggered(shortcutId)
                }
                return OSStatus(noErr)
            }
        }
        
        return OSStatus(eventNotHandledErr)
    }
    
    /// 处理快捷键触发
    private func handleShortcutTriggered(_ shortcutId: String) {
        guard let config = shortcuts[shortcutId] else { return }
        
        LogManager.shared.info(.shortcuts, "快捷键触发", metadata: [
            "id": shortcutId,
            "name": config.name,
            "description": config.description
        ])
        
        delegate?.globalShortcuts(self, didTrigger: shortcutId)
    }
    
    /// 清理资源
    private func cleanup() {
        // 注销所有快捷键
        unregisterAllShortcuts()
        
        // 移除事件处理器
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        
        // 移除通知观察者
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        
        LogManager.shared.info(.shortcuts, "GlobalShortcuts资源清理完成")
    }
    
    /// 同步清理方法，用于deinit
    nonisolated private func cleanupSync() {
        Task { @MainActor in
            // 注销所有快捷键
            unregisterAllShortcuts()
            
            // 移除事件处理器
            if let eventHandler = eventHandler {
                RemoveEventHandler(eventHandler)
                self.eventHandler = nil
            }
            
            // 移除通知观察者
            NSWorkspace.shared.notificationCenter.removeObserver(self)
            
            LogManager.shared.info(.shortcuts, "GlobalShortcuts资源清理完成（同步）")
        }
    }
}

// MARK: - 全局快捷键错误类型
enum GlobalShortcutsError: LocalizedError {
    case registrationFailed(OSStatus)
    case eventHandlerInstallFailed(OSStatus)
    case shortcutAlreadyRegistered(String)
    case shortcutNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .registrationFailed(let status):
            return "快捷键注册失败 (状态码: \(status))"
        case .eventHandlerInstallFailed(let status):
            return "事件处理器安装失败 (状态码: \(status))"
        case .shortcutAlreadyRegistered(let id):
            return "快捷键已注册: \(id)"
        case .shortcutNotFound(let id):
            return "未找到快捷键: \(id)"
        }
    }
}

// MARK: - 快捷键工具扩展
extension GlobalShortcuts {
    
    /// 获取按键名称
    static func getKeyName(for keyCode: UInt16) -> String {
        let keyNames: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2", 20: "3",
            21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]",
            31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";",
            42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 50: "`",
            36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Escape",
            123: "Left", 124: "Right", 125: "Down", 126: "Up"
        ]
        
        return keyNames[keyCode] ?? "Key\(keyCode)"
    }
    
    /// 获取修饰键描述
    static func getModifierDescription(for modifierFlags: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        
        if modifierFlags.contains(.control) {
            parts.append("⌃")
        }
        if modifierFlags.contains(.option) {
            parts.append("⌥")
        }
        if modifierFlags.contains(.shift) {
            parts.append("⇧")
        }
        if modifierFlags.contains(.command) {
            parts.append("⌘")
        }
        
        return parts.joined()
    }
    
    /// 格式化快捷键描述
    static func formatShortcutDescription(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) -> String {
        let modifierDesc = getModifierDescription(for: modifierFlags)
        let keyName = getKeyName(for: keyCode)
        return "\(modifierDesc)\(keyName)"
    }
    
    /// 获取OSStatus错误描述
    private func getOSStatusDescription(_ status: OSStatus) -> String {
        switch status {
        case noErr: return "无错误"
        case -50: return "参数错误 (paramErr)"
        case -9850: return "事件已注册"
        case -9868: return "修饰键参数无效"
        case -9869: return "无效的快捷键ID"
        case -25291: return "事件处理器未找到"
        default: return "未知错误 (\(status))"
        }
    }
    
    /// 分析注册失败原因
    private func analyzRegistrationFailure(keyCode: UInt16, modifiers: UInt32, status: OSStatus) -> String {
        var analysis: [String] = []
        
        switch status {
        case -9868:
            analysis.append("修饰键参数无效")
            analysis.append("检查修饰键组合是否正确")
        case -50:
            analysis.append("参数错误")
            analysis.append("键码或修饰键可能不正确")
        case -9850:
            analysis.append("快捷键已被注册")
            analysis.append("该组合可能被其他应用占用")
        default:
            break
        }
        
        // 检查是否是系统保留快捷键
        if isSystemReservedShortcut(keyCode: keyCode, modifiers: modifiers) {
            analysis.append("系统保留快捷键")
        }
        
        // 检查常见冲突
        let conflicts = getCommonConflicts(keyCode: keyCode, modifiers: modifiers)
        if !conflicts.isEmpty {
            analysis.append("可能与以下应用冲突: \(conflicts.joined(separator: ", "))")
        }
        
        return analysis.isEmpty ? "未知原因" : analysis.joined(separator: "; ")
    }
    
    /// 检查是否是系统保留快捷键
    private func isSystemReservedShortcut(keyCode: UInt16, modifiers: UInt32) -> Bool {
        let reserved = [
            (9, UInt32(cmdKey)), // Tab + Cmd
            (49, UInt32(cmdKey)), // Space + Cmd (Spotlight)
            (8, UInt32(cmdKey)), // C + Cmd
            (9, UInt32(cmdKey)), // V + Cmd
            (7, UInt32(cmdKey)), // X + Cmd
            (6, UInt32(cmdKey)), // Z + Cmd
        ]
        
        for (reservedKey, reservedMod) in reserved {
            if keyCode == reservedKey && (modifiers & reservedMod) != 0 {
                return true
            }
        }
        
        return false
    }
    
    /// 获取常见冲突应用
    private func getCommonConflicts(keyCode: UInt16, modifiers: UInt32) -> [String] {
        var conflicts: [String] = []
        
        // ⌘⌃R 冲突
        if keyCode == 15 && (modifiers & UInt32(cmdKey | controlKey)) == UInt32(cmdKey | controlKey) {
            conflicts.append("Chrome刷新")
        }
        
        // ⌘⌃F 冲突
        if keyCode == 3 && (modifiers & UInt32(cmdKey | controlKey)) == UInt32(cmdKey | controlKey) {
            conflicts.append("全屏模式")
        }
        
        // ⌘⌃U 冲突
        if keyCode == 32 && (modifiers & UInt32(cmdKey | controlKey)) == UInt32(cmdKey | controlKey) {
            conflicts.append("Safari查看源码")
        }
        
        return conflicts
    }
}