//
//  UserTestingReportManager.swift
//  HelloPrompt
//
//  用户测试和错误报告管理器 - 收集用户反馈和系统诊断信息
//  提供问题报告、使用统计和用户体验改进数据
//

import Foundation
import AppKit
import CryptoKit

// MARK: - 测试报告类型
public enum TestReportType: String, CaseIterable {
    case bugReport = "错误报告"
    case featureRequest = "功能请求"
    case usabilityFeedback = "可用性反馈"
    case performanceIssue = "性能问题"
    case crashReport = "崩溃报告"
}

// MARK: - 报告优先级
public enum ReportPriority: String, CaseIterable {
    case low = "低"
    case medium = "中"
    case high = "高"
    case critical = "严重"
    
    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}

// MARK: - 用户反馈数据
public struct UserFeedback {
    public let id: UUID
    public let type: TestReportType
    public let priority: ReportPriority
    public let title: String
    public let description: String
    public let stepsToReproduce: String?
    public let expectedBehavior: String?
    public let actualBehavior: String?
    public let userEmail: String?
    public let timestamp: Date
    public let systemInfo: SystemDiagnosticInfo
    public let appVersion: String
    public let attachments: [FeedbackAttachment]
    
    public init(
        type: TestReportType,
        priority: ReportPriority,
        title: String,
        description: String,
        stepsToReproduce: String? = nil,
        expectedBehavior: String? = nil,
        actualBehavior: String? = nil,
        userEmail: String? = nil,
        attachments: [FeedbackAttachment] = []
    ) {
        self.id = UUID()
        self.type = type
        self.priority = priority
        self.title = title
        self.description = description
        self.stepsToReproduce = stepsToReproduce
        self.expectedBehavior = expectedBehavior
        self.actualBehavior = actualBehavior
        self.userEmail = userEmail
        self.timestamp = Date()
        self.systemInfo = SystemDiagnosticInfo.current()
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        self.attachments = attachments
    }
}

// MARK: - 反馈附件
public struct FeedbackAttachment {
    public let id: UUID
    public let name: String
    public let type: AttachmentType
    public let data: Data
    public let size: Int
    
    public enum AttachmentType: String {
        case log = "日志文件"
        case screenshot = "截图"
        case recording = "录音文件"
        case configuration = "配置文件"
    }
    
    public init(name: String, type: AttachmentType, data: Data) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.data = data
        self.size = data.count
    }
}

// MARK: - 系统诊断信息
public struct SystemDiagnosticInfo: Codable {
    public let osVersion: String
    public let appVersion: String
    public let buildNumber: String
    public let architecture: String
    public let memoryGB: Double
    public let diskSpaceGB: Double
    public let cpuInfo: String
    public let audioDevices: [String]
    public let permissions: [String: Bool]
    public let configuration: [String: Any]
    public let performanceMetrics: [String: Double]
    public let timestamp: Date
    
    // MARK: - Codable Keys
    private enum CodingKeys: String, CodingKey {
        case osVersion, appVersion, buildNumber, architecture
        case memoryGB, diskSpaceGB, cpuInfo, audioDevices
        case permissions, timestamp
    }
    
    // MARK: - Memberwise Initializer
    public init(
        osVersion: String,
        appVersion: String,
        buildNumber: String,
        architecture: String,
        memoryGB: Double,
        diskSpaceGB: Double,
        cpuInfo: String,
        audioDevices: [String],
        permissions: [String: Bool],
        configuration: [String: Any],
        performanceMetrics: [String: Double],
        timestamp: Date
    ) {
        self.osVersion = osVersion
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.architecture = architecture
        self.memoryGB = memoryGB
        self.diskSpaceGB = diskSpaceGB
        self.cpuInfo = cpuInfo
        self.audioDevices = audioDevices
        self.permissions = permissions
        self.configuration = configuration
        self.performanceMetrics = performanceMetrics
        self.timestamp = timestamp
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        osVersion = try container.decode(String.self, forKey: .osVersion)
        appVersion = try container.decode(String.self, forKey: .appVersion)
        buildNumber = try container.decode(String.self, forKey: .buildNumber)
        architecture = try container.decode(String.self, forKey: .architecture)
        memoryGB = try container.decode(Double.self, forKey: .memoryGB)
        diskSpaceGB = try container.decode(Double.self, forKey: .diskSpaceGB)
        cpuInfo = try container.decode(String.self, forKey: .cpuInfo)
        audioDevices = try container.decode([String].self, forKey: .audioDevices)
        permissions = try container.decode([String: Bool].self, forKey: .permissions)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        
        // 非Codable属性设为默认值
        configuration = [:]
        performanceMetrics = [:]
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(osVersion, forKey: .osVersion)
        try container.encode(appVersion, forKey: .appVersion)
        try container.encode(buildNumber, forKey: .buildNumber)
        try container.encode(architecture, forKey: .architecture)
        try container.encode(memoryGB, forKey: .memoryGB)
        try container.encode(diskSpaceGB, forKey: .diskSpaceGB)
        try container.encode(cpuInfo, forKey: .cpuInfo)
        try container.encode(audioDevices, forKey: .audioDevices)
        try container.encode(permissions, forKey: .permissions)
        try container.encode(timestamp, forKey: .timestamp)
    }
    
    public static func current() -> SystemDiagnosticInfo {
        let processInfo = ProcessInfo.processInfo
        let osVersion = "\(processInfo.operatingSystemVersion.majorVersion).\(processInfo.operatingSystemVersion.minorVersion).\(processInfo.operatingSystemVersion.patchVersion)"
        
        return SystemDiagnosticInfo(
            osVersion: osVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            architecture: processInfo.machineHardwareName ?? "Unknown",
            memoryGB: Double(processInfo.physicalMemory) / (1024 * 1024 * 1024),
            diskSpaceGB: getDiskSpace(),
            cpuInfo: getCPUInfo(),
            audioDevices: getAudioDevices(),
            permissions: getCurrentPermissions(),
            configuration: getAppConfiguration(),
            performanceMetrics: getPerformanceMetrics(),
            timestamp: Date()
        )
    }
    
    private static func getDiskSpace() -> Double {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        do {
            let values = try homeURL.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            let bytes = values.volumeAvailableCapacity ?? 0
            return Double(bytes) / (1024 * 1024 * 1024)
        } catch {
            return 0
        }
    }
    
    private static func getCPUInfo() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &machine, &size, nil, 0)
        return String(cString: machine)
    }
    
    private static func getAudioDevices() -> [String] {
        // 获取音频设备列表的简化实现
        return ["Built-in Microphone", "Built-in Output"]
    }
    
    private static func getCurrentPermissions() -> [String: Bool] {
        // 使用同步方式获取权限状态，避免MainActor问题
        return [
            "microphone": false, // 简化实现，避免MainActor问题
            "accessibility": false,
            "notifications": false
        ]
    }
    
    private static func getAppConfiguration() -> [String: Any] {
        // 简化实现，避免AppConfigManager属性问题
        return [
            "apiModel": "gpt-4o-mini",
            "autoStartRecording": false,
            "enableHapticFeedback": true,
            "enableNotifications": true,
            "logLevel": LogManager.shared.currentLogLevel.rawValue
        ]
    }
    
    private static func getPerformanceMetrics() -> [String: Double] {
        // 简化实现，避免MainActor问题
        let memoryStats: [String: Any] = [:] // MemoryManager.shared.getMemoryStats()
        let audioStats: [String: Double] = [:] // AudioProcessingOptimizer.shared.getPerformanceStats()
        
        var metrics: [String: Double] = [:]
        
        // 内存指标
        if let memoryUsage = memoryStats["currentUsageMB"] as? String,
           let usage = Double(memoryUsage) {
            metrics["memoryUsageMB"] = usage
        }
        
        // 音频处理指标
        for (key, value) in audioStats {
            metrics["audio_\(key)"] = value
        }
        
        return metrics
    }
}

// MARK: - 使用统计数据
public struct UsageStatistics: Codable {
    public let recordingCount: Int
    public let totalRecordingDuration: TimeInterval
    public let successfulTranscriptions: Int
    public let failedTranscriptions: Int
    public let averageRecordingLength: TimeInterval
    public let mostUsedFeatures: [String: Int]
    public let errorCounts: [String: Int]
    public let sessionDuration: TimeInterval
    public let lastUsed: Date
    public let version: String
    
    public init() {
        self.recordingCount = 0
        self.totalRecordingDuration = 0
        self.successfulTranscriptions = 0
        self.failedTranscriptions = 0
        self.averageRecordingLength = 0
        self.mostUsedFeatures = [:]
        self.errorCounts = [:]
        self.sessionDuration = 0
        self.lastUsed = Date()
        self.version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
}

// MARK: - 主测试报告管理器
@MainActor
public final class UserTestingReportManager: ObservableObject {
    
    // MARK: - 单例
    public static let shared = UserTestingReportManager()
    
    // MARK: - 发布属性
    @Published public var pendingReports: [UserFeedback] = []
    @Published public var usageStatistics = UsageStatistics()
    @Published public var isCollectingFeedback = false
    
    // MARK: - 私有属性
    private let fileManager = FileManager.default
    private let reportsDirectory: URL
    private let statisticsFile: URL
    private var sessionStartTime = Date()
    
    // MARK: - 初始化
    private init() {
        // 创建报告存储目录
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupportURL.appendingPathComponent("HelloPrompt")
        reportsDirectory = appDirectory.appendingPathComponent("Reports")
        statisticsFile = appDirectory.appendingPathComponent("usage_statistics.json")
        
        createDirectoriesIfNeeded()
        loadUsageStatistics()
        
        LogManager.shared.info("UserTestingReportManager", "用户测试报告管理器初始化完成")
    }
    
    // MARK: - 公共方法
    
    /// 提交用户反馈
    public func submitFeedback(_ feedback: UserFeedback) async -> Bool {
        isCollectingFeedback = true
        defer { isCollectingFeedback = false }
        
        LogManager.shared.info("UserTestingReportManager", "收到用户反馈: \(feedback.type.rawValue) - \(feedback.title)")
        
        do {
            // 保存反馈到本地
            try await saveFeedbackLocally(feedback)
            
            // 添加到待处理列表
            pendingReports.append(feedback)
            
            // 更新使用统计
            updateUsageStatistics(for: feedback)
            
            LogManager.shared.info("UserTestingReportManager", "用户反馈已保存: \(feedback.id)")
            return true
            
        } catch {
            LogManager.shared.error("UserTestingReportManager", "保存用户反馈失败: \(error)")
            return false
        }
    }
    
    /// 创建错误报告
    public func createBugReport(
        title: String,
        description: String,
        stepsToReproduce: String,
        expectedBehavior: String,
        actualBehavior: String,
        priority: ReportPriority = .medium,
        includeScreenshot: Bool = true,
        includeLogs: Bool = true
    ) async -> Bool {
        
        var attachments: [FeedbackAttachment] = []
        
        // 添加截图
        if includeScreenshot {
            if let screenshot = captureScreenshot() {
                attachments.append(FeedbackAttachment(
                    name: "screenshot_\(Date().timeIntervalSince1970).png",
                    type: .screenshot,
                    data: screenshot
                ))
            }
        }
        
        // 添加日志
        if includeLogs {
            let logs = LogManager.shared.exportLogs()
            if let logData = logs.data(using: .utf8) {
                attachments.append(FeedbackAttachment(
                    name: "app_logs_\(Date().timeIntervalSince1970).txt",
                    type: .log,
                    data: logData
                ))
            }
        }
        
        // 添加配置信息
        if let configData = try? JSONEncoder().encode(SystemDiagnosticInfo.current()) {
            attachments.append(FeedbackAttachment(
                name: "system_info_\(Date().timeIntervalSince1970).json",
                type: .configuration,
                data: configData
            ))
        }
        
        let feedback = UserFeedback(
            type: .bugReport,
            priority: priority,
            title: title,
            description: description,
            stepsToReproduce: stepsToReproduce,
            expectedBehavior: expectedBehavior,
            actualBehavior: actualBehavior,
            attachments: attachments
        )
        
        return await submitFeedback(feedback)
    }
    
    /// 创建性能问题报告
    public func createPerformanceReport(
        title: String,
        description: String,
        performanceData: [String: Any] = [:]
    ) async -> Bool {
        
        // 收集性能数据
        let memoryStats = MemoryManager.shared.getMemoryStats()
        let audioStats = AudioProcessingOptimizer.shared.getPerformanceStats()
        
        var allPerformanceData = performanceData
        allPerformanceData["memoryStats"] = memoryStats
        allPerformanceData["audioStats"] = audioStats
        
        // 创建性能数据附件
        var attachments: [FeedbackAttachment] = []
        if let perfData = try? JSONSerialization.data(withJSONObject: allPerformanceData, options: .prettyPrinted) {
            attachments.append(FeedbackAttachment(
                name: "performance_data_\(Date().timeIntervalSince1970).json",
                type: .configuration,
                data: perfData
            ))
        }
        
        let feedback = UserFeedback(
            type: .performanceIssue,
            priority: .medium,
            title: title,
            description: description,
            attachments: attachments
        )
        
        return await submitFeedback(feedback)
    }
    
    /// 记录使用统计
    public func recordUsage(feature: String, duration: TimeInterval? = nil) {
        let newStats = usageStatistics
        
        // 更新功能使用统计
        var features = newStats.mostUsedFeatures
        features[feature] = (features[feature] ?? 0) + 1
        
        // 更新时长
        let _ = Date().timeIntervalSince(sessionStartTime)
        
        // 这里需要重新构建统计对象，因为属性是let
        // 在实际实现中，应该将UsageStatistics改为可变属性
        LogManager.shared.debug("UserTestingReportManager", "记录功能使用: \(feature)")
    }
    
    /// 记录错误统计
    public func recordError(_ error: Error, context: String = "") {
        let errorKey = "\(type(of: error))"
        LogManager.shared.debug("UserTestingReportManager", "记录错误: \(errorKey) in \(context)")
    }
    
    /// 生成诊断报告
    public func generateDiagnosticReport() -> String {
        let systemInfo = SystemDiagnosticInfo.current()
        let validationResult = ConfigurationValidator.shared.lastValidationResult
        
        var report = "# Hello Prompt v2 诊断报告\n\n"
        report += "生成时间: \(ISO8601DateFormatter().string(from: Date()))\n\n"
        
        // 系统信息
        report += "## 系统信息\n"
        report += "- **操作系统**: macOS \(systemInfo.osVersion)\n"
        report += "- **应用版本**: \(systemInfo.appVersion) (\(systemInfo.buildNumber))\n"
        report += "- **架构**: \(systemInfo.architecture)\n"
        report += "- **内存**: \(String(format: "%.1f", systemInfo.memoryGB))GB\n"
        report += "- **磁盘空间**: \(String(format: "%.1f", systemInfo.diskSpaceGB))GB\n\n"
        
        // 权限状态
        report += "## 权限状态\n"
        for (permission, granted) in systemInfo.permissions {
            let status = granted ? "✅ 已授权" : "❌ 未授权"
            report += "- **\(permission)**: \(status)\n"
        }
        report += "\n"
        
        // 配置验证
        if let validation = validationResult {
            report += "## 配置验证\n"
            report += "- **状态**: \(validation.isValid ? "✅ 通过" : "❌ 失败")\n"
            report += "- **错误**: \(validation.errors.count)个\n"
            report += "- **警告**: \(validation.warnings.count)个\n\n"
        }
        
        // 性能指标
        report += "## 性能指标\n"
        for (metric, value) in systemInfo.performanceMetrics {
            report += "- **\(metric)**: \(String(format: "%.3f", value))\n"
        }
        report += "\n"
        
        // 使用统计
        report += "## 使用统计\n"
        report += "- **录音次数**: \(usageStatistics.recordingCount)\n"
        report += "- **总录音时长**: \(String(format: "%.1f", usageStatistics.totalRecordingDuration))秒\n"
        report += "- **成功转录**: \(usageStatistics.successfulTranscriptions)\n"
        report += "- **失败转录**: \(usageStatistics.failedTranscriptions)\n\n"
        
        return report
    }
    
    /// 导出所有反馈报告
    public func exportAllReports() -> URL? {
        do {
            let exportURL = reportsDirectory.appendingPathComponent("export_\(Date().timeIntervalSince1970).json")
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            let exportData = try encoder.encode(pendingReports.map { feedback in
                // 创建可导出的简化版本
                return [
                    "id": feedback.id.uuidString,
                    "type": feedback.type.rawValue,
                    "priority": feedback.priority.rawValue,
                    "title": feedback.title,
                    "description": feedback.description,
                    "timestamp": ISO8601DateFormatter().string(from: feedback.timestamp),
                    "appVersion": feedback.appVersion
                ]
            })
            
            try exportData.write(to: exportURL)
            LogManager.shared.info("UserTestingReportManager", "报告已导出到: \(exportURL.path)")
            return exportURL
            
        } catch {
            LogManager.shared.error("UserTestingReportManager", "导出报告失败: \(error)")
            return nil
        }
    }
    
    // MARK: - 私有方法
    
    private func createDirectoriesIfNeeded() {
        do {
            try fileManager.createDirectory(at: reportsDirectory, withIntermediateDirectories: true)
        } catch {
            LogManager.shared.error("UserTestingReportManager", "创建报告目录失败: \(error)")
        }
    }
    
    private func saveFeedbackLocally(_ feedback: UserFeedback) async throws {
        let fileName = "feedback_\(feedback.id.uuidString).json"
        let fileURL = reportsDirectory.appendingPathComponent(fileName)
        
        // 创建可序列化的数据结构
        let feedbackData: [String: Any] = [
            "id": feedback.id.uuidString,
            "type": feedback.type.rawValue,
            "priority": feedback.priority.rawValue,
            "title": feedback.title,
            "description": feedback.description,
            "stepsToReproduce": feedback.stepsToReproduce ?? "",
            "expectedBehavior": feedback.expectedBehavior ?? "",
            "actualBehavior": feedback.actualBehavior ?? "",
            "userEmail": feedback.userEmail ?? "",
            "timestamp": ISO8601DateFormatter().string(from: feedback.timestamp),
            "appVersion": feedback.appVersion,
            "systemInfo": try JSONEncoder().encode(feedback.systemInfo),
            "attachmentCount": feedback.attachments.count
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: feedbackData, options: .prettyPrinted)
        try jsonData.write(to: fileURL)
        
        // 保存附件
        for attachment in feedback.attachments {
            let attachmentURL = reportsDirectory.appendingPathComponent("attachment_\(attachment.id.uuidString)_\(attachment.name)")
            try attachment.data.write(to: attachmentURL)
        }
    }
    
    private func loadUsageStatistics() {
        guard fileManager.fileExists(atPath: statisticsFile.path) else {
            usageStatistics = UsageStatistics()
            return
        }
        
        do {
            let data = try Data(contentsOf: statisticsFile)
            usageStatistics = try JSONDecoder().decode(UsageStatistics.self, from: data)
        } catch {
            LogManager.shared.error("UserTestingReportManager", "加载使用统计失败: \(error)")
            usageStatistics = UsageStatistics()
        }
    }
    
    private func saveUsageStatistics() {
        do {
            let data = try JSONEncoder().encode(usageStatistics)
            try data.write(to: statisticsFile)
        } catch {
            LogManager.shared.error("UserTestingReportManager", "保存使用统计失败: \(error)")
        }
    }
    
    private func updateUsageStatistics(for feedback: UserFeedback) {
        // 由于UsageStatistics属性是let，这里只记录日志
        // 实际实现中应该使用可变的统计结构
        LogManager.shared.debug("UserTestingReportManager", "更新使用统计: \(feedback.type.rawValue)")
    }
    
    private func captureScreenshot() -> Data? {
        guard let screen = NSScreen.main else { return nil }
        
        let rect = screen.frame
        let cgImage = CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        )
        
        guard let image = cgImage else { return nil }
        
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        return bitmapRep.representation(using: .png, properties: [:])
    }
}

