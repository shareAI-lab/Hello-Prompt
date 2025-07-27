//
//  ShortcutManager.swift
//  HelloPrompt
//
//  Hello Prompt - 极简的macOS语音到AI提示词转换工具
//  快捷键管理 + 配置集成
//

import Foundation
import KeyboardShortcuts
import Defaults

// MARK: - ShortcutManager
/// 快捷键管理器 - 负责应用程序的快捷键配置和管理
class ShortcutManager {
    static let shared = ShortcutManager()
    
    private init() {
        setupDefaultShortcuts()
    }
    
    // MARK: - 快捷键名称定义
    
    /// 录音快捷键
    static let recordingShortcut = KeyboardShortcuts.Name("recordingShortcut")
    
    /// 停止录音快捷键
    static let stopRecordingShortcut = KeyboardShortcuts.Name("stopRecordingShortcut")
    
    /// 切换窗口快捷键
    static let toggleWindowShortcut = KeyboardShortcuts.Name("toggleWindowShortcut")
    
    // MARK: - 快捷键配置
    
    /// 设置默认快捷键
    private func setupDefaultShortcuts() {
        // 设置默认快捷键组合
        if KeyboardShortcuts.getShortcut(for: Self.recordingShortcut) == nil {
            KeyboardShortcuts.setShortcut(.init(.r, modifiers: [.command, .shift]), for: Self.recordingShortcut)
        }
        
        if KeyboardShortcuts.getShortcut(for: Self.stopRecordingShortcut) == nil {
            KeyboardShortcuts.setShortcut(.init(.s, modifiers: [.command, .shift]), for: Self.stopRecordingShortcut)
        }
        
        if KeyboardShortcuts.getShortcut(for: Self.toggleWindowShortcut) == nil {
            KeyboardShortcuts.setShortcut(.init(.h, modifiers: [.command, .shift]), for: Self.toggleWindowShortcut)
        }
    }
    
    // MARK: - 快捷键获取和设置
    
    /// 获取录音快捷键
    func getRecordingShortcut() -> KeyboardShortcuts.Shortcut? {
        return KeyboardShortcuts.getShortcut(for: Self.recordingShortcut)
    }
    
    /// 设置录音快捷键
    func setRecordingShortcut(_ shortcut: KeyboardShortcuts.Shortcut?) {
        KeyboardShortcuts.setShortcut(shortcut, for: Self.recordingShortcut)
        // 更新配置存储
        Defaults[.recordingShortcutName] = shortcut?.description
    }
    
    /// 获取停止录音快捷键
    func getStopRecordingShortcut() -> KeyboardShortcuts.Shortcut? {
        return KeyboardShortcuts.getShortcut(for: Self.stopRecordingShortcut)
    }
    
    /// 设置停止录音快捷键
    func setStopRecordingShortcut(_ shortcut: KeyboardShortcuts.Shortcut?) {
        KeyboardShortcuts.setShortcut(shortcut, for: Self.stopRecordingShortcut)
        // 更新配置存储
        Defaults[.stopRecordingShortcutName] = shortcut?.description
    }
    
    /// 获取切换窗口快捷键
    func getToggleWindowShortcut() -> KeyboardShortcuts.Shortcut? {
        return KeyboardShortcuts.getShortcut(for: Self.toggleWindowShortcut)
    }
    
    /// 设置切换窗口快捷键
    func setToggleWindowShortcut(_ shortcut: KeyboardShortcuts.Shortcut?) {
        KeyboardShortcuts.setShortcut(shortcut, for: Self.toggleWindowShortcut)
        // 更新配置存储
        Defaults[.toggleWindowShortcutName] = shortcut?.description
    }
    
    // MARK: - 快捷键重置
    
    /// 重置所有快捷键到默认值
    func resetToDefaults() {
        setRecordingShortcut(.init(.r, modifiers: [.command, .shift]))
        setStopRecordingShortcut(.init(.s, modifiers: [.command, .shift]))
        setToggleWindowShortcut(.init(.h, modifiers: [.command, .shift]))
    }
    
    // MARK: - 快捷键启用/禁用
    
    /// 启用所有快捷键
    func enableAllShortcuts() {
        KeyboardShortcuts.enable(Self.recordingShortcut)
        KeyboardShortcuts.enable(Self.stopRecordingShortcut)
        KeyboardShortcuts.enable(Self.toggleWindowShortcut)
    }
    
    /// 禁用所有快捷键
    func disableAllShortcuts() {
        KeyboardShortcuts.disable(Self.recordingShortcut)
        KeyboardShortcuts.disable(Self.stopRecordingShortcut)
        KeyboardShortcuts.disable(Self.toggleWindowShortcut)
    }
    
    /// 检查快捷键是否启用
    func isShortcutEnabled(_ name: KeyboardShortcuts.Name) -> Bool {
        return KeyboardShortcuts.getShortcut(for: name) != nil
    }
}

// MARK: - 快捷键扩展

extension KeyboardShortcuts.Name {
    /// 录音快捷键
    static let recordingShortcut = ShortcutManager.recordingShortcut
    
    /// 停止录音快捷键
    static let stopRecordingShortcut = ShortcutManager.stopRecordingShortcut
    
    /// 切换窗口快捷键
    static let toggleWindowShortcut = ShortcutManager.toggleWindowShortcut
}