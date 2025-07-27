//
//  RealAppManager.swift
//  HelloPrompt
//
//  完整应用管理器 - 协调所有服务模块，处理完整业务逻辑流程
//  Copyright © 2025 HelloPrompt. All rights reserved.
//

import Foundation
import AppKit

// MARK: - 应用状态
enum AppState: Equatable {
    case initializing
    case idle
    case listening
    case recording
    case processing
    case presenting
    case inserting
    case modifying(originalText: String)  // 语音修改状态
    case error(Error)
    
    static func == (lhs: AppState, rhs: AppState) -> Bool {
        switch (lhs, rhs) {
        case (.initializing, .initializing),
             (.idle, .idle),
             (.listening, .listening),
             (.recording, .recording),
             (.processing, .processing),
             (.presenting, .presenting),
             (.inserting, .inserting):
            return true
        case (.modifying, .modifying):
            return true // 简化处理，只比较状态类型
        case (.error, .error):
            return true // 简化处理，只比较状态类型
        default:
            return false
        }
    }
}

// MARK: - 完整应用管理器
@MainActor
class RealAppManager: NSObject {
    
    // MARK: - Services
    private let audioService: AudioService
    private let openAIService: OpenAIService
    private let floatingBall: FloatingBall
    private let resultOverlay: ResultOverlay
    private let modernGlobalShortcuts: ModernGlobalShortcuts
    private let textInsertion: TextInsertion
    private let errorHandler: ErrorHandler
    
    // MARK: - Configuration
    private let configurationManager: ConfigurationManager
    
    // MARK: - State
    private var currentState: AppState = .initializing {
        didSet {
            LogManager.shared.info(.app, "应用状态变更", metadata: [
                "from": "\(oldValue)",
                "to": "\(currentState)"
            ])
            updateUIForState()
        }
    }
    
    private var currentAudioData: AudioData?
    private var currentTranscription: TranscriptionResult?
    private var currentOptimization: PromptOptimizationResult?
    
    // MARK: - Initialization
    override init() {
        LogManager.shared.info(.app, "开始RealAppManager基础初始化")
        
        // 初始化配置管理器（轻量级，不会阻塞）
        self.configurationManager = ConfigurationManager.shared
        LogManager.shared.info(.app, "✅ ConfigurationManager初始化完成")
        
        // 创建服务实例（延迟完整初始化）
        self.audioService = AudioService()
        LogManager.shared.info(.app, "✅ AudioService基础初始化完成")
        
        self.openAIService = OpenAIService(configurationManager: configurationManager)
        LogManager.shared.info(.app, "✅ OpenAIService基础初始化完成")
        
        self.floatingBall = FloatingBall()
        LogManager.shared.info(.app, "✅ FloatingBall基础初始化完成")
        
        self.resultOverlay = ResultOverlay()
        LogManager.shared.info(.app, "✅ ResultOverlay基础初始化完成")
        
        self.modernGlobalShortcuts = ModernGlobalShortcuts()
        LogManager.shared.info(.app, "✅ ModernGlobalShortcuts基础初始化完成")
        
        self.textInsertion = TextInsertion()
        LogManager.shared.info(.app, "✅ TextInsertion基础初始化完成")
        
        self.errorHandler = ErrorHandler.shared
        LogManager.shared.info(.app, "✅ ErrorHandler引用获取完成")
        
        super.init()
        
        LogManager.shared.info(.app, "✅ RealAppManager基础初始化完成，开始异步初始化")
        
        // 不在init中直接启动异步初始化，等待外部调用
    }
    
    /// 异步完成初始化（非阻塞）
    private func completeInitializationAsync() async {
        LogManager.shared.info(.app, "开始异步初始化流程")
        
        // 分步骤异步初始化
        LogManager.shared.info(.app, "📋 设置代理关系")
        setupDelegates()
        LogManager.shared.info(.app, "✅ 代理关系设置完成")
        
        LogManager.shared.info(.app, "📋 设置错误处理")
        setupErrorHandling()
        LogManager.shared.info(.app, "✅ 错误处理设置完成")
        
        LogManager.shared.info(.app, "📋 初始化UI组件")
        setupUI()
        LogManager.shared.info(.app, "✅ UI组件初始化完成")
        
        LogManager.shared.info(.app, "📋 配置快捷键")
        setupShortcuts()
        LogManager.shared.info(.app, "✅ 快捷键配置完成")
        
        // 设置状态为空闲
        currentState = .idle
        
        LogManager.shared.info(.app, "🎉 RealAppManager异步初始化完成")
    }
    
    deinit {
        // 在Swift 6.0中，@MainActor类的deinit不能直接调用其他@MainActor方法
        cleanupSync()
    }
    
    // MARK: - Public Methods
    
    /// 启动应用
    func start() {
        LogManager.shared.startFlow("应用启动")
        
        // 显示悬浮球
        floatingBall.show()
        
        // 启用现代化全局快捷键
        modernGlobalShortcuts.enable()
        
        currentState = .idle
        
        LogManager.shared.endFlow("应用启动", success: true)
    }
    
    /// 异步启动应用
    func startAsync() async {
        LogManager.shared.startFlow("异步应用启动")
        
        // 首先完成异步初始化
        LogManager.shared.info(.app, "🔧 完成异步初始化")
        await completeInitializationAsync()
        
        // 异步显示悬浮球
        LogManager.shared.info(.app, "🎈 显示悬浮球")
        await MainActor.run {
            floatingBall.show()
            LogManager.shared.info(.app, "✅ 悬浮球显示完成")
        }
        
        // 让出控制权
        await Task.yield()
        
        // 异步启用现代化全局快捷键
        LogManager.shared.info(.app, "⌨️ 启用全局快捷键")
        await MainActor.run {
            modernGlobalShortcuts.enable()
            if modernGlobalShortcuts.isEnabledStatus {
                LogManager.shared.info(.app, "✅ 现代化全局快捷键启用成功")
            } else {
                LogManager.shared.warning(.app, "⚠️ 现代化全局快捷键启用失败，可能缺少权限")
            }
        }
        
        // 让出控制权
        await Task.yield()
        
        // 等待一小段时间确保所有初始化完成
        LogManager.shared.info(.app, "⏳ 等待所有组件初始化完成")
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        await MainActor.run {
            currentState = .idle
            LogManager.shared.info(.app, "🎯 应用状态设置为空闲")
            LogManager.shared.endFlow("异步应用启动", success: true)
        }
    }
    
    /// 开始录音
    func startRecording() {
        guard currentState == .idle || currentState == .listening else {
            LogManager.shared.warning(.app, "无效的录音请求", metadata: ["currentState": "\(currentState)"])
            return
        }
        
        LogManager.shared.startFlow("录音流程")
        
        currentState = .recording
        audioService.startRecording()
    }
    
    /// 停止录音
    func stopRecording() {
        guard currentState == .recording else {
            LogManager.shared.warning(.app, "当前未在录音")
            return
        }
        
        audioService.stopRecording()
    }
    
    /// 取消当前操作
    func cancelCurrentOperation() {
        switch currentState {
        case .recording:
            audioService.cancelRecording()
        case .processing:
            openAIService.cancelAllRequests()
        case .presenting:
            resultOverlay.hide()
        default:
            break
        }
        
        currentState = .idle
        LogManager.shared.info(.app, "取消当前操作")
    }
    
    /// 显示设置
    func showSettings() {
        LogManager.shared.info(.app, "显示设置面板")
        SettingsWindowManager.shared.showSettings()
    }
    
    /// 切换悬浮球显示
    func toggleFloatingBall() {
        // 实现悬浮球显示切换逻辑
        LogManager.shared.info(.app, "切换悬浮球显示")
    }
    
    /// 更新OpenAI配置
    func updateOpenAIConfig() {
        let config = OpenAIConfig.fromConfiguration(configurationManager.configuration)
        openAIService.updateConfig(config)
        
        LogManager.shared.info(.app, "更新OpenAI配置", metadata: [
            "model": config.gptModel,
            "temperature": config.temperature,
            "hasAPIKey": !config.apiKey.isEmpty
        ])
    }
    
    /// 检查配置是否有效
    var isConfigurationValid: Bool {
        return configurationManager.isValidConfiguration
    }
    
    /// 是否需要初始设置
    var needsInitialSetup: Bool {
        return configurationManager.needsInitialSetup
    }
    
    // MARK: - Private Methods
    
    /// 设置代理
    private func setupDelegates() {
        audioService.delegate = self
        openAIService.delegate = self
        floatingBall.delegate = self
        resultOverlay.delegate = self
        modernGlobalShortcuts.delegate = self
        textInsertion.delegate = self
        errorHandler.delegate = self
        
        LogManager.shared.info(.app, "代理设置完成")
    }
    
    /// 设置UI
    private func setupUI() {
        // 悬浮球初始状态
        floatingBall.updateState(.idle)
        
        LogManager.shared.info(.app, "UI设置完成")
    }
    
    /// 设置快捷键
    private func setupShortcuts() {
        // 现代化快捷键不需要预注册，在enable时自动设置
        LogManager.shared.info(.app, "现代化快捷键配置完成")
    }
    
    /// 根据状态更新UI
    private func updateUIForState() {
        switch currentState {
        case .initializing:
            floatingBall.updateState(.hidden)
            
        case .idle:
            floatingBall.updateState(.idle)
            
        case .listening:
            floatingBall.updateState(.listening)
            
        case .recording:
            floatingBall.updateState(.recording)
            
        case .processing:
            floatingBall.updateState(.processing)
            
        case .presenting:
            floatingBall.updateState(.idle)
            
        case .inserting:
            floatingBall.updateState(.processing)
            
        case .modifying:
            floatingBall.updateState(.recording)  // 修改时显示录音状态
            
        case .error:
            floatingBall.updateState(.error)
            
            // 短暂显示错误状态后回到空闲
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                if case .error = self?.currentState {
                    self?.currentState = .idle
                }
            }
        }
    }
    
    /// 处理转录完成
    private func handleTranscriptionComplete(_ result: TranscriptionResult) {
        currentTranscription = result
        
        // 显示转录结果
        let resultType = ResultType.transcription(result)
        resultOverlay.show(result: resultType)
        
        currentState = .presenting
        
        LogManager.shared.stepFlow("录音流程", step: "转录完成，显示结果")
        LogManager.shared.endFlow("录音流程", success: true, context: [
            "transcriptionLength": result.text.count,
            "confidence": result.confidence ?? 0,
            "hasValidText": !result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            "language": result.language ?? "unknown",
            "duration": result.duration
        ])
    }
    
    /// 处理优化完成
    private func handleOptimizationComplete(_ result: PromptOptimizationResult) {
        currentOptimization = result
        
        // 显示优化结果
        let resultType = ResultType.optimization(result)
        resultOverlay.show(result: resultType)
        
        currentState = .presenting
        
        LogManager.shared.stepFlow("优化流程", step: "优化完成，显示结果")
    }
    
    /// 执行文本插入
    private func performTextInsertion(_ text: String) {
        LogManager.shared.startFlow("文本插入")
        
        currentState = .inserting
        
        Task {
            await textInsertion.insertText(text)
        }
    }
    
    /// 开始语音修改流程
    private func startVoiceModification(originalText: String) {
        LogManager.shared.startFlow("语音修改")
        LogManager.shared.info(.app, "开始语音修改", metadata: [
            "originalLength": originalText.count
        ])
        
        // 隐藏当前的结果显示
        resultOverlay.hide()
        
        // 进入修改状态
        currentState = .modifying(originalText: originalText)
        
        // 显示修改提示
        let modificationHint = "🎤 请说出修改要求\n\n原文：\(originalText)\n\n说出您希望如何修改这段文字，比如：\n• \"改成更正式的语气\"\n• \"增加技术细节\"\n• \"删除不必要的部分\"\n• \"重新组织语言\""
        
        let loadingResult = ResultType.loading(modificationHint)
        resultOverlay.show(result: loadingResult)
        
        // 开始录音等待修改指令
        startModificationRecording(originalText: originalText)
    }
    
    /// 开始修改录音
    private func startModificationRecording(originalText: String) {
        LogManager.shared.stepFlow("语音修改", step: "开始录音修改指令")
        
        Task {
            audioService.startRecording()
        }
    }
    
    /// 处理修改录音完成
    private func handleModificationRecordingComplete(_ audioData: AudioData, originalText: String) {
        LogManager.shared.stepFlow("语音修改", step: "修改录音完成，开始识别修改指令")
        
        // 显示处理中状态
        let processingResult = ResultType.loading("正在识别修改指令...")
        resultOverlay.show(result: processingResult)
        
        Task {
            await openAIService.transcribeAudio(audioData)
        }
    }
    
    /// 处理修改指令识别完成
    private func handleModificationInstructionComplete(_ instruction: String, originalText: String) {
        LogManager.shared.stepFlow("语音修改", step: "修改指令识别完成，开始生成修改结果")
        
        // 显示处理中状态
        let processingResult = ResultType.loading("正在生成修改结果...")
        resultOverlay.show(result: processingResult)
        
        // 调用GPT-4进行修改
        Task {
            await performTextModification(originalText: originalText, instruction: instruction)
        }
    }
    
    /// 执行文本修改
    private func performTextModification(originalText: String, instruction: String) async {
        let modificationPrompt = """
        请根据用户的修改要求，对原始文本进行修改。

        原始文本：
        \(originalText)

        修改要求：
        \(instruction)

        请返回JSON格式的结果：
        {
          "modified_text": "修改后的文本",
          "improvements": ["修改说明1", "修改说明2", "..."]
        }
        """
        
        // 使用OpenAI服务进行修改
        // 这里需要创建一个专门的修改方法
        await openAIService.optimizePrompt(modificationPrompt, context: "modification")
    }
    
    /// 处理修改完成
    private func handleModificationComplete(originalText: String, modifiedText: String, improvements: [String]) {
        LogManager.shared.stepFlow("语音修改", step: "修改完成，显示结果")
        
        // 显示修改结果
        let modificationResult = ResultType.modification(
            original: originalText,
            modified: modifiedText,
            improvements: improvements
        )
        resultOverlay.show(result: modificationResult)
        
        currentState = .presenting
        
        LogManager.shared.endFlow("语音修改", success: true, context: [
            "originalLength": originalText.count,
            "modifiedLength": modifiedText.count,
            "improvementsCount": improvements.count
        ])
    }
    
    /// 解析修改结果
    private func parseModificationResult(result: PromptOptimizationResult, originalText: String) {
        LogManager.shared.stepFlow("语音修改", step: "解析修改结果")
        
        // 尝试解析JSON格式的修改结果
        let modifiedText: String
        let improvements: [String]
        
        do {
            if let jsonData = result.optimizedPrompt.data(using: .utf8),
               let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                modifiedText = json["modified_text"] as? String ?? result.optimizedPrompt
                improvements = json["improvements"] as? [String] ?? []
            } else {
                // 如果不是JSON格式，直接使用优化结果
                modifiedText = result.optimizedPrompt
                improvements = result.improvements
            }
            
            handleModificationComplete(
                originalText: originalText,
                modifiedText: modifiedText,
                improvements: improvements
            )
            
        } catch {
            LogManager.shared.warning(.app, "修改结果解析失败，使用原始结果", metadata: [
                "error": error.localizedDescription
            ])
            
            // 解析失败时使用原始结果
            handleModificationComplete(
                originalText: originalText,
                modifiedText: result.optimizedPrompt,
                improvements: result.improvements
            )
        }
    }
    
    /// 设置错误处理
    private func setupErrorHandling() {
        errorHandler.delegate = self
        LogManager.shared.info(.app, "错误处理设置完成")
    }
    
    /// 清理资源
    private func cleanup() {
        modernGlobalShortcuts.disable()
        audioService.cancelRecording()
        openAIService.cancelAllRequests()
        floatingBall.hide()
        resultOverlay.hide()
        
        LogManager.shared.info(.app, "RealAppManager资源清理完成")
    }
    
    /// 同步清理方法，用于deinit
    nonisolated private func cleanupSync() {
        Task { @MainActor in
            modernGlobalShortcuts.disable()
            audioService.cancelRecording()
            openAIService.cancelAllRequests()
            floatingBall.hide()
            resultOverlay.hide()
            
            LogManager.shared.info(.app, "RealAppManager资源清理完成（同步）")
        }
    }
}

// MARK: - AudioService Delegate
extension RealAppManager: AudioServiceDelegate {
    
    func audioService(_ service: AudioService, didChangeState state: AudioRecordingState) {
        switch state {
        case .idle:
            if currentState == .recording {
                currentState = .idle
            }
            
        case .preparing:
            currentState = .listening
            
        case .recording:
            currentState = .recording
            
        case .processing:
            currentState = .processing
            
        case .completed:
            // 等待音频数据回调
            break
            
        case .error(let error):
            LogManager.shared.trackError(error, context: "音频录制")
            currentState = .error(error)
        }
    }
    
    func audioService(_ service: AudioService, didDetectVoiceActivity active: Bool) {
        LogManager.shared.audioLog("VAD检测", details: ["active": active])
    }
    
    func audioService(_ service: AudioService, didUpdateLevel rms: Float, peak: Float) {
        floatingBall.updateLevel(rms)
    }
    
    func audioService(_ service: AudioService, didCompleteRecording audioData: AudioData) {
        self.currentAudioData = audioData
        
        LogManager.shared.stepFlow("录音流程", step: "录音完成", context: [
            "duration": audioData.duration,
            "dataSize": audioData.data.count,
            "hasVoiceActivity": audioData.hasVoiceActivity,
            "rmsLevel": audioData.rmsLevel
        ])
        
        // 根据当前状态决定处理方式
        switch currentState {
        case .modifying(let originalText):
            // 修改模式：录音完成后开始识别修改指令
            handleModificationRecordingComplete(audioData, originalText: originalText)
            
        default:
            // 普通录音模式：显示处理状态并开始转录
            resultOverlay.show(result: .loading("录音完成！正在进行语音识别，请稍候..."))
            currentState = .processing
            
            // 开始转录
            Task {
                await openAIService.transcribeAudio(audioData)
            }
        }
    }
    
    func audioService(_ service: AudioService, didFailWithError error: Error) {
        LogManager.shared.trackError(error, context: "音频服务")
        errorHandler.handleAudioError(error)
        currentState = .error(error)
    }
}

// MARK: - OpenAIService Delegate
extension RealAppManager: OpenAIServiceDelegate {
    
    func openAIService(_ service: OpenAIService, didStartTranscription requestId: String) {
        resultOverlay.show(result: .loading("正在识别语音..."))
        LogManager.shared.stepFlow("录音流程", step: "开始语音识别")
    }
    
    func openAIService(_ service: OpenAIService, didCompleteTranscription result: TranscriptionResult, requestId: String) {
        // 根据当前状态决定处理方式
        switch currentState {
        case .modifying(let originalText):
            // 修改模式：识别完修改指令后执行修改
            handleModificationInstructionComplete(result.text, originalText: originalText)
            
        default:
            // 普通转录模式
            handleTranscriptionComplete(result)
            LogManager.shared.endFlow("录音流程", success: true)
        }
    }
    
    func openAIService(_ service: OpenAIService, didStartOptimization requestId: String) {
        resultOverlay.show(result: .loading("正在优化提示词..."))
        LogManager.shared.stepFlow("优化流程", step: "开始提示词优化")
    }
    
    func openAIService(_ service: OpenAIService, didCompleteOptimization result: PromptOptimizationResult, requestId: String) {
        // 根据当前状态决定处理方式
        switch currentState {
        case .modifying(let originalText):
            // 修改模式：解析修改结果
            parseModificationResult(result: result, originalText: originalText)
            
        default:
            // 普通优化模式
            handleOptimizationComplete(result)
            LogManager.shared.endFlow("优化流程", success: true)
        }
    }
    
    func openAIService(_ service: OpenAIService, didFailWithError error: Error, requestId: String) {
        LogManager.shared.trackError(error, context: "OpenAI API")
        errorHandler.handleNetworkError(error)
        
        let errorMessage = error.localizedDescription
        resultOverlay.show(result: .error(errorMessage))
        
        currentState = .error(error)
    }
}

// MARK: - FloatingBall Delegate
extension RealAppManager: FloatingBallDelegate {
    
    func floatingBallDidClick(_ floatingBall: FloatingBall) {
        switch currentState {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        default:
            LogManager.shared.debug(.app, "悬浮球点击被忽略", metadata: ["state": "\(currentState)"])
        }
    }
    
    func floatingBallDidDoubleClick(_ floatingBall: FloatingBall) {
        // 双击显示设置
        showSettings()
    }
    
    func floatingBallDidRightClick(_ floatingBall: FloatingBall) {
        // 右键取消当前操作
        cancelCurrentOperation()
    }
    
    func floatingBallDidDragToPosition(_ floatingBall: FloatingBall, position: CGPoint) {
        LogManager.shared.uiLog("悬浮球拖拽", details: [
            "position": "\(position)"
        ])
    }
}

// MARK: - ResultOverlay Delegate
extension RealAppManager: ResultOverlayDelegate {
    
    func resultOverlay(_ overlay: ResultOverlay, didClickConfirm result: ResultType) {
        switch result {
        case .transcription(let transcriptionResult):
            performTextInsertion(transcriptionResult.text)
            
        case .optimization(let optimizationResult):
            performTextInsertion(optimizationResult.optimizedPrompt)
            
        case .modification(_, let modified, _):
            performTextInsertion(modified)
            
        case .error:
            // 重试逻辑
            if let audioData = currentAudioData {
                Task {
                    await openAIService.transcribeAudio(audioData)
                }
            }
            
        case .loading:
            break
        }
        
        overlay.hide()
    }
    
    func resultOverlay(_ overlay: ResultOverlay, didClickEdit result: ResultType) {
        switch result {
        case .transcription(let transcriptionResult):
            // 开始语音修改流程
            startVoiceModification(originalText: transcriptionResult.text)
            
        case .optimization(let optimizationResult):
            // 对优化结果进行修改
            startVoiceModification(originalText: optimizationResult.optimizedPrompt)
            
        case .modification(_, let modified, _):
            // 对修改结果再次修改
            startVoiceModification(originalText: modified)
            
        default:
            LogManager.shared.warning(.app, "该结果类型不支持编辑功能")
        }
    }
    
    func resultOverlay(_ overlay: ResultOverlay, didClickCopy result: ResultType) {
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
        
        // 复制到剪贴板
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(textToCopy, forType: .string)
        
        LogManager.shared.info(.app, "文本已复制到剪贴板", metadata: [
            "textLength": textToCopy.count
        ])
    }
    
    func resultOverlay(_ overlay: ResultOverlay, didClickCancel result: ResultType) {
        overlay.hide()
        currentState = .idle
    }
    
    func resultOverlayDidDismiss(_ overlay: ResultOverlay) {
        if currentState == .presenting {
            currentState = .idle
        }
    }
}

// MARK: - ModernGlobalShortcuts Delegate
extension RealAppManager: ModernGlobalShortcutsDelegate {
    
    func modernGlobalShortcuts(_ shortcuts: ModernGlobalShortcuts, didTrigger shortcutId: String) {
        LogManager.shared.info(.app, "现代化快捷键触发", metadata: ["shortcutId": shortcutId])
        
        switch shortcutId {
        case "start_recording":
            if currentState == .idle {
                startRecording()
            } else if currentState == .recording {
                stopRecording()
            }
            
        case "show_settings":
            showSettings()
            
        case "toggle_floating_ball":
            toggleFloatingBall()
            
        case "quick_optimize":
            // 快速优化剪贴板文本
            let pasteboard = NSPasteboard.general
            if let text = pasteboard.string(forType: .string), !text.isEmpty {
                Task {
                    await openAIService.optimizePrompt(text, context: "general")
                }
            }
            
        default:
            LogManager.shared.warning(.app, "未知现代化快捷键", metadata: ["shortcutId": shortcutId])
        }
    }
    
    func modernGlobalShortcuts(_ shortcuts: ModernGlobalShortcuts, didFailToSetup error: Error) {
        LogManager.shared.trackError(error, context: "现代化快捷键设置失败")
        errorHandler.handlePermissionError(error, context: "快捷键设置")
    }
}

// MARK: - TextInsertion Delegate
extension RealAppManager: TextInsertionDelegate {
    
    func textInsertion(_ service: TextInsertion, willInsertText text: String, to app: AppInfo) {
        LogManager.shared.stepFlow("文本插入", step: "准备插入到 \(app.name)")
    }
    
    func textInsertion(_ service: TextInsertion, didCompleteInsertion result: InsertionResult) {
        if result.success {
            LogManager.shared.endFlow("文本插入", success: true, context: [
                "targetApp": result.targetApp.name,
                "textLength": result.insertedText.count,
                "duration": result.duration
            ])
            
            // 显示成功状态
            floatingBall.updateState(.success)
            
        } else {
            LogManager.shared.endFlow("文本插入", success: false, context: [
                "error": result.error?.localizedDescription ?? "未知错误"
            ])
            
            if let error = result.error {
                currentState = .error(error)
            }
        }
        
        // 短暂延迟后回到空闲状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.currentState = .idle
        }
    }
    
    func textInsertion(_ service: TextInsertion, didFailWithError error: Error) {
        LogManager.shared.trackError(error, context: "文本插入")
        errorHandler.handlePermissionError(error, context: "文本插入")
        currentState = .error(error)
    }
}

// MARK: - ErrorHandler Delegate
extension RealAppManager: ErrorHandlerDelegate {
    
    func errorHandler(_ handler: ErrorHandler, shouldRetry error: AppError) -> Bool {
        LogManager.shared.info(.app, "错误处理器请求重试", metadata: [
            "error": error.localizedDescription
        ])
        
        // 根据错误类型决定是否重试
        switch error {
        case .networkConnectionFailed:
            // 网络错误可以重试
            return true
        case .audioRecordingFailed:
            // 音频录制错误可以重试
            return currentState != .recording
        case .speechRecognitionFailed:
            // 语音识别错误可以重试
            return currentAudioData != nil
        default:
            return false
        }
    }
    
    func errorHandler(_ handler: ErrorHandler, didRecover error: AppError) {
        LogManager.shared.info(.app, "错误自动恢复成功", metadata: [
            "error": error.localizedDescription
        ])
        
        // 恢复操作
        switch error {
        case .networkConnectionFailed, .speechRecognitionFailed:
            // 重新进行语音识别
            if let audioData = currentAudioData {
                Task {
                    await openAIService.transcribeAudio(audioData)
                }
            }
        case .audioRecordingFailed:
            // 重新开始录音
            if currentState == .idle {
                startRecording()
            }
        default:
            break
        }
        
        currentState = .idle
    }
    
    func errorHandler(_ handler: ErrorHandler, failedToRecover error: AppError) {
        LogManager.shared.warning(.app, "错误自动恢复失败", metadata: [
            "error": error.localizedDescription
        ])
        
        currentState = .error(error)
    }
}