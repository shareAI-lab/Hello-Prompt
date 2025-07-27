//
//  GlobalShortcutDiagnostic.swift
//  HelloPrompt
//
//  全局快捷键诊断工具 - 检测注册状态和错误原因
//  Copyright © 2025 HelloPrompt. All rights reserved.
//

import Foundation
import AppKit
import Carbon

/// 全局快捷键诊断工具
@MainActor
class GlobalShortcutDiagnostic {
    
    static let shared = GlobalShortcutDiagnostic()
    
    private var testHotKeys: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?
    
    private init() {}
    
    /// 执行完整的快捷键诊断
    func runFullDiagnostic() {
        print("🔍 开始全局快捷键诊断...")
        print("==========================================")
        
        // 1. 检查系统权限
        checkSystemPermissions()
        
        // 2. 检查Carbon框架可用性
        checkCarbonFramework()
        
        // 3. 测试事件处理器安装
        testEventHandlerInstallation()
        
        // 4. 测试快捷键注册
        testHotkeyRegistration()
        
        // 5. 测试冲突检测
        testConflictDetection()
        
        // 6. 测试安全快捷键
        testSafeShortcuts()
        
        print("==========================================")
        print("✅ 诊断完成")
        
        // 清理测试资源
        cleanup()
    }
    
    // MARK: - 诊断方法
    
    /// 检查系统权限
    private func checkSystemPermissions() {
        print("\n📋 检查系统权限:")
        
        // 检查辅助功能权限
        let accessibilityEnabled = AXIsProcessTrusted()
        print("  • 辅助功能权限: \(accessibilityEnabled ? "✅ 已授予" : "❌ 需要授予")")
        
        // 检查Input Monitoring权限（间接检测）
        let inputMonitoringStatus = checkInputMonitoringPermission()
        print("  • Input Monitoring权限: \(inputMonitoringStatus)")
        
        // 检查麦克风权限
        let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        print("  • 麦克风权限: \(getAuthStatusString(microphoneStatus))")
    }
    
    /// 间接检测Input Monitoring权限
    private func checkInputMonitoringPermission() -> String {
        // 尝试创建一个全局事件监听器来检测权限
        let monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { _ in }
        
        if monitor != nil {
            NSEvent.removeMonitor(monitor!)
            return "✅ 已授予"
        } else {
            return "❌ 需要授予"
        }
    }
    
    /// 获取授权状态字符串
    private func getAuthStatusString(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "✅ 已授予"
        case .denied: return "❌ 被拒绝"
        case .restricted: return "⚠️ 受限制"
        case .notDetermined: return "⚪ 未确定"
        @unknown default: return "❓ 未知状态"
        }
    }
    
    /// 检查Carbon框架可用性
    private func checkCarbonFramework() {
        print("\n🔧 检查Carbon框架:")
        
        // 测试基本的Carbon函数
        let appTarget = GetApplicationEventTarget()
        print("  • GetApplicationEventTarget: \(appTarget != nil ? "✅ 可用" : "❌ 失败")")
        
        // 测试事件类型定义
        let keyEventClass = OSType(kEventClassKeyboard)
        let hotKeyEvent = OSType(kEventHotKeyPressed)
        print("  • 事件类型定义: ✅ 正常 (class: \(keyEventClass), kind: \(hotKeyEvent))")
    }
    
    /// 测试事件处理器安装
    private func testEventHandlerInstallation() {
        print("\n⚡ 测试事件处理器安装:")
        
        let eventSpec = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        ]
        
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (handler, event, userData) -> OSStatus in
                print("    🎯 测试事件处理器被调用")
                return OSStatus(noErr)
            },
            1,
            eventSpec,
            nil,
            &eventHandler
        )
        
        print("  • 事件处理器安装: \(status == noErr ? "✅ 成功" : "❌ 失败 (状态码: \(status))")")
        
        if status == noErr {
            print("    ℹ️ 事件处理器地址: \(String(describing: eventHandler))")
        } else {
            print("    ❗ 错误详情: \(getOSStatusDescription(status))")
        }
    }
    
    /// 测试快捷键注册
    private func testHotkeyRegistration() {
        print("\n🎹 测试快捷键注册:")
        
        let testCases = [
            ("F5功能键", UInt32(kVK_F5), UInt32(0)),
            ("F6功能键", UInt32(kVK_F6), UInt32(0)),
            ("⌘⌃T (测试)", UInt32(17), UInt32(cmdKey | controlKey)), // T key
            ("⌘⌃Y (测试)", UInt32(16), UInt32(cmdKey | controlKey)), // Y key
            ("⌘⌃R (当前配置)", UInt32(15), UInt32(cmdKey | controlKey)), // R key
        ]
        
        for (name, keyCode, modifiers) in testCases {
            testSingleHotkey(name: name, keyCode: keyCode, modifiers: modifiers)
        }
    }
    
    /// 测试单个快捷键
    private func testSingleHotkey(name: String, keyCode: UInt32, modifiers: UInt32) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: fourCharCode("TEST"), id: UInt32(name.hashValue))
        
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        let statusDesc = status == noErr ? "✅ 成功" : "❌ 失败 (\(status))"
        print("  • \(name): \(statusDesc)")
        
        if status != noErr {
            print("    ❗ 错误详情: \(getOSStatusDescription(status))")
            
            // 尝试分析可能的原因
            analyzRegistrationFailure(keyCode: keyCode, modifiers: modifiers, status: status)
        } else if let hotKey = hotKeyRef {
            testHotKeys.append(hotKey)
            print("    ℹ️ 已注册，HotKey引用: \(String(describing: hotKey))")
        }
    }
    
    /// 分析注册失败原因
    private func analyzRegistrationFailure(keyCode: UInt32, modifiers: UInt32, status: OSStatus) {
        switch status {
        case -9868:
            print("    💡 可能原因: 修饰键参数无效")
        case -50:
            print("    💡 可能原因: 参数错误 (paramErr)")
        case -9850:
            print("    💡 可能原因: 事件已经被注册")
        default:
            print("    💡 未知错误码，请查阅文档")
        }
        
        // 检查是否是系统保留快捷键
        if isSystemReservedShortcut(keyCode: keyCode, modifiers: modifiers) {
            print("    ⚠️ 这可能是系统保留的快捷键组合")
        }
    }
    
    /// 检查是否是系统保留快捷键
    private func isSystemReservedShortcut(keyCode: UInt32, modifiers: UInt32) -> Bool {
        // 常见的系统保留快捷键
        let reserved = [
            (kVK_Tab, cmdKey), // Cmd+Tab
            (kVK_Space, cmdKey), // Cmd+Space (Spotlight)
            (kVK_ANSI_C, cmdKey), // Cmd+C
            (kVK_ANSI_V, cmdKey), // Cmd+V
            (kVK_ANSI_X, cmdKey), // Cmd+X
            (kVK_ANSI_Z, cmdKey), // Cmd+Z
        ]
        
        for (reservedKey, reservedMod) in reserved {
            if keyCode == UInt32(reservedKey) && (modifiers & UInt32(reservedMod)) != 0 {
                return true
            }
        }
        
        return false
    }
    
    /// 测试冲突检测
    private func testConflictDetection() {
        print("\n🔍 测试冲突检测:")
        
        let conflictCases = [
            ("⌘R (刷新)", UInt32(15), UInt32(cmdKey)),
            ("⌘⌃F (全屏)", UInt32(3), UInt32(cmdKey | controlKey)),
            ("⌘⌃U (查看源码)", UInt32(32), UInt32(cmdKey | controlKey)),
        ]
        
        for (name, keyCode, modifiers) in conflictCases {
            var hotKeyRef: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: fourCharCode("CONF"), id: UInt32(name.hashValue))
            
            let status = RegisterEventHotKey(
                keyCode,
                modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )
            
            if status == noErr {
                print("  • \(name): ⚠️ 可以注册，但可能与系统功能冲突")
                if let hotKey = hotKeyRef {
                    UnregisterEventHotKey(hotKey)
                }
            } else {
                print("  • \(name): ❌ 无法注册，可能已被占用")
            }
        }
    }
    
    /// 测试安全快捷键
    private func testSafeShortcuts() {
        print("\n🛡️ 推荐的安全快捷键:")
        
        let safeCases = [
            ("F5", UInt32(kVK_F5), UInt32(0)),
            ("F6", UInt32(kVK_F6), UInt32(0)),
            ("F7", UInt32(kVK_F7), UInt32(0)),
            ("F8", UInt32(kVK_F8), UInt32(0)),
            ("⌘⇧F1", UInt32(kVK_F1), UInt32(cmdKey | shiftKey)),
            ("⌘⇧F2", UInt32(kVK_F2), UInt32(cmdKey | shiftKey)),
            ("⌃⌥F5", UInt32(kVK_F5), UInt32(controlKey | optionKey)),
        ]
        
        var recommendedShortcuts: [String] = []
        
        for (name, keyCode, modifiers) in safeCases {
            var hotKeyRef: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: fourCharCode("SAFE"), id: UInt32(name.hashValue))
            
            let status = RegisterEventHotKey(
                keyCode,
                modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )
            
            if status == noErr {
                print("  • \(name): ✅ 可用")
                recommendedShortcuts.append(name)
                if let hotKey = hotKeyRef {
                    UnregisterEventHotKey(hotKey)
                }
            } else {
                print("  • \(name): ❌ 不可用")
            }
        }
        
        if !recommendedShortcuts.isEmpty {
            print("\n💡 推荐使用以下快捷键: \(recommendedShortcuts.joined(separator: ", "))")
        }
    }
    
    // MARK: - 工具方法
    
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
    
    /// 清理测试资源
    private func cleanup() {
        // 注销所有测试快捷键
        for hotKey in testHotKeys {
            UnregisterEventHotKey(hotKey)
        }
        testHotKeys.removeAll()
        
        // 移除事件处理器
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        
        print("\n🧹 清理完成")
    }
}

// MARK: - 键码常量
extension GlobalShortcutDiagnostic {
    // 功能键常量
    static let kVK_F1: Int = 0x7A
    static let kVK_F2: Int = 0x78
    static let kVK_F3: Int = 0x63
    static let kVK_F4: Int = 0x76
    static let kVK_F5: Int = 0x60
    static let kVK_F6: Int = 0x61
    static let kVK_F7: Int = 0x62
    static let kVK_F8: Int = 0x64
    static let kVK_F9: Int = 0x65
    static let kVK_F10: Int = 0x6D
    static let kVK_F11: Int = 0x67
    static let kVK_F12: Int = 0x6F
    
    // 字母键常量
    static let kVK_ANSI_A: Int = 0x00
    static let kVK_ANSI_C: Int = 0x08
    static let kVK_ANSI_V: Int = 0x09
    static let kVK_ANSI_X: Int = 0x07
    static let kVK_ANSI_Z: Int = 0x06
    
    // 特殊键常量
    static let kVK_Tab: Int = 0x30
    static let kVK_Space: Int = 0x31
}

// MARK: - 独立运行支持
#if DEBUG
extension GlobalShortcutDiagnostic {
    /// 作为独立工具运行
    static func runAsStandalone() {
        print("🚀 启动全局快捷键诊断工具")
        print("按 Ctrl+C 退出")
        
        Task { @MainActor in
            GlobalShortcutDiagnostic.shared.runFullDiagnostic()
            
            // 保持程序运行，以便测试快捷键响应
            print("\n⏳ 工具将在5秒后自动退出...")
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            exit(0)
        }
        
        RunLoop.main.run()
    }
}
#endif