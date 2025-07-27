//
//  ErrorHandlerTests.swift
//  Hello-Prompt
//
//  Created by Bai Cai on 26/7/2025.
//

import Testing
import Foundation
@testable import HelloPrompt

// MARK: - Error Protocol Tests

@Test("HelloPromptError protocol implementation")
func testHelloPromptErrorProtocol() {
    let error = AudioSystemError.deviceNotFound
    
    // 测试基本属性
    #expect(error.errorCode == "AUDIO_001")
    #expect(error.severity == .error)
    #expect(!error.userMessage.isEmpty)
    #expect(!error.technicalDescription.isEmpty)
    
    // 测试默认实现
    #expect(error.errorDescription == error.userMessage)
    #expect(error.failureReason == error.technicalDescription)
    #expect(error.description.contains(error.errorCode))
    #expect(error.shouldLog == true) // error级别应该记录日志
    #expect(error.shouldReport == true) // error级别应该上报
}

// MARK: - Error Severity Tests

@Test("Error severity comparison")
func testErrorSeverityComparison() {
    #expect(ErrorSeverity.info < .warning)
    #expect(ErrorSeverity.warning < .error)
    #expect(ErrorSeverity.error < .critical)
    
    // 测试排序
    let severities: [ErrorSeverity] = [.critical, .info, .error, .warning]
    let sorted = severities.sorted()
    #expect(sorted == [.info, .warning, .error, .critical])
}

@Test("Error severity properties")
func testErrorSeverityProperties() {
    #expect(ErrorSeverity.info.description == "信息")
    #expect(ErrorSeverity.warning.icon == "exclamationmark.triangle")
    #expect(ErrorSeverity.error.color.description.contains("red"))
    #expect(ErrorSeverity.critical.color.description.contains("purple"))
}

// MARK: - Audio System Error Tests

@Test("AudioSystemError properties")
func testAudioSystemErrorProperties() {
    let deviceError = AudioSystemError.deviceNotFound
    #expect(deviceError.errorCode == "AUDIO_001")
    #expect(deviceError.severity == .error)
    #expect(deviceError.userMessage.contains("音频设备"))
    
    let permissionError = AudioSystemError.permissionDenied
    #expect(permissionError.errorCode == "AUDIO_002")
    #expect(permissionError.severity == .error)
    #expect(permissionError.userMessage.contains("权限"))
    
    let configError = AudioSystemError.configurationFailed(reason: "test reason")
    #expect(configError.errorCode == "AUDIO_003")
    #expect(configError.severity == .warning)
    #expect(configError.technicalDescription.contains("test reason"))
}

@Test("AudioSystemError recovery strategies")
func testAudioSystemErrorRecoveryStrategies() {
    let deviceError = AudioSystemError.deviceNotFound
    if case .userIntervention(let message) = deviceError.recoveryStrategy {
        #expect(message.contains("设备"))
    } else {
        #expect(Bool(false), "Expected userIntervention strategy")
    }
    
    let playbackError = AudioSystemError.playbackFailed(underlying: nil)
    if case .retry(let maxAttempts, let delay) = playbackError.recoveryStrategy {
        #expect(maxAttempts == 3)
        #expect(delay == 1.0)
    } else {
        #expect(Bool(false), "Expected retry strategy")
    }
}

// MARK: - API Error Tests

@Test("APIError properties")
func testAPIErrorProperties() {
    let networkError = APIError.networkUnavailable
    #expect(networkError.errorCode == "API_001")
    #expect(networkError.severity == .error)
    #expect(networkError.userMessage.contains("网络"))
    
    let timeoutError = APIError.timeout
    #expect(timeoutError.errorCode == "API_002")
    #expect(timeoutError.severity == .warning)
    
    let rateLimitError = APIError.rateLimited(retryAfter: 30)
    #expect(rateLimitError.errorCode == "API_004")
    #expect(rateLimitError.technicalDescription.contains("30"))
    
    let serverError = APIError.serverError(code: 500, message: "Internal Server Error")
    #expect(serverError.errorCode == "API_005")
    #expect(serverError.technicalDescription.contains("500"))
    #expect(serverError.technicalDescription.contains("Internal Server Error"))
}

@Test("APIError recovery strategies")
func testAPIErrorRecoveryStrategies() {
    let timeoutError = APIError.timeout
    if case .retry(let maxAttempts, let delay) = timeoutError.recoveryStrategy {
        #expect(maxAttempts == 3)
        #expect(delay == 2.0)
    } else {
        #expect(Bool(false), "Expected retry strategy")
    }
    
    let rateLimitError = APIError.rateLimited(retryAfter: 45)
    if case .retry(let maxAttempts, let delay) = rateLimitError.recoveryStrategy {
        #expect(maxAttempts == 1)
        #expect(delay == 45)
    } else {
        #expect(Bool(false), "Expected retry strategy with custom delay")
    }
}

// MARK: - UI Error Tests

@Test("UIError properties")
func testUIErrorProperties() {
    let viewError = UIError.viewLoadFailed(viewName: "TestView")
    #expect(viewError.errorCode == "UI_001")
    #expect(viewError.severity == .error)
    #expect(viewError.technicalDescription.contains("TestView"))
    
    let animationError = UIError.animationFailed
    #expect(animationError.errorCode == "UI_002")
    #expect(animationError.severity == .info)
    #expect(animationError.shouldLog == false) // info级别不应该记录日志
    #expect(animationError.shouldReport == false) // info级别不应该上报
    
    let resourceError = UIError.resourceNotFound(resourceName: "test.png")
    #expect(resourceError.errorCode == "UI_004")
    #expect(resourceError.technicalDescription.contains("test.png"))
}

// MARK: - Config Error Tests

@Test("ConfigError properties")
func testConfigErrorProperties() {
    let fileError = ConfigError.fileNotFound(path: "/test/config.json")
    #expect(fileError.errorCode == "CONFIG_001")
    #expect(fileError.severity == .warning)
    #expect(fileError.technicalDescription.contains("/test/config.json"))
    
    let keyError = ConfigError.missingRequiredKey(key: "apiKey")
    #expect(keyError.errorCode == "CONFIG_003")
    #expect(keyError.severity == .error)
    #expect(keyError.technicalDescription.contains("apiKey"))
    
    let rangeError = ConfigError.valueOutOfRange(key: "timeout", value: -1, range: "0-300")
    #expect(rangeError.errorCode == "CONFIG_004")
    #expect(rangeError.technicalDescription.contains("timeout"))
    #expect(rangeError.technicalDescription.contains("-1"))
    #expect(rangeError.technicalDescription.contains("0-300"))
}

// MARK: - Generic Error Tests

@Test("GenericError wrapper")
func testGenericErrorWrapper() {
    let originalError = NSError(domain: "TestDomain", code: 123, userInfo: [
        NSLocalizedDescriptionKey: "Test error message"
    ])
    
    let wrappedError = GenericError.wrapped(originalError, context: "test context")
    #expect(wrappedError.errorCode == "GENERIC_001")
    #expect(wrappedError.severity == .error)
    #expect(wrappedError.userMessage == "Test error message")
    #expect(wrappedError.technicalDescription.contains("test context"))
    #expect(wrappedError.context["context"] as? String == "test context")
    
    let unknownError = GenericError.unknown(message: "Unknown issue")
    #expect(unknownError.errorCode == "GENERIC_002")
    #expect(unknownError.userMessage == "Unknown issue")
}

// MARK: - Recovery Strategy Tests

@Test("Recovery strategy types")
func testRecoveryStrategyTypes() {
    // 测试不同的恢复策略类型
    let retryStrategy = RecoveryStrategy.retry(maxAttempts: 3, delay: 1.0)
    if case .retry(let attempts, let delay) = retryStrategy {
        #expect(attempts == 3)
        #expect(delay == 1.0)
    } else {
        #expect(Bool(false), "Expected retry strategy")
    }
    
    let userStrategy = RecoveryStrategy.userIntervention(message: "Please fix this")
    if case .userIntervention(let message) = userStrategy {
        #expect(message == "Please fix this")
    } else {
        #expect(Bool(false), "Expected userIntervention strategy")
    }
}

// MARK: - Error Handler Tests

@Test("ErrorHandler singleton")
func testErrorHandlerSingleton() {
    let handler1 = ErrorHandler.shared
    let handler2 = ErrorHandler.shared
    
    // 验证单例模式
    #expect(handler1 === handler2)
}

@Test("ErrorHandler error processing")
@MainActor
func testErrorHandlerProcessing() async {
    let errorHandler = ErrorHandler.shared
    let testError = AudioSystemError.deviceNotFound
    
    // 初始状态
    #expect(errorHandler.currentError == nil)
    #expect(errorHandler.isShowingError == false)
    
    // 处理错误
    errorHandler.handle(testError)
    
    // 等待处理完成
    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
    
    // 由于这是error级别的错误，应该显示给用户
    #expect(errorHandler.isShowingError == true)
    #expect(errorHandler.currentError != nil)
    
    // 清除错误
    errorHandler.dismissError()
    #expect(errorHandler.currentError == nil)
    #expect(errorHandler.isShowingError == false)
}

@Test("ErrorHandler with different severity levels")
@MainActor
func testErrorHandlerSeverityLevels() async {
    let errorHandler = ErrorHandler.shared
    
    // 测试info级别错误（不应该显示给用户）
    let infoError = UIError.animationFailed
    errorHandler.handle(infoError)
    
    try? await Task.sleep(nanoseconds: 50_000_000) // 0.05秒
    
    // info级别的错误不应该显示给用户
    #expect(errorHandler.isShowingError == false)
    
    // 清理状态
    errorHandler.dismissError()
    
    // 测试warning级别错误（应该显示给用户）
    let warningError = APIError.timeout
    errorHandler.handle(warningError)
    
    try? await Task.sleep(nanoseconds: 50_000_000) // 0.05秒
    
    // warning级别的错误应该显示给用户
    #expect(errorHandler.isShowingError == true)
    
    // 清理
    errorHandler.dismissError()
}

// MARK: - Integration Tests

@Test("Error handling integration")
@MainActor
func testErrorHandlingIntegration() async {
    let errorHandler = ErrorHandler.shared
    
    // 模拟真实的错误处理场景
    let errors: [HelloPromptError] = [
        AudioSystemError.deviceNotFound,
        APIError.networkUnavailable,
        UIError.viewLoadFailed(viewName: "TestView"),
        ConfigError.missingRequiredKey(key: "testKey")
    ]
    
    for (index, error) in errors.enumerated() {
        errorHandler.dismissError() // 清理之前的状态
        
        errorHandler.handle(error)
        
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05秒
        
        // 所有这些错误都应该显示给用户（都是warning级别或以上）
        #expect(errorHandler.isShowingError == true, "Error \(index) should be shown to user")
        #expect(errorHandler.currentError?.errorCode == error.errorCode, "Error code should match")
    }
}

// MARK: - Performance Tests

@Test("Error handling performance")
func testErrorHandlingPerformance() {
    let startTime = CFAbsoluteTimeGetCurrent()
    
    // 创建大量错误对象
    var errors: [HelloPromptError] = []
    for i in 0..<1000 {
        let error = UIError.resourceNotFound(resourceName: "resource_\(i)")
        errors.append(error)
    }
    
    let creationTime = CFAbsoluteTimeGetCurrent()
    
    // 处理错误（不等待异步处理完成）
    let errorHandler = ErrorHandler.shared
    for error in errors {
        errorHandler.handle(error)
    }
    
    let processingTime = CFAbsoluteTimeGetCurrent()
    
    // 验证性能
    let creationDuration = creationTime - startTime
    let processingDuration = processingTime - creationTime
    
    #expect(creationDuration < 0.1, "Error creation should be fast")
    #expect(processingDuration < 0.5, "Error processing should be reasonably fast")
    
    print("Creation time: \(creationDuration)s, Processing time: \(processingDuration)s")
}

// MARK: - Edge Cases Tests

@Test("Error handler edge cases")
@MainActor
func testErrorHandlerEdgeCases() async {
    let errorHandler = ErrorHandler.shared
    
    // 测试处理nil错误的场景（通过GenericError包装）
    let nilError: Error? = nil
    if nilError == nil {
        let unknownError = GenericError.unknown(message: "Nil error encountered")
        errorHandler.handle(unknownError)
    }
    
    // 测试快速连续的错误处理
    let error1 = AudioSystemError.deviceNotFound
    let error2 = APIError.networkUnavailable
    
    errorHandler.handle(error1)
    errorHandler.handle(error2)
    
    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
    
    // 最后的错误应该覆盖之前的错误
    #expect(errorHandler.currentError?.errorCode == error2.errorCode)
}

@Test("Error context information")
func testErrorContextInformation() {
    let error = AudioSystemError.configurationFailed(reason: "test reason")
    
    // 基本错误不应该有额外的context
    #expect(error.context.isEmpty)
    
    let wrappedError = GenericError.wrapped(
        NSError(domain: "Test", code: 1, userInfo: nil),
        context: "test context"
    )
    
    // 包装的错误应该有context信息
    #expect(!wrappedError.context.isEmpty)
    #expect(wrappedError.context["context"] as? String == "test context")
}

// MARK: - Helper Functions for Testing

private func createTestError(severity: ErrorSeverity) -> HelloPromptError {
    switch severity {
    case .info:
        return UIError.animationFailed
    case .warning:
        return APIError.timeout
    case .error:
        return AudioSystemError.deviceNotFound
    case .critical:
        return APIError.serverError(code: 500, message: "Critical server error")
    }
}