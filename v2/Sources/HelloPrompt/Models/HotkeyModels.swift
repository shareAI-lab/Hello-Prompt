//
//  HotkeyModels.swift
//  HelloPrompt
//
//  快捷键相关的数据模型定义
//  包含快捷键标识符、组合键、配置等类型
//

import Foundation
import SwiftUI

// MARK: - Carbon常量定义（为了兼容性）
private let cmdKey: UInt32 = 256
private let shiftKey: UInt32 = 512
private let optionKey: UInt32 = 2048
private let controlKey: UInt32 = 4096

// MARK: - 快捷键标识符
public enum HotkeyIdentifier: String, CaseIterable, Identifiable {
    case startRecording = "开始录音"
    case stopRecording = "停止录音"
    case retryRecording = "重试录音"
    case insertResult = "插入结果"
    case copyResult = "复制结果"
    case togglePause = "切换暂停"
    case cancelOperation = "取消操作"
    case toggleRecording = "切换录音"
    case cancelRecording = "取消录音"
    case showMainWindow = "显示主窗口"
    case hideMainWindow = "隐藏主窗口"
    case toggleMainWindow = "切换主窗口"
    case showSettings = "显示设置"
    case quickCopy = "快速复制"
    case quickPaste = "快速粘贴"
    case clearHistory = "清空历史"
    case retryLastOperation = "重试上次操作"
    case emergencyStop = "紧急停止"
    
    public var id: String { rawValue }
    
    var description: String {
        switch self {
        case .startRecording: return "开始语音录制"
        case .stopRecording: return "停止语音录制"
        case .retryRecording: return "重试录制"
        case .insertResult: return "插入结果到当前位置"
        case .copyResult: return "复制结果到剪贴板"
        case .togglePause: return "切换应用暂停状态"
        case .cancelOperation: return "取消当前操作"
        case .toggleRecording: return "切换录制状态"
        case .cancelRecording: return "取消当前录制"
        case .showMainWindow: return "显示主窗口"
        case .hideMainWindow: return "隐藏主窗口"
        case .toggleMainWindow: return "显示/隐藏主窗口"
        case .showSettings: return "打开设置界面"
        case .quickCopy: return "快速复制结果"
        case .quickPaste: return "快速粘贴结果"
        case .clearHistory: return "清空历史记录"
        case .retryLastOperation: return "重试上次操作"
        case .emergencyStop: return "紧急停止所有操作"
        }
    }
    
    var category: HotkeyCategory {
        switch self {
        case .startRecording, .stopRecording, .retryRecording, .toggleRecording, .cancelRecording:
            return .recording
        case .insertResult, .copyResult, .quickCopy, .quickPaste, .clearHistory, .retryLastOperation:
            return .action
        case .togglePause, .cancelOperation, .emergencyStop:
            return .system
        case .showMainWindow, .hideMainWindow, .toggleMainWindow, .showSettings:
            return .window
        }
    }
    
    var defaultShortcut: KeyboardShortcut? {
        switch self {
        case .startRecording:
            return KeyboardShortcut(" ", modifiers: [.option, .command])
        case .stopRecording:
            return KeyboardShortcut(" ", modifiers: [.option, .command, .shift])
        case .retryRecording:
            return KeyboardShortcut("r", modifiers: [.control, .option])
        case .insertResult:
            return KeyboardShortcut("i", modifiers: [.control, .shift])
        case .copyResult:
            return KeyboardShortcut("c", modifiers: [.control, .shift])
        case .togglePause:
            return KeyboardShortcut("p", modifiers: [.control, .option])
        case .cancelOperation:
            return KeyboardShortcut(.escape, modifiers: [])
        case .toggleRecording:
            return KeyboardShortcut("r", modifiers: [.option, .command])
        case .cancelRecording:
            return KeyboardShortcut(.escape, modifiers: [.option])
        case .showMainWindow:
            return KeyboardShortcut("m", modifiers: [.option, .command])
        case .hideMainWindow:
            return KeyboardShortcut("h", modifiers: [.option, .command])
        case .toggleMainWindow:
            return KeyboardShortcut("w", modifiers: [.option, .command])
        case .showSettings:
            return KeyboardShortcut(",", modifiers: [.command])
        case .quickCopy:
            return KeyboardShortcut("c", modifiers: [.option, .command])
        case .quickPaste:
            return KeyboardShortcut("v", modifiers: [.option, .command])
        case .clearHistory:
            return KeyboardShortcut(.delete, modifiers: [.option, .command])
        case .retryLastOperation:
            return KeyboardShortcut("r", modifiers: [.command, .shift])
        case .emergencyStop:
            return KeyboardShortcut(.escape, modifiers: [.command, .shift])
        }
    }
    
    var icon: String {
        switch self {
        case .startRecording: return "mic.circle"
        case .stopRecording: return "stop.circle"
        case .retryRecording: return "arrow.clockwise.circle"
        case .insertResult: return "doc.badge.plus"
        case .copyResult: return "doc.on.doc"
        case .togglePause: return "pause.circle"
        case .cancelOperation: return "xmark.circle"
        case .toggleRecording: return "mic.badge.plus"
        case .cancelRecording: return "xmark.circle"
        case .showMainWindow: return "window"
        case .hideMainWindow: return "window.badge.minus"
        case .toggleMainWindow: return "window.badge.plus"
        case .showSettings: return "gearshape"
        case .quickCopy: return "doc.on.doc"
        case .quickPaste: return "doc.on.clipboard"
        case .clearHistory: return "trash"
        case .retryLastOperation: return "arrow.clockwise"
        case .emergencyStop: return "stop.fill"
        }
    }
}

// MARK: - 快捷键分类
public enum HotkeyCategory: String, CaseIterable {
    case recording = "录音控制"
    case window = "窗口管理"
    case action = "操作功能"
    case system = "系统控制"
    
    var description: String {
        switch self {
        case .recording: return "控制录音的开始、停止和取消"
        case .window: return "管理应用窗口的显示和隐藏"
        case .action: return "快速执行复制、粘贴等操作"
        case .system: return "系统级别的控制功能"
        }
    }
    
    var color: Color {
        switch self {
        case .recording: return .red
        case .window: return .blue
        case .action: return .green
        case .system: return .orange
        }
    }
}

// MARK: - 键盘快捷键
public struct KeyboardShortcut: Codable, Equatable {
    public let key: KeyEquivalent
    public let modifiers: SwiftUI.EventModifiers
    
    public init(_ key: KeyEquivalent, modifiers: SwiftUI.EventModifiers = []) {
        self.key = key
        self.modifiers = modifiers
    }
    
    // MARK: - Codable实现
    private enum CodingKeys: String, CodingKey {
        case keyCode
        case modifierFlags
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let keyCode = try container.decode(String.self, forKey: .keyCode)
        let modifierFlags = try container.decode(Int.self, forKey: .modifierFlags)
        
        self.key = KeyEquivalent(Character(keyCode))
        self.modifiers = EventModifiers(rawValue: modifierFlags)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(String(key.character), forKey: .keyCode)
        try container.encode(modifiers.rawValue, forKey: .modifierFlags)
    }
    
    // MARK: - 显示文本
    public var displayText: String {
        var components: [String] = []
        
        if modifiers.contains(.control) {
            components.append("⌃")
        }
        if modifiers.contains(.option) {
            components.append("⌥")
        }
        if modifiers.contains(.shift) {
            components.append("⇧")
        }
        if modifiers.contains(.command) {
            components.append("⌘")
        }
        
        components.append(key.displayText)
        
        return components.joined()
    }
    
    // MARK: - Carbon键码转换
    public var carbonKeyCode: Int32 {
        return key.carbonKeyCode
    }
    
    public var carbonModifierFlags: Int32 {
        var flags: Int32 = 0
        
        if modifiers.contains(.command) {
            flags |= Int32(cmdKey)
        }
        if modifiers.contains(.shift) {
            flags |= Int32(shiftKey)
        }
        if modifiers.contains(.option) {
            flags |= Int32(optionKey)
        }
        if modifiers.contains(.control) {
            flags |= Int32(controlKey)
        }
        
        return flags
    }
}

// MARK: - KeyEquivalent扩展
extension KeyEquivalent {
    var displayText: String {
        switch character {
        case " ": return "Space"
        case "\t": return "Tab"
        case "\r": return "Return"
        case "\u{1b}": return "Escape"
        case "\u{7f}": return "Delete"
        case "\u{f700}": return "↑"
        case "\u{f701}": return "↓"
        case "\u{f702}": return "←"
        case "\u{f703}": return "→"
        case "\u{f704}": return "F1"
        case "\u{f705}": return "F2"
        case "\u{f706}": return "F3"
        case "\u{f707}": return "F4"
        case "\u{f708}": return "F5"
        case "\u{f709}": return "F6"
        case "\u{f70a}": return "F7"
        case "\u{f70b}": return "F8"
        case "\u{f70c}": return "F9"
        case "\u{f70d}": return "F10"
        case "\u{f70e}": return "F11"
        case "\u{f70f}": return "F12"
        default: return String(character).uppercased()
        }
    }
    
    var carbonKeyCode: Int32 {
        switch character {
        case "a": return 0
        case "s": return 1
        case "d": return 2
        case "f": return 3
        case "h": return 4
        case "g": return 5
        case "z": return 6
        case "x": return 7
        case "c": return 8
        case "v": return 9
        case "b": return 11
        case "q": return 12
        case "w": return 13
        case "e": return 14
        case "r": return 15
        case "y": return 16
        case "t": return 17
        case "1": return 18
        case "2": return 19
        case "3": return 20
        case "4": return 21
        case "6": return 22
        case "5": return 23
        case "=": return 24
        case "9": return 25
        case "7": return 26
        case "-": return 27
        case "8": return 28
        case "0": return 29
        case "]": return 30
        case "o": return 31
        case "u": return 32
        case "[": return 33
        case "i": return 34
        case "p": return 35
        case "\r": return 36 // Return
        case "l": return 37
        case "j": return 38
        case "'": return 39
        case "k": return 40
        case ";": return 41
        case "\\": return 42
        case ",": return 43
        case "/": return 44
        case "n": return 45
        case "m": return 46
        case ".": return 47
        case "\t": return 48 // Tab
        case " ": return 49 // Space
        case "`": return 50
        case "\u{7f}": return 51 // Delete
        case "\u{1b}": return 53 // Escape
        case "\u{f700}": return 126 // Up Arrow
        case "\u{f701}": return 125 // Down Arrow
        case "\u{f702}": return 123 // Left Arrow
        case "\u{f703}": return 124 // Right Arrow
        case "\u{f704}": return 122 // F1
        case "\u{f705}": return 120 // F2
        case "\u{f706}": return 99  // F3
        case "\u{f707}": return 118 // F4
        case "\u{f708}": return 96  // F5
        case "\u{f709}": return 97  // F6
        case "\u{f70a}": return 98  // F7
        case "\u{f70b}": return 100 // F8
        case "\u{f70c}": return 101 // F9
        case "\u{f70d}": return 109 // F10
        case "\u{f70e}": return 103 // F11
        case "\u{f70f}": return 111 // F12
        default: return 0
        }
    }
}

// MARK: - 快捷键配置
public struct HotkeyConfiguration: Codable {
    public let identifier: HotkeyIdentifier
    public let shortcut: KeyboardShortcut
    public let isEnabled: Bool
    public let isGlobal: Bool
    public let description: String?
    
    public init(
        identifier: HotkeyIdentifier,
        shortcut: KeyboardShortcut,
        isEnabled: Bool = true,
        isGlobal: Bool = true,
        description: String? = nil
    ) {
        self.identifier = identifier
        self.shortcut = shortcut
        self.isEnabled = isEnabled
        self.isGlobal = isGlobal
        self.description = description
    }
    
    // MARK: - Codable实现
    private enum CodingKeys: String, CodingKey {
        case identifier
        case shortcut
        case isEnabled
        case isGlobal
        case description
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let identifierString = try container.decode(String.self, forKey: .identifier)
        
        guard let id = HotkeyIdentifier(rawValue: identifierString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .identifier,
                in: container,
                debugDescription: "Invalid hotkey identifier: \(identifierString)"
            )
        }
        
        self.identifier = id
        self.shortcut = try container.decode(KeyboardShortcut.self, forKey: .shortcut)
        self.isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        self.isGlobal = try container.decode(Bool.self, forKey: .isGlobal)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identifier.rawValue, forKey: .identifier)
        try container.encode(shortcut, forKey: .shortcut)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(isGlobal, forKey: .isGlobal)
        try container.encodeIfPresent(description, forKey: .description)
    }
}

// MARK: - 快捷键冲突检测
public struct HotkeyConflict {
    public let shortcut: KeyboardShortcut
    public let conflictingIdentifiers: [HotkeyIdentifier]
    public let systemConflicts: [SystemHotkeyConflict]
    
    public init(
        shortcut: KeyboardShortcut,
        conflictingIdentifiers: [HotkeyIdentifier] = [],
        systemConflicts: [SystemHotkeyConflict] = []
    ) {
        self.shortcut = shortcut
        self.conflictingIdentifiers = conflictingIdentifiers
        self.systemConflicts = systemConflicts
    }
    
    public var hasConflicts: Bool {
        return !conflictingIdentifiers.isEmpty || !systemConflicts.isEmpty
    }
    
    public var severity: ConflictSeverity {
        if !systemConflicts.isEmpty {
            return .critical
        } else if conflictingIdentifiers.count > 1 {
            return .high
        } else if conflictingIdentifiers.count == 1 {
            return .medium
        } else {
            return .none
        }
    }
    
    public enum ConflictSeverity: String, CaseIterable {
        case none = "无冲突"
        case medium = "轻微冲突"
        case high = "严重冲突"
        case critical = "系统冲突"
        
        var color: Color {
            switch self {
            case .none: return .green
            case .medium: return .yellow
            case .high: return .orange
            case .critical: return .red
            }
        }
    }
}

// MARK: - 系统快捷键冲突
public struct SystemHotkeyConflict {
    public let application: String
    public let function: String
    public let canOverride: Bool
    
    public init(application: String, function: String, canOverride: Bool = false) {
        self.application = application
        self.function = function
        self.canOverride = canOverride
    }
}

// MARK: - 快捷键事件
public struct HotkeyEvent {
    public let identifier: HotkeyIdentifier
    public let shortcut: KeyboardShortcut
    public let timestamp: Date
    public let source: EventSource
    
    public init(
        identifier: HotkeyIdentifier,
        shortcut: KeyboardShortcut,
        timestamp: Date = Date(),
        source: EventSource = .global
    ) {
        self.identifier = identifier
        self.shortcut = shortcut
        self.timestamp = timestamp
        self.source = source
    }
    
    public enum EventSource: String, CaseIterable {
        case global = "全局"
        case local = "本地"
        case system = "系统"
        case programmatic = "程序"
    }
}

// MARK: - 快捷键统计
public struct HotkeyStatistics {
    public let identifier: HotkeyIdentifier
    public let usageCount: Int
    public let lastUsed: Date?
    public let averageInterval: TimeInterval
    public let errorCount: Int
    
    public init(
        identifier: HotkeyIdentifier,
        usageCount: Int = 0,
        lastUsed: Date? = nil,
        averageInterval: TimeInterval = 0,
        errorCount: Int = 0
    ) {
        self.identifier = identifier
        self.usageCount = usageCount
        self.lastUsed = lastUsed
        self.averageInterval = averageInterval
        self.errorCount = errorCount
    }
    
    public var successRate: Double {
        guard usageCount > 0 else { return 0 }
        return Double(usageCount - errorCount) / Double(usageCount)
    }
    
    public var isFrequentlyUsed: Bool {
        return usageCount > 10 && averageInterval < 3600 // 1小时内使用超过10次
    }
}

// MARK: - 默认配置
extension HotkeyConfiguration {
    public static func defaultConfigurations() -> [HotkeyConfiguration] {
        return HotkeyIdentifier.allCases.compactMap { identifier in
            guard let shortcut = identifier.defaultShortcut else { return nil }
            return HotkeyConfiguration(
                identifier: identifier,
                shortcut: shortcut,
                description: identifier.description
            )
        }
    }
}