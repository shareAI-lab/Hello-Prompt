//
//  SiriOrb.swift
//  HelloPrompt
//
//  Siri风格录音光球UI组件 - 提供视觉反馈和动画效果
//  包含语音活动检测可视化、状态指示、平滑动画过渡
//

import SwiftUI
import Combine

// MARK: - 光球状态枚举
public enum OrbState: String, CaseIterable {
    case idle = "空闲"
    case listening = "监听中"
    case recording = "录音中"
    case processing = "处理中"
    case result = "显示结果"
    case error = "错误状态"
    
    var baseColor: Color {
        switch self {
        case .idle:
            return Color(.systemBlue).opacity(0.3)
        case .listening:
            return Color(.systemBlue).opacity(0.6)
        case .recording:
            return Color(.systemRed)
        case .processing:
            return Color(.systemOrange)
        case .result:
            return Color(.systemGreen)
        case .error:
            return Color(.systemRed).opacity(0.8)
        }
    }
    
    var glowColor: Color {
        switch self {
        case .idle:
            return Color(.systemBlue).opacity(0.1)
        case .listening:
            return Color(.systemBlue).opacity(0.3)
        case .recording:
            return Color(.systemRed).opacity(0.6)
        case .processing:
            return Color(.systemOrange).opacity(0.4)
        case .result:
            return Color(.systemGreen).opacity(0.4)
        case .error:
            return Color(.systemRed).opacity(0.5)
        }
    }
    
    var shouldPulse: Bool {
        switch self {
        case .listening, .recording, .processing:
            return true
        default:
            return false
        }
    }
    
    var shouldRotate: Bool {
        switch self {
        case .processing:
            return true
        default:
            return false
        }
    }
}

// MARK: - 音频频谱数据
public struct AudioSpectrum {
    let levels: [Float]
    let peakLevel: Float
    let rmsLevel: Float
    
    static let empty = AudioSpectrum(levels: Array(repeating: 0.0, count: 8), peakLevel: 0.0, rmsLevel: 0.0)
    
    func normalizedLevels(count: Int = 8) -> [Float] {
        if levels.count >= count {
            return Array(levels.prefix(count))
        } else {
            var normalized = levels
            while normalized.count < count {
                normalized.append(0.0)
            }
            return normalized
        }
    }
}

// MARK: - 主Siri光球组件
public struct SiriOrb: View {
    
    // MARK: - 状态属性
    @State private var currentState: OrbState = .idle
    @State private var audioSpectrum: AudioSpectrum = .empty
    @State private var animationScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0.0
    @State private var pulseOpacity: Double = 0.3
    @State private var waveformAmplitudes: [CGFloat] = Array(repeating: 0.2, count: 8)
    
    // MARK: - 动画状态
    @State private var isPulsing = false
    @State private var isRotating = false
    @State private var waveformTimer: Timer?
    
    // MARK: - 外部绑定
    @Binding var orbState: OrbState
    @Binding var audioLevel: Float
    @Binding var isVisible: Bool
    
    // MARK: - 配置参数
    let orbSize: CGFloat
    let enableHapticFeedback: Bool
    let showDebugInfo: Bool
    
    // MARK: - 私有属性
    private let maxWaveformBars = 8
    private let animationDuration: Double = 0.8
    private let pulseAnimationDuration: Double = 1.2
    
    // MARK: - 初始化
    public init(
        orbState: Binding<OrbState>,
        audioLevel: Binding<Float>,
        isVisible: Binding<Bool>,
        orbSize: CGFloat = 120,
        enableHapticFeedback: Bool = true,
        showDebugInfo: Bool = false
    ) {
        self._orbState = orbState
        self._audioLevel = audioLevel
        self._isVisible = isVisible
        self.orbSize = orbSize
        self.enableHapticFeedback = enableHapticFeedback
        self.showDebugInfo = showDebugInfo
    }
    
    // MARK: - 主视图
    public var body: some View {
        ZStack {
            if isVisible {
                // 背景光圈
                backgroundGlow
                
                // 主光球
                mainOrb
                
                // 音频波形
                if currentState == .recording {
                    audioWaveform
                }
                
                // 处理中旋转环
                if currentState == .processing {
                    processingRing
                }
                
                // 状态指示器
                statusIndicator
                
                // 调试信息
                if showDebugInfo {
                    debugOverlay
                }
            }
        }
        .frame(width: orbSize * 1.8, height: orbSize * 1.8)
        .scaleEffect(animationScale)
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.3), value: isVisible)
        .onChange(of: orbState) { newState in
            handleStateChange(newState)
        }
        .onChange(of: audioLevel) { newLevel in
            updateAudioVisualization(newLevel)
        }
        .onAppear {
            setupInitialState()
        }
        .onDisappear {
            cleanup()
        }
    }
    
    // MARK: - 子视图组件
    
    /// 背景光圈效果
    private var backgroundGlow: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        currentState.glowColor,
                        currentState.glowColor.opacity(0.1),
                        Color.clear
                    ]),
                    center: .center,
                    startRadius: orbSize * 0.3,
                    endRadius: orbSize * 0.9
                )
            )
            .frame(width: orbSize * 1.8, height: orbSize * 1.8)
            .opacity(pulseOpacity)
            .animation(.easeInOut(duration: pulseAnimationDuration).repeatForever(autoreverses: true), value: isPulsing)
    }
    
    /// 主光球
    private var mainOrb: some View {
        ZStack {
            // 基础圆形
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            currentState.baseColor.opacity(0.8),
                            currentState.baseColor.opacity(0.9),
                            currentState.baseColor
                        ]),
                        center: UnitPoint(x: 0.3, y: 0.3),
                        startRadius: 5,
                        endRadius: orbSize * 0.5
                    )
                )
                .frame(width: orbSize, height: orbSize)
            
            // 内部高光
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.4),
                            Color.white.opacity(0.1),
                            Color.clear
                        ]),
                        center: UnitPoint(x: 0.3, y: 0.3),
                        startRadius: 0,
                        endRadius: orbSize * 0.3
                    )
                )
                .frame(width: orbSize * 0.6, height: orbSize * 0.6)
            
            // 边缘光晕
            Circle()
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            currentState.baseColor.opacity(0.8),
                            currentState.baseColor.opacity(0.2)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: orbSize, height: orbSize)
        }
        .rotationEffect(.degrees(rotationAngle))
        .animation(.linear(duration: 2.0).repeatForever(autoreverses: false), value: isRotating)
    }
    
    /// 音频波形可视化
    private var audioWaveform: some View {
        HStack(spacing: 3) {
            ForEach(0..<maxWaveformBars, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                currentState.baseColor.opacity(0.8),
                                currentState.baseColor.opacity(0.4)
                            ]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(
                        width: 4,
                        height: CGFloat(waveformAmplitudes[index]) * orbSize * 0.4
                    )
                    .animation(
                        .easeInOut(duration: 0.1),
                        value: waveformAmplitudes[index]
                    )
            }
        }
        .opacity(0.8)
    }
    
    /// 处理中旋转环
    private var processingRing: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [
                        currentState.baseColor,
                        currentState.baseColor.opacity(0.3),
                        Color.clear
                    ]),
                    center: .center
                ),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            .frame(width: orbSize * 1.2, height: orbSize * 1.2)
            .rotationEffect(.degrees(rotationAngle))
            .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: isRotating)
    }
    
    /// 状态指示器
    private var statusIndicator: some View {
        VStack(spacing: 8) {
            Spacer()
            
            Text(currentState.rawValue)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .opacity(0.8)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                        .backdrop(BlurEffect(style: .hudWindow))
                )
        }
        .offset(y: orbSize * 0.7)
    }
    
    /// 调试信息覆盖
    private var debugOverlay: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("状态: \(currentState.rawValue)")
            Text("音频: \(String(format: "%.3f", audioLevel))")
            Text("缩放: \(String(format: "%.2f", animationScale))")
            Text("脉冲: \(String(format: "%.2f", pulseOpacity))")
        }
        .font(.system(size: 10).monospaced())
        .foregroundColor(.secondary)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.8))
        )
        .offset(x: orbSize * 0.7, y: -orbSize * 0.7)
    }
    
    // MARK: - 状态管理
    
    /// 处理状态变化
    private func handleStateChange(_ newState: OrbState) {
        let oldState = currentState
        currentState = newState
        
        LogManager.shared.info("SiriOrb", "状态变化: \(oldState.rawValue) -> \(newState.rawValue)")
        
        // 触觉反馈
        if enableHapticFeedback {
            providehapticFeedback(for: newState)
        }
        
        // 更新动画状态
        updateAnimationState(for: newState)
        
        // 状态转换动画
        performStateTransitionAnimation(from: oldState, to: newState)
    }
    
    /// 更新动画状态
    private func updateAnimationState(for state: OrbState) {
        withAnimation(.easeInOut(duration: animationDuration)) {
            isPulsing = state.shouldPulse
            pulseOpacity = state.shouldPulse ? 0.6 : 0.3
        }
        
        if state.shouldRotate {
            if !isRotating {
                isRotating = true
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    rotationAngle = 360
                }
            }
        } else {
            isRotating = false
            withAnimation(.easeOut(duration: 0.5)) {
                rotationAngle = 0
            }
        }
        
        // 启动或停止波形动画
        if state == .recording {
            startWaveformAnimation()
        } else {
            stopWaveformAnimation()
        }
    }
    
    /// 执行状态转换动画
    private func performStateTransitionAnimation(from oldState: OrbState, to newState: OrbState) {
        // 缩放动画
        withAnimation(.easeInOut(duration: 0.2)) {
            animationScale = 1.1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                animationScale = 1.0
            }
        }
        
        // 特殊状态转换
        switch (oldState, newState) {
        case (_, .error):
            // 错误状态震动效果
            performErrorShakeAnimation()
            
        case (.processing, .result):
            // 成功完成动画
            performSuccessAnimation()
            
        default:
            break
        }
    }
    
    /// 错误震动动画
    private func performErrorShakeAnimation() {
        let shakeAnimation = Animation.easeInOut(duration: 0.1).repeatCount(4, autoreverses: true)
        
        withAnimation(shakeAnimation) {
            // 这里应该实现震动效果，但SwiftUI的限制使得实现较复杂
            // 可以考虑使用偏移量来模拟震动
        }
    }
    
    /// 成功完成动画
    private func performSuccessAnimation() {
        withAnimation(.easeOut(duration: 0.5)) {
            animationScale = 1.2
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                animationScale = 1.0
            }
        }
    }
    
    // MARK: - 音频可视化
    
    /// 更新音频可视化
    private func updateAudioVisualization(_ level: Float) {
        guard currentState == .recording else { return }
        
        // 生成模拟频谱数据
        let normalizedLevel = min(max(level, 0.0), 1.0)
        
        // 更新波形振幅
        for i in 0..<maxWaveformBars {
            let randomVariation = Float.random(in: 0.7...1.3)
            let amplitude = normalizedLevel * randomVariation
            
            withAnimation(.easeInOut(duration: 0.1)) {
                waveformAmplitudes[i] = CGFloat(amplitude * 0.5 + 0.2) // 基础高度 + 音频驱动
            }
        }
        
        // 主光球大小调整
        let scaleVariation = 1.0 + CGFloat(normalizedLevel) * 0.1
        withAnimation(.easeInOut(duration: 0.1)) {
            animationScale = scaleVariation
        }
    }
    
    /// 启动波形动画
    private func startWaveformAnimation() {
        waveformTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            // 生成随机波形动画（当没有实际音频输入时）
            if audioLevel <= 0.01 {
                for i in 0..<maxWaveformBars {
                    let randomAmplitude = CGFloat.random(in: 0.1...0.4)
                    withAnimation(.easeInOut(duration: 0.1)) {
                        waveformAmplitudes[i] = randomAmplitude
                    }
                }
            }
        }
    }
    
    /// 停止波形动画
    private func stopWaveformAnimation() {
        waveformTimer?.invalidate()
        waveformTimer = nil
        
        // 重置波形到基础状态
        withAnimation(.easeOut(duration: 0.3)) {
            for i in 0..<maxWaveformBars {
                waveformAmplitudes[i] = 0.2
            }
        }
    }
    
    // MARK: - 触觉反馈
    
    /// 提供触觉反馈
    private func providehapticFeedback(for state: OrbState) {
        guard enableHapticFeedback else { return }
        
        switch state {
        case .listening:
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            
        case .recording:
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
            
        case .processing:
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            
        case .result:
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            
        case .error:
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            
        default:
            break
        }
    }
    
    // MARK: - 生命周期管理
    
    /// 设置初始状态
    private func setupInitialState() {
        currentState = orbState
        
        // 重置所有动画状态
        animationScale = 1.0
        rotationAngle = 0.0
        pulseOpacity = 0.3
        
        // 初始化波形数据
        waveformAmplitudes = Array(repeating: 0.2, count: maxWaveformBars)
        
        LogManager.shared.info("SiriOrb", "Siri光球组件初始化完成")
    }
    
    /// 清理资源
    private func cleanup() {
        waveformTimer?.invalidate()
        waveformTimer = nil
        
        LogManager.shared.info("SiriOrb", "Siri光球组件已清理")
    }
}

// MARK: - 背景模糊效果
private struct BlurEffect: NSViewRepresentable {
    let style: NSVisualEffectView.Material
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = style
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = style
    }
}

// MARK: - 扩展方法
extension View {
    fileprivate func backdrop(_ effect: BlurEffect) -> some View {
        self.background(effect)
    }
}

// MARK: - SiriOrb预览
#if DEBUG
struct SiriOrb_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 不同状态预览
            VStack(spacing: 30) {
                HStack(spacing: 30) {
                    SiriOrb(
                        orbState: .constant(.idle),
                        audioLevel: .constant(0.0),
                        isVisible: .constant(true),
                        orbSize: 80
                    )
                    .previewDisplayName("空闲状态")
                    
                    SiriOrb(
                        orbState: .constant(.listening),
                        audioLevel: .constant(0.2),
                        isVisible: .constant(true),
                        orbSize: 80
                    )
                    .previewDisplayName("监听状态")
                }
                
                HStack(spacing: 30) {
                    SiriOrb(
                        orbState: .constant(.recording),
                        audioLevel: .constant(0.6),
                        isVisible: .constant(true),
                        orbSize: 80
                    )
                    .previewDisplayName("录音状态")
                    
                    SiriOrb(
                        orbState: .constant(.processing),
                        audioLevel: .constant(0.0),
                        isVisible: .constant(true),
                        orbSize: 80
                    )
                    .previewDisplayName("处理状态")
                }
                
                HStack(spacing: 30) {
                    SiriOrb(
                        orbState: .constant(.result),
                        audioLevel: .constant(0.0),
                        isVisible: .constant(true),
                        orbSize: 80
                    )
                    .previewDisplayName("结果状态")
                    
                    SiriOrb(
                        orbState: .constant(.error),
                        audioLevel: .constant(0.0),
                        isVisible: .constant(true),
                        orbSize: 80
                    )
                    .previewDisplayName("错误状态")
                }
            }
            .padding(40)
            .background(Color(NSColor.windowBackgroundColor))
            .previewLayout(.sizeThatFits)
        }
    }
}
#endif