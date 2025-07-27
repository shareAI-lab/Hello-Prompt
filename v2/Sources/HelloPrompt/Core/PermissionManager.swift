//
//  PermissionManager.swift
//  HelloPrompt
//
//  智能权限管理器 - 统一管理应用权限状态、监听权限变化、智能处理权限申请
//  解决权限检查逻辑问题和用户体验问题
//

import Foundation
import SwiftUI
import AVFoundation
import ApplicationServices
import Combine
import AppKit
import UserNotifications

// MARK: - 权限类型枚举
public enum PermissionType: String, CaseIterable {
    case microphone = "microphone"
    case accessibility = "accessibility"
    case notification = "notification"
    
    var displayName: String {
        switch self {
        case .microphone: return "Microphone Access"
        case .accessibility: return "Accessibility Access"
        case .notification: return "Notification Access"
        }
    }
    
    var systemName: String {
        switch self {
        case .microphone: return "mic"
        case .accessibility: return "person.crop.circle.badge.checkmark"
        case .notification: return "bell"
        }
    }
    
    var localizedReason: String {
        switch self {
        case .microphone:
            return "HelloPrompt needs microphone access to record your voice and convert it to optimized AI prompts."
        case .accessibility:
            return "HelloPrompt needs accessibility access to detect global keyboard shortcuts and insert optimized text into other applications."
        case .notification:
            return "HelloPrompt would like to send you notifications about processing status and when your optimized prompts are ready."
        }
    }
}

// MARK: - 权限状态枚举
public enum PermissionStatus: Equatable {
    case granted
    case denied
    case notDetermined
    case restricted
    case unknown
    
    var statusText: String {
        switch self {
        case .granted: return "Granted"
        case .denied: return "Denied"
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        case .unknown: return "Unknown"
        }
    }
    
    var statusColor: Color {
        switch self {
        case .granted: return .green
        case .denied: return .red
        case .notDetermined: return .orange
        case .restricted: return .red
        case .unknown: return .gray
        }
    }
    
    var isGranted: Bool {
        return self == .granted
    }
    
    var canRequest: Bool {
        return self == .notDetermined
    }
}

public extension PermissionType {
    var priority: Int {
        switch self {
        case .microphone: return 1      // 核心功能，最高优先级
        case .accessibility: return 2   // 增强功能，次要优先级
        case .notification: return 3    // 提示功能，最低优先级
        }
    }
    
    var isRequired: Bool {
        switch self {
        case .microphone: return true   // 录音功能必需
        case .accessibility: return false // 可选，但影响用户体验
        case .notification: return false // 可选，用于提醒用户
        }
    }
    
    var description: String {
        switch self {
        case .microphone: return "用于录制您的语音输入"
        case .accessibility: return "用于全局快捷键和文本插入功能"
        case .notification: return "用于发送系统通知和提醒"
        }
    }
    
    var icon: String {
        switch self {
        case .microphone: return "mic.fill"
        case .accessibility: return "accessibility"
        case .notification: return "bell.fill"
        }
    }
}

// MARK: - 权限状态结构
public struct PermissionState {
    let type: PermissionType
    let status: PermissionStatus
    let lastChecked: Date
    let requestCount: Int
    
    var isGranted: Bool { status == .granted }
    var needsRefresh: Bool { 
        Date().timeIntervalSince(lastChecked) > 5.0 // 5秒后状态可能过期
    }
}

// MARK: - 权限变化事件
public struct PermissionChangeEvent {
    let type: PermissionType
    let oldStatus: PermissionStatus
    let newStatus: PermissionStatus
    let timestamp: Date
}

// MARK: - 智能权限管理器
@MainActor
public final class PermissionManager: ObservableObject {
    
    // MARK: - 单例
    public static let shared = PermissionManager()
    
    // MARK: - Published Properties
    @Published public var permissionStates: [PermissionType: PermissionState] = [:]
    @Published public var isCheckingPermissions = false
    @Published public var shouldShowPermissionWindow = false
    @Published public var currentPermissionRequest: PermissionType?
    
    // MARK: - Public Properties
    public var allPermissionsGranted: Bool {
        PermissionType.allCases.allSatisfy { type in
            permissionStates[type]?.isGranted ?? false
        }
    }
    
    public var corePermissionsGranted: Bool {
        PermissionType.allCases.filter(\.isRequired).allSatisfy { type in
            permissionStates[type]?.isGranted ?? false
        }
    }
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var permissionCheckTimer: Timer?
    private var applicationStateObserver: NSKeyValueObservation?
    
    // 权限申请历史记录
    private var permissionRequestHistory: [PermissionType: [Date]] = [:]
    private let maxRequestsPerHour = 3 // 每小时最多申请3次
    
    // 权限变化回调
    public var onPermissionChanged: ((PermissionChangeEvent) -> Void)?
    
    // MARK: - 初始化
    private init() {
        setupPermissionStates()
        setupApplicationStateObserver()
        setupPeriodicCheck()
        startPermissionMonitoring()
        
        LogManager.shared.info("PermissionManager", "智能权限管理器已初始化")
    }
    
    deinit {
        permissionCheckTimer?.invalidate()
        applicationStateObserver?.invalidate()
    }
    
    // MARK: - 权限状态初始化
    private func setupPermissionStates() {
        for type in PermissionType.allCases {
            permissionStates[type] = PermissionState(
                type: type,
                status: .notDetermined,
                lastChecked: Date.distantPast,
                requestCount: 0
            )
        }
    }
    
    // MARK: - 应用状态监听
    private func setupApplicationStateObserver() {
        // 监听应用激活状态
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.checkAllPermissions(reason: "应用激活")
                }
            }
            .store(in: &cancellables)
        
        // 监听应用失去焦点
        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
            .sink { [weak self] _ in
                self?.currentPermissionRequest = nil
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 定期权限检查
    private func setupPeriodicCheck() {
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkAllPermissions(reason: "定期检查")
            }
        }
    }
    
    // MARK: - 权限检查核心方法
    
    /// 检查所有权限状态
    public func checkAllPermissions(reason: String = "手动检查") async {
        guard !isCheckingPermissions else { return }
        
        isCheckingPermissions = true
        LogManager.shared.info("PermissionManager", "开始权限检查，原因：\(reason)")
        
        defer {
            isCheckingPermissions = false
        }
        
        for type in PermissionType.allCases {
            await checkPermission(type)
        }
        
        // 智能决定是否显示权限窗口
        updatePermissionWindowVisibility()
        
        LogManager.shared.info("PermissionManager", "权限检查完成，核心权限: \(corePermissionsGranted), 全部权限: \(allPermissionsGranted)")
    }
    
    /// 检查单个权限状态
    public func checkPermission(_ type: PermissionType) async {
        let currentState = permissionStates[type]
        
        // 如果状态仍然有效，跳过检查
        if let state = currentState, !state.needsRefresh {
            return
        }
        
        let newStatus = await getPermissionStatus(type)
        let oldStatus = currentState?.status ?? .notDetermined
        
        // 更新权限状态
        permissionStates[type] = PermissionState(
            type: type,
            status: newStatus,
            lastChecked: Date(),
            requestCount: currentState?.requestCount ?? 0
        )
        
        // 检测权限变化
        if oldStatus != newStatus {
            let event = PermissionChangeEvent(
                type: type,
                oldStatus: oldStatus,
                newStatus: newStatus,
                timestamp: Date()
            )
            
            LogManager.shared.info("PermissionManager", "权限状态变化：\(type.rawValue) \(oldStatus.statusText) -> \(newStatus.statusText)")
            
            // 触发权限变化回调
            onPermissionChanged?(event)
            
            // 如果权限被授权，立即更新UI状态
            if newStatus == .granted && oldStatus != .granted {
                LogManager.shared.info("PermissionManager", "权限被授权，立即更新UI状态")
                updatePermissionWindowVisibility()
                
                // 强制刷新全部权限状态
                Task {
                    await forceRefreshCorePermissions()
                }
            }
        }
    }
    
    /// 强制刷新核心权限状态
    private func forceRefreshCorePermissions() async {
        LogManager.shared.info("PermissionManager", "强制刷新核心权限状态")
        
        // 清除麦克风权限缓存
        permissionStates[.microphone] = PermissionState(
            type: .microphone,
            status: .notDetermined,
            lastChecked: Date.distantPast,
            requestCount: permissionStates[.microphone]?.requestCount ?? 0
        )
        
        // 立即重新检查
        await checkPermission(.microphone)
        
        // 更新UI
        updatePermissionWindowVisibility()
    }
    
    /// 获取实际权限状态
    private func getPermissionStatus(_ type: PermissionType) async -> PermissionStatus {
        switch type {
        case .microphone:
            return await getMicrophonePermissionStatus()
        case .accessibility:
            return getAccessibilityPermissionStatus()
        case .notification:
            return await getNotificationPermissionStatusAsync()
        }
    }
    
    private func getMicrophonePermissionStatus() async -> PermissionStatus {
        let authStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch authStatus {
        case .authorized:
            return .granted
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .unknown
        }
    }
    
    private func getAccessibilityPermissionStatus() -> PermissionStatus {
        let isEnabled = AXIsProcessTrusted()
        return isEnabled ? .granted : .notDetermined // Don't assume denied unless explicitly denied
    }
    
    private func getNotificationPermissionStatus() -> PermissionStatus {
        // 对于同步方法，我们返回一个基本检查
        // 实际的权限状态将在异步检查中更新
        
        // 添加bundle检查，避免崩溃
        guard Bundle.main.bundleIdentifier != nil else {
            LogManager.shared.warning("PermissionManager", "Bundle标识符缺失，跳过通知权限检查（同步版本）")
            return .notDetermined
        }
        
        // 暂时返回未确定状态，实际状态将通过异步检查获取
        return .notDetermined
    }
    
    private func getNotificationPermissionStatusAsync() async -> PermissionStatus {
        // Add bundle checks to avoid crashes
        guard Bundle.main.bundleIdentifier != nil else {
            LogManager.shared.warning("PermissionManager", "Bundle identifier missing, skipping notification permission check")
            return .unknown
        }
        
        // Use safe method to get UNUserNotificationCenter
        guard let center = getNotificationCenterSafely() else {
            LogManager.shared.warning("PermissionManager", "Cannot safely get UNUserNotificationCenter, skipping notification permission check")
            return .unknown
        }
        
        return await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                let status: PermissionStatus
                switch settings.authorizationStatus {
                case .authorized:
                    status = .granted
                case .provisional:
                    status = .granted
                case .denied:
                    status = .denied
                case .notDetermined:
                    status = .notDetermined
                case .ephemeral:
                    status = .granted
                @unknown default:
                    status = .unknown
                }
                continuation.resume(returning: status)
            }
        }
    }
    
    /// 安全地获取UNUserNotificationCenter实例  
    private func getNotificationCenterSafely() -> UNUserNotificationCenter? {
        // 临时解决方案：跳过通知权限检查以避免崩溃
        // 这是因为在某些bundle配置不正确的情况下，UNUserNotificationCenter.current()会崩溃
        // 优先级：让应用不崩溃 > 完整的通知功能
        
        LogManager.shared.warning("PermissionManager", "为避免崩溃，暂时跳过UNUserNotificationCenter初始化")
        return nil
    }
    
    // MARK: - 权限申请
    
    /// 申请权限 (Modern API)
    public func requestPermission(_ type: PermissionType) async -> PermissionStatus {
        LogManager.shared.info("PermissionManager", "Requesting permission for: \(type.displayName)")
        
        // 检查申请频率限制
        if !canRequestPermission(type) {
            LogManager.shared.warning("PermissionManager", "Permission request rate limited: \(type.rawValue)")
            return getPermissionStatus(type)
        }
        
        // 记录申请历史
        recordPermissionRequest(type)
        
        currentPermissionRequest = type
        
        let newStatus: PermissionStatus
        switch type {
        case .microphone:
            newStatus = await requestMicrophonePermissionModern()
        case .accessibility:
            newStatus = await requestAccessibilityPermissionModern()
        case .notification:
            newStatus = await requestNotificationPermissionModern()
        }
        
        // 更新权限状态
        await updatePermissionState(type, status: newStatus)
        
        currentPermissionRequest = nil
        
        LogManager.shared.info("PermissionManager", "Permission request completed for \(type.displayName): \(newStatus.statusText)")
        
        return newStatus
    }
    
    /// 申请权限 (Legacy Bool API for backward compatibility)
    public func requestPermissionLegacy(_ type: PermissionType) async -> Bool {
        let status = await requestPermission(type)
        return status.isGranted
    }
    
    /// 批量申请权限
    public func requestPermissions(_ types: [PermissionType]) async -> [PermissionType: PermissionStatus] {
        var results: [PermissionType: PermissionStatus] = [:]
        
        for type in types.sorted(by: { $0.priority < $1.priority }) {
            let status = await requestPermission(type)
            results[type] = status
            
            // Add small delay between requests for better UX
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        return results
    }
    
    /// 申请所有必需权限
    public func requestAllRequiredPermissions() async -> Bool {
        let requiredTypes = PermissionType.allCases.filter(\.isRequired)
        let results = await requestPermissions(requiredTypes)
        
        return requiredTypes.allSatisfy { type in
            results[type]?.isGranted ?? false
        }
    }
    
    // MARK: - Modern Permission Request Methods
    
    private func requestMicrophonePermissionModern() async -> PermissionStatus {
        let currentStatus = await getMicrophonePermissionStatus()
        
        // If already granted or denied, return current status
        if currentStatus != .notDetermined {
            return currentStatus
        }
        
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                let status: PermissionStatus = granted ? .granted : .denied
                continuation.resume(returning: status)
            }
        }
    }
    
    private func requestAccessibilityPermissionModern() async -> PermissionStatus {
        let currentStatus = getAccessibilityPermissionStatus()
        
        // If already granted, return immediately
        if currentStatus == .granted {
            return .granted
        }
        
        // Show modern permission dialog
        let granted = await showAccessibilityPermissionDialog()
        
        if granted {
            // Wait for user to grant permission in System Preferences
            return await waitForAccessibilityPermission()
        }
        
        return .denied
    }
    
    private func requestNotificationPermissionModern() async -> PermissionStatus {
        // Check bundle status to avoid crashes
        guard Bundle.main.bundleIdentifier != nil else {
            LogManager.shared.warning("PermissionManager", "Bundle identifier missing, skipping notification permission request")
            return .unknown
        }
        
        // Use safe method to get UNUserNotificationCenter
        guard let center = getNotificationCenterSafely() else {
            LogManager.shared.warning("PermissionManager", "Cannot safely get UNUserNotificationCenter, skipping notification permission request")
            return .unknown
        }
        
        // Check current status first
        let currentStatus = await getNotificationPermissionStatusAsync()
        if currentStatus != .notDetermined {
            return currentStatus
        }
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted ? .granted : .denied
        } catch {
            LogManager.shared.error("PermissionManager", "Failed to request notification permission: \(error)")
            return .denied
        }
    }
    
    // MARK: - Permission Dialog Methods
    
    @MainActor
    private func showAccessibilityPermissionDialog() async -> Bool {
        return await withCheckedContinuation { continuation in
            let alert = NSAlert()
            alert.messageText = "Accessibility Access Required"
            alert.informativeText = """
            HelloPrompt needs accessibility access to provide these features:
            
            • Global keyboard shortcut detection
            • Insert optimized text into other applications
            • Detect the currently active application
            
            Click "Open System Preferences" to grant this permission. You'll need to add HelloPrompt to the accessibility list.
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Open System Preferences")
            alert.addButton(withTitle: "Not Now")
            
            let response = alert.runModal()
            
            if response == .alertFirstButtonReturn {
                openAccessibilitySystemPreferences()
                continuation.resume(returning: true)
            } else {
                continuation.resume(returning: false)
            }
        }
    }
    
    private func openAccessibilitySystemPreferences() {
        // Try different URLs for different macOS versions
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.Settings.PrivacySecurity.Privacy?Accessibility"
        ]
        
        for urlString in urls {
            if let url = URL(string: urlString) {
                if NSWorkspace.shared.open(url) {
                    LogManager.shared.info("PermissionManager", "Opened accessibility system preferences")
                    return
                }
            }
        }
        
        // Fallback to general security preferences
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func waitForAccessibilityPermission() async -> PermissionStatus {
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            
            let checkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                Task { @MainActor in
                    let isGranted = AXIsProcessTrusted()
                    
                    if isGranted && !hasResumed {
                        hasResumed = true
                        timer.invalidate()
                        
                        // Show success notification
                        await self.showAccessibilityPermissionGrantedNotification()
                        
                        continuation.resume(returning: .granted)
                    }
                }
            }
            
            // Timeout after 60 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 60.0) {
                if !hasResumed {
                    hasResumed = true
                    checkTimer.invalidate()
                    continuation.resume(returning: .denied)
                }
            }
        }
    }
    
    @MainActor
    private func showAccessibilityPermissionGrantedNotification() async {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Granted"
        alert.informativeText = "Thank you! HelloPrompt can now use all accessibility features."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Continue")
        
        // Show briefly and auto-dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            alert.runModal()
        }
    }
    
    // MARK: - Helper Methods
    
    /// 更新权限状态
    private func updatePermissionState(_ type: PermissionType, status: PermissionStatus) async {
        let currentState = permissionStates[type]
        let oldStatus = currentState?.status ?? .notDetermined
        
        // Update permission state
        permissionStates[type] = PermissionState(
            type: type,
            status: status,
            lastChecked: Date(),
            requestCount: (currentState?.requestCount ?? 0) + 1
        )
        
        // Detect permission changes
        if oldStatus != status {
            let event = PermissionChangeEvent(
                type: type,
                oldStatus: oldStatus,
                newStatus: status,
                timestamp: Date()
            )
            
            LogManager.shared.info("PermissionManager", "Permission status changed: \(type.displayName) \(oldStatus.statusText) -> \(status.statusText)")
            
            // Trigger permission change callback
            onPermissionChanged?(event)
            
            // If permission was granted, immediately update UI state
            if status == .granted && oldStatus != .granted {
                LogManager.shared.info("PermissionManager", "Permission granted, immediately updating UI state")
                updatePermissionWindowVisibility()
                
                // Force refresh all permission states
                Task {
                    await forceRefreshCorePermissions()
                }
            }
        }
    }
    
    /// 等待用户在系统设置中授权辅助功能权限
    private func startWaitingForAccessibilityPermission() {
        let checkTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                
                await self.checkPermission(.accessibility)
                
                if self.permissionStates[.accessibility]?.isGranted == true {
                    timer.invalidate()
                    
                    // 显示授权成功提示
                    let successAlert = NSAlert()
                    successAlert.messageText = "辅助功能权限已授权"
                    successAlert.informativeText = "感谢您的授权！Hello Prompt v2 现在可以正常使用全部功能。"
                    successAlert.alertStyle = .informational
                    successAlert.addButton(withTitle: "好的")
                    successAlert.runModal()
                    
                    // 更新UI
                    self.updatePermissionWindowVisibility()
                }
            }
        }
        
        // 30秒后停止检查
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
            checkTimer.invalidate()
        }
    }
    
    private func requestNotificationPermission() async -> Bool {
        // 检查bundle状态，避免崩溃
        guard Bundle.main.bundleIdentifier != nil else {
            LogManager.shared.warning("PermissionManager", "Bundle标识符缺失，跳过通知权限申请")
            return false
        }
        
        // 使用安全方式获取UNUserNotificationCenter
        guard let center = getNotificationCenterSafely() else {
            LogManager.shared.warning("PermissionManager", "无法安全获取UNUserNotificationCenter，跳过通知权限申请")
            return false
        }
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            LogManager.shared.error("PermissionManager", "申请通知权限失败: \(error)")
            return false
        }
    }
    
    // MARK: - 权限申请频率控制
    
    private func canRequestPermission(_ type: PermissionType) -> Bool {
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        
        let recentRequests = permissionRequestHistory[type]?.filter { $0 > oneHourAgo } ?? []
        return recentRequests.count < maxRequestsPerHour
    }
    
    private func recordPermissionRequest(_ type: PermissionType) {
        if permissionRequestHistory[type] == nil {
            permissionRequestHistory[type] = []
        }
        permissionRequestHistory[type]?.append(Date())
        
        // 清理旧记录
        let oneHourAgo = Date().addingTimeInterval(-3600)
        permissionRequestHistory[type] = permissionRequestHistory[type]?.filter { $0 > oneHourAgo }
    }
    
    // MARK: - 智能UI控制
    
    /// 智能决定是否显示权限申请窗口
    private func updatePermissionWindowVisibility() {
        let shouldShow = calculateShouldShowPermissionWindow()
        
        if self.shouldShowPermissionWindow != shouldShow {
            self.shouldShowPermissionWindow = shouldShow
            
            LogManager.shared.info("PermissionManager", "权限窗口显示状态更新：\(shouldShow)")
            
            // 立即触发UI更新
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    private func calculateShouldShowPermissionWindow() -> Bool {
        // 强制刷新权限状态，确保获取最新状态
        let micStatus = getMicrophonePermissionStatusSync()
        let accStatus = getAccessibilityPermissionStatus()
        
        LogManager.shared.debug("PermissionManager", "权限窗口决策 - 麦克风: \(micStatus.statusText), 辅助功能: \(accStatus.statusText)")
        
        // 如果麦克风权限已授权，窗口应该关闭
        if micStatus == .granted {
            LogManager.shared.info("PermissionManager", "麦克风权限已授权，关闭权限窗口")
            return false
        }
        
        // 如果正在申请权限，保持窗口显示
        if currentPermissionRequest != nil {
            return true
        }
        
        // 如果核心权限（麦克风）未授权，需要显示窗口
        if micStatus != .granted {
            return true
        }
        
        return false
    }
    
    /// 同步获取麦克风权限状态（用于即时检查）
    private func getMicrophonePermissionStatusSync() -> PermissionStatus {
        let authStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch authStatus {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }
    
    /// 实时获取辅助功能权限状态（绕过缓存）
    public func checkAccessibilityPermissionRealTime() -> Bool {
        return AXIsProcessTrusted()
    }
    
    /// 强制刷新辅助功能权限状态
    public func forceRefreshAccessibilityPermission() async {
        let realTimeStatus = checkAccessibilityPermissionRealTime()
        let newStatus: PermissionStatus = realTimeStatus ? .granted : .denied
        let oldStatus = permissionStates[.accessibility]?.status ?? .notDetermined
        
        // 强制更新状态
        permissionStates[.accessibility] = PermissionState(
            type: .accessibility,
            status: newStatus,
            lastChecked: Date(),
            requestCount: permissionStates[.accessibility]?.requestCount ?? 0
        )
        
        // 如果状态发生变化，触发通知
        if oldStatus != newStatus {
            let event = PermissionChangeEvent(
                type: .accessibility,
                oldStatus: oldStatus,
                newStatus: newStatus,
                timestamp: Date()
            )
            onPermissionChanged?(event)
            
            LogManager.shared.info("PermissionManager", "辅助功能权限状态强制更新：\(oldStatus.statusText) -> \(newStatus.statusText)")
        }
        
        updatePermissionWindowVisibility()
    }
    
    // MARK: - 公共接口
    
    /// 获取权限状态
    public func getPermissionStatus(_ type: PermissionType) -> PermissionStatus {
        return permissionStates[type]?.status ?? .notDetermined
    }
    
    /// 是否有权限
    public func hasPermission(_ type: PermissionType) -> Bool {
        return getPermissionStatus(type) == .granted
    }
    
    /// 异步权限检查，确保获得最新状态
    public func hasPermissionAsync(_ type: PermissionType) async -> Bool {
        await checkPermission(type)
        return hasPermission(type)
    }
    
    // MARK: - 便捷权限检查属性
    
    /// 是否有麦克风权限
    public var hasMicrophonePermission: Bool {
        return hasPermission(.microphone)
    }
    
    /// 是否有辅助功能权限
    public var hasAccessibilityPermission: Bool {
        return hasPermission(.accessibility)
    }
    
    /// 是否有通知权限
    public var hasNotificationPermission: Bool {
        return hasPermission(.notification)
    }
    
    // MARK: - 兼容性方法（用于ConfigurationValidator）
    
    /// 检查麦克风权限（异步版本）
    public func checkMicrophonePermission() async -> Bool {
        return await getPermissionStatus(.microphone) == .granted
    }
    
    /// 检查辅助功能权限（同步版本）
    public func checkAccessibilityPermission() -> Bool {
        return hasPermission(.accessibility)
    }
    
    /// 检查通知权限（异步版本）
    public func checkNotificationPermission() async -> Bool {
        return await getPermissionStatus(.notification) == .granted
    }
    
    /// 获取未授权的必需权限
    public func getMissingRequiredPermissions() -> [PermissionType] {
        return PermissionType.allCases.filter { type in
            type.isRequired && !hasPermission(type)
        }
    }
    
    /// 获取未授权的可选权限
    public func getMissingOptionalPermissions() -> [PermissionType] {
        return PermissionType.allCases.filter { type in
            !type.isRequired && !hasPermission(type)
        }
    }
    
    /// 强制刷新所有权限状态
    public func forceRefreshPermissions() async {
        for type in PermissionType.allCases {
            // 清除缓存，强制重新检查
            permissionStates[type] = PermissionState(
                type: type,
                status: .notDetermined,
                lastChecked: Date.distantPast,
                requestCount: permissionStates[type]?.requestCount ?? 0
            )
        }
        
        await checkAllPermissions(reason: "强制刷新")
    }
    
    /// 立即检查权限状态并更新UI（用于解决权限已授权但窗口仍显示的问题）
    public func immediatePermissionCheck() async {
        LogManager.shared.info("PermissionManager", "执行立即权限检查")
        
        // 强制清除缓存并重新检查麦克风权限
        await forceRefreshCorePermissions()
        
        // 同时强制刷新辅助功能权限
        await forceRefreshAccessibilityPermission()
        
        // 立即更新UI状态
        updatePermissionWindowVisibility()
        
        LogManager.shared.info("PermissionManager", "立即权限检查完成 - 窗口应显示: \(shouldShowPermissionWindow)")
    }
    
    /// 启动权限状态监控
    public func startPermissionMonitoring() {
        // 每2秒检查一次辅助功能权限状态变化
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                
                let currentStatus = self.checkAccessibilityPermissionRealTime()
                let previousStatus = self.hasPermission(.accessibility)
                
                if currentStatus != previousStatus {
                    LogManager.shared.info("PermissionManager", "检测到辅助功能权限状态变化：\(previousStatus) -> \(currentStatus)")
                    await self.forceRefreshAccessibilityPermission()
                    
                    if currentStatus {
                        // 权限刚被授权，通知HotkeyService重新初始化
                        HotkeyService.shared.reinitializeEventTap()
                    }
                }
            }
        }
    }
    
    /// 获取权限申请建议
    public func getPermissionSuggestions() -> [String] {
        var suggestions: [String] = []
        
        let missingRequired = getMissingRequiredPermissions()
        let missingOptional = getMissingOptionalPermissions()
        
        if !missingRequired.isEmpty {
            suggestions.append("应用需要以下必需权限才能正常工作：\(missingRequired.map(\.rawValue).joined(separator: "、"))")
        }
        
        if !missingOptional.isEmpty {
            suggestions.append("建议授权以下权限以获得完整体验：\(missingOptional.map(\.rawValue).joined(separator: "、"))")
        }
        
        if missingRequired.isEmpty && missingOptional.isEmpty {
            suggestions.append("所有权限已正确配置，应用可以正常使用所有功能。")
        }
        
        return suggestions
    }
    
    /// 停止权限检查
    public func stopPeriodicCheck() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }
    
    /// 重启权限检查
    public func startPeriodicCheck() {
        stopPeriodicCheck()
        setupPeriodicCheck()
    }
}

// MARK: - 扩展：统计和调试
extension PermissionManager {
    
    /// 获取权限统计信息
    public func getPermissionStatistics() -> [String: Any] {
        let stats: [String: Any] = [
            "allPermissionsGranted": allPermissionsGranted,
            "corePermissionsGranted": corePermissionsGranted,
            "permissionStates": permissionStates.mapValues { state in
                [
                    "status": state.status.statusText,
                    "lastChecked": state.lastChecked,
                    "requestCount": state.requestCount
                ]
            },
            "requestHistory": permissionRequestHistory.mapValues { dates in
                dates.map { $0.timeIntervalSince1970 }
            },
            "shouldShowWindow": shouldShowPermissionWindow
        ]
        
        return stats
    }
    
    /// 调试信息
    public func debugPermissionState() {
        let missingRequired = getMissingRequiredPermissions()
        let missingOptional = getMissingOptionalPermissions()
        
        LogManager.shared.debug("PermissionManager", """
            权限状态调试信息：
            核心权限已授权: \(corePermissionsGranted)
            全部权限已授权: \(allPermissionsGranted)
            缺失必需权限: \(missingRequired.map(\.rawValue))
            缺失可选权限: \(missingOptional.map(\.rawValue))
            应显示权限窗口: \(shouldShowPermissionWindow)
            当前申请权限: \(currentPermissionRequest?.rawValue ?? "无")
            """)
    }
}