//
//  EnhancedPermissionManager.swift
//  HelloPrompt
//
//  现代化权限管理系统 - 使用最新API和增强日志追踪
//  提供完整的权限生命周期管理和透明的状态追踪
//

import Foundation
import SwiftUI
import AVFoundation
import ApplicationServices
import Combine
import AppKit
import UserNotifications

// MARK: - 增强的权限管理器
@MainActor
public class EnhancedPermissionManager: ObservableObject {
    
    public static let shared = EnhancedPermissionManager()
    
    // MARK: - Published Properties
    @Published public var permissionStates: [PermissionType: PermissionState] = [:]
    @Published public var isCheckingPermissions = false
    @Published public var lastPermissionCheck: Date = Date.distantPast
    
    // MARK: - Permission Change Callbacks
    public var onPermissionChanged: ((PermissionChangeEvent) -> Void)?
    public var onAllPermissionsReady: (() -> Void)?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var permissionCheckTimer: Timer?
    private var currentPermissionRequest: PermissionType?
    
    private init() {
        LogManager.shared.info("EnhancedPermissionManager", "🚀 初始化增强权限管理系统")
        setupInitialStates()
        setupApplicationStateObserver()
        setupPeriodicCheck()
    }
    
    deinit {
        permissionCheckTimer?.invalidate()
        LogManager.shared.info("EnhancedPermissionManager", "♻️  权限管理系统已清理")
    }
    
    // MARK: - 初始化设置
    private func setupInitialStates() {
        for type in PermissionType.allCases {
            permissionStates[type] = PermissionState(
                type: type,
                status: .notDetermined,
                lastChecked: Date.distantPast,
                requestCount: 0
            )
        }
        LogManager.shared.debug("EnhancedPermissionManager", "📋 初始化了 \(PermissionType.allCases.count) 个权限状态")
    }
    
    // MARK: - 现代化权限请求方法
    
    /// 请求指定类型的权限（使用最新API）
    @discardableResult
    public func requestPermission(_ type: PermissionType) async -> PermissionStatus {
        LogManager.shared.info("EnhancedPermissionManager", "🎯 开始请求\(type.displayName)权限")
        
        let startTime = Date()
        currentPermissionRequest = type
        
        // 增加请求计数
        if var state = permissionStates[type] {
            state.requestCount += 1
            permissionStates[type] = state
        }
        
        let result: PermissionStatus
        
        switch type {
        case .microphone:
            result = await requestMicrophonePermissionModern()
        case .accessibility:
            result = await requestAccessibilityPermissionModern()
        case .notification:
            result = await requestNotificationPermissionModern()
        }
        
        let duration = Date().timeIntervalSince(startTime)
        LogManager.shared.info("EnhancedPermissionManager", "✅ \(type.displayName)权限请求完成: \(result.statusText) (耗时: \(String(format: "%.2f", duration))s)")
        
        currentPermissionRequest = nil
        await logDetailedPermissionState(type, result)
        
        return result
    }
    
    /// 现代化麦克风权限请求
    private func requestMicrophonePermissionModern() async -> PermissionStatus {
        let currentStatus = await checkMicrophonePermissionAsync()
        
        LogManager.shared.debug("EnhancedPermissionManager", "🎤 当前麦克风权限状态: \(currentStatus.statusText)")
        
        if currentStatus == .notDetermined {
            LogManager.shared.info("EnhancedPermissionManager", "🎤 使用AVAudioSession现代API请求麦克风权限...")
            
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                    let status: PermissionStatus = granted ? .granted : .denied
                    
                    LogManager.shared.info("EnhancedPermissionManager", "🎤 麦克风权限请求结果: \(granted ? "✅ 已授权" : "❌ 被拒绝")")
                    
                    Task { @MainActor in
                        await self?.updatePermissionState(.microphone, newStatus: status)
                    }
                    
                    continuation.resume(returning: status)
                }
            }
        }
        
        return currentStatus
    }
    
    /// 现代化辅助功能权限请求
    private func requestAccessibilityPermissionModern() async -> PermissionStatus {
        let currentStatus = checkAccessibilityPermissionRealTime()
        
        LogManager.shared.debug("EnhancedPermissionManager", "🔐 当前辅助功能权限状态: \(currentStatus ? "已授权" : "未授权")")
        
        if !currentStatus {
            LogManager.shared.info("EnhancedPermissionManager", "🔐 使用最新Accessibility API请求权限...")
            
            // 使用最新的带提示的权限请求API
            let options: [String: Any] = [
                kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
            ]
            
            let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
            let newStatus: PermissionStatus = isTrusted ? .granted : .denied
            
            LogManager.shared.info("EnhancedPermissionManager", "🔐 辅助功能权限检查结果: \(isTrusted ? "✅ 已授权" : "⚠️  需要用户手动授权")")
            
            await updatePermissionState(.accessibility, newStatus: newStatus)
            
            // 如果仍未授权，显示详细指导
            if newStatus != .granted {
                await showModernAccessibilityGuide()
            }
            
            return newStatus
        }
        
        await updatePermissionState(.accessibility, newStatus: .granted)
        return .granted
    }
    
    /// 现代化通知权限请求
    private func requestNotificationPermissionModern() async -> PermissionStatus {
        guard let center = getNotificationCenterSafely() else {
            LogManager.shared.warning("EnhancedPermissionManager", "⚠️  无法获取通知中心，跳过通知权限请求")
            return .unknown
        }
        
        LogManager.shared.info("EnhancedPermissionManager", "🔔 使用UNUserNotificationCenter现代API请求通知权限...")
        
        return await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
                let status: PermissionStatus
                
                if let error = error {
                    LogManager.shared.error("EnhancedPermissionManager", "🔔 通知权限请求失败: \(error.localizedDescription)")
                    status = .denied
                } else {
                    status = granted ? .granted : .denied
                    LogManager.shared.info("EnhancedPermissionManager", "🔔 通知权限请求结果: \(granted ? "✅ 已授权" : "❌ 被拒绝")")
                }
                
                Task { @MainActor in
                    await self?.updatePermissionState(.notification, newStatus: status)
                }
                
                continuation.resume(returning: status)
            }
        }
    }
    
    // MARK: - 权限状态检查方法
    
    /// 实时检查辅助功能权限（绕过缓存）
    public func checkAccessibilityPermissionRealTime() -> Bool {
        let result = AXIsProcessTrusted()
        LogManager.shared.debug("EnhancedPermissionManager", "🔍 实时辅助功能权限检查: \(result ? "✅" : "❌")")
        return result
    }
    
    /// 异步检查麦克风权限
    public func checkMicrophonePermissionAsync() async -> PermissionStatus {
        let authStatus = AVAudioSession.sharedInstance().recordPermission
        let status: PermissionStatus
        
        switch authStatus {
        case .granted:
            status = .granted
        case .denied:
            status = .denied
        case .undetermined:
            status = .notDetermined
        @unknown default:
            status = .unknown
        }
        
        LogManager.shared.debug("EnhancedPermissionManager", "🎤 异步麦克风权限检查: \(status.statusText)")
        return status
    }
    
    /// 检查所有权限状态（增强版）
    public func checkAllPermissionsEnhanced(reason: String = "手动检查") async {
        guard !isCheckingPermissions else { 
            LogManager.shared.debug("EnhancedPermissionManager", "⏳ 权限检查已在进行中，跳过重复检查")
            return
        }
        
        isCheckingPermissions = true
        lastPermissionCheck = Date()
        
        LogManager.shared.info("EnhancedPermissionManager", "🔍 开始增强权限检查，原因：\(reason)")
        
        defer {
            isCheckingPermissions = false
            LogManager.shared.info("EnhancedPermissionManager", "✅ 权限检查完成")
        }
        
        var allPermissionsReady = true
        
        for type in PermissionType.allCases {
            let currentStatus = await getCurrentPermissionStatus(type)
            await updatePermissionState(type, newStatus: currentStatus)
            
            // 检查必需权限是否都已获得
            if type.isRequired && currentStatus != .granted {
                allPermissionsReady = false
            }
            
            LogManager.shared.debug("EnhancedPermissionManager", "📊 \(type.displayName): \(currentStatus.statusText)")
        }
        
        // 触发全部权限就绪回调
        if allPermissionsReady, let callback = onAllPermissionsReady {
            LogManager.shared.info("EnhancedPermissionManager", "🎉 所有必需权限已就绪")
            callback()
        }
    }
    
    // MARK: - 私有辅助方法
    
    private func getCurrentPermissionStatus(_ type: PermissionType) async -> PermissionStatus {
        switch type {
        case .microphone:
            return await checkMicrophonePermissionAsync()
        case .accessibility:
            return checkAccessibilityPermissionRealTime() ? .granted : .notDetermined
        case .notification:
            return await getNotificationPermissionStatusAsync()
        }
    }
    
    private func updatePermissionState(_ type: PermissionType, newStatus: PermissionStatus) async {
        let oldStatus = permissionStates[type]?.status ?? .notDetermined
        
        permissionStates[type] = PermissionState(
            type: type,
            status: newStatus,
            lastChecked: Date(),
            requestCount: permissionStates[type]?.requestCount ?? 0
        )
        
        // 触发权限变化事件
        if oldStatus != newStatus, let callback = onPermissionChanged {
            let event = PermissionChangeEvent(
                type: type,
                oldStatus: oldStatus,
                newStatus: newStatus,
                timestamp: Date()
            )
            
            LogManager.shared.info("EnhancedPermissionManager", "🔄 权限状态变化: \(type.displayName) \(oldStatus.statusText) → \(newStatus.statusText)")
            callback(event)
        }
    }
    
    private func getNotificationPermissionStatusAsync() async -> PermissionStatus {
        guard let center = getNotificationCenterSafely() else {
            return .unknown
        }
        
        return await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                let status: PermissionStatus
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    status = .granted
                case .denied:
                    status = .denied
                case .notDetermined:
                    status = .notDetermined
                @unknown default:
                    status = .unknown
                }
                continuation.resume(returning: status)
            }
        }
    }
    
    private func getNotificationCenterSafely() -> UNUserNotificationCenter? {
        guard Bundle.main.bundleIdentifier != nil else {
            return nil
        }
        return UNUserNotificationCenter.current()
    }
    
    private func showModernAccessibilityGuide() async {
        LogManager.shared.info("EnhancedPermissionManager", "📖 显示现代化辅助功能权限指导")
        
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = """
        Hello Prompt 需要辅助功能权限来监听全局快捷键（Ctrl+U）。
        
        请按照以下步骤授权：
        1. 打开"系统偏好设置"
        2. 选择"安全性与隐私"
        3. 点击"隐私"标签
        4. 选择"辅助功能"
        5. 点击锁图标并输入密码
        6. 勾选"Hello Prompt v2"
        """
        alert.addButton(withTitle: "打开系统偏好设置")
        alert.addButton(withTitle: "稍后设置")
        alert.alertStyle = .informational
        
        let response = await alert.beginSheetModal(for: NSApp.keyWindow ?? NSApp.mainWindow ?? NSWindow())
        
        if response == .alertFirstButtonReturn {
            // 打开系统偏好设置的辅助功能页面
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
            LogManager.shared.info("EnhancedPermissionManager", "🔧 已打开系统偏好设置")
        }
    }
    
    private func logDetailedPermissionState(_ type: PermissionType, _ status: PermissionStatus) async {
        let state = permissionStates[type]
        LogManager.shared.info("EnhancedPermissionManager", """
        📋 权限详细状态报告:
        类型: \(type.displayName)
        状态: \(status.statusText)
        请求次数: \(state?.requestCount ?? 0)
        上次检查: \(state?.lastChecked.description ?? "从未")
        是否必需: \(type.isRequired ? "是" : "否")
        优先级: \(type.priority)
        """)
    }
    
    // MARK: - 应用状态监听
    private func setupApplicationStateObserver() {
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.checkAllPermissionsEnhanced(reason: "应用激活")
                }
            }
            .store(in: &cancellables)
        
        LogManager.shared.debug("EnhancedPermissionManager", "👁️  应用状态监听器已设置")
    }
    
    // MARK: - 定期权限检查
    private func setupPeriodicCheck() {
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkAllPermissionsEnhanced(reason: "定期检查")
            }
        }
        LogManager.shared.debug("EnhancedPermissionManager", "⏰ 定期权限检查器已启动 (30秒间隔)")
    }
}

// MARK: - 扩展功能
extension EnhancedPermissionManager {
    
    /// 强制刷新所有权限状态
    public func forceRefreshAllPermissions() async {
        LogManager.shared.info("EnhancedPermissionManager", "🔄 强制刷新所有权限状态")
        await checkAllPermissionsEnhanced(reason: "强制刷新")
    }
    
    /// 获取权限摘要报告
    public func getPermissionSummary() -> String {
        let summary = permissionStates.map { type, state in
            "\(type.displayName): \(state.status.statusText)"
        }.joined(separator: ", ")
        
        LogManager.shared.debug("EnhancedPermissionManager", "📊 权限摘要: \(summary)")
        return summary
    }
    
    /// 检查是否所有必需权限都已获得
    public var allRequiredPermissionsGranted: Bool {
        let result = PermissionType.allCases
            .filter { $0.isRequired }
            .allSatisfy { permissionStates[$0]?.status.isGranted ?? false }
        
        LogManager.shared.debug("EnhancedPermissionManager", "✅ 所有必需权限已获得: \(result ? "是" : "否")")
        return result
    }
}