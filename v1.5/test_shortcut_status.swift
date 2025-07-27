#!/usr/bin/env swift

import Foundation
import AppKit
import Carbon

print("🔍 Hello Prompt Shortcut System Diagnostic")
print("==========================================")

// Check Input Monitoring Permission
print("\n📋 Permission Status:")

// Method 1: CGPreflightListenEventAccess
let cgPreflightResult = CGPreflightListenEventAccess()
print("  • CGPreflightListenEventAccess: \(cgPreflightResult ? "✅ True" : "❌ False")")

// Method 2: Try creating a global event monitor
let monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { _ in }
if monitor != nil {
    NSEvent.removeMonitor(monitor!)
    print("  • NSEvent Global Monitor: ✅ Can create (permission granted)")
} else {
    print("  • NSEvent Global Monitor: ❌ Cannot create (permission denied)")
}

// Check Accessibility Permission
let accessibilityEnabled = AXIsProcessTrusted()
print("  • Accessibility Permission: \(accessibilityEnabled ? "✅ Granted" : "❌ Denied")")

// Test Carbon Hotkey Registration
print("\n🎹 Carbon Hotkey Test:")

var testHotKeyRef: EventHotKeyRef?
let hotKeyID = EventHotKeyID(signature: OSType(fourCharCode("TEST")), id: 1)

let status = RegisterEventHotKey(
    UInt32(96), // F5 key
    UInt32(0),  // No modifiers
    hotKeyID,
    GetApplicationEventTarget(),
    0,
    &testHotKeyRef
)

if status == noErr {
    print("  • F5 Hotkey Registration: ✅ Success")
    if let hotKey = testHotKeyRef {
        UnregisterEventHotKey(hotKey)
        print("  • F5 Hotkey Cleanup: ✅ Success")
    }
} else {
    print("  • F5 Hotkey Registration: ❌ Failed (Status: \(status))")
    
    switch status {
    case -50:
        print("    → Error: Parameter error (paramErr)")
    case -9868:
        print("    → Error: Invalid modifier key parameter")
    case -9850:
        print("    → Error: Event already registered")
    default:
        print("    → Error: Unknown status code \(status)")
    }
}

// Test CGEventTap Creation
print("\n⚡ CGEventTap Test:")

let eventMask = (1 << CGEventType.keyDown.rawValue)
let eventTap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: CGEventMask(eventMask),
    callback: { _, _, event, _ in
        return Unmanaged.passUnretained(event)
    },
    userInfo: nil
)

if eventTap != nil {
    print("  • CGEvent Tap Creation: ✅ Success")
    CFMachPortInvalidate(eventTap!)
} else {
    print("  • CGEvent Tap Creation: ❌ Failed (likely permission issue)")
}

print("\n💡 Recommendations:")

if !cgPreflightResult && monitor == nil {
    print("  • Enable Input Monitoring permission in System Preferences")
    print("    → System Preferences > Security & Privacy > Privacy > Input Monitoring")
}

if !accessibilityEnabled {
    print("  • Enable Accessibility permission in System Preferences")
    print("    → System Preferences > Security & Privacy > Privacy > Accessibility")
}

if status != noErr {
    print("  • Carbon hotkey registration failed - try alternative shortcuts")
}

print("\n==========================================")
print("✅ Diagnostic Complete")

// Helper function to create four-character codes
func fourCharCode(_ string: String) -> UInt32 {
    let data = string.data(using: .utf8) ?? Data()
    let bytes = data.prefix(4)
    var result: UInt32 = 0
    
    for (index, byte) in bytes.enumerated() {
        result |= UInt32(byte) << (8 * (3 - index))
    }
    
    return result
}