//
//  MemoryManager.swift
//  HelloPrompt
//
//  内存管理器 - 监控和优化内存使用
//  提供内存压力检测和自动清理机制
//

import Foundation
import os

// MARK: - 内存管理器
@MainActor
public final class MemoryManager: ObservableObject {
    
    // MARK: - 单例
    public static let shared = MemoryManager()
    
    // MARK: - 发布属性
    @Published public var currentMemoryUsage: UInt64 = 0
    @Published public var memoryPressureLevel: MemoryPressureLevel = .normal
    @Published public var isMemoryWarningActive = false
    
    // MARK: - 内存压力级别
    public enum MemoryPressureLevel: String, CaseIterable {
        case normal = "正常"
        case warning = "警告"
        case critical = "严重"
        
        var thresholdMB: Double {
            switch self {
            case .normal: return 500    // 500MB以下
            case .warning: return 800   // 500-800MB
            case .critical: return 1000 // 800MB以上
            }
        }
        
        var cleanupStrategy: CleanupStrategy {
            switch self {
            case .normal: return .none
            case .warning: return .moderate
            case .critical: return .aggressive
            }
        }
    }
    
    // MARK: - 清理策略
    public enum CleanupStrategy {
        case none
        case moderate
        case aggressive
    }
    
    // MARK: - 私有属性
    private var memoryMonitorTimer: Timer?
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    private let monitorQueue = DispatchQueue(label: "com.helloprompt.memory", qos: .utility)
    
    // 内存统计
    private var memoryHistory: [UInt64] = []
    private let maxHistoryCount = 60 // 保留60个记录（约1分钟）
    
    // MARK: - 初始化
    private init() {
        setupMemoryMonitoring()
        setupMemoryPressureMonitoring()
        LogManager.shared.info("MemoryManager", "内存管理器初始化完成")
    }
    
    // MARK: - 私有方法
    
    private func setupMemoryMonitoring() {
        // 每秒监控一次内存使用
        memoryMonitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMemoryUsage()
            }
        }
    }
    
    private func setupMemoryPressureMonitoring() {
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: .all, queue: monitorQueue)
        
        memoryPressureSource?.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.handleMemoryPressure()
            }
        }
        
        memoryPressureSource?.resume()
    }
    
    private func updateMemoryUsage() {
        let usage = getCurrentMemoryUsage()
        currentMemoryUsage = usage
        
        // 更新历史记录
        memoryHistory.append(usage)
        if memoryHistory.count > maxHistoryCount {
            memoryHistory.removeFirst()
        }
        
        // 更新压力级别
        updateMemoryPressureLevel(usage)
        
        // 根据压力级别执行清理
        executeCleanupIfNeeded()
    }
    
    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? info.resident_size : 0
    }
    
    private func updateMemoryPressureLevel(_ usage: UInt64) {
        let usageMB = Double(usage) / (1024 * 1024)
        
        let newLevel: MemoryPressureLevel
        if usageMB < MemoryPressureLevel.normal.thresholdMB {
            newLevel = .normal
        } else if usageMB < MemoryPressureLevel.warning.thresholdMB {
            newLevel = .warning
        } else {
            newLevel = .critical
        }
        
        if newLevel != memoryPressureLevel {
            let oldLevel = memoryPressureLevel
            memoryPressureLevel = newLevel
            
            LogManager.shared.info("MemoryManager", "内存压力级别变化: \(oldLevel.rawValue) -> \(newLevel.rawValue), 当前使用: \(String(format: "%.1f", usageMB))MB")
            
            // 触发内存警告
            if newLevel == .critical && !isMemoryWarningActive {
                isMemoryWarningActive = true
                triggerMemoryWarning()
            } else if newLevel == .normal && isMemoryWarningActive {
                isMemoryWarningActive = false
            }
        }
    }
    
    private func executeCleanupIfNeeded() {
        let strategy = memoryPressureLevel.cleanupStrategy
        
        switch strategy {
        case .none:
            break
        case .moderate:
            performModerateCleanup()
        case .aggressive:
            performAggressiveCleanup()
        }
    }
    
    private func performModerateCleanup() {
        LogManager.shared.info("MemoryManager", "执行适度内存清理")
        
        // 清理音频缓冲区池中的未使用缓冲区
        AudioBufferPool.shared.cleanupUnusedBuffers()
        
        // 清理日志历史
        LogManager.shared.clearLogs()
        
        // 清理性能统计
        AudioProcessingOptimizer.shared.clearPerformanceStats()
    }
    
    private func performAggressiveCleanup() {
        LogManager.shared.warning("MemoryManager", "执行积极内存清理")
        
        // 执行适度清理
        performModerateCleanup()
        
        // 紧急清理音频缓冲区池
        AudioBufferPool.shared.emergencyCleanup()
        
        // 强制垃圾回收（如果可能）
        // 注意：在现代Swift中，这主要依赖于ARC
        
        // 降低动画质量以减少内存使用
        AnimationPerformanceOptimizer.shared.setAnimationQuality(.low)
    }
    
    private func handleMemoryPressure() {
        LogManager.shared.warning("MemoryManager", "系统内存压力事件触发")
        
        // 立即执行积极清理
        performAggressiveCleanup()
        
        // 更新内存使用状态
        updateMemoryUsage()
    }
    
    private func triggerMemoryWarning() {
        LogManager.shared.warning("MemoryManager", "内存使用警告激活")
        
        // 发送通知给其他组件
        NotificationCenter.default.post(name: .memoryWarning, object: nil)
    }
    
    // MARK: - 公共方法
    
    /// 获取内存使用统计
    public func getMemoryStats() -> [String: Any] {
        let usageMB = Double(currentMemoryUsage) / (1024 * 1024)
        let avgUsage = memoryHistory.isEmpty ? 0 : memoryHistory.reduce(0, +) / UInt64(memoryHistory.count)
        let avgUsageMB = Double(avgUsage) / (1024 * 1024)
        
        let audioBufferStats = AudioBufferPool.shared.getMemoryUsage()
        
        return [
            "currentUsageMB": String(format: "%.1f", usageMB),
            "averageUsageMB": String(format: "%.1f", avgUsageMB),
            "pressureLevel": memoryPressureLevel.rawValue,
            "isWarningActive": isMemoryWarningActive,
            "audioBufferCount": audioBufferStats.totalBuffers,
            "audioBufferMemoryMB": String(format: "%.1f", audioBufferStats.estimatedMemoryMB),
            "historyCount": memoryHistory.count
        ]
    }
    
    /// 手动触发内存清理
    public func manualCleanup() {
        LogManager.shared.info("MemoryManager", "手动触发内存清理")
        performModerateCleanup()
        updateMemoryUsage()
    }
    
    /// 紧急内存清理
    public func emergencyCleanup() {
        LogManager.shared.warning("MemoryManager", "紧急内存清理")
        performAggressiveCleanup()
        updateMemoryUsage()
    }
    
    /// 获取内存使用趋势
    public func getMemoryTrend() -> MemoryTrend {
        guard memoryHistory.count >= 10 else { return .stable }
        
        let recent = Array(memoryHistory.suffix(10))
        let old = Array(memoryHistory.prefix(10))
        
        let recentAvg = recent.reduce(0, +) / UInt64(recent.count)
        let oldAvg = old.reduce(0, +) / UInt64(old.count)
        
        let changePercent = Double(Int64(recentAvg) - Int64(oldAvg)) / Double(oldAvg) * 100
        
        if changePercent > 10 {
            return .increasing
        } else if changePercent < -10 {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    /// 清理资源
    public func cleanup() {
        memoryMonitorTimer?.invalidate()
        memoryMonitorTimer = nil
        
        memoryPressureSource?.cancel()
        memoryPressureSource = nil
        
        memoryHistory.removeAll()
        
        LogManager.shared.info("MemoryManager", "内存管理器已清理")
    }
    
    deinit {
        // cleanup() 需要在MainActor上下文中执行，deinit中不安全
        // 资源清理将由系统处理
    }
}

// MARK: - 内存使用趋势
public enum MemoryTrend: String {
    case increasing = "上升"
    case stable = "稳定"
    case decreasing = "下降"
    
    var color: String {
        switch self {
        case .increasing: return "red"
        case .stable: return "green"
        case .decreasing: return "blue"
        }
    }
}

// MARK: - 通知扩展
extension Notification.Name {
    static let memoryWarning = Notification.Name("HelloPrompt.MemoryWarning")
}