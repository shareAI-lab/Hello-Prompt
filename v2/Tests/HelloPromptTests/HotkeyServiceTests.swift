//
//  HotkeyServiceTests.swift
//  HelloPrompt
//
//  快捷键服务测试套件 - 测试快捷键注册、事件处理、冲突检测等功能
//  包含系统级快捷键测试和性能验证
//

import XCTest
import Carbon
import AppKit
import Combine
@testable import HelloPrompt

class HotkeyServiceTests: HelloPromptTestCase, HotkeyServiceTestable {
    
    // MARK: - 测试属性
    var hotkeyService: HotkeyService!
    var mockEventHandler: MockEventHandler!
    var registeredHotkeys: Set<HotkeyIdentifier>!
    
    override func setUp() async throws {
        try await super.setUp()
        
        hotkeyService = HotkeyService.shared
        mockEventHandler = MockEventHandler()
        registeredHotkeys = Set<HotkeyIdentifier>()
        
        // 配置测试环境
        await setupHotkeyTestEnvironment()
    }
    
    override func tearDown() async throws {
        await cleanupHotkeyTestEnvironment()
        
        hotkeyService = nil
        mockEventHandler = nil
        registeredHotkeys = nil
        
        try await super.tearDown()
    }
    
    // MARK: - 环境设置
    
    @MainActor
    private func setupHotkeyTestEnvironment() async {
        // 清理之前注册的快捷键
        hotkeyService.resetToDefaults()
        
        // 启用快捷键服务
        hotkeyService.enable()
        
        XCTAssertTrue(hotkeyService.isEnabled, "Hotkey service should be enabled")
    }
    
    @MainActor
    private func cleanupHotkeyTestEnvironment() async {
        // 清理所有测试注册的快捷键
        for identifier in registeredHotkeys {
            _ = hotkeyService.unregisterHotkey(identifier)
        }
        
        // 禁用快捷键服务
        hotkeyService.disable()
        
        registeredHotkeys.removeAll()
    }
    
    // MARK: - 快捷键注册测试
    
    func testHotkeyRegistration() throws {
        // 测试基本快捷键注册
        let testIdentifier = HotkeyIdentifier.startRecording
        let testShortcut = KeyboardShortcut(.space, modifiers: [.option, .command])
        var handlerCalled = false
        
        let success = hotkeyService.registerHotkey(testIdentifier, shortcut: testShortcut) {
            handlerCalled = true
        }
        
        XCTAssertTrue(success, "Hotkey registration should succeed")
        XCTAssertTrue(hotkeyService.registeredHotkeys.keys.contains(testIdentifier), "Hotkey should be in registered list")
        XCTAssertEqual(hotkeyService.registeredHotkeys[testIdentifier], testShortcut, "Registered shortcut should match")
        
        registeredHotkeys.insert(testIdentifier)
        
        // 模拟快捷键事件
        simulateHotkeyEvent(for: testIdentifier)
        
        // 给事件处理一些时间
        let expectation = XCTestExpectation(description: "Handler execution")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(handlerCalled, "Handler should be called when hotkey is triggered")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testMultipleHotkeyRegistration() throws {
        // 测试多个快捷键注册
        let testIdentifiers: [HotkeyIdentifier] = [.startRecording, .stopRecording, .showSettings]
        let testShortcuts: [KeyboardShortcut] = [
            KeyboardShortcut(.space, modifiers: [.option, .command]),
            KeyboardShortcut(.escape, modifiers: [.option]),
            KeyboardShortcut(.comma, modifiers: [.option, .command])
        ]
        
        var handlerCallCounts: [HotkeyIdentifier: Int] = [:]
        
        for (identifier, shortcut) in zip(testIdentifiers, testShortcuts) {
            handlerCallCounts[identifier] = 0
            
            let success = hotkeyService.registerHotkey(identifier, shortcut: shortcut) {
                handlerCallCounts[identifier, default: 0] += 1
            }
            
            XCTAssertTrue(success, "Registration should succeed for \(identifier)")
            registeredHotkeys.insert(identifier)
        }
        
        XCTAssertEqual(hotkeyService.registeredHotkeys.count, testIdentifiers.count, "All hotkeys should be registered")
        
        // 测试每个快捷键
        for identifier in testIdentifiers {
            simulateHotkeyEvent(for: identifier)
        }
        
        // 验证处理器调用
        let expectation = XCTestExpectation(description: "Multiple handlers execution")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            for identifier in testIdentifiers {
                XCTAssertEqual(handlerCallCounts[identifier], 1, "Handler for \(identifier) should be called once")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testDuplicateHotkeyRegistration() throws {
        // 测试重复注册同一快捷键
        let identifier = HotkeyIdentifier.insertResult
        let shortcut = KeyboardShortcut(.return, modifiers: [.option])
        var firstHandlerCallCount = 0
        var secondHandlerCallCount = 0
        
        // 第一次注册
        let firstSuccess = hotkeyService.registerHotkey(identifier, shortcut: shortcut) {
            firstHandlerCallCount += 1
        }
        XCTAssertTrue(firstSuccess, "First registration should succeed")
        registeredHotkeys.insert(identifier)
        
        // 第二次注册（应该覆盖第一次）
        let secondSuccess = hotkeyService.registerHotkey(identifier, shortcut: shortcut) {
            secondHandlerCallCount += 1
        }
        XCTAssertTrue(secondSuccess, "Second registration should succeed and override first")
        
        // 触发快捷键
        simulateHotkeyEvent(for: identifier)
        
        let expectation = XCTestExpectation(description: "Override handler execution")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(firstHandlerCallCount, 0, "First handler should not be called")
            XCTAssertEqual(secondHandlerCallCount, 1, "Second handler should be called")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - 快捷键取消注册测试
    
    func testHotkeyUnregistration() throws {
        // 测试快捷键取消注册
        let identifier = HotkeyIdentifier.copyResult
        let shortcut = KeyboardShortcut("c", modifiers: [.option, .command])
        var handlerCallCount = 0
        
        // 注册快捷键
        let registerSuccess = hotkeyService.registerHotkey(identifier, shortcut: shortcut) {
            handlerCallCount += 1
        }
        XCTAssertTrue(registerSuccess, "Registration should succeed")
        registeredHotkeys.insert(identifier)
        
        // 取消注册
        let unregisterSuccess = hotkeyService.unregisterHotkey(identifier)
        XCTAssertTrue(unregisterSuccess, "Unregistration should succeed")
        XCTAssertFalse(hotkeyService.registeredHotkeys.keys.contains(identifier), "Hotkey should be removed from registered list")
        
        registeredHotkeys.remove(identifier)
        
        // 尝试触发已取消注册的快捷键
        simulateHotkeyEvent(for: identifier)
        
        let expectation = XCTestExpectation(description: "Unregistered handler should not execute")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(handlerCallCount, 0, "Handler should not be called after unregistration")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testUnregisterNonexistentHotkey() throws {
        // 测试取消注册不存在的快捷键
        let nonexistentIdentifier = HotkeyIdentifier.togglePause
        
        let success = hotkeyService.unregisterHotkey(nonexistentIdentifier)
        XCTAssertFalse(success, "Unregistering nonexistent hotkey should fail")
    }
    
    // MARK: - 快捷键更新测试
    
    func testHotkeyUpdate() throws {
        // 测试快捷键更新
        let identifier = HotkeyIdentifier.retryRecording
        let originalShortcut = KeyboardShortcut("r", modifiers: [.option, .command])
        let newShortcut = KeyboardShortcut("r", modifiers: [.control, .command])
        var handlerCallCount = 0
        
        // 注册原始快捷键
        let registerSuccess = hotkeyService.registerHotkey(identifier, shortcut: originalShortcut) {
            handlerCallCount += 1
        }
        XCTAssertTrue(registerSuccess, "Original registration should succeed")
        registeredHotkeys.insert(identifier)
        
        // 更新快捷键
        let updateSuccess = hotkeyService.updateHotkey(identifier, newShortcut: newShortcut) {
            handlerCallCount += 1
        }
        XCTAssertTrue(updateSuccess, "Hotkey update should succeed")
        XCTAssertEqual(hotkeyService.registeredHotkeys[identifier], newShortcut, "Registered shortcut should be updated")
        
        // 测试新快捷键有效，旧快捷键无效
        simulateHotkeyEvent(for: identifier, withShortcut: newShortcut)
        
        let expectation = XCTestExpectation(description: "Updated handler execution")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(handlerCallCount, 1, "Handler should be called with new shortcut")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - 快捷键冲突检测测试
    
    func testHotkeyConflictDetection() async throws {
        // 测试快捷键冲突检测
        let systemConflictShortcut = KeyboardShortcut(.space, modifiers: [.command]) // Spotlight
        let identifier = HotkeyIdentifier.startRecording
        
        // 注册与系统快捷键冲突的快捷键
        let success = hotkeyService.registerHotkey(identifier, shortcut: systemConflictShortcut) {
            // 空处理器
        }
        
        if success {
            registeredHotkeys.insert(identifier)
            
            // 检查冲突
            let conflicts = await hotkeyService.checkConflicts()
            
            XCTAssertGreaterThan(conflicts.count, 0, "Should detect conflicts")
            
            let hasSystemConflict = conflicts.contains { conflict in
                conflict.identifier == identifier && conflict.conflictingApp == "系统"
            }
            XCTAssertTrue(hasSystemConflict, "Should detect system conflict")
        }
    }
    
    func testAlternativeShortcutSuggestions() throws {
        // 测试替代快捷键建议
        let identifier = HotkeyIdentifier.showSettings
        let suggestions = hotkeyService.suggestAlternativeShortcuts(for: identifier)
        
        XCTAssertGreaterThan(suggestions.count, 0, "Should provide alternative suggestions")
        XCTAssertLessThanOrEqual(suggestions.count, 5, "Should not provide too many suggestions")
        
        // 验证建议的快捷键未被注册
        for suggestion in suggestions {
            let isRegistered = hotkeyService.registeredHotkeys.values.contains(suggestion)
            XCTAssertFalse(isRegistered, "Suggested shortcut should not be already registered")
        }
    }
    
    // MARK: - 服务状态测试
    
    func testServiceEnableDisable() throws {
        // 测试服务启用/禁用
        hotkeyService.disable()
        XCTAssertFalse(hotkeyService.isEnabled, "Service should be disabled")
        
        // 尝试在禁用状态下注册快捷键
        let identifier = HotkeyIdentifier.cancelOperation
        let shortcut = KeyboardShortcut(.escape, modifiers: [.option, .command])
        
        let registerSuccess = hotkeyService.registerHotkey(identifier, shortcut: shortcut) {
            // 空处理器
        }
        
        // 注册可能成功，但不会生效
        hotkeyService.enable()
        XCTAssertTrue(hotkeyService.isEnabled, "Service should be enabled")
        
        if registerSuccess {
            registeredHotkeys.insert(identifier)
        }
    }
    
    func testServiceStatus() throws {
        // 测试服务状态获取
        let status = hotkeyService.getServiceStatus()
        
        XCTAssertNotNil(status["isEnabled"], "Status should include enabled state")
        XCTAssertNotNil(status["registeredCount"], "Status should include registered count")
        XCTAssertNotNil(status["handlerCount"], "Status should include handler count")
        XCTAssertNotNil(status["conflictCount"], "Status should include conflict count")
        XCTAssertNotNil(status["registeredHotkeys"], "Status should include registered hotkeys")
        
        let isEnabled = status["isEnabled"] as? Bool
        XCTAssertEqual(isEnabled, hotkeyService.isEnabled, "Status should reflect actual enabled state")
    }
    
    // MARK: - 配置导入导出测试
    
    func testConfigurationExport() throws {
        // 测试配置导出
        let testIdentifiers: [HotkeyIdentifier] = [.startRecording, .stopRecording]
        let testShortcuts: [KeyboardShortcut] = [
            KeyboardShortcut(.space, modifiers: [.option, .command]),
            KeyboardShortcut(.escape, modifiers: [.option])
        ]
        
        // 注册测试快捷键
        for (identifier, shortcut) in zip(testIdentifiers, testShortcuts) {
            let success = hotkeyService.registerHotkey(identifier, shortcut: shortcut) {
                // 空处理器
            }
            XCTAssertTrue(success, "Registration should succeed for export test")
            registeredHotkeys.insert(identifier)
        }
        
        // 导出配置
        let exportData = hotkeyService.exportConfiguration()
        XCTAssertNotNil(exportData, "Should be able to export configuration")
        
        if let data = exportData {
            XCTAssertGreaterThan(data.count, 0, "Export data should not be empty")
            
            // 验证导出的JSON格式
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                XCTAssertTrue(json is [String: Any], "Export should be valid JSON object")
            } catch {
                XCTFail("Export data should be valid JSON: \(error)")
            }
        }
    }
    
    func testConfigurationImport() throws {
        // 测试配置导入
        let importConfig = [
            "startRecording": [
                "key": " ",
                "modifiers": NSEvent.ModifierFlags([.option, .command]).rawValue,
                "displayString": "⌥⌘Space"
            ],
            "stopRecording": [
                "key": "\\u{001B}", // Escape
                "modifiers": NSEvent.ModifierFlags([.option]).rawValue,
                "displayString": "⌥⎋"
            ]
        ]
        
        let importData = try JSONSerialization.data(withJSONObject: importConfig, options: [])
        let success = hotkeyService.importConfiguration(importData)
        
        XCTAssertTrue(success, "Configuration import should succeed")
        
        // 验证导入的配置
        XCTAssertTrue(hotkeyService.registeredHotkeys.keys.contains(.startRecording), "Start recording hotkey should be imported")
        XCTAssertTrue(hotkeyService.registeredHotkeys.keys.contains(.stopRecording), "Stop recording hotkey should be imported")
        
        registeredHotkeys.insert(.startRecording)
        registeredHotkeys.insert(.stopRecording)
    }
    
    // MARK: - 性能测试
    
    func testHotkeyRegistrationPerformance() throws {
        // 测试快捷键注册性能
        let testIdentifiers = HotkeyIdentifier.allCases
        let baseShortcuts = [
            KeyboardShortcut("a", modifiers: [.option, .command]),
            KeyboardShortcut("b", modifiers: [.option, .command]),
            KeyboardShortcut("c", modifiers: [.option, .command]),
            KeyboardShortcut("d", modifiers: [.option, .command]),
            KeyboardShortcut("e", modifiers: [.option, .command]),
            KeyboardShortcut("f", modifiers: [.option, .command]),
            KeyboardShortcut("g", modifiers: [.option, .command]),
            KeyboardShortcut("h", modifiers: [.option, .command])
        ]
        
        measure {
            for (index, identifier) in testIdentifiers.enumerated() {
                let shortcut = baseShortcuts[index % baseShortcuts.count]
                _ = hotkeyService.registerHotkey(identifier, shortcut: shortcut) {
                    // 空处理器
                }
                registeredHotkeys.insert(identifier)
            }
            
            // 清理
            for identifier in testIdentifiers {
                _ = hotkeyService.unregisterHotkey(identifier)
                registeredHotkeys.remove(identifier)
            }
        }
    }
    
    func testHotkeyEventHandlingPerformance() throws {
        // 测试快捷键事件处理性能
        let identifier = HotkeyIdentifier.startRecording
        let shortcut = KeyboardShortcut(.space, modifiers: [.option, .command])
        var handlerCallCount = 0
        
        let success = hotkeyService.registerHotkey(identifier, shortcut: shortcut) {
            handlerCallCount += 1
        }
        XCTAssertTrue(success, "Registration should succeed for performance test")
        registeredHotkeys.insert(identifier)
        
        measure {
            for _ in 0..<100 {
                simulateHotkeyEvent(for: identifier)
            }
        }
        
        // 给事件处理一些时间
        let expectation = XCTestExpectation(description: "Performance test completion")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertEqual(handlerCallCount, 100, "All handlers should be called")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - 边界条件测试
    
    func testInvalidShortcutRegistration() throws {
        // 测试无效快捷键注册
        let identifier = HotkeyIdentifier.insertResult
        
        // 测试无修饰符的字母键（通常不建议）
        let invalidShortcut = KeyboardShortcut("a", modifiers: [])
        
        let success = hotkeyService.registerHotkey(identifier, shortcut: invalidShortcut) {
            // 空处理器
        }
        
        // 结果可能成功也可能失败，取决于系统实现
        if success {
            registeredHotkeys.insert(identifier)
        }
    }
    
    func testMaximumHotkeyRegistration() throws {
        // 测试最大快捷键注册数量
        var registeredCount = 0
        let maxAttempts = 50 // 尝试注册50个快捷键
        
        for i in 0..<maxAttempts {
            let identifier = HotkeyIdentifier.allCases[i % HotkeyIdentifier.allCases.count]
            let shortcut = KeyboardShortcut(
                Character(UnicodeScalar(65 + i % 26)!), // A-Z循环
                modifiers: [.option, .command]
            )
            
            let success = hotkeyService.registerHotkey(identifier, shortcut: shortcut) {
                // 空处理器
            }
            
            if success {
                registeredCount += 1
                registeredHotkeys.insert(identifier)
            } else {
                break
            }
        }
        
        XCTAssertGreaterThan(registeredCount, 0, "Should be able to register at least some hotkeys")
        print("Successfully registered \(registeredCount) hotkeys")
    }
    
    // MARK: - 辅助方法
    
    /// 模拟快捷键事件
    private func simulateHotkeyEvent(for identifier: HotkeyIdentifier, withShortcut shortcut: KeyboardShortcut? = nil) {
        // 这是一个简化的模拟，实际的Carbon事件模拟更复杂
        let hotkeyID = EventHotKeyID(
            signature: OSType(identifier.rawValue.hashValue),
            id: UInt32(identifier.hashValue)
        )
        
        // 直接调用处理方法（在实际测试中，这会通过系统事件机制触发）
        DispatchQueue.main.async {
            // 模拟事件处理
            self.mockEventHandler.handleHotkeyEvent(hotkeyID)
        }
    }
}

// MARK: - Mock事件处理器

class MockEventHandler {
    weak var hotkeyService: HotkeyService?
    
    func handleHotkeyEvent(_ hotkeyID: EventHotKeyID) {
        // 这里应该模拟实际的快捷键事件处理逻辑
        // 在真实环境中，这会通过Carbon事件系统调用
        print("Mock hotkey event: signature=\(hotkeyID.signature), id=\(hotkeyID.id)")
    }
}

// MARK: - 测试扩展

extension KeyboardShortcut {
    init(_ character: Character, modifiers: NSEvent.ModifierFlags) {
        self.init(KeyEquivalent(character), modifiers: modifiers)
    }
}