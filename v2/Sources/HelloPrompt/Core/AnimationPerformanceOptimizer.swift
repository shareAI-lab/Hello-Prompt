//
//  AnimationPerformanceOptimizer.swift
//  HelloPrompt
//
//  动画性能优化器 - 智能调整动画质量和持续时间
//  基于系统性能动态优化UI动画体验
//

import Foundation
import SwiftUI

// MARK: - 动画性能优化器主类
@MainActor
public final class AnimationPerformanceOptimizer: ObservableObject {
    
    // MARK: - 单例
    public static let shared = AnimationPerformanceOptimizer()
    
    // MARK: - 发布属性
    @Published public var isAnimationEnabled = true
    @Published public var animationQuality: AnimationQuality = .high
    @Published public var currentFrameRate: Double = 60.0
    
    // MARK: - 动画质量级别
    public enum AnimationQuality: String, CaseIterable {
        case low = "低"
        case medium = "中"
        case high = "高"
        case adaptive = "自适应"
        
        var maxFrameRate: Double {
            switch self {
            case .low: return 30.0
            case .medium: return 45.0
            case .high: return 60.0
            case .adaptive: return 120.0 // 根据系统能力动态调整
            }
        }
        
        var enableComplexAnimations: Bool {
            switch self {
            case .low: return false
            case .medium, .high, .adaptive: return true
            }
        }
        
        var animationDurationMultiplier: Double {
            switch self {
            case .low: return 0.5 // 更快的动画
            case .medium: return 0.75
            case .high: return 1.0
            case .adaptive: return 1.0 // 动态调整
            }
        }
    }
    
    // MARK: - 性能监控
    private struct PerformanceMetrics {
        var averageFrameTime: TimeInterval = 0
        var droppedFrames: Int = 0
        var totalFrames: Int = 0
        var lastFrameTime: CFTimeInterval = 0
        
        var frameRate: Double {
            guard averageFrameTime > 0 else { return 60.0 }
            return 1.0 / averageFrameTime
        }
        
        var dropRate: Double {
            guard totalFrames > 0 else { return 0.0 }
            return Double(droppedFrames) / Double(totalFrames)
        }
    }
    
    private var performanceMetrics = PerformanceMetrics()
    private var performanceTimer: Timer?
    
    // MARK: - 初始化
    private init() {
        setupPerformanceMonitoring()
        LogManager.shared.info("AnimationPerformanceOptimizer", "动画性能优化器初始化完成")
    }
    
    deinit {
        performanceTimer?.invalidate()
    }
    
    // MARK: - 主要优化方法
    
    /// 获取优化后的动画持续时间
    public func getOptimizedAnimationDuration(_ baseDuration: TimeInterval) -> TimeInterval {
        guard isAnimationEnabled else { return 0.0 }
        
        let qualityMultiplier = animationQuality.animationDurationMultiplier
        let performanceMultiplier = calculatePerformanceMultiplier()
        
        return baseDuration * qualityMultiplier * performanceMultiplier
    }
    
    /// 获取优化后的动画曲线
    public func getOptimizedAnimationCurve() -> Animation {
        guard isAnimationEnabled else { return .linear(duration: 0) }
        
        switch animationQuality {
        case .low:
            return .linear
        case .medium:
            return .easeInOut
        case .high:
            return .spring(response: 0.6, dampingFraction: 0.8)
        case .adaptive:
            return currentFrameRate > 45 ? 
                .spring(response: 0.6, dampingFraction: 0.8) : 
                .easeInOut
        }
    }
    
    /// 检查是否应该启用复杂动画
    public func shouldEnableComplexAnimations() -> Bool {
        return isAnimationEnabled && 
               animationQuality.enableComplexAnimations && 
               currentFrameRate > 30.0
    }
    
    /// 获取优化后的粒子数量
    public func getOptimizedParticleCount(_ baseCount: Int) -> Int {
        guard isAnimationEnabled else { return 0 }
        
        switch animationQuality {
        case .low:
            return max(1, baseCount / 4)
        case .medium:
            return max(1, baseCount / 2)
        case .high:
            return baseCount
        case .adaptive:
            return currentFrameRate > 45 ? baseCount : max(1, baseCount / 2)
        }
    }
    
    /// 设置动画质量
    public func setAnimationQuality(_ quality: AnimationQuality) {
        animationQuality = quality
        LogManager.shared.info("AnimationPerformanceOptimizer", "动画质量设置为: \(quality.rawValue)")
        
        // 如果是自适应模式，立即调整性能设置
        if quality == .adaptive {
            updateAdaptiveSettings()
        }
    }
    
    /// 启用/禁用动画
    public func setAnimationEnabled(_ enabled: Bool) {
        isAnimationEnabled = enabled
        LogManager.shared.info("AnimationPerformanceOptimizer", "动画: \(enabled ? "已启用" : "已禁用")")
    }
    
    // MARK: - 性能监控
    
    /// 设置性能监控
    private func setupPerformanceMonitoring() {
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePerformanceMetrics()
            }
        }
    }
    
    /// 更新性能指标
    private func updatePerformanceMetrics() {
        let currentTime = CACurrentMediaTime()
        
        if performanceMetrics.lastFrameTime > 0 {
            let frameTime = currentTime - performanceMetrics.lastFrameTime
            
            // 更新平均帧时间（使用指数移动平均）
            let alpha: Double = 0.1
            if performanceMetrics.averageFrameTime == 0 {
                performanceMetrics.averageFrameTime = frameTime
            } else {
                performanceMetrics.averageFrameTime = alpha * frameTime + (1 - alpha) * performanceMetrics.averageFrameTime
            }
            
            // 检测掉帧
            let expectedFrameTime = 1.0 / animationQuality.maxFrameRate
            if frameTime > expectedFrameTime * 1.5 {
                performanceMetrics.droppedFrames += 1
            }
            
            performanceMetrics.totalFrames += 1
        }
        
        performanceMetrics.lastFrameTime = currentTime
        currentFrameRate = performanceMetrics.frameRate
        
        // 自适应质量调整
        if animationQuality == .adaptive {
            updateAdaptiveSettings()
        }
    }
    
    /// 更新自适应设置
    private func updateAdaptiveSettings() {
        let dropRate = performanceMetrics.dropRate
        let frameRate = performanceMetrics.frameRate
        
        // 基于性能指标调整设置
        if dropRate > 0.1 || frameRate < 30 {
            // 性能不佳，降低质量
            LogManager.shared.debug("AnimationPerformanceOptimizer", "检测到性能不佳，降低动画质量")
        } else if dropRate < 0.02 && frameRate > 55 {
            // 性能良好，可以提升质量
            LogManager.shared.debug("AnimationPerformanceOptimizer", "检测到性能良好，可以提升动画质量")
        }
    }
    
    /// 计算性能乘数
    private func calculatePerformanceMultiplier() -> Double {
        let dropRate = performanceMetrics.dropRate
        let frameRate = performanceMetrics.frameRate
        
        // 基于掉帧率和帧率计算性能乘数
        if dropRate > 0.1 {
            return 0.5 // 严重掉帧，加速动画
        } else if dropRate > 0.05 {
            return 0.75 // 轻微掉帧，略微加速
        } else if frameRate > 55 {
            return 1.0 // 性能良好，保持原速
        } else if frameRate > 30 {
            return 0.8 // 帧率稍低，略微加速
        } else {
            return 0.5 // 帧率很低，明显加速
        }
    }
    
    // MARK: - 具体优化方法
    
    /// 优化窗口动画
    public func optimizeWindowAnimation() -> (duration: TimeInterval, curve: Animation) {
        let baseDuration: TimeInterval = 0.3
        let optimizedDuration = getOptimizedAnimationDuration(baseDuration)
        let optimizedCurve = getOptimizedAnimationCurve()
        
        return (duration: optimizedDuration, curve: optimizedCurve)
    }
    
    /// 优化光球动画
    public func optimizeOrbAnimation() -> (duration: TimeInterval, enableParticles: Bool, particleCount: Int) {
        let baseDuration: TimeInterval = 0.8
        let baseParticleCount = 20
        
        let optimizedDuration = getOptimizedAnimationDuration(baseDuration)
        let enableParticles = shouldEnableComplexAnimations()
        let particleCount = getOptimizedParticleCount(baseParticleCount)
        
        return (duration: optimizedDuration, enableParticles: enableParticles, particleCount: particleCount)
    }
    
    /// 优化过渡动画
    public func optimizeTransitionAnimation() -> (duration: TimeInterval, enableBlur: Bool) {
        let baseDuration: TimeInterval = 0.25
        let optimizedDuration = getOptimizedAnimationDuration(baseDuration)
        let enableBlur = shouldEnableComplexAnimations()
        
        return (duration: optimizedDuration, enableBlur: enableBlur)
    }
    
    // MARK: - 性能报告
    
    /// 获取性能报告
    public func getPerformanceReport() -> AnimationPerformanceReport {
        return AnimationPerformanceReport(
            currentFrameRate: currentFrameRate,
            averageFrameTime: performanceMetrics.averageFrameTime * 1000, // 转换为毫秒
            dropRate: performanceMetrics.dropRate * 100, // 转换为百分比
            totalFrames: performanceMetrics.totalFrames,
            droppedFrames: performanceMetrics.droppedFrames,
            animationQuality: animationQuality,
            isOptimizationActive: animationQuality == .adaptive,
            recommendations: generatePerformanceRecommendations()
        )
    }
    
    /// 生成性能建议
    private func generatePerformanceRecommendations() -> [String] {
        var recommendations: [String] = []
        
        let dropRate = performanceMetrics.dropRate
        let frameRate = performanceMetrics.frameRate
        
        if dropRate > 0.1 {
            recommendations.append("检测到严重掉帧，建议降低动画质量")
        }
        
        if frameRate < 30 {
            recommendations.append("帧率较低，建议启用性能优化模式")
        }
        
        if animationQuality == .high && dropRate > 0.05 {
            recommendations.append("当前质量设置可能过高，建议切换到自适应模式")
        }
        
        if frameRate > 55 && animationQuality == .low {
            recommendations.append("系统性能良好，可以提升动画质量")
        }
        
        if recommendations.isEmpty {
            recommendations.append("动画性能良好")
        }
        
        return recommendations
    }
    
    /// 重置性能统计
    public func resetPerformanceMetrics() {
        performanceMetrics = PerformanceMetrics()
        LogManager.shared.info("AnimationPerformanceOptimizer", "性能统计已重置")
    }
}

// MARK: - 性能报告结构
public struct AnimationPerformanceReport {
    public let currentFrameRate: Double
    public let averageFrameTime: TimeInterval // 毫秒
    public let dropRate: Double // 百分比
    public let totalFrames: Int
    public let droppedFrames: Int
    public let animationQuality: AnimationPerformanceOptimizer.AnimationQuality
    public let isOptimizationActive: Bool
    public let recommendations: [String]
    
    public init(
        currentFrameRate: Double,
        averageFrameTime: TimeInterval,
        dropRate: Double,
        totalFrames: Int,
        droppedFrames: Int,
        animationQuality: AnimationPerformanceOptimizer.AnimationQuality,
        isOptimizationActive: Bool,
        recommendations: [String]
    ) {
        self.currentFrameRate = currentFrameRate
        self.averageFrameTime = averageFrameTime
        self.dropRate = dropRate
        self.totalFrames = totalFrames
        self.droppedFrames = droppedFrames
        self.animationQuality = animationQuality
        self.isOptimizationActive = isOptimizationActive
        self.recommendations = recommendations
    }
}