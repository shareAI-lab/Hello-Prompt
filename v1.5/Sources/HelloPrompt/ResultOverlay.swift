//
//  ResultOverlay.swift
//  HelloPrompt
//
//  结果展示蒙版 - 实现半透明背景、可滚动内容、操作按钮
//  Copyright © 2025 HelloPrompt. All rights reserved.
//

import Foundation
import AppKit
import QuartzCore

// MARK: - 结果展示配置
struct ResultOverlayConfig {
    let backgroundColor: NSColor = NSColor.black.withAlphaComponent(0.7)
    let contentBackgroundColor: NSColor = NSColor.controlBackgroundColor
    let cornerRadius: CGFloat = 12.0
    let padding: CGFloat = 20.0
    let maxWidth: CGFloat = 600.0
    let maxHeight: CGFloat = 400.0
    let animationDuration: TimeInterval = 0.3
    let autoHideDelay: TimeInterval = 10.0
    let fontSize: CGFloat = 14.0
}

// MARK: - 结果类型
enum ResultType {
    case transcription(TranscriptionResult)
    case optimization(PromptOptimizationResult)
    case modification(original: String, modified: String, improvements: [String])
    case error(String)
    case loading(String)
}

// MARK: - 结果展示代理协议
@MainActor
protocol ResultOverlayDelegate: AnyObject {
    func resultOverlay(_ overlay: ResultOverlay, didClickConfirm result: ResultType)
    func resultOverlay(_ overlay: ResultOverlay, didClickEdit result: ResultType)
    func resultOverlay(_ overlay: ResultOverlay, didClickCopy result: ResultType)
    func resultOverlay(_ overlay: ResultOverlay, didClickCancel result: ResultType)
    func resultOverlayDidDismiss(_ overlay: ResultOverlay)
}

// MARK: - 结果展示蒙版主类
@MainActor
class ResultOverlay: NSObject {
    
    // MARK: - Properties
    weak var delegate: ResultOverlayDelegate?
    
    private let config: ResultOverlayConfig
    private var window: NSWindow?
    private var backgroundView: NSView?
    private var contentView: NSView?
    private var scrollView: NSScrollView?
    private var textView: NSTextView?
    private var buttonContainer: NSView?
    
    private var confirmButton: NSButton?
    private var editButton: NSButton?
    private var copyButton: NSButton?
    private var cancelButton: NSButton?
    private var statsLabel: NSTextField?
    
    private var currentResult: ResultType?
    private var isVisible = false
    private var autoHideTimer: Timer?
    
    // MARK: - Initialization
    init(config: ResultOverlayConfig = ResultOverlayConfig()) {
        self.config = config
        super.init()
        
        LogManager.shared.uiLog("ResultOverlay初始化", details: [
            "maxWidth": config.maxWidth,
            "maxHeight": config.maxHeight,
            "autoHideDelay": config.autoHideDelay
        ])
        
        setupWindow()
        setupViews()
    }
    
    deinit {
        // 在Swift 6.0中，@MainActor类的deinit不能直接调用其他@MainActor方法
        cleanupSync()
    }
    
    // MARK: - Public Methods
    
    /// 显示结果
    func show(result: ResultType, at position: CGPoint? = nil) {
        currentResult = result
        
        updateContent(for: result)
        updateButtons(for: result)
        
        if let position = position {
            updatePosition(position)
        } else {
            centerWindow()
        }
        
        window?.setIsVisible(true)
        window?.makeKeyAndOrderFront(nil) // 确保窗口获得焦点
        isVisible = true
        
        animateShow()
        scheduleAutoHide()
        
        LogManager.shared.uiLog("显示结果蒙版", details: [
            "resultType": "\(result)",
            "position": position?.debugDescription ?? "center",
            "windowVisible": window?.isVisible ?? false
        ])
        
        // 强制刷新UI以确保内容显示
        DispatchQueue.main.async { [weak self] in
            self?.window?.display()
        }
    }
    
    /// 隐藏结果
    func hide() {
        guard isVisible else { return }
        
        cancelAutoHide()
        
        animateHide { [weak self] in
            self?.window?.setIsVisible(false)
            self?.isVisible = false
            self?.delegate?.resultOverlayDidDismiss(self!)
        }
        
        LogManager.shared.uiLog("隐藏结果蒙版")
    }
    
    /// 更新结果内容
    func updateResult(_ result: ResultType) {
        currentResult = result
        updateContent(for: result)
        updateButtons(for: result)
        
        // 重新安排自动隐藏
        scheduleAutoHide()
        
        LogManager.shared.uiLog("更新结果内容", details: [
            "resultType": "\(result)"
        ])
    }
    
    // MARK: - Private Methods
    
    /// 设置窗口
    private func setupWindow() {
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
        
        let windowRect = NSRect(
            x: (screenSize.width - config.maxWidth) / 2,
            y: (screenSize.height - config.maxHeight) / 2,
            width: screenSize.width,
            height: screenSize.height
        )
        
        window = NSWindow(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window?.level = .modalPanel
        window?.isOpaque = false
        window?.backgroundColor = .clear
        window?.hasShadow = false
        window?.ignoresMouseEvents = false
        window?.collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        LogManager.shared.uiLog("结果蒙版窗口创建", details: [
            "frame": "\(windowRect)",
            "level": "modalPanel"
        ])
    }
    
    /// 设置视图
    private func setupViews() {
        guard let window = window else { return }
        
        // 背景视图（全屏遮罩）
        backgroundView = NSView(frame: window.contentView?.bounds ?? .zero)
        backgroundView?.wantsLayer = true
        backgroundView?.layer?.backgroundColor = config.backgroundColor.cgColor
        
        // 添加点击背景关闭功能
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleBackgroundClick))
        backgroundView?.addGestureRecognizer(clickGesture)
        
        window.contentView = backgroundView
        
        // 内容视图
        let contentFrame = NSRect(
            x: (window.frame.width - config.maxWidth) / 2,
            y: (window.frame.height - config.maxHeight) / 2,
            width: config.maxWidth,
            height: config.maxHeight
        )
        
        contentView = NSView(frame: contentFrame)
        contentView?.wantsLayer = true
        contentView?.layer?.backgroundColor = config.contentBackgroundColor.cgColor
        contentView?.layer?.cornerRadius = config.cornerRadius
        contentView?.layer?.masksToBounds = true
        contentView?.layer?.shadowColor = NSColor.black.cgColor
        contentView?.layer?.shadowOpacity = 0.3
        contentView?.layer?.shadowOffset = CGSize(width: 0, height: -2)
        contentView?.layer?.shadowRadius = 8
        
        if let contentView = contentView {
            backgroundView?.addSubview(contentView)
        }
        
        setupScrollView()
        setupButtons()
        setupStatsBar()
        
        LogManager.shared.uiLog("结果蒙版视图设置完成", details: [
            "contentFrame": "\(contentFrame)",
            "cornerRadius": config.cornerRadius
        ])
    }
    
    /// 设置滚动视图
    private func setupScrollView() {
        guard let contentView = contentView else { return }
        
        let scrollFrame = NSRect(
            x: config.padding,
            y: 80, // 为按钮和状态栏留出空间
            width: contentView.bounds.width - config.padding * 2,
            height: contentView.bounds.height - 80 - config.padding
        )
        
        scrollView = NSScrollView(frame: scrollFrame)
        scrollView?.hasVerticalScroller = true
        scrollView?.hasHorizontalScroller = false
        scrollView?.borderType = .noBorder
        scrollView?.backgroundColor = .clear
        scrollView?.drawsBackground = false
        
        // 文本视图
        textView = NSTextView()
        textView?.isEditable = false
        textView?.isSelectable = true
        textView?.backgroundColor = .clear
        textView?.textColor = .labelColor
        textView?.font = NSFont.systemFont(ofSize: config.fontSize)
        textView?.textContainerInset = CGSize(width: 10, height: 10)
        textView?.isVerticallyResizable = true
        textView?.isHorizontallyResizable = false
        textView?.textContainer?.containerSize = CGSize(width: scrollFrame.width - 20, height: .greatestFiniteMagnitude)
        textView?.textContainer?.widthTracksTextView = true
        
        scrollView?.documentView = textView
        
        if let scrollView = scrollView {
            contentView.addSubview(scrollView)
        }
        
        LogManager.shared.uiLog("滚动视图设置完成", details: [
            "scrollFrame": "\(scrollFrame)",
            "fontSize": config.fontSize
        ])
    }
    
    /// 设置按钮
    private func setupButtons() {
        guard let contentView = contentView else { return }
        
        let buttonHeight: CGFloat = 32
        let buttonWidth: CGFloat = 80
        let buttonSpacing: CGFloat = 12
        
        let containerFrame = NSRect(
            x: config.padding,
            y: config.padding,
            width: contentView.bounds.width - config.padding * 2,
            height: buttonHeight
        )
        
        buttonContainer = NSView(frame: containerFrame)
        
        // 确认按钮
        confirmButton = createButton(title: "确认", width: buttonWidth)
        confirmButton?.target = self
        confirmButton?.action = #selector(handleConfirm)
        confirmButton?.keyEquivalent = "\\r" // Enter键
        
        // 编辑按钮
        editButton = createButton(title: "编辑", width: buttonWidth)
        editButton?.target = self
        editButton?.action = #selector(handleEdit)
        
        // 复制按钮
        copyButton = createButton(title: "复制", width: buttonWidth)
        copyButton?.target = self
        copyButton?.action = #selector(handleCopy)
        copyButton?.keyEquivalent = "c"
        copyButton?.keyEquivalentModifierMask = .command
        
        // 取消按钮
        cancelButton = createButton(title: "取消", width: buttonWidth)
        cancelButton?.target = self
        cancelButton?.action = #selector(handleCancel)
        cancelButton?.keyEquivalent = "\\u{1b}" // Escape键
        
        // 布局按钮
        let buttons = [confirmButton, editButton, copyButton, cancelButton].compactMap { $0 }
        let totalButtonsWidth = CGFloat(buttons.count) * buttonWidth + CGFloat(buttons.count - 1) * buttonSpacing
        let startX = (containerFrame.width - totalButtonsWidth) / 2
        
        for (index, button) in buttons.enumerated() {
            let buttonFrame = NSRect(
                x: startX + CGFloat(index) * (buttonWidth + buttonSpacing),
                y: 0,
                width: buttonWidth,
                height: buttonHeight
            )
            button.frame = buttonFrame
            buttonContainer?.addSubview(button)
        }
        
        if let buttonContainer = buttonContainer {
            contentView.addSubview(buttonContainer)
        }
        
        LogManager.shared.uiLog("按钮设置完成", details: [
            "buttonCount": buttons.count,
            "totalWidth": totalButtonsWidth
        ])
    }
    
    /// 设置底部状态栏
    private func setupStatsBar() {
        guard let contentView = contentView else { return }
        
        let statsFrame = NSRect(
            x: config.padding,
            y: 50, // 在按钮上方
            width: contentView.bounds.width - config.padding * 2,
            height: 20
        )
        
        statsLabel = NSTextField(frame: statsFrame)
        statsLabel?.isEditable = false
        statsLabel?.isSelectable = false
        statsLabel?.isBordered = false
        statsLabel?.drawsBackground = false
        statsLabel?.font = NSFont.systemFont(ofSize: 11)
        statsLabel?.textColor = .secondaryLabelColor
        statsLabel?.alignment = .center
        statsLabel?.stringValue = ""
        
        if let statsLabel = statsLabel {
            contentView.addSubview(statsLabel)
        }
        
        LogManager.shared.uiLog("状态栏设置完成", details: [
            "statsFrame": "\(statsFrame)"
        ])
    }
    
    /// 创建按钮
    private func createButton(title: String, width: CGFloat) -> NSButton {
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: width, height: 32))
        button.title = title
        button.bezelStyle = .rounded
        button.controlSize = .regular
        return button
    }
    
    /// 更新内容
    private func updateContent(for result: ResultType) {
        guard let textView = textView else { return }
        
        var content: String
        var statsText: String
        
        switch result {
        case .transcription(let transcriptionResult):
            content = formatTranscriptionResult(transcriptionResult)
            statsText = formatTranscriptionStats(transcriptionResult)
            
        case .optimization(let optimizationResult):
            content = formatOptimizationResult(optimizationResult)
            statsText = formatOptimizationStats(optimizationResult)
            
        case .modification(let original, let modified, let improvements):
            content = formatModificationResult(original: original, modified: modified, improvements: improvements)
            statsText = formatModificationStats(original: original, modified: modified)
            
        case .error(let message):
            content = "❌ 发生错误\n\n"
            content += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            content += "\(message)\n"
            content += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
            content += "💡 建议操作：\n"
            content += "• 检查网络连接\n"
            content += "• 确认API密钥有效\n"
            content += "• 重新尝试录音\n"
            content += "• 查看详细日志获取更多信息"
            statsText = "错误时间: \(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium))"
            
        case .loading(let message):
            content = "⏳ 正在处理\n\n"
            content += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            content += "\(message)\n"
            content += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
            content += "请耐心等待...\n\n"
            content += "💡 处理过程：\n"
            if message.contains("录音") {
                content += "🎤 正在捕获音频信号...\n"
            } else if message.contains("识别") || message.contains("转录") {
                content += "🔍 正在进行语音识别...\n"
            } else if message.contains("优化") {
                content += "✨ 正在优化提示词...\n"
            }
            statsText = "开始时间: \(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium))"
        }
        
        textView.string = content
        statsLabel?.stringValue = statsText
        
        // 滚动到顶部
        textView.scrollToBeginningOfDocument(nil)
        
        LogManager.shared.uiLog("更新内容完成", details: [
            "contentLength": content.count,
            "statsText": statsText,
            "resultType": "\(result)"
        ])
    }
    
    /// 格式化语音识别结果
    private func formatTranscriptionResult(_ result: TranscriptionResult) -> String {
        var content = "🎤 语音识别结果\n\n"
        
        // 突出显示识别的文本
        content += "📝 识别文本：\n"
        content += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        content += "\(result.text)\n"
        content += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        
        // 添加质量评估
        if !result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            content += "✅ 识别质量：良好\n"
        } else {
            content += "⚠️ 识别质量：可能需要重新录制\n"
        }
        
        if let language = result.language {
            content += "🌍 语言：\(language)\n"
        }
        
        if let confidence = result.confidence {
            let confidenceLevel = confidence >= 0.7 ? "高" : confidence >= 0.5 ? "中" : "低"
            content += "📊 置信度：\(String(format: "%.1f%%", confidence * 100)) (\(confidenceLevel))\n"
        }
        
        content += "⏱️ 处理时间：\(String(format: "%.2f秒", result.duration))\n"
        content += "📏 文本长度：\(result.text.count) 字符\n"
        
        if let segments = result.segments, !segments.isEmpty {
            content += "\n📋 语音片段详情：\n"
            for (index, segment) in segments.enumerated() {
                content += "\(index + 1). [\(String(format: "%.1f", segment.start))s-\(String(format: "%.1f", segment.end))s] \(segment.text)\n"
            }
        }
        
        return content
    }
    
    /// 格式化提示词优化结果
    private func formatOptimizationResult(_ result: PromptOptimizationResult) -> String {
        var content = "✨ 提示词优化结果\n\n"
        content += "📝 优化后的提示词：\n\(result.optimizedPrompt)\n\n"
        content += "📊 统计信息：\n"
        content += "• 原始长度：\(result.originalLength) 字符\n"
        content += "• 优化后长度：\(result.optimizedLength) 字符\n"
        content += "• 优化置信度：\(String(format: "%.2f%%", result.confidence * 100))\n"
        content += "• 应用场景：\(result.context)\n"
        
        if !result.improvements.isEmpty {
            content += "\n💡 主要改进：\n"
            for (index, improvement) in result.improvements.enumerated() {
                content += "\(index + 1). \(improvement)\n"
            }
        }
        
        return content
    }
    
    /// 格式化语音修改结果
    private func formatModificationResult(original: String, modified: String, improvements: [String]) -> String {
        var content = "🔄 语音修改结果\n\n"
        content += "📝 修改后的文本：\n\(modified)\n\n"
        content += "📋 原始文本：\n\(original)\n\n"
        
        if !improvements.isEmpty {
            content += "💡 修改说明：\n"
            for (index, improvement) in improvements.enumerated() {
                content += "\(index + 1). \(improvement)\n"
            }
        }
        
        return content
    }
    
    /// 格式化语音识别统计信息
    private func formatTranscriptionStats(_ result: TranscriptionResult) -> String {
        var stats: [String] = []
        
        stats.append("处理时间: \(String(format: "%.2f", result.duration))s")
        stats.append("字数: \(result.text.count)")
        
        if let confidence = result.confidence {
            stats.append("置信度: \(String(format: "%.1f", confidence * 100))%")
        }
        
        if let language = result.language {
            stats.append("语言: \(language)")
        }
        
        return stats.joined(separator: "   ")
    }
    
    /// 格式化提示词优化统计信息
    private func formatOptimizationStats(_ result: PromptOptimizationResult) -> String {
        var stats: [String] = []
        
        stats.append("优化字数: \(result.originalLength) → \(result.optimizedLength)")
        stats.append("置信度: \(String(format: "%.1f", result.confidence * 100))%")
        stats.append("改进项: \(result.improvements.count)")
        stats.append("场景: \(result.context)")
        
        return stats.joined(separator: "   ")
    }
    
    /// 格式化语音修改统计信息
    private func formatModificationStats(original: String, modified: String) -> String {
        var stats: [String] = []
        
        stats.append("修改字数: \(original.count) → \(modified.count)")
        
        let changePercent = original.count > 0 ? Float(abs(modified.count - original.count)) / Float(original.count) * 100 : 0
        stats.append("变化率: \(String(format: "%.1f", changePercent))%")
        
        return stats.joined(separator: "   ")
    }
    
    /// 更新按钮状态
    private func updateButtons(for result: ResultType) {
        switch result {
        case .transcription:
            confirmButton?.title = "插入文本"
            confirmButton?.isEnabled = true
            editButton?.isEnabled = true
            copyButton?.isEnabled = true
            
        case .optimization:
            confirmButton?.title = "使用优化"
            confirmButton?.isEnabled = true
            editButton?.isEnabled = true
            copyButton?.isEnabled = true
            
        case .modification:
            confirmButton?.title = "使用修改"
            confirmButton?.isEnabled = true
            editButton?.isEnabled = true
            copyButton?.isEnabled = true
            
        case .error:
            confirmButton?.title = "重试"
            confirmButton?.isEnabled = true
            editButton?.isEnabled = false
            copyButton?.isEnabled = true
            
        case .loading:
            confirmButton?.title = "确认"
            confirmButton?.isEnabled = false
            editButton?.isEnabled = false
            copyButton?.isEnabled = false
        }
        
        LogManager.shared.uiLog("按钮状态更新", details: [
            "confirmTitle": confirmButton?.title ?? "",
            "confirmEnabled": confirmButton?.isEnabled ?? false
        ])
    }
    
    /// 更新位置
    private func updatePosition(_ position: CGPoint) {
        guard let window = window, let contentView = contentView else { return }
        
        let newFrame = NSRect(
            x: position.x - config.maxWidth / 2,
            y: position.y - config.maxHeight / 2,
            width: config.maxWidth,
            height: config.maxHeight
        )
        
        // 确保窗口在屏幕范围内
        let screenFrame = NSScreen.main?.frame ?? NSRect.zero
        let _ = NSRect(
            x: max(0, min(newFrame.origin.x, screenFrame.width - newFrame.width)),
            y: max(0, min(newFrame.origin.y, screenFrame.height - newFrame.height)),
            width: newFrame.width,
            height: newFrame.height
        )
        
        contentView.frame = NSRect(
            x: (window.frame.width - config.maxWidth) / 2,
            y: (window.frame.height - config.maxHeight) / 2,
            width: config.maxWidth,
            height: config.maxHeight
        )
    }
    
    /// 居中窗口
    private func centerWindow() {
        guard let window = window, let contentView = contentView else { return }
        
        contentView.frame = NSRect(
            x: (window.frame.width - config.maxWidth) / 2,
            y: (window.frame.height - config.maxHeight) / 2,
            width: config.maxWidth,
            height: config.maxHeight
        )
    }
    
    /// 安排自动隐藏
    private func scheduleAutoHide() {
        cancelAutoHide()
        
        // 只有非加载状态才自动隐藏
        if case .loading = currentResult {
            return
        }
        
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: config.autoHideDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.hide()
            }
        }
    }
    
    /// 取消自动隐藏
    private func cancelAutoHide() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
    }
    
    // MARK: - Animations
    
    private func animateShow() {
        backgroundView?.alphaValue = 0.0
        contentView?.layer?.transform = CATransform3DMakeScale(0.8, 0.8, 1.0)
        contentView?.alphaValue = 0.0
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = config.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            backgroundView?.animator().alphaValue = 1.0
            contentView?.animator().alphaValue = 1.0
            contentView?.animator().layer?.transform = CATransform3DIdentity
        }
    }
    
    private func animateHide(completion: @escaping () -> Void) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = config.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            backgroundView?.animator().alphaValue = 0.0
            contentView?.animator().alphaValue = 0.0
            contentView?.animator().layer?.transform = CATransform3DMakeScale(0.8, 0.8, 1.0)
        }, completionHandler: completion)
    }
    
    // MARK: - Event Handlers
    
    @objc private func handleBackgroundClick(_ gesture: NSClickGestureRecognizer) {
        // 点击内容区域外关闭
        let clickPoint = gesture.location(in: backgroundView)
        
        if let contentView = contentView, !contentView.frame.contains(clickPoint) {
            hide()
        }
    }
    
    @objc private func handleConfirm() {
        guard let result = currentResult else { return }
        
        LogManager.shared.uiLog("确认按钮点击", details: ["resultType": "\(result)"])
        delegate?.resultOverlay(self, didClickConfirm: result)
    }
    
    @objc private func handleEdit() {
        guard let result = currentResult else { return }
        
        LogManager.shared.uiLog("编辑按钮点击", details: ["resultType": "\(result)"])
        delegate?.resultOverlay(self, didClickEdit: result)
    }
    
    @objc private func handleCopy() {
        guard let result = currentResult else { return }
        
        let textToCopy: String
        
        switch result {
        case .transcription(let transcriptionResult):
            textToCopy = transcriptionResult.text
        case .optimization(let optimizationResult):
            textToCopy = optimizationResult.optimizedPrompt
        case .modification(_, let modified, _):
            textToCopy = modified
        case .error(let message):
            textToCopy = message
        case .loading(let message):
            textToCopy = message
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(textToCopy, forType: .string)
        
        LogManager.shared.uiLog("复制按钮点击", details: [
            "textLength": textToCopy.count,
            "resultType": "\(result)"
        ])
        
        delegate?.resultOverlay(self, didClickCopy: result)
    }
    
    @objc private func handleCancel() {
        guard let result = currentResult else { return }
        
        LogManager.shared.uiLog("取消按钮点击", details: ["resultType": "\(result)"])
        delegate?.resultOverlay(self, didClickCancel: result)
        hide()
    }
    
    // MARK: - Cleanup
    
    private func cleanup() {
        cancelAutoHide()
        window?.close()
        window = nil
        
        LogManager.shared.uiLog("ResultOverlay资源清理完成")
    }
    
    /// 同步清理方法，用于deinit
    nonisolated private func cleanupSync() {
        Task { @MainActor in
            cancelAutoHide()
            window?.close()
            window = nil
            
            LogManager.shared.uiLog("ResultOverlay资源清理完成（同步）")
        }
    }
}