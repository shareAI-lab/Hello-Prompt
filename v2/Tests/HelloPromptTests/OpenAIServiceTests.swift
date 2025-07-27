//
//  OpenAIServiceTests.swift
//  HelloPrompt
//
//  OpenAI服务测试套件 - 测试API连接、语音识别、提示词优化等功能
//  包含网络错误处理、重试机制、响应解析测试
//

import XCTest
import Combine
@testable import HelloPrompt

class OpenAIServiceTests: HelloPromptTestCase, OpenAIServiceTestable {
    
    // MARK: - 测试属性
    var openAIService: OpenAIService!
    var mockNetworkSession: MockURLSession!
    var testAudioData: Data!
    
    override func setUp() async throws {
        try await super.setUp()
        
        openAIService = OpenAIService()
        mockNetworkSession = MockURLSession()
        testAudioData = createTestAudioData(duration: 2.0)
        
        // 配置测试环境
        setupOpenAITestEnvironment()
    }
    
    override func tearDown() async throws {
        openAIService = nil
        mockNetworkSession = nil
        testAudioData = nil
        
        try await super.tearDown()
    }
    
    // MARK: - 环境设置
    
    private func setupOpenAITestEnvironment() {
        // 配置测试API密钥和基础URL
        openAIService.configure(
            apiKey: "test_api_key_12345",
            baseURL: "https://api.test.openai.com/v1"
        )
        
        // 注入mock网络会话
        openAIService.urlSession = mockNetworkSession
    }
    
    // MARK: - API连接测试
    
    func testAPIConnection() async throws {
        // 测试基本API连接
        mockNetworkSession.mockResponse = createMockHealthResponse()
        
        let result = await openAIService.testConnection()
        
        switch result {
        case .success(let isConnected):
            XCTAssertTrue(isConnected, "API connection should be successful")
        case .failure(let error):
            XCTFail("API connection should succeed, got error: \(error)")
        }
    }
    
    func testAPIConnectionFailure() async throws {
        // 测试API连接失败
        mockNetworkSession.shouldFail = true
        mockNetworkSession.error = URLError(.notConnectedToInternet)
        
        let result = await openAIService.testConnection()
        
        switch result {
        case .success:
            XCTFail("API connection should fail")
        case .failure(let error):
            XCTAssertTrue(error is URLError, "Should return network error")
        }
    }
    
    func testAPIAuthentication() async throws {
        // 测试API认证
        mockNetworkSession.mockResponse = createMockAuthErrorResponse()
        
        let result = await openAIService.testConnection()
        
        switch result {
        case .success:
            XCTFail("Should fail with authentication error")
        case .failure(let error):
            if let apiError = error as? APIError {
                switch apiError {
                case .authenticationFailed:
                    break // 期望的错误
                default:
                    XCTFail("Expected authentication error, got: \(apiError)")
                }
            } else {
                XCTFail("Expected APIError, got: \(error)")
            }
        }
    }
    
    // MARK: - 语音识别测试
    
    func testSpeechRecognition() async throws {
        // 测试语音识别功能
        let expectedTranscription = "Hello, this is a test transcription from audio data."
        mockNetworkSession.mockResponse = createMockTranscriptionResponse(text: expectedTranscription)
        
        do {
            let transcription = try await openAIService.transcribeAudio(testAudioData)
            
            XCTAssertEqual(transcription, expectedTranscription, "Transcription should match expected result")
            XCTAssertFalse(transcription.isEmpty, "Transcription should not be empty")
        } catch {
            XCTFail("Speech recognition should succeed, got error: \(error)")
        }
    }
    
    func testSpeechRecognitionWithEmptyAudio() async throws {
        // 测试空音频数据的语音识别
        let emptyAudioData = Data()
        
        do {
            _ = try await openAIService.transcribeAudio(emptyAudioData)
            XCTFail("Should fail with empty audio data")
        } catch let error as APIError {
            switch error {
            case .invalidRequest:
                break // 期望的错误
            default:
                XCTFail("Expected invalid request error, got: \(error)")
            }
        }
    }
    
    func testSpeechRecognitionWithLargeAudio() async throws {
        // 测试大文件音频识别
        let largeAudioData = createTestAudioData(duration: 600.0) // 10分钟
        mockNetworkSession.mockResponse = createMockTranscriptionResponse(text: "Long transcription result")
        
        do {
            let transcription = try await openAIService.transcribeAudio(largeAudioData)
            XCTAssertFalse(transcription.isEmpty, "Should handle large audio files")
        } catch let error as APIError {
            switch error {
            case .fileTooLarge:
                // 这也是可接受的结果
                break
            default:
                XCTFail("Unexpected error for large audio: \(error)")
            }
        }
    }
    
    func testSpeechRecognitionLanguageDetection() async throws {
        // 测试语言检测
        let chineseText = "你好，这是一个中文语音识别测试。"
        mockNetworkSession.mockResponse = createMockTranscriptionResponse(
            text: chineseText,
            language: "zh"
        )
        
        let transcription = try await openAIService.transcribeAudio(testAudioData, language: "zh")
        
        XCTAssertEqual(transcription, chineseText, "Should handle Chinese transcription")
    }
    
    // MARK: - 提示词优化测试
    
    func testPromptOptimization() async throws {
        // 测试提示词优化
        let originalPrompt = "写一个函数"
        let optimizedPrompt = """
        请编写一个函数，要求如下：
        1. 明确函数的功能和用途
        2. 指定编程语言
        3. 包含输入参数说明
        4. 包含返回值说明
        5. 提供使用示例
        """
        
        mockNetworkSession.mockResponse = createMockChatCompletionResponse(content: optimizedPrompt)
        
        do {
            let result = try await openAIService.optimizePrompt(originalPrompt, context: "代码编程")
            
            XCTAssertNotEqual(result, originalPrompt, "Optimized prompt should be different from original")
            XCTAssertGreaterThan(result.count, originalPrompt.count, "Optimized prompt should be more detailed")
            XCTAssertTrue(result.contains("函数"), "Optimized prompt should contain key terms")
        } catch {
            XCTFail("Prompt optimization should succeed, got error: \(error)")
        }
    }
    
    func testPromptOptimizationWithContext() async throws {
        // 测试带上下文的提示词优化
        let originalPrompt = "帮我优化这个查询"
        let context = "数据库查询优化，PostgreSQL环境"
        
        let optimizedPrompt = """
        请帮我优化以下PostgreSQL数据库查询：
        1. 分析查询性能瓶颈
        2. 建议索引优化策略
        3. 提供重写后的SQL语句
        4. 解释优化原理
        """
        
        mockNetworkSession.mockResponse = createMockChatCompletionResponse(content: optimizedPrompt)
        
        let result = try await openAIService.optimizePrompt(originalPrompt, context: context)
        
        XCTAssertTrue(result.contains("PostgreSQL"), "Should incorporate context information")
        XCTAssertTrue(result.contains("索引"), "Should include relevant technical terms")
    }
    
    func testPromptOptimizationWithLongInput() async throws {
        // 测试长提示词优化
        let longPrompt = String(repeating: "这是一个很长的提示词。", count: 100)
        
        // 模拟token限制错误
        mockNetworkSession.mockResponse = createMockTokenLimitErrorResponse()
        
        do {
            _ = try await openAIService.optimizePrompt(longPrompt)
            XCTFail("Should fail with token limit error")
        } catch let error as APIError {
            switch error {
            case .tokenLimitExceeded:
                break // 期望的错误
            default:
                XCTFail("Expected token limit error, got: \(error)")
            }
        }
    }
    
    // MARK: - 错误处理测试
    
    func testNetworkTimeoutHandling() async throws {
        // 测试网络超时处理
        mockNetworkSession.shouldTimeout = true
        
        do {
            _ = try await openAIService.transcribeAudio(testAudioData)
            XCTFail("Should timeout")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .timedOut, "Should be timeout error")
        }
    }
    
    func testRateLimitHandling() async throws {
        // 测试请求频率限制处理
        mockNetworkSession.mockResponse = createMockRateLimitErrorResponse()
        
        do {
            _ = try await openAIService.transcribeAudio(testAudioData)
            XCTFail("Should fail with rate limit error")
        } catch let error as APIError {
            switch error {
            case .rateLimitExceeded:
                break // 期望的错误
            default:
                XCTFail("Expected rate limit error, got: \(error)")
            }
        }
    }
    
    func testServerErrorHandling() async throws {
        // 测试服务器错误处理
        mockNetworkSession.mockResponse = createMockServerErrorResponse()
        
        do {
            _ = try await openAIService.transcribeAudio(testAudioData)
            XCTFail("Should fail with server error")
        } catch let error as APIError {
            switch error {
            case .serverError:
                break // 期望的错误
            default:
                XCTFail("Expected server error, got: \(error)")
            }
        }
    }
    
    // MARK: - 重试机制测试
    
    func testRetryMechanism() async throws {
        // 测试重试机制
        var requestCount = 0
        mockNetworkSession.requestHandler = { request in
            requestCount += 1
            if requestCount < 3 {
                // 前两次请求失败
                throw URLError(.networkConnectionLost)
            } else {
                // 第三次请求成功
                return self.createMockTranscriptionResponse(text: "Success after retry")
            }
        }
        
        do {
            let transcription = try await openAIService.transcribeAudio(testAudioData)
            
            XCTAssertEqual(requestCount, 3, "Should retry exactly 2 times before success")
            XCTAssertEqual(transcription, "Success after retry", "Should return successful result")
        } catch {
            XCTFail("Should succeed after retries, got error: \(error)")
        }
    }
    
    func testRetryExhaustion() async throws {
        // 测试重试次数耗尽
        var requestCount = 0
        mockNetworkSession.requestHandler = { request in
            requestCount += 1
            throw URLError(.networkConnectionLost)
        }
        
        do {
            _ = try await openAIService.transcribeAudio(testAudioData)
            XCTFail("Should fail after exhausting retries")
        } catch {
            XCTAssertEqual(requestCount, 4, "Should attempt 1 initial + 3 retries")
        }
    }
    
    // MARK: - 性能测试
    
    func testTranscriptionPerformance() async throws {
        // 测试转录性能
        mockNetworkSession.mockResponse = createMockTranscriptionResponse(text: "Performance test transcription")
        
        await measureAsync({
            _ = try await self.openAIService.transcribeAudio(self.testAudioData)
        }, iterations: 5, name: "Transcription Performance")
    }
    
    func testPromptOptimizationPerformance() async throws {
        // 测试提示词优化性能
        mockNetworkSession.mockResponse = createMockChatCompletionResponse(content: "Optimized prompt for performance testing")
        
        await measureAsync({
            _ = try await self.openAIService.optimizePrompt("Test prompt for performance", context: "Performance testing")
        }, iterations: 3, name: "Prompt Optimization Performance")
    }
    
    func testConcurrentRequests() async throws {
        // 测试并发请求处理
        mockNetworkSession.mockResponse = createMockTranscriptionResponse(text: "Concurrent request result")
        
        let numberOfConcurrentRequests = 5
        let expectations = (0..<numberOfConcurrentRequests).map { 
            XCTestExpectation(description: "Concurrent request \($0)")
        }
        
        for (index, expectation) in expectations.enumerated() {
            Task {
                do {
                    let result = try await self.openAIService.transcribeAudio(self.testAudioData)
                    XCTAssertFalse(result.isEmpty, "Concurrent request \(index) should succeed")
                    expectation.fulfill()
                } catch {
                    XCTFail("Concurrent request \(index) failed: \(error)")
                    expectation.fulfill()
                }
            }
        }
        
        await fulfillment(of: expectations, timeout: 10.0)
    }
    
    // MARK: - 配置测试
    
    func testConfigurationUpdate() {
        // 测试配置更新
        let newAPIKey = "new_test_api_key_67890"
        let newBaseURL = "https://api.custom.openai.com/v1"
        
        openAIService.configure(apiKey: newAPIKey, baseURL: newBaseURL)
        
        XCTAssertEqual(openAIService.apiKey, newAPIKey, "API key should be updated")
        XCTAssertEqual(openAIService.baseURL, newBaseURL, "Base URL should be updated")
    }
    
    func testInvalidConfiguration() {
        // 测试无效配置
        let invalidConfigurations = [
            ("", "https://api.openai.com/v1"), // 空API密钥
            ("valid_key", ""), // 空URL
            ("valid_key", "invalid_url"), // 无效URL格式
        ]
        
        for (apiKey, baseURL) in invalidConfigurations {
            openAIService.configure(apiKey: apiKey, baseURL: baseURL)
            
            // 验证配置验证逻辑
            XCTAssertFalse(openAIService.isConfigurationValid, 
                          "Configuration should be invalid for key: '\(apiKey)', url: '\(baseURL)'")
        }
    }
    
    // MARK: - Mock响应创建方法
    
    private func createMockHealthResponse() -> MockURLSessionDataTask.MockResponse {
        let responseData = """
        {
            "status": "ok",
            "version": "1.0"
        }
        """.data(using: .utf8)!
        
        let httpResponse = HTTPURLResponse(
            url: URL(string: "https://api.test.openai.com/v1/health")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        return MockURLSessionDataTask.MockResponse(data: responseData, response: httpResponse, error: nil)
    }
    
    private func createMockAuthErrorResponse() -> MockURLSessionDataTask.MockResponse {
        let responseData = """
        {
            "error": {
                "message": "Invalid authentication credentials",
                "type": "authentication_error",
                "code": "invalid_api_key"
            }
        }
        """.data(using: .utf8)!
        
        let httpResponse = HTTPURLResponse(
            url: URL(string: "https://api.test.openai.com/v1/audio/transcriptions")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        return MockURLSessionDataTask.MockResponse(data: responseData, response: httpResponse, error: nil)
    }
    
    private func createMockTranscriptionResponse(text: String, language: String = "en") -> MockURLSessionDataTask.MockResponse {
        let responseData = """
        {
            "text": "\(text)",
            "language": "\(language)",
            "duration": 2.0,
            "segments": [
                {
                    "id": 0,
                    "start": 0.0,
                    "end": 2.0,
                    "text": "\(text)",
                    "confidence": 0.95
                }
            ]
        }
        """.data(using: .utf8)!
        
        let httpResponse = HTTPURLResponse(
            url: URL(string: "https://api.test.openai.com/v1/audio/transcriptions")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        return MockURLSessionDataTask.MockResponse(data: responseData, response: httpResponse, error: nil)
    }
    
    private func createMockChatCompletionResponse(content: String) -> MockURLSessionDataTask.MockResponse {
        let responseData = """
        {
            "id": "chatcmpl-test123",
            "object": "chat.completion",
            "created": 1677652288,
            "model": "gpt-4",
            "choices": [
                {
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": "\(content)"
                    },
                    "finish_reason": "stop"
                }
            ],
            "usage": {
                "prompt_tokens": 50,
                "completion_tokens": 100,
                "total_tokens": 150
            }
        }
        """.data(using: .utf8)!
        
        let httpResponse = HTTPURLResponse(
            url: URL(string: "https://api.test.openai.com/v1/chat/completions")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        return MockURLSessionDataTask.MockResponse(data: responseData, response: httpResponse, error: nil)
    }
    
    private func createMockRateLimitErrorResponse() -> MockURLSessionDataTask.MockResponse {
        let responseData = """
        {
            "error": {
                "message": "Rate limit exceeded",
                "type": "rate_limit_error",
                "code": "rate_limit_exceeded"
            }
        }
        """.data(using: .utf8)!
        
        let httpResponse = HTTPURLResponse(
            url: URL(string: "https://api.test.openai.com/v1/audio/transcriptions")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: [
                "Content-Type": "application/json",
                "Retry-After": "60"
            ]
        )!
        
        return MockURLSessionDataTask.MockResponse(data: responseData, response: httpResponse, error: nil)
    }
    
    private func createMockServerErrorResponse() -> MockURLSessionDataTask.MockResponse {
        let responseData = """
        {
            "error": {
                "message": "Internal server error",
                "type": "server_error",
                "code": "internal_error"
            }
        }
        """.data(using: .utf8)!
        
        let httpResponse = HTTPURLResponse(
            url: URL(string: "https://api.test.openai.com/v1/audio/transcriptions")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        return MockURLSessionDataTask.MockResponse(data: responseData, response: httpResponse, error: nil)
    }
    
    private func createMockTokenLimitErrorResponse() -> MockURLSessionDataTask.MockResponse {
        let responseData = """
        {
            "error": {
                "message": "This model's maximum context length is 4096 tokens",
                "type": "invalid_request_error",
                "code": "context_length_exceeded"
            }
        }
        """.data(using: .utf8)!
        
        let httpResponse = HTTPURLResponse(
            url: URL(string: "https://api.test.openai.com/v1/chat/completions")!,
            statusCode: 400,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        return MockURLSessionDataTask.MockResponse(data: responseData, response: httpResponse, error: nil)
    }
}

// MARK: - Mock网络会话

class MockURLSession: URLSession {
    var mockResponse: MockURLSessionDataTask.MockResponse?
    var shouldFail = false
    var shouldTimeout = false
    var error: Error?
    var requestHandler: ((URLRequest) throws -> MockURLSessionDataTask.MockResponse)?
    
    override func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        return MockURLSessionDataTask(request: request, session: self, completionHandler: completionHandler)
    }
}

class MockURLSessionDataTask: URLSessionDataTask {
    struct MockResponse {
        let data: Data
        let response: URLResponse
        let error: Error?
    }
    
    private let mockRequest: URLRequest
    private let mockSession: MockURLSession
    private let completionHandler: (Data?, URLResponse?, Error?) -> Void
    
    init(request: URLRequest, session: MockURLSession, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        self.mockRequest = request
        self.mockSession = session
        self.completionHandler = completionHandler
        super.init()
    }
    
    override func resume() {
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            if self.mockSession.shouldTimeout {
                self.completionHandler(nil, nil, URLError(.timedOut))
                return
            }
            
            if self.mockSession.shouldFail {
                self.completionHandler(nil, nil, self.mockSession.error ?? URLError(.unknown))
                return
            }
            
            // 使用自定义请求处理器
            if let handler = self.mockSession.requestHandler {
                do {
                    let response = try handler(self.mockRequest)
                    self.completionHandler(response.data, response.response, response.error)
                } catch {
                    self.completionHandler(nil, nil, error)
                }
                return
            }
            
            // 使用预设响应
            if let mockResponse = self.mockSession.mockResponse {
                self.completionHandler(mockResponse.data, mockResponse.response, mockResponse.error)
            } else {
                self.completionHandler(nil, nil, URLError(.unknown))
            }
        }
    }
}