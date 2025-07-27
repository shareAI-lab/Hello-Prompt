#!/usr/bin/env swift

import Foundation
import Carbon

print("🔍 macOS全局快捷键诊断工具")
print("=============================")

// 测试Carbon框架可用性
print("\n1. 检查Carbon框架状态...")
let eventTarget = GetApplicationEventTarget()
if eventTarget != nil {
    print("✅ Carbon框架可用")
} else {
    print("❌ Carbon框架不可用")
    exit(1)
}

// 测试权限状态
print("\n2. 检查系统权限...")
let accessibilityEnabled = AXIsProcessTrusted()
print("辅助功能权限: \(accessibilityEnabled ? "✅ 已启用" : "❌ 未启用")")

// 测试快捷键注册
print("\n3. 测试快捷键注册...")

func testHotKeyRegistration(keyCode: UInt16, modifiers: UInt32, name: String) -> Bool {
    let hotKeyID = EventHotKeyID(signature: fourCharCode("TEST"), id: UInt32(keyCode))
    var hotKeyRef: EventHotKeyRef?
    
    let status = RegisterEventHotKey(
        UInt32(keyCode),
        modifiers,
        hotKeyID,
        GetApplicationEventTarget(),
        0,
        &hotKeyRef
    )
    
    if let hotKey = hotKeyRef {
        UnregisterEventHotKey(hotKey)
    }
    
    let success = (status == noErr)
    print("\(name) (键码:\(keyCode)): \(success ? "✅ 可注册" : "❌ 注册失败(状态:\(status))")")
    return success
}

func fourCharCode(_ string: String) -> OSType {
    let data = string.data(using: .utf8) ?? Data()
    let bytes = data.prefix(4)
    var result: OSType = 0
    
    for (index, byte) in bytes.enumerated() {
        result |= OSType(byte) << (8 * (3 - index))
    }
    
    return result
}

// 测试安全的功能键
let testKeys = [
    (96, UInt32(0), "F5"),           // F5键，无修饰符
    (97, UInt32(0), "F6"),           // F6键
    (98, UInt32(0), "F7"),           // F7键
    (99, UInt32(0), "F8"),           // F8键
    (15, UInt32(cmdKey | controlKey), "⌘⌃R"), // Command+Control+R
]

var successCount = 0
for (keyCode, modifiers, name) in testKeys {
    if testHotKeyRegistration(keyCode: keyCode, modifiers: modifiers, name: name) {
        successCount += 1
    }
}

print("\n📊 测试结果:")
print("成功注册: \(successCount)/\(testKeys.count)")
print("\n💡 建议:")
if successCount == 0 {
    print("❌ 所有快捷键都无法注册，请检查:")
    print("   1. 是否在系统偏好设置中启用了辅助功能权限")
    print("   2. 是否需要输入监控权限")
    print("   3. 应用是否有正确的权限配置")
} else if successCount < testKeys.count {
    print("⚠️  部分快捷键冲突，建议使用功能键(F5-F8)")
} else {
    print("✅ 所有快捷键都可以正常注册!")
}

print("\n🔧 权限设置路径:")
print("系统偏好设置 > 安全性与隐私 > 隐私 > 辅助功能")
print("系统偏好设置 > 安全性与隐私 > 隐私 > 输入监控")