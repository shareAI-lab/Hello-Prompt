//
//  IntegrationTests.swift
//  HelloPrompt
//
//  集成测试套件 - 测试各模块间的协作和完整工作流程
//  包含端到端测试、用户场景测试和系统集成验证
//

import XCTest
import Combine
import AVFoundation
@testable import HelloPrompt

class IntegrationTests: HelloPromptTestCase {
    
    // MARK: - 测试属性
    var appManager: AppManager!
    var audioService: AudioService!
    var openAIService: OpenAIService!
    var contextDetector: ContextDetector!
    var hotkeyService: HotkeyService!
    var configManager: AppConfigManager!
    var errorHandler: ErrorHandler!
    
    // Mock组件
    var mockNetworkSession: MockURLSession!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // 初始化真实组件
        audioService = AudioService()
        openAIService = OpenAIService()
        contextDetector = ContextDetector.shared
        hotkeyService = HotkeyService.shared
        configManager = AppConfigManager.shared
        errorHandler = ErrorHandler.shared
        
        // 初始化mock组件
        mockNetworkSession = MockURLSession()
        
        // 初始化AppManager
        appManager = AppManager.shared
        
        // 配置测试环境
        await setupIntegrationTestEnvironment()
    }
    
    override func tearDown() async throws {
        await cleanupIntegrationTestEnvironment()
        
        appManager = nil
        audioService = nil
        openAIService = nil
        contextDetector = nil
        hotkeyService = nil
        configManager = nil
        errorHandler = nil
        mockNetworkSession = nil
        
        try await super.tearDown()
    }
    
    // MARK: - 环境设置
    
    @MainActor
    private func setupIntegrationTestEnvironment() async {
        // 配置OpenAI服务
        openAIService.configure(
            apiKey: "test_api_key_integration",
            baseURL: "https://api.test.openai.com/v1"
        )
        openAIService.urlSession = mockNetworkSession
        
        // 配置mock响应
        setupMockResponses()
        
        // 初始化AppManager
        do {
            await appManager.initialize()
        } catch {
            print("Warning: AppManager initialization failed in test setup: \(error)")
        }
    }
    
    @MainActor
    private func cleanupIntegrationTestEnvironment() async {
        // 停止所有活动操作
        if appManager.appState != .idle {
            appManager.cancelCurrentWorkflow()
        }
        
        // 重置到闲置状态
        await appManager.resetApplicationState()
        
        // 清理快捷键
        hotkeyService.resetToDefaults()
    }
    
    private func setupMockResponses() {
        // 设置转录响应
        mockNetworkSession.mockResponse = createMockTranscriptionResponse(
            text: "请帮我写一个Python函数来计算斐波那契数列"
        )
    }
    
    // MARK: - 完整工作流程测试
    
    func testCompleteVoiceToPromptWorkflow() async throws {
        // 测试完整的语音到提示词工作流程
        let workflowExpectation = XCTestExpectation(description: "Complete workflow")
        
        // 设置mock响应
        setupMockTranscriptionAndOptimizationResponses()
        
        // 监听状态变化
        var stateChanges: [AppState] = []
        appManager.$appState
            .sink { state in
                stateChanges.append(state)
                print("State changed to: \(state)")
                
                if state == .presenting {
                    workflowExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // 开始工作流程
        do {
            await appManager.startVoiceToPromptWorkflow()
            
            // 模拟录音过程
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            
            // 停止录音（模拟用户操作或VAD检测）
            if appManager.audioService.isRecording {
                appManager.audioService.stopRecording()
            }
            
        } catch {
            XCTFail("Workflow should not throw error: \(error)")
            workflowExpectation.fulfill()
        }
        
        await fulfillment(of: [workflowExpectation], timeout: 10.0)
        
        // 验证状态变化序列
        XCTAssertTrue(stateChanges.contains(.listening), "Should enter listening state")
        XCTAssertTrue(stateChanges.contains(.recording), "Should enter recording state")
        XCTAssertTrue(stateChanges.contains(.processing), "Should enter processing state")
        XCTAssertTrue(stateChanges.contains(.presenting), "Should enter presenting state")
        
        // 验证最终结果
        XCTAssertFalse(appManager.lastResult.isEmpty, "Should have a result")
        XCTAssertEqual(appManager.appState, .presenting, "Should be in presenting state")
    }
    
    func testWorkflowWithAudioInitializationFailure() async throws {
        // 测试音频初始化失败的工作流程
        let mockAudioService = MockAudioService()
        mockAudioService.shouldFailPermissionRequest = true
        
        // 替换音频服务
        appManager.audioService = mockAudioService
        
        do {
            await appManager.startVoiceToPromptWorkflow()
            XCTFail("Should fail with audio initialization error")
        } catch let error as AudioSystemError {
            switch error {
            case .permissionDenied:
                XCTAssertEqual(appManager.appState, .error, "Should be in error state")
            default:
                XCTFail("Unexpected audio error: \(error)")
            }
        }
    }
    
    func testWorkflowWithNetworkFailure() async throws {
        // 测试网络失败的工作流程
        mockNetworkSession.shouldFail = true
        mockNetworkSession.error = URLError(.notConnectedToInternet)
        
        let networkFailureExpectation = XCTestExpectation(description: "Network failure handling")
        
        // 监听错误状态
        appManager.$appState
            .sink { state in
                if state == .error {
                    networkFailureExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // 开始工作流程
        await appManager.startVoiceToPromptWorkflow()
        
        // 模拟录音并停止
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2秒
        if appManager.audioService.isRecording {
            appManager.audioService.stopRecording()
        }
        
        await fulfillment(of: [networkFailureExpectation], timeout: 15.0)
        
        XCTAssertEqual(appManager.appState, .error, "Should be in error state after network failure")
    }
    
    // MARK: - 用户场景测试
    
    func testQuickVoicePromptScenario() async throws {
        // 测试快速语音提示场景
        setupMockResponsesForQuickPrompt()
        
        let scenarioExpectation = XCTestExpectation(description: "Quick voice prompt scenario")
        
        // 监听完成
        appManager.$appState
            .sink { state in
                if state == .presenting {
                    scenarioExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // 模拟用户快速操作
        await appManager.startVoiceToPromptWorkflow()
        
        // 快速录音
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        appManager.audioService.stopRecording()
        
        await fulfillment(of: [scenarioExpectation], timeout: 8.0)
        
        // 验证结果质量
        XCTAssertFalse(appManager.lastResult.isEmpty, "Should have optimized result")
        XCTAssertGreaterThan(appManager.lastResult.count, 50, "Result should be reasonably detailed")
    }
    
    func testLongFormPromptScenario() async throws {
        // 测试长形式提示场景
        setupMockResponsesForLongPrompt()
        
        let longFormExpectation = XCTestExpectation(description: "Long form prompt scenario")
        
        appManager.$appState
            .sink { state in
                if state == .presenting {
                    longFormExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // 模拟长时间录音
        await appManager.startVoiceToPromptWorkflow()
        
        // 长录音时间
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
        appManager.audioService.stopRecording()
        
        await fulfillment(of: [longFormExpectation], timeout: 15.0)
        
        // 验证长形式结果
        XCTAssertGreaterThan(appManager.lastResult.count, 200, "Long form result should be comprehensive")
    }
    
    func testMultipleConsecutivePromptsScenario() async throws {
        // 测试连续多个提示词场景
        let numberOfPrompts = 3
        var completedPrompts = 0
        let consecutiveExpectation = XCTestExpectation(description: "Multiple consecutive prompts")
        
        // 为每个提示设置不同的响应
        var responseIndex = 0
        let responses = [
            "优化后的第一个提示词：请详细描述您需要的Python函数功能",
            "优化后的第二个提示词：请说明您希望实现的具体算法和数据结构",
            "优化后的第三个提示词：请提供您期望的输入输出格式和错误处理需求"
        ]
        
        mockNetworkSession.requestHandler = { request in
            defer { responseIndex += 1 }
            
            if request.url?.path.contains("transcriptions") == true {
                return self.createMockTranscriptionResponse(text: "提示词 \(responseIndex + 1)")
            } else if request.url?.path.contains("chat/completions") == true {
                return self.createMockChatCompletionResponse(content: responses[responseIndex % responses.count])
            }
            
            throw URLError(.badURL)
        }
        
        // 连续执行多个提示
        for i in 0..<numberOfPrompts {
            await appManager.resetApplicationState()
            
            let singlePromptExpectation = XCTestExpectation(description: "Single prompt \(i)")
            
            appManager.$appState
                .sink { state in
                    if state == .presenting {
                        completedPrompts += 1
                        singlePromptExpectation.fulfill()
                    }
                }
                .store(in: &cancellables)
            
            await appManager.startVoiceToPromptWorkflow()
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3秒
            appManager.audioService.stopRecording()
            
            await fulfillment(of: [singlePromptExpectation], timeout: 10.0)
            
            // 验证每个结果
            XCTAssertFalse(appManager.lastResult.isEmpty, "Prompt \(i) should have result")
        }
        
        XCTAssertEqual(completedPrompts, numberOfPrompts, "All prompts should complete successfully")
        consecutiveExpectation.fulfill()
        
        await fulfillment(of: [consecutiveExpectation], timeout: 1.0)
    }
    
    // MARK: - 快捷键集成测试
    
    func testHotkeyIntegrationWithWorkflow() async throws {
        // 测试快捷键与工作流程的集成
        setupMockResponsesForQuickPrompt()
        
        let hotkeyIntegrationExpectation = XCTestExpectation(description: "Hotkey integration")
        
        // 注册快捷键处理器
        var hotkeyTriggered = false
        let success = hotkeyService.registerHotkey(.startRecording, 
                                                  shortcut: KeyboardShortcut(.space, modifiers: [.option, .command])) {
            hotkeyTriggered = true
            Task {
                await self.appManager.startVoiceToPromptWorkflow()
            }
        }
        
        XCTAssertTrue(success, "Hotkey registration should succeed")
        
        // 监听工作流程完成
        appManager.$appState
            .sink { state in
                if state == .presenting {
                    hotkeyIntegrationExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // 模拟快捷键触发
        simulateHotkeyTrigger(.startRecording)
        
        // 给快捷键处理一些时间
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        // 模拟录音完成
        if appManager.audioService.isRecording {
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2秒
            appManager.audioService.stopRecording()
        }
        
        await fulfillment(of: [hotkeyIntegrationExpectation], timeout: 10.0)
        
        XCTAssertTrue(hotkeyTriggered, "Hotkey should be triggered")
        XCTAssertEqual(appManager.appState, .presenting, "Should complete workflow via hotkey")
        
        // 清理
        _ = hotkeyService.unregisterHotkey(.startRecording)
    }
    
    // MARK: - 错误恢复测试
    
    func testErrorRecoveryAndRetry() async throws {
        // 测试错误恢复和重试机制
        var attemptCount = 0
        mockNetworkSession.requestHandler = { request in
            attemptCount += 1
            
            if attemptCount <= 2 {
                // 前两次失败
                throw URLError(.networkConnectionLost)
            } else {
                // 第三次成功
                if request.url?.path.contains("transcriptions") == true {
                    return self.createMockTranscriptionResponse(text: "成功恢复的转录结果")
                } else {
                    return self.createMockChatCompletionResponse(content: "成功恢复的优化结果")
                }
            }
        }
        
        let recoveryExpectation = XCTestExpectation(description: "Error recovery")
        
        // 监听最终成功
        appManager.$appState
            .sink { state in
                if state == .presenting {
                    recoveryExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // 开始工作流程
        await appManager.startVoiceToPromptWorkflow()
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2秒
        appManager.audioService.stopRecording()
        
        await fulfillment(of: [recoveryExpectation], timeout: 20.0)
        
        XCTAssertGreaterThan(attemptCount, 2, "Should retry after failures")
        XCTAssertEqual(appManager.appState, .presenting, "Should eventually succeed")
        XCTAssertTrue(appManager.lastResult.contains("成功恢复"), "Should have recovered result")
    }
    
    // MARK: - 性能集成测试
    
    func testEndToEndPerformance() async throws {
        // 测试端到端性能
        setupMockResponsesForPerformanceTest()
        
        await measureAsync({
            await self.appManager.resetApplicationState()
            await self.appManager.startVoiceToPromptWorkflow()
            
            // 模拟快速录音
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            self.appManager.audioService.stopRecording()
            
            // 等待完成
            while self.appManager.appState != .presenting && self.appManager.appState != .error {
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05秒
            }
            
            XCTAssertEqual(self.appManager.appState, .presenting, "Should complete successfully")
        }, iterations: 3, name: "End-to-End Performance")
    }
    
    func testMemoryUsageIntegration() throws {
        // 测试集成场景下的内存使用
        setupMockResponsesForQuickPrompt()
        
        try measureMemoryUsage({
            // 运行多个工作流程周期
            let group = DispatchGroup()
            
            for _ in 0..<5 {
                group.enter()
                Task {
                    await self.appManager.resetApplicationState()
                    await self.appManager.startVoiceToPromptWorkflow()
                    
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                    self.appManager.audioService.stopRecording()
                    
                    // 等待完成
                    while self.appManager.appState == .processing {
                        try await Task.sleep(nanoseconds: 10_000_000) // 0.01秒
                    }
                    
                    group.leave()
                }
            }
            
            group.wait()
        }, name: "Integration Memory Usage")
    }
    
    // MARK: - 辅助方法
    
    private func setupMockTranscriptionAndOptimizationResponses() {
        mockNetworkSession.requestHandler = { request in
            if request.url?.path.contains("transcriptions") == true {
                return self.createMockTranscriptionResponse(
                    text: "请帮我写一个Python函数来计算斐波那契数列"
                )
            } else if request.url?.path.contains("chat/completions") == true {
                return self.createMockChatCompletionResponse(content: """
                请编写一个Python函数来计算斐波那契数列，具体要求如下：

                1. 函数名称：fibonacci
                2. 输入参数：n (整数，表示要计算的项数)
                3. 返回值：包含前n项斐波那契数的列表
                4. 处理边界情况：n=0返回空列表，n=1返回[0]，n=2返回[0,1]
                5. 实现方式：使用迭代方法以提高性能
                6. 添加类型提示和文档字符串
                7. 包含输入验证（确保n为非负整数）

                示例用法：
                - fibonacci(5) 应返回 [0, 1, 1, 2, 3]
                - fibonacci(0) 应返回 []
                """)
            }
            
            throw URLError(.badURL)
        }
    }
    
    private func setupMockResponsesForQuickPrompt() {
        mockNetworkSession.requestHandler = { request in
            if request.url?.path.contains("transcriptions") == true {
                return self.createMockTranscriptionResponse(text: "快速提示")
            } else {
                return self.createMockChatCompletionResponse(content: "优化后的快速提示：请详细说明您的具体需求和期望结果。")
            }
        }
    }
    
    private func setupMockResponsesForLongPrompt() {
        mockNetworkSession.requestHandler = { request in
            if request.url?.path.contains("transcriptions") == true {
                return self.createMockTranscriptionResponse(
                    text: "这是一个很长的提示，包含了很多细节和具体的要求，需要系统进行全面的分析和优化处理。"
                )
            } else {
                return self.createMockChatCompletionResponse(content: """
                基于您提供的详细需求，我为您优化了以下完整的提示词：

                ## 项目背景
                请详细描述您的项目背景和业务场景，包括：
                - 目标用户群体
                - 预期使用场景
                - 技术栈要求

                ## 功能需求
                1. 核心功能描述
                2. 性能要求指标
                3. 兼容性要求
                4. 安全性考虑

                ## 实现细节
                - 架构设计原则
                - 关键算法选择
                - 数据结构优化
                - 错误处理策略

                ## 交付标准
                - 代码质量要求
                - 测试覆盖率标准
                - 文档完整性要求
                - 部署和维护指南

                请按照以上结构提供您的具体需求，以便我为您提供最准确的解决方案。
                """)
            }
        }
    }
    
    private func setupMockResponsesForPerformanceTest() {
        mockNetworkSession.requestHandler = { request in
            // 添加轻微延迟模拟真实网络
            Thread.sleep(forTimeInterval: 0.05) // 50ms
            
            if request.url?.path.contains("transcriptions") == true {
                return self.createMockTranscriptionResponse(text: "性能测试提示")
            } else {
                return self.createMockChatCompletionResponse(content: "优化后的性能测试提示")
            }
        }
    }
    
    private func simulateHotkeyTrigger(_ identifier: HotkeyIdentifier) {
        // 在真实测试中，这会通过系统快捷键机制触发
        // 这里我们直接调用处理器
        DispatchQueue.main.async {
            // 模拟快捷键事件处理
            print("Simulating hotkey trigger for: \(identifier)")
        }
    }
    
    // MARK: - Mock响应创建
    
    private func createMockTranscriptionResponse(text: String) -> MockURLSessionDataTask.MockResponse {
        let responseData = """
        {
            "text": "\(text)",
            "language": "zh",
            "duration": 1.5
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
            "id": "chatcmpl-integration-test",
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
                "prompt_tokens": 20,
                "completion_tokens": 50,
                "total_tokens": 70
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
}