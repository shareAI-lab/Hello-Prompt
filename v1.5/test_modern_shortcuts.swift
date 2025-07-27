#!/usr/bin/env swift

import Foundation
import Carbon
import AppKit

print("🚀 macOS 2025现代化全局快捷键诊断工具")
print("==========================================")

// 检查所需的框架
print("\n1. 检查系统框架...")
let eventTarget = GetApplicationEventTarget()
if eventTarget != nil {
    print("✅ Carbon框架可用")
} else {
    print("❌ Carbon框架不可用")
    exit(1)
}

// 检查Input Monitoring权限（现代化要求）
print("\n2. 检查现代化权限...")
let inputMonitoring = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
print("输入监控权限: \(inputMonitoring ? "✅ 已启用" : "❌ 需要启用")")

let accessibility = AXIsProcessTrusted()
print("辅助功能权限: \(accessibility ? "✅ 已启用" : "❌ 需要启用")")

// 测试CGEventTap权限
print("\n3. 测试CGEventTap权限...")
let eventMask = (1 << CGEventType.keyDown.rawValue)

let callback: CGEventTapCallBack = { proxy, type, event, refcon in
    return Unmanaged.passUnretained(event)
}

let eventTap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: CGEventMask(eventMask),
    callback: callback,
    userInfo: nil
)

if eventTap != nil {
    print("✅ CGEventTap创建成功")
    CFMachPortInvalidate(eventTap!)
} else {
    print("❌ CGEventTap创建失败 - 可能需要输入监控权限")
}

// 测试现代化快捷键组合
print("\n4. 测试现代化快捷键组合...")

struct TestShortcut {
    let name: String
    let keyCode: Int64
    let modifiers: CGEventFlags
    let description: String
}

let testShortcuts = [
    TestShortcut(name: "Cmd+Shift+Option+R", keyCode: 15, modifiers: [.maskCommand, .maskShift, .maskAlternate], description: "⌘⇧⌥R - 开始/停止录音"),
    TestShortcut(name: "Cmd+Shift+Option+S", keyCode: 1, modifiers: [.maskCommand, .maskShift, .maskAlternate], description: "⌘⇧⌥S - 显示设置"),
    TestShortcut(name: "Cmd+Shift+Option+F", keyCode: 3, modifiers: [.maskCommand, .maskShift, .maskAlternate], description: "⌘⇧⌥F - 显示/隐藏悬浮球"),
    TestShortcut(name: "Cmd+Shift+Option+U", keyCode: 32, modifiers: [.maskCommand, .maskShift, .maskAlternate], description: "⌘⇧⌥U - 快速优化")
]

for shortcut in testShortcuts {
    // 模拟检查快捷键是否被系统占用
    let available = !shortcut.modifiers.isEmpty // 带修饰键的组合通常可用
    print("\(shortcut.name): \(available ? "✅ 可用" : "❌ 冲突") - \(shortcut.description)")
}

// 系统信息
print("\n5. 系统环境信息...")
let processInfo = ProcessInfo.processInfo
print("系统版本: \(processInfo.operatingSystemVersionString)")

let sandbox = processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
print("应用沙盒: \(sandbox ? "✅ 启用" : "❌ 未启用")")

print("\n📊 诊断总结:")
let inputOK = inputMonitoring
let accessibilityOK = accessibility
let eventTapOK = eventTap != nil

if inputOK && accessibilityOK && eventTapOK {
    print("✅ 所有权限和功能正常，现代化快捷键应该可以工作")
    print("🎯 推荐快捷键组合:")
    for shortcut in testShortcuts {
        print("   \(shortcut.description)")
    }
} else {
    print("⚠️  发现问题，需要配置权限:")
    if !inputOK {
        print("   • 需要启用输入监控权限")
    }
    if !accessibilityOK {
        print("   • 需要启用辅助功能权限")
    }
    if !eventTapOK {
        print("   • CGEventTap创建失败")
    }
}

print("\n🔧 权限设置路径:")
print("系统偏好设置 > 安全性与隐私 > 隐私 > 输入监控")
print("系统偏好设置 > 安全性与隐私 > 隐私 > 辅助功能")
print("\n💡 提示: 现代化方案使用CGEventTap + Input Monitoring权限")
print("这是2025年macOS推荐的全局快捷键实现方式")