//
//  EnhancedAPIValidator.swift
//  HelloPrompt
//
//  增强的API配置验证器 - 提供完整的OpenAI API验证和模型测试
//  包含连接测试、API密钥验证、base URL检查和模型能力测试
//

import Foundation
import SwiftUI
import OpenAI

// MARK: - API验证结果
public struct APIValidationResult {
    let isValid: Bool
    let error: APIValidationError?
    let responseTime: TimeInterval
    let supportedModels: [String]
    let accountInfo: AccountInfo?
    let timestamp: Date
    
    public struct AccountInfo {
        let organizationId: String?
        let accountName: String?
        let planType: String?
        let usageQuota: Double?
    }
}

// MARK: - API验证错误类型
public enum APIValidationError: LocalizedError, CaseIterable {
    case invalidAPIKey
    case invalidBaseURL
    case networkError
    case authenticationFailed
    case quotaExceeded
    case unsupportedModel
    case connectionTimeout
    case serverError(Int)
    case unknownError
    
    public var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "API密钥格式无效或已过期"
        case .invalidBaseURL:
            return "Base URL格式无效或无法访问"
        case .networkError:
            return "网络连接失败，请检查网络设置"
        case .authenticationFailed:
            return "身份验证失败，请检查API密钥"
        case .quotaExceeded:
            return "API使用配额已超限"
        case .unsupportedModel:
            return "选择的模型不受支持"
        case .connectionTimeout:
            return "连接超时，请稍后重试"
        case .serverError(let code):
            return "服务器错误 (HTTP \(code))"
        case .unknownError:
            return "未知错误，请联系支持"
        }
    }
    
    public var recoveryDescription: String {
        switch self {
        case .invalidAPIKey:
            return "请在 https://platform.openai.com/api-keys 获取有效的API密钥"
        case .invalidBaseURL:
            return "请检查Base URL格式，确保包含协议（http/https）"
        case .networkError:
            return "请检查网络连接并重试"
        case .authenticationFailed:
            return "请确认API密钥正确且有效"
        case .quotaExceeded:
            return "请检查OpenAI账户余额或升级计划"
        case .unsupportedModel:
            return "请选择支持的模型或升级API访问权限"
        case .connectionTimeout:
            return "请检查网络连接稳定性"
        case .serverError:
            return "请稍后重试或联系OpenAI支持"
        case .unknownError:
            return "请重启应用或联系技术支持"
        }
    }
}

// MARK: - 模型测试结果
public struct ModelTestResult {
    let modelName: String
    let isSupported: Bool
    let responseTime: TimeInterval
    let testPrompt: String
    let testResponse: String?
    let error: APIValidationError?
    let capabilities: ModelCapabilities
    
    public struct ModelCapabilities {
        let maxTokens: Int
        let supportsStreaming: Bool
        let supportsFunctions: Bool
        let contextWindow: Int
        let costPer1KTokens: Double?
    }
}

// MARK: - 增强API验证器
@MainActor
public class EnhancedAPIValidator: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var isValidating = false
    @Published public var validationProgress: Double = 0.0
    @Published public var currentValidationStep = ""
    @Published public var lastValidationResult: APIValidationResult?
    @Published public var supportedModels: [String] = []
    
    // MARK: - Private Properties
    private let logger = EnhancedLogManager.shared
    private var openAIClient: OpenAI?
    private let testTimeout: TimeInterval = 30.0
    
    // MARK: - Validation Steps
    private enum ValidationStep: String, CaseIterable {
        case apiKeyFormat = "验证API密钥格式"
        case baseURLFormat = "验证Base URL格式"
        case networkConnection = "测试网络连接"
        case authentication = "验证身份认证"
        case modelList = "获取支持的模型列表"
        case modelTesting = "测试模型能力"
        case quotaCheck = "检查使用配额"
        
        var weight: Double {
            switch self {
            case .apiKeyFormat: return 0.05
            case .baseURLFormat: return 0.05
            case .networkConnection: return 0.15
            case .authentication: return 0.20
            case .modelList: return 0.25
            case .modelTesting: return 0.20
            case .quotaCheck: return 0.10
            }
        }
    }
    
    // MARK: - Main Validation Method
    
    /// 完整的API配置验证
    public func validateAPIConfiguration(
        apiKey: String,
        baseURL: String,
        organizationId: String? = nil
    ) async -> APIValidationResult {
        
        logger.startPerformanceTracking("api_validation")
        logger.info("EnhancedAPIValidator", "🧪 开始API配置验证", metadata: [
            "base_url": baseURL,
            "has_org_id": organizationId != nil,
            "api_key_prefix": String(apiKey.prefix(8))
        ])
        
        isValidating = true
        validationProgress = 0.0
        defer { isValidating = false }
        
        let startTime = Date()
        var currentProgress: Double = 0.0
        
        // Step 1: API Key Format Validation
        currentValidationStep = ValidationStep.apiKeyFormat.rawValue
        logger.debug("EnhancedAPIValidator", "📝 Step 1: \(currentValidationStep)")
        
        if let error = validateAPIKeyFormat(apiKey) {
            let result = APIValidationResult(
                isValid: false,
                error: error,
                responseTime: Date().timeIntervalSince(startTime),
                supportedModels: [],
                accountInfo: nil,
                timestamp: Date()
            )
            logger.error("EnhancedAPIValidator", "❌ API密钥格式验证失败: \(error.localizedDescription)")
            return result
        }
        
        currentProgress += ValidationStep.apiKeyFormat.weight
        validationProgress = currentProgress
        
        // Step 2: Base URL Format Validation
        currentValidationStep = ValidationStep.baseURLFormat.rawValue
        logger.debug("EnhancedAPIValidator", "🌐 Step 2: \(currentValidationStep)")
        
        if let error = validateBaseURLFormat(baseURL) {
            let result = APIValidationResult(
                isValid: false,
                error: error,
                responseTime: Date().timeIntervalSince(startTime),
                supportedModels: [],
                accountInfo: nil,
                timestamp: Date()
            )
            logger.error("EnhancedAPIValidator", "❌ Base URL格式验证失败: \(error.localizedDescription)")
            return result
        }
        
        currentProgress += ValidationStep.baseURLFormat.weight
        validationProgress = currentProgress
        
        // Step 3: Initialize OpenAI Client
        openAIClient = createOpenAIClient(apiKey: apiKey, baseURL: baseURL, organizationId: organizationId)
        
        // Step 4: Network Connection Test
        currentValidationStep = ValidationStep.networkConnection.rawValue
        logger.debug("EnhancedAPIValidator", "🔗 Step 3: \(currentValidationStep)")
        
        if let error = await testNetworkConnection(baseURL) {
            let result = APIValidationResult(
                isValid: false,
                error: error,
                responseTime: Date().timeIntervalSince(startTime),
                supportedModels: [],
                accountInfo: nil,
                timestamp: Date()
            )
            logger.error("EnhancedAPIValidator", "❌ 网络连接测试失败: \(error.localizedDescription)")
            return result
        }
        
        currentProgress += ValidationStep.networkConnection.weight
        validationProgress = currentProgress
        
        // Step 5: Authentication Test
        currentValidationStep = ValidationStep.authentication.rawValue
        logger.debug("EnhancedAPIValidator", "🔐 Step 4: \(currentValidationStep)")
        
        if let error = await testAuthentication() {
            let result = APIValidationResult(
                isValid: false,
                error: error,
                responseTime: Date().timeIntervalSince(startTime),
                supportedModels: [],
                accountInfo: nil,
                timestamp: Date()
            )
            logger.error("EnhancedAPIValidator", "❌ 身份验证失败: \(error.localizedDescription)")
            return result
        }
        
        currentProgress += ValidationStep.authentication.weight
        validationProgress = currentProgress
        
        // Step 6: Get Supported Models
        currentValidationStep = ValidationStep.modelList.rawValue
        logger.debug("EnhancedAPIValidator", "📋 Step 5: \(currentValidationStep)")
        
        let (models, modelError) = await getSupportedModels()
        if let error = modelError {
            logger.warning("EnhancedAPIValidator", "⚠️  获取模型列表失败: \(error.localizedDescription)")
        } else {
            supportedModels = models
            logger.info("EnhancedAPIValidator", "✅ 获取到 \(models.count) 个支持的模型")
        }
        
        currentProgress += ValidationStep.modelList.weight
        validationProgress = currentProgress
        
        // Step 7: Test Model Capabilities
        currentValidationStep = ValidationStep.modelTesting.rawValue
        logger.debug("EnhancedAPIValidator", "🧠 Step 6: \(currentValidationStep)")
        
        await testModelCapabilities(models.first ?? "gpt-3.5-turbo")
        
        currentProgress += ValidationStep.modelTesting.weight
        validationProgress = currentProgress
        
        // Step 8: Check Usage Quota
        currentValidationStep = ValidationStep.quotaCheck.rawValue
        logger.debug("EnhancedAPIValidator", "💰 Step 7: \(currentValidationStep)")
        
        let accountInfo = await getAccountInfo()
        
        currentProgress += ValidationStep.quotaCheck.weight
        validationProgress = 1.0
        
        // Final Result
        let totalTime = Date().timeIntervalSince(startTime)
        logger.endPerformanceTracking("api_validation")
        
        let result = APIValidationResult(
            isValid: true,
            error: nil,
            responseTime: totalTime,
            supportedModels: models,
            accountInfo: accountInfo,
            timestamp: Date()
        )
        
        lastValidationResult = result
        
        logger.info("EnhancedAPIValidator", "🎉 API配置验证成功", metadata: [
            "validation_time": totalTime,
            "models_count": models.count,
            "has_account_info": accountInfo != nil
        ])
        
        return result
    }
    
    // MARK: - Individual Validation Methods
    
    private func validateAPIKeyFormat(_ apiKey: String) -> APIValidationError? {
        logger.debug("EnhancedAPIValidator", "🔍 验证API密钥格式")
        
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check basic format
        guard !trimmedKey.isEmpty else {
            return .invalidAPIKey
        }
        
        // OpenAI API keys should start with "sk-" and be at least 20 characters
        guard trimmedKey.hasPrefix("sk-") && trimmedKey.count >= 20 else {
            return .invalidAPIKey
        }
        
        // Check for valid characters (alphanumeric and some special chars)
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard trimmedKey.rangeOfCharacter(from: allowedCharacters.inverted) == nil else {
            return .invalidAPIKey
        }
        
        logger.debug("EnhancedAPIValidator", "✅ API密钥格式验证通过")
        return nil
    }
    
    private func validateBaseURLFormat(_ baseURL: String) -> APIValidationError? {
        logger.debug("EnhancedAPIValidator", "🔍 验证Base URL格式")
        
        let trimmedURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedURL.isEmpty else {
            return .invalidBaseURL
        }
        
        guard let url = URL(string: trimmedURL) else {
            return .invalidBaseURL
        }
        
        guard let scheme = url.scheme, ["http", "https"].contains(scheme.lowercased()) else {
            return .invalidBaseURL
        }
        
        guard let host = url.host, !host.isEmpty else {
            return .invalidBaseURL
        }
        
        logger.debug("EnhancedAPIValidator", "✅ Base URL格式验证通过: \(host)")
        return nil
    }
    
    private func createOpenAIClient(apiKey: String, baseURL: String, organizationId: String?) -> OpenAI {
        logger.debug("EnhancedAPIValidator", "🔧 创建OpenAI客户端")
        
        guard let url = URL(string: baseURL) else {
            fatalError("Invalid base URL after validation")
        }
        
        var configuration = OpenAI.Configuration(
            token: apiKey,
            host: url.host ?? "api.openai.com",
            scheme: url.scheme ?? "https",
            timeoutInterval: testTimeout
        )
        
        if let orgId = organizationId {
            configuration.organizationIdentifier = orgId
            logger.debug("EnhancedAPIValidator", "🏢 使用组织ID: \(orgId)")
        }
        
        return OpenAI(configuration: configuration)
    }
    
    private func testNetworkConnection(_ baseURL: String) async -> APIValidationError? {
        logger.debug("EnhancedAPIValidator", "🌐 测试网络连接")
        
        guard let url = URL(string: baseURL) else {
            return .invalidBaseURL
        }
        
        return await withCheckedContinuation { continuation in
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = testTimeout
            
            URLSession.shared.dataTask(with: request) { _, response, error in
                if let error = error {
                    self.logger.error("EnhancedAPIValidator", "🌐 网络连接失败: \(error.localizedDescription)")
                    
                    if error.localizedDescription.contains("timeout") {
                        continuation.resume(returning: .connectionTimeout)
                    } else {
                        continuation.resume(returning: .networkError)
                    }
                } else if let httpResponse = response as? HTTPURLResponse {
                    self.logger.debug("EnhancedAPIValidator", "🌐 网络连接测试完成，状态码: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode >= 400 {
                        continuation.resume(returning: .serverError(httpResponse.statusCode))
                    } else {
                        continuation.resume(returning: nil)
                    }
                } else {
                    continuation.resume(returning: .networkError)
                }
            }.resume()
        }
    }
    
    private func testAuthentication() async -> APIValidationError? {
        logger.debug("EnhancedAPIValidator", "🔐 测试身份验证")
        
        guard let client = openAIClient else {
            return .unknownError
        }
        
        do {
            // Use a simple models request to test authentication
            let _ = try await client.models()
            logger.debug("EnhancedAPIValidator", "✅ 身份验证成功")
            return nil
        } catch {
            logger.error("EnhancedAPIValidator", "🔐 身份验证失败: \(error.localizedDescription)")
            
            if error.localizedDescription.contains("401") || error.localizedDescription.contains("Unauthorized") {
                return .authenticationFailed
            } else if error.localizedDescription.contains("403") || error.localizedDescription.contains("quota") {
                return .quotaExceeded
            } else if error.localizedDescription.contains("timeout") {
                return .connectionTimeout
            } else {
                return .unknownError
            }
        }
    }
    
    private func getSupportedModels() async -> ([String], APIValidationError?) {
        logger.debug("EnhancedAPIValidator", "📋 获取支持的模型列表")
        
        guard let client = openAIClient else {
            return ([], .unknownError)
        }
        
        do {
            let modelsResponse = try await client.models()
            let modelNames = modelsResponse.data.map { $0.id }.sorted()
            
            logger.info("EnhancedAPIValidator", "📋 获取到模型列表: \(modelNames.joined(separator: ", "))")
            return (modelNames, nil)
        } catch {
            logger.error("EnhancedAPIValidator", "📋 获取模型列表失败: \(error.localizedDescription)")
            return ([], .networkError)
        }
    }
    
    private func testModelCapabilities(_ modelName: String) async {
        logger.debug("EnhancedAPIValidator", "🧠 测试模型能力: \(modelName)")
        
        guard let client = openAIClient else { return }
        
        let testPrompt = "Hello, this is a test message to verify the model is working correctly."
        
        do {
            let query = ChatQuery(
                messages: [
                    Chat(role: .user, content: testPrompt)
                ],
                model: .gpt3_5Turbo,
                maxTokens: 50
            )
            
            let response = try await client.chats(query: query)
            
            if let content = response.choices.first?.message.content {
                logger.info("EnhancedAPIValidator", "🧠 模型测试成功，响应: \(content.prefix(50))...")
            }
        } catch {
            logger.warning("EnhancedAPIValidator", "🧠 模型测试失败: \(error.localizedDescription)")
        }
    }
    
    private func getAccountInfo() async -> APIValidationResult.AccountInfo? {
        logger.debug("EnhancedAPIValidator", "💰 获取账户信息")
        
        // Note: OpenAI doesn't provide a direct account info endpoint
        // This would typically be implemented with billing API if available
        // For now, we'll return basic info from the client configuration
        
        return APIValidationResult.AccountInfo(
            organizationId: openAIClient?.configuration.organizationIdentifier,
            accountName: nil,
            planType: nil,
            usageQuota: nil
        )
    }
    
    // MARK: - Quick Validation Methods
    
    /// 快速API密钥验证（仅格式检查）
    public func quickValidateAPIKey(_ apiKey: String) -> Bool {
        return validateAPIKeyFormat(apiKey) == nil
    }
    
    /// 快速Base URL验证（仅格式检查）
    public func quickValidateBaseURL(_ baseURL: String) -> Bool {
        return validateBaseURLFormat(baseURL) == nil
    }
    
    /// 测试单个模型
    public func testModel(_ modelName: String, apiKey: String, baseURL: String) async -> ModelTestResult {
        logger.info("EnhancedAPIValidator", "🧪 测试单个模型: \(modelName)")
        
        let client = createOpenAIClient(apiKey: apiKey, baseURL: baseURL, organizationId: nil)
        let testPrompt = "Test prompt for model validation"
        let startTime = Date()
        
        do {
            let query = ChatQuery(
                messages: [Chat(role: .user, content: testPrompt)],
                model: .gpt3_5Turbo,
                maxTokens: 10
            )
            
            let response = try await client.chats(query: query)
            let responseTime = Date().timeIntervalSince(startTime)
            
            return ModelTestResult(
                modelName: modelName,
                isSupported: true,
                responseTime: responseTime,
                testPrompt: testPrompt,
                testResponse: response.choices.first?.message.content,
                error: nil,
                capabilities: ModelTestResult.ModelCapabilities(
                    maxTokens: 4096,
                    supportsStreaming: true,
                    supportsFunctions: true,
                    contextWindow: 4096,
                    costPer1KTokens: 0.002
                )
            )
        } catch {
            let responseTime = Date().timeIntervalSince(startTime)
            
            return ModelTestResult(
                modelName: modelName,
                isSupported: false,
                responseTime: responseTime,
                testPrompt: testPrompt,
                testResponse: nil,
                error: .unsupportedModel,
                capabilities: ModelTestResult.ModelCapabilities(
                    maxTokens: 0,
                    supportsStreaming: false,
                    supportsFunctions: false,
                    contextWindow: 0,
                    costPer1KTokens: nil
                )
            )
        }
    }
}