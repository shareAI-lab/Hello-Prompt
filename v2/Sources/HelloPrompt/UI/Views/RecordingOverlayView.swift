//
//  RecordingOverlayView.swift
//  HelloPrompt
//
//  录音覆盖层界面 - 显示Siri风格的录音气泡
//  提供全屏录音反馈和取消操作功能
//

import SwiftUI

// MARK: - 录音覆盖层视图
public struct RecordingOverlayView: View {
    
    // MARK: - 绑定属性
    @Binding var orbState: OrbState
    @Binding var audioLevel: Float
    @Binding var isVisible: Bool
    
    // MARK: - 音频服务（用于获取详细状态）
    @StateObject private var audioService = AudioService()
    
    // MARK: - 性能优化器
    @StateObject private var uiThrottler = UIUpdateThrottler()
    @StateObject private var animationOptimizer = AnimationPerformanceOptimizer.shared
    
    // MARK: - 回调函数
    let onCancel: () -> Void
    
    // MARK: - 状态属性
    @State private var showCancelButton = false
    
    // MARK: - 初始化
    public init(
        orbState: Binding<OrbState>,
        audioLevel: Binding<Float>,
        isVisible: Binding<Bool>,
        onCancel: @escaping () -> Void
    ) {
        self._orbState = orbState
        self._audioLevel = audioLevel
        self._isVisible = isVisible
        self.onCancel = onCancel
    }
    
    // MARK: - 主视图
    public var body: some View {
        ZStack {
            // 透明背景
            Color.clear
                .ignoresSafeArea()
            
            if isVisible {
                VStack(spacing: 20) {
                    // Siri风格的录音光球（直接使用绑定状态）
                    SiriOrb(
                        orbState: $orbState,
                        audioLevel: $audioLevel,
                        isVisible: $isVisible,
                        orbSize: 120,
                        enableHapticFeedback: true,
                        showDebugInfo: false
                    )
                    
                    // 详细状态显示（优化版本）
                    optimizedStatusView
                    
                    // 取消按钮（延迟显示）
                    if showCancelButton && animationOptimizer.isAnimationEnabled {
                        Button("取消") {
                            onCancel()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.white)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.8))
                        )
                        .transition(.opacity.combined(with: .scale))
                        .animation(
                            .easeInOut(duration: animationOptimizer.getOptimizedAnimationDuration(0.3)),
                            value: showCancelButton
                        )
                    }
                }
                .transition(.opacity.combined(with: .scale))
                .animation(
                    .easeInOut(duration: animationOptimizer.getOptimizedAnimationDuration(0.3)), 
                    value: isVisible
                )
                .onAppear {
                    setupUIUpdates()
                    scheduleShowCancelButton()
                }
                .onDisappear {
                    showCancelButton = false
                }
            }
        }
        .onChange(of: isVisible) { visible in
            // 使用优化的窗口操作
            updateWindowVisibilityOptimized(visible)
        }
        .onChange(of: orbState) { state in
            uiThrottler.updateState(state)
        }
        .onChange(of: audioLevel) { level in
            uiThrottler.updateAudioLevel(level)
        }
    }
    
    // MARK: - 辅助方法
    
    /// 优化的状态显示视图
    @ViewBuilder
    private var optimizedStatusView: some View {
        VStack(spacing: 8) {
            // 主状态文字
            HStack(spacing: 8) {
                Image(systemName: audioService.detailedState.iconName)
                    .foregroundColor(colorForState(audioService.detailedState.color))
                    .font(.title2)
                
                Text(audioService.detailedState.displayText)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.7))
            )
            
            // 条件性显示的进度和时长信息
            if animationOptimizer.animationQuality != .low {
                conditionalStatusInfo
            }
        }
    }
    
    /// 条件性状态信息
    @ViewBuilder
    private var conditionalStatusInfo: some View {
        // VAD倒计时进度条（仅在静音检测时显示）
        if case .silenceDetected(let countdown) = audioService.detailedState {
            VADCountdownView(countdown: countdown, timeout: 1.5)
                .transition(.opacity.combined(with: .scale))
                .animation(
                    .easeInOut(duration: animationOptimizer.getOptimizedAnimationDuration(0.2)), 
                    value: countdown
                )
        }
        
        // 录音时长显示（录音时显示）
        if case .recording(let duration) = audioService.detailedState {
            Text("时长: \(formatDuration(duration))")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.5))
                )
        }
    }
    
    /// 设置UI更新
    private func setupUIUpdates() {
        // 初始化节流器状态
        uiThrottler.updateState(orbState)
        uiThrottler.updateAudioLevel(audioLevel)
        uiThrottler.updateVisibility(isVisible)
    }
    
    /// 延迟显示取消按钮
    private func scheduleShowCancelButton() {
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
            await MainActor.run {
                if isVisible {
                    withAnimation(.easeInOut(duration: animationOptimizer.getOptimizedAnimationDuration(0.3))) {
                        showCancelButton = true
                    }
                }
            }
        }
    }
    
    /// 优化的窗口可见性更新
    private func updateWindowVisibilityOptimized(_ visible: Bool) {
        // 更新节流器状态
        uiThrottler.updateVisibility(visible)
        
        // 使用优化的窗口操作器
        if visible {
            WindowOperationOptimizer.shared.showWindow("录音")
        } else {
            WindowOperationOptimizer.shared.hideWindow("录音")
        }
        
        LogManager.shared.debug("RecordingOverlayView", "优化的窗口可见性更新: \(visible)")
    }
    
    /// 获取状态文字
    private func getStatusText() -> String {
        switch orbState {
        case .idle:
            return "准备就绪"
        case .listening:
            return "正在监听..."
        case .recording:
            return "正在录音..."
        case .processing:
            return "正在处理..."
        case .result:
            return "处理完成"
        case .error:
            return "出现错误"
        }
    }
    
    /// 颜色转换辅助方法
    private func colorForState(_ colorString: String) -> Color {
        switch colorString {
        case "red":
            return .red
        case "green":
            return .green
        case "blue":
            return .blue
        case "orange":
            return .orange
        case "yellow":
            return .yellow
        default:
            return .white
        }
    }
    
    /// 格式化时长显示
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let milliseconds = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        
        if minutes > 0 {
            return String(format: "%d:%02d.%d", minutes, seconds, milliseconds)
        } else {
            return String(format: "%d.%d", seconds, milliseconds)
        }
    }
    
    /// 更新窗口可见性
    private func updateWindowVisibility(_ visible: Bool) {
        LogManager.shared.info("RecordingOverlayView", "updateWindowVisibility 被调用，visible: \(visible)")
        
        DispatchQueue.main.async {
            let recordingWindows = NSApp.windows.filter { $0.title == "录音" }
            LogManager.shared.info("RecordingOverlayView", "找到 \(recordingWindows.count) 个录音窗口")
            
            if let window = recordingWindows.first {
                LogManager.shared.info("RecordingOverlayView", "操作录音窗口: \(window.windowNumber)")
                
                if visible {
                    window.orderFront(nil)
                    window.makeKey()
                    LogManager.shared.info("RecordingOverlayView", "录音窗口已显示")
                } else {
                    window.orderOut(nil)
                    LogManager.shared.info("RecordingOverlayView", "录音窗口已隐藏")
                }
            } else {
                LogManager.shared.error("RecordingOverlayView", "未找到录音窗口")
                // 打印所有窗口信息进行调试
                for (index, window) in NSApp.windows.enumerated() {
                    LogManager.shared.debug("RecordingOverlayView", "窗口\(index): 标题='\(window.title)', ID=\(window.windowNumber)")
                }
            }
        }
    }
}

// MARK: - VAD倒计时视图
struct VADCountdownView: View {
    let countdown: TimeInterval
    let timeout: TimeInterval
    
    private var progress: Double {
        max(0, min(1, countdown / timeout))
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text("静音检测")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
            
            HStack(spacing: 8) {
                // 进度条
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 4)
                            .cornerRadius(2)
                        
                        Rectangle()
                            .fill(Color.yellow)
                            .frame(width: geometry.size.width * progress, height: 4)
                            .cornerRadius(2)
                            .animation(.linear(duration: 0.1), value: progress)
                    }
                }
                .frame(height: 4)
                
                // 倒计时数字
                Text(String(format: "%.1f", countdown))
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .frame(width: 30, alignment: .trailing)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.6))
        )
    }
}

// MARK: - 预览
#if DEBUG
struct RecordingOverlayView_Previews: PreviewProvider {
    @State static var orbState: OrbState = .recording
    @State static var audioLevel: Float = 0.5
    @State static var isVisible: Bool = true
    
    static var previews: some View {
        RecordingOverlayView(
            orbState: $orbState,
            audioLevel: $audioLevel,
            isVisible: $isVisible,
            onCancel: {}
        )
        .previewDisplayName("录音覆盖层")
    }
}
#endif