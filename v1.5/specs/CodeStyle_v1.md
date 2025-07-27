# Hello Prompt - 代码风格文档 V1.0
**版本：V1.0**  
**日期：2025-07-25**  
**设计原则：简洁、一致、高质量音频处理**

## 1. 全局代码风格要求

### 1.1 Swift编码规范

#### 1.1.1 基础格式化
```swift
// ✅ 正确：使用4个空格缩进
class AudioService: ObservableObject {
    @Published var isRecording = false
    
    func startRecording() async throws {
        try await setupAudioEngine()
    }
}

// ❌ 错误：使用tab或2个空格
class AudioService: ObservableObject {
  @Published var isRecording = false
}
```

#### 1.1.2 命名约定
```swift
// ✅ 正确：清晰的类型和变量命名
class OpenAIService {
    private let apiConfiguration: APIConfiguration
    private var transcriptionRequest: AudioTranscriptionRequest?
    
    func transcribeAudio(_ audioData: Data) async throws -> String {
        // 实现
    }
}

// ❌ 错误：缩写和不清晰的命名
class AIServ {
    private let cfg: APICfg
    private var req: AudioTransReq?
    
    func transcribe(_ data: Data) async throws -> String {
        // 实现
    }
}
```

#### 1.1.3 类型注解和推断
```swift
// ✅ 正确：在需要明确性时使用类型注解
let audioFormat: AVAudioFormat = AVAudioFormat(
    standardFormatWithSampleRate: 16000,
    channels: 1
)!

// 简单情况下依赖类型推断
let sampleRate = 16000.0
let channels = 1

// ❌ 错误：不必要的类型注解
let sampleRate: Double = 16000.0
let channels: Int = 1
```

### 1.2 文件组织结构

#### 1.2.1 标准文件模板
```swift
//
//  AudioService.swift
//  HelloPrompt
//
//  Created by [Author] on [Date].
//  Copyright © 2025 HelloPrompt. All rights reserved.
//

import Foundation
import AVFoundation
import AudioKit
import OSLog

// MARK: - Main Class
@MainActor
class AudioService: ObservableObject {
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    
    // MARK: - Private Properties
    private let audioEngine = AVAudioEngine()
    private let logger = Logger(subsystem: "com.hellprompt.audio", category: "service")
    
    // MARK: - Initialization
    init() {
        setupAudioSession()
    }
    
    // MARK: - Public Methods
    func startRecording() async throws {
        logger.info("开始录音")
        // 实现
    }
    
    // MARK: - Private Methods
    private func setupAudioSession() {
        // 实现
    }
}

// MARK: - Extensions
extension AudioService {
    // 相关扩展
}

// MARK: - Helper Types
enum AudioError: LocalizedError {
    case microphonePermissionDenied
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "需要麦克风权限"
        }
    }
}
```

### 1.3 SwiftUI视图规范

#### 1.3.1 视图结构组织
```swift
import SwiftUI

struct FloatingBall: View {
    // MARK: - Properties
    @ObservedObject var audioService: AudioService
    @State private var pulseAnimation = false
    
    // MARK: - Body
    var body: some View {
        ZStack {
            backgroundCircle
            pulseEffect
            centerIcon
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - View Components
    private var backgroundCircle: some View {
        Circle()
            .fill(backgroundGradient)
            .frame(width: ballSize, height: ballSize)
    }
    
    private var pulseEffect: some View {
        Circle()
            .stroke(strokeColor, lineWidth: 2)
            .scaleEffect(pulseAnimation ? 1.2 : 1.0)
    }
    
    private var centerIcon: some View {
        Image(systemName: iconName)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white)
    }
    
    // MARK: - Computed Properties
    private var ballSize: CGFloat {
        audioService.isRecording ? 50 : 40
    }
    
    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: audioService.isRecording ? 
                [.red.opacity(0.8), .red.opacity(0.6)] :
                [.green.opacity(0.8), .green.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Private Methods
    private func startAnimations() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            pulseAnimation = true
        }
    }
}
```

## 2. 音频处理最佳实践

### 2.1 AVFoundation音频配置

#### 2.1.1 专业音频设置
```swift
import AVFoundation
import AudioKit

class AudioBestPractices {
    
    // MARK: - 音频会话配置
    private func setupOptimalAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        
        // 设置最佳录音类别和选项
        try audioSession.setCategory(
            .playAndRecord,                    // 支持录音和播放
            mode: .measurement,                // 测量模式，减少处理延迟
            options: [
                .duckOthers,                   // 自动降低其他音频音量
                .defaultToSpeaker,             // 默认使用扬声器
                .allowBluetoothA2DP,          // 支持蓝牙音频
                .allowAirPlay                  // 支持AirPlay
            ]
        )
        
        // 优化录音质量参数
        try audioSession.setPreferredSampleRate(16000.0)      // OpenAI Whisper最佳采样率
        try audioSession.setPreferredIOBufferDuration(0.02)   // 20ms缓冲，平衡延迟和稳定性
        try audioSession.setPreferredInputNumberOfChannels(1) // 单声道减少数据量
        
        // 激活音频会话
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        LogManager.shared.audioLog(.sessionConfigured, details: [
            "sampleRate": audioSession.sampleRate,
            "bufferDuration": audioSession.ioBufferDuration,
            "inputChannels": audioSession.inputNumberOfChannels
        ])
    }
    
    // MARK: - 音频格式配置
    private var optimalAudioFormat: AVAudioFormat {
        // 专门为OpenAI Whisper API优化的音频格式
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,   // 32位浮点PCM
            sampleRate: 16000,                 // 16kHz采样率
            channels: 1,                       // 单声道
            interleaved: false                 // 非交错模式，更好的处理性能
        ) else {
            fatalError("无法创建音频格式")
        }
        return format
    }
    
    // MARK: - 音频引擎配置
    private func setupHighQualityAudioEngine() throws {
        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        
        // 获取输入节点的硬件格式
        let hardwareFormat = inputNode.inputFormat(forBus: 0)
        LogManager.shared.audioLog(.engineSetup, details: [
            "hardwareSampleRate": hardwareFormat.sampleRate,
            "hardwareChannels": hardwareFormat.channelCount
        ])
        
        // 安装高质量音频处理tap
        inputNode.installTap(
            onBus: 0,
            bufferSize: 1024,              // 1024帧缓冲区，平衡延迟和稳定性
            format: optimalAudioFormat     // 使用优化的音频格式
        ) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, timestamp: time)
        }
        
        // 配置音频引擎性能
        try audioEngine.enableManualRenderingMode(
            .realtime,
            format: optimalAudioFormat,
            maximumFrameCount: 4096
        )
        
        try audioEngine.start()
    }
    
    // MARK: - 高质量音频处理
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, timestamp: AVAudioTime) {
        // 1. 音频质量检查
        guard validateAudioQuality(buffer) else {
            LogManager.shared.warning("AudioProcessing", "音频质量不符合要求")
            return
        }
        
        // 2. 实时音频增强
        let enhancedBuffer = enhanceAudioQuality(buffer)
        
        // 3. Voice Activity Detection
        let voiceActivity = performVAD(enhancedBuffer)
        
        // 4. 音频数据写入
        writeToAudioFile(enhancedBuffer)
        
        // 5. UI更新
        DispatchQueue.main.async {
            self.updateAudioLevelUI(enhancedBuffer)
        }
    }
    
    // MARK: - 音频质量验证
    private func validateAudioQuality(_ buffer: AVAudioPCMBuffer) -> Bool {
        guard let channelData = buffer.floatChannelData?[0] else { return false }
        
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0.0
        var peak: Float = 0.0
        
        for i in 0..<frameLength {
            let sample = abs(channelData[i])
            sum += sample * sample
            peak = max(peak, sample)
        }
        
        let rms = sqrt(sum / Float(frameLength))
        
        // 质量检查：RMS不能太低（静音）或太高（削波）
        let isValidRMS = rms > 0.001 && rms < 0.9
        let isValidPeak = peak < 0.95
        
        LogManager.shared.debug("AudioQuality", "RMS: \(rms), Peak: \(peak), Valid: \(isValidRMS && isValidPeak)")
        
        return isValidRMS && isValidPeak
    }
    
    // MARK: - 音频增强处理
    private func enhanceAudioQuality(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        // 使用AudioKit进行音频增强
        
        // 1. 噪声抑制 (基于谱减法)
        let denoisedBuffer = applySpectralSubtraction(buffer)
        
        // 2. 自动增益控制 (AGC)
        let normalizedBuffer = applyAutomaticGainControl(denoisedBuffer)
        
        // 3. 高通滤波器 (移除低频噪声)
        let filteredBuffer = applyHighPassFilter(normalizedBuffer, cutoffFreq: 80.0)
        
        return filteredBuffer
    }
    
    // MARK: - 噪声抑制 (谱减法实现)
    private func applySpectralSubtraction(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        // 简化的谱减法实现
        guard let inputData = buffer.floatChannelData?[0],
              let outputBuffer = AVAudioPCMBuffer(
                pcmFormat: buffer.format,
                frameCapacity: buffer.frameCapacity
              ) else {
            return buffer
        }
        
        outputBuffer.frameLength = buffer.frameLength
        
        guard let outputData = outputBuffer.floatChannelData?[0] else {
            return buffer
        }
        
        let frameLength = Int(buffer.frameLength)
        
        // 估算噪声谱 (使用前100帧)
        var noiseSpectrum: Float = 0.0
        let noiseFrames = min(100, frameLength)
        
        for i in 0..<noiseFrames {
            noiseSpectrum += inputData[i] * inputData[i]
        }
        noiseSpectrum /= Float(noiseFrames)
        
        // 应用谱减法
        for i in 0..<frameLength {
            let signalPower = inputData[i] * inputData[i]
            let enhancedPower = max(signalPower - 2.0 * noiseSpectrum, 0.1 * signalPower)
            outputData[i] = inputData[i] * sqrt(enhancedPower / signalPower)
        }
        
        return outputBuffer
    }
    
    // MARK: - 自动增益控制
    private func applyAutomaticGainControl(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        guard let inputData = buffer.floatChannelData?[0],
              let outputBuffer = AVAudioPCMBuffer(
                pcmFormat: buffer.format,
                frameCapacity: buffer.frameCapacity
              ) else {
            return buffer
        }
        
        outputBuffer.frameLength = buffer.frameLength
        
        guard let outputData = outputBuffer.floatChannelData?[0] else {
            return buffer
        }
        
        let frameLength = Int(buffer.frameLength)
        
        // 计算RMS
        var rms: Float = 0.0
        for i in 0..<frameLength {
            rms += inputData[i] * inputData[i]
        }
        rms = sqrt(rms / Float(frameLength))
        
        // 目标RMS电平 (约-20dB)
        let targetRMS: Float = 0.1
        let gain = rms > 0 ? min(targetRMS / rms, 4.0) : 1.0 // 限制最大增益
        
        // 应用增益
        for i in 0..<frameLength {
            outputData[i] = inputData[i] * gain
        }
        
        LogManager.shared.debug("AGC", "原始RMS: \(rms), 增益: \(gain)")
        
        return outputBuffer
    }
    
    // MARK: - 高通滤波器
    private func applyHighPassFilter(_ buffer: AVAudioPCMBuffer, cutoffFreq: Float) -> AVAudioPCMBuffer {
        // 简单的一阶高通滤波器实现
        guard let inputData = buffer.floatChannelData?[0],
              let outputBuffer = AVAudioPCMBuffer(
                pcmFormat: buffer.format,
                frameCapacity: buffer.frameCapacity
              ) else {
            return buffer
        }
        
        outputBuffer.frameLength = buffer.frameLength
        
        guard let outputData = outputBuffer.floatChannelData?[0] else {
            return buffer
        }
        
        let frameLength = Int(buffer.frameLength)
        let sampleRate = Float(buffer.format.sampleRate)
        
        // 计算滤波器系数
        let rc = 1.0 / (2.0 * Float.pi * cutoffFreq)
        let dt = 1.0 / sampleRate
        let alpha = rc / (rc + dt)
        
        // 应用高通滤波器
        var previousInput: Float = 0.0
        var previousOutput: Float = 0.0
        
        for i in 0..<frameLength {
            let currentInput = inputData[i]
            let currentOutput = alpha * (previousOutput + currentInput - previousInput)
            
            outputData[i] = currentOutput
            
            previousInput = currentInput
            previousOutput = currentOutput
        }
        
        return outputBuffer
    }
    
    // MARK: - 先进VAD算法
    private func performVAD(_ buffer: AVAudioPCMBuffer) -> Bool {
        guard let channelData = buffer.floatChannelData?[0] else { return false }
        
        let frameLength = Int(buffer.frameLength)
        
        // 1. 能量检测
        var energy: Float = 0.0
        for i in 0..<frameLength {
            energy += channelData[i] * channelData[i]
        }
        energy /= Float(frameLength)
        
        // 2. 零穿越率检测
        var zeroCrossings = 0
        for i in 1..<frameLength {
            if (channelData[i] >= 0) != (channelData[i-1] >= 0) {
                zeroCrossings += 1
            }
        }
        let zcr = Float(zeroCrossings) / Float(frameLength)
        
        // 3. 综合判断
        let energyThreshold: Float = 0.01
        let zcrThreshold: Float = 0.1
        
        let hasVoice = energy > energyThreshold && zcr < zcrThreshold
        
        LogManager.shared.debug("VAD", "Energy: \(energy), ZCR: \(zcr), Voice: \(hasVoice)")
        
        return hasVoice
    }
}

// MARK: - 音频事件枚举扩展
extension AudioEvent {
    static let sessionConfigured = AudioEvent(rawValue: "SessionConfigured")!
    static let engineSetup = AudioEvent(rawValue: "EngineSetup")!
    static let qualityCheck = AudioEvent(rawValue: "QualityCheck")!
    static let noiseReduction = AudioEvent(rawValue: "NoiseReduction")!
    static let gainControl = AudioEvent(rawValue: "GainControl")!
}
```

### 2.2 音频文件处理规范

#### 2.2.1 高效音频文件操作
```swift
import AVFoundation

class AudioFileManager {
    
    // MARK: - 音频文件写入最佳实践
    func createOptimalAudioFile(at url: URL, format: AVAudioFormat) throws -> AVAudioFile {
        // 为OpenAI API优化的音频文件设置
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        
        let audioFile = try AVAudioFile(
            forWriting: url,
            settings: settings,
            commonFormat: .pcmFormatInt16,
            interleaved: true
        )
        
        LogManager.shared.audioLog(.fileCreated, details: [
            "url": url.path,
            "sampleRate": settings[AVSampleRateKey] ?? 0,
            "channels": settings[AVNumberOfChannelsKey] ?? 0
        ])
        
        return audioFile
    }
    
    // MARK: - 高效音频数据转换
    func convertToAPIFormat(_ audioFile: AVAudioFile) async throws -> Data {
        let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFile.processingFormat,
            frameCapacity: AVAudioFrameCount(audioFile.length)
        )!
        
        try audioFile.read(into: buffer)
        
        // 转换为WAV格式数据
        let wavData = try await convertBufferToWAV(buffer)
        
        LogManager.shared.audioLog(.formatConversion, details: [
            "originalLength": audioFile.length,
            "convertedSize": wavData.count
        ])
        
        return wavData
    }
    
    private func convertBufferToWAV(_ buffer: AVAudioPCMBuffer) async throws -> Data {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("temp_\(UUID().uuidString).wav")
        
        let outputFile = try AVAudioFile(
            forWriting: outputURL,
            settings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
        )
        
        try outputFile.write(from: buffer)
        
        defer {
            // 清理临时文件
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        return try Data(contentsOf: outputURL)
    }
    
    // MARK: - 内存管理
    func cleanupAudioResources() {
        // 清理音频缓冲区
        AudioBufferPool.shared.clear()
        
        // 清理临时文件
        let tempDir = FileManager.default.temporaryDirectory
        let audioFiles = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "wav" || $0.pathExtension == "m4a" }
        
        audioFiles?.forEach { url in
            try? FileManager.default.removeItem(at: url)
        }
        
        LogManager.shared.audioLog(.resourceCleanup)
    }
}

// MARK: - 音频缓冲池 (性能优化)
class AudioBufferPool {
    static let shared = AudioBufferPool()
    
    private var bufferPool: [AVAudioPCMBuffer] = []
    private let maxPoolSize = 10
    private let queue = DispatchQueue(label: "audiobuffer.pool", qos: .utility)
    
    func getBuffer(format: AVAudioFormat, frameCapacity: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        return queue.sync {
            if let buffer = bufferPool.first(where: { 
                $0.format.isEqual(format) && $0.frameCapacity >= frameCapacity 
            }) {
                bufferPool.removeAll { $0 === buffer }
                return buffer
            }
            
            return AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity)
        }
    }
    
    func returnBuffer(_ buffer: AVAudioPCMBuffer) {
        queue.async {
            if self.bufferPool.count < self.maxPoolSize {
                buffer.frameLength = 0 // 重置长度
                self.bufferPool.append(buffer)
            }
        }
    }
    
    func clear() {
        queue.async {
            self.bufferPool.removeAll()
        }
    }
}
```

## 3. 网络请求最佳实践

### 3.1 OpenAI API优化

#### 3.1.1 高效API客户端
```swift
import Foundation
import OpenAI

class OptimizedOpenAIClient {
    
    // MARK: - 连接优化配置
    private func createOptimizedConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        
        // 连接优化
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        
        // HTTP/2支持
        config.httpShouldUsePipelining = true
        config.httpMaximumConnectionsPerHost = 4
        
        // 压缩优化
        config.httpAdditionalHeaders = [
            "Accept-Encoding": "gzip, deflate, br",
            "Connection": "keep-alive"
        ]
        
        return config
    }
    
    // MARK: - 重试机制
    func performRequestWithRetry<T>(
        _ request: @escaping () async throws -> T,
        maxRetries: Int = 3,
        backoffStrategy: BackoffStrategy = .exponential
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                LogManager.shared.apiLog(.requestAttempt, details: ["attempt": attempt + 1])
                
                let startTime = CFAbsoluteTimeGetCurrent()
                let result = try await request()
                let duration = CFAbsoluteTimeGetCurrent() - startTime
                
                LogManager.shared.apiLog(.requestSuccess, duration: duration)
                return result
                
            } catch {
                lastError = error
                LogManager.shared.apiLog(.requestError, details: ["error": error.localizedDescription])
                
                // 如果不是最后一次尝试，等待后重试
                if attempt < maxRetries - 1 {
                    let delay = backoffStrategy.delay(for: attempt)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? OpenAIError.maxRetriesExceeded
    }
    
    // MARK: - 音频转录优化
    func optimizedTranscription(_ audioData: Data) async throws -> String {
        return try await performRequestWithRetry {
            // 数据压缩检查
            let compressedData = try self.compressAudioIfNeeded(audioData)
            
            let request = AudioTranscriptionRequest(
                file: compressedData,
                fileName: "audio.wav",
                model: .whisper_1,
                language: "zh",
                temperature: 0.0,
                responseFormat: .text,
                prompt: "以下是普通话语音，可能包含技术术语。" // 提供上下文提示
            )
            
            return try await self.openAI.audioTranscriptions(request: request).text
        }
    }
    
    // MARK: - 数据压缩优化
    private func compressAudioIfNeeded(_ data: Data) throws -> Data {
        // 如果音频数据超过25MB，进行压缩
        let maxSize = 25 * 1024 * 1024
        
        if data.count > maxSize {
            LogManager.shared.warning("OpenAIClient", "音频文件过大: \(data.count)字节，开始压缩")
            
            // 使用音频压缩算法
            return try compressAudioData(data, targetSize: maxSize)
        }
        
        return data
    }
    
    private func compressAudioData(_ data: Data, targetSize: Int) throws -> Data {
        // 简化的音频压缩实现
        // 实际项目中应使用专业的音频编码库
        
        let compressionRatio = Double(targetSize) / Double(data.count)
        let stepSize = max(1, Int(1.0 / compressionRatio))
        
        var compressedData = Data()
        compressedData.reserveCapacity(targetSize)
        
        for i in stride(from: 0, to: data.count, by: stepSize) {
            compressedData.append(data[i])
        }
        
        LogManager.shared.info("OpenAIClient", "音频压缩完成: \(data.count) -> \(compressedData.count)字节")
        
        return compressedData
    }
}

// MARK: - 重试策略
enum BackoffStrategy {
    case linear
    case exponential
    case fixed(TimeInterval)
    
    func delay(for attempt: Int) -> TimeInterval {
        switch self {
        case .linear:
            return TimeInterval(attempt + 1)
        case .exponential:
            return pow(2.0, Double(attempt))
        case .fixed(let interval):
            return interval
        }
    }
}

// MARK: - API事件扩展
extension APIEvent {
    static let requestAttempt = APIEvent(rawValue: "RequestAttempt")!
    static let requestSuccess = APIEvent(rawValue: "RequestSuccess")!
    static let requestError = APIEvent(rawValue: "RequestError")!
    static let compressionApplied = APIEvent(rawValue: "CompressionApplied")!
}
```

## 4. 错误处理与日志规范

### 4.1 结构化错误处理

#### 4.1.1 分层错误处理系统
```swift
import Foundation

// MARK: - 错误分类体系
protocol HelloPromptError: LocalizedError {
    var errorCode: String { get }
    var severity: ErrorSeverity { get }
    var recoverySuggestion: String? { get }
    var underlyingError: Error? { get }
}

enum ErrorSeverity {
    case info       // 信息性错误，不影响功能
    case warning    // 警告性错误，功能降级
    case error      // 一般错误，功能受影响
    case critical   // 严重错误，需要重启
}

// MARK: - 音频相关错误
enum AudioSystemError: HelloPromptError {
    case microphonePermissionDenied
    case audioEngineFailure(Error)
    case audioQualityTooLow(rms: Float)
    case recordingTimeout
    case vadFailure
    
    var errorCode: String {
        switch self {
        case .microphonePermissionDenied: return "AUDIO_001"
        case .audioEngineFailure: return "AUDIO_002"
        case .audioQualityTooLow: return "AUDIO_003"
        case .recordingTimeout: return "AUDIO_004"
        case .vadFailure: return "AUDIO_005"
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .microphonePermissionDenied: return .critical
        case .audioEngineFailure: return .error
        case .audioQualityTooLow: return .warning
        case .recordingTimeout: return .info
        case .vadFailure: return .warning
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "应用需要麦克风权限才能录音"
        case .audioEngineFailure(let error):
            return "音频引擎故障: \(error.localizedDescription)"
        case .audioQualityTooLow(let rms):
            return "音频质量过低 (RMS: \(rms))，请在安静环境中重试"
        case .recordingTimeout:
            return "录音时间过长，已自动停止"
        case .vadFailure:
            return "语音检测失败，请重新录制"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .microphonePermissionDenied:
            return "请到系统偏好设置 > 安全性与隐私 > 麦克风 中授权"
        case .audioEngineFailure:
            return "请重启应用或检查音频设备连接"
        case .audioQualityTooLow:
            return "请靠近麦克风，确保环境安静"
        case .recordingTimeout:
            return "请在30秒内完成录音"
        case .vadFailure:
            return "请说话更清晰一些"
        }
    }
    
    var underlyingError: Error? {
        switch self {
        case .audioEngineFailure(let error):
            return error
        default:
            return nil
        }
    }
}

// MARK: - API相关错误
enum APIError: HelloPromptError {
    case invalidAPIKey
    case networkTimeout
    case rateLimitExceeded
    case audioFileTooLarge(size: Int)
    case transcriptionEmpty
    case optimizationFailed(Error)
    
    var errorCode: String {
        switch self {
        case .invalidAPIKey: return "API_001"
        case .networkTimeout: return "API_002"
        case .rateLimitExceeded: return "API_003"
        case .audioFileTooLarge: return "API_004"
        case .transcriptionEmpty: return "API_005"
        case .optimizationFailed: return "API_006"
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .invalidAPIKey: return .critical
        case .networkTimeout: return .error
        case .rateLimitExceeded: return .warning
        case .audioFileTooLarge: return .warning
        case .transcriptionEmpty: return .info
        case .optimizationFailed: return .error
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "OpenAI API密钥无效或已过期"
        case .networkTimeout:
            return "网络连接超时"
        case .rateLimitExceeded:
            return "API调用频率超限，请稍后重试"
        case .audioFileTooLarge(let size):
            return "音频文件过大 (\(size)字节)，OpenAI限制为25MB"
        case .transcriptionEmpty:
            return "语音识别结果为空，可能是静音录制"
        case .optimizationFailed(let error):
            return "提示词优化失败: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidAPIKey:
            return "请检查设置中的API密钥配置"
        case .networkTimeout:
            return "请检查网络连接或稍后重试"
        case .rateLimitExceeded:
            return "请等待1分钟后重试"
        case .audioFileTooLarge:
            return "请录制更短的音频"
        case .transcriptionEmpty:
            return "请重新录制，确保有清晰的语音输入"
        case .optimizationFailed:
            return "请重试或检查网络连接"
        }
    }
    
    var underlyingError: Error? {
        switch self {
        case .optimizationFailed(let error):
            return error
        default:
            return nil
        }
    }
}

// MARK: - 错误处理器
class ErrorHandler {
    static let shared = ErrorHandler()
    
    private init() {}
    
    func handle(_ error: HelloPromptError, context: String = "") {
        // 记录错误日志
        LogManager.shared.error(
            "ErrorHandler",
            "[\(error.errorCode)] \(context): \(error.localizedDescription)"
        )
        
        // 根据严重程度处理
        switch error.severity {
        case .info:
            handleInfoError(error)
        case .warning:
            handleWarningError(error)
        case .error:
            handleGeneralError(error)
        case .critical:
            handleCriticalError(error)
        }
        
        // 上报错误分析（可选）
        reportErrorAnalytics(error)
    }
    
    private func handleInfoError(_ error: HelloPromptError) {
        // 轻微提示，不打断用户
        DispatchQueue.main.async {
            // 可以显示状态栏提示或轻微的UI反馈
        }
    }
    
    private func handleWarningError(_ error: HelloPromptError) {
        // 显示警告提示，提供重试选项
        DispatchQueue.main.async {
            self.showWarningAlert(error)
        }
    }
    
    private func handleGeneralError(_ error: HelloPromptError) {
        // 显示错误对话框，提供恢复建议
        DispatchQueue.main.async {
            self.showErrorAlert(error)
        }
    }
    
    private func handleCriticalError(_ error: HelloPromptError) {
        // 严重错误，可能需要重启应用
        DispatchQueue.main.async {
            self.showCriticalErrorAlert(error)
        }
    }
    
    private func showWarningAlert(_ error: HelloPromptError) {
        // 实现警告提示UI
    }
    
    private func showErrorAlert(_ error: HelloPromptError) {
        // 实现错误对话框UI
    }
    
    private func showCriticalErrorAlert(_ error: HelloPromptError) {
        // 实现严重错误处理UI
    }
    
    private func reportErrorAnalytics(_ error: HelloPromptError) {
        // 可选：错误分析上报（注意隐私保护）
        let errorData: [String: Any] = [
            "errorCode": error.errorCode,
            "severity": error.severity,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        LogManager.shared.debug("ErrorAnalytics", "错误上报: \(errorData)")
    }
}
```

### 4.2 高级日志系统

#### 4.2.1 性能监控日志
```swift
import OSLog
import Foundation

class PerformanceLogger {
    private let logger = Logger(subsystem: "com.hellprompt.performance", category: "monitoring")
    
    // MARK: - 性能测量
    func measurePerformance<T>(
        operation: String,
        category: String = "General",
        _ block: () throws -> T
    ) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = getMemoryUsage()
        
        defer {
            let endTime = CFAbsoluteTimeGetCurrent()
            let endMemory = getMemoryUsage()
            let duration = endTime - startTime
            let memoryDelta = endMemory - startMemory
            
            logger.info("""
                Performance: [\(category)] \(operation)
                Duration: \(String(format: "%.3f", duration))s
                Memory: \(formatBytes(startMemory)) -> \(formatBytes(endMemory)) (Δ\(formatBytes(memoryDelta)))
                """)
        }
        
        return try block()
    }
    
    // MARK: - 异步性能测量
    func measureAsyncPerformance<T>(
        operation: String,
        category: String = "General",
        _ block: () async throws -> T
    ) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = getMemoryUsage()
        
        defer {
            let endTime = CFAbsoluteTimeGetCurrent()
            let endMemory = getMemoryUsage()
            let duration = endTime - startTime
            let memoryDelta = endMemory - startMemory
            
            logger.info("""
                Async Performance: [\(category)] \(operation)
                Duration: \(String(format: "%.3f", duration))s
                Memory: \(formatBytes(startMemory)) -> \(formatBytes(endMemory)) (Δ\(formatBytes(memoryDelta)))
                """)
        }
        
        return try await block()
    }
    
    // MARK: - 内存使用监控
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? info.resident_size : 0
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    // MARK: - 音频性能专项监控
    func logAudioPerformance(
        bufferSize: Int,
        sampleRate: Double,
        processingTime: TimeInterval
    ) {
        let bufferDuration = Double(bufferSize) / sampleRate
        let realTimeRatio = processingTime / bufferDuration
        
        logger.info("""
            Audio Performance:
            Buffer: \(bufferSize) frames (\(String(format: "%.1f", bufferDuration * 1000))ms)
            Processing: \(String(format: "%.3f", processingTime * 1000))ms
            Real-time ratio: \(String(format: "%.2f", realTimeRatio))
            """)
        
        if realTimeRatio > 0.8 {
            logger.warning("音频处理接近实时极限，可能出现延迟")
        }
    }
}

// MARK: - 专用日志扩展
extension LogManager {
    func performance(_ operation: String, duration: TimeInterval, details: [String: Any] = [:]) {
        var message = "Performance: \(operation) - \(String(format: "%.3f", duration))s"
        if !details.isEmpty {
            message += " - \(details)"
        }
        info("Performance", message)
    }
    
    func memory(_ event: String, usage: UInt64) {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .memory
        let formattedUsage = formatter.string(fromByteCount: Int64(usage))
        
        debug("Memory", "\(event) - Usage: \(formattedUsage)")
    }
    
    func network(_ url: String, method: String, statusCode: Int, duration: TimeInterval) {
        info("Network", "\(method) \(url) - \(statusCode) - \(String(format: "%.3f", duration))s")
    }
}
```

## 5. 测试规范

### 5.1 单元测试标准

#### 5.1.1 音频服务测试
```swift
import XCTest
import AVFoundation
@testable import HelloPrompt

class AudioServiceTests: XCTestCase {
    var audioService: AudioService!
    var mockAudioEngine: MockAudioEngine!
    
    override func setUp() {
        super.setUp()
        audioService = AudioService()
        mockAudioEngine = MockAudioEngine()
        audioService.audioEngine = mockAudioEngine
    }
    
    override func tearDown() {
        audioService = nil
        mockAudioEngine = nil
        super.tearDown()
    }
    
    // MARK: - 音频录制测试
    func testStartRecording_WithPermission_ShouldSucceed() async throws {
        // Given
        mockAudioEngine.shouldGrantPermission = true
        
        // When
        try await audioService.startRecording()
        
        // Then
        XCTAssertTrue(audioService.isRecording)
        XCTAssertTrue(mockAudioEngine.isRunning)
    }
    
    func testStartRecording_WithoutPermission_ShouldThrow() async {
        // Given
        mockAudioEngine.shouldGrantPermission = false
        
        // When & Then
        await XCTAssertThrowsError(try await audioService.startRecording()) { error in
            XCTAssertTrue(error is AudioSystemError)
            if case AudioSystemError.microphonePermissionDenied = error {
                // Expected error
            } else {
                XCTFail("Expected microphonePermissionDenied error")
            }
        }
    }
    
    // MARK: - VAD测试
    func testVAD_WithVoiceSignal_ShouldDetectVoice() {
        // Given
        let voiceBuffer = createMockVoiceBuffer()
        
        // When
        let hasVoice = audioService.performVAD(voiceBuffer)
        
        // Then
        XCTAssertTrue(hasVoice)
    }
    
    func testVAD_WithSilence_ShouldNotDetectVoice() {
        // Given
        let silenceBuffer = createMockSilenceBuffer()
        
        // When
        let hasVoice = audioService.performVAD(silenceBuffer)
        
        // Then
        XCTAssertFalse(hasVoice)
    }
    
    // MARK: - 音频质量测试
    func testAudioQuality_ValidSignal_ShouldPass() {
        // Given
        let validBuffer = createMockValidAudioBuffer()
        
        // When
        let isValid = audioService.validateAudioQuality(validBuffer)
        
        // Then
        XCTAssertTrue(isValid)
    }
    
    func testAudioQuality_ClippedSignal_ShouldFail() {
        // Given
        let clippedBuffer = createMockClippedAudioBuffer()
        
        // When
        let isValid = audioService.validateAudioQuality(clippedBuffer)
        
        // Then
        XCTAssertFalse(isValid)
    }
    
    // MARK: - Helper Methods
    private func createMockVoiceBuffer() -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024
        
        // 生成模拟语音信号
        guard let channelData = buffer.floatChannelData?[0] else {
            fatalError("Cannot access channel data")
        }
        
        for i in 0..<Int(buffer.frameLength) {
            let sample = sin(2.0 * Float.pi * 440.0 * Float(i) / Float(format.sampleRate)) * 0.1
            channelData[i] = sample
        }
        
        return buffer
    }
    
    private func createMockSilenceBuffer() -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024
        
        // 静音缓冲区已经是零值
        return buffer
    }
    
    private func createMockValidAudioBuffer() -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024
        
        guard let channelData = buffer.floatChannelData?[0] else {
            fatalError("Cannot access channel data")
        }
        
        for i in 0..<Int(buffer.frameLength) {
            channelData[i] = Float.random(in: -0.3...0.3) // 正常音频范围
        }
        
        return buffer
    }
    
    private func createMockClippedAudioBuffer() -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024
        
        guard let channelData = buffer.floatChannelData?[0] else {
            fatalError("Cannot access channel data")
        }
        
        for i in 0..<Int(buffer.frameLength) {
            channelData[i] = i % 2 == 0 ? 1.0 : -1.0 // 削波信号
        }
        
        return buffer
    }
}

// MARK: - Mock Objects
class MockAudioEngine: AVAudioEngine {
    var shouldGrantPermission = true
    var isRunning = false
    
    override func start() throws {
        isRunning = true
    }
    
    override func stop() {
        isRunning = false
    }
}
```

### 5.2 性能测试规范

#### 5.2.1 音频处理性能基准
```swift
import XCTest
@testable import HelloPrompt

class PerformanceTests: XCTestCase {
    
    func testAudioProcessingPerformance() {
        let audioService = AudioService()
        let buffer = createLargeAudioBuffer()
        
        measure {
            _ = audioService.processAudioBuffer(buffer, timestamp: AVAudioTime.now())
        }
        
        // 基准：处理1024帧应在1ms内完成
    }
    
    func testVADPerformance() {
        let audioService = AudioService()
        let buffer = createTestAudioBuffer()
        
        measure {
            _ = audioService.performVAD(buffer)
        }
        
        // 基准：VAD检测应在0.1ms内完成
    }
    
    func testAPIRequestPerformance() async {
        let apiService = OpenAIService(apiKey: "test-key")
        let audioData = createTestAudioData()
        
        await measure {
            do {
                _ = try await apiService.transcribeAudio(audioData)
            } catch {
                // 测试性能，忽略实际错误
            }
        }
        
        // 基准：API调用应在3秒内完成
    }
    
    private func createLargeAudioBuffer() -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16000)! // 1秒音频
        buffer.frameLength = 16000
        return buffer
    }
    
    private func createTestAudioBuffer() -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024
        return buffer
    }
    
    private func createTestAudioData() -> Data {
        return Data(count: 1024 * 1024) // 1MB测试数据
    }
}
```

## 6. 代码质量工具配置

### 6.1 SwiftLint配置

#### 6.1.1 .swiftlint.yml
```yaml
# SwiftLint 配置文件
# 适用于 Hello Prompt 项目

# 包含的规则
opt_in_rules:
  - array_init
  - attributes
  - closure_body_length
  - closure_end_indentation
  - closure_spacing
  - collection_alignment
  - contains_over_filter_count
  - contains_over_filter_is_empty
  - contains_over_first_not_nil
  - contains_over_range_nil_comparison
  - discouraged_object_literal
  - empty_collection_literal
  - empty_count
  - empty_string
  - enum_case_associated_values_count
  - explicit_init
  - extension_access_modifier
  - fallthrough
  - fatal_error_message
  - file_header
  - file_name
  - first_where
  - force_unwrapping
  - function_default_parameter_at_end
  - identical_operands
  - implicit_return
  - joined_default_parameter
  - last_where
  - legacy_random
  - literal_expression_end_indentation
  - lower_acl_than_parent
  - modifier_order
  - nimble_operator
  - nslocalizedstring_key
  - number_separator
  - object_literal
  - operator_usage_whitespace
  - overridden_super_call
  - override_in_extension
  - pattern_matching_keywords
  - prefer_self_type_over_type_of_self
  - redundant_nil_coalescing
  - redundant_type_annotation
  - sorted_first_last
  - static_operator
  - strong_iboutlet
  - toggle_bool
  - unavailable_function
  - unneeded_parentheses_in_closure_argument
  - untyped_error_in_catch
  - vertical_parameter_alignment_on_call
  - vertical_whitespace_closing_braces
  - vertical_whitespace_opening_braces
  - yoda_condition

# 禁用的规则
disabled_rules:
  - trailing_whitespace # 在某些情况下允许尾随空格

# 规则配置
line_length:
  warning: 120
  error: 150
  ignores_function_declarations: true
  ignores_comments: true
  ignores_urls: true

file_length:
  warning: 500
  error: 800

function_body_length:
  warning: 50
  error: 100

function_parameter_count:
  warning: 6
  error: 10

type_body_length:
  warning: 300
  error: 500

type_name:
  min_length: 3
  max_length: 40

identifier_name:
  min_length: 2
  max_length: 40
  excluded:
    - id
    - i
    - j
    - x
    - y
    - z
    - db
    - ui
    - os

# 自定义规则
custom_rules:
  # 强制使用 LogManager
  force_log_manager:
    name: "Force LogManager Usage"
    regex: "print\\("
    message: "请使用 LogManager 替代 print() 进行日志记录"
    severity: warning
  
  # 音频相关函数命名规范
  audio_function_naming:
    name: "Audio Function Naming"
    regex: "func\\s+[a-z][a-zA-Z]*Audio[a-zA-Z]*\\("
    message: "音频相关函数应使用清晰的命名，如 processAudioBuffer, configureAudioSession"
    severity: warning
  
  # API调用必须有错误处理
  api_error_handling:
    name: "API Error Handling"
    regex: "try\\s+await\\s+openAI\\."
    message: "API调用必须包含适当的错误处理"
    severity: error

# 包含和排除的文件路径
included:
  - Sources
  - Tests
  - HelloPrompt

excluded:
  - Pods
  - .build
  - DerivedData
  - Package.swift

# 记者输出
reporter: "xcode"
```

### 6.2 代码格式化配置

#### 6.2.1 .swift-format配置
```json
{
  "version": 1,
  "lineLength": 120,
  "indentation": {
    "spaces": 4
  },
  "tabWidth": 4,
  "maximumBlankLines": 1,
  "respectsExistingLineBreaks": true,
  "lineBreakBeforeControlFlowKeywords": false,
  "lineBreakBeforeEachArgument": false,
  "lineBreakBeforeEachGenericRequirement": false,
  "prioritizeKeepingFunctionOutputTogether": true,
  "indentConditionalCompilationBlocks": true,
  "lineBreakAroundMultilineExpressionChainComponents": false,
  "rules": {
    "AllPublicDeclarationsHaveDocumentation": false,
    "AlwaysUseLowerCamelCase": true,
    "AmbiguousTrailingClosureOverload": true,
    "BeginDocumentationCommentWithOneLineSummary": false,
    "DoNotUseSemicolons": true,
    "DontRepeatTypeInStaticProperties": true,
    "FileScopedDeclarationPrivacy": true,
    "FullyIndirectEnum": true,
    "GroupNumericLiterals": true,
    "IdentifiersMustBeASCII": true,
    "NeverForceUnwrap": false,
    "NeverUseForceTryInTests": false,
    "NeverUseImplicitlyUnwrappedOptionals": false,
    "NoAccessLevelOnExtensionDeclaration": true,
    "NoBlockComments": true,
    "NoCasesWithOnlyFallthrough": true,
    "NoEmptyTrailingClosureParentheses": true,
    "NoLabelsInCasePatterns": true,
    "NoLeadingUnderscores": false,
    "NoParensAroundConditions": true,
    "NoVoidReturnOnFunctionSignature": true,
    "OneCasePerLine": true,
    "OneVariableDeclarationPerLine": true,
    "OnlyOneTrailingClosureArgument": true,
    "OrderedImports": true,
    "ReturnVoidInsteadOfEmptyTuple": true,
    "UseLetInEveryBoundCaseVariable": true,
    "UseShorthandTypeNames": true,
    "UseSingleLinePropertyGetter": true,
    "UseSynthesizedInitializer": true,
    "UseTripleSlashForDocumentationComments": true,
    "UseWhereClausesInForLoops": true,
    "ValidateDocumentationComments": false
  }
}
```

## 7. 部署与发布规范

### 7.1 构建脚本

#### 7.1.1 build.sh
```bash
#!/bin/bash

# Hello Prompt 构建脚本
# 用于自动化构建、测试和打包

set -e  # 遇到错误立即退出

# 项目配置
PROJECT_NAME="HelloPrompt"
SCHEME_NAME="HelloPrompt"
BUILD_DIR="./build"
ARCHIVE_PATH="$BUILD_DIR/HelloPrompt.xcarchive"
EXPORT_PATH="$BUILD_DIR/HelloPrompt.app"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# 清理函数
cleanup() {
    log "清理构建目录..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
}

# 依赖检查
check_dependencies() {
    log "检查构建依赖..."
    
    # 检查 Xcode
    if ! command -v xcodebuild &> /dev/null; then
        error "Xcode 未安装或未正确配置"
    fi
    
    # 检查 SwiftLint
    if ! command -v swiftlint &> /dev/null; then
        log "警告: SwiftLint 未安装，将跳过代码检查"
    fi
    
    # 检查证书
    if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
        log "警告: 未找到代码签名证书，将创建未签名版本"
    fi
}

# 代码质量检查
run_quality_checks() {
    log "运行代码质量检查..."
    
    if command -v swiftlint &> /dev/null; then
        log "运行 SwiftLint..."
        swiftlint --strict
    fi
    
    log "运行单元测试..."
    swift test --parallel
}

# 音频功能测试
test_audio_functionality() {
    log "运行音频功能测试..."
    
    # 检查音频权限测试
    swift test --filter AudioServiceTests
    
    # 性能基准测试
    swift test --filter PerformanceTests
    
    log "音频功能测试完成"
}

# 构建应用
build_app() {
    log "开始构建应用..."
    
    # 构建 Release 版本
    swift build -c release
    
    log "应用构建完成"
}

# 创建应用包
create_app_bundle() {
    log "创建应用包..."
    
    local app_bundle="$BUILD_DIR/HelloPrompt.app"
    
    # 创建应用包结构
    mkdir -p "$app_bundle/Contents/MacOS"
    mkdir -p "$app_bundle/Contents/Resources"
    
    # 复制可执行文件
    cp ".build/release/HelloPrompt" "$app_bundle/Contents/MacOS/"
    
    # 创建 Info.plist
    create_info_plist "$app_bundle/Contents/Info.plist"
    
    # 复制资源文件
    if [ -d "Resources" ]; then
        cp -R Resources/* "$app_bundle/Contents/Resources/"
    fi
    
    log "应用包创建完成: $app_bundle"
}

# 创建 Info.plist
create_info_plist() {
    local plist_path="$1"
    
    cat > "$plist_path" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>HelloPrompt</string>
    <key>CFBundleIdentifier</key>
    <string>com.hellprompt.app</string>
    <key>CFBundleName</key>
    <string>Hello Prompt</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Hello Prompt 需要麦克风权限来录制语音并转换为AI提示词</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Hello Prompt 需要此权限来将文本插入到当前应用</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF
}

# 代码签名
sign_app() {
    local app_bundle="$1"
    
    if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
        log "对应用进行代码签名..."
        
        codesign --force --deep --sign "Developer ID Application" "$app_bundle"
        
        # 验证签名
        codesign --verify --verbose "$app_bundle"
        
        log "代码签名完成"
    else
        log "跳过代码签名（未找到证书）"
    fi
}

# 创建 DMG
create_dmg() {
    local app_bundle="$1"
    local dmg_path="$BUILD_DIR/HelloPrompt.dmg"
    
    log "创建 DMG 安装包..."
    
    # 创建临时目录
    local temp_dir="$BUILD_DIR/dmg_temp"
    mkdir -p "$temp_dir"
    
    # 复制应用到临时目录
    cp -R "$app_bundle" "$temp_dir/"
    
    # 创建应用程序快捷方式
    ln -s /Applications "$temp_dir/Applications"
    
    # 创建 DMG
    hdiutil create -volname "Hello Prompt" \
        -srcfolder "$temp_dir" \
        -ov -format UDZO \
        "$dmg_path"
    
    # 清理临时目录
    rm -rf "$temp_dir"
    
    log "DMG 创建完成: $dmg_path"
}

# 主函数
main() {
    log "开始构建 Hello Prompt..."
    
    cleanup
    check_dependencies
    run_quality_checks
    test_audio_functionality
    build_app
    create_app_bundle
    
    local app_bundle="$BUILD_DIR/HelloPrompt.app"
    sign_app "$app_bundle"
    create_dmg "$app_bundle"
    
    log "构建完成！"
    log "应用包: $app_bundle"
    log "安装包: $BUILD_DIR/HelloPrompt.dmg"
}

# 运行主函数
main "$@"
```

### 7.2 持续集成配置

#### 7.2.1 GitHub Actions工作流
```yaml
# .github/workflows/build.yml
name: Build and Test

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Swift
      uses: swift-actions/setup-swift@v1
      with:
        swift-version: "5.10"
    
    - name: Install SwiftLint
      run: brew install swiftlint
    
    - name: Cache Swift Packages
      uses: actions/cache@v3
      with:
        path: .build
        key: ${{ runner.os }}-spm-${{ hashFiles('**/Package.resolved') }}
        restore-keys: |
          ${{ runner.os }}-spm-
    
    - name: Run SwiftLint
      run: swiftlint --strict
    
    - name: Run Tests
      run: swift test --parallel --enable-code-coverage
    
    - name: Generate Code Coverage
      run: |
        xcrun llvm-cov export -format="lcov" \
          .build/debug/HelloPromptPackageTests.xctest/Contents/MacOS/HelloPromptPackageTests \
          -instr-profile .build/debug/codecov/default.profdata > coverage.lcov
    
    - name: Upload Coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        file: ./coverage.lcov
        flags: unittests
        name: codecov-umbrella
  
  build:
    needs: test
    runs-on: macos-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Swift
      uses: swift-actions/setup-swift@v1
      with:
        swift-version: "5.10"
    
    - name: Build Release
      run: swift build -c release
    
    - name: Create App Bundle
      run: ./scripts/build.sh
    
    - name: Upload Artifacts
      uses: actions/upload-artifact@v3
      with:
        name: HelloPrompt-${{ github.sha }}
        path: build/HelloPrompt.dmg
```

---

**文档状态**：开发版本  
**最后更新**：2025-07-25  
**代码审查**：待开发团队评审

**总结**：
本文档定义了Hello Prompt项目的完整代码风格规范，特别强调了音频处理的最佳实践。主要包括：

1. **全局代码风格**：Swift编码规范、文件组织、SwiftUI视图规范
2. **音频处理最佳实践**：专业音频配置、高质量处理算法、性能优化
3. **网络请求优化**：OpenAI API优化、重试机制、数据压缩
4. **错误处理与日志**：结构化错误体系、高级日志系统、性能监控
5. **测试规范**：单元测试、性能测试、音频功能测试
6. **代码质量工具**：SwiftLint配置、代码格式化、自动化检查
7. **部署与发布**：构建脚本、持续集成、自动化流程

这套规范确保代码质量高、音频处理专业、开发效率高，同时保持项目的可维护性和扩展性。