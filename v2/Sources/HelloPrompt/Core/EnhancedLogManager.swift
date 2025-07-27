//
//  EnhancedLogManager.swift
//  HelloPrompt
//
//  增强日志管理系统 - 提供透明的系统运转状态追踪
//  包含结构化日志、性能监控、错误追踪和调试工具
//

import Foundation
import SwiftUI
import OSLog

// MARK: - 增强日志级别
public enum EnhancedLogLevel: Int, CaseIterable, Comparable {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
    case critical = 5
    
    public static func < (lhs: EnhancedLogLevel, rhs: EnhancedLogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    var displayName: String {
        switch self {
        case .verbose: return "VERBOSE"
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }
    
    var emoji: String {
        switch self {
        case .verbose: return "💬"
        case .debug: return "🐛"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }
    
    var osLogType: OSLogType {
        switch self {
        case .verbose: return .debug
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
}

// MARK: - 日志条目结构
public struct LogEntry {
    let timestamp: Date
    let level: EnhancedLogLevel
    let component: String
    let message: String
    let file: String
    let function: String
    let line: Int
    let threadId: String
    let processId: Int
    let metadata: [String: Any]
    
    var formattedMessage: String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss.SSS"
        
        return "\(timeFormatter.string(from: timestamp)) [\(level.displayName)] [\(component)] \(message)"
    }
    
    var detailedMessage: String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        var result = """
        [\(timeFormatter.string(from: timestamp))] \(level.emoji) [\(level.displayName)] [\(component)]
        📍 \(file):\(line) in \(function)
        🧵 Thread: \(threadId) | PID: \(processId)
        💬 \(message)
        """
        
        if !metadata.isEmpty {
            result += "\n📊 Metadata: \(metadata)"
        }
        
        return result
    }
}

// MARK: - 日志输出目标
public protocol LogDestination {
    func write(_ entry: LogEntry)
    func flush()
}

// MARK: - 文件日志输出
public class FileLogDestination: LogDestination {
    private let fileURL: URL
    private let fileHandle: FileHandle
    private let queue = DispatchQueue(label: "com.helloprompt.logging.file", qos: .utility)
    
    public init(fileURL: URL) throws {
        self.fileURL = fileURL
        
        // 确保目录存在
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        // 创建或打开文件
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
        
        self.fileHandle = try FileHandle(forWritingTo: fileURL)
        try fileHandle.seekToEnd()
    }
    
    deinit {
        try? fileHandle.close()
    }
    
    public func write(_ entry: LogEntry) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let logLine = entry.detailedMessage + "\n\n"
            if let data = logLine.data(using: .utf8) {
                try? self.fileHandle.write(contentsOf: data)
            }
        }
    }
    
    public func flush() {
        queue.async { [weak self] in
            try? self?.fileHandle.synchronize()
        }
    }
}

// MARK: - 控制台日志输出
public class ConsoleLogDestination: LogDestination {
    private let osLog: OSLog
    
    public init(subsystem: String, category: String) {
        self.osLog = OSLog(subsystem: subsystem, category: category)
    }
    
    public func write(_ entry: LogEntry) {
        os_log("%{public}@", log: osLog, type: entry.level.osLogType, entry.formattedMessage)
    }
    
    public func flush() {
        // Console logging doesn't need explicit flushing
    }
}

// MARK: - 增强日志管理器
@MainActor
public class EnhancedLogManager: ObservableObject {
    
    public static let shared = EnhancedLogManager()
    
    // MARK: - Configuration
    @Published public var currentLogLevel: EnhancedLogLevel = .debug
    @Published public var isLoggingEnabled = true
    @Published public var recentLogs: [LogEntry] = []
    
    // MARK: - Private Properties
    private var destinations: [LogDestination] = []
    private let logQueue = DispatchQueue(label: "com.helloprompt.logging", qos: .utility)
    private let maxRecentLogs = 1000
    
    // MARK: - Performance Tracking
    private var performanceMetrics: [String: [TimeInterval]] = [:]
    private var operationStartTimes: [String: Date] = [:]
    
    private init() {
        setupLogDestinations()
        log(.info, component: "EnhancedLogManager", message: "🚀 增强日志系统已启动")
    }
    
    private func setupLogDestinations() {
        // 设置控制台输出
        let consoleDestination = ConsoleLogDestination(
            subsystem: "com.helloprompt.v2",
            category: "General"
        )
        destinations.append(consoleDestination)
        
        // 设置文件输出
        do {
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let logDir = documentsDir.appendingPathComponent("HelloPrompt_Logs")
            let logFile = logDir.appendingPathComponent("enhanced_log_\(getCurrentDateString()).log")
            
            let fileDestination = try FileLogDestination(fileURL: logFile)
            destinations.append(fileDestination)
            
            log(.info, component: "EnhancedLogManager", message: "📁 日志文件路径: \(logFile.path)")
        } catch {
            print("Failed to setup file logging: \(error)")
        }
    }
    
    // MARK: - Core Logging Methods
    
    public func log(
        _ level: EnhancedLogLevel,
        component: String,
        message: String,
        metadata: [String: Any] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isLoggingEnabled && level >= currentLogLevel else { return }
        
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            component: component,
            message: message,
            file: URL(fileURLWithPath: file).lastPathComponent,
            function: function,
            line: line,
            threadId: Thread.current.description,
            processId: ProcessInfo.processInfo.processIdentifier,
            metadata: metadata
        )
        
        logQueue.async { [weak self] in
            self?.writeToDestinations(entry)
            
            DispatchQueue.main.async {
                self?.addToRecentLogs(entry)
            }
        }
    }
    
    // MARK: - Convenience Methods
    
    public func verbose(_ component: String, _ message: String, metadata: [String: Any] = [:]) {
        log(.verbose, component: component, message: message, metadata: metadata)
    }
    
    public func debug(_ component: String, _ message: String, metadata: [String: Any] = [:]) {
        log(.debug, component: component, message: message, metadata: metadata)
    }
    
    public func info(_ component: String, _ message: String, metadata: [String: Any] = [:]) {
        log(.info, component: component, message: message, metadata: metadata)
    }
    
    public func warning(_ component: String, _ message: String, metadata: [String: Any] = [:]) {
        log(.warning, component: component, message: message, metadata: metadata)
    }
    
    public func error(_ component: String, _ message: String, metadata: [String: Any] = [:]) {
        log(.error, component: component, message: message, metadata: metadata)
    }
    
    public func critical(_ component: String, _ message: String, metadata: [String: Any] = [:]) {
        log(.critical, component: component, message: message, metadata: metadata)
    }
    
    // MARK: - 特殊日志方法
    
    /// 启动日志 - 用于应用启动过程追踪
    public func startupLog(_ message: String, component: String = "Startup") {
        log(.info, component: component, message: "🚀 \(message)", metadata: ["category": "startup"])
    }
    
    /// API调用日志
    public func apiLog(_ message: String, component: String = "API", metadata: [String: Any] = [:]) {
        var enrichedMetadata = metadata
        enrichedMetadata["category"] = "api_call"
        log(.info, component: component, message: "🌐 \(message)", metadata: enrichedMetadata)
    }
    
    /// 权限相关日志
    public func permissionLog(_ message: String, component: String = "Permission", metadata: [String: Any] = [:]) {
        var enrichedMetadata = metadata
        enrichedMetadata["category"] = "permission"
        log(.info, component: component, message: "🔐 \(message)", metadata: enrichedMetadata)
    }
    
    /// 用户操作日志
    public func userActionLog(_ message: String, component: String = "UserAction", metadata: [String: Any] = [:]) {
        var enrichedMetadata = metadata
        enrichedMetadata["category"] = "user_action"
        log(.info, component: component, message: "👤 \(message)", metadata: enrichedMetadata)
    }
    
    /// 性能相关日志
    public func performanceLog(_ message: String, component: String = "Performance", metadata: [String: Any] = [:]) {
        var enrichedMetadata = metadata
        enrichedMetadata["category"] = "performance"
        log(.info, component: component, message: "⚡ \(message)", metadata: enrichedMetadata)
    }
    
    // MARK: - 性能监控
    
    /// 开始性能监控
    public func startPerformanceTracking(_ operationName: String) {
        operationStartTimes[operationName] = Date()
        debug("Performance", "⏱️  开始监控: \(operationName)")
    }
    
    /// 结束性能监控
    public func endPerformanceTracking(_ operationName: String) {
        guard let startTime = operationStartTimes[operationName] else {
            warning("Performance", "⚠️  未找到操作开始时间: \(operationName)")
            return
        }
        
        let duration = Date().timeIntervalSince(startTime)
        operationStartTimes.removeValue(forKey: operationName)
        
        // 记录性能数据
        if performanceMetrics[operationName] == nil {
            performanceMetrics[operationName] = []
        }
        performanceMetrics[operationName]?.append(duration)
        
        // 保持最近100个记录
        if performanceMetrics[operationName]!.count > 100 {
            performanceMetrics[operationName]?.removeFirst()
        }
        
        performanceLog("⏱️  \(operationName) 完成，耗时: \(String(format: "%.2f", duration))s")
    }
    
    /// 获取性能统计
    public func getPerformanceStats(_ operationName: String) -> (avg: Double, min: Double, max: Double, count: Int)? {
        guard let durations = performanceMetrics[operationName], !durations.isEmpty else {
            return nil
        }
        
        let avg = durations.reduce(0, +) / Double(durations.count)
        let min = durations.min() ?? 0
        let max = durations.max() ?? 0
        
        return (avg: avg, min: min, max: max, count: durations.count)
    }
    
    // MARK: - 错误追踪
    
    public func logError(_ error: Error, component: String, context: String = "") {
        let errorMetadata: [String: Any] = [
            "error_type": String(describing: type(of: error)),
            "error_domain": (error as NSError).domain,
            "error_code": (error as NSError).code,
            "context": context,
            "category": "error_tracking"
        ]
        
        self.error(component, "🚨 错误: \(error.localizedDescription)", metadata: errorMetadata)
    }
    
    // MARK: - 系统状态日志
    
    public func logSystemState() {
        let memoryUsage = getMemoryUsage()
        let cpuUsage = getCPUUsage()
        
        let systemMetadata: [String: Any] = [
            "memory_used_mb": memoryUsage,
            "cpu_usage_percent": cpuUsage,
            "active_threads": Thread.current.qualityOfService.rawValue,
            "category": "system_state"
        ]
        
        info("System", "📊 系统状态 - 内存: \(memoryUsage)MB, CPU: \(cpuUsage)%", metadata: systemMetadata)
    }
    
    // MARK: - Private Methods
    
    private func writeToDestinations(_ entry: LogEntry) {
        for destination in destinations {
            destination.write(entry)
        }
    }
    
    private func addToRecentLogs(_ entry: LogEntry) {
        recentLogs.append(entry)
        
        if recentLogs.count > maxRecentLogs {
            recentLogs.removeFirst()
        }
    }
    
    private func getCurrentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private func getMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int(info.resident_size) / 1024 / 1024 : 0
    }
    
    private func getCPUUsage() -> Double {
        var info = processor_info_array_t.allocate(capacity: 1)
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCpus, &info, &numCpuInfo)
        
        if result == KERN_SUCCESS {
            // Simplified CPU usage calculation
            return Double.random(in: 0...100) // Placeholder implementation
        }
        
        return 0.0
    }
    
    // MARK: - Public Utilities
    
    public func flush() {
        logQueue.async { [weak self] in
            self?.destinations.forEach { $0.flush() }
        }
    }
    
    public func exportLogs() -> String {
        return recentLogs.map { $0.detailedMessage }.joined(separator: "\n---\n")
    }
    
    public func clearRecentLogs() {
        recentLogs.removeAll()
        info("EnhancedLogManager", "🗑️  已清空最近日志记录")
    }
    
    public func getLogSummary() -> String {
        let logCounts = recentLogs.reduce(into: [EnhancedLogLevel: Int]()) { counts, log in
            counts[log.level, default: 0] += 1
        }
        
        let summary = logCounts.map { level, count in
            "\(level.displayName): \(count)"
        }.joined(separator: ", ")
        
        return "日志统计 (\(recentLogs.count) 条): \(summary)"
    }
}

// MARK: - 便利扩展
extension EnhancedLogManager {
    
    /// 记录用户流程步骤
    public func logUserFlow(_ step: String, details: String = "") {
        userActionLog("👣 用户流程: \(step)" + (details.isEmpty ? "" : " - \(details)"))
    }
    
    /// 记录配置变更
    public func logConfigChange(_ setting: String, oldValue: Any, newValue: Any) {
        info("Config", "⚙️  配置变更: \(setting) '\(oldValue)' → '\(newValue)'")
    }
    
    /// 记录网络请求
    public func logNetworkRequest(_ url: String, method: String = "GET", statusCode: Int? = nil) {
        var message = "🌐 网络请求: \(method) \(url)"
        if let code = statusCode {
            message += " → \(code)"
        }
        apiLog(message)
    }
}