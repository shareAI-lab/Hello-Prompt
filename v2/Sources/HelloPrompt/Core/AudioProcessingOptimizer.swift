//
//  AudioProcessingOptimizer.swift
//  HelloPrompt
//
//  音频处理优化器 - 提供SIMD加速和缓冲区管理
//  专门针对实时音频处理的性能优化
//

import Foundation
import Accelerate
import AVFoundation

// MARK: - 音频处理优化器主类
@MainActor
public final class AudioProcessingOptimizer: ObservableObject {
    
    // MARK: - 单例
    public static let shared = AudioProcessingOptimizer()
    
    // MARK: - 发布属性
    @Published public var isOptimizationEnabled = true
    @Published public var processingQuality: ProcessingQuality = .high
    
    // MARK: - 处理质量级别
    public enum ProcessingQuality: String, CaseIterable {
        case low = "低"
        case medium = "中"
        case high = "高"
        case maximum = "最高"
        
        var simdVectorSize: Int {
            switch self {
            case .low: return 2
            case .medium: return 4
            case .high: return 8
            case .maximum: return 16
            }
        }
        
        var enableAdvancedProcessing: Bool {
            switch self {
            case .low, .medium: return false
            case .high, .maximum: return true
            }
        }
    }
    
    // MARK: - 性能统计
    private struct PerformanceStats {
        var totalProcessingTime: TimeInterval = 0
        var processedBuffers: Int = 0
        var averageProcessingTime: TimeInterval {
            guard processedBuffers > 0 else { return 0 }
            return totalProcessingTime / Double(processedBuffers)
        }
    }
    
    private var performanceStats = PerformanceStats()
    
    // MARK: - 初始化
    private init() {
        LogManager.shared.info("AudioProcessingOptimizer", "音频处理优化器初始化完成")
    }
    
    // MARK: - 主要优化方法
    
    /// SIMD优化的音频增强处理
    public func enhanceAudioInPlace(_ buffer: AVAudioPCMBuffer) -> Bool {
        guard isOptimizationEnabled else { return false }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let processingTime = CFAbsoluteTimeGetCurrent() - startTime
            updatePerformanceStats(processingTime)
        }
        
        guard let channelData = buffer.floatChannelData,
              buffer.frameLength > 0 else {
            return false
        }
        
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        // 对每个通道进行SIMD优化处理
        for channel in 0..<channelCount {
            let channelPointer = channelData[channel]
            
            // 应用噪声抑制
            applyNoiseSuppressionSIMD(channelPointer, frameCount: frameCount)
            
            // 应用音量归一化
            if processingQuality.enableAdvancedProcessing {
                applyVolumeNormalizationSIMD(channelPointer, frameCount: frameCount)
            }
            
            // 应用频率均衡
            if processingQuality == .maximum {
                applyFrequencyEqualizationSIMD(channelPointer, frameCount: frameCount)
            }
        }
        
        return true
    }
    
    /// 计算音频指标（SIMD优化）
    public func calculateAudioMetricsSIMD(_ buffer: AVAudioPCMBuffer) -> AudioMetrics? {
        guard let channelData = buffer.floatChannelData,
              buffer.frameLength > 0 else {
            return nil
        }
        
        let frameCount = Int(buffer.frameLength)
        let samples = UnsafeBufferPointer(start: channelData[0], count: frameCount)
        
        // 使用Accelerate框架进行SIMD计算
        var rms: Float = 0
        var peak: Float = 0
        var mean: Float = 0
        
        // RMS计算
        vDSP_rmsqv(samples.baseAddress!, 1, &rms, vDSP_Length(frameCount))
        
        // 峰值计算
        vDSP_maxv(samples.baseAddress!, 1, &peak, vDSP_Length(frameCount))
        
        // 均值计算
        vDSP_meanv(samples.baseAddress!, 1, &mean, vDSP_Length(frameCount))
        
        // 零交叉率计算
        let zeroCrossings = calculateZeroCrossingRate(samples.baseAddress!, frameCount: frameCount)
        
        return AudioMetrics(
            rms: rms,
            peak: peak,
            mean: mean,
            zeroCrossingRate: zeroCrossings,
            frameCount: frameCount
        )
    }
    
    /// 音频质量分析
    public func analyzeAudioQuality(_ buffer: AVAudioPCMBuffer) -> AudioQualityAnalysis {
        guard let metrics = calculateAudioMetricsSIMD(buffer) else {
            return AudioQualityAnalysis(
                overallScore: 0.0,
                signalToNoiseRatio: 0.0,
                dynamicRange: 0.0,
                recommendations: ["无法分析音频质量"]
            )
        }
        
        // 信噪比估算
        let snr = estimateSignalToNoiseRatio(metrics)
        
        // 动态范围计算
        let dynamicRange = calculateDynamicRange(metrics)
        
        // 综合评分
        let overallScore = calculateOverallQualityScore(snr: snr, dynamicRange: dynamicRange, metrics: metrics)
        
        // 生成建议
        let recommendations = generateQualityRecommendations(snr: snr, dynamicRange: dynamicRange, metrics: metrics)
        
        return AudioQualityAnalysis(
            overallScore: overallScore,
            signalToNoiseRatio: snr,
            dynamicRange: dynamicRange,
            recommendations: recommendations
        )
    }
    
    // MARK: - SIMD处理方法
    
    /// SIMD噪声抑制
    private func applyNoiseSuppressionSIMD(_ samples: UnsafeMutablePointer<Float>, frameCount: Int) {
        let noiseThreshold: Float = 0.01 // 噪声阈值
        let vectorSize = processingQuality.simdVectorSize
        
        let processableFrames = (frameCount / vectorSize) * vectorSize
        
        // 处理SIMD对齐的部分
        for i in stride(from: 0, to: processableFrames, by: vectorSize) {
            let vectorPointer = samples.advanced(by: i)
            
            // 加载向量
            var inputVector = Array<Float>(UnsafeBufferPointer(start: vectorPointer, count: vectorSize))
            
            // 应用噪声门限
            for j in 0..<vectorSize {
                if abs(inputVector[j]) < noiseThreshold {
                    inputVector[j] *= 0.1 // 衰减噪声
                }
            }
            
            // 写回内存
            vectorPointer.assign(from: inputVector, count: vectorSize)
        }
        
        // 处理剩余的非对齐部分
        for i in processableFrames..<frameCount {
            if abs(samples[i]) < noiseThreshold {
                samples[i] *= 0.1
            }
        }
    }
    
    /// SIMD音量归一化
    private func applyVolumeNormalizationSIMD(_ samples: UnsafeMutablePointer<Float>, frameCount: Int) {
        // 计算当前RMS
        var currentRMS: Float = 0
        vDSP_rmsqv(samples, 1, &currentRMS, vDSP_Length(frameCount))
        
        // 目标RMS
        let targetRMS: Float = 0.3
        
        // 计算增益因子
        let gainFactor = currentRMS > 0 ? targetRMS / currentRMS : 1.0
        
        // 限制增益范围
        var clampedGain = max(0.1, min(3.0, gainFactor))
        
        // 应用增益
        vDSP_vsmul(samples, 1, &clampedGain, samples, 1, vDSP_Length(frameCount))
    }
    
    /// SIMD频率均衡
    private func applyFrequencyEqualizationSIMD(_ samples: UnsafeMutablePointer<Float>, frameCount: Int) {
        // 简化的高通滤波器（去除低频噪声）
        let cutoffFrequency: Float = 80.0 // Hz
        let sampleRate: Float = 16000.0 // Hz
        
        let alpha = cutoffFrequency / sampleRate
        var previousSample: Float = 0
        
        for i in 0..<frameCount {
            let currentSample = samples[i]
            let filteredSample = alpha * (previousSample + currentSample - previousSample)
            samples[i] = filteredSample
            previousSample = currentSample
        }
    }
    
    // MARK: - 音频分析辅助方法
    
    /// 计算零交叉率
    private func calculateZeroCrossingRate(_ samples: UnsafePointer<Float>, frameCount: Int) -> Float {
        var crossings = 0
        
        for i in 1..<frameCount {
            if (samples[i] >= 0) != (samples[i-1] >= 0) {
                crossings += 1
            }
        }
        
        return Float(crossings) / Float(frameCount - 1)
    }
    
    /// 估算信噪比
    private func estimateSignalToNoiseRatio(_ metrics: AudioMetrics) -> Float {
        // 简化的SNR计算
        let signalPower = metrics.rms * metrics.rms
        let noisePower = max(0.001, metrics.mean * metrics.mean) // 避免除零
        
        return 10 * log10(signalPower / noisePower)
    }
    
    /// 计算动态范围
    private func calculateDynamicRange(_ metrics: AudioMetrics) -> Float {
        let peakDb = 20 * log10(max(0.001, metrics.peak))
        let rmsDb = 20 * log10(max(0.001, metrics.rms))
        
        return peakDb - rmsDb
    }
    
    /// 计算综合质量评分
    private func calculateOverallQualityScore(snr: Float, dynamicRange: Float, metrics: AudioMetrics) -> Float {
        let snrScore = max(0, min(100, (snr + 20) * 2)) // SNR: -20dB~30dB映射到0~100
        let dynamicScore = max(0, min(100, dynamicRange * 5)) // 动态范围: 0~20dB映射到0~100
        let rmsScore: Float = metrics.rms > 0.01 ? 100.0 : 50.0 // RMS阈值检查
        
        return (snrScore + dynamicScore + rmsScore) / 3.0
    }
    
    /// 生成质量改进建议
    private func generateQualityRecommendations(snr: Float, dynamicRange: Float, metrics: AudioMetrics) -> [String] {
        var recommendations: [String] = []
        
        if snr < 10 {
            recommendations.append("环境噪声较大，建议使用更安静的环境录音")
        }
        
        if dynamicRange < 5 {
            recommendations.append("音频动态范围较小，建议调整麦克风增益")
        }
        
        if metrics.rms < 0.01 {
            recommendations.append("音频信号较弱，建议靠近麦克风或提高音量")
        }
        
        if metrics.rms > 0.7 {
            recommendations.append("音频信号过强，可能出现削波失真，建议降低音量")
        }
        
        if metrics.zeroCrossingRate > 0.5 {
            recommendations.append("检测到较多高频成分，建议降低环境中的高频噪声")
        }
        
        if recommendations.isEmpty {
            recommendations.append("音频质量良好")
        }
        
        return recommendations
    }
    
    // MARK: - 性能统计
    
    /// 更新性能统计
    private func updatePerformanceStats(_ processingTime: TimeInterval) {
        performanceStats.totalProcessingTime += processingTime
        performanceStats.processedBuffers += 1
    }
    
    /// 获取性能统计
    public func getPerformanceStats() -> [String: Double] {
        return [
            "averageProcessingTime": performanceStats.averageProcessingTime * 1000, // 转换为毫秒
            "totalProcessedBuffers": Double(performanceStats.processedBuffers),
            "totalProcessingTime": performanceStats.totalProcessingTime
        ]
    }
    
    /// 重置性能统计
    public func resetPerformanceStats() {
        performanceStats = PerformanceStats()
    }
    
    /// 清理性能统计（与resetPerformanceStats功能相同，提供语义别名）
    public func clearPerformanceStats() {
        resetPerformanceStats()
        LogManager.shared.info("AudioProcessingOptimizer", "性能统计已清理")
    }
    
    // MARK: - 配置方法
    
    /// 设置处理质量
    public func setProcessingQuality(_ quality: ProcessingQuality) {
        processingQuality = quality
        LogManager.shared.info("AudioProcessingOptimizer", "音频处理质量设置为: \(quality.rawValue)")
    }
    
    /// 启用/禁用优化
    public func setOptimizationEnabled(_ enabled: Bool) {
        isOptimizationEnabled = enabled
        LogManager.shared.info("AudioProcessingOptimizer", "音频处理优化: \(enabled ? "已启用" : "已禁用")")
    }
}

// MARK: - 音频指标结构
public struct AudioMetrics {
    public let rms: Float           // 均方根值
    public let peak: Float          // 峰值
    public let mean: Float          // 平均值
    public let zeroCrossingRate: Float  // 零交叉率
    public let frameCount: Int      // 帧数
    
    public init(rms: Float, peak: Float, mean: Float, zeroCrossingRate: Float, frameCount: Int) {
        self.rms = rms
        self.peak = peak
        self.mean = mean
        self.zeroCrossingRate = zeroCrossingRate
        self.frameCount = frameCount
    }
}

// MARK: - 音频质量分析结果
public struct AudioQualityAnalysis {
    public let overallScore: Float          // 综合评分 (0-100)
    public let signalToNoiseRatio: Float    // 信噪比 (dB)
    public let dynamicRange: Float          // 动态范围 (dB)
    public let recommendations: [String]    // 改进建议
    
    public init(overallScore: Float, signalToNoiseRatio: Float, dynamicRange: Float, recommendations: [String]) {
        self.overallScore = overallScore
        self.signalToNoiseRatio = signalToNoiseRatio
        self.dynamicRange = dynamicRange
        self.recommendations = recommendations
    }
}