//
//  ResultOverlay.swift
//  HelloPrompt
//
//  结果展示覆盖层 - 半透明浮窗显示语音转换和提示词优化结果
//  支持文本编辑、快捷键操作、多种显示模式
//

import SwiftUI
import AppKit

// MARK: - 显示模式枚举
public enum OverlayDisplayMode: String, CaseIterable {
    case compact = "紧凑模式"
    case expanded = "展开模式"
    case minimal = "最小模式"
    
    var windowSize: CGSize {
        switch self {
        case .compact:
            return CGSize(width: 400, height: 200)
        case .expanded:
            return CGSize(width: 600, height: 400)
        case .minimal:
            return CGSize(width: 300, height: 100)
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .compact: return 12
        case .expanded: return 16
        case .minimal: return 8
        }
    }
}

// 使用UIModels.swift中定义的OverlayAction和OverlayResult

// MARK: - 主覆盖层组件
public struct ResultOverlay: View {
    
    // MARK: - 状态属性
    @State private var displayMode: OverlayDisplayMode = .compact
    @State private var isVisible = false
    @State private var editableText: String = ""
    @State private var isEditing = false
    @State private var showImprovements = false
    @State private var showStatistics = false
    
    // MARK: - 外部绑定
    @Binding var result: OverlayResult?
    @Binding var isShowing: Bool
    
    // MARK: - 回调处理
    let onAction: (OverlayAction, String) -> Void
    let onClose: () -> Void
    
    // MARK: - 配置参数
    let enableAnimations: Bool
    let allowEditing: Bool
    let showKeyboardHints: Bool
    
    // MARK: - 私有属性
    @FocusState private var isTextFieldFocused: Bool
    @State private var hoveredAction: OverlayAction?
    
    // MARK: - 初始化
    public init(
        result: Binding<OverlayResult?>,
        isShowing: Binding<Bool>,
        onAction: @escaping (OverlayAction, String) -> Void,
        onClose: @escaping () -> Void,
        enableAnimations: Bool = true,
        allowEditing: Bool = true,
        showKeyboardHints: Bool = true
    ) {
        self._result = result
        self._isShowing = isShowing
        self.onAction = onAction
        self.onClose = onClose
        self.enableAnimations = enableAnimations
        self.allowEditing = allowEditing
        self.showKeyboardHints = showKeyboardHints
    }
    
    // MARK: - 主视图
    public var body: some View {
        Group {
            if isShowing, let result = result {
                ZStack {
                    // 背景遮罩
                    backgroundMask
                    
                    // 主内容区域
                    mainContent(result)
                }
                .opacity(isVisible ? 1 : 0)
                .animation(enableAnimations ? .easeInOut(duration: 0.3) : .none, value: isVisible)
                .onAppear {
                    setupOverlay(with: result)
                }
                .onDisappear {
                    cleanup()
                }
            }
        }
        .onChange(of: isShowing) { newValue in
            if newValue {
                showOverlay()
            } else {
                hideOverlay()
            }
        }
    }
    
    // MARK: - 子视图组件
    
    /// 背景遮罩
    private var backgroundMask: some View {
        Color.black
            .opacity(0.2)
            .ignoresSafeArea()
            .onTapGesture {
                handleAction(.close)
            }
    }
    
    /// 主内容区域
    private func mainContent(_ result: OverlayResult) -> some View {
        VStack(spacing: 0) {
            // 头部工具栏
            headerToolbar(result)
            
            // 内容区域
            contentArea(result)
            
            // 底部操作栏
            actionBar
        }
        .frame(
            width: displayMode.windowSize.width,
            height: displayMode.windowSize.height
        )
        .background(overlayBackground)
        .cornerRadius(displayMode.cornerRadius)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
    
    /// 覆盖层背景
    private var overlayBackground: some View {
        ZStack {
            // 毛玻璃效果
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
            
            // 渐变覆盖
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.8),
                    Color.white.opacity(0.6)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    /// 头部工具栏
    private func headerToolbar(_ result: OverlayResult) -> some View {
        HStack {
            // 标题和状态
            VStack(alignment: .leading, spacing: 2) {
                Text("提示词优化结果")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("处理时间: \(String(format: "%.2f", result.processingTime))s")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 工具按钮
            HStack(spacing: 8) {
                // 显示模式切换
                displayModeToggle
                
                // 改进点显示切换
                Button(action: { showImprovements.toggle() }) {
                    Image(systemName: showImprovements ? "list.bullet.circle.fill" : "list.bullet.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("显示/隐藏改进点")
                
                // 统计信息切换
                Button(action: { showStatistics.toggle() }) {
                    Image(systemName: showStatistics ? "chart.bar.fill" : "chart.bar")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("显示/隐藏统计信息")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.05))
    }
    
    /// 显示模式切换器
    private var displayModeToggle: some View {
        Menu {
            ForEach(OverlayDisplayMode.allCases, id: \.self) { mode in
                Button(mode.rawValue) {
                    withAnimation(enableAnimations ? .easeInOut(duration: 0.3) : .none) {
                        displayMode = mode
                    }
                }
            }
        } label: {
            Image(systemName: "rectangle.3.group")
                .foregroundColor(.secondary)
        }
        .menuStyle(BorderlessButtonMenuStyle())
        .help("切换显示模式")
    }
    
    /// 内容区域
    private func contentArea(_ result: OverlayResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 原始文本（仅在展开模式显示）
                if displayMode == .expanded {
                    originalTextSection(result.originalText)
                }
                
                // 优化后文本
                optimizedTextSection(result.optimizedText)
                
                // 改进点列表
                if showImprovements && !result.improvements.isEmpty {
                    improvementsSection(result.improvements)
                }
                
                // 统计信息
                if showStatistics {
                    statisticsSection(result)
                }
            }
            .padding(16)
        }
        .frame(maxHeight: .infinity)
    }
    
    /// 原始文本区域
    private func originalTextSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("原始输入")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .textSelection(.enabled)
        }
    }
    
    /// 优化后文本区域
    private func optimizedTextSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("优化结果")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            if allowEditing && isEditing {
                TextEditor(text: $editableText)
                    .font(.body)
                    .padding(8)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue, lineWidth: 2)
                    )
                    .focused($isTextFieldFocused)
                    .frame(minHeight: 80)
            } else {
                Text(editableText)
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                    .textSelection(.enabled)
                    .onTapGesture(count: 2) {
                        if allowEditing {
                            startEditing()
                        }
                    }
            }
            
            // 编辑控制按钮
            if allowEditing {
                HStack {
                    if isEditing {
                        Button("保存") {
                            finishEditing()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        
                        Button("取消") {
                            cancelEditing()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Button("编辑") {
                            startEditing()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    /// 改进点区域
    private func improvementsSection(_ improvements: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("主要改进")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(improvements.indices, id: \.self) { index in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        
                        Text(improvements[index])
                            .font(.caption)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                }
            }
            .padding(12)
            .background(Color.green.opacity(0.05))
            .cornerRadius(8)
        }
    }
    
    /// 统计信息区域
    private func statisticsSection(_ result: OverlayResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("统计信息")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            HStack {
                statisticItem("字数", "\(result.wordCount)")
                Spacer()
                statisticItem("字符", "\(result.characterCount)")
                Spacer()
                statisticItem("改进", "\(result.improvements.count)")
                Spacer()
            }
            .padding(12)
            .background(Color.orange.opacity(0.05))
            .cornerRadius(8)
        }
    }
    
    /// 统计项
    private func statisticItem(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    /// 底部操作栏
    private var actionBar: some View {
        HStack(spacing: 12) {
            // 主要操作按钮
            ForEach([OverlayAction.insert, .copy], id: \.self) { action in
                actionButton(action, isPrimary: action == .insert)
            }
            
            Spacer()
            
            // 次要操作按钮
            ForEach([OverlayAction.modify, .regenerate, .close], id: \.self) { action in
                actionButton(action, isPrimary: false)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.05))
    }
    
    /// 操作按钮
    private func actionButton(_ action: OverlayAction, isPrimary: Bool) -> some View {
        Button(action: { handleAction(action) }) {
            HStack(spacing: 6) {
                Image(systemName: action.systemImage)
                    .font(.system(size: 14, weight: .medium))
                
                Text(action.rawValue)
                    .font(.system(size: 14, weight: .medium))
                
                if showKeyboardHints {
                    keyboardHint(for: action)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .controlSize(.small)
        .keyboardShortcut(action.keyboardShortcut, modifiers: action.modifiers)
        .onHover { isHovered in
            hoveredAction = isHovered ? action : nil
        }
        .help("\(action.rawValue) (\(shortcutDescription(for: action)))")
    }
    
    /// 键盘快捷键提示
    private func keyboardHint(for action: OverlayAction) -> some View {
        Text(shortcutDescription(for: action))
            .font(.system(size: 10).monospaced())
            .foregroundColor(.secondary)
            .opacity(0.8)
    }
    
    /// 快捷键描述
    private func shortcutDescription(for action: OverlayAction) -> String {
        let modifierSymbols = action.modifiers.contains(.command) ? "⌘" : ""
        let keyChar = action.keyboardShortcut.character
        let keySymbol: String
        
        switch keyChar {
        case "\r": keySymbol = "↩"
        case "\u{1b}": keySymbol = "⎋"
        default: keySymbol = keyChar.uppercased()
        }
        
        return "\(modifierSymbols)\(keySymbol)"
    }
    
    // MARK: - 交互处理
    
    /// 处理操作
    private func handleAction(_ action: OverlayAction) {
        LogManager.shared.info("ResultOverlay", "执行操作: \(action.rawValue)")
        
        switch action {
        case .close:
            onClose()
        default:
            onAction(action, editableText)
        }
        
        // 提供触觉反馈
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
    
    /// 开始编辑
    private func startEditing() {
        isEditing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isTextFieldFocused = true
        }
        
        LogManager.shared.debug("ResultOverlay", "开始编辑模式")
    }
    
    /// 完成编辑
    private func finishEditing() {
        isEditing = false
        isTextFieldFocused = false
        
        LogManager.shared.debug("ResultOverlay", "完成编辑: \(editableText.count) 字符")
    }
    
    /// 取消编辑
    private func cancelEditing() {
        if let result = result {
            editableText = result.optimizedText
        }
        isEditing = false
        isTextFieldFocused = false
        
        LogManager.shared.debug("ResultOverlay", "取消编辑")
    }
    
    // MARK: - 生命周期管理
    
    /// 设置覆盖层
    private func setupOverlay(with result: OverlayResult) {
        editableText = result.optimizedText
        
        LogManager.shared.info("ResultOverlay", """
            显示结果覆盖层
            原始文本长度: \(result.originalText.count)
            优化文本长度: \(result.optimizedText.count)
            改进点数量: \(result.improvements.count)
            """)
    }
    
    /// 显示覆盖层
    private func showOverlay() {
        withAnimation(enableAnimations ? .easeOut(duration: 0.3) : .none) {
            isVisible = true
        }
    }
    
    /// 隐藏覆盖层
    private func hideOverlay() {
        withAnimation(enableAnimations ? .easeIn(duration: 0.2) : .none) {
            isVisible = false
        }
    }
    
    /// 清理资源
    private func cleanup() {
        isEditing = false
        isTextFieldFocused = false
        
        LogManager.shared.debug("ResultOverlay", "结果覆盖层已清理")
    }
}

// MARK: - 视觉效果视图
private struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - ResultOverlay预览
#if DEBUG
struct ResultOverlay_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 基本预览
            ResultOverlay(
                result: .constant(OverlayResult(
                    originalText: "帮我写一个Python函数来计算斐波那契数列",
                    optimizedText: """
                    请编写一个Python函数来计算斐波那契数列。函数应该满足以下要求：
                    1. 函数名为 `fibonacci`
                    2. 接受一个整数参数 `n` 表示要计算的项数
                    3. 返回包含前n项斐波那契数的列表
                    4. 处理边界情况（n=0, n=1）
                    5. 添加适当的文档字符串和类型提示
                    6. 考虑性能优化，避免重复计算
                    """,
                    improvements: [
                        "明确了函数名和参数要求",
                        "添加了返回值格式说明",
                        "补充了边界情况处理要求",
                        "要求添加文档和类型提示",
                        "强调了性能优化考虑"
                    ],
                    processingTime: 2.34,
                    context: "代码编辑器环境"
                )),
                isShowing: .constant(true),
                onAction: { action, text in
                    print("Action: \(action), Text: \(text.prefix(50))...")
                },
                onClose: {
                    print("Overlay closed")
                }
            )
            .previewDisplayName("完整结果覆盖层")
            .previewLayout(.sizeThatFits)
            
            // 最小模式预览
            ResultOverlay(
                result: .constant(OverlayResult(
                    originalText: "简短的测试文本",
                    optimizedText: "优化后的简短测试文本，更加清晰和准确。",
                    improvements: ["提高了清晰度", "增强了准确性"],
                    processingTime: 1.2
                )),
                isShowing: .constant(true),
                onAction: { _, _ in },
                onClose: { }
            )
            .previewDisplayName("最小模式")
            .previewLayout(.sizeThatFits)
        }
        .background(Color.gray.opacity(0.3))
    }
}
#endif