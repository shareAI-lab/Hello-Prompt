//
//  FloatingBall.swift
//  HelloPrompt
//
//  录音悬浮球UI - 实现脉动动画、状态指示、毛玻璃效果
//  Copyright © 2025 HelloPrompt. All rights reserved.
//

import Foundation
import AppKit
import QuartzCore

// MARK: - 悬浮球状态
enum FloatingBallState {
    case hidden       // 隐藏
    case idle         // 空闲等待
    case listening    // 监听中
    case recording    // 录音中
    case processing   // 处理中
    case success      // 成功
    case error        // 错误
}

// MARK: - 悬浮球配置
struct FloatingBallConfig {
    let size: CGFloat = 80.0
    let position: FloatingBallPosition = .centerBottom
    let animationDuration: TimeInterval = 0.3
    let pulseAnimationDuration: TimeInterval = 1.2
    let fadeAnimationDuration: TimeInterval = 0.2
    let maxLevel: Float = 1.0
    let visualEffectStyle: NSVisualEffectView.Material = .hudWindow
}

// MARK: - 悬浮球位置
enum FloatingBallPosition {
    case center
    case centerBottom
    case topRight
    case bottomRight
    case custom(x: CGFloat, y: CGFloat)
    
    func calculatePosition(for screenSize: CGSize, ballSize: CGFloat) -> CGPoint {
        switch self {
        case .center:
            return CGPoint(x: screenSize.width / 2, y: screenSize.height / 2)
        case .centerBottom:
            return CGPoint(x: screenSize.width / 2, y: 150)
        case .topRight:
            return CGPoint(x: screenSize.width - ballSize - 20, y: screenSize.height - ballSize - 20)
        case .bottomRight:
            return CGPoint(x: screenSize.width - ballSize - 20, y: ballSize + 20)
        case .custom(let x, let y):
            return CGPoint(x: x, y: y)
        }
    }
}

// MARK: - 悬浮球代理协议
@MainActor
protocol FloatingBallDelegate: AnyObject {
    func floatingBallDidClick(_ floatingBall: FloatingBall)
    func floatingBallDidDoubleClick(_ floatingBall: FloatingBall)
    func floatingBallDidRightClick(_ floatingBall: FloatingBall)
    func floatingBallDidDragToPosition(_ floatingBall: FloatingBall, position: CGPoint)
}

// MARK: - 录音悬浮球主类
@MainActor
class FloatingBall: NSObject {
    
    // MARK: - Properties
    weak var delegate: FloatingBallDelegate?
    
    private let config: FloatingBallConfig
    private var window: NSWindow?
    private var containerView: NSView?
    private var visualEffectView: NSVisualEffectView?
    private var iconView: NSImageView?
    private var levelIndicatorView: NSView?
    private var pulseLayer: CAShapeLayer?
    
    private var currentState: FloatingBallState = .hidden {
        didSet {
            updateAppearanceForState()
        }
    }
    
    private var currentLevel: Float = 0.0
    private var isVisible = false
    private var isDragging = false
    
    // MARK: - Initialization
    init(config: FloatingBallConfig = FloatingBallConfig()) {
        self.config = config
        super.init()
        
        LogManager.shared.uiLog("FloatingBall基础初始化", details: [
            "size": config.size,
            "position": "\(config.position)",
            "material": "\(config.visualEffectStyle)"
        ])
        
        // 延迟设置窗口和视图，避免阻塞初始化
        Task { @MainActor in
            await setupWindowAsync()
        }
    }
    
    deinit {
        // 在Swift 6.0中，@MainActor类的deinit不能直接调用其他@MainActor方法
        // 使用nonisolated方法处理清理
        cleanupSync()
    }
    
    // MARK: - Public Methods
    
    /// 显示悬浮球
    func show(at position: FloatingBallPosition? = nil) {
        guard !isVisible else { return }
        
        let targetPosition = position ?? config.position
        updatePosition(targetPosition)
        
        window?.setIsVisible(true)
        isVisible = true
        currentState = .idle
        
        // 显示动画
        animateShow()
        
        LogManager.shared.uiLog("显示悬浮球", details: [
            "position": "\(targetPosition)",
            "size": config.size
        ])
    }
    
    /// 隐藏悬浮球
    func hide() {
        guard isVisible else { return }
        
        // 隐藏动画
        animateHide { [weak self] in
            self?.window?.setIsVisible(false)
            self?.isVisible = false
            self?.currentState = .hidden
        }
        
        LogManager.shared.uiLog("隐藏悬浮球")
    }
    
    /// 更新状态
    func updateState(_ state: FloatingBallState) {
        guard currentState != state else { return }
        
        LogManager.shared.uiLog("悬浮球状态变更", details: [
            "from": "\(currentState)",
            "to": "\(state)"
        ])
        
        currentState = state
        
        // 添加简单的状态日志
        DispatchQueue.main.async { [weak self] in
            self?.updateStateAppearance(state)
        }
    }
    
    /// 更新状态外观
    private func updateStateAppearance(_ state: FloatingBallState) {
        guard let window = window else { return }
        
        switch state {
        case .hidden:
            window.orderOut(nil)
            
        case .idle:
            window.orderFront(nil)
            LogManager.shared.uiLog("悬浮球状态: 空闲等待")
            
        case .listening:
            LogManager.shared.uiLog("悬浮球状态: 准备录音")
            
        case .recording:
            LogManager.shared.uiLog("悬浮球状态: 正在录音")
            
        case .processing:
            LogManager.shared.uiLog("悬浮球状态: 处理中")
            
        case .success:
            LogManager.shared.uiLog("悬浮球状态: 完成")
            
        case .error:
            LogManager.shared.uiLog("悬浮球状态: 错误")
        }
    }
    
    /// 更新音频级别
    func updateLevel(_ level: Float) {
        let normalizedLevel = min(max(level, 0.0), config.maxLevel)
        currentLevel = normalizedLevel
        
        // 更新级别指示器
        updateLevelIndicator(normalizedLevel)
        
        // 根据音频级别调整脉动强度
        if currentState == .recording {
            updatePulseIntensity(normalizedLevel)
        }
    }
    
    /// 移动到指定位置
    func moveTo(position: FloatingBallPosition) {
        updatePosition(position)
        
        LogManager.shared.uiLog("移动悬浮球", details: [
            "newPosition": "\(position)"
        ])
    }
    
    // MARK: - Private Methods
    
    /// 异步设置窗口和视图
    private func setupWindowAsync() async {
        LogManager.shared.uiLog("🪟 悬浮球: 开始异步设置窗口")
        
        await Task.yield() // 让出控制权
        
        setupWindow()
        setupViews()
        setupAnimations()
        
        LogManager.shared.uiLog("✅ 悬浮球: 异步窗口设置完成")
    }
    
    /// 设置窗口
    private func setupWindow() {
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
        let initialPosition = config.position.calculatePosition(for: screenSize, ballSize: config.size)
        
        let windowRect = NSRect(
            x: initialPosition.x - config.size / 2,
            y: initialPosition.y - config.size / 2,
            width: config.size,
            height: config.size
        )
        
        window = NSWindow(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window?.level = .floating
        window?.isOpaque = false
        window?.backgroundColor = .clear
        window?.hasShadow = true
        window?.ignoresMouseEvents = false
        window?.collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        LogManager.shared.uiLog("悬浮球窗口创建", details: [
            "frame": "\(windowRect)",
            "level": "floating"
        ])
    }
    
    /// 设置视图
    private func setupViews() {
        guard let window = window else { return }
        
        // 容器视图
        containerView = NSView(frame: window.contentView?.bounds ?? .zero)
        containerView?.wantsLayer = true
        window.contentView = containerView
        
        // 毛玻璃效果视图
        visualEffectView = NSVisualEffectView(frame: containerView?.bounds ?? .zero)
        visualEffectView?.material = config.visualEffectStyle
        visualEffectView?.blendingMode = .behindWindow
        visualEffectView?.state = .active
        visualEffectView?.wantsLayer = true
        visualEffectView?.layer?.cornerRadius = config.size / 2
        visualEffectView?.layer?.masksToBounds = true
        
        if let visualEffectView = visualEffectView {
            containerView?.addSubview(visualEffectView)
        }
        
        // 图标视图
        let iconSize: CGFloat = config.size * 0.4
        let iconFrame = NSRect(
            x: (config.size - iconSize) / 2,
            y: (config.size - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )
        
        iconView = NSImageView(frame: iconFrame)
        iconView?.imageScaling = .scaleProportionallyUpOrDown
        iconView?.image = createMicrophoneIcon()
        
        if let iconView = iconView {
            containerView?.addSubview(iconView)
        }
        
        // 级别指示器视图
        levelIndicatorView = NSView(frame: containerView?.bounds ?? .zero)
        levelIndicatorView?.wantsLayer = true
        levelIndicatorView?.layer?.cornerRadius = config.size / 2
        levelIndicatorView?.layer?.masksToBounds = true
        levelIndicatorView?.isHidden = true
        
        if let levelIndicatorView = levelIndicatorView {
            containerView?.addSubview(levelIndicatorView)
        }
        
        // 添加手势识别
        setupGestureRecognizers()
        
        LogManager.shared.uiLog("悬浮球视图设置完成", details: [
            "containerSize": "\(containerView?.bounds.size ?? .zero)",
            "iconSize": "\(iconSize)",
            "material": "\(config.visualEffectStyle)"
        ])
    }
    
    /// 设置动画
    private func setupAnimations() {
        guard let containerView = containerView else { return }
        
        // 脉动动画层
        pulseLayer = CAShapeLayer()
        let pulsePath = NSBezierPath(ovalIn: containerView.bounds)
        
        // 统一使用手动转换方法以确保兼容性
        pulseLayer?.path = convertBezierPathToCGPath(pulsePath)
        
        pulseLayer?.fillColor = NSColor.systemBlue.withAlphaComponent(0.3).cgColor
        pulseLayer?.opacity = 0.0
        
        if let pulseLayer = pulseLayer {
            containerView.layer?.insertSublayer(pulseLayer, at: 0)
        }
        
        LogManager.shared.uiLog("悬浮球动画设置完成")
    }
    
    /// 设置手势识别
    private func setupGestureRecognizers() {
        guard let containerView = containerView else { return }
        
        // 点击手势
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        clickGesture.numberOfClicksRequired = 1
        containerView.addGestureRecognizer(clickGesture)
        
        // 双击手势
        let doubleClickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleDoubleClick(_:)))
        doubleClickGesture.numberOfClicksRequired = 2
        containerView.addGestureRecognizer(doubleClickGesture)
        
        // 右键手势
        let rightClickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleRightClick(_:)))
        rightClickGesture.buttonMask = 0x2 // 右键
        containerView.addGestureRecognizer(rightClickGesture)
        
        // 拖拽手势
        let panGesture = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        containerView.addGestureRecognizer(panGesture)
        
        // 注意：在macOS上，手势识别器的优先级处理与iOS不同
        // 这里我们不需要显式设置失败依赖
    }
    
    /// 更新位置
    private func updatePosition(_ position: FloatingBallPosition) {
        guard let window = window else { return }
        
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
        let newPosition = position.calculatePosition(for: screenSize, ballSize: config.size)
        
        let newRect = NSRect(
            x: newPosition.x - config.size / 2,
            y: newPosition.y - config.size / 2,
            width: config.size,
            height: config.size
        )
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = config.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newRect, display: true)
        }
    }
    
    /// 根据状态更新外观
    private func updateAppearanceForState() {
        switch currentState {
        case .hidden:
            break
        case .idle:
            updateForIdleState()
        case .listening:
            updateForListeningState()
        case .recording:
            updateForRecordingState()
        case .processing:
            updateForProcessingState()
        case .success:
            updateForSuccessState()
        case .error:
            updateForErrorState()
        }
    }
    
    private func updateForIdleState() {
        stopPulseAnimation()
        levelIndicatorView?.isHidden = true
        iconView?.image = createMicrophoneIcon()
        visualEffectView?.layer?.borderWidth = 0
    }
    
    private func updateForListeningState() {
        startPulseAnimation()
        levelIndicatorView?.isHidden = true
        iconView?.image = createMicrophoneIcon()
        visualEffectView?.layer?.borderColor = NSColor.systemBlue.cgColor
        visualEffectView?.layer?.borderWidth = 2
    }
    
    private func updateForRecordingState() {
        startPulseAnimation()
        levelIndicatorView?.isHidden = false
        iconView?.image = createRecordingIcon()
        visualEffectView?.layer?.borderColor = NSColor.systemRed.cgColor
        visualEffectView?.layer?.borderWidth = 2
    }
    
    private func updateForProcessingState() {
        startSpinAnimation()
        levelIndicatorView?.isHidden = true
        iconView?.image = createProcessingIcon()
        visualEffectView?.layer?.borderColor = NSColor.systemYellow.cgColor
        visualEffectView?.layer?.borderWidth = 2
    }
    
    private func updateForSuccessState() {
        stopAllAnimations()
        levelIndicatorView?.isHidden = true
        iconView?.image = createSuccessIcon()
        visualEffectView?.layer?.borderColor = NSColor.systemGreen.cgColor
        visualEffectView?.layer?.borderWidth = 2
        
        // 短暂显示成功状态后回到空闲
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.currentState = .idle
        }
    }
    
    private func updateForErrorState() {
        stopAllAnimations()
        levelIndicatorView?.isHidden = true
        iconView?.image = createErrorIcon()
        visualEffectView?.layer?.borderColor = NSColor.systemRed.cgColor
        visualEffectView?.layer?.borderWidth = 2
        
        // 短暂显示错误状态后回到空闲
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.currentState = .idle
        }
    }
    
    /// 更新级别指示器
    private func updateLevelIndicator(_ level: Float) {
        guard let levelIndicatorView = levelIndicatorView else { return }
        
        let alpha = CGFloat(level) * 0.5
        let color = NSColor.systemBlue.withAlphaComponent(alpha)
        
        levelIndicatorView.layer?.backgroundColor = color.cgColor
    }
    
    /// 更新脉动强度
    private func updatePulseIntensity(_ level: Float) {
        guard let pulseLayer = pulseLayer else { return }
        
        let intensity = 0.3 + CGFloat(level) * 0.7
        pulseLayer.opacity = Float(intensity)
    }
    
    // MARK: - Animations
    
    private func animateShow() {
        containerView?.layer?.transform = CATransform3DMakeScale(0.1, 0.1, 1.0)
        containerView?.alphaValue = 0.0
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = config.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            containerView?.animator().layer?.transform = CATransform3DIdentity
            containerView?.animator().alphaValue = 1.0
        }
    }
    
    private func animateHide(completion: @escaping () -> Void) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = config.fadeAnimationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            containerView?.animator().alphaValue = 0.0
            containerView?.animator().layer?.transform = CATransform3DMakeScale(0.1, 0.1, 1.0)
        }, completionHandler: completion)
    }
    
    private func startPulseAnimation() {
        guard let pulseLayer = pulseLayer else { return }
        
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 1.2
        pulseAnimation.duration = config.pulseAnimationDuration
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        pulseLayer.add(pulseAnimation, forKey: "pulse")
        
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 0.0
        opacityAnimation.toValue = 0.6
        opacityAnimation.duration = config.pulseAnimationDuration
        opacityAnimation.autoreverses = true
        opacityAnimation.repeatCount = .infinity
        
        pulseLayer.add(opacityAnimation, forKey: "opacity")
    }
    
    private func stopPulseAnimation() {
        pulseLayer?.removeAnimation(forKey: "pulse")
        pulseLayer?.removeAnimation(forKey: "opacity")
        pulseLayer?.opacity = 0.0
    }
    
    private func startSpinAnimation() {
        guard let iconView = iconView else { return }
        
        let spinAnimation = CABasicAnimation(keyPath: "transform.rotation")
        spinAnimation.fromValue = 0
        spinAnimation.toValue = Double.pi * 2
        spinAnimation.duration = 1.0
        spinAnimation.repeatCount = .infinity
        spinAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
        
        iconView.layer?.add(spinAnimation, forKey: "spin")
    }
    
    private func stopAllAnimations() {
        stopPulseAnimation()
        iconView?.layer?.removeAllAnimations()
    }
    
    // MARK: - Icon Creation
    
    private func createMicrophoneIcon() -> NSImage {
        return NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "麦克风")
            ?? NSImage(named: "mic.fill")
            ?? createDefaultMicIcon()
    }
    
    private func createRecordingIcon() -> NSImage {
        return NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "录音")
            ?? NSImage(named: "record.circle.fill")
            ?? createDefaultRecordIcon()
    }
    
    private func createProcessingIcon() -> NSImage {
        return NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: "处理中")
            ?? NSImage(named: "gearshape.fill")
            ?? createDefaultProcessingIcon()
    }
    
    private func createSuccessIcon() -> NSImage {
        return NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "成功")
            ?? NSImage(named: "checkmark.circle.fill")
            ?? createDefaultSuccessIcon()
    }
    
    private func createErrorIcon() -> NSImage {
        return NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "错误")
            ?? NSImage(named: "xmark.circle.fill")
            ?? createDefaultErrorIcon()
    }
    
    private func createDefaultMicIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 32, height: 32))
        image.lockFocus()
        defer { image.unlockFocus() }
        NSColor.white.setFill()
        let path = NSBezierPath(ovalIn: NSRect(x: 8, y: 8, width: 16, height: 16))
        path.fill()
        return image
    }
    
    private func createDefaultRecordIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 32, height: 32))
        image.lockFocus()
        defer { image.unlockFocus() }
        NSColor.systemRed.setFill()
        let path = NSBezierPath(ovalIn: NSRect(x: 8, y: 8, width: 16, height: 16))
        path.fill()
        return image
    }
    
    private func createDefaultProcessingIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 32, height: 32))
        image.lockFocus()
        defer { image.unlockFocus() }
        NSColor.systemYellow.setFill()
        let path = NSBezierPath(ovalIn: NSRect(x: 8, y: 8, width: 16, height: 16))
        path.fill()
        return image
    }
    
    private func createDefaultSuccessIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 32, height: 32))
        image.lockFocus()
        defer { image.unlockFocus() }
        NSColor.systemGreen.setFill()
        let path = NSBezierPath(ovalIn: NSRect(x: 8, y: 8, width: 16, height: 16))
        path.fill()
        return image
    }
    
    private func createDefaultErrorIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 32, height: 32))
        image.lockFocus()
        defer { image.unlockFocus() }
        NSColor.systemRed.setFill()
        let path = NSBezierPath(ovalIn: NSRect(x: 8, y: 8, width: 16, height: 16))
        path.fill()
        return image
    }
    
    // MARK: - Gesture Handlers
    
    @objc private func handleClick(_ gesture: NSClickGestureRecognizer) {
        LogManager.shared.uiLog("悬浮球点击")
        delegate?.floatingBallDidClick(self)
    }
    
    @objc private func handleDoubleClick(_ gesture: NSClickGestureRecognizer) {
        LogManager.shared.uiLog("悬浮球双击")
        delegate?.floatingBallDidDoubleClick(self)
    }
    
    @objc private func handleRightClick(_ gesture: NSClickGestureRecognizer) {
        LogManager.shared.uiLog("悬浮球右键点击")
        delegate?.floatingBallDidRightClick(self)
    }
    
    @objc private func handlePan(_ gesture: NSPanGestureRecognizer) {
        guard let window = window else { return }
        
        switch gesture.state {
        case .began:
            isDragging = true
            LogManager.shared.uiLog("开始拖拽悬浮球")
            
        case .changed:
            let translation = gesture.translation(in: containerView)
            let currentFrame = window.frame
            let newOrigin = CGPoint(
                x: currentFrame.origin.x + translation.x,
                y: currentFrame.origin.y - translation.y // AppKit坐标系Y轴相反
            )
            window.setFrameOrigin(newOrigin)
            gesture.setTranslation(.zero, in: containerView)
            
        case .ended, .cancelled:
            isDragging = false
            let finalPosition = CGPoint(
                x: window.frame.midX,
                y: window.frame.midY
            )
            delegate?.floatingBallDidDragToPosition(self, position: finalPosition)
            LogManager.shared.uiLog("结束拖拽悬浮球", details: [
                "finalPosition": "\(finalPosition)"
            ])
            
        default:
            break
        }
    }
    
    // MARK: - Cleanup
    
    private func cleanup() {
        stopAllAnimations()
        window?.close()
        window = nil
        
        LogManager.shared.uiLog("FloatingBall资源清理完成")
    }
    
    /// 同步清理方法，用于deinit
    nonisolated private func cleanupSync() {
        Task { @MainActor in
            stopAllAnimations()
            window?.close()
            window = nil
            
            LogManager.shared.uiLog("FloatingBall资源清理完成（同步）")
        }
    }
    
    /// 将NSBezierPath转换为CGPath（兼容旧版macOS）
    private func convertBezierPathToCGPath(_ bezierPath: NSBezierPath) -> CGPath {
        let path = CGMutablePath()
        let points = NSPointArray.allocate(capacity: 3)
        defer { points.deallocate() }
        
        for i in 0..<bezierPath.elementCount {
            let element = bezierPath.element(at: i, associatedPoints: points)
            
            switch element {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }
        
        return path
    }
}