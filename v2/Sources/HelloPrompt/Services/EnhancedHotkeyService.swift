//
//  EnhancedHotkeyService.swift
//  HelloPrompt
//
//  针对最新 macOS 系统优化的快捷键服务
//  基于现有 HotkeyService 的增强版本
//

import Foundation
import SwiftUI
import AppKit
import ApplicationServices
import os.log

// MARK: - 增强版快捷键服务
@MainActor
public final class EnhancedHotkeyService: NSObject, ObservableObject {
    
    // MARK: - 单例实例
    public static let shared = EnhancedHotkeyService()
    
    // MARK: - Published Properties
    @Published public var isEnabled = true
    @Published public var registeredHotkeys: [HotkeyIdentifier: KeyboardShortcut] = [:]
    @Published public var systemStatus: SystemStatus = .normal
    
    // MARK: - 私有属性
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let hotkeyQueue = DispatchQueue(label: "com.helloprompt.hotkey.enhanced", qos: .userInitiated)
    
    // 现代化事件处理
    private var hotkeyHandlers: [HotkeyIdentifier: () async -> Void] = [:]
    private let eventProcessor = EventProcessor()
    
    // Ctrl+U 状态管理
    private var ctrlUState: CtrlUState = .idle
    private var ctrlUPressTime: Date?
    private let minimumPressDuration: TimeInterval = 0.15 // 优化为 150ms
    
    // 系统监控
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    private var secureInputTimer: Timer?
    private var isInSecureMode = false
    
    // 回调
    var onCtrlURecordingStart: (() async -> Void)?
    var onCtrlURecordingStop: (() async -> Void)?
    
    // MARK: - 状态定义
    public enum SystemStatus {
        case normal
        case secureInputMode
        case lowMemory
        case permissionDenied
    }
    
    private enum CtrlUState {
        case idle
        case pressed
        case recording
        case debouncing
    }
    
    // MARK: - 初始化
    private override init() {
        super.init()
        setupEnhancedMonitoring()
        setupModernEventTap()
    }
    
    // MARK: - 现代化权限检查
    private func checkComprehensivePermissions() -> Bool {
        // 基础辅助功能权限
        let hasAccessibility = AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false
        ] as CFDictionary)
        
        // 检查安全输入模式
        let isSecureInput = IsSecureEventInputEnabled()
        
        if isSecureInput {
            systemStatus = .secureInputMode
            os_log(.info, log: .default, "检测到安全输入模式，暂时禁用快捷键")
            return false
        }
        
        if !hasAccessibility {
            systemStatus = .permissionDenied
            return false
        }
        
        systemStatus = .normal
        return true
    }
    
    // MARK: - 增强的事件监听设置
    private func setupModernEventTap() {
        Task {
            guard checkComprehensivePermissions() else { return }
            
            await createEnhancedEventTap()
        }
    }
    
    private func createEnhancedEventTap() async {
        let eventMask = (1 << CGEventType.keyDown.rawValue) | 
                       (1 << CGEventType.keyUp.rawValue) |
                       (1 << CGEventType.flagsChanged.rawValue)
        
        let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let service = Unmanaged<EnhancedHotkeyService>.fromOpaque(refcon!).takeUnretainedValue()
                return service.handleEnhancedEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        
        guard let eventTap = eventTap else {
            os_log(.error, log: .default, "无法创建增强事件监听器")
            return
        }
        
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        self.eventTap = eventTap
        self.runLoopSource = runLoopSource
        
        os_log(.info, log: .default, "增强事件监听器创建成功")
    }
    
    // MARK: - 优化的事件处理
    private nonisolated func handleEnhancedEvent(
        proxy: CGEventTapProxy, 
        type: CGEventType, 
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        
        // 快速路径：只处理我们关心的事件
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        
        // 优化的 Ctrl+U 处理
        if keyCode == 32 { // U key
            return handleCtrlUEvent(type: type, event: event, flags: flags)
        }
        
        // 处理其他快捷键
        if type == .keyDown {
            Task { @MainActor in
                await self.processRegisteredHotkeys(keyCode: Int32(keyCode), flags: flags)
            }
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    // MARK: - 优化的 Ctrl+U 事件处理
    private nonisolated func handleCtrlUEvent(
        type: CGEventType, 
        event: CGEvent, 
        flags: CGEventFlags
    ) -> Unmanaged<CGEvent>? {
        
        switch type {
        case .keyDown:
            if flags.contains(.maskControl) {
                Task { @MainActor in
                    await self.handleCtrlUPressed()
                }
                // 消费事件，防止系统默认行为（删除到行首）
                return nil
            }
            
        case .keyUp:
            Task { @MainActor in
                await self.handleCtrlUReleased()
            }
            return nil
            
        case .flagsChanged:
            // 处理 Ctrl 键释放的情况
            if !flags.contains(.maskControl) {
                Task { @MainActor in
                    await self.handleCtrlReleased()
                }
            }
            
        default:
            break
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    // MARK: - 现代化的 Ctrl+U 状态管理
    private func handleCtrlUPressed() async {
        guard ctrlUState == .idle else { return }
        
        ctrlUState = .pressed
        ctrlUPressTime = Date()
        
        os_log(.debug, log: .default, "Ctrl+U 按下，开始计时")
        
        // 使用现代 async/await 延迟
        try? await Task.sleep(nanoseconds: UInt64(minimumPressDuration * 1_000_000_000))
        
        // 检查是否仍在按压状态
        if ctrlUState == .pressed {
            ctrlUState = .recording
            os_log(.info, log: .default, "开始录音 - Ctrl+U 长按触发")
            await onCtrlURecordingStart?()
        }
    }
    
    private func handleCtrlUReleased() async {
        let pressDuration = ctrlUPressTime.map { Date().timeIntervalSince($0) } ?? 0
        
        switch ctrlUState {
        case .pressed:
            // 短按，不执行录音
            ctrlUState = .debouncing
            os_log(.debug, log: .default, "Ctrl+U 短按（%.3fs），忽略", pressDuration)
            
            // 短暂防抖
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            ctrlUState = .idle
            
        case .recording:
            // 正在录音，停止录音
            ctrlUState = .idle
            os_log(.info, log: .default, "停止录音 - Ctrl+U 释放（%.3fs）", pressDuration)
            await onCtrlURecordingStop?()
            
        default:
            ctrlUState = .idle
        }
        
        ctrlUPressTime = nil
    }
    
    private func handleCtrlReleased() async {
        // Ctrl 键释放，无论 U 是否还在按压都停止录音
        if ctrlUState == .recording {
            ctrlUState = .idle
            os_log(.info, log: .default, "停止录音 - Ctrl 键释放")
            await onCtrlURecordingStop?()
        } else if ctrlUState == .pressed {
            ctrlUState = .idle
        }
        ctrlUPressTime = nil
    }
    
    // MARK: - 处理其他注册的快捷键
    private func processRegisteredHotkeys(keyCode: Int32, flags: CGEventFlags) async {
        for (identifier, shortcut) in registeredHotkeys {
            if keyCode == shortcut.carbonKeyCode && 
               matchesModifiers(flags, shortcut.carbonModifierFlags) {
                
                os_log(.info, log: .default, "触发快捷键: %@", identifier.rawValue)
                await hotkeyHandlers[identifier]?()
                break
            }
        }
    }
    
    // MARK: - 系统监控设置
    private func setupEnhancedMonitoring() {
        // 内存压力监控
        setupMemoryPressureMonitoring()
        
        // 安全输入模式监控
        setupSecureInputMonitoring()
    }
    
    private func setupMemoryPressureMonitoring() {
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .global(qos: .utility)
        )
        
        memoryPressureSource?.setEventHandler { [weak self] in
            guard let self = self else { return }
            let event = self.memoryPressureSource?.mask ?? []
            
            Task { @MainActor in
                if event.contains(.critical) {
                    self.systemStatus = .lowMemory
                    os_log(.warning, log: .default, "内存压力严重，进入低功耗模式")
                } else if event.contains(.warning) {
                    os_log(.info, log: .default, "检测到内存压力警告")
                }
            }
        }
        
        memoryPressureSource?.resume()
    }
    
    private func setupSecureInputMonitoring() {
        secureInputTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let wasSecure = self.isInSecureMode
            let isSecure = IsSecureEventInputEnabled()
            
            if wasSecure != isSecure {
                Task { @MainActor in
                    self.isInSecureMode = isSecure
                    self.systemStatus = isSecure ? .secureInputMode : .normal
                    
                    if isSecure {
                        os_log(.info, log: .default, "进入安全输入模式，禁用快捷键")
                    } else {
                        os_log(.info, log: .default, "退出安全输入模式，恢复快捷键")
                    }
                }
            }
        }
    }
    
    // MARK: - 现代化快捷键注册
    public func registerHotkey(
        _ identifier: HotkeyIdentifier,
        shortcut: KeyboardShortcut,
        handler: @escaping () async -> Void
    ) -> Bool {
        guard isEnabled && systemStatus == .normal else { return false }
        
        registeredHotkeys[identifier] = shortcut
        hotkeyHandlers[identifier] = handler
        
        os_log(.info, log: .default, "注册快捷键: %@ -> %@", 
               identifier.rawValue, shortcut.displayText)
        
        return true
    }
    
    // MARK: - 辅助方法
    private nonisolated func matchesModifiers(_ eventFlags: CGEventFlags, _ targetModifiers: Int32) -> Bool {
        let cmdKey: UInt32 = 256
        let shiftKey: UInt32 = 512
        let optionKey: UInt32 = 2048
        let controlKey: UInt32 = 4096
        
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
    
    // MARK: - 清理
    deinit {
        secureInputTimer?.invalidate()
        memoryPressureSource?.cancel()
        
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFRelease(eventTap)
        }
    }
}

// MARK: - 事件处理器
private class EventProcessor {
    private let processingQueue = DispatchQueue(
        label: "com.helloprompt.event.processing",
        qos: .userInitiated,
        attributes: .concurrent
    )
    
    func processEventBatch(_ events: [CGEvent]) async {
        // 批量处理事件以提高性能
        let chunks = events.chunked(into: 10)
        
        await withTaskGroup(of: Void.self) { group in
            for chunk in chunks {
                group.addTask {
                    await self.processChunk(chunk)
                }
            }
        }
    }
    
    private func processChunk(_ events: [CGEvent]) async {
        // 处理单个事件块
        for event in events {
            // 事件处理逻辑
        }
    }
}

// MARK: - Array 扩展
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}