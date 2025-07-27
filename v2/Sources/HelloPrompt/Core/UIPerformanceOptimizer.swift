//
//  UIPerformanceOptimizer.swift
//  HelloPrompt
//
//  UI性能优化器 - 防止主线程阻塞，优化动画和布局性能
//  提供防抖、节流、批量更新等机制
//

import Foundation
import SwiftUI
import Combine

// MARK: - UI更新节流器
@MainActor
public final class UIUpdateThrottler: ObservableObject {
    
    // MARK: - 发布属性
    @Published public var audioLevel: Float = 0.0
    @Published public var waveformData: [Float] = Array(repeating: 0.0, count: 8)
    @Published public var currentState: OrbState = .idle
    @Published public var isVisible: Bool = false
    
    // MARK: - 私有属性
    private var audioLevelSubject = PassthroughSubject<Float, Never>()
    private var waveformSubject = PassthroughSubject<[Float], Never>()
    private var stateSubject = PassthroughSubject<OrbState, Never>()
    private var visibilitySubject = PassthroughSubject<Bool, Never>()
    
    private var cancellables = Set<AnyCancellable>()
    
    // 节流配置
    private let audioUpdateInterval: TimeInterval = 1.0 / 30.0  // 30 FPS
    private let waveformUpdateInterval: TimeInterval = 1.0 / 20.0  // 20 FPS
    private let stateUpdateInterval: TimeInterval = 1.0 / 10.0  // 10 FPS
    
    // MARK: - 初始化
    public init() {
        setupThrottling()
        LogManager.shared.info("UIUpdateThrottler", "UI更新节流器初始化完成")
    }
    
    // MARK: - 私有方法
    private func setupThrottling() {
        // 音频级别节流更新
        audioLevelSubject
            .throttle(for: .seconds(audioUpdateInterval), scheduler: DispatchQueue.main, latest: true)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.audioLevel = level
            }
            .store(in: &cancellables)
        
        // 波形数据节流更新
        waveformSubject
            .throttle(for: .seconds(waveformUpdateInterval), scheduler: DispatchQueue.main, latest: true)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data in
                self?.waveformData = data
            }
            .store(in: &cancellables)
        
        // 状态节流更新
        stateSubject
            .removeDuplicates() // 只有状态真正改变才更新
            .throttle(for: .seconds(stateUpdateInterval), scheduler: DispatchQueue.main, latest: true)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.currentState = state
            }
            .store(in: &cancellables)
        
        // 可见性防抖更新
        visibilitySubject
            .removeDuplicates()
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] visible in
                self?.isVisible = visible
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 公共方法
    
    /// 更新音频级别
    public func updateAudioLevel(_ level: Float) {
        audioLevelSubject.send(level)
    }
    
    /// 更新波形数据
    public func updateWaveformData(_ data: [Float]) {
        waveformSubject.send(data)
    }
    
    /// 更新状态
    public func updateState(_ state: OrbState) {
        stateSubject.send(state)
    }
    
    /// 更新可见性
    public func updateVisibility(_ visible: Bool) {
        visibilitySubject.send(visible)
    }
    
    /// 批量更新多个属性
    public func batchUpdate(
        audioLevel: Float? = nil,
        waveformData: [Float]? = nil,
        state: OrbState? = nil,
        visibility: Bool? = nil
    ) {
        if let level = audioLevel {
            audioLevelSubject.send(level)
        }
        if let data = waveformData {
            waveformSubject.send(data)
        }
        if let newState = state {
            stateSubject.send(newState)
        }
        if let visible = visibility {
            visibilitySubject.send(visible)
        }
    }
}

// MARK: - 窗口操作优化器
@MainActor
public final class WindowOperationOptimizer: ObservableObject {
    
    // MARK: - 单例
    public static let shared = WindowOperationOptimizer()
    
    // MARK: - 私有属性
    private var pendingOperations: [WindowOperation] = []
    private var operationTimer: Timer?
    private let operationQueue = DispatchQueue(label: "com.helloprompt.windowops", qos: .userInteractive)
    
    // 批处理配置
    private let batchInterval: TimeInterval = 0.016  // ~60 FPS
    
    // MARK: - 窗口操作类型
    private enum WindowOperation {
        case show(windowTitle: String)
        case hide(windowTitle: String)
        case focus(windowTitle: String)
    }
    
    // MARK: - 初始化
    private init() {
        setupBatchProcessing()
        LogManager.shared.info("WindowOperationOptimizer", "窗口操作优化器初始化完成")
    }
    
    // MARK: - 私有方法
    private func setupBatchProcessing() {
        operationTimer = Timer.scheduledTimer(withTimeInterval: batchInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.processBatchedOperations()
            }
        }
    }
    
    private func processBatchedOperations() async {
        guard !pendingOperations.isEmpty else { return }
        
        let operations = pendingOperations
        pendingOperations.removeAll()
        
        // 在后台队列处理窗口操作，避免阻塞主线程
        Task.detached(priority: .userInteractive) { [weak self] in
            await self?.executeWindowOperations(operations)
        }
    }
    
    private func executeWindowOperations(_ operations: [WindowOperation]) async {
        await MainActor.run {
            // 合并同类型操作，只执行最后一个
            var consolidatedOps: [String: WindowOperation] = [:]
            
            for operation in operations {
                let key = self.getOperationKey(operation)
                consolidatedOps[key] = operation
            }
            
            // 执行合并后的操作
            for operation in consolidatedOps.values {
                self.performWindowOperation(operation)
            }
        }
    }
    
    private func getOperationKey(_ operation: WindowOperation) -> String {
        switch operation {
        case .show(let title), .hide(let title), .focus(let title):
            return title
        }
    }
    
    private func performWindowOperation(_ operation: WindowOperation) {
        switch operation {
        case .show(let windowTitle):
            performShowWindow(windowTitle)
        case .hide(let windowTitle):
            performHideWindow(windowTitle)
        case .focus(let windowTitle):
            performFocusWindow(windowTitle)
        }
    }
    
    private func performShowWindow(_ title: String) {
        let window = findWindow(title)
        window?.orderFront(nil)
        window?.makeKey()
    }
    
    private func performHideWindow(_ title: String) {
        let window = findWindow(title)
        window?.orderOut(nil)
    }
    
    private func performFocusWindow(_ title: String) {
        let window = findWindow(title)
        window?.makeKey()
    }
    
    private func findWindow(_ title: String) -> NSWindow? {
        return NSApp.windows.first { $0.title == title }
    }
    
    // MARK: - 公共方法
    
    // MARK: - 公共窗口操作方法
    
    /// 异步显示窗口
    public func showWindow(_ title: String) {
        pendingOperations.append(.show(windowTitle: title))
    }
    
    /// 异步隐藏窗口
    public func hideWindow(_ title: String) {
        pendingOperations.append(.hide(windowTitle: title))
    }
    
    /// 异步聚焦窗口
    public func focusWindow(_ title: String) {
        pendingOperations.append(.focus(windowTitle: title))
    }
    
    /// 立即执行窗口操作（紧急情况使用）
    public func immediateShowWindow(_ title: String) {
        performShowWindow(title)
    }
    
    /// 立即隐藏窗口（紧急情况使用）
    public func immediateHideWindow(_ title: String) {
        performHideWindow(title)
    }
    
    /// 清理资源
    public func cleanup() {
        operationTimer?.invalidate()
        operationTimer = nil
        pendingOperations.removeAll()
        LogManager.shared.info("WindowOperationOptimizer", "窗口操作优化器已清理")
    }
}
