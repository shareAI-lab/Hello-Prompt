//
//  ErrorHandlerExample.swift
//  Hello-Prompt
//
//  Created by Bai Cai on 26/7/2025.
//

import Foundation
import SwiftUI

// MARK: - 使用示例和最佳实践

/// 示例音频服务 - 展示如何在服务层使用错误处理
/// 注意：这是示例代码，实际应用应使用 Services/AudioService.swift 中的实现
public class ExampleAudioService: ObservableObject {
    private let errorHandler = ErrorHandler.shared
    private let logger = LogManager.shared
    
    @Published public var isRecording = false
    @Published public var isPlaying = false
    
    public init() {}
    
    /// 开始录音 - 展示错误处理的完整流程
    public func startRecording() async {
        logger.info("ExampleAudioService", "Starting audio recording")
        
        do {
            // 检查权限
            guard await checkMicrophonePermission() else {
                throw AudioSystemError.microphonePermissionDenied
            }
            
            // 检查设备
            guard await checkAudioDevice() else {
                throw AudioSystemError.audioDeviceNotFound
            }
            
            // 配置音频会话
            try await configureAudioSession()
            
            // 开始录音
            try await performRecording()
            
            await MainActor.run {
                isRecording = true
            }
            
            logger.info("ExampleAudioService", "Audio recording started successfully")
            
        } catch let error as HelloPromptError {
            // 处理自定义错误
            await errorHandler.handle(error, context: "ExampleAudioService.startRecording")
        } catch {
            // 处理系统错误
            let wrappedError = AudioSystemError.audioEngineFailure(error)
            await errorHandler.handle(wrappedError, context: "ExampleAudioService.startRecording")
        }
    }
    
    /// 停止录音
    public func stopRecording() async {
        logger.info("ExampleAudioService", "Stopping audio recording")
        
        do {
            try await performStopRecording()
            
            await MainActor.run {
                isRecording = false
            }
            
            logger.info("ExampleAudioService", "Audio recording stopped successfully")
            
        } catch {
            let wrappedError = AudioSystemError.audioEngineFailure(error)
            await errorHandler.handle(wrappedError, context: "ExampleAudioService.stopRecording")
        }
    }
    
    /// 播放音频
    public func playAudio(url: URL) async {
        logger.info("ExampleAudioService", "Starting audio playback for: \(url.lastPathComponent)")
        
        do {
            // 检查文件格式
            let format = url.pathExtension.lowercased()
            guard ["mp3", "wav", "m4a"].contains(format) else {
                throw AudioSystemError.audioFormatNotSupported
            }
            
            // 开始播放
            try await performPlayback(url: url)
            
            await MainActor.run {
                isPlaying = true
            }
            
            logger.info("ExampleAudioService", "Audio playback started successfully")
            
        } catch let error as HelloPromptError {
            await errorHandler.handle(error, context: "ExampleAudioService.playAudio")
        } catch {
            let wrappedError = AudioSystemError.audioEngineFailure(error)
            await errorHandler.handle(wrappedError, context: "ExampleAudioService.playAudio")
        }
    }
    
    // MARK: - Private Methods (模拟实现)
    
    private func checkMicrophonePermission() async -> Bool {
        // 模拟权限检查
        return Bool.random()
    }
    
    private func checkAudioDevice() async -> Bool {
        // 模拟设备检查
        return Bool.random()
    }
    
    private func configureAudioSession() async throws {
        // 模拟配置失败
        if Bool.random() {
            throw NSError(domain: "AudioSession", code: 1001, userInfo: [
                NSLocalizedDescriptionKey: "Failed to configure audio session"
            ])
        }
    }
    
    private func performRecording() async throws {
        // 模拟录音过程
        if Bool.random() {
            throw NSError(domain: "Recording", code: 2001, userInfo: [
                NSLocalizedDescriptionKey: "Recording hardware error"
            ])
        }
    }
    
    private func performStopRecording() async throws {
        // 模拟停止录音
    }
    
    private func performPlayback(url: URL) async throws {
        // 模拟播放过程
        if Bool.random() {
            throw NSError(domain: "Playback", code: 3001, userInfo: [
                NSLocalizedDescriptionKey: "Playback codec error"
            ])
        }
    }
}

/// 网络服务示例 - 展示API错误处理
public class NetworkService: ObservableObject {
    private let errorHandler = ErrorHandler.shared
    private let logger = LogManager.shared
    
    public init() {}
    
    /// 发送请求 - 展示网络错误处理
    public func sendRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        responseType: T.Type
    ) async throws -> T {
        logger.info("NetworkService", "Sending \(method.rawValue) request to: \(endpoint)")
        
        do {
            // 检查网络连接
            guard await checkNetworkAvailability() else {
                throw APIError.networkTimeout
            }
            
            // 构建请求
            let request = try buildRequest(endpoint: endpoint, method: method, body: body)
            
            // 发送请求
            let (data, response) = try await performRequest(request)
            
            // 处理响应
            try validateResponse(response)
            
            // 解析数据
            let result = try parseResponse(data: data, responseType: responseType)
            
            logger.info("NetworkService", "Request completed successfully: \(endpoint)")
            return result
            
        } catch let error as HelloPromptError {
            // 直接抛出自定义错误，让调用者决定是否处理
            throw error
        } catch {
            // 包装系统错误
            let wrappedError = APIError.serverError(statusCode: -1, message: error.localizedDescription)
            throw wrappedError
        }
    }
    
    // MARK: - Private Methods (模拟实现)
    
    private func checkNetworkAvailability() async -> Bool {
        // 模拟网络检查
        return Bool.random()
    }
    
    private func buildRequest(endpoint: String, method: HTTPMethod, body: Data?) throws -> URLRequest {
        guard let url = URL(string: endpoint) else {
            throw APIError.invalidResponse(statusCode: 400)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        
        return request
    }
    
    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        // 模拟网络请求
        if Bool.random() {
            throw APIError.networkTimeout
        }
        
        if Bool.random() {
            throw APIError.rateLimitExceeded(retryAfter: 30)
        }
        
        // 返回模拟数据
        let data = Data()
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        return (data, response)
    }
    
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse(statusCode: 0)
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw APIError.invalidAPIKey
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init) ?? 60
            throw APIError.rateLimitExceeded(retryAfter: retryAfter)
        case 500...599:
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Server Error")
        default:
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Unknown Error")
        }
    }
    
    private func parseResponse<T: Codable>(data: Data, responseType: T.Type) throws -> T {
        do {
            return try JSONDecoder().decode(responseType, from: data)
        } catch {
            throw APIError.transcriptionEmpty
        }
    }
}

/// HTTP方法枚举
public enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

/// UI控制器示例 - 展示UI错误处理
public class ViewController: ObservableObject {
    private let audioService = ExampleAudioService()
    private let networkService = NetworkService()
    private let errorHandler = ErrorHandler.shared
    private let logger = LogManager.shared
    
    @Published public var isLoading = false
    @Published public var statusMessage = ""
    
    public init() {}
    
    /// 加载数据 - 展示UI层错误处理
    public func loadData() {
        Task {
            await MainActor.run {
                isLoading = true
                statusMessage = "加载中..."
            }
            
            do {
                // 模拟加载配置
                try await loadConfiguration()
                
                // 模拟加载用户数据
                let _: UserData = try await networkService.sendRequest(
                    endpoint: "https://api.example.com/user",
                    responseType: UserData.self
                )
                
                await MainActor.run {
                    statusMessage = "加载完成"
                    isLoading = false
                }
                
                logger.info("ViewController", "Data loaded successfully")
                
            } catch let error as HelloPromptError {
                // 处理自定义错误 - 错误处理器会自动显示给用户
                await errorHandler.handle(error)
                
                await MainActor.run {
                    statusMessage = "加载失败"
                    isLoading = false
                }
                
            } catch {
                // 处理其他错误
                let uiError = UIError.windowCreationFailed
                await errorHandler.handle(uiError, context: "ViewController.loadData")
                
                await MainActor.run {
                    statusMessage = "加载失败"
                    isLoading = false
                }
            }
        }
    }
    
    /// 开始录音 - 展示用户操作错误处理
    public func startRecording() {
        Task {
            await audioService.startRecording()
        }
    }
    
    /// 重试操作 - 展示错误恢复
    public func retryOperation() {
        logger.info("ViewController", "User requested retry operation")
        loadData()
    }
    
    // MARK: - Private Methods
    
    private func loadConfiguration() async throws {
        // 模拟配置加载失败
        if Bool.random() {
            throw ConfigError.configurationCorrupted
        }
        
        if Bool.random() {
            throw ConfigError.validationFailed(key: "apiBaseURL", value: "missing")
        }
    }
}

/// 用户数据模型
public struct UserData: Codable {
    let id: String
    let name: String
    let email: String
}

// MARK: - SwiftUI集成示例

/// 展示如何在SwiftUI视图中集成错误处理
public struct MainContentView: View {
    @StateObject private var viewController = ViewController()
    @StateObject private var audioService = ExampleAudioService()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 20) {
            // 状态显示
            Text(viewController.statusMessage)
                .font(.headline)
            
            if viewController.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            }
            
            // 操作按钮
            VStack(spacing: 12) {
                Button("加载数据") {
                    viewController.loadData()
                }
                .disabled(viewController.isLoading)
                
                Button("开始录音") {
                    viewController.startRecording()
                }
                .disabled(audioService.isRecording)
                
                if audioService.isRecording {
                    Button("停止录音") {
                        Task {
                            await audioService.stopRecording()
                        }
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            
            // 测试错误按钮（仅用于演示）
            Group {
                Button("测试音频错误") {
                    let error = AudioSystemError.audioDeviceNotFound
                    ErrorHandler.shared.handle(error, context: "MainContentView.testButton")
                }
                
                Button("测试网络错误") {
                    let error = APIError.networkTimeout
                    ErrorHandler.shared.handle(error, context: "MainContentView.testButton")
                }
                
                Button("测试UI错误") {
                    let error = UIError.windowCreationFailed
                    ErrorHandler.shared.handle(error, context: "MainContentView.testButton")
                }
                
                Button("测试配置错误") {
                    let error = ConfigError.configurationCorrupted
                    ErrorHandler.shared.handle(error, context: "MainContentView.testButton")
                }
            }
            .buttonStyle(.bordered)
            .foregroundColor(.secondary)
        }
        .padding()
        .errorHandler() // 添加错误处理支持
    }
}

// MARK: - 最佳实践说明

/*
 
 使用错误处理系统的最佳实践：
 
 1. **错误分类**：
    - 使用合适的错误类型（AudioSystemError、APIError等）
    - 选择正确的严重程度级别
    - 提供有意义的错误代码
 
 2. **错误处理**：
    - 在服务层捕获和处理特定错误
    - 在UI层使用ErrorHandler统一处理
    - 不要忽略错误，至少要记录日志
 
 3. **用户体验**：
    - 提供友好的用户错误消息
    - 给出明确的恢复建议
    - 实现自动重试机制
 
 4. **日志记录**：
    - 记录足够的上下文信息
    - 使用适当的日志级别
    - 在生产环境中保护敏感信息
 
 5. **恢复策略**：
    - 实现有意义的重试逻辑
    - 提供降级方案
    - 在必要时引导用户干预
 
 6. **测试**：
    - 测试各种错误场景
    - 验证恢复机制
    - 确保错误消息的准确性
 
 */