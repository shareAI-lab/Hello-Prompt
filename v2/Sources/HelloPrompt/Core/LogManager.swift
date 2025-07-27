//
//  LogManager.swift
//  HelloPrompt
//
//  全局日志管理器 - 提供结构化、高性能的日志记录服务
//  支持分级日志、性能监控、音频处理专用日志
//

import Foundation
import OSLog
import Combine

// MARK: - 日志级别定义
public enum LogLevel: String, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .fault
        case .error: return .error
        case .critical: return .fault
        }
    }
    
    var priority: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        case .critical: return 4
        }
    }
}

// MARK: - 日志事件类型
public struct LogEvent: RawRepresentable, Hashable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    // 通用事件
    public static let appLaunched = LogEvent(rawValue: "AppLaunched")
    public static let appTerminated = LogEvent(rawValue: "AppTerminated")
    public static let configurationChanged = LogEvent(rawValue: "ConfigurationChanged")
    
    // 音频事件
    public static let audioSessionConfigured = LogEvent(rawValue: "AudioSessionConfigured")
    public static let engineSetup = LogEvent(rawValue: "EngineSetup")
    public static let recordingStarted = LogEvent(rawValue: "RecordingStarted")
    public static let recordingStopped = LogEvent(rawValue: "RecordingStopped")
    public static let vadDetected = LogEvent(rawValue: "VADDetected")
    public static let audioQualityCheck = LogEvent(rawValue: "AudioQualityCheck")
    public static let qualityCheck = LogEvent(rawValue: "QualityCheck")
    public static let formatConversion = LogEvent(rawValue: "FormatConversion")
    
    // API事件
    public static let apiRequestStarted = LogEvent(rawValue: "APIRequestStarted")
    public static let apiRequestCompleted = LogEvent(rawValue: "APIRequestCompleted")
    public static let apiRequestFailed = LogEvent(rawValue: "APIRequestFailed")
    public static let requestAttempt = LogEvent(rawValue: "RequestAttempt")
    public static let requestSuccess = LogEvent(rawValue: "RequestSuccess")
    public static let requestError = LogEvent(rawValue: "RequestError")
    public static let requestStarted = LogEvent(rawValue: "RequestStarted")
    public static let transcriptionStarted = LogEvent(rawValue: "TranscriptionStarted")
    public static let transcriptionCompleted = LogEvent(rawValue: "TranscriptionCompleted")
    public static let optimizationStarted = LogEvent(rawValue: "OptimizationStarted")
    public static let optimizationCompleted = LogEvent(rawValue: "OptimizationCompleted")
    public static let requestCompleted = LogEvent(rawValue: "RequestCompleted")
    
    // UI事件
    public static let overlayShown = LogEvent(rawValue: "OverlayShown")
    public static let overlayDismissed = LogEvent(rawValue: "OverlayDismissed")
    public static let settingsOpened = LogEvent(rawValue: "SettingsOpened")
}

// MARK: - 性能监控数据
public struct PerformanceMetrics {
    let operation: String
    let duration: TimeInterval
    let memoryUsage: UInt64
    let metadata: [String: Any]
}

// MARK: - 日志管理器主类
public final class LogManager: ObservableObject {
    
    // MARK: - 单例实例
    nonisolated public static let shared = LogManager()
    
    // MARK: - Published Properties
    @Published public var isLoggingEnabled = true
    @Published public var currentLogLevel: LogLevel = .debug  // 设置为最详细
    @Published public var recentLogs: [LogEntry] = []
    
    // MARK: - Private Properties
    private let subsystem = "com.helloprompt.app"
    private let generalLogger: Logger
    private let audioLogger: Logger
    private let apiLogger: Logger
    private let performanceLogger: Logger
    private let uiLogger: Logger
    private let hotkeyLogger: Logger
    private let startupLogger: Logger
    
    private let logQueue = DispatchQueue(label: "com.helloprompt.logging", qos: .utility)
    private var logEntries: [LogEntry] = []
    private let maxLogEntries = 5000  // 增加内存日志容量
    
    // MARK: - 文件日志相关
    private let fileLogQueue = DispatchQueue(label: "com.helloprompt.file-logging", qos: .utility)
    private var logFileURL: URL
    private var sessionStartTime: Date
    private let sessionId: String
    
    // MARK: - 日志条目结构
    public struct LogEntry: Identifiable {
        public let id = UUID()
        public let timestamp: Date
        public let level: LogLevel
        public let category: String
        public let message: String
        public let metadata: [String: Any]
        public let file: String
        public let line: Int
        public let function: String
    }
    
    // MARK: - 初始化
    private init() {
        // 初始化会话信息
        self.sessionStartTime = Date()
        self.sessionId = UUID().uuidString.prefix(8).lowercased()
        
        // 设置日志文件路径
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logsDirectory = documentsPath.appendingPathComponent("HelloPrompt_Logs")
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        
        let timestamp = ISO8601DateFormatter().string(from: sessionStartTime).replacingOccurrences(of: ":", with: "-")
        self.logFileURL = logsDirectory.appendingPathComponent("HelloPrompt_\(timestamp)_\(sessionId).log")
        
        // 初始化日志器
        self.generalLogger = Logger(subsystem: subsystem, category: "General")
        self.audioLogger = Logger(subsystem: subsystem, category: "Audio")
        self.apiLogger = Logger(subsystem: subsystem, category: "API")
        self.performanceLogger = Logger(subsystem: subsystem, category: "Performance")
        self.uiLogger = Logger(subsystem: subsystem, category: "UI")
        self.hotkeyLogger = Logger(subsystem: subsystem, category: "Hotkey")
        self.startupLogger = Logger(subsystem: subsystem, category: "Startup")
        
        setupLogConfiguration()
        writeSessionHeader()
        log(.info, category: "LogManager", "日志管理器初始化完成", metadata: [
            "sessionId": sessionId,
            "logFile": logFileURL.path
        ])
    }
    
    // MARK: - 配置设置
    private func setupLogConfiguration() {
        // 强制设置为调试级别以获取最详细的日志
        currentLogLevel = .debug
        isLoggingEnabled = true
    }
    
    // MARK: - 会话头信息
    private func writeSessionHeader() {
        let systemInfo = getSystemInfo()
        let header = """
        ================================================================================
        Hello Prompt v2 日志会话开始
        ================================================================================
        会话ID: \(sessionId)
        启动时间: \(ISO8601DateFormatter().string(from: sessionStartTime))
        系统信息: \(systemInfo["system"] ?? "未知")
        硬件: \(systemInfo["hardware"] ?? "未知")
        内存: \(systemInfo["memory"] ?? "未知")
        CPU: \(systemInfo["cpu"] ?? "未知")
        日志级别: \(currentLogLevel.rawValue)
        日志文件: \(logFileURL.path)
        ================================================================================
        """
        
        writeToFile(header)
    }
    
    private func getSystemInfo() -> [String: String] {
        let processInfo = ProcessInfo.processInfo
        var info: [String: String] = [:]
        
        info["system"] = "\(processInfo.operatingSystemVersionString)"
        info["hardware"] = processInfo.machineHardwareName ?? "未知"
        
        // 获取内存信息
        let physicalMemory = processInfo.physicalMemory
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .memory
        info["memory"] = formatter.string(fromByteCount: Int64(physicalMemory))
        
        // 获取CPU信息
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var cpuBrand = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &cpuBrand, &size, nil, 0)
        info["cpu"] = String(cString: cpuBrand)
        
        return info
    }
    
    // MARK: - 核心日志方法
    public func log(
        _ level: LogLevel,
        category: String = "General",
        _ message: String,
        metadata: [String: Any] = [:],
        file: String = #file,
        line: Int = #line,
        function: String = #function
    ) {
        guard isLoggingEnabled && level.priority >= currentLogLevel.priority else { return }
        
        let logger = getLogger(for: category)
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            metadata: metadata,
            file: URL(fileURLWithPath: file).lastPathComponent,
            line: line,
            function: function
        )
        
        // 异步记录日志，避免阻塞主线程
        logQueue.async { [weak self] in
            self?.recordLogEntry(entry, logger: logger)
        }
    }
    
    private func recordLogEntry(_ entry: LogEntry, logger: Logger) {
        // 构建详细的日志消息
        let timestamp = formatTimestamp(entry.timestamp)
        let timeFromStart = String(format: "%.3f", entry.timestamp.timeIntervalSince(sessionStartTime))
        
        var logMessage = "[\(entry.level.rawValue)] \(entry.message)"
        
        if !entry.metadata.isEmpty {
            let metadataString = entry.metadata.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            logMessage += " | \(metadataString)"
        }
        
        // 构建文件日志格式（更详细）
        let fileLogMessage = """
        [\(timestamp)] [+\(timeFromStart)s] [\(entry.level.rawValue)] [\(entry.category)] \(entry.message)
        📍 位置: \(entry.file):\(entry.line) in \(entry.function)
        \(entry.metadata.isEmpty ? "" : "📊 元数据: \(entry.metadata.map { "\($0.key)=\($0.value)" }.joined(separator: " "))")
        ----------------------------------------
        """
        
        // 输出到系统日志
        logger.log(level: entry.level.osLogType, "\(logMessage)")
        
        // 写入文件日志
        writeToFile(fileLogMessage)
        
        // 添加到内存日志
        DispatchQueue.main.async { [weak self] in
            self?.addToRecentLogs(entry)
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
    
    private func writeToFile(_ message: String) {
        fileLogQueue.async { [weak self] in
            guard let self = self else { return }
            
            let data = (message + "\n").data(using: .utf8) ?? Data()
            
            if FileManager.default.fileExists(atPath: self.logFileURL.path) {
                // 追加到现有文件
                if let fileHandle = try? FileHandle(forWritingTo: self.logFileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                // 创建新文件
                try? data.write(to: self.logFileURL)
            }
        }
    }
    
    private func addToRecentLogs(_ entry: LogEntry) {
        logEntries.append(entry)
        
        // 限制内存中的日志条目数量
        if logEntries.count > maxLogEntries {
            logEntries.removeFirst(logEntries.count - maxLogEntries)
        }
        
        // 更新最近日志（用于UI显示）
        recentLogs = Array(logEntries.suffix(50))
    }
    
    // MARK: - 便捷日志方法
    public func debug(
        _ category: String,
        _ message: String,
        metadata: [String: Any] = [:],
        file: String = #file,
        line: Int = #line,
        function: String = #function
    ) {
        log(.debug, category: category, message, metadata: metadata, file: file, line: line, function: function)
    }
    
    public func info(
        _ category: String,
        _ message: String,
        metadata: [String: Any] = [:],
        file: String = #file,
        line: Int = #line,
        function: String = #function
    ) {
        log(.info, category: category, message, metadata: metadata, file: file, line: line, function: function)
    }
    
    public func warning(
        _ category: String,
        _ message: String,
        metadata: [String: Any] = [:],
        file: String = #file,
        line: Int = #line,
        function: String = #function
    ) {
        log(.warning, category: category, message, metadata: metadata, file: file, line: line, function: function)
    }
    
    public func error(
        _ category: String,
        _ message: String,
        metadata: [String: Any] = [:],
        file: String = #file,
        line: Int = #line,
        function: String = #function
    ) {
        log(.error, category: category, message, metadata: metadata, file: file, line: line, function: function)
    }
    
    public func critical(
        _ category: String,
        _ message: String,
        metadata: [String: Any] = [:],
        file: String = #file,
        line: Int = #line,
        function: String = #function
    ) {
        log(.critical, category: category, message, metadata: metadata, file: file, line: line, function: function)
    }
    
    // MARK: - 专用日志方法
    
    /// 音频处理专用日志
    public func audioLog(
        _ event: LogEvent,
        level: LogLevel = .info,
        details: [String: Any] = [:],
        file: String = #file,
        line: Int = #line,
        function: String = #function
    ) {
        var metadata = details
        metadata["event"] = event.rawValue
        
        log(level, category: "Audio", event.rawValue, metadata: metadata, file: file, line: line, function: function)
    }
    
    /// API调用专用日志
    public func apiLog(
        _ event: LogEvent,
        level: LogLevel = .info,
        url: String? = nil,
        duration: TimeInterval? = nil,
        details: [String: Any] = [:],
        file: String = #file,
        line: Int = #line,
        function: String = #function
    ) {
        var metadata = details
        metadata["event"] = event.rawValue
        if let url = url { metadata["url"] = url }
        if let duration = duration { metadata["duration"] = String(format: "%.3fs", duration) }
        
        log(level, category: "API", event.rawValue, metadata: metadata, file: file, line: line, function: function)
    }
    
    /// 性能监控专用日志
    public func performanceLog(
        operation: String,
        duration: TimeInterval,
        memoryUsage: UInt64? = nil,
        details: [String: Any] = [:],
        file: String = #file,
        line: Int = #line,
        function: String = #function
    ) {
        var metadata = details
        metadata["operation"] = operation
        metadata["duration"] = String(format: "%.3fs", duration)
        
        if let memory = memoryUsage {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB, .useKB]
            formatter.countStyle = .memory
            metadata["memory"] = formatter.string(fromByteCount: Int64(memory))
        }
        
        log(.info, category: "Performance", "Performance: \(operation)", metadata: metadata, file: file, line: line, function: function)
    }
    
    /// UI事件专用日志
    public func uiLog(
        _ event: LogEvent,
        level: LogLevel = .info,
        details: [String: Any] = [:],
        file: String = #file,
        line: Int = #line,
        function: String = #function
    ) {
        var metadata = details
        metadata["event"] = event.rawValue
        
        log(level, category: "UI", event.rawValue, metadata: metadata, file: file, line: line, function: function)
    }
    
    /// 快捷键专用日志
    public func hotkeyLog(
        _ message: String,
        level: LogLevel = .debug,
        keyCode: Int? = nil,
        modifiers: [String] = [],
        details: [String: Any] = [:],
        file: String = #file,
        line: Int = #line,
        function: String = #function
    ) {
        var metadata = details
        if let keyCode = keyCode { metadata["keyCode"] = keyCode }
        if !modifiers.isEmpty { metadata["modifiers"] = modifiers.joined(separator: "+") }
        metadata["component"] = "HotkeyService"
        
        log(level, category: "Hotkey", message, metadata: metadata, file: file, line: line, function: function)
    }
    
    /// 启动过程专用日志
    public func startupLog(
        _ message: String,
        level: LogLevel = .info,
        component: String? = nil,
        details: [String: Any] = [:],
        file: String = #file,
        line: Int = #line,
        function: String = #function
    ) {
        var metadata = details
        if let component = component { metadata["component"] = component }
        metadata["stage"] = "startup"
        
        log(level, category: "Startup", message, metadata: metadata, file: file, line: line, function: function)
    }
    
    // MARK: - 性能测量工具
    
    /// 测量同步操作性能
    public func measurePerformance<T>(
        operation: String,
        category: String = "Performance",
        _ block: () throws -> T
    ) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = getMemoryUsage()
        
        defer {
            let endTime = CFAbsoluteTimeGetCurrent()
            let endMemory = getMemoryUsage()
            let duration = endTime - startTime
            
            performanceLog(
                operation: operation,
                duration: duration,
                memoryUsage: endMemory,
                details: [
                    "memoryDelta": Int64(endMemory) - Int64(startMemory),
                    "category": category
                ]
            )
        }
        
        return try block()
    }
    
    /// 测量异步操作性能
    public func measureAsyncPerformance<T>(
        operation: String,
        category: String = "Performance",
        _ block: () async throws -> T
    ) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = getMemoryUsage()
        
        defer {
            let endTime = CFAbsoluteTimeGetCurrent()
            let endMemory = getMemoryUsage()
            let duration = endTime - startTime
            
            performanceLog(
                operation: operation,
                duration: duration,
                memoryUsage: endMemory,
                details: [
                    "memoryDelta": Int64(endMemory) - Int64(startMemory),
                    "category": category
                ]
            )
        }
        
        return try await block()
    }
    
    // MARK: - 工具方法
    
    private func getLogger(for category: String) -> Logger {
        switch category.lowercased() {
        case "audio": return audioLogger
        case "api": return apiLogger
        case "performance": return performanceLogger
        case "ui": return uiLogger
        case "hotkey": return hotkeyLogger
        case "startup": return startupLogger
        default: return generalLogger
        }
    }
    
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
    
    // MARK: - 日志管理
    
    /// 清除所有日志
    public func clearLogs() {
        logQueue.async { [weak self] in
            DispatchQueue.main.async {
                self?.logEntries.removeAll()
                self?.recentLogs.removeAll()
            }
        }
        info("LogManager", "所有日志已清除")
    }
    
    /// 导出日志
    public func exportLogs() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        return logEntries.map { entry in
            let timestamp = formatter.string(from: entry.timestamp)
            let location = "\(entry.file):\(entry.line)"
            
            var logLine = "[\(timestamp)] [\(entry.level.rawValue)] [\(entry.category)] \(entry.message)"
            
            if !entry.metadata.isEmpty {
                let metadataString = entry.metadata.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
                logLine += " | \(metadataString)"
            }
            
            logLine += " (\(location))"
            return logLine
        }.joined(separator: "\n")
    }
    
    /// 设置日志级别
    public func setLogLevel(_ level: LogLevel) {
        currentLogLevel = level
        info("LogManager", "日志级别已设置为: \(level.rawValue)")
    }
    
    /// 启用/禁用日志
    public func setLoggingEnabled(_ enabled: Bool) {
        isLoggingEnabled = enabled
        info("LogManager", "日志记录已\(enabled ? "启用" : "禁用")")
    }
}

// MARK: - 日志管理器扩展 - 便捷方法
extension LogManager {
    
    /// 记录应用启动
    public func logAppLaunched(version: String, buildNumber: String) {
        info("Application", "Hello Prompt v2 已启动", metadata: [
            "version": version,
            "build": buildNumber,
            "platform": "macOS",
            "architecture": ProcessInfo.processInfo.machineHardwareName ?? "unknown"
        ])
    }
    
    /// 记录配置变更
    public func logConfigurationChange(key: String, oldValue: Any?, newValue: Any?) {
        info("Configuration", "配置已更改: \(key)", metadata: [
            "key": key,
            "oldValue": String(describing: oldValue),
            "newValue": String(describing: newValue)
        ])
    }
    
    /// 记录音频处理性能
    public func logAudioPerformance(
        bufferSize: Int,
        sampleRate: Double,
        processingTime: TimeInterval,
        realTimeRatio: Double
    ) {
        let bufferDuration = Double(bufferSize) / sampleRate
        
        performanceLog(
            operation: "AudioBufferProcessing",
            duration: processingTime,
            details: [
                "bufferSize": bufferSize,
                "sampleRate": sampleRate,
                "bufferDuration": String(format: "%.1fms", bufferDuration * 1000),
                "realTimeRatio": String(format: "%.2f", realTimeRatio)
            ]
        )
        
        if realTimeRatio > 0.8 {
            warning("Audio", "音频处理接近实时极限", metadata: [
                "realTimeRatio": realTimeRatio,
                "bufferSize": bufferSize
            ])
        }
    }
}

// MARK: - ProcessInfo 扩展
extension ProcessInfo {
    var machineHardwareName: String? {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }
}