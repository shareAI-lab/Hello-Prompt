//
//  LogManager.swift
//  HelloPrompt
//
//  全局日志管理系统 - 详细运行状态跟踪和问题诊断
//  Copyright © 2025 HelloPrompt. All rights reserved.
//

import Foundation
import AppKit

// MARK: - 日志级别
enum LogLevel: String, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
    
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }
}

// MARK: - 模块标识
enum LogModule: String {
    case app = "App"
    case audio = "Audio"  
    case openai = "OpenAI"
    case ui = "UI"
    case shortcuts = "Shortcuts"
    case textInsertion = "TextInsertion"
    case settings = "Settings"
    case performance = "Performance"
    case network = "Network"
    case system = "System"
}

// MARK: - 全局日志管理器
@MainActor
class LogManager {
    static let shared = LogManager()
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    private let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private var logLevel: LogLevel = .debug
    private var isInitialized = false
    private var logToFile: Bool = true
    private var logDirectory: URL?
    private var currentLogFile: URL?
    private var fileHandle: FileHandle?
    private let maxLogFileSize: Int = 10 * 1024 * 1024 // 10MB
    private let maxLogFiles: Int = 5
    
    private init() {
        setupLogDirectory()
    }
    
    // MARK: - 初始化
    func initialize(level: LogLevel = .debug, enableFileLogging: Bool = true) {
        guard !isInitialized else { return }
        self.logLevel = level
        self.logToFile = enableFileLogging
        self.isInitialized = true
        
        if enableFileLogging {
            setupCurrentLogFile()
            rotateLogFilesIfNeeded()
        }
        
        info(.app, "🚀 LogManager初始化完成", metadata: [
            "level": level.rawValue,
            "fileLogging": enableFileLogging,
            "logDirectory": logDirectory?.path ?? "无",
            "timestamp": dateFormatter.string(from: Date())
        ])
    }
    
    // MARK: - 日志目录设置
    private func setupLogDirectory() {
        let fileManager = FileManager.default
        
        // 创建应用支持目录下的日志文件夹
        if let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, 
                                               in: .userDomainMask).first {
            let appDir = appSupportDir.appendingPathComponent("HelloPrompt")
            logDirectory = appDir.appendingPathComponent("Logs")
            
            do {
                try fileManager.createDirectory(at: logDirectory!, 
                                               withIntermediateDirectories: true, 
                                               attributes: nil)
            } catch {
                print("❌ 创建日志目录失败: \(error)")
                logDirectory = nil
                logToFile = false
            }
        }
    }
    
    /// 设置当前日志文件
    private func setupCurrentLogFile() {
        guard let logDirectory = logDirectory else { return }
        
        let today = fileDateFormatter.string(from: Date())
        let logFileName = "HelloPrompt-\(today).log"
        currentLogFile = logDirectory.appendingPathComponent(logFileName)
        
        // 如果文件不存在，创建它
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: currentLogFile!.path) {
            fileManager.createFile(atPath: currentLogFile!.path, contents: nil, attributes: nil)
            
            // 写入文件头
            let header = """
            =====================================
            Hello Prompt 日志文件
            创建时间: \(dateFormatter.string(from: Date()))
            日志级别: \(logLevel.rawValue)
            =====================================
            
            """
            writeToLogFile(header)
        }
        
        // 打开文件句柄
        do {
            fileHandle = try FileHandle(forWritingTo: currentLogFile!)
            fileHandle?.seekToEndOfFile()
        } catch {
            print("❌ 打开日志文件失败: \(error)")
            logToFile = false
        }
    }
    
    /// 写入日志文件
    private func writeToLogFile(_ message: String) {
        guard logToFile, let fileHandle = fileHandle else { return }
        
        guard let data = (message + "\n").data(using: .utf8) else {
            print("❌ 日志消息转换为数据时失败")
            return
        }
        
        do {
            fileHandle.write(data)
            
            // 检查文件大小，必要时轮转
            let fileSize = try fileHandle.offset()
            if fileSize > maxLogFileSize {
                rotateLogFiles()
            }
        } catch {
            print("❌ 写入日志文件失败: \(error)")
            // 尝试重新设置文件句柄
            ensureFileHandleClosed()
            setupCurrentLogFile()
        }
    }
    
    /// 确保文件句柄正确关闭
    private func ensureFileHandleClosed() {
        defer { fileHandle = nil }
        do {
            try fileHandle?.close()
        } catch {
            print("❌ 关闭文件句柄时出错: \(error)")
        }
    }
    
    /// 轮转日志文件
    private func rotateLogFiles() {
        ensureFileHandleClosed()
        
        guard let logDirectory = logDirectory else { return }
        
        let fileManager = FileManager.default
        let today = fileDateFormatter.string(from: Date())
        let timestamp = DateFormatter().string(from: Date()).replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: ":", with: "-")
        
        // 重命名当前文件
        if let currentLogFile = currentLogFile {
            let archivedName = "HelloPrompt-\(today)-\(timestamp).log"
            let archivedURL = logDirectory.appendingPathComponent(archivedName)
            
            do {
                try fileManager.moveItem(at: currentLogFile, to: archivedURL)
            } catch {
                print("❌ 轮转日志文件失败: \(error)")
            }
        }
        
        // 创建新的日志文件
        setupCurrentLogFile()
        
        // 清理旧日志文件
        cleanupOldLogFiles()
    }
    
    /// 如果需要则轮转日志文件
    private func rotateLogFilesIfNeeded() {
        guard let currentLogFile = currentLogFile else { return }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: currentLogFile.path)
            if let fileSize = attributes[.size] as? Int, fileSize > maxLogFileSize {
                rotateLogFiles()
            }
        } catch {
            // 文件可能不存在，忽略错误
        }
    }
    
    /// 清理旧日志文件
    private func cleanupOldLogFiles() {
        guard let logDirectory = logDirectory else { return }
        
        do {
            let fileManager = FileManager.default
            let logFiles = try fileManager.contentsOfDirectory(at: logDirectory, 
                                                               includingPropertiesForKeys: [.creationDateKey], 
                                                               options: [])
            
            // 按创建时间排序
            let sortedFiles = logFiles.filter { $0.pathExtension == "log" }
                .compactMap { url -> (URL, Date)? in
                    guard let creationDate = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate else {
                        return nil
                    }
                    return (url, creationDate)
                }
                .sorted { $0.1 > $1.1 } // 最新的在前
            
            // 删除超过最大数量的文件
            if sortedFiles.count > maxLogFiles {
                let filesToDelete = Array(sortedFiles.dropFirst(maxLogFiles))
                for (fileURL, _) in filesToDelete {
                    do {
                        try fileManager.removeItem(at: fileURL)
                        print("🗑️ 删除旧日志文件: \(fileURL.lastPathComponent)")
                    } catch {
                        print("❌ 删除旧日志文件失败: \(error)")
                    }
                }
            }
        } catch {
            print("❌ 清理旧日志文件失败: \(error)")
        }
    }
    
    // MARK: - 核心日志方法
    func log(_ level: LogLevel, 
             _ module: LogModule, 
             _ message: String, 
             metadata: [String: Any]? = nil,
             function: String = #function,
             file: String = #file,
             line: Int = #line) {
        
        guard isInitialized else { return }
        
        // 检查日志级别过滤
        guard shouldLog(level) else { return }
        
        let timestamp = dateFormatter.string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let metadataString = formatMetadata(metadata)
        
        let logMessage = "[\(timestamp)] \(level.emoji) \(level.rawValue) [\(module.rawValue)] \(fileName):\(line) \(function): \(message)\(metadataString)"
        
        // 输出到控制台
        print(logMessage)
        
        // 写入文件
        if logToFile {
            writeToLogFile(logMessage)
        }
        
        // 如果是错误级别，输出到stderr
        if level == .error || level == .critical {
            fputs(logMessage + "\n", stderr)
        }
    }
    
    /// 检查是否应该记录此级别的日志
    private func shouldLog(_ level: LogLevel) -> Bool {
        let levelPriorities: [LogLevel: Int] = [
            .debug: 0,
            .info: 1,
            .warning: 2,
            .error: 3,
            .critical: 4
        ]
        
        let currentPriority = levelPriorities[logLevel] ?? 0
        let messagePriority = levelPriorities[level] ?? 0
        
        return messagePriority >= currentPriority
    }
    
    // MARK: - 便捷方法
    func debug(_ module: LogModule, 
               _ message: String, 
               metadata: [String: Any]? = nil,
               function: String = #function,
               file: String = #file,
               line: Int = #line) {
        log(.debug, module, message, metadata: metadata, function: function, file: file, line: line)
    }
    
    func info(_ module: LogModule, 
              _ message: String, 
              metadata: [String: Any]? = nil,
              function: String = #function,
              file: String = #file,
              line: Int = #line) {
        log(.info, module, message, metadata: metadata, function: function, file: file, line: line)
    }
    
    func warning(_ module: LogModule, 
                 _ message: String, 
                 metadata: [String: Any]? = nil,
                 function: String = #function,
                 file: String = #file,
                 line: Int = #line) {
        log(.warning, module, message, metadata: metadata, function: function, file: file, line: line)
    }
    
    func error(_ module: LogModule, 
               _ message: String, 
               metadata: [String: Any]? = nil,
               function: String = #function,
               file: String = #file,
               line: Int = #line) {
        log(.error, module, message, metadata: metadata, function: function, file: file, line: line)
    }
    
    func critical(_ module: LogModule, 
                  _ message: String, 
                  metadata: [String: Any]? = nil,
                  function: String = #function,
                  file: String = #file,
                  line: Int = #line) {
        log(.critical, module, message, metadata: metadata, function: function, file: file, line: line)
    }
    
    // MARK: - 专项日志方法
    
    /// 音频处理专项日志
    func audioLog(_ event: String, 
                  details: [String: Any]? = nil,
                  function: String = #function) {
        info(.audio, "🎵 音频处理: \(event)", metadata: details, function: function)
    }
    
    /// API调用专项日志
    func apiLog(_ event: String, 
                duration: TimeInterval? = nil,
                details: [String: Any]? = nil,
                function: String = #function) {
        var metadata = details ?? [:]
        if let duration = duration {
            metadata["duration"] = String(format: "%.3fs", duration)
        }
        info(.openai, "🤖 API调用: \(event)", metadata: metadata, function: function)
    }
    
    /// UI操作专项日志
    func uiLog(_ event: String, 
               details: [String: Any]? = nil,
               function: String = #function) {
        info(.ui, "🖥️ UI操作: \(event)", metadata: details, function: function)
    }
    
    /// 性能监控专项日志
    func performanceLog(_ operation: String, 
                       duration: TimeInterval,
                       details: [String: Any]? = nil,
                       function: String = #function) {
        var metadata = details ?? [:]
        metadata["duration"] = String(format: "%.3fs", duration)
        info(.performance, "⚡ 性能监控: \(operation)", metadata: metadata, function: function)
    }
    
    /// 网络请求专项日志
    func networkLog(_ url: String, 
                    method: String, 
                    statusCode: Int? = nil,
                    duration: TimeInterval? = nil,
                    error: Error? = nil,
                    function: String = #function) {
        var metadata: [String: Any] = [
            "url": url,
            "method": method
        ]
        
        if let statusCode = statusCode {
            metadata["statusCode"] = statusCode
        }
        
        if let duration = duration {
            metadata["duration"] = String(format: "%.3fs", duration)
        }
        
        if let error = error {
            self.error(.network, "🌐 网络请求失败: \(method) \(url) - \(error.localizedDescription)", 
                      metadata: metadata, function: function)
        } else {
            info(.network, "🌐 网络请求: \(method) \(url)", metadata: metadata, function: function)
        }
    }
    
    // MARK: - 业务流程追踪
    func startFlow(_ flowName: String, 
                   context: [String: Any]? = nil,
                   function: String = #function) {
        info(.app, "🚀 开始业务流程: \(flowName)", metadata: context, function: function)
    }
    
    func stepFlow(_ flowName: String, 
                  step: String,
                  context: [String: Any]? = nil,
                  function: String = #function) {
        info(.app, "📍 业务流程步骤: \(flowName) -> \(step)", metadata: context, function: function)
    }
    
    func endFlow(_ flowName: String, 
                 success: Bool,
                 context: [String: Any]? = nil,
                 function: String = #function) {
        let emoji = success ? "✅" : "❌"
        let result = success ? "成功" : "失败"
        info(.app, "\(emoji) 业务流程结束: \(flowName) - \(result)", metadata: context, function: function)
    }
    
    /// 错误追踪增强
    func trackError(_ error: Error, 
                    context: String,
                    recoveryAction: String? = nil,
                    function: String = #function) {
        var metadata: [String: Any] = [
            "context": context,
            "errorType": String(describing: type(of: error)),
            "errorDescription": error.localizedDescription
        ]
        
        if let recoveryAction = recoveryAction {
            metadata["recoveryAction"] = recoveryAction
        }
        
        self.error(.system, "💥 系统错误追踪: \(context)", metadata: metadata, function: function)
    }
    
    // MARK: - 系统信息记录
    func logSystemInfo() {
        let processInfo = ProcessInfo.processInfo
        
        info(.system, "📊 系统信息记录", metadata: [
            "系统版本": processInfo.operatingSystemVersionString,
            "进程名称": processInfo.processName,
            "进程ID": processInfo.processIdentifier,
            "启动时间": dateFormatter.string(from: Date()),
            "Swift版本": "6.1"
        ])
    }
    
    // MARK: - 日志文件管理公共方法
    
    /// 获取日志目录URL
    func getLogDirectoryURL() -> URL? {
        return logDirectory
    }
    
    /// 打开日志文件夹
    func openLogDirectory() {
        guard let logDirectory = logDirectory else {
            LogManager.shared.warning(.app, "日志目录不存在，无法打开")
            return
        }
        
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: logDirectory.path)
        LogManager.shared.info(.app, "打开日志文件夹", metadata: ["path": logDirectory.path])
    }
    
    /// 清除所有日志文件
    func clearAllLogs() {
        guard let logDirectory = logDirectory else {
            LogManager.shared.warning(.app, "日志目录不存在，无法清除日志")
            return
        }
        
        do {
            let fileManager = FileManager.default
            let logFiles = try fileManager.contentsOfDirectory(at: logDirectory, 
                                                               includingPropertiesForKeys: nil, 
                                                               options: [])
            
            var deletedCount = 0
            for fileURL in logFiles {
                if fileURL.pathExtension == "log" {
                    try fileManager.removeItem(at: fileURL)
                    deletedCount += 1
                }
            }
            
            // 关闭当前文件句柄并重新创建
            fileHandle?.closeFile()
            fileHandle = nil
            setupCurrentLogFile()
            
            LogManager.shared.info(.app, "清除所有日志文件完成", metadata: [
                "deletedCount": deletedCount,
                "logDirectory": logDirectory.path
            ])
            
        } catch {
            LogManager.shared.error(.app, "清除日志文件失败", metadata: ["error": error.localizedDescription])
        }
    }
    
    /// 获取日志文件统计信息
    func getLogStatistics() -> LogStatistics {
        guard let logDirectory = logDirectory else {
            return LogStatistics(fileCount: 0, totalSize: 0, oldestFileDate: nil, newestFileDate: nil)
        }
        
        do {
            let fileManager = FileManager.default
            let logFiles = try fileManager.contentsOfDirectory(at: logDirectory, 
                                                               includingPropertiesForKeys: [.fileSizeKey, .creationDateKey], 
                                                               options: [])
            
            let logFileInfos = logFiles.filter { $0.pathExtension == "log" }
                .compactMap { url -> (URL, Int64, Date)? in
                    guard let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey]),
                          let fileSize = resourceValues.fileSize,
                          let creationDate = resourceValues.creationDate else {
                        return nil
                    }
                    return (url, Int64(fileSize), creationDate)
                }
            
            let totalSize = logFileInfos.reduce(0) { $0 + $1.1 }
            let dates = logFileInfos.map { $0.2 }
            
            let statistics = LogStatistics(
                fileCount: logFileInfos.count,
                totalSize: totalSize,
                oldestFileDate: dates.min(),
                newestFileDate: dates.max()
            )
            
            LogManager.shared.debug(.app, "获取日志统计信息", metadata: [
                "fileCount": statistics.fileCount,
                "totalSize": statistics.totalSize,
                "oldestFile": statistics.oldestFileDate?.timeIntervalSince1970 ?? 0,
                "newestFile": statistics.newestFileDate?.timeIntervalSince1970 ?? 0
            ])
            
            return statistics
            
        } catch {
            LogManager.shared.error(.app, "获取日志统计信息失败", metadata: ["error": error.localizedDescription])
            return LogStatistics(fileCount: 0, totalSize: 0, oldestFileDate: nil, newestFileDate: nil)
        }
    }
    
    /// 导出日志文件
    func exportLogs(to destinationURL: URL) throws {
        guard let logDirectory = logDirectory else {
            throw LogManagerError.logDirectoryNotFound
        }
        
        let fileManager = FileManager.default
        
        // 创建目标目录
        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
        
        // 获取所有日志文件
        let logFiles = try fileManager.contentsOfDirectory(at: logDirectory, 
                                                           includingPropertiesForKeys: nil, 
                                                           options: [])
        
        var copiedCount = 0
        for logFile in logFiles {
            if logFile.pathExtension == "log" {
                let destinationFile = destinationURL.appendingPathComponent(logFile.lastPathComponent)
                try fileManager.copyItem(at: logFile, to: destinationFile)
                copiedCount += 1
            }
        }
        
        LogManager.shared.info(.app, "导出日志文件完成", metadata: [
            "copiedCount": copiedCount,
            "destination": destinationURL.path
        ])
    }
    
    /// 启用或禁用文件日志记录
    func setFileLogging(enabled: Bool) {
        logToFile = enabled
        
        if enabled && fileHandle == nil {
            setupCurrentLogFile()
        } else if !enabled {
            fileHandle?.closeFile()
            fileHandle = nil
        }
        
        LogManager.shared.info(.app, "文件日志记录状态更新", metadata: ["enabled": enabled])
    }
    
    /// 设置日志级别
    func setLogLevel(_ level: LogLevel) {
        logLevel = level
        LogManager.shared.info(.app, "日志级别更新", metadata: ["level": level.rawValue])
    }
    
    // MARK: - 私有辅助方法
    private func formatMetadata(_ metadata: [String: Any]?) -> String {
        guard let metadata = metadata, !metadata.isEmpty else { return "" }
        let metadataStrings = metadata.map { "\($0.key)=\($0.value)" }
        return " | \(metadataStrings.joined(separator: ", "))"
    }
}

// MARK: - 日志统计信息结构
struct LogStatistics {
    let fileCount: Int
    let totalSize: Int64
    let oldestFileDate: Date?
    let newestFileDate: Date?
    
    var totalSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
    
    var dateRangeDescription: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        
        if let oldest = oldestFileDate, let newest = newestFileDate {
            if Calendar.current.isDate(oldest, inSameDayAs: newest) {
                return formatter.string(from: newest)
            } else {
                return "\(formatter.string(from: oldest)) ~ \(formatter.string(from: newest))"
            }
        } else if let newest = newestFileDate {
            return formatter.string(from: newest)
        } else {
            return "无日志文件"
        }
    }
}

// MARK: - 日志管理器错误类型
enum LogManagerError: LocalizedError {
    case logDirectoryNotFound
    case fileWriteError(Error)
    case fileReadError(Error)
    
    var errorDescription: String? {
        switch self {
        case .logDirectoryNotFound:
            return "日志目录未找到"
        case .fileWriteError(let error):
            return "日志文件写入失败: \(error.localizedDescription)"
        case .fileReadError(let error):
            return "日志文件读取失败: \(error.localizedDescription)"
        }
    }
}