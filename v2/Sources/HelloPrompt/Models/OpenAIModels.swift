//
//  OpenAIModels.swift
//  HelloPrompt
//
//  OpenAI API相关的数据模型定义
//  包含请求、响应和优化结果的完整类型定义
//

import Foundation

// MARK: - API请求状态
public enum APIRequestState: String, CaseIterable {
    case idle = "空闲"
    case preparing = "准备中"
    case sending = "发送中"
    case processing = "处理中"
    case transcribing = "转录中"
    case optimizing = "优化中"
    case completed = "已完成"
    case failed = "失败"
    case cancelled = "已取消"
    
    var isActive: Bool {
        switch self {
        case .preparing, .sending, .processing, .transcribing, .optimizing:
            return true
        default:
            return false
        }
    }
    
    var canCancel: Bool {
        return isActive
    }
}

// MARK: - 转录请求
public struct TranscriptionRequest: Codable {
    public let model: String
    public let language: String?
    public let prompt: String?
    public let response_format: String?
    public let temperature: Double?
    
    public init(
        model: String = "whisper-1",
        language: String? = nil,
        prompt: String? = nil,
        response_format: String? = "json",
        temperature: Double? = nil
    ) {
        self.model = model
        self.language = language
        self.prompt = prompt
        self.response_format = response_format
        self.temperature = temperature
    }
}

// MARK: - 转录响应
public struct TranscriptionResponse: Codable {
    public let text: String
    public let language: String?
    public let duration: Double?
    public let segments: [TranscriptionSegment]?
    
    public init(text: String, language: String? = nil, duration: Double? = nil, segments: [TranscriptionSegment]? = nil) {
        self.text = text
        self.language = language
        self.duration = duration
        self.segments = segments
    }
}

// MARK: - 转录片段
public struct TranscriptionSegment: Codable {
    public let id: Int
    public let seek: Double
    public let start: Double
    public let end: Double
    public let text: String
    public let tokens: [Int]
    public let temperature: Double
    public let avg_logprob: Double
    public let compression_ratio: Double
    public let no_speech_prob: Double
    
    public init(
        id: Int,
        seek: Double,
        start: Double,
        end: Double,
        text: String,
        tokens: [Int],
        temperature: Double,
        avg_logprob: Double,
        compression_ratio: Double,
        no_speech_prob: Double
    ) {
        self.id = id
        self.seek = seek
        self.start = start
        self.end = end
        self.text = text
        self.tokens = tokens
        self.temperature = temperature
        self.avg_logprob = avg_logprob
        self.compression_ratio = compression_ratio
        self.no_speech_prob = no_speech_prob
    }
}

// MARK: - 聊天完成请求
public struct ChatCompletionRequest: Codable {
    public let model: String
    public let messages: [ChatMessage]
    public let temperature: Double?
    public let max_tokens: Int?
    public let top_p: Double?
    public let frequency_penalty: Double?
    public let presence_penalty: Double?
    public let stream: Bool?
    
    public init(
        model: String,
        messages: [ChatMessage],
        temperature: Double? = nil,
        max_tokens: Int? = nil,
        top_p: Double? = nil,
        frequency_penalty: Double? = nil,
        presence_penalty: Double? = nil,
        stream: Bool? = false
    ) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.max_tokens = max_tokens
        self.top_p = top_p
        self.frequency_penalty = frequency_penalty
        self.presence_penalty = presence_penalty
        self.stream = stream
    }
}

// MARK: - 聊天消息
public struct ChatMessage: Codable {
    public let role: String
    public let content: String
    public let name: String?
    
    public init(role: String, content: String, name: String? = nil) {
        self.role = role
        self.content = content
        self.name = name
    }
    
    // 便捷初始化方法
    public static func system(_ content: String) -> ChatMessage {
        return ChatMessage(role: "system", content: content)
    }
    
    public static func user(_ content: String) -> ChatMessage {
        return ChatMessage(role: "user", content: content)
    }
    
    public static func assistant(_ content: String) -> ChatMessage {
        return ChatMessage(role: "assistant", content: content)
    }
}

// MARK: - 聊天完成响应
public struct ChatCompletionResponse: Codable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [ChatChoice]
    public let usage: TokenUsage?
    
    public init(
        id: String,
        object: String,
        created: Int,
        model: String,
        choices: [ChatChoice],
        usage: TokenUsage?
    ) {
        self.id = id
        self.object = object
        self.created = created
        self.model = model
        self.choices = choices
        self.usage = usage
    }
}

// MARK: - 聊天选择
public struct ChatChoice: Codable {
    public let index: Int
    public let message: ChatMessage
    public let finish_reason: String?
    
    public init(index: Int, message: ChatMessage, finish_reason: String?) {
        self.index = index
        self.message = message
        self.finish_reason = finish_reason
    }
}

// MARK: - Token使用情况
public struct TokenUsage: Codable {
    public let prompt_tokens: Int
    public let completion_tokens: Int
    public let total_tokens: Int
    
    public init(prompt_tokens: Int, completion_tokens: Int, total_tokens: Int) {
        self.prompt_tokens = prompt_tokens
        self.completion_tokens = completion_tokens
        self.total_tokens = total_tokens
    }
}

// MARK: - 优化结果
public struct OptimizationResult {
    public let originalText: String
    public let optimizedText: String
    public let improvements: [String]
    public let confidence: Double
    public let processingTime: TimeInterval
    public let tokenUsage: TokenUsage?
    public let metadata: [String: Any]
    
    // 为了兼容性，提供optimizedPrompt别名
    public var optimizedPrompt: String {
        return optimizedText
    }
    
    public init(
        originalText: String,
        optimizedText: String,
        improvements: [String] = [],
        confidence: Double = 1.0,
        processingTime: TimeInterval = 0,
        tokenUsage: TokenUsage? = nil,
        metadata: [String: Any] = [:]
    ) {
        self.originalText = originalText
        self.optimizedText = optimizedText
        self.improvements = improvements
        self.confidence = confidence
        self.processingTime = processingTime
        self.tokenUsage = tokenUsage
        self.metadata = metadata
    }
    
    // 计算改进程度
    public var improvementRatio: Double {
        guard originalText.count > 0 else { return 0 }
        return Double(optimizedText.count) / Double(originalText.count)
    }
    
    // 是否有显著改进
    public var hasSignificantImprovement: Bool {
        return !improvements.isEmpty && confidence > 0.7
    }
}

// MARK: - API错误响应
public struct APIErrorResponse: Codable {
    public let error: APIErrorDetail
    
    public init(error: APIErrorDetail) {
        self.error = error
    }
}

public struct APIErrorDetail: Codable {
    public let message: String
    public let type: String?
    public let param: String?
    public let code: String?
    
    public init(message: String, type: String? = nil, param: String? = nil, code: String? = nil) {
        self.message = message
        self.type = type
        self.param = param
        self.code = code
    }
}

// MARK: - 请求进度
public struct RequestProgress {
    public let stage: RequestStage
    public let progress: Double // 0.0 - 1.0
    public let message: String
    public let startTime: Date
    public let estimatedCompletion: Date?
    
    public init(
        stage: RequestStage,
        progress: Double,
        message: String,
        startTime: Date = Date(),
        estimatedCompletion: Date? = nil
    ) {
        self.stage = stage
        self.progress = max(0.0, min(1.0, progress))
        self.message = message
        self.startTime = startTime
        self.estimatedCompletion = estimatedCompletion
    }
    
    public enum RequestStage: String, CaseIterable {
        case preparing = "准备请求"
        case uploading = "上传音频"
        case transcribing = "语音识别"
        case optimizing = "优化提示词"
        case completing = "完成处理"
        
        var estimatedDuration: TimeInterval {
            switch self {
            case .preparing: return 0.5
            case .uploading: return 2.0
            case .transcribing: return 5.0
            case .optimizing: return 3.0
            case .completing: return 0.5
            }
        }
    }
}

// MARK: - 模型信息
public struct ModelInfo: Codable {
    public let id: String
    public let object: String
    public let created: Int
    public let owned_by: String
    public let permission: [ModelPermission]?
    
    public init(
        id: String,
        object: String,
        created: Int,
        owned_by: String,
        permission: [ModelPermission]? = nil
    ) {
        self.id = id
        self.object = object
        self.created = created
        self.owned_by = owned_by
        self.permission = permission
    }
}

public struct ModelPermission: Codable {
    public let id: String
    public let object: String
    public let created: Int
    public let allow_create_engine: Bool
    public let allow_sampling: Bool
    public let allow_logprobs: Bool
    public let allow_search_indices: Bool
    public let allow_view: Bool
    public let allow_fine_tuning: Bool
    public let organization: String
    public let group: String?
    public let is_blocking: Bool
    
    public init(
        id: String,
        object: String,
        created: Int,
        allow_create_engine: Bool,
        allow_sampling: Bool,
        allow_logprobs: Bool,
        allow_search_indices: Bool,
        allow_view: Bool,
        allow_fine_tuning: Bool,
        organization: String,
        group: String?,
        is_blocking: Bool
    ) {
        self.id = id
        self.object = object
        self.created = created
        self.allow_create_engine = allow_create_engine
        self.allow_sampling = allow_sampling
        self.allow_logprobs = allow_logprobs
        self.allow_search_indices = allow_search_indices
        self.allow_view = allow_view
        self.allow_fine_tuning = allow_fine_tuning
        self.organization = organization
        self.group = group
        self.is_blocking = is_blocking
    }
}

// MARK: - 扩展便捷方法
extension OptimizationResult {
    /// 创建失败的优化结果
    public static func failure(originalText: String, error: Error) -> OptimizationResult {
        return OptimizationResult(
            originalText: originalText,
            optimizedText: originalText,
            improvements: ["优化失败: \(error.localizedDescription)"],
            confidence: 0.0,
            metadata: ["error": error.localizedDescription]
        )
    }
    
    /// 创建无改进的结果
    public static func noImprovement(text: String) -> OptimizationResult {
        return OptimizationResult(
            originalText: text,
            optimizedText: text,
            improvements: ["文本已经足够清晰，无需优化"],
            confidence: 1.0
        )
    }
}