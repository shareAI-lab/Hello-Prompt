//
//  OpenAIService.swift
//  HelloPrompt
//
//  OpenAI API服务 - 实现Whisper语音识别和GPT-4提示词优化
//  Copyright © 2025 HelloPrompt. All rights reserved.
//

import Foundation

// MARK: - OpenAI配置
struct OpenAIConfig {
    var apiKey: String
    var baseURL: String
    var whisperModel: String
    var gptModel: String
    var maxTokens: Int = 4096
    var temperature: Double = 0.3
    var timeout: TimeInterval = 30.0
    
    // 从配置管理器创建
    static func fromConfiguration(_ config: AppConfiguration) -> OpenAIConfig {
        return OpenAIConfig(
            apiKey: config.openAIAPIKey,
            baseURL: config.openAIBaseURL,
            whisperModel: config.whisperModel,
            gptModel: config.gptModel
        )
    }
}

// MARK: - 语音识别结果
struct TranscriptionResult {
    let text: String
    let language: String?
    let confidence: Double?
    let duration: TimeInterval
    let segments: [TranscriptionSegment]?
}

struct TranscriptionSegment {
    let text: String
    let start: TimeInterval
    let end: TimeInterval
    let confidence: Double?
}

// MARK: - 提示词优化结果
struct PromptOptimizationResult {
    let optimizedPrompt: String
    let originalLength: Int
    let optimizedLength: Int
    let improvements: [String]
    let context: String
    let confidence: Double
}

// MARK: - API测试结果
struct APITestResult {
    let success: Bool
    let message: String
    let responseTime: TimeInterval
    let statusCode: Int
    let model: String
}

// MARK: - API响应结构
private struct WhisperResponse: Codable {
    let text: String
    let language: String?
    let duration: Double?
    let segments: [WhisperSegment]?
}

private struct WhisperSegment: Codable {
    let text: String
    let start: Double
    let end: Double
    let avg_logprob: Double?
}

private struct ChatResponse: Codable {
    let choices: [ChatChoice]
    let usage: Usage?
}

private struct ChatChoice: Codable {
    let message: ChatMessage
    let finish_reason: String?
}

private struct ChatMessage: Codable {
    let role: String
    let content: String
}

private struct Usage: Codable {
    let prompt_tokens: Int
    let completion_tokens: Int
    let total_tokens: Int
}

// MARK: - OpenAI服务协议
@MainActor
protocol OpenAIServiceDelegate: AnyObject {
    func openAIService(_ service: OpenAIService, didStartTranscription requestId: String)
    func openAIService(_ service: OpenAIService, didCompleteTranscription result: TranscriptionResult, requestId: String)
    func openAIService(_ service: OpenAIService, didStartOptimization requestId: String)
    func openAIService(_ service: OpenAIService, didCompleteOptimization result: PromptOptimizationResult, requestId: String)
    func openAIService(_ service: OpenAIService, didFailWithError error: Error, requestId: String)
}

// MARK: - OpenAI服务主类
@MainActor
class OpenAIService {
    
    // MARK: - Properties
    weak var delegate: OpenAIServiceDelegate?
    
    private var config: OpenAIConfig
    private let urlSession: URLSession
    private var activeRequests: Set<String> = []
    
    // MARK: - Initialization
    init(config: OpenAIConfig) {
        self.config = config
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = config.timeout
        configuration.timeoutIntervalForResource = config.timeout * 2
        self.urlSession = URLSession(configuration: configuration)
        
        LogManager.shared.info(.openai, "OpenAIService初始化完成", metadata: [
            "baseURL": config.baseURL,
            "whisperModel": config.whisperModel,
            "gptModel": config.gptModel,
            "timeout": config.timeout,
            "hasAPIKey": !config.apiKey.isEmpty
        ])
    }
    
    /// 便利初始化方法，从配置管理器创建
    convenience init(configurationManager: ConfigurationManager = .shared) {
        let config = OpenAIConfig.fromConfiguration(configurationManager.configuration)
        self.init(config: config)
    }
    
    // MARK: - Public Methods
    
    /// 更新配置
    func updateConfig(_ newConfig: OpenAIConfig) {
        self.config = newConfig
        LogManager.shared.apiLog("配置更新", details: [
            "whisperModel": newConfig.whisperModel,
            "gptModel": newConfig.gptModel,
            "temperature": newConfig.temperature
        ])
    }
    
    /// 测试API连接
    func testConnection() async throws -> APITestResult {
        let startTime = Date()
        
        LogManager.shared.apiLog("开始API连接测试", details: [
            "baseURL": config.baseURL,
            "whisperModel": config.whisperModel,
            "gptModel": config.gptModel
        ])
        
        // 构建一个简单的chat completion请求来测试连接
        guard let url = URL(string: "\(config.baseURL)/chat/completions") else {
            let result = APITestResult(
                success: false,
                message: "无效的API基础URL: \(config.baseURL)",
                responseTime: 0,
                statusCode: 0,
                model: config.gptModel
            )
            LogManager.shared.error(.openai, "无效的API基础URL", metadata: ["baseURL": config.baseURL])
            return result
        }
        
        let testMessage: [String: Any] = [
            "model": config.gptModel,
            "messages": [
                ["role": "user", "content": "Hello, test connection"]
            ],
            "max_tokens": 5,
            "temperature": 0
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: testMessage)
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            let duration = Date().timeIntervalSince(startTime)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAIServiceError.invalidResponse
            }
            
            LogManager.shared.networkLog(url.absoluteString, method: "POST", statusCode: httpResponse.statusCode, duration: duration)
            
            let result: APITestResult
            
            switch httpResponse.statusCode {
            case 200:
                // 成功响应，解析响应检查是否有效
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   !choices.isEmpty {
                    result = APITestResult(
                        success: true,
                        message: "API连接成功，响应正常",
                        responseTime: duration,
                        statusCode: httpResponse.statusCode,
                        model: config.gptModel
                    )
                } else {
                    result = APITestResult(
                        success: false,
                        message: "API响应格式异常",
                        responseTime: duration,
                        statusCode: httpResponse.statusCode,
                        model: config.gptModel
                    )
                }
                
            case 401:
                result = APITestResult(
                    success: false,
                    message: "API密钥无效或过期",
                    responseTime: duration,
                    statusCode: httpResponse.statusCode,
                    model: config.gptModel
                )
                
            case 429:
                result = APITestResult(
                    success: false,  
                    message: "API调用频率超限，请稍后重试",
                    responseTime: duration,
                    statusCode: httpResponse.statusCode,
                    model: config.gptModel
                )
                
            case 403:
                result = APITestResult(
                    success: false,
                    message: "API权限不足或被拒绝",
                    responseTime: duration,
                    statusCode: httpResponse.statusCode,
                    model: config.gptModel
                )
                
            case 404:
                result = APITestResult(
                    success: false,
                    message: "API端点不存在，请检查Base URL",
                    responseTime: duration,
                    statusCode: httpResponse.statusCode,
                    model: config.gptModel
                )
                
            case 500...599:
                result = APITestResult(
                    success: false,
                    message: "服务器内部错误，请稍后重试",
                    responseTime: duration,
                    statusCode: httpResponse.statusCode,
                    model: config.gptModel
                )
                
            default:
                let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
                result = APITestResult(
                    success: false,
                    message: "API请求失败: \(errorMessage)",
                    responseTime: duration,
                    statusCode: httpResponse.statusCode,
                    model: config.gptModel
                )
            }
            
            LogManager.shared.apiLog("API连接测试完成", details: [
                "success": result.success,
                "statusCode": result.statusCode,
                "responseTime": String(format: "%.3fs", result.responseTime),
                "message": result.message
            ])
            
            return result
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            
            let result = APITestResult(
                success: false,
                message: "网络连接失败: \(error.localizedDescription)",
                responseTime: duration,
                statusCode: 0,
                model: config.gptModel
            )
            
            LogManager.shared.trackError(error, context: "API连接测试", recoveryAction: "检查网络连接和防火墙设置")
            
            return result
        }
    }
    
    /// 语音转文字
    func transcribeAudio(_ audioData: AudioData) async {
        let requestId = UUID().uuidString
        activeRequests.insert(requestId)
        
        LogManager.shared.apiLog("开始语音识别", details: [
            "requestId": requestId,
            "audioSize": "\(audioData.data.count) bytes",
            "duration": String(format: "%.2fs", audioData.duration),
            "model": config.whisperModel
        ])
        
        delegate?.openAIService(self, didStartTranscription: requestId)
        
        do {
            let result = try await performTranscription(audioData, requestId: requestId)
            
            LogManager.shared.apiLog("语音识别完成", details: [
                "requestId": requestId,
                "textLength": result.text.count,
                "language": result.language ?? "unknown",
                "confidence": result.confidence ?? 0
            ])
            
            delegate?.openAIService(self, didCompleteTranscription: result, requestId: requestId)
            
        } catch {
            LogManager.shared.trackError(error, context: "语音识别", recoveryAction: "检查网络连接和API密钥")
            delegate?.openAIService(self, didFailWithError: error, requestId: requestId)
        }
        
        activeRequests.remove(requestId)
    }
    
    /// 优化提示词
    func optimizePrompt(_ text: String, context: String = "general") async {
        let requestId = UUID().uuidString
        activeRequests.insert(requestId)
        
        LogManager.shared.apiLog("开始提示词优化", details: [
            "requestId": requestId,
            "originalLength": text.count,
            "context": context,
            "model": config.gptModel
        ])
        
        delegate?.openAIService(self, didStartOptimization: requestId)
        
        do {
            let result = try await performOptimization(text, context: context, requestId: requestId)
            
            LogManager.shared.apiLog("提示词优化完成", details: [
                "requestId": requestId,
                "originalLength": result.originalLength,
                "optimizedLength": result.optimizedLength,
                "improvements": result.improvements.count,
                "confidence": result.confidence
            ])
            
            delegate?.openAIService(self, didCompleteOptimization: result, requestId: requestId)
            
        } catch {
            LogManager.shared.trackError(error, context: "提示词优化", recoveryAction: "检查网络连接和API配额")
            delegate?.openAIService(self, didFailWithError: error, requestId: requestId)
        }
        
        activeRequests.remove(requestId)
    }
    
    /// 取消所有请求
    func cancelAllRequests() {
        urlSession.invalidateAndCancel()
        activeRequests.removeAll()
        LogManager.shared.apiLog("取消所有API请求", details: ["cancelledCount": activeRequests.count])
    }
    
    // MARK: - Private Methods
    
    /// 执行语音识别
    private func performTranscription(_ audioData: AudioData, requestId: String) async throws -> TranscriptionResult {
        guard let url = URL(string: "\(config.baseURL)/audio/transcriptions") else {
            LogManager.shared.error(.openai, "无效的API基础URL", metadata: [
                "baseURL": config.baseURL,
                "endpoint": "/audio/transcriptions"
            ])
            throw OpenAIServiceError.invalidResponse
        }
        
        // 创建multipart/form-data请求
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // 构建请求体
        var body = Data()
        
        // 音频文件
        guard let boundaryData = "--\(boundary)\r\n".data(using: .utf8),
              let dispositionData = "Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8),
              let contentTypeData = "Content-Type: audio/wav\r\n\r\n".data(using: .utf8) else {
            LogManager.shared.error(.openai, "无法创建multipart数据")
            throw OpenAIServiceError.invalidResponse
        }
        body.append(boundaryData)
        body.append(dispositionData)
        body.append(contentTypeData)
        body.append(createWAVData(from: audioData))
        guard let newlineData = "\r\n".data(using: .utf8) else {
            throw OpenAIServiceError.invalidResponse
        }
        body.append(newlineData)
        
        // 模型参数
        guard let modelBoundary = "--\(boundary)\r\n".data(using: .utf8),
              let modelDisposition = "Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8),
              let modelData = config.whisperModel.data(using: .utf8) else {
            throw OpenAIServiceError.invalidResponse
        }
        body.append(modelBoundary)
        body.append(modelDisposition)
        body.append(modelData)
        body.append(newlineData)
        
        // 响应格式
        guard let formatBoundary = "--\(boundary)\r\n".data(using: .utf8),
              let formatDisposition = "Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8),
              let verboseJsonData = "verbose_json".data(using: .utf8) else {
            throw OpenAIServiceError.invalidResponse
        }
        body.append(formatBoundary)
        body.append(formatDisposition)
        body.append(verboseJsonData)
        body.append(newlineData)
        
        // 语言（可选）
        guard let langBoundary = "--\(boundary)\r\n".data(using: .utf8),
              let langDisposition = "Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8),
              let zhData = "zh".data(using: .utf8),
              let endBoundary = "--\(boundary)--\r\n".data(using: .utf8) else {
            throw OpenAIServiceError.invalidResponse
        }
        body.append(langBoundary)
        body.append(langDisposition)
        body.append(zhData)
        body.append(newlineData)
        
        body.append(endBoundary)
        
        request.httpBody = body
        
        let startTime = Date()
        
        LogManager.shared.networkLog(url.absoluteString, method: "POST", duration: nil)
        
        let (data, response) = try await urlSession.data(for: request)
        let duration = Date().timeIntervalSince(startTime)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIServiceError.invalidResponse
        }
        
        LogManager.shared.networkLog(url.absoluteString, method: "POST", statusCode: httpResponse.statusCode, duration: duration)
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            LogManager.shared.error(.openai, "API请求失败", metadata: [
                "statusCode": httpResponse.statusCode,
                "error": errorMessage
            ])
            throw OpenAIServiceError.apiError(httpResponse.statusCode, errorMessage)
        }
        
        let whisperResponse = try JSONDecoder().decode(WhisperResponse.self, from: data)
        
        // 转换响应格式
        let segments = whisperResponse.segments?.map { segment in
            TranscriptionSegment(
                text: segment.text,
                start: segment.start,
                end: segment.end,
                confidence: segment.avg_logprob.map { exp($0) }
            )
        }
        
        // 计算平均置信度
        let avgConfidence: Double?
        if let segments = segments, !segments.isEmpty {
            let confidences = segments.compactMap { $0.confidence }
            if !confidences.isEmpty {
                let sum = confidences.reduce(0, +)
                avgConfidence = sum / Double(confidences.count)
            } else {
                avgConfidence = nil
            }
        } else {
            avgConfidence = nil
        }
        
        let result = TranscriptionResult(
            text: whisperResponse.text,
            language: whisperResponse.language,
            confidence: avgConfidence,
            duration: duration,
            segments: segments
        )
        
        // 验证转录结果
        try validateTranscriptionResult(result)
        
        return result
    }
    
    /// 验证转录结果
    private func validateTranscriptionResult(_ result: TranscriptionResult) throws {
        let trimmedText = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 检查是否为空文本
        guard !trimmedText.isEmpty else {
            LogManager.shared.warning(.openai, "转录结果为空", metadata: [
                "audioDuration": result.duration,
                "language": result.language ?? "unknown"
            ])
            throw OpenAIServiceError.emptyTranscription
        }
        
        // 检查文本长度是否过短（可能是噪音）
        guard trimmedText.count >= 2 else {
            LogManager.shared.warning(.openai, "转录结果过短", metadata: [
                "textLength": trimmedText.count,
                "text": trimmedText,
                "audioDuration": result.duration
            ])
            throw OpenAIServiceError.invalidTranscription
        }
        
        // 检查置信度（如果可用）
        if let confidence = result.confidence {
            let minConfidence = 0.3  // 最小可接受置信度
            guard confidence >= minConfidence else {
                LogManager.shared.warning(.openai, "转录置信度过低", metadata: [
                    "confidence": confidence,
                    "minConfidence": minConfidence,
                    "text": trimmedText
                ])
                throw OpenAIServiceError.lowConfidence
            }
        }
        
        // 检查文本质量（过滤常见的错误识别结果）
        let lowQualityPatterns = [
            "谢谢", "Thank you", "thanks", "bye", "嗯", "啊", "哦", "呃",
            ".", "。", "?", "？", "!", "！"
        ]
        
        if lowQualityPatterns.contains(where: { trimmedText.lowercased().contains($0.lowercased()) }) &&
           trimmedText.count <= 10 {
            LogManager.shared.warning(.openai, "检测到低质量转录结果", metadata: [
                "text": trimmedText,
                "textLength": trimmedText.count
            ])
            throw OpenAIServiceError.lowQualityTranscription
        }
        
        LogManager.shared.info(.openai, "转录结果验证通过", metadata: [
            "textLength": trimmedText.count,
            "confidence": result.confidence ?? 0,
            "language": result.language ?? "unknown"
        ])
    }
    
    /// 执行提示词优化
    private func performOptimization(_ text: String, context: String, requestId: String) async throws -> PromptOptimizationResult {
        guard let url = URL(string: "\(config.baseURL)/chat/completions") else {
            LogManager.shared.error(.openai, "无效的API基础URL", metadata: [
                "baseURL": config.baseURL,
                "endpoint": "/chat/completions"
            ])
            throw OpenAIServiceError.invalidResponse
        }
        
        let systemPrompt = buildOptimizationSystemPrompt(context: context)
        let userPrompt = "请优化以下提示词，使其更清晰、具体和有效：\n\n\(text)"
        
        let requestBody: [String: Any] = [
            "model": config.gptModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "max_tokens": config.maxTokens,
            "temperature": config.temperature,
            "response_format": ["type": "json_object"]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let startTime = Date()
        
        LogManager.shared.networkLog(url.absoluteString, method: "POST", duration: nil)
        
        let (data, response) = try await urlSession.data(for: request)
        let duration = Date().timeIntervalSince(startTime)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIServiceError.invalidResponse
        }
        
        LogManager.shared.networkLog(url.absoluteString, method: "POST", statusCode: httpResponse.statusCode, duration: duration)
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OpenAIServiceError.apiError(httpResponse.statusCode, errorMessage)
        }
        
        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
        
        guard let content = chatResponse.choices.first?.message.content else {
            throw OpenAIServiceError.emptyResponse
        }
        
        // 解析JSON响应
        guard let jsonData = content.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw OpenAIServiceError.invalidJsonResponse
        }
        
        let optimizedPrompt = json["optimized_prompt"] as? String ?? text
        let improvements = json["improvements"] as? [String] ?? []
        let confidence = json["confidence"] as? Double ?? 0.8
        
        return PromptOptimizationResult(
            optimizedPrompt: optimizedPrompt,
            originalLength: text.count,
            optimizedLength: optimizedPrompt.count,
            improvements: improvements,
            context: context,
            confidence: confidence
        )
    }
    
    /// 构建优化系统提示词
    private func buildOptimizationSystemPrompt(context: String) -> String {
        let basePrompt = """
        你是一个专业的提示词优化专家。你的任务是优化用户提供的提示词，使其更加清晰、具体和有效。
        
        优化原则：
        1. 明确性：确保指令清晰明确，避免歧义
        2. 具体性：提供具体的要求和约束
        3. 结构性：使用适当的格式和结构
        4. 完整性：包含所有必要的信息
        5. 可执行性：确保AI能够理解和执行
        
        请以JSON格式返回结果：
        {
          "optimized_prompt": "优化后的提示词",
          "improvements": ["改进点1", "改进点2", "..."],
          "confidence": 0.95
        }
        """
        
        let contextSpecific: String
        switch context.lowercased() {
        case "development", "coding":
            contextSpecific = "\n\n特别注意：这是编程开发相关的提示词，请优化为更适合代码生成和技术问题的格式。"
        case "creative", "writing":
            contextSpecific = "\n\n特别注意：这是创意写作相关的提示词，请优化为更适合创意表达的格式。"
        case "analysis", "research":
            contextSpecific = "\n\n特别注意：这是分析研究相关的提示词，请优化为更适合数据分析和研究的格式。"
        default:
            contextSpecific = ""
        }
        
        return basePrompt + contextSpecific
    }
    
    /// 创建WAV音频数据
    private func createWAVData(from audioData: AudioData) -> Data {
        // 简化的WAV头部创建
        // 在实际应用中需要根据音频格式正确构建WAV头部
        let sampleRate = UInt32(audioData.sampleRate)
        let channels = UInt16(audioData.channels)
        let bitsPerSample: UInt16 = 16
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample) / 8
        let blockAlign = channels * bitsPerSample / 8
        let dataSize = UInt32(audioData.data.count)
        let fileSize = 36 + dataSize
        
        var wavData = Data()
        
        // RIFF header
        guard let riffData = "RIFF".data(using: .utf8),
              let waveData = "WAVE".data(using: .utf8),
              let fmtData = "fmt ".data(using: .utf8) else {
            LogManager.shared.error(.openai, "无法创建WAV头部数据")
            return audioData.data // 返回原始数据作为降级
        }
        
        wavData.append(riffData)
        wavData.append(withUnsafeBytes(of: fileSize.littleEndian) { Data($0) })
        wavData.append(waveData)
        
        // fmt chunk
        wavData.append(fmtData)
        wavData.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: channels.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
        
        // data chunk
        guard let dataChunkData = "data".data(using: .utf8) else {
            LogManager.shared.error(.openai, "无法创建WAV data chunk")
            return audioData.data // 返回原始数据作为降级
        }
        
        wavData.append(dataChunkData)
        wavData.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
        wavData.append(audioData.data)
        
        return wavData
    }
}

// MARK: - OpenAI服务错误类型
enum OpenAIServiceError: LocalizedError {
    case invalidAPIKey
    case invalidResponse
    case apiError(Int, String)
    case networkError
    case emptyResponse
    case invalidJsonResponse
    case rateLimitExceeded
    case quotaExceeded
    case emptyTranscription
    case invalidTranscription
    case lowConfidence
    case lowQualityTranscription
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "无效的API密钥"
        case .invalidResponse:
            return "无效的服务器响应"
        case .apiError(let code, let message):
            return "API错误 (\(code)): \(message)"
        case .networkError:
            return "网络连接错误"
        case .emptyResponse:
            return "服务器返回空响应"
        case .invalidJsonResponse:
            return "无效的JSON响应格式"
        case .rateLimitExceeded:
            return "API调用频率超限"
        case .quotaExceeded:
            return "API配额已用完"
        case .emptyTranscription:
            return "语音转录结果为空，请重新录制"
        case .invalidTranscription:
            return "语音转录结果无效，请重新录制"
        case .lowConfidence:
            return "语音识别置信度过低，请在安静环境重新录制"
        case .lowQualityTranscription:
            return "检测到低质量录音，请重新录制"
        }
    }
}