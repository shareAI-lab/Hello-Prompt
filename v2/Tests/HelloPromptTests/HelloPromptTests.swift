//
//  HelloPromptTests.swift
//  HelloPrompt
//
//  测试框架入口 - 组织和管理所有测试类型
//  提供基础测试工具和共享资源
//

import XCTest
import Combine
@testable import HelloPrompt

// MARK: - 测试基类
open class HelloPromptTestCase: XCTestCase {
    
    // MARK: - 共享属性
    var cancellables: Set<AnyCancellable>!
    var testLogManager: TestLogManager!
    var mockConfigManager: MockConfigManager!
    var mockErrorHandler: MockErrorHandler!
    
    // MARK: - 生命周期管理
    
    override func setUp() async throws {
        try await super.setUp()
        
        // 初始化共享资源
        cancellables = Set<AnyCancellable>()
        testLogManager = TestLogManager()
        mockConfigManager = MockConfigManager()
        mockErrorHandler = MockErrorHandler()
        
        // 配置测试环境
        await setupTestEnvironment()
    }
    
    override func tearDown() async throws {
        // 清理资源
        await cleanupTestEnvironment()
        
        cancellables?.removeAll()
        cancellables = nil
        testLogManager = nil
        mockConfigManager = nil
        mockErrorHandler = nil
        
        try await super.tearDown()
    }
    
    // MARK: - 环境配置
    
    /// 设置测试环境
    @MainActor
    private func setupTestEnvironment() async {
        // 设置测试日志级别
        LogManager.shared.currentLogLevel = .debug
        
        // 配置测试模式
        UserDefaults.standard.set(true, forKey: "HelloPrompt.TestMode")
        
        // 清理之前的测试数据
        clearTestData()
    }
    
    /// 清理测试环境
    @MainActor
    private func cleanupTestEnvironment() async {
        // 重置用户偏好
        UserDefaults.standard.removeObject(forKey: "HelloPrompt.TestMode")
        
        // 清理测试数据
        clearTestData()
    }
    
    /// 清理测试数据
    private func clearTestData() {
        let testKeys = [
            "test_api_key",
            "test_config_data",
            "test_audio_settings",
            "test_hotkey_config"
        ]
        
        for key in testKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
    
    // MARK: - 测试工具方法
    
    /// 等待异步操作完成
    func waitForAsync(_ operation: @escaping () async throws -> Void, timeout: TimeInterval = 5.0) async throws {
        let expectation = XCTestExpectation(description: "Async operation")
        
        Task {
            do {
                try await operation()
                expectation.fulfill()
            } catch {
                XCTFail("Async operation failed: \(error)")
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: timeout)
    }
    
    /// 验证Publisher结果
    func verifyPublisher<T: Publisher>(
        _ publisher: T,
        expectedValue: T.Output,
        timeout: TimeInterval = 2.0,
        file: StaticString = #file,
        line: UInt = #line
    ) where T.Output: Equatable, T.Failure == Never {
        let expectation = XCTestExpectation(description: "Publisher expectation")
        
        publisher
            .sink { value in
                XCTAssertEqual(value, expectedValue, file: file, line: line)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: timeout)
    }
    
    /// 创建测试音频数据
    func createTestAudioData(duration: TimeInterval = 1.0, sampleRate: Double = 16000) -> Data {
        let frameCount = Int(duration * sampleRate)
        var audioData = Data()
        
        // 生成简单的正弦波测试音频
        for i in 0..<frameCount {
            let amplitude: Float = 0.5
            let frequency: Float = 440.0 // A4音符
            let sample = amplitude * sin(2.0 * .pi * frequency * Float(i) / Float(sampleRate))
            
            // 转换为16位PCM数据
            let intSample = Int16(sample * Float(Int16.max))
            withUnsafeBytes(of: intSample.littleEndian) { bytes in
                audioData.append(contentsOf: bytes)
            }
        }
        
        return audioData
    }
    
    /// 创建测试配置
    func createTestConfiguration() -> [String: Any] {
        return [
            "apiKey": "test_api_key_12345",
            "baseURL": "https://api.test.example.com/v1",
            "silenceThreshold": 0.02,
            "silenceTimeout": 0.8,
            "maxRecordingTime": 120.0,
            "enableVAD": true,
            "enableAudioEnhancement": true,
            "logLevel": "debug"
        ]
    }
}

// MARK: - Mock对象

/// 测试用日志管理器
class TestLogManager: LogManagerProtocol {
    var loggedMessages: [(level: LogLevel, category: String, message: String)] = []
    var currentLogLevel: LogLevel = .debug
    
    func log(_ level: LogLevel, category: String, message: String, 
             file: String = #file, function: String = #function, line: Int = #line) {
        loggedMessages.append((level: level, category: category, message: message))
    }
    
    func clearLogs() {
        loggedMessages.removeAll()
    }
    
    // 实现其他必需的方法
    func debug(_ category: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, category: category, message: message, file: file, function: function, line: line)
    }
    
    func info(_ category: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, category: category, message: message, file: file, function: function, line: line)
    }
    
    func warning(_ category: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, category: category, message: message, file: file, function: function, line: line)
    }
    
    func error(_ category: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, category: category, message: message, file: file, function: function, line: line)
    }
}

/// 模拟配置管理器
class MockConfigManager: ObservableObject {
    @Published var apiKey: String = ""
    @Published var baseURL: String = "https://api.openai.com/v1"
    @Published var silenceThreshold: Float = 0.01
    @Published var silenceTimeout: TimeInterval = 0.5
    @Published var maxRecordingTime: TimeInterval = 300.0
    @Published var enableVAD: Bool = true
    @Published var enableAudioEnhancement: Bool = true
    
    private var storage: [String: Any] = [:]
    var shouldFailOperations: Bool = false
    
    func getValue<T>(for key: String, defaultValue: T) -> T {
        if shouldFailOperations {
            return defaultValue
        }
        return storage[key] as? T ?? defaultValue
    }
    
    func setValue<T>(_ value: T, for key: String) throws {
        if shouldFailOperations {
            throw ConfigurationError.defaultsWriteFailed
        }
        storage[key] = value
    }
    
    func getAPIKey() throws -> String {
        if shouldFailOperations {
            throw ConfigurationError.keychainAccessFailed
        }
        return apiKey
    }
    
    func setAPIKey(_ key: String) throws {
        if shouldFailOperations {
            throw ConfigurationError.keychainAccessFailed
        }
        apiKey = key
    }
    
    func resetToDefaults() {
        storage.removeAll()
        apiKey = ""
        baseURL = "https://api.openai.com/v1"
        silenceThreshold = 0.01
        silenceTimeout = 0.5
        maxRecordingTime = 300.0
        enableVAD = true
        enableAudioEnhancement = true
    }
}

/// 模拟错误处理器
class MockErrorHandler: ObservableObject {
    @Published var lastError: Error?
    @Published var errorCount: Int = 0
    
    var handledErrors: [Error] = []
    var shouldLogErrors: Bool = true
    
    func handle(_ error: Error, context: String = "") {
        handledErrors.append(error)
        lastError = error
        errorCount += 1
        
        if shouldLogErrors {
            print("Mock error handled: \(error) in context: \(context)")
        }
    }
    
    func clearErrors() {
        handledErrors.removeAll()
        lastError = nil
        errorCount = 0
    }
    
    func exportErrorReport() -> String {
        return handledErrors.map { "\($0)" }.joined(separator: "\n")
    }
}

// MARK: - 测试断言扩展

extension XCTestCase {
    
    /// 断言抛出特定错误类型
    func XCTAssertThrowsError<T: Error & Equatable>(
        _ expression: @autoclosure () async throws -> Any,
        expectedError: T,
        _ message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected error \(expectedError) but no error was thrown", file: file, line: line)
        } catch let error as T {
            XCTAssertEqual(error, expectedError, message, file: file, line: line)
        } catch {
            XCTFail("Expected error \(expectedError) but got \(error)", file: file, line: line)
        }
    }
    
    /// 断言值在指定范围内
    func XCTAssertInRange<T: Comparable>(
        _ value: T,
        _ range: ClosedRange<T>,
        _ message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(range.contains(value), 
                     "\(message.isEmpty ? "" : message + " - ")Value \(value) is not in range \(range)", 
                     file: file, line: line)
    }
    
    /// 断言两个浮点数近似相等
    func XCTAssertApproximatelyEqual(
        _ lhs: Double,
        _ rhs: Double,
        accuracy: Double = 0.001,
        _ message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let difference = abs(lhs - rhs)
        XCTAssertTrue(difference <= accuracy,
                     "\(message.isEmpty ? "" : message + " - ")\(lhs) is not approximately equal to \(rhs) (difference: \(difference), accuracy: \(accuracy))",
                     file: file, line: line)
    }
    
    /// 断言集合包含所有指定元素
    func XCTAssertContainsAll<T: Equatable>(
        _ collection: [T],
        _ elements: [T],
        _ message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        for element in elements {
            XCTAssertTrue(collection.contains(element),
                         "\(message.isEmpty ? "" : message + " - ")Collection does not contain \(element)",
                         file: file, line: line)
        }
    }
}

// MARK: - 性能测试工具

extension HelloPromptTestCase {
    
    /// 测量异步操作性能
    func measureAsync(
        _ operation: @escaping () async throws -> Void,
        iterations: Int = 10,
        name: String = "Async Operation"
    ) async throws {
        var times: [TimeInterval] = []
        
        for _ in 0..<iterations {
            let startTime = CFAbsoluteTimeGetCurrent()
            try await operation()
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            times.append(timeElapsed)
        }
        
        let averageTime = times.reduce(0, +) / Double(times.count)
        let minTime = times.min() ?? 0
        let maxTime = times.max() ?? 0
        
        print("""
        Performance Metrics for \(name):
        - Iterations: \(iterations)
        - Average Time: \(String(format: "%.4f", averageTime))s
        - Min Time: \(String(format: "%.4f", minTime))s
        - Max Time: \(String(format: "%.4f", maxTime))s
        - All Times: \(times.map { String(format: "%.4f", $0) }.joined(separator: ", "))s
        """)
        
        // 断言平均时间在合理范围内（可根据需要调整）
        XCTAssertLessThan(averageTime, 5.0, "Average execution time should be less than 5 seconds")
    }
    
    /// 内存使用测试
    func measureMemoryUsage(
        _ operation: () throws -> Void,
        name: String = "Memory Usage Test"
    ) throws {
        let beforeMemory = getMemoryUsage()
        try operation()
        let afterMemory = getMemoryUsage()
        
        let memoryDifference = afterMemory - beforeMemory
        
        print("""
        Memory Usage for \(name):
        - Before: \(formatMemorySize(beforeMemory))
        - After: \(formatMemorySize(afterMemory))
        - Difference: \(formatMemorySize(memoryDifference))
        """)
        
        // 断言内存增长在合理范围内（100MB）
        XCTAssertLessThan(memoryDifference, 100 * 1024 * 1024, 
                         "Memory usage should not increase by more than 100MB")
    }
    
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
    
    private func formatMemorySize(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - 测试数据生成器

struct TestDataGenerator {
    
    /// 生成随机字符串
    static func randomString(length: Int = 10) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
    
    /// 生成测试提示词
    static func samplePrompts() -> [String] {
        return [
            "写一个Python函数来计算斐波那契数列",
            "解释机器学习中的梯度下降算法",
            "如何在Swift中实现单例模式",
            "创建一个响应式的网页布局",
            "优化数据库查询性能的方法"
        ]
    }
    
    /// 生成测试音频配置
    static func sampleAudioConfigs() -> [AudioConfiguration] {
        return [
            AudioConfiguration(
                sampleRate: 16000,
                channels: 1,
                bitDepth: 16,
                silenceThreshold: 0.01,
                silenceTimeout: 0.5
            ),
            AudioConfiguration(
                sampleRate: 44100,
                channels: 2,
                bitDepth: 24,
                silenceThreshold: 0.005,
                silenceTimeout: 1.0
            ),
            AudioConfiguration(
                sampleRate: 48000,
                channels: 1,
                bitDepth: 32,
                silenceThreshold: 0.02,
                silenceTimeout: 0.3
            )
        ]
    }
}

// MARK: - 主测试套件
class HelloPromptMainTests: HelloPromptTestCase {
    
    func testApplicationInitialization() async throws {
        // 测试应用程序基本初始化
        let expectation = XCTestExpectation(description: "App initialization")
        
        Task {
            // 模拟应用初始化过程
            let configManager = MockConfigManager()
            let errorHandler = MockErrorHandler()
            
            XCTAssertNotNil(configManager)
            XCTAssertNotNil(errorHandler)
            XCTAssertEqual(errorHandler.errorCount, 0)
            
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    func testConfigurationManagement() throws {
        // 测试配置管理功能
        let config = MockConfigManager()
        
        // 测试设置和获取值
        try config.setValue("test_value", for: "test_key")
        let retrievedValue: String = config.getValue(for: "test_key", defaultValue: "default")
        XCTAssertEqual(retrievedValue, "test_value")
        
        // 测试默认值
        let defaultValue: String = config.getValue(for: "nonexistent_key", defaultValue: "default")
        XCTAssertEqual(defaultValue, "default")
        
        // 测试API密钥管理
        try config.setAPIKey("test_api_key")
        let apiKey = try config.getAPIKey()
        XCTAssertEqual(apiKey, "test_api_key")
    }
    
    func testErrorHandling() {
        // 测试错误处理机制
        let errorHandler = MockErrorHandler()
        
        let testError = NSError(domain: "TestDomain", code: 100, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        errorHandler.handle(testError, context: "Unit test")
        
        XCTAssertEqual(errorHandler.errorCount, 1)
        XCTAssertEqual(errorHandler.handledErrors.count, 1)
        XCTAssertNotNil(errorHandler.lastError)
    }
    
    func testPerformanceBaseline() async throws {
        // 建立性能基准测试
        await measureAsync({
            // 模拟轻量级操作
            _ = TestDataGenerator.randomString(length: 1000)
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }, iterations: 5, name: "Baseline Performance")
    }
}

// MARK: - 模块特定测试标记

protocol AudioServiceTestable {
    func testAudioInitialization() async throws
    func testAudioRecording() async throws
    func testVoiceActivityDetection() async throws
}

protocol OpenAIServiceTestable {
    func testAPIConnection() async throws
    func testSpeechRecognition() async throws
    func testPromptOptimization() async throws
}

protocol HotkeyServiceTestable {
    func testHotkeyRegistration() throws
    func testHotkeyConflictDetection() async throws
    func testHotkeyExecution() throws
}