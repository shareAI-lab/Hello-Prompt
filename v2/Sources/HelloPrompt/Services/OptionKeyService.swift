import Foundation
import Carbon
import Combine

/// Option 键监听服务
/// 实现按住 Option 键录音，松开键停止录音的功能
@MainActor
final class OptionKeyService: ObservableObject {
    
    // MARK: - 发布属性
    @Published var isOptionKeyPressed = false
    @Published var isRecording = false
    
    // MARK: - 私有属性
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var keyPressStartTime: Date?
    private var minimumPressDuration: TimeInterval = 0.2 // 最小按压时间200ms
    
    // MARK: - 回调
    var onRecordingStart: (() -> Void)?
    var onRecordingStop: (() -> Void)?
    
    // MARK: - 初始化
    init() {
        LogManager.shared.info("OptionKeyService", "初始化 Option 键监听服务")
        setupOptionKeyMonitoring()
    }
    
    deinit {
        Task { @MainActor in
            stopMonitoring()
        }
    }
    
    // MARK: - 公共方法
    
    /// 开始监听 Option 键
    func startMonitoring() {
        LogManager.shared.info("OptionKeyService", "开始监听 Option 键")
        
        guard eventTap == nil else {
            LogManager.shared.warning("OptionKeyService", "Option 键监听已在运行")
            return
        }
        
        setupOptionKeyMonitoring()
    }
    
    /// 停止监听 Option 键
    func stopMonitoring() {
        LogManager.shared.info("OptionKeyService", "停止监听 Option 键")
        
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFRelease(eventTap)
            self.eventTap = nil
        }
        
        // 如果正在录音，停止录音
        if isRecording {
            handleOptionKeyUp()
        }
    }
    
    // MARK: - 私有方法
    
    private func setupOptionKeyMonitoring() {
        LogManager.shared.debug("OptionKeyService", "开始设置Option键监听，检查权限状态...")
        
        // 首先检查辅助功能权限
        guard hasAccessibilityPermission() else {
            LogManager.shared.error("OptionKeyService", "辅助功能权限未授权，无法创建事件监听")
            LogManager.shared.info("OptionKeyService", "请在系统偏好设置 > 安全性与隐私 > 辅助功能中添加此应用")
            
            // 尝试请求权限
            requestAccessibilityPermission()
            return
        }
        
        LogManager.shared.info("OptionKeyService", "辅助功能权限已授权，创建事件监听...")
        
        // 创建事件监听
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        
        LogManager.shared.debug("OptionKeyService", "事件监听掩码: \(eventMask)")
        
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let service = Unmanaged<OptionKeyService>.fromOpaque(refcon!).takeUnretainedValue()
                return service.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        
        guard let eventTap = eventTap else {
            LogManager.shared.error("OptionKeyService", "无法创建事件监听，可能原因：")
            LogManager.shared.error("OptionKeyService", "1. 辅助功能权限被系统拒绝")
            LogManager.shared.error("OptionKeyService", "2. 系统安全限制")
            LogManager.shared.error("OptionKeyService", "3. 其他应用占用了事件监听")
            LogManager.shared.error("OptionKeyService", "请重新启动应用或联系技术支持")
            return
        }
        
        LogManager.shared.info("OptionKeyService", "事件监听创建成功")
        
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        LogManager.shared.info("OptionKeyService", "Option 键监听设置完成")
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        
        // 检查是否是 Option 键相关事件
        if type == .flagsChanged {
            let flags = event.flags
            let optionPressed = flags.contains(.maskAlternate)
            
            Task { @MainActor in
                handleOptionKeyStateChange(pressed: optionPressed)
            }
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    private func handleOptionKeyStateChange(pressed: Bool) {
        let wasPressed = isOptionKeyPressed
        isOptionKeyPressed = pressed
        
        if pressed && !wasPressed {
            // Option 键按下
            handleOptionKeyDown()
        } else if !pressed && wasPressed {
            // Option 键松开
            handleOptionKeyUp()
        }
    }
    
    private func handleOptionKeyDown() {
        keyPressStartTime = Date()
        
        LogManager.shared.debug("OptionKeyService", "Option 键按下")
        
        // 延迟启动录音，防止意外触发
        Task {
            try? await Task.sleep(nanoseconds: UInt64(minimumPressDuration * 1_000_000_000))
            
            // 检查是否仍在按压状态
            if isOptionKeyPressed && !isRecording {
                LogManager.shared.info("OptionKeyService", "开始 Option 键录音")
                isRecording = true
                onRecordingStart?()
            }
        }
    }
    
    private func handleOptionKeyUp() {
        LogManager.shared.debug("OptionKeyService", "Option 键松开")
        
        // 检查按压时长
        if let startTime = keyPressStartTime {
            let pressDuration = Date().timeIntervalSince(startTime)
            
            if pressDuration < minimumPressDuration {
                LogManager.shared.debug("OptionKeyService", "按压时间过短 (\(pressDuration)s)，忽略录音")
                keyPressStartTime = nil
                return
            }
        }
        
        if isRecording {
            LogManager.shared.info("OptionKeyService", "停止 Option 键录音")
            isRecording = false
            onRecordingStop?()
        }
        
        keyPressStartTime = nil
    }
    
    // MARK: - 权限相关
    
    /// 检查是否有输入监控权限
    func hasAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    /// 请求输入监控权限
    func requestAccessibilityPermission() {
        LogManager.shared.info("OptionKeyService", "请求辅助功能权限")
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}

// MARK: - 日志扩展
extension OptionKeyService {
    
    func logCurrentState() {
        LogManager.shared.debug("OptionKeyService", """
            Option 键服务状态详情:
            - Option 键按压: \(isOptionKeyPressed)
            - 正在录音: \(isRecording)
            - 事件监听: \(eventTap != nil ? "已启用" : "未启用")
            - RunLoop源: \(runLoopSource != nil ? "已添加到RunLoop" : "未添加")
            - 辅助功能权限: \(hasAccessibilityPermission() ? "已授权" : "未授权")
            - 最小按压时长: \(minimumPressDuration)s
            - 按压开始时间: \(keyPressStartTime?.description ?? "无")
            """)
        
        // 如果权限被拒绝，提供更多帮助信息
        if !hasAccessibilityPermission() {
            LogManager.shared.warning("OptionKeyService", """
                辅助功能权限被拒绝，Option键功能将不可用。
                解决方案：
                1. 打开"系统偏好设置" > "安全性与隐私" > "隐私"
                2. 选择左侧的"辅助功能"
                3. 点击锁图标并输入密码
                4. 在右侧列表中找到并勾选"Hello Prompt v2"
                5. 重新启动应用
                """)
        }
    }
    
    /// 检查服务健康状态
    func checkServiceHealth() -> Bool {
        let hasPermission = hasAccessibilityPermission()
        let hasEventTap = eventTap != nil
        let hasRunLoopSource = runLoopSource != nil
        
        LogManager.shared.debug("OptionKeyService", """
            服务健康检查:
            - 权限状态: \(hasPermission ? "✅" : "❌")
            - 事件监听: \(hasEventTap ? "✅" : "❌")
            - RunLoop源: \(hasRunLoopSource ? "✅" : "❌")
            - 整体状态: \(hasPermission && hasEventTap && hasRunLoopSource ? "健康" : "异常")
            """)
        
        return hasPermission && hasEventTap && hasRunLoopSource
    }
    
    /// 尝试恢复服务
    func attemptServiceRecovery() {
        LogManager.shared.info("OptionKeyService", "尝试恢复Option键监听服务...")
        
        // 停止当前监听
        stopMonitoring()
        
        // 等待短暂时间
        Thread.sleep(forTimeInterval: 0.5)
        
        // 重新启动监听
        startMonitoring()
        
        // 检查恢复结果
        if checkServiceHealth() {
            LogManager.shared.info("OptionKeyService", "✅ 服务恢复成功")
        } else {
            LogManager.shared.error("OptionKeyService", "❌ 服务恢复失败，请检查权限设置")
        }
    }
}