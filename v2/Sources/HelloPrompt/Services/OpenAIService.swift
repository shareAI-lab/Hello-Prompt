//
//  OpenAIService.swift
//  HelloPrompt
//
//  OpenAI API服务层 - 提供Whisper语音识别和GPT-4提示词优化
//  包含重试机制、错误处理和性能优化
//

import Foundation
import OpenAI
import Combine

// 使用Models/OpenAIModels.swift中定义的APIRequestState

// MARK: - API验证相关数据结构
public struct APIValidationResult {
    let isValid: Bool
    let errors: [APIValidationError]
    let warnings: [String]
    let estimatedQuota: Int?
    let responseTime: TimeInterval?
    
    var hasErrors: Bool { !errors.isEmpty }
    var hasWarnings: Bool { !warnings.isEmpty }
}

public enum APIValidationError: LocalizedError {
    case invalidAPIKey
    case networkUnavailable
    case quotaExceeded
    case serviceUnavailable
    case rateLimited(retryAfter: TimeInterval?)
    case authenticationFailed
    case invalidBaseURL
    
    public var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "API密钥无效或为空"
        case .networkUnavailable:
            return "网络连接不可用"
        case .quotaExceeded:
            return "API配额已用完"
        case .serviceUnavailable:
            return "OpenAI服务暂时不可用"
        case .rateLimited(let retryAfter):
            let timeText = retryAfter.map { "，请在\(Int($0))秒后重试" } ?? ""
            return "请求频率过高\(timeText)"
        case .authenticationFailed:
            return "API认证失败"
        case .invalidBaseURL:
            return "API基础URL无效"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .invalidAPIKey:
            return "请在设置中配置有效的OpenAI API密钥"
        case .networkUnavailable:
            return "请检查网络连接是否正常"
        case .quotaExceeded:
            return "请充值OpenAI账户或等待配额重置"
        case .serviceUnavailable:
            return "请稍后再试，或检查OpenAI服务状态"
        case .rateLimited:
            return "请降低请求频率或升级API账户"
        case .authenticationFailed:
            return "请验证API密钥是否正确且有效"
        case .invalidBaseURL:
            return "请检查API基础URL配置是否正确"
        }
    }
}

// MARK: - 重试策略
public enum RetryStrategy {
    case linear(interval: TimeInterval)
    case exponential(baseInterval: TimeInterval, maxInterval: TimeInterval)
    case fixed(interval: TimeInterval)
    
    func delay(for attempt: Int) -> TimeInterval {
        switch self {
        case .linear(let interval):
            return interval * Double(attempt)
        case .exponential(let baseInterval, let maxInterval):
            let delay = baseInterval * pow(2.0, Double(attempt - 1))
            return min(delay, maxInterval)
        case .fixed(let interval):
            return interval
        }
    }
}

// MARK: - API响应数据结构
public struct TranscriptionResult {
    let text: String
    let language: String?
    let duration: TimeInterval
    let confidence: Float?
    
    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// 使用Models/OpenAIModels.swift中定义的OptimizationResult

// MARK: - 主OpenAI服务类
@MainActor
public final class OpenAIService: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var state: APIRequestState = .idle
    @Published public var isProcessing = false
    @Published public var progress: Float = 0.0
    @Published public var lastError: APIError?
    
    // MARK: - Private Properties
    private var openAI: OpenAI?
    private let urlSession: URLSession
    private var currentTask: Task<Void, Never>?
    
    // 配置参数
    private let maxRetryAttempts = 3
    private let requestTimeout: TimeInterval = 30.0
    private let retryStrategy: RetryStrategy = .exponential(baseInterval: 1.0, maxInterval: 10.0)
    
    // 性能统计
    private var requestCount = 0
    private var totalRequestTime: TimeInterval = 0.0
    private var successCount = 0
    private var failureCount = 0
    
    // MARK: - 初始化
    public init() {
        // 创建优化的URLSession配置
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = requestTimeout
        config.timeoutIntervalForResource = requestTimeout * 2
        config.httpShouldUsePipelining = true
        config.httpMaximumConnectionsPerHost = 4
        config.httpAdditionalHeaders = [
            "Accept-Encoding": "gzip, deflate, br",
            "Connection": "keep-alive",
            "User-Agent": "HelloPrompt/1.0 (macOS)"
        ]
        
        self.urlSession = URLSession(configuration: config)
        
        LogManager.shared.info("OpenAIService", "OpenAI服务初始化完成")
    }
    
    deinit {
        currentTask?.cancel()
        urlSession.invalidateAndCancel()
    }
    
    // MARK: - 配置管理
    public func configure(apiKey: String, baseURL: String = "https://api.openai.com/v1") {
        guard !apiKey.isEmpty else {
            LogManager.shared.warning("OpenAIService", "API密钥为空，无法配置OpenAI客户端")
            self.openAI = nil
            return
        }
        
        // 正确解析URL
        guard let url = URL(string: baseURL) else {
            LogManager.shared.error("OpenAIService", "无效的BaseURL: \(baseURL)")
            self.openAI = nil
            return
        }
        
        let configuration = OpenAI.Configuration(
            token: apiKey,
            host: url.host ?? "api.openai.com",
            scheme: url.scheme ?? "https",
            timeoutInterval: requestTimeout
        )
        
        self.openAI = OpenAI(configuration: configuration)
        
        LogManager.shared.info("OpenAIService", """
            OpenAI配置已更新
            BaseURL: \(baseURL)
            Host: \(url.host ?? "api.openai.com")
            Scheme: \(url.scheme ?? "https")
            Timeout: \(requestTimeout)s
            API Key: [已配置]
            """)
    }
    
    /// 从配置管理器自动配置
    public func configureFromSettings() {
        do {
            guard let apiKey = try AppConfigManager.shared.getOpenAIAPIKey(),
                  !apiKey.isEmpty else {
                LogManager.shared.info("OpenAIService", "未配置API密钥")
                return
            }
            
            let baseURL = AppConfigManager.shared.openAIBaseURL
            configure(apiKey: apiKey, baseURL: baseURL)
            
        } catch {
            LogManager.shared.error("OpenAIService", "从配置加载API密钥失败: \(error)")
        }
    }
    
    // MARK: - API验证系统
    
    /// 全面验证API配置和连接状态
    public func validateConfiguration() async -> APIValidationResult {
        var errors: [APIValidationError] = []
        var warnings: [String] = []
        var responseTime: TimeInterval?
        
        LogManager.shared.info("OpenAIService", "开始API配置验证")
        
        // 1. 检查API密钥
        guard let apiKey = try? AppConfigManager.shared.getOpenAIAPIKey(),
              !apiKey.isEmpty else {
            errors.append(.invalidAPIKey)
            LogManager.shared.error("OpenAIService", "API密钥验证失败：未配置或为空")
            return APIValidationResult(
                isValid: false,
                errors: errors,
                warnings: warnings,
                estimatedQuota: nil,
                responseTime: nil
            )
        }
        
        // 2. 验证API密钥格式
        if !isValidAPIKeyFormat(apiKey) {
            errors.append(.invalidAPIKey)
            LogManager.shared.error("OpenAIService", "API密钥格式无效")
        }
        
        // 3. 验证基础URL
        let baseURL = AppConfigManager.shared.openAIBaseURL
        if !isValidBaseURL(baseURL) {
            errors.append(.invalidBaseURL)
            LogManager.shared.error("OpenAIService", "基础URL格式无效: \(baseURL)")
        }
        
        // 4. 网络连接测试
        let startTime = Date()
        let connectionResult = await testConnection()
        responseTime = Date().timeIntervalSince(startTime)
        
        switch connectionResult {
        case .success:
            LogManager.shared.info("OpenAIService", "连接测试成功，响应时间: \(String(format: "%.2f", responseTime!))s")
            
            // 响应时间警告
            if responseTime! > 5.0 {
                warnings.append("网络响应较慢，可能影响使用体验")
            }
            
        case .failure(let error):
            let validationError = mapAPIErrorToValidationError(error)
            errors.append(validationError)
            LogManager.shared.error("OpenAIService", "连接测试失败: \(error)")
        }
        
        // 5. 模型可用性测试（仅在连接成功时）
        if errors.isEmpty {
            let modelResult = await testModelAvailability()
            switch modelResult {
            case .success(let models):
                LogManager.shared.info("OpenAIService", "模型可用性测试成功，可用模型: \(models.count)个")
                
                // 检查关键模型
                let requiredModels = ["whisper-1", "gpt-4o", "gpt-4o-mini", "gpt-4", "gpt-3.5-turbo"]
                let availableModelNames = models.map { $0.id }
                for requiredModel in requiredModels {
                    if !availableModelNames.contains(requiredModel) {
                        warnings.append("模型 \(requiredModel) 不可用")
                    }
                }
                
            case .failure(let error):
                let validationError = mapAPIErrorToValidationError(error)
                errors.append(validationError)
                LogManager.shared.error("OpenAIService", "模型可用性检查失败: \(error.localizedDescription)")
            }
        }
        
        let isValid = errors.isEmpty
        LogManager.shared.info("OpenAIService", "API验证完成，有效: \(isValid), 错误: \(errors.count), 警告: \(warnings.count)")
        
        return APIValidationResult(
            isValid: isValid,
            errors: errors,
            warnings: warnings,
            estimatedQuota: nil, // 可以后续添加配额检查
            responseTime: responseTime
        )
    }
    
    /// 验证API密钥格式
    private func isValidAPIKeyFormat(_ apiKey: String) -> Bool {
        // OpenAI API密钥通常以 "sk-" 开头，长度约51字符
        return apiKey.hasPrefix("sk-") && apiKey.count >= 20
    }
    
    /// 验证基础URL格式
    private func isValidBaseURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme == "https" && url.host != nil
    }
    
    /// 将API错误映射为验证错误
    private func mapAPIErrorToValidationError(_ error: APIError) -> APIValidationError {
        switch error {
        case .invalidAPIKey:
            return .authenticationFailed
        case .networkTimeout:
            return .networkUnavailable
        case .quotaExceeded:
            return .quotaExceeded
        case .rateLimitExceeded(let retryAfter):
            return .rateLimited(retryAfter: retryAfter)
        case .serverError:
            return .serviceUnavailable
        case .invalidResponse:
            return .serviceUnavailable
        case .optimizationFailed, .audioFileTooLarge, .transcriptionEmpty, .modelNotAvailable, .contentFiltered:
            return .serviceUnavailable
        }
    }
    
    /// 测试模型可用性
    private func testModelAvailability() async -> Result<[ModelResult], APIError> {
        guard let openAI = openAI else {
            return .failure(.invalidAPIKey)
        }
        
        do {
            let modelsResult = try await openAI.models()
            return .success(modelsResult.data)
        } catch {
            LogManager.shared.error("OpenAIService", "模型列表获取失败: \(error)")
            return .failure(.serverError(statusCode: 500, message: error.localizedDescription))
        }
    }
    
    // MARK: - API连接测试
    public func testConnection() async -> Result<Bool, APIError> {
        guard let openAI = openAI else {
            return .failure(.invalidAPIKey)
        }
        
        LogManager.shared.apiLog(.requestAttempt, details: ["operation": "connectionTest"])
        
        do {
            // 使用简单的模型列表请求测试连接
            let startTime = CFAbsoluteTimeGetCurrent()
            _ = try await openAI.models()
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            LogManager.shared.apiLog(.requestSuccess, duration: duration, details: [
                "operation": "connectionTest"
            ])
            
            return .success(true)
            
        } catch {
            let apiError = mapToAPIError(error)
            LogManager.shared.apiLog(.requestError, level: .error, details: [
                "operation": "connectionTest",
                "error": error.localizedDescription
            ])
            
            return .failure(apiError)
        }
    }
    
    // MARK: - 模型选择
    private func getSelectedChatModel() -> Model {
        let configuredModel = AppConfigManager.shared.openAIModel
        
        // 如果配置为空，使用默认值
        if configuredModel.isEmpty {
            return "gpt-4o-mini"
        }
        
        // 直接返回配置的模型字符串，让OpenAI SDK处理
        return configuredModel
    }
    
    private func getSelectedChatModelName() -> String {
        let configuredModel = AppConfigManager.shared.openAIModel
        return configuredModel.isEmpty ? "gpt-4o-mini" : configuredModel
    }
    
    // MARK: - 语音转录
    public func transcribeAudio(_ audioData: Data, language: String? = nil) async -> Result<TranscriptionResult, APIError> {
        guard let openAI = openAI else {
            return .failure(.invalidAPIKey)
        }
        
        // 检查音频文件大小
        let maxSize = 25 * 1024 * 1024  // 25MB
        if audioData.count > maxSize {
            return .failure(.audioFileTooLarge(size: audioData.count))
        }
        
        state = .transcribing
        isProcessing = true
        progress = 0.0
        
        LogManager.shared.apiLog(.requestStarted, details: [
            "operation": "transcription",
            "audioSize": audioData.count,
            "language": language ?? "auto"
        ])
        
        let result = await performWithRetry(operation: "transcription") { attempt in
            try await self.performTranscription(openAI, audioData: audioData, language: language, attempt: attempt)
        }
        
        state = result.isSuccess ? .completed : .failed
        isProcessing = false
        progress = result.isSuccess ? 1.0 : 0.0
        
        return result
    }
    
    private func performTranscription(_ openAI: OpenAI, audioData: Data, language: String?, attempt: Int) async throws -> TranscriptionResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 更新进度
        progress = 0.3
        
        // 压缩音频数据（如果需要）
        let processedAudioData = try compressAudioIfNeeded(audioData)
        
        progress = 0.5
        
        // 实现真正的OpenAI Whisper API调用
        do {
            // 创建转录请求 - 直接使用音频数据
            let audioTranscriptionQuery = AudioTranscriptionQuery(
                file: processedAudioData,
                fileType: .wav,
                model: .whisper_1,
                temperature: 0.0,
                language: language,
                responseFormat: .json
            )
            
            progress = 0.7
            
            LogManager.shared.apiLog(.requestStarted, details: [
                "model": "whisper-1",
                "audioSize": processedAudioData.count,
                "language": language ?? "auto"
            ])
            
            // 执行转录请求
            let transcriptionResponse = try await openAI.audioTranscriptions(query: audioTranscriptionQuery)
            
            progress = 0.9
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            // 构建结果
            let result = TranscriptionResult(
                text: transcriptionResponse.text,
                language: language ?? "auto",
                duration: duration,
                confidence: nil  // Whisper API不提供置信度
            )
            
            // 检查结果是否为空
            if result.isEmpty {
                throw APIError.transcriptionEmpty
            }
            
            LogManager.shared.apiLog(.requestCompleted, duration: duration, details: [
                "operation": "transcription",
                "attempt": attempt,
                "textLength": result.text.count,
                "language": result.language ?? "unknown"
            ])
            
            return result
            
        } catch {
            LogManager.shared.apiLog(.requestError, level: .error, details: [
                "operation": "transcription",
                "attempt": attempt,
                "error": error.localizedDescription
            ])
            
            // 将错误映射为APIError并抛出
            let mappedError = mapToAPIError(error)
            
            // 特殊处理API认证错误
            if case .invalidAPIKey = mappedError {
                LogManager.shared.error("OpenAIService", "API密钥无效或未配置")
            }
            
            throw mappedError
        }
    }
    
    // MARK: - 提示词优化
    public func optimizePrompt(_ originalText: String, context: String? = nil) async -> Result<OptimizationResult, APIError> {
        guard let openAI = openAI else {
            return .failure(.invalidAPIKey)
        }
        
        guard !originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.optimizationFailed(NSError(domain: "EmptyInput", code: 0, userInfo: [NSLocalizedDescriptionKey: "输入文本为空"])))
        }
        
        state = .optimizing
        isProcessing = true
        progress = 0.0
        
        LogManager.shared.apiLog(.requestStarted, details: [
            "operation": "optimization",
            "originalLength": originalText.count,
            "context": context ?? "none"
        ])
        
        let result = await performWithRetry(operation: "optimization") { attempt in
            try await self.performOptimization(openAI, originalText: originalText, context: context, attempt: attempt)
        }
        
        state = result.isSuccess ? .completed : .failed
        isProcessing = false
        progress = result.isSuccess ? 1.0 : 0.0
        
        return result
    }
    
    private func performOptimization(_ openAI: OpenAI, originalText: String, context: String?, attempt: Int) async throws -> OptimizationResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        progress = 0.2
        
        // 构建优化提示词
        let systemPrompt = buildOptimizationSystemPrompt(context: context)
        let userPrompt = buildOptimizationUserPrompt(originalText: originalText)
        
        progress = 0.4
        
        do {
            // 创建聊天请求
            let chatQuery = ChatQuery(
                messages: [
                    ChatQuery.ChatCompletionMessageParam(role: .system, content: systemPrompt)!,
                    ChatQuery.ChatCompletionMessageParam(role: .user, content: userPrompt)!
                ],
                model: .gpt4_o_mini,
                temperature: 0.7
            )
            
            progress = 0.6
            
            LogManager.shared.apiLog(.requestStarted, details: [
                "model": "gpt-4o-mini",
                "originalLength": originalText.count,
                "systemPromptLength": systemPrompt.count,
                "temperature": 0.7
            ])
            
            // 执行聊天请求
            let chatResult = try await openAI.chats(query: chatQuery)
            
            progress = 0.9
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            // 获取响应内容
            guard let choice = chatResult.choices.first,
                  let content = choice.message.content else {
                throw APIError.invalidResponse(statusCode: 200)
            }
            
            // 解析优化结果
            let optimizationResult = parseOptimizationResult(
                content: content,
                originalText: originalText,
                processingTime: duration
            )
            
            progress = 1.0
            
            LogManager.shared.apiLog(.requestCompleted, duration: duration, details: [
                "operation": "optimization",
                "attempt": attempt,
                "originalLength": originalText.count,
                "optimizedLength": optimizationResult.optimizedPrompt.count,
                "improvements": optimizationResult.improvements.count,
                "tokensUsed": chatResult.usage?.totalTokens ?? 0,
                "isPlaceholder": false
            ])
            
            return optimizationResult
            
        } catch {
            LogManager.shared.apiLog(.requestError, level: .error, details: [
                "operation": "optimization",
                "attempt": attempt,
                "error": error.localizedDescription
            ])
            
            // 如果是API配置问题，直接抛出错误而不是提供误导性的占位符结果
            if error.localizedDescription.contains("Invalid API key") ||
               error.localizedDescription.contains("Unauthorized") ||
               error.localizedDescription.contains("authentication") {
                LogManager.shared.warning("OpenAIService", "API密钥无效，无法进行优化")
                throw APIError.invalidAPIKey
            }
            
            throw error
        }
    }
    
    // MARK: - 语音修改功能
    public func modifyPrompt(_ originalPrompt: String, modificationRequest: String) async -> Result<OptimizationResult, APIError> {
        guard let openAI = openAI else {
            return .failure(.invalidAPIKey)
        }
        
        state = .optimizing
        isProcessing = true
        progress = 0.0
        
        LogManager.shared.apiLog(.requestStarted, details: [
            "operation": "modification",
            "originalLength": originalPrompt.count,
            "modificationLength": modificationRequest.count
        ])
        
        let result = await performWithRetry(operation: "modification") { attempt in
            try await self.performModification(openAI, originalPrompt: originalPrompt, modificationRequest: modificationRequest, attempt: attempt)
        }
        
        state = result.isSuccess ? .completed : .failed
        isProcessing = false
        progress = result.isSuccess ? 1.0 : 0.0
        
        return result
    }
    
    private func performModification(_ openAI: OpenAI, originalPrompt: String, modificationRequest: String, attempt: Int) async throws -> OptimizationResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 构建修改提示词
        let systemPrompt = """
        你是一个AI提示词修改专家。用户会提供一个原始提示词和修改需求，请根据修改需求对原始提示词进行调整，返回完整的修改后提示词。
        
        要求：
        1. 理解修改需求的意图
        2. 保持原有提示词的核心功能
        3. 融入修改需求，形成新的完整提示词
        4. 确保修改后的提示词清晰、具体、可执行
        5. 如果修改需求与原提示词冲突，以修改需求为准
        
        返回格式：
        ```
        [修改后的完整提示词]
        
        主要改进：
        - 改进点1
        - 改进点2
        - ...
        ```
        """
        
        let userPrompt = """
        原始提示词：
        \(originalPrompt)
        
        修改需求：
        \(modificationRequest)
        
        请返回修改后的完整提示词：
        """
        
        do {
            // 创建聊天请求
            let chatQuery = ChatQuery(
                messages: [
                    ChatQuery.ChatCompletionMessageParam(role: .system, content: systemPrompt)!,
                    ChatQuery.ChatCompletionMessageParam(role: .user, content: userPrompt)!
                ],
                model: .gpt4_o_mini,
                temperature: 0.7
            )
            
            LogManager.shared.apiLog(.requestStarted, details: [
                "model": "gpt-4o-mini",
                "originalLength": originalPrompt.count,
                "modificationLength": modificationRequest.count,
                "temperature": 0.7
            ])
            
            // 执行聊天请求
            let chatResult = try await openAI.chats(query: chatQuery)
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            // 获取响应内容
            guard let choice = chatResult.choices.first,
                  let content = choice.message.content else {
                throw APIError.invalidResponse(statusCode: 200)
            }
            
            // 解析修改结果
            let modificationResult = parseModificationResult(
                content: content,
                originalText: originalPrompt,
                processingTime: duration
            )
            
            LogManager.shared.apiLog(.requestCompleted, duration: duration, details: [
                "operation": "modification",
                "attempt": attempt,
                "originalLength": originalPrompt.count,
                "modifiedLength": modificationResult.optimizedPrompt.count,
                "tokensUsed": chatResult.usage?.totalTokens ?? 0
            ])
            
            return modificationResult
            
        } catch {
            LogManager.shared.apiLog(.requestError, level: .error, details: [
                "operation": "modification",
                "attempt": attempt,
                "error": error.localizedDescription
            ])
            
            // 如果是API配置问题，直接抛出错误而不是提供误导性的占位符结果
            if error.localizedDescription.contains("Invalid API key") ||
               error.localizedDescription.contains("Unauthorized") ||
               error.localizedDescription.contains("authentication") {
                LogManager.shared.warning("OpenAIService", "API密钥无效，无法进行修改")
                throw APIError.invalidAPIKey
            }
            
            throw error
        }
    }
    
    // MARK: - 重试机制
    private func performWithRetry<T>(
        operation: String,
        maxAttempts: Int? = nil,
        block: (Int) async throws -> T
    ) async -> Result<T, APIError> {
        let attempts = maxAttempts ?? maxRetryAttempts
        var lastError: Error?
        
        for attempt in 1...attempts {
            do {
                requestCount += 1
                let startTime = CFAbsoluteTimeGetCurrent()
                
                let result = try await block(attempt)
                
                let duration = CFAbsoluteTimeGetCurrent() - startTime
                totalRequestTime += duration
                successCount += 1
                
                return .success(result)
                
            } catch {
                lastError = error
                failureCount += 1
                
                let apiError = mapToAPIError(error)
                
                LogManager.shared.apiLog(.requestError, level: .warning, details: [
                    "operation": operation,
                    "attempt": attempt,
                    "maxAttempts": attempts,
                    "error": error.localizedDescription,
                    "errorCode": apiError.errorCode
                ])
                
                // 检查是否应该重试
                if attempt < attempts && shouldRetry(error: apiError) {
                    let delay = retryStrategy.delay(for: attempt)
                    LogManager.shared.info("OpenAIService", "等待\(delay)秒后重试 (第\(attempt)次)")
                    
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    break
                }
            }
        }
        
        let finalError = mapToAPIError(lastError ?? NSError(domain: "UnknownError", code: 0))
        self.lastError = finalError
        
        return .failure(finalError)
    }
    
    private func shouldRetry(error: APIError) -> Bool {
        switch error {
        case .networkTimeout, .rateLimitExceeded, .serverError:
            return true
        case .invalidAPIKey, .quotaExceeded, .contentFiltered:
            return false
        default:
            return true
        }
    }
    
    // MARK: - 错误映射
    private func mapToAPIError(_ error: Error) -> APIError {
        if let apiError = error as? APIError {
            return apiError
        }
        
        // 根据错误类型进行映射
        let nsError = error as NSError
        
        switch nsError.code {
        case NSURLErrorTimedOut:
            return .networkTimeout
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
            return .networkTimeout
        default:
            break
        }
        
        // 检查HTTP状态码
        if let httpError = error as? URLError,
           let response = httpError.userInfo[NSURLErrorFailingURLStringErrorKey] as? HTTPURLResponse {
            switch response.statusCode {
            case 401:
                return .invalidAPIKey
            case 429:
                let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
                let delay = retryAfter.flatMap(Double.init)
                return .rateLimitExceeded(retryAfter: delay)
            case 402:
                return .quotaExceeded
            case 500...599:
                return .serverError(statusCode: response.statusCode, message: nsError.localizedDescription)
            default:
                return .invalidResponse(statusCode: response.statusCode)
            }
        }
        
        return .optimizationFailed(error)
    }
    
    // MARK: - 工具方法
    
    private func compressAudioIfNeeded(_ data: Data) throws -> Data {
        let maxSize = 25 * 1024 * 1024  // 25MB
        
        if data.count <= maxSize {
            return data
        }
        
        LogManager.shared.warning("OpenAIService", "音频文件超过25MB限制，尝试压缩")
        
        // 简化的压缩实现 - 实际项目中应使用专业音频编码
        let compressionRatio = Double(maxSize) / Double(data.count)
        let stepSize = max(1, Int(1.0 / compressionRatio))
        
        var compressedData = Data()
        compressedData.reserveCapacity(maxSize)
        
        for i in stride(from: 0, to: data.count, by: stepSize) {
            compressedData.append(data[i])
        }
        
        LogManager.shared.info("OpenAIService", "音频压缩完成: \(data.count) -> \(compressedData.count) bytes")
        
        return compressedData
    }
    
    private func generateTranscriptionPrompt(language: String?) -> String {
        let basePrompt = "以下是普通话语音内容，可能包含技术术语、专业词汇或日常对话。"
        
        guard let language = language else {
            return basePrompt
        }
        
        switch language.lowercased() {
        case "zh", "chinese":
            return basePrompt + "请准确识别中文内容。"
        case "en", "english":
            return "The following is English speech content, which may include technical terms, professional vocabulary, or casual conversation."
        default:
            return basePrompt
        }
    }
    
    private func buildOptimizationSystemPrompt(context: String?) -> String {
        let basePrompt = """
        你是一个专业的AI提示词优化专家。你的任务是将用户的口语化描述转换为清晰、具体、高效的AI提示词。
        
        优化原则：
        1. 保持用户的原始意图不变
        2. 使语言更加准确和专业
        3. 添加必要的结构和格式要求
        4. 确保提示词具有可执行性
        5. 适当添加上下文信息以提高AI理解准确性
        
        优化方向：
        - 明确任务目标和期望输出
        - 规范语言表达，去除口语化表述
        - 添加格式要求和约束条件
        - 补充必要的背景信息
        - 优化逻辑结构和条理性
        """
        
        if let context = context, !context.isEmpty {
            return basePrompt + "\n\n当前上下文：\(context)\n请根据上下文优化提示词的相关性和适用性。"
        }
        
        return basePrompt
    }
    
    private func buildOptimizationUserPrompt(originalText: String) -> String {
        return """
        请将以下口语化描述优化为专业的AI提示词：
        
        原始描述：
        \(originalText)
        
        请返回优化后的提示词，并说明主要改进点。
        
        返回格式：
        ```
        [优化后的提示词]
        
        主要改进：
        - 改进点1
        - 改进点2
        - ...
        ```
        """
    }
    
    private func parseOptimizationResult(content: String, originalText: String, processingTime: TimeInterval) -> OptimizationResult {
        // 提取优化后的提示词和改进点
        let lines = content.components(separatedBy: .newlines)
        var optimizedPrompt = ""
        var improvements: [String] = []
        var inPromptSection = false
        var inImprovementSection = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.hasPrefix("```") {
                inPromptSection.toggle()
                continue
            }
            
            if trimmedLine.contains("主要改进") || trimmedLine.contains("改进点") || trimmedLine.contains("优化") {
                inImprovementSection = true
                continue
            }
            
            if inPromptSection && !trimmedLine.isEmpty {
                if !optimizedPrompt.isEmpty {
                    optimizedPrompt += "\n"
                }
                optimizedPrompt += trimmedLine
            } else if inImprovementSection && trimmedLine.hasPrefix("-") {
                let improvement = trimmedLine.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
                if !improvement.isEmpty {
                    improvements.append(improvement)
                }
            }
        }
        
        // 如果没有找到结构化内容，使用整个响应作为优化结果
        if optimizedPrompt.isEmpty {
            optimizedPrompt = content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return OptimizationResult(
            originalText: originalText,
            optimizedText: optimizedPrompt,
            improvements: improvements,
            processingTime: processingTime
        )
    }
    
    private func parseModificationResult(content: String, originalText: String, processingTime: TimeInterval) -> OptimizationResult {
        // 解析修改结果，逻辑与优化结果类似
        return parseOptimizationResult(content: content, originalText: originalText, processingTime: processingTime)
    }
    
    // MARK: - 统计和监控
    public func getPerformanceStatistics() -> [String: Any] {
        let avgRequestTime = requestCount > 0 ? totalRequestTime / Double(requestCount) : 0.0
        let successRate = requestCount > 0 ? Double(successCount) / Double(requestCount) * 100 : 0.0
        
        return [
            "totalRequests": requestCount,
            "successCount": successCount,
            "failureCount": failureCount,
            "successRate": String(format: "%.1f%%", successRate),
            "averageRequestTime": String(format: "%.2fs", avgRequestTime),
            "totalRequestTime": String(format: "%.2fs", totalRequestTime)
        ]
    }
    
    public func resetStatistics() {
        requestCount = 0
        totalRequestTime = 0.0
        successCount = 0
        failureCount = 0
        
        LogManager.shared.info("OpenAIService", "性能统计已重置")
    }
    
    // MARK: - 取消操作
    public func cancelCurrentOperation() {
        currentTask?.cancel()
        currentTask = nil
        
        state = .idle
        isProcessing = false
        progress = 0.0
        
        LogManager.shared.info("OpenAIService", "当前操作已取消")
    }
}

// MARK: - Result扩展
extension Result {
    var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
    
    var isFailure: Bool {
        return !isSuccess
    }
}