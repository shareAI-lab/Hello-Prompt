//
//  LaunchAgentManager.swift
//  HelloPrompt
//
//  启动代理管理器 - 管理macOS Launch Agent，实现开机自启动和后台运行
//  包含plist文件管理、权限检查、状态监控等功能
//

import Foundation
import ServiceManagement
import AppKit

// MARK: - 启动代理状态
public enum LaunchAgentStatus: String, CaseIterable {
    case notInstalled = "未安装"
    case installed = "已安装"
    case enabled = "已启用"
    case disabled = "已禁用"
    case error = "错误状态"
    
    var isActive: Bool {
        switch self {
        case .enabled:
            return true
        default:
            return false
        }
    }
}

// MARK: - 启动选项配置
public struct LaunchAgentConfiguration {
    public let bundleIdentifier: String
    public let executablePath: String
    public let arguments: [String]
    public let environmentVariables: [String: String]
    public let runAtLoad: Bool
    public let keepAlive: Bool
    public let watchPaths: [String]
    public let queueDirectories: [String]
    
    public init(
        bundleIdentifier: String,
        executablePath: String,
        arguments: [String] = [],
        environmentVariables: [String: String] = [:],
        runAtLoad: Bool = true,
        keepAlive: Bool = false,
        watchPaths: [String] = [],
        queueDirectories: [String] = []
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.executablePath = executablePath
        self.arguments = arguments
        self.environmentVariables = environmentVariables
        self.runAtLoad = runAtLoad
        self.keepAlive = keepAlive
        self.watchPaths = watchPaths
        self.queueDirectories = queueDirectories
    }
    
    public static var `default`: LaunchAgentConfiguration {
        LaunchAgentConfiguration(
            bundleIdentifier: "com.helloprompt.launch-agent",
            executablePath: Bundle.main.executablePath ?? "",
            arguments: ["--launch-agent"],
            runAtLoad: true,
            keepAlive: false
        )
    }
}

// MARK: - 主启动代理管理器
@MainActor
public final class LaunchAgentManager: ObservableObject {
    
    // MARK: - 单例实例
    public static let shared = LaunchAgentManager()
    
    // MARK: - Published Properties
    @Published public var status: LaunchAgentStatus = .notInstalled
    @Published public var isEnabled = false
    @Published public var lastError: Error?
    
    // MARK: - 私有属性
    private let configuration: LaunchAgentConfiguration
    private let fileManager = FileManager.default
    
    // 路径常量
    private var launchAgentsDirectory: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("LaunchAgents")
    }
    
    private var plistFileName: String {
        "\(configuration.bundleIdentifier).plist"
    }
    
    private var plistURL: URL {
        launchAgentsDirectory.appendingPathComponent(plistFileName)
    }
    
    // MARK: - 初始化
    private init(configuration: LaunchAgentConfiguration = .default) {
        self.configuration = configuration
        // 延迟状态更新，避免在初始化时阻塞主线程
        Task {
            await updateStatus()
        }
        
        LogManager.shared.info("LaunchAgentManager", """
            启动代理管理器初始化完成
            Bundle ID: \(configuration.bundleIdentifier)
            可执行文件路径: \(configuration.executablePath)
            """)
    }
    
    // MARK: - 公共接口
    
    /// 启用开机自启动
    public func enableLaunchAtLogin() async -> Bool {
        do {
            // 检查和创建目录
            try createLaunchAgentsDirectoryIfNeeded()
            
            // 创建plist文件
            try createLaunchAgentPlist()
            
            // 加载Launch Agent
            try await loadLaunchAgent()
            
            await updateStatus()
            
            LogManager.shared.info("LaunchAgentManager", "开机自启动已启用")
            return true
            
        } catch {
            LogManager.shared.error("LaunchAgentManager", "启用开机自启动失败: \(error)")
            lastError = error
            return false
        }
    }
    
    /// 禁用开机自启动
    public func disableLaunchAtLogin() async -> Bool {
        do {
            // 卸载Launch Agent
            try await unloadLaunchAgent()
            
            // 删除plist文件
            try removeLaunchAgentPlist()
            
            await updateStatus()
            
            LogManager.shared.info("LaunchAgentManager", "开机自启动已禁用")
            return true
            
        } catch {
            LogManager.shared.error("LaunchAgentManager", "禁用开机自启动失败: \(error)")
            lastError = error
            return false
        }
    }
    
    /// 切换开机自启动状态
    public func toggleLaunchAtLogin() async -> Bool {
        if isEnabled {
            return await disableLaunchAtLogin()
        } else {
            return await enableLaunchAtLogin()
        }
    }
    
    /// 检查Launch Agent状态
    public func checkStatus() async -> LaunchAgentStatus {
        await updateStatus()
        return status
    }
    
    /// 重新加载Launch Agent
    public func reloadLaunchAgent() async -> Bool {
        do {
            if status == .enabled {
                try await unloadLaunchAgent()
            }
            
            try await loadLaunchAgent()
            await updateStatus()
            
            LogManager.shared.info("LaunchAgentManager", "Launch Agent已重新加载")
            return true
            
        } catch {
            LogManager.shared.error("LaunchAgentManager", "重新加载Launch Agent失败: \(error)")
            lastError = error
            return false
        }
    }
    
    /// 修复Launch Agent配置
    public func repairConfiguration() async -> Bool {
        do {
            // 强制删除旧配置
            try? removeLaunchAgentPlist()
            try? await unloadLaunchAgent()
            
            // 重新创建配置
            try createLaunchAgentsDirectoryIfNeeded()
            try createLaunchAgentPlist()
            try await loadLaunchAgent()
            
            await updateStatus()
            
            LogManager.shared.info("LaunchAgentManager", "Launch Agent配置已修复")
            return true
            
        } catch {
            LogManager.shared.error("LaunchAgentManager", "修复Launch Agent配置失败: \(error)")
            lastError = error
            return false
        }
    }
    
    // MARK: - 私有方法
    
    /// 更新状态
    private func updateStatus() async {
        let plistExists = fileManager.fileExists(atPath: plistURL.path)
        let isLoaded = await checkIfLaunchAgentLoaded()
        
        await MainActor.run {
            if !plistExists {
                status = .notInstalled
                isEnabled = false
            } else if isLoaded {
                status = .enabled
                isEnabled = true
            } else {
                status = .installed
                isEnabled = false
            }
        }
        
        LogManager.shared.debug("LaunchAgentManager", """
            状态更新:
            Plist存在: \(plistExists)
            已加载: \(isLoaded)
            当前状态: \(status.rawValue)
            """)
    }
    
    /// 创建LaunchAgents目录
    private func createLaunchAgentsDirectoryIfNeeded() throws {
        if !fileManager.fileExists(atPath: launchAgentsDirectory.path) {
            try fileManager.createDirectory(
                at: launchAgentsDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            LogManager.shared.info("LaunchAgentManager", "已创建LaunchAgents目录: \(launchAgentsDirectory.path)")
        }
    }
    
    /// 创建Launch Agent plist文件
    private func createLaunchAgentPlist() throws {
        let plistDict = createPlistDictionary()
        
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plistDict,
            format: .xml,
            options: 0
        )
        
        try plistData.write(to: plistURL)
        
        LogManager.shared.info("LaunchAgentManager", "已创建plist文件: \(plistURL.path)")
    }
    
    /// 删除Launch Agent plist文件
    private func removeLaunchAgentPlist() throws {
        if fileManager.fileExists(atPath: plistURL.path) {
            try fileManager.removeItem(at: plistURL)
            LogManager.shared.info("LaunchAgentManager", "已删除plist文件: \(plistURL.path)")
        }
    }
    
    /// 创建plist字典
    private func createPlistDictionary() -> [String: Any] {
        // 总是使用ProgramArguments而不是Program（macOS推荐格式）
        var programArguments = [configuration.executablePath]
        programArguments.append(contentsOf: configuration.arguments)
        
        var plist: [String: Any] = [
            "Label": configuration.bundleIdentifier,
            "ProgramArguments": programArguments,
            "RunAtLoad": configuration.runAtLoad,
            "KeepAlive": false  // 明确设置，避免重复启动
        ]
        
        // 添加环境变量
        if !configuration.environmentVariables.isEmpty {
            plist["EnvironmentVariables"] = configuration.environmentVariables
        }
        
        // KeepAlive已在初始化时设置为false，不需要重复设置
        
        // 添加监视路径
        if !configuration.watchPaths.isEmpty {
            plist["WatchPaths"] = configuration.watchPaths
        }
        
        // 添加队列目录
        if !configuration.queueDirectories.isEmpty {
            plist["QueueDirectories"] = configuration.queueDirectories
        }
        
        // 添加标准输出和错误输出重定向
        let logDirectory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Logs")
            .appendingPathComponent("HelloPrompt")
        
        // 确保日志目录存在
        try? fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        
        plist["StandardOutPath"] = logDirectory.appendingPathComponent("launch-agent.out.log").path
        plist["StandardErrorPath"] = logDirectory.appendingPathComponent("launch-agent.err.log").path
        
        // 设置工作目录为应用包目录
        if let appBundle = Bundle.main.bundleURL.deletingLastPathComponent().path.isEmpty ? nil : Bundle.main.bundleURL.deletingLastPathComponent().path {
            plist["WorkingDirectory"] = appBundle
        }
        
        return plist
    }
    
    /// 加载Launch Agent
    private func loadLaunchAgent() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", plistURL.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        if process.terminationStatus != 0 {
            throw LaunchAgentError.loadFailed(output)
        }
        
        LogManager.shared.info("LaunchAgentManager", "Launch Agent已加载")
    }
    
    /// 卸载Launch Agent
    private func unloadLaunchAgent() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["unload", plistURL.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        // launchctl unload可能会返回非零状态，即使操作成功
        // 所以我们不检查terminationStatus，而是检查实际状态
        
        LogManager.shared.info("LaunchAgentManager", "Launch Agent卸载完成: \(output)")
    }
    
    /// 检查Launch Agent是否已加载
    private func checkIfLaunchAgentLoaded() async -> Bool {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["list", configuration.bundleIdentifier]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            process.terminationHandler = { process in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                // 如果找到对应的bundle identifier，说明已加载
                let bundleId = self.configuration.bundleIdentifier
                let isLoaded = process.terminationStatus == 0 && output.contains(bundleId)
                continuation.resume(returning: isLoaded)
            }
            
            do {
                try process.run()
            } catch {
                LogManager.shared.debug("LaunchAgentManager", "检查Launch Agent状态失败: \(error)")
                continuation.resume(returning: false)
            }
        }
    }
    
    // MARK: - 诊断和维护
    
    /// 获取Launch Agent详细信息
    public func getLaunchAgentInfo() async -> [String: Any] {
        var info: [String: Any] = [
            "status": status.rawValue,
            "isEnabled": isEnabled,
            "bundleIdentifier": configuration.bundleIdentifier,
            "executablePath": configuration.executablePath,
            "plistExists": fileManager.fileExists(atPath: plistURL.path),
            "plistPath": plistURL.path
        ]
        
        // 获取plist内容
        if fileManager.fileExists(atPath: plistURL.path) {
            do {
                let plistData = try Data(contentsOf: plistURL)
                if let plistDict = try PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] {
                    info["plistContent"] = plistDict
                }
            } catch {
                info["plistReadError"] = error.localizedDescription
            }
        }
        
        // 获取launchctl状态
        info["launchctlStatus"] = await getLaunchctlStatus()
        
        return info
    }
    
    /// 获取launchctl状态信息
    private func getLaunchctlStatus() async -> [String: Any] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["list"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            // 查找我们的Launch Agent
            let lines = output.components(separatedBy: .newlines)
            for line in lines {
                if line.contains(configuration.bundleIdentifier) {
                    let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    if components.count >= 3 {
                        return [
                            "pid": components[0],
                            "status": components[1],
                            "label": components[2],
                            "found": true
                        ]
                    }
                }
            }
            
            return ["found": false, "allOutput": output]
            
        } catch {
            return ["error": error.localizedDescription]
        }
    }
    
    /// 验证配置完整性
    public func validateConfiguration() -> [String] {
        var issues: [String] = []
        
        // 检查可执行文件路径
        if configuration.executablePath.isEmpty {
            issues.append("可执行文件路径为空")
        } else if !fileManager.fileExists(atPath: configuration.executablePath) {
            issues.append("可执行文件不存在: \(configuration.executablePath)")
        } else if !fileManager.isExecutableFile(atPath: configuration.executablePath) {
            issues.append("文件不可执行: \(configuration.executablePath)")
        }
        
        // 检查Bundle ID格式
        if !configuration.bundleIdentifier.contains(".") {
            issues.append("Bundle ID格式不正确: \(configuration.bundleIdentifier)")
        }
        
        // 检查LaunchAgents目录权限
        let launchAgentsPath = launchAgentsDirectory.path
        if !fileManager.fileExists(atPath: launchAgentsPath) {
            issues.append("LaunchAgents目录不存在: \(launchAgentsPath)")
        } else if !fileManager.isWritableFile(atPath: launchAgentsPath) {
            issues.append("LaunchAgents目录不可写: \(launchAgentsPath)")
        }
        
        // 检查plist文件
        if fileManager.fileExists(atPath: plistURL.path) {
            do {
                let plistData = try Data(contentsOf: plistURL)
                _ = try PropertyListSerialization.propertyList(from: plistData, format: nil)
            } catch {
                issues.append("plist文件格式错误: \(error.localizedDescription)")
            }
        }
        
        return issues
    }
    
    /// 清理所有相关文件
    public func cleanupAllFiles() async -> Bool {
        do {
            // 卸载Launch Agent
            if status == .enabled {
                try await unloadLaunchAgent()
            }
            
            // 删除plist文件
            try removeLaunchAgentPlist()
            
            // 清理日志文件
            let logDirectory = fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library")
                .appendingPathComponent("Logs")
                .appendingPathComponent("HelloPrompt")
            
            if fileManager.fileExists(atPath: logDirectory.path) {
                let logFiles = ["launch-agent.out.log", "launch-agent.err.log"]
                for logFile in logFiles {
                    let logPath = logDirectory.appendingPathComponent(logFile)
                    try? fileManager.removeItem(at: logPath)
                }
            }
            
            await updateStatus()
            
            LogManager.shared.info("LaunchAgentManager", "所有相关文件已清理")
            return true
            
        } catch {
            LogManager.shared.error("LaunchAgentManager", "清理文件失败: \(error)")
            lastError = error
            return false
        }
    }
    
    // MARK: - 错误处理
    
    /// 处理Launch Agent错误
    private func handleError(_ error: Error) {
        lastError = error
        status = .error
        
        LogManager.shared.error("LaunchAgentManager", "Launch Agent错误: \(error)")
        
        // 根据错误类型提供不同的处理策略
        if let launchError = error as? LaunchAgentError {
            switch launchError {
            case .loadFailed:
                // 尝试修复配置
                Task {
                    _ = await repairConfiguration()
                }
            case .permissionDenied:
                // 提示用户检查权限
                break
            case .invalidConfiguration:
                // 重新创建配置
                Task {
                    _ = await repairConfiguration()
                }
            case .fileSystemError(_):
                // 文件系统错误处理
                break
            }
        }
    }
}

// MARK: - Launch Agent错误类型
public enum LaunchAgentError: LocalizedError {
    case loadFailed(String)
    case permissionDenied
    case invalidConfiguration(String)
    case fileSystemError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .loadFailed(let output):
            return "Launch Agent加载失败: \(output)"
        case .permissionDenied:
            return "权限不足，无法操作Launch Agent"
        case .invalidConfiguration(let reason):
            return "配置无效: \(reason)"
        case .fileSystemError(let error):
            return "文件系统错误: \(error.localizedDescription)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .loadFailed:
            return "请检查应用程序路径和权限设置"
        case .permissionDenied:
            return "请检查用户权限和系统安全设置"
        case .invalidConfiguration:
            return "请重新配置Launch Agent参数"
        case .fileSystemError:
            return "请检查磁盘空间和文件权限"
        }
    }
}

// MARK: - 便捷扩展
extension LaunchAgentManager {
    
    /// 快速设置开机自启动
    public static func setLaunchAtLogin(_ enabled: Bool) async -> Bool {
        if enabled {
            return await shared.enableLaunchAtLogin()
        } else {
            return await shared.disableLaunchAtLogin()
        }
    }
    
    /// 检查当前是否启用开机自启动
    public static func isLaunchAtLoginEnabled() async -> Bool {
        let status = await shared.checkStatus()
        return status == .enabled
    }
    
    /// 获取启动代理状态描述
    public var statusDescription: String {
        switch status {
        case .notInstalled:
            return "未配置开机自启动"
        case .installed:
            return "已配置但未启用"
        case .enabled:
            return "开机自启动已启用"
        case .disabled:
            return "开机自启动已禁用"
        case .error:
            return "配置错误: \(lastError?.localizedDescription ?? "未知错误")"
        }
    }
}