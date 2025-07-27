//
//  AudioService.swift
//  HelloPrompt
//
//  音频录制服务 - 实现AVFoundation录音、VAD检测、音频质量控制
//  Copyright © 2025 HelloPrompt. All rights reserved.
//

import Foundation
import AVFoundation

// MARK: - 音频质量配置
struct AudioQualityConfig {
    let sampleRate: Double = 16000.0
    let channels: Int = 1
    let bitDepth: Int = 16
    let bufferSize: Int = 1024
    let format: AudioFormatID = kAudioFormatLinearPCM
}

// MARK: - VAD配置
struct VADConfig {
    let threshold: Float = 0.015         // 音量阈值（降低以提高灵敏度）
    let minSpeechDuration: TimeInterval = 0.8    // 最小语音持续时间（增加以避免误触发）
    let maxSilenceDuration: TimeInterval = 1.5   // 最大静音持续时间（增加以给用户思考时间）
    let windowSize: Int = 512            // 分析窗口大小
    let maxRecordingDuration: TimeInterval = 500.0  // 最大录音时长(秒)
}

// MARK: - 音频录制状态
enum AudioRecordingState: Equatable {
    case idle           // 空闲
    case preparing      // 准备中
    case recording      // 录音中
    case processing     // 处理中
    case completed      // 完成
    case error(Error)   // 错误
    
    static func == (lhs: AudioRecordingState, rhs: AudioRecordingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.preparing, .preparing),
             (.recording, .recording),
             (.processing, .processing),
             (.completed, .completed):
            return true
        case (.error, .error):
            return true // 简化处理，只比较状态类型
        default:
            return false
        }
    }
}

// MARK: - 音频数据结构
struct AudioData {
    let data: Data
    let duration: TimeInterval
    let sampleRate: Double
    let channels: Int
    let rmsLevel: Float
    let peakLevel: Float
    let hasVoiceActivity: Bool
}

// MARK: - 音频服务协议
@MainActor
protocol AudioServiceDelegate: AnyObject {
    func audioService(_ service: AudioService, didChangeState state: AudioRecordingState)
    func audioService(_ service: AudioService, didDetectVoiceActivity active: Bool)
    func audioService(_ service: AudioService, didUpdateLevel rms: Float, peak: Float)
    func audioService(_ service: AudioService, didCompleteRecording audioData: AudioData)
    func audioService(_ service: AudioService, didFailWithError error: Error)
}

// MARK: - 音频服务主类
@MainActor
class AudioService: NSObject {
    
    // MARK: - Properties
    weak var delegate: AudioServiceDelegate?
    
    private var audioEngine: AVAudioEngine
    private var inputNode: AVAudioInputNode
    private var audioFile: AVAudioFile?
    private var audioBuffer: AVAudioPCMBuffer?
    
    private let qualityConfig: AudioQualityConfig
    private let vadConfig: VADConfig
    
    private var currentState: AudioRecordingState = .idle {
        didSet {
            LogManager.shared.audioLog("状态变更", details: [
                "from": "\(oldValue)",
                "to": "\(currentState)"
            ])
            delegate?.audioService(self, didChangeState: currentState)
        }
    }
    
    private var recordingStartTime: Date?
    private var audioDataBuffer = Data()
    private var rmsLevels: [Float] = []
    private var peakLevels: [Float] = []
    
    // VAD 相关
    private var voiceActivityDetected = false
    private var lastVoiceActivityTime: Date?
    private var speechStartTime: Date?
    
    // 录音时长监控
    private var maxDurationTimer: Timer?
    
    // MARK: - Initialization
    override init() {
        self.audioEngine = AVAudioEngine()
        self.inputNode = audioEngine.inputNode
        self.qualityConfig = AudioQualityConfig()
        self.vadConfig = VADConfig()
        
        super.init()
        
        LogManager.shared.audioLog("AudioService基础初始化", details: [
            "sampleRate": qualityConfig.sampleRate,
            "channels": qualityConfig.channels,
            "bufferSize": qualityConfig.bufferSize
        ])
        
        setupAudioSession()
        
        // 延迟设置音频引擎，避免阻塞初始化
        Task { @MainActor in
            await setupAudioEngineAsync()
        }
    }
    
    deinit {
        cleanupSync()
    }
    
    // MARK: - Public Methods
    
    /// 开始录音
    func startRecording() {
        LogManager.shared.audioLog("开始录音请求")
        
        guard currentState == .idle else {
            LogManager.shared.warning(.audio, "录音状态无效", metadata: ["currentState": "\(currentState)"])
            return
        }
        
        currentState = .preparing
        
        Task {
            do {
                try await prepareRecording()
                try await beginRecording()
            } catch {
                LogManager.shared.trackError(error, context: "开始录音", recoveryAction: "检查麦克风权限和音频设备")
                currentState = .error(error)
                delegate?.audioService(self, didFailWithError: error)
            }
        }
    }
    
    /// 停止录音
    func stopRecording() {
        LogManager.shared.audioLog("停止录音请求")
        
        guard currentState == .recording else {
            LogManager.shared.warning(.audio, "当前未在录音", metadata: ["currentState": "\(currentState)"])
            return
        }
        
        currentState = .processing
        
        Task {
            await finishRecording()
        }
    }
    
    /// 取消录音
    func cancelRecording() {
        LogManager.shared.audioLog("取消录音")
        stopMaxDurationTimer()
        cleanup()
        currentState = .idle
    }
    
    // MARK: - Private Methods
    
    /// 设置音频会话
    private func setupAudioSession() {
        // 在macOS上，音频会话配置是自动处理的，不需要手动设置
        // 这里我们只记录一下初始化信息
        LogManager.shared.audioLog("音频会话配置成功（macOS自动处理）", details: [
            "platform": "macOS",
            "note": "音频会话由系统自动管理"
        ])
    }
    
    /// 异步设置音频引擎
    private func setupAudioEngineAsync() async {
        LogManager.shared.audioLog("🎵 音频处理: 开始异步设置音频引擎")
        
        await Task.yield() // 让出控制权
        
        do {
            try setupAudioEngine()
            LogManager.shared.audioLog("✅ 音频处理: 异步音频引擎设置完成")
        } catch {
            LogManager.shared.error(.audio, "音频引擎异步设置失败", metadata: [
                "error": error.localizedDescription
            ])
        }
    }
    
    /// 设置音频引擎
    private func setupAudioEngine() throws {
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let recordingFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                          sampleRate: qualityConfig.sampleRate,
                                          channels: AVAudioChannelCount(qualityConfig.channels),
                                          interleaved: false)!
        
        LogManager.shared.audioLog("音频格式配置", details: [
            "inputSampleRate": inputFormat.sampleRate,
            "inputChannels": inputFormat.channelCount,
            "recordingSampleRate": recordingFormat.sampleRate,
            "recordingChannels": recordingFormat.channelCount
        ])
        
        // 确保在安装新tap之前移除任何现有的tap
        do {
            inputNode.removeTap(onBus: 0)
            LogManager.shared.audioLog("清理现有的音频tap")
        } catch {
            // 如果没有现有tap，这是正常的
            LogManager.shared.debug(.audio, "没有现有tap需要清理")
        }
        
        // 使用硬件输入格式安装tap，避免格式不匹配错误
        do {
            inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(qualityConfig.bufferSize), format: inputFormat) { [weak self] buffer, time in
                Task { @MainActor in
                    await self?.processAudioBuffer(buffer, at: time, targetFormat: recordingFormat)
                }
            }
            
            LogManager.shared.audioLog("音频处理节点安装成功", details: [
                "tapFormat": "使用硬件输入格式 (\(inputFormat.sampleRate)Hz, \(inputFormat.channelCount)ch)",
                "targetFormat": "转换到目标格式 (\(recordingFormat.sampleRate)Hz, \(recordingFormat.channelCount)ch)"
            ])
        } catch {
            LogManager.shared.error(.audio, "安装音频处理节点失败", metadata: [
                "error": error.localizedDescription,
                "inputFormat": "\(inputFormat.sampleRate)Hz, \(inputFormat.channelCount)ch",
                "bufferSize": qualityConfig.bufferSize
            ])
            throw AudioServiceError.audioEngineFailure
        }
    }
    
    /// 准备录音
    private func prepareRecording() async throws {
        LogManager.shared.audioLog("准备录音环境")
        
        // 请求麦克风权限（macOS版本）
        let permissionGranted = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
        
        guard permissionGranted else {
            throw AudioServiceError.permissionDenied
        }
        
        // 重置录音数据
        audioDataBuffer.removeAll()
        rmsLevels.removeAll()
        peakLevels.removeAll()
        voiceActivityDetected = false
        lastVoiceActivityTime = nil
        speechStartTime = nil
        
        LogManager.shared.audioLog("录音环境准备完成", details: [
            "permission": "granted",
            "bufferCleared": true,
            "vadReset": true
        ])
    }
    
    /// 开始录音
    private func beginRecording() async throws {
        recordingStartTime = Date()
        
        // 检查音频引擎状态，确保干净的启动环境
        if audioEngine.isRunning {
            LogManager.shared.warning(.audio, "音频引擎已在运行，先停止再重新执行设置")
            audioEngine.stop()
            audioEngine.reset()
            
            // 重新设置音频引擎以确保tap正确安装
            try setupAudioEngine()
        }
        
        do {
            try audioEngine.start()
            
            // 验证音频引擎是否成功启动
            guard audioEngine.isRunning else {
                throw AudioServiceError.audioEngineFailure
            }
            
            // 获取当前输入格式信息用于日志
            let inputFormat = inputNode.outputFormat(forBus: 0)
            
            LogManager.shared.audioLog("音频引擎启动成功", details: [
                "engineRunning": audioEngine.isRunning,
                "inputFormat": "\(inputFormat.sampleRate)Hz, \(inputFormat.channelCount)ch",
                "targetFormat": "\(qualityConfig.sampleRate)Hz, \(qualityConfig.channels)ch"
            ])
            
            currentState = .recording
        } catch {
            LogManager.shared.error(.audio, "音频引擎启动失败", metadata: [
                "error": error.localizedDescription,
                "engineRunning": audioEngine.isRunning,
                "errorType": "\(type(of: error))"
            ])
            
            // 尝试重置音频引擎并重新设置
            audioEngine.reset()
            try setupAudioEngine()
            throw AudioServiceError.audioEngineFailure
        }
        
        LogManager.shared.audioLog("录音开始", details: [
            "startTime": recordingStartTime?.description ?? "unknown",
            "engineRunning": audioEngine.isRunning,
            "maxDuration": vadConfig.maxRecordingDuration
        ])
        
        // 开始VAD监听
        startVADMonitoring()
        
        // 启动最大录音时长定时器
        startMaxDurationTimer()
    }
    
    /// 处理音频缓冲区，支持格式转换
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime, targetFormat: AVAudioFormat? = nil) async {
        // 检查当前状态，只在录音状态下处理缓冲区
        guard currentState == .recording else {
            LogManager.shared.debug(.audio, "音频缓冲区处理被跳过", metadata: ["currentState": "\(currentState)"])
            return
        }
        
        guard let channelData = buffer.floatChannelData else { 
            LogManager.shared.warning(.audio, "音频缓冲区缺少通道数据")
            return 
        }
        
        let frameCount = Int(buffer.frameLength)
        var samples: [Float]
        
        // 获取输入音频格式信息
        let inputSampleRate = buffer.format.sampleRate
        let inputChannelCount = Int(buffer.format.channelCount)
        
        // 格式转换处理
        if let targetFormat = targetFormat,
           inputSampleRate != targetFormat.sampleRate || 
           inputChannelCount != Int(targetFormat.channelCount) {
            
            LogManager.shared.debug(.audio, "执行音频格式转换", metadata: [
                "输入格式": "\(inputSampleRate)Hz, \(inputChannelCount)ch",
                "目标格式": "\(targetFormat.sampleRate)Hz, \(targetFormat.channelCount)ch",
                "帧数": frameCount
            ])
            
            // 处理多声道到单声道的转换
            if inputChannelCount > 1 && Int(targetFormat.channelCount) == 1 {
                // 混合所有声道到单声道
                samples = []
                samples.reserveCapacity(frameCount)
                for i in 0..<frameCount {
                    var mixedSample: Float = 0
                    for channel in 0..<inputChannelCount {
                        mixedSample += channelData[channel][i]
                    }
                    samples.append(mixedSample / Float(inputChannelCount))
                }
                LogManager.shared.debug(.audio, "完成多声道到单声道转换", metadata: [
                    "原始声道数": inputChannelCount,
                    "转换后声道数": 1,
                    "样本数": samples.count
                ])
            } else {
                // 直接使用第一个声道
                samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
            }
            
            // 采样率转换（如果需要）
            if inputSampleRate != targetFormat.sampleRate {
                let ratio = inputSampleRate / targetFormat.sampleRate
                let targetFrameCount = Int(Double(frameCount) / ratio)
                var resampledSamples: [Float] = []
                resampledSamples.reserveCapacity(targetFrameCount)
                
                for i in 0..<targetFrameCount {
                    let sourceIndex = Int(Double(i) * ratio)
                    if sourceIndex < samples.count {
                        resampledSamples.append(samples[sourceIndex])
                    }
                }
                samples = resampledSamples
                
                LogManager.shared.debug(.audio, "完成采样率转换", metadata: [
                    "原始采样率": inputSampleRate,
                    "目标采样率": targetFormat.sampleRate,
                    "原始帧数": frameCount,
                    "转换后帧数": samples.count
                ])
            }
        } else {
            // 无需格式转换，直接使用第一个声道
            samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
        }
        
        // 计算音频级别
        let rms = calculateRMS(samples: samples)
        let peak = calculatePeak(samples: samples)
        
        rmsLevels.append(rms)
        peakLevels.append(peak)
        
        // VAD检测
        let voiceActive = detectVoiceActivity(rms: rms, peak: peak)
        
        // 检查自动停止条件
        await checkAutoStopCondition(voiceActive: voiceActive)
        
        // 通知代理音频级别更新
        delegate?.audioService(self, didUpdateLevel: rms, peak: peak)
        
        // 如果检测到语音活动变化，通知代理
        if voiceActive != voiceActivityDetected {
            voiceActivityDetected = voiceActive
            delegate?.audioService(self, didDetectVoiceActivity: voiceActive)
            
            LogManager.shared.audioLog("VAD状态变更", details: [
                "voiceActive": voiceActive,
                "rms": rms,
                "peak": peak,
                "threshold": vadConfig.threshold
            ])
        }
        
        // 将处理后的音频数据添加到缓冲区
        let data = Data(bytes: samples, count: samples.count * MemoryLayout<Float>.size)
        audioDataBuffer.append(data)
        
        // 性能监控
        if rmsLevels.count % 100 == 0 {
            let avgRMS = rmsLevels.suffix(100).reduce(0, +) / 100
            LogManager.shared.performanceLog("音频处理", duration: 0.001, details: [
                "bufferSize": frameCount,
                "avgRMS": avgRMS,
                "dataSize": audioDataBuffer.count
            ])
        }
    }
    
    /// 完成录音
    private func finishRecording() async {
        LogManager.shared.audioLog("开始完成录音处理")
        
        // 安全停止音频引擎
        if audioEngine.isRunning {
            audioEngine.stop()
            LogManager.shared.audioLog("音频引擎已停止")
        } else {
            LogManager.shared.warning(.audio, "音频引擎未在运行状态")
        }
        
        // 清理定时器
        stopMaxDurationTimer()
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(recordingStartTime ?? endTime)
        
        // 计算最终统计数据
        let avgRMS = rmsLevels.isEmpty ? 0 : rmsLevels.reduce(0, +) / Float(rmsLevels.count)
        let maxPeak = peakLevels.max() ?? 0
        let hasVoice = voiceActivityDetected || speechStartTime != nil
        
        let audioData = AudioData(
            data: audioDataBuffer,
            duration: duration,
            sampleRate: qualityConfig.sampleRate,
            channels: qualityConfig.channels,
            rmsLevel: avgRMS,
            peakLevel: maxPeak,
            hasVoiceActivity: hasVoice
        )
        
        LogManager.shared.audioLog("录音完成", details: [
            "duration": String(format: "%.2fs", duration),
            "dataSize": "\(audioDataBuffer.count) bytes",
            "avgRMS": avgRMS,
            "maxPeak": maxPeak,
            "hasVoiceActivity": hasVoice,
            "sampleCount": rmsLevels.count
        ])
        
        currentState = .completed
        delegate?.audioService(self, didCompleteRecording: audioData)
        
        // 重置状态
        currentState = .idle
    }
    
    /// 开始VAD监听
    private func startVADMonitoring() {
        LogManager.shared.audioLog("开始VAD监听", details: [
            "threshold": vadConfig.threshold,
            "minSpeechDuration": vadConfig.minSpeechDuration,
            "maxSilenceDuration": vadConfig.maxSilenceDuration
        ])
    }
    
    /// VAD检测
    private func detectVoiceActivity(rms: Float, peak: Float) -> Bool {
        let isActiveNow = rms > vadConfig.threshold || peak > vadConfig.threshold * 2
        let now = Date()
        
        if isActiveNow {
            lastVoiceActivityTime = now
            if speechStartTime == nil {
                speechStartTime = now
                LogManager.shared.audioLog("检测到语音开始", details: [
                    "rms": rms,
                    "peak": peak,
                    "threshold": vadConfig.threshold
                ])
            }
        } else if let lastActivity = lastVoiceActivityTime {
            // 检查静音持续时间
            if now.timeIntervalSince(lastActivity) > vadConfig.maxSilenceDuration {
                speechStartTime = nil
            }
        }
        
        return isActiveNow
    }
    
    /// 检查自动停止条件
    private func checkAutoStopCondition(voiceActive: Bool) async {
        guard currentState == .recording else { return }
        
        let now = Date()
        
        // 如果检测到足够的语音并且当前处于静音状态
        if !voiceActive,
           let speechStart = speechStartTime,
           let lastActivity = lastVoiceActivityTime {
            
            let speechDuration = lastActivity.timeIntervalSince(speechStart)
            let silenceDuration = now.timeIntervalSince(lastActivity)
            
            // 满足自动停止条件：
            // 1. 语音持续时间超过最小阈值(0.5秒)
            // 2. 静音持续时间超过VAD配置(默认0.5秒)
            if speechDuration >= vadConfig.minSpeechDuration && 
               silenceDuration >= vadConfig.maxSilenceDuration {
                
                LogManager.shared.audioLog("VAD自动停止录音", details: [
                    "speechDuration": speechDuration,
                    "silenceDuration": silenceDuration,
                    "minSpeechDuration": vadConfig.minSpeechDuration,
                    "maxSilenceDuration": vadConfig.maxSilenceDuration
                ])
                
                // 自动停止录音
                await stopRecording()
            }
        }
        
        // 检查最大录音时长限制
        if let recordingStart = recordingStartTime {
            let recordingDuration = now.timeIntervalSince(recordingStart)
            if recordingDuration >= vadConfig.maxRecordingDuration {
                LogManager.shared.audioLog("达到最大录音时长，自动停止", details: [
                    "recordingDuration": recordingDuration,
                    "maxRecordingDuration": vadConfig.maxRecordingDuration
                ])
                
                await stopRecording()
            }
        }
    }
    
    /// 计算RMS音量
    private func calculateRMS(samples: [Float]) -> Float {
        let sum = samples.reduce(0) { $0 + $1 * $1 }
        return sqrt(sum / Float(samples.count))
    }
    
    /// 计算峰值音量
    private func calculatePeak(samples: [Float]) -> Float {
        return samples.map(abs).max() ?? 0
    }
    
    /// 启动最大录音时长定时器
    private func startMaxDurationTimer() {
        maxDurationTimer = Timer.scheduledTimer(withTimeInterval: vadConfig.maxRecordingDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.handleMaxDurationReached()
            }
        }
        
        LogManager.shared.audioLog("录音时长监控定时器启动", details: [
            "maxDuration": vadConfig.maxRecordingDuration,
            "timerScheduled": true
        ])
    }
    
    /// 停止最大录音时长定时器
    private func stopMaxDurationTimer() {
        maxDurationTimer?.invalidate()
        maxDurationTimer = nil
        
        LogManager.shared.audioLog("录音时长监控定时器已停止")
    }
    
    /// 处理达到最大录音时长
    private func handleMaxDurationReached() async {
        LogManager.shared.warning(.audio, "录音时长达到最大限制", metadata: [
            "maxDuration": vadConfig.maxRecordingDuration,
            "action": "自动停止录音"
        ])
        
        // 自动停止录音
        if currentState == .recording {
            await finishRecording()
            
            // 通知代理达到最大时长
            delegate?.audioService(self, didFailWithError: AudioServiceError.maxDurationReached)
        }
    }
    
    /// 清理资源
    private func cleanup() {
        LogManager.shared.audioLog("开始清理音频资源")
        
        // 停止音频引擎并重置状态
        if audioEngine.isRunning {
            audioEngine.stop()
            LogManager.shared.audioLog("音频引擎已停止")
        }
        
        // 安全移除tap
        inputNode.removeTap(onBus: 0)
        LogManager.shared.audioLog("音频tap已移除")
        
        // 重置音频引擎以确保完全清理
        audioEngine.reset()
        LogManager.shared.audioLog("音频引擎已重置")
        
        // 清理定时器
        stopMaxDurationTimer()
        
        // 清理音频数据缓冲区
        audioDataBuffer.removeAll(keepingCapacity: false) // 释放内存
        rmsLevels.removeAll(keepingCapacity: false)
        peakLevels.removeAll(keepingCapacity: false)
        
        // 重置VAD状态
        voiceActivityDetected = false
        lastVoiceActivityTime = nil
        speechStartTime = nil
        recordingStartTime = nil
        
        LogManager.shared.audioLog("音频资源清理完成", details: [
            "bufferCleared": true,
            "levelsCleared": true,
            "vadReset": true,
            "timersCleared": true
        ])
    }
    
    /// 同步清理方法，用于deinit
    nonisolated private func cleanupSync() {
        Task { @MainActor in
            if audioEngine.isRunning {
                audioEngine.stop()
            }
            inputNode.removeTap(onBus: 0)
            audioDataBuffer.removeAll()
            rmsLevels.removeAll()
            peakLevels.removeAll()
            
            LogManager.shared.audioLog("音频资源清理完成（同步）")
        }
    }
}

// MARK: - 音频服务错误类型
enum AudioServiceError: LocalizedError {
    case permissionDenied
    case audioEngineFailure
    case recordingFailed
    case invalidAudioFormat
    case maxDurationReached
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "麦克风权限被拒绝"
        case .audioEngineFailure:
            return "音频引擎启动失败"
        case .recordingFailed:
            return "录音过程中出现错误"
        case .invalidAudioFormat:
            return "不支持的音频格式"
        case .maxDurationReached:
            return "录音时长超过最大限制(500秒)，已自动停止"
        }
    }
}