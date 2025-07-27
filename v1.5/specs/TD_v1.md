# Hello Prompt - 技术设计文档 V1.0
**版本：V1.0**  
**日期：2025-07-25**  
**设计原则：简单、鲁棒、高质量音频处理**

## 1. 系统架构设计

### 1.1 简化三层架构
```
┌─────────────────────────────────────────────────────────────┐
│                    UI Layer                                 │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│  │FloatingBall │ │ResultOverlay│ │SettingsView │           │
│  │   (录音)     │ │   (结果)     │ │   (配置)     │           │
│  └─────────────┘ └─────────────┘ └─────────────┘           │
└─────────────────────────────────────────────────────────────┘
                            │ SwiftUI Bindings
┌─────────────────────────────────────────────────────────────┐
│                 Service Layer                               │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│  │AudioService │ │ OpenAIService│ │ AppManager  │           │
│  │  (录音+VAD)  │ │(Whisper+GPT)│ │  (状态管理)  │           │
│  └─────────────┘ └─────────────┘ └─────────────┘           │
└─────────────────────────────────────────────────────────────┘
                            │ System APIs
┌─────────────────────────────────────────────────────────────┐
│                Foundation Layer                             │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│  │AVFoundation │ │   Keychain  │ │  Hotkey API │           │
│  │  (音频框架)  │ │  (安全存储)  │ │  (全局快捷键) │           │
│  └─────────────┘ └─────────────┘ └─────────────┘           │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 技术栈选择

#### 1.2.1 核心技术栈
- **语言**：Swift 5.10+ (Xcode 15.0+)
- **UI框架**：SwiftUI (主界面) + AppKit (系统集成)
- **音频处理**：AVFoundation + AudioKit (专业音频处理)
- **网络层**：Foundation URLSession (简单可靠)
- **状态管理**：Combine + ObservableObject
- **依赖管理**：Swift Package Manager

#### 1.2.2 关键依赖
```swift
// Package.swift
let package = Package(
    name: "HelloPrompt",
    platforms: [.macOS(.v12)],
    dependencies: [
        // 音频处理增强
        .package(url: "https://github.com/AudioKit/AudioKit.git", from: "5.6.0"),
        
        // 键盘快捷键
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "1.14.0"),
        
        // 安全配置存储
        .package(url: "https://github.com/sindresorhus/Defaults.git", from: "7.1.0"),
        
        // OpenAI API客户端
        .package(url: "https://github.com/MacPaw/OpenAI.git", from: "0.2.4")
    ]
)
```

## 2. 核心模块设计

### 2.1 音频服务模块 (AudioService)

#### 2.1.1 音频最佳实践设计
```swift
import AVFoundation
import AudioKit
import Combine

@MainActor
class AudioService: ObservableObject {
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published var recordingDuration: TimeInterval = 0.0
    
    // MARK: - Private Properties
    private let audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    private var audioFile: AVAudioFile?
    private var recordingTimer: Timer?
    private var silenceTimer: Timer?
    
    // 音频配置 - 针对语音识别优化
    private let audioFormat = AVAudioFormat(
        standardFormatWithSampleRate: 16000,  // OpenAI Whisper优化采样率
        channels: 1                           // 单声道减少数据量
    )!
    
    // VAD (Voice Activity Detection) 配置
    private let silenceThreshold: Float = 0.01    // 静音阈值
    private let silenceTimeout: TimeInterval = 0.5  // 500ms静音后停止
    private let maxRecordingTime: TimeInterval = 500.0 // 最大录音500秒
    
    // MARK: - 音频权限管理
    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    // MARK: - 录音控制
    func startRecording() async throws {
        guard await requestMicrophonePermission() else {
            throw AudioError.microphonePermissionDenied
        }
        
        try await setupAudioSession()
        try setupAudioEngine()
        
        isRecording = true
        startRecordingTimer()
        
        LogManager.shared.info("AudioService", "开始录音 - 采样率: \(audioFormat.sampleRate)Hz")
    }
    
    func stopRecording() async -> Data? {
        guard isRecording else { return nil }
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recordingTimer?.invalidate()
        silenceTimer?.invalidate()
        isRecording = false
        recordingDuration = 0.0
        
        LogManager.shared.info("AudioService", "录音结束 - 时长: \(recordingDuration)秒")
        
        return await convertToAPIFormat()
    }
    
    // MARK: - 音频引擎配置
    private func setupAudioSession() async throws {
        let audioSession = AVAudioSession.sharedInstance()
        
        try audioSession.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.duckOthers, .defaultToSpeaker]
        )
        
        // 优化录音质量
        try audioSession.setPreferredSampleRate(16000.0)
        try audioSession.setPreferredIOBufferDuration(0.02) // 20ms缓冲
        
        try audioSession.setActive(true)
    }
    
    private func setupAudioEngine() throws {
        let inputNode = audioEngine.inputNode
        self.inputNode = inputNode
        
        // 创建临时音频文件
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("recording_\(UUID().uuidString).wav")
        
        audioFile = try AVAudioFile(
            forWriting: tempURL,
            settings: audioFormat.settings
        )
        
        // 安装录音tap - 处理音频数据
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: audioFormat) { [weak self] buffer, _ in
            Task { @MainActor in
                self?.processAudioBuffer(buffer)
            }
        }
        
        try audioEngine.start()
    }
    
    // MARK: - 音频处理与VAD
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // 写入音频文件
        try? audioFile?.write(from: buffer)
        
        // 计算音频电平用于UI显示
        let level = calculateRMSLevel(buffer)
        audioLevel = level
        
        // Voice Activity Detection
        if level > silenceThreshold {
            // 检测到语音，重置静音计时器
            silenceTimer?.invalidate()
        } else {
            // 检测到静音，开始计时
            if silenceTimer == nil {
                silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTimeout, repeats: false) { [weak self] _ in
                    Task {
                        await self?.stopRecording()
                    }
                }
            }
        }
    }
    
    private func calculateRMSLevel(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0.0 }
        
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0.0
        
        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }
        
        return sqrt(sum / Float(frameLength))
    }
    
    // MARK: - 音频格式转换
    private func convertToAPIFormat() async -> Data? {
        guard let audioFile = audioFile else { return nil }
        
        do {
            let audioData = try Data(contentsOf: audioFile.url)
            
            // 清理临时文件
            try? FileManager.default.removeItem(at: audioFile.url)
            
            return audioData
        } catch {
            LogManager.shared.error("AudioService", "音频转换失败: \(error)")
            return nil
        }
    }
    
    // MARK: - 计时器管理
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.recordingDuration += 0.1
            
            // 超时自动停止
            if self.recordingDuration >= self.maxRecordingTime {
                Task {
                    await self.stopRecording()
                }
            }
        }
    }
}

// MARK: - 错误定义
enum AudioError: LocalizedError {
    case microphonePermissionDenied
    case audioEngineStartFailed
    case audioFileCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "需要麦克风权限才能录音"
        case .audioEngineStartFailed:
            return "音频引擎启动失败"
        case .audioFileCreationFailed:
            return "音频文件创建失败"
        }
    }
}
```

### 2.2 OpenAI服务模块 (OpenAIService)

#### 2.2.1 分离式API调用设计
```swift
import OpenAI
import Foundation

class OpenAIService: ObservableObject {
    // MARK: - Configuration
    private let openAI: OpenAI
    private let apiConfiguration: APIConfiguration
    
    init(apiKey: String, baseURL: String = "https://api.openai.com/v1") {
        self.apiConfiguration = APIConfiguration(
            baseURL: baseURL,
            apiKey: apiKey,
            timeoutInterval: 30.0
        )
        self.openAI = OpenAI(configuration: apiConfiguration)
    }
    
    // MARK: - ASR (Automatic Speech Recognition)
    func transcribeAudio(_ audioData: Data) async throws -> String {
        LogManager.shared.info("OpenAIService", "开始语音识别 - 音频大小: \(audioData.count)字节")
        
        let request = AudioTranscriptionRequest(
            file: audioData,
            fileName: "audio.wav",
            model: .whisper_1,
            language: "zh",  // 中文优先，支持中英混合
            temperature: 0.0,  // 确保一致性输出
            responseFormat: .text
        )
        
        do {
            let result = try await openAI.audioTranscriptions(request: request)
            LogManager.shared.info("OpenAIService", "语音识别成功 - 文本长度: \(result.text.count)")
            return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            LogManager.shared.error("OpenAIService", "语音识别失败: \(error)")
            throw OpenAIError.transcriptionFailed(error)
        }
    }
    
    // MARK: - LLM (Large Language Model)
    func optimizePrompt(_ rawText: String, context: PromptContext) async throws -> String {
        LogManager.shared.info("OpenAIService", "开始优化提示词 - 上下文: \(context.rawValue)")
        
        let systemPrompt = buildSystemPrompt(for: context)
        let userPrompt = buildUserPrompt(rawText: rawText, context: context)
        
        let request = ChatCompletionsRequest(
            model: .gpt4o,  // 使用最新的GPT-4o模型
            messages: [
                .system(content: systemPrompt),
                .user(content: userPrompt)
            ],
            temperature: 0.3,  // 平衡创意和一致性
            maxTokens: 2000,
            presencePenalty: 0.1,
            frequencyPenalty: 0.1
        )
        
        do {
            let result = try await openAI.chatCompletions(request: request)
            guard let content = result.choices.first?.message.content else {
                throw OpenAIError.emptyResponse
            }
            
            LogManager.shared.info("OpenAIService", "提示词优化成功 - 输出长度: \(content.count)")
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            LogManager.shared.error("OpenAIService", "提示词优化失败: \(error)")
            throw OpenAIError.optimizationFailed(error)
        }
    }
    
    // MARK: - 语音修改功能
    func modifyPrompt(originalPrompt: String, modificationRequest: String) async throws -> String {
        LogManager.shared.info("OpenAIService", "开始修改提示词")
        
        let systemPrompt = """
        你是一个AI提示词修改专家。用户会提供一个原始提示词和修改需求，请根据修改需求对原始提示词进行调整，返回完整的修改后提示词。
        
        修改原则：
        1. 保持原始提示词的核心意图和结构
        2. 准确理解修改需求，精确执行修改指令
        3. 确保修改后的提示词逻辑清晰、表达准确
        4. 返回完整的修改后提示词，不要返回diff或部分内容
        """
        
        let userPrompt = """
        原始提示词：
        \(originalPrompt)
        
        修改需求：
        \(modificationRequest)
        
        请返回修改后的完整提示词：
        """
        
        let request = ChatCompletionsRequest(
            model: .gpt4o,
            messages: [
                .system(content: systemPrompt),
                .user(content: userPrompt)
            ],
            temperature: 0.2,  // 修改时需要更高的一致性
            maxTokens: 2500
        )
        
        do {
            let result = try await openAI.chatCompletions(request: request)
            guard let content = result.choices.first?.message.content else {
                throw OpenAIError.emptyResponse
            }
            
            LogManager.shared.info("OpenAIService", "提示词修改成功")
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            LogManager.shared.error("OpenAIService", "提示词修改失败: \(error)")
            throw OpenAIError.modificationFailed(error)
        }
    }
    
    // MARK: - 上下文感知的提示词构建
    private func buildSystemPrompt(for context: PromptContext) -> String {
        let basePrompt = """
        你是一个AI提示词优化专家。用户会说出他们的想法，你需要将其转换为清晰、专业的AI提示词。
        
        优化原则：
        1. 保持用户的核心意图不变
        2. 补充必要的技术细节和约束条件
        3. 使用专业术语，提高AI理解准确性
        4. 结构化表达，便于AI执行
        """
        
        let contextSpecific: String
        switch context {
        case .code:
            contextSpecific = """
            
            代码类提示词优化要求：
            - 明确指定编程语言和技术栈
            - 包含代码结构和架构要求
            - 添加错误处理和边界情况考虑
            - 指定代码风格和最佳实践
            - 包含必要的注释和文档要求
            """
        case .design:
            contextSpecific = """
            
            设计类提示词优化要求：
            - 详细描述视觉风格和美学要求
            - 指定颜色、构图、lighting等技术参数
            - 添加分辨率、格式等输出规格
            - 包含设计理念和目标受众
            - 使用专业的设计和艺术术语
            """
        case .writing:
            contextSpecific = """
            
            写作类提示词优化要求：
            - 明确文本类型、风格和语调
            - 指定目标受众和使用场景
            - 添加结构要求和内容框架
            - 包含字数、格式等具体要求
            - 强调逻辑性和可读性
            """
        case .general:
            contextSpecific = """
            
            通用提示词优化要求：
            - 分析用户意图，补充必要背景信息
            - 添加输出格式和质量要求
            - 包含相关的约束条件
            - 确保指令清晰、可执行
            """
        }
        
        return basePrompt + contextSpecific
    }
    
    private func buildUserPrompt(rawText: String, context: PromptContext) -> String {
        return """
        用户原始输入："\(rawText)"
        当前上下文：\(context.displayName)
        
        请将用户的想法优化为专业的AI提示词：
        """
    }
    
    // MARK: - 连接测试
    func testConnection() async throws -> Bool {
        let request = ChatCompletionsRequest(
            model: .gpt3_5Turbo,
            messages: [.user(content: "Hello")],
            maxTokens: 10
        )
        
        do {
            _ = try await openAI.chatCompletions(request: request)
            return true
        } catch {
            throw OpenAIError.connectionFailed(error)
        }
    }
}

// MARK: - 上下文类型定义
enum PromptContext: String, CaseIterable {
    case code = "code"
    case design = "design"  
    case writing = "writing"
    case general = "general"
    
    var displayName: String {
        switch self {
        case .code: return "代码开发"
        case .design: return "设计创作"
        case .writing: return "文本写作"
        case .general: return "通用场景"
        }
    }
}

// MARK: - 错误定义
enum OpenAIError: LocalizedError {
    case transcriptionFailed(Error)
    case optimizationFailed(Error)
    case modificationFailed(Error)
    case connectionFailed(Error)
    case emptyResponse
    case invalidAPIKey
    
    var errorDescription: String? {
        switch self {
        case .transcriptionFailed:
            return "语音识别失败"
        case .optimizationFailed:
            return "提示词优化失败"
        case .modificationFailed:
            return "提示词修改失败"
        case .connectionFailed:
            return "API连接失败"
        case .emptyResponse:
            return "API返回空结果"
        case .invalidAPIKey:
            return "API密钥无效"
        }
    }
}
```

### 2.3 应用管理器 (AppManager)

#### 2.3.1 Siri风格状态管理与流程控制
```swift
import SwiftUI
import Combine
import KeyboardShortcuts

@MainActor
class AppManager: ObservableObject {
    // MARK: - Published State
    @Published var currentState: AppState = .idle
    @Published var isRecording = false
    @Published var currentPrompt = ""
    @Published var errorMessage = ""
    @Published var showSettings = false
    @Published var showResultOverlay = false
    @Published var processingProgress: Double = 0.0
    @Published var currentPhase: ProcessingPhase = .none
    
    // MARK: - Services
    private let audioService = AudioService()
    private let configManager = ConfigManager()
    private var openAIService: OpenAIService?
    private let hapticManager = HapticManager()
    private let soundManager = SoundManager()
    
    // MARK: - Context Detection
    private let contextDetector = ContextDetector()
    private var currentContext: PromptContext = .general
    
    // MARK: - Siri风格状态转换
    private var stateTransitionQueue = DispatchQueue(label: "state.transition", qos: .userInteractive)
    private var processingStartTime: Date?
    
    // MARK: - Combine Subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupKeyboardShortcuts()
        setupStateObservers()
        initializeOpenAIService()
        setupSiriStyleTransitions()
    }
    
    // MARK: - 初始化配置
    private func initializeOpenAIService() {
        if let apiKey = configManager.config.apiKey, !apiKey.isEmpty {
            openAIService = OpenAIService(
                apiKey: apiKey,
                baseURL: configManager.config.baseURL
            )
        }
    }
    
    // MARK: - 快捷键设置
    private func setupKeyboardShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .recordPrompt) {
            Task {
                await self.handleRecordingToggle()
            }
        }
    }
    
    // MARK: - 状态观察
    private func setupStateObservers() {
        audioService.$isRecording
            .sink { [weak self] isRecording in
                self?.isRecording = isRecording
            }
            .store(in: &cancellables)
        
        configManager.$config
            .sink { [weak self] config in
                if let apiKey = config.apiKey, !apiKey.isEmpty {
                    self?.openAIService = OpenAIService(
                        apiKey: apiKey,
                        baseURL: config.baseURL
                    )
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Siri风格主要功能流程
    func handleRecordingToggle() async {
        await performSiriStyleTransition {
            switch currentState {
            case .idle:
                await startRecording()
            case .recording:
                await stopRecording()
            default:
                break
            }
        }
    }
    
    private func startRecording() async {
        guard openAIService != nil else {
            await showError("请先配置OpenAI API密钥")
            return
        }
        
        // Siri风格启动序列
        await performStartupSequence()
        
        currentContext = contextDetector.detectCurrentContext()
        
        do {
            try await audioService.startRecording()
            
            // 触觉反馈 - 开始录音
            hapticManager.playRecordingStart()
            
            // 音效反馈
            soundManager.playRecordingStart()
            
            currentState = .recording
            
            LogManager.shared.info("AppManager", "开始录音 - 上下文: \(currentContext.displayName)")
        } catch {
            await showError("录音启动失败: \(error.localizedDescription)")
            await returnToIdle()
        }
    }
    
    private func stopRecording() async {
        // 触觉反馈 - 停止录音
        hapticManager.playRecordingStop()
        
        // 音效反馈
        soundManager.playRecordingStop()
        
        // 优雅的过渡到处理状态
        await transitionToProcessing()
        
        guard let audioData = await audioService.stopRecording() else {
            await showError("录音数据获取失败")
            await returnToIdle()
            return
        }
        
        await processAudioToPrompt(audioData)
    }
    
    private func processAudioToPrompt(_ audioData: Data) async {
        guard let openAI = openAIService else {
            await showError("OpenAI服务未配置")
            await returnToIdle()
            return
        }
        
        processingStartTime = Date()
        
        do {
            // Phase 1: 语音识别 (40%进度)
            await updateProcessingPhase(.transcription, progress: 0.1)
            
            let rawText = try await openAI.transcribeAudio(audioData)
            
            await updateProcessingPhase(.transcription, progress: 0.4)
            
            guard !rawText.isEmpty else {
                await showError("未检测到有效语音，请重试")
                await returnToIdle()
                return
            }
            
            // Phase 2: 理解与优化 (30%进度)
            await updateProcessingPhase(.understanding, progress: 0.5)
            
            // 添加处理延迟以展示优雅的过渡
            try await Task.sleep(nanoseconds: 300_000_000) // 300ms
            
            await updateProcessingPhase(.optimization, progress: 0.7)
            
            let optimizedPrompt = try await openAI.optimizePrompt(rawText, context: currentContext)
            
            // Phase 3: 完成 (100%进度)
            await updateProcessingPhase(.completion, progress: 1.0)
            
            // 成功完成的触觉和音效反馈
            hapticManager.playProcessingComplete()
            soundManager.playProcessingComplete()
            
            // 优雅显示结果
            await presentResult(optimizedPrompt)
            
            LogManager.shared.info("AppManager", "处理完成 - 原文: \(rawText) -> 提示词长度: \(optimizedPrompt.count)")
            
        } catch {
            // 错误反馈
            hapticManager.playError()
            soundManager.playError()
            
            await showError("处理失败: \(error.localizedDescription)")
            await returnToIdle()
        }
    }
    
    // MARK: - Siri风格状态转换方法
    private func performSiriStyleTransition(_ action: @escaping () async -> Void) async {
        await stateTransitionQueue.asyncTask {
            await action()
        }
    }
    
    private func performStartupSequence() async {
        // 模拟Siri的启动动画序列
        currentState = .idle
        
        // 短暂的准备阶段
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
    }
    
    private func transitionToProcessing() async {
        // 平滑过渡到处理状态
        withAnimation(.easeOut(duration: 0.5)) {
            currentState = .processing
            processingProgress = 0.0
            currentPhase = .none
        }
        
        // 短暂延迟以显示转换动画
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
    }
    
    private func updateProcessingPhase(_ phase: ProcessingPhase, progress: Double) async {
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPhase = phase
                processingProgress = progress
            }
        }
        
        // 给用户足够时间看到每个阶段
        try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
    }
    
    private func presentResult(_ prompt: String) async {
        await MainActor.run {
            currentPrompt = prompt
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                currentState = .result
                showResultOverlay = true
            }
        }
    }
    
    private func returnToIdle() async {
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.4)) {
                currentState = .idle
                processingProgress = 0.0
                currentPhase = .none
            }
        }
    }
    
    // MARK: - Siri风格状态观察设置
    private func setupSiriStyleTransitions() {
        // 监听状态变化并触发相应的效果
        $currentState
            .removeDuplicates()
            .sink { [weak self] state in
                Task { @MainActor in
                    await self?.handleStateTransition(to: state)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleStateTransition(to state: AppState) async {
        switch state {
        case .idle:
            // 重置所有状态
            processingProgress = 0.0
            currentPhase = .none
            
        case .recording:
            // 录音状态的额外设置
            break
            
        case .processing:
            // 处理状态的额外设置
            break
            
        case .result:
            // 结果显示的额外设置
            break
        }
    }
    
    // MARK: - 结果确认与修改
    func confirmPrompt() {
        Task {
            await insertTextToCursor(currentPrompt)
            dismissResult()
        }
    }
    
    func requestModification() async {
        currentState = .recording
        
        do {
            try await audioService.startRecording()
            LogManager.shared.info("AppManager", "开始录制修改指令")
        } catch {
            showError("录音启动失败: \(error.localizedDescription)")
            currentState = .result
        }
    }
    
    func processModification(_ audioData: Data) async {
        guard let openAI = openAIService else { return }
        
        do {
            let modificationRequest = try await openAI.transcribeAudio(audioData)
            let modifiedPrompt = try await openAI.modifyPrompt(
                originalPrompt: currentPrompt,
                modificationRequest: modificationRequest
            )
            
            currentPrompt = modifiedPrompt
            currentState = .result
            
            LogManager.shared.info("AppManager", "修改完成 - 修改指令: \(modificationRequest)")
            
        } catch {
            showError("修改失败: \(error.localizedDescription)")
            currentState = .result
        }
    }
    
    func dismissResult() {
        showResultOverlay = false
        currentPrompt = ""
        currentState = .idle
    }
    
    // MARK: - 文本插入功能
    private func insertTextToCursor(_ text: String) async {
        let pasteboard = NSPasteboard.general
        let originalContents = pasteboard.pasteboardItems
        
        // 复制文本到剪贴板
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // 模拟Cmd+V粘贴
        let source = CGEventSource(stateID: .hidSystemState)
        
        let cmdVDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let cmdVUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        
        cmdVDown?.flags = .maskCommand
        cmdVUp?.flags = .maskCommand
        
        cmdVDown?.post(tap: .cghidEventTap)
        cmdVUp?.post(tap: .cghidEventTap)
        
        // 延迟后恢复剪贴板内容
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            pasteboard.clearContents()
            if let originalContents = originalContents {
                pasteboard.writeObjects(originalContents)
            }
        }
        
        LogManager.shared.info("AppManager", "文本已插入到光标位置")
    }
    
    // MARK: - 错误处理
    private func showError(_ message: String) {
        errorMessage = message
        LogManager.shared.error("AppManager", message)
        
        // 3秒后自动清除错误
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.errorMessage = ""
        }
    }
    
    // MARK: - 配置管理
    func updateConfiguration(_ config: AppConfiguration) {
        configManager.config = config
        initializeOpenAIService()
    }
    
    func testAPIConnection() async -> Bool {
        guard let openAI = openAIService else { return false }
        
        do {
            return try await openAI.testConnection()
        } catch {
            showError("API连接测试失败: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - 应用状态定义
enum AppState {
    case idle          // 空闲状态
    case recording     // 录音中
    case processing    // 处理中
    case result        // 显示结果
}

// MARK: - 处理阶段定义
enum ProcessingPhase: String, CaseIterable {
    case none = "none"
    case transcription = "语音识别中"
    case understanding = "理解语义中"
    case optimization = "优化提示词中"
    case completion = "完成"
    
    var description: String {
        return self.rawValue
    }
    
    var icon: String {
        switch self {
        case .none: return ""
        case .transcription: return "waveform"
        case .understanding: return "brain.head.profile"
        case .optimization: return "gearshape.2"
        case .completion: return "checkmark.circle"
        }
    }
}

// MARK: - 触觉反馈管理器
class HapticManager {
    
    func playRecordingStart() {
        let feedback = NSHapticFeedbackManager.defaultPerformer
        feedback.perform(.generic, performanceTime: .now)
    }
    
    func playRecordingStop() {
        let feedback = NSHapticFeedbackManager.defaultPerformer
        feedback.perform(.generic, performanceTime: .now)
    }
    
    func playProcessingComplete() {
        let feedback = NSHapticFeedbackManager.defaultPerformer
        feedback.perform(.generic, performanceTime: .now)
    }
    
    func playError() {
        let feedback = NSHapticFeedbackManager.defaultPerformer
        feedback.perform(.generic, performanceTime: .now)
    }
}

// MARK: - 音效管理器
class SoundManager {
    private var audioPlayers: [String: AVAudioPlayer] = [:]
    
    init() {
        setupSounds()
    }
    
    private func setupSounds() {
        // 预加载音效文件
        loadSound(name: "recording_start", file: "recording_start.aiff")
        loadSound(name: "recording_stop", file: "recording_stop.aiff")
        loadSound(name: "processing_complete", file: "processing_complete.aiff")
        loadSound(name: "error", file: "error.aiff")
    }
    
    private func loadSound(name: String, file: String) {
        guard let url = Bundle.main.url(forResource: file, withExtension: nil) else {
            LogManager.shared.warning("SoundManager", "音效文件未找到: \(file)")
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            audioPlayers[name] = player
        } catch {
            LogManager.shared.error("SoundManager", "音效加载失败: \(error)")
        }
    }
    
    func playRecordingStart() {
        playSound("recording_start")
    }
    
    func playRecordingStop() {
        playSound("recording_stop")
    }
    
    func playProcessingComplete() {
        playSound("processing_complete")
    }
    
    func playError() {
        playSound("error")
    }
    
    private func playSound(_ name: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.audioPlayers[name]?.play()
        }
    }
}

// MARK: - DispatchQueue异步扩展
extension DispatchQueue {
    func asyncTask<T>(_ task: @escaping () async -> T) async -> T {
        return await withCheckedContinuation { continuation in
            self.async {
                Task {
                    let result = await task()
                    continuation.resume(returning: result)
                }
            }
        }
    }
}

// MARK: - 快捷键定义
extension KeyboardShortcuts.Name {
    static let recordPrompt = Self("recordPrompt", default: .init(.m, modifiers: [.control]))
}
```

### 2.4 上下文检测器 (ContextDetector)

#### 2.4.1 智能上下文识别
```swift
import AppKit
import Foundation

class ContextDetector {
    
    func detectCurrentContext() -> PromptContext {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return .general
        }
        
        let bundleIdentifier = frontApp.bundleIdentifier ?? ""
        let appName = frontApp.localizedName ?? ""
        
        LogManager.shared.debug("ContextDetector", "检测到前台应用: \(appName) (\(bundleIdentifier))")
        
        return classifyApplication(bundleIdentifier: bundleIdentifier, appName: appName)
    }
    
    private func classifyApplication(bundleIdentifier: String, appName: String) -> PromptContext {
        let lowercaseName = appName.lowercased()
        let lowercaseBundle = bundleIdentifier.lowercased()
        
        // 代码开发工具
        if isCodeEditor(bundle: lowercaseBundle, name: lowercaseName) {
            return .code
        }
        
        // 设计工具
        if isDesignTool(bundle: lowercaseBundle, name: lowercaseName) {
            return .design
        }
        
        // 写作工具
        if isWritingTool(bundle: lowercaseBundle, name: lowercaseName) {
            return .writing
        }
        
        return .general
    }
    
    private func isCodeEditor(bundle: String, name: String) -> Bool {
        let codeKeywords = [
            // IDE
            "xcode", "android studio", "intellij", "pycharm", "webstorm",
            // 编辑器
            "visual studio code", "vscode", "sublime", "atom", "vim", "emacs",
            "nova", "coderunner", "textmate",
            // 终端
            "terminal", "iterm", "hyper", "alacritty",
            // 特定bundle
            "com.apple.dt.xcode", "com.microsoft.vscode", "com.sublimetext",
            "com.jetbrains", "com.panic.nova", "com.apple.terminal"
        ]
        
        return codeKeywords.contains { keyword in
            bundle.contains(keyword) || name.contains(keyword)
        }
    }
    
    private func isDesignTool(bundle: String, name: String) -> Bool {
        let designKeywords = [
            // Adobe套件
            "photoshop", "illustrator", "indesign", "after effects", "premiere",
            "lightroom", "xd", "dimension",
            // 其他设计工具
            "figma", "sketch", "invision", "principle", "framer",
            "canva", "affinity", "pixelmator", "procreate",
            // 3D工具
            "blender", "cinema 4d", "maya", "3ds max",
            // 特定bundle
            "com.adobe", "com.figma", "com.bohemiancoding.sketch3",
            "com.pixelmatorteam"
        ]
        
        return designKeywords.contains { keyword in
            bundle.contains(keyword) || name.contains(keyword)
        }
    }
    
    private func isWritingTool(bundle: String, name: String) -> Bool {
        let writingKeywords = [
            // 文档编辑
            "pages", "word", "google docs", "notion", "obsidian",
            "typora", "bear", "ulysses", "scrivener", "drafts",
            // 笔记应用
            "evernote", "onenote", "apple notes", "logseq", "roam",
            // Markdown编辑器
            "markdown editor", "iawriter", "writeroom", "focused",
            // 特定bundle
            "com.apple.pages", "com.microsoft.word", "md.obsidian",
            "com.typora", "net.shinyfrog.bear", "com.ulysses"
        ]
        
        return writingKeywords.contains { keyword in
            bundle.contains(keyword) || name.contains(keyword)
        }
    }
}
```

## 3. UI界面设计

### 3.1 Siri风格光球组件 (SiriOrb)

#### 3.1.1 苹果Siri光球视觉效果
```swift
import SwiftUI
import AVFoundation

struct SiriOrb: View {
    @ObservedObject var appManager: AppManager
    @ObservedObject var audioService: AudioService
    
    @State private var wavePoints: [WavePoint] = []
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0
    @State private var particleSystem = ParticleSystem()
    @State private var breathingScale: CGFloat = 1.0
    @State private var shimmerOffset: CGFloat = 0
    @State private var coreGlowIntensity: CGFloat = 0.5
    
    private let orbSize: CGFloat = 120
    private let coreSize: CGFloat = 24
    
    var body: some View {
        ZStack {
            // 背景光晕层
            backgroundGlow
            
            // Siri波形环
            if appManager.currentState == .recording {
                siriWaveRing
            }
            
            // 粒子系统
            if appManager.currentState == .processing {
                particleLayer
            }
            
            // 核心光球
            coreOrb
            
            // 状态指示器
            statusIndicator
            
            // 处理进度指示器 (仅在处理阶段显示)
            if appManager.currentState == .processing {
                processingIndicator
            }
        }
        .frame(width: orbSize, height: orbSize)
        .position(x: screenWidth / 2, y: screenHeight - 120) // 屏幕中下方
        .onAppear {
            setupInitialState()
        }
        .onChange(of: appManager.currentState) { state in
            animateStateTransition(to: state)
        }
        .onChange(of: audioService.audioLevel) { level in
            updateAudioVisualization(level: level)
        }
    }
    
    // MARK: - Siri波形环
    private var siriWaveRing: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { ring in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [recordingColor.opacity(0.8), recordingColor.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(
                            lineWidth: 2 + CGFloat(ring) * 0.5,
                            lineCap: .round
                        )
                    )
                    .frame(width: orbSize - CGFloat(ring) * 15)
                    .scaleEffect(1.0 + audioVisualScale * CGFloat(3 - ring) * 0.3)
                    .opacity(0.8 - Double(ring) * 0.2)
                    .animation(
                        .easeInOut(duration: 0.1),
                        value: audioVisualScale
                    )
            }
            
            // 动态波形点
            SiriWaveShape(points: wavePoints, audioLevel: audioService.audioLevel)
                .stroke(
                    LinearGradient(
                        colors: [recordingColor, recordingColor.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )
                .frame(width: orbSize * 0.7, height: orbSize * 0.7)
                .animation(.easeOut(duration: 0.1), value: audioService.audioLevel)
        }
    }
    
    // MARK: - 背景光晕
    private var backgroundGlow: some View {
        ZStack {
            // 外层光晕
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            currentStateColor.opacity(0.3),
                            currentStateColor.opacity(0.1),
                            .clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: orbSize
                    )
                )
                .frame(width: orbSize * 1.5, height: orbSize * 1.5)
                .scaleEffect(breathingScale)
                .animation(
                    .easeInOut(duration: 3.0).repeatForever(autoreverses: true),
                    value: breathingScale
                )
            
            // 中层光晕
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            currentStateColor.opacity(0.4),
                            currentStateColor.opacity(0.2),
                            .clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: orbSize * 0.8
                    )
                )
                .frame(width: orbSize, height: orbSize)
                .scaleEffect(pulseScale)
        }
        .blur(radius: 8)
    }
    
    // MARK: - 核心光球
    private var coreOrb: some View {
        ZStack {
            // 核心基础球体
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.9),
                            currentStateColor.opacity(0.8),
                            currentStateColor.opacity(0.6)
                        ],
                        center: UnitPoint(x: 0.3, y: 0.3), // 模拟光源
                        startRadius: 2,
                        endRadius: coreSize
                    )
                )
                .frame(width: coreSize, height: coreSize)
                .overlay(
                    // 内部高光
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .white.opacity(coreGlowIntensity),
                                    .clear
                                ],
                                center: UnitPoint(x: 0.25, y: 0.25),
                                startRadius: 1,
                                endRadius: 8
                            )
                        )
                        .frame(width: 12, height: 12)
                        .offset(x: -4, y: -4)
                )
            
            // 状态图标
            if let icon = currentStateIcon {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 1)
            }
        }
        .scaleEffect(breathingScale)
        .rotationEffect(.degrees(rotationAngle))
    }
    
    // MARK: - 状态指示器
    private var statusIndicator: some View {
        VStack(spacing: 4) {
            if appManager.currentState != .idle {
                Text(statusText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(currentStateColor.opacity(0.5), lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 2)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .offset(y: orbSize/2 + 20)
    }
    
    // MARK: - 处理进度指示器
    private var processingIndicator: some View {
        VStack(spacing: 8) {
            // 当前阶段指示
            if appManager.currentPhase != .none {
                HStack(spacing: 6) {
                    Image(systemName: appManager.currentPhase.icon)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(processingColor)
                    
                    Text(appManager.currentPhase.description)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(processingColor.opacity(0.3), lineWidth: 1)
                        )
                )
                .transition(.scale.combined(with: .opacity))
            }
            
            // 进度条
            ProgressView(value: appManager.processingProgress)
                .progressViewStyle(SiriProgressViewStyle(color: processingColor))
                .frame(width: 80)
        }
        .offset(y: orbSize/2 + 50)
    }
    
    // MARK: - 粒子系统
    private var particleLayer: some View {
        Canvas { context, size in
            for particle in particleSystem.particles {
                let rect = CGRect(
                    x: particle.position.x - particle.size/2,
                    y: particle.position.y - particle.size/2,
                    width: particle.size,
                    height: particle.size
                )
                
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(processingColor.opacity(particle.opacity))
                )
            }
        }
        .frame(width: orbSize, height: orbSize)
        .onReceive(Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()) { _ in
            particleSystem.update()
        }
    }
    
    // MARK: - 计算属性
    private var currentStateColor: Color {
        switch appManager.currentState {
        case .idle: return idleColor
        case .recording: return recordingColor
        case .processing: return processingColor
        case .result: return resultColor
        }
    }
    
    private var idleColor: Color { Color(red: 0.2, green: 0.8, blue: 0.4) } // 苹果绿
    private var recordingColor: Color { Color(red: 0.9, green: 0.2, blue: 0.2) } // 录音红
    private var processingColor: Color { Color(red: 0.3, green: 0.6, blue: 1.0) } // 处理蓝
    private var resultColor: Color { Color(red: 0.8, green: 0.4, blue: 0.9) } // 结果紫
    
    private var currentStateIcon: String? {
        switch appManager.currentState {
        case .idle: return nil
        case .recording: return "mic.fill"
        case .processing: return nil // 由粒子系统表示
        case .result: return "checkmark"
        }
    }
    
    private var statusText: String {
        switch appManager.currentState {
        case .idle: return ""
        case .recording: return "听取中..."
        case .processing: return "思考中..."
        case .result: return "完成"
        }
    }
    
    private var audioVisualScale: CGFloat {
        let normalizedLevel = min(max(audioService.audioLevel, 0), 1)
        return 1.0 + normalizedLevel * 0.5
    }
    
    private var screenWidth: CGFloat {
        NSScreen.main?.frame.width ?? 1920
    }
    
    private var screenHeight: CGFloat {
        NSScreen.main?.frame.height ?? 1080
    }
    
    // MARK: - 动画控制方法
    private func setupInitialState() {
        generateWavePoints()
        breathingScale = 1.0
        
        // 开始呼吸动画
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            breathingScale = 1.1
        }
    }
    
    private func animateStateTransition(to state: AppState) {
        switch state {
        case .idle:
            animateToIdle()
        case .recording:
            animateToRecording()
        case .processing:
            animateToProcessing()
        case .result:
            animateToResult()
        }
    }
    
    private func animateToIdle() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
            pulseScale = 1.0
            coreGlowIntensity = 0.5
            rotationAngle = 0
        }
    }
    
    private func animateToRecording() {
        // 脉动动画
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            pulseScale = 1.3
            coreGlowIntensity = 1.0
        }
        
        // 开始波形生成
        updateWavePoints()
    }
    
    private func animateToProcessing() {
        // 停止录音动画
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            pulseScale = 1.0
        }
        
        // 开始旋转动画
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
        
        // 启动粒子系统
        particleSystem.start(in: CGRect(x: 0, y: 0, width: orbSize, height: orbSize))
        
        // 神秘感光效
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            coreGlowIntensity = 0.8
        }
    }
    
    private func animateToResult() {
        // 完成闪烁
        withAnimation(.easeOut(duration: 0.3)) {
            coreGlowIntensity = 1.2
        }
        
        withAnimation(.easeIn(duration: 0.2).delay(0.3)) {
            coreGlowIntensity = 0.6
        }
        
        // 停止旋转
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            rotationAngle = 0
        }
        
        // 停止粒子系统
        particleSystem.stop()
    }
    
    private func updateAudioVisualization(level: Float) {
        if appManager.currentState == .recording {
            updateWavePoints()
            
            // 根据音频电平调整光晕强度
            let normalizedLevel = CGFloat(min(max(level, 0), 1))
            withAnimation(.easeOut(duration: 0.1)) {
                coreGlowIntensity = 0.5 + normalizedLevel * 0.7
            }
        }
    }
    
    private func generateWavePoints() {
        wavePoints = (0..<60).map { i in
            WavePoint(
                angle: Double(i) * 6.0,
                baseRadius: 30.0,
                amplitude: 0.0
            )
        }
    }
    
    private func updateWavePoints() {
        guard appManager.currentState == .recording else { return }
        
        let audioLevel = Double(audioService.audioLevel)
        let time = Date().timeIntervalSince1970
        
        for i in 0..<wavePoints.count {
            let frequency = 0.5 + Double(i) * 0.1
            let phase = time * frequency * 2 * Double.pi
            wavePoints[i].amplitude = audioLevel * 15.0 * sin(phase)
        }
        
        // 定时更新
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) {
            self.updateWavePoints()
        }
    }
}

// MARK: - 波形数据结构
struct WavePoint {
    let angle: Double
    let baseRadius: Double
    var amplitude: Double
    
    var position: CGPoint {
        let radius = baseRadius + amplitude
        let x = cos(angle * .pi / 180) * radius
        let y = sin(angle * .pi / 180) * radius
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Siri波形形状
struct SiriWaveShape: Shape {
    let points: [WavePoint]
    let audioLevel: Float
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        guard !points.isEmpty else { return path }
        
        let center = CGPoint(x: rect.midX, y: rect.midY)
        
        // 创建平滑的波形路径
        for (index, point) in points.enumerated() {
            let position = CGPoint(
                x: center.x + point.position.x,
                y: center.y + point.position.y
            )
            
            if index == 0 {
                path.move(to: position)
            } else {
                let previousPoint = points[index - 1]
                let previousPosition = CGPoint(
                    x: center.x + previousPoint.position.x,
                    y: center.y + previousPoint.position.y
                )
                
                // 使用二次贝塞尔曲线创建平滑连接
                let controlPoint = CGPoint(
                    x: (previousPosition.x + position.x) / 2,
                    y: (previousPosition.y + position.y) / 2
                )
                
                path.addQuadCurve(to: position, control: controlPoint)
            }
        }
        
        // 闭合路径
        if let firstPoint = points.first {
            let firstPosition = CGPoint(
                x: center.x + firstPoint.position.x,
                y: center.y + firstPoint.position.y
            )
            path.addLine(to: firstPosition)
        }
        
        return path
    }
}

// MARK: - 粒子系统
class ParticleSystem: ObservableObject {
    @Published var particles: [Particle] = []
    private var isActive = false
    private var bounds: CGRect = .zero
    
    func start(in bounds: CGRect) {
        self.bounds = bounds
        isActive = true
        generateParticles()
    }
    
    func stop() {
        isActive = false
    }
    
    func update() {
        guard isActive else {
            particles.removeAll()
            return
        }
        
        // 更新现有粒子
        particles = particles.compactMap { particle in
            var updatedParticle = particle
            updatedParticle.update()
            return updatedParticle.isAlive ? updatedParticle : nil
        }
        
        // 生成新粒子
        if particles.count < 20 {
            particles.append(generateRandomParticle())
        }
    }
    
    private func generateParticles() {
        particles = (0..<10).map { _ in generateRandomParticle() }
    }
    
    private func generateRandomParticle() -> Particle {
        let centerX = bounds.midX
        let centerY = bounds.midY
        let radius = Double.random(in: 20...40)
        let angle = Double.random(in: 0...(2 * Double.pi))
        
        return Particle(
            position: CGPoint(
                x: centerX + cos(angle) * radius,
                y: centerY + sin(angle) * radius
            ),
            velocity: CGPoint(
                x: cos(angle) * Double.random(in: 0.5...1.5),
                y: sin(angle) * Double.random(in: 0.5...1.5)
            ),
            size: Double.random(in: 1...3),
            opacity: Double.random(in: 0.3...0.8),
            life: Double.random(in: 2...4)
        )
    }
}

// MARK: - 粒子数据结构
struct Particle {
    var position: CGPoint
    var velocity: CGPoint
    var size: Double
    var opacity: Double
    var life: Double
    var age: Double = 0
    
    var isAlive: Bool {
        age < life
    }
    
    mutating func update() {
        position.x += velocity.x
        position.y += velocity.y
        age += 0.016 // 60fps
        
        // 渐变透明度
        opacity = max(0, opacity * (1 - age / life))
        
        // 轻微的重力效果
        velocity.y += 0.1
    }
}

// MARK: - Siri风格进度条样式
struct SiriProgressViewStyle: ProgressViewStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        ZStack(alignment: .leading) {
            // 背景轨道
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(height: 3)
            
            // 进度条
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.8), color],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(
                    width: (configuration.fractionCompleted ?? 0) * 80,
                    height: 3
                )
                .overlay(
                    // 进度条光效
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.6), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 2)
                        .blur(radius: 1)
                )
                .animation(.easeInOut(duration: 0.3), value: configuration.fractionCompleted)
        }
    }
}
    
    private var shadowColor: Color {
        strokeColor.opacity(0.3)
    }
    
    private var centerIcon: String {
        switch appManager.currentState {
        case .recording: return "mic.fill"
        case .processing: return "gearshape.fill"
        default: return "mic"
        }
    }
    
    private var animationDuration: Double {
        switch appManager.currentState {
        case .recording: return 0.8
        case .processing: return 1.2
        default: return 2.0
        }
    }
    
    private var screenWidth: CGFloat {
        NSScreen.main?.frame.width ?? 1920
    }
    
    private var screenHeight: CGFloat {
        NSScreen.main?.frame.height ?? 1080
    }
    
    // MARK: - 动画控制
    private func startAnimations() {
        pulseAnimation = true
    }
    
    private func updateAnimationForState(_ state: AppState) {
        switch state {
        case .processing:
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        default:
            withAnimation(.easeInOut(duration: 0.5)) {
                rotationAngle = 0
            }
        }
    }
}
```

### 3.2 结果展示覆盖层 (ResultOverlay)

#### 3.2.1 半透明美观展示
```swift
import SwiftUI

struct ResultOverlay: View {
    @ObservedObject var appManager: AppManager
    @State private var showContent = false
    @State private var keyboardMonitor: Any?
    
    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture {
                    appManager.dismissResult()
                }
            
            // 主内容卡片
            VStack(alignment: .leading, spacing: 20) {
                // 提示词内容区域
                ScrollView {
                    Text(appManager.currentPrompt)
                        .font(.system(.body, design: .rounded))
                        .lineSpacing(4)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(0.05))
                        )
                }
                .frame(maxHeight: 300)
                
                // 操作按钮区域
                HStack(spacing: 16) {
                    // 确认插入按钮
                    Button(action: {
                        appManager.confirmPrompt()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("确认插入")
                            Text("↵")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [])
                    
                    // 语音修改按钮
                    Button(action: {
                        Task {
                            await appManager.requestModification()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "mic.circle")
                            Text("语音修改")
                            Text("Space")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.space, modifiers: [])
                }
                
                // 底部状态栏
                HStack {
                    Text("处理时间: 1.2s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("字数: \(appManager.currentPrompt.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(24)
            .frame(width: 600)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            )
            .scaleEffect(showContent ? 1.0 : 0.9)
            .opacity(showContent ? 1.0 : 0.0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showContent = true
            }
            setupKeyboardHandling()
        }
        .onDisappear {
            cleanupKeyboardHandling()
        }
    }
    
    // MARK: - 键盘事件处理
    private func setupKeyboardHandling() {
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            switch event.keyCode {
            case 53: // ESC
                appManager.dismissResult()
                return nil
            default:
                return event
            }
        }
    }
    
    private func cleanupKeyboardHandling() {
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }
    }
}
```

### 3.3 设置界面 (SettingsView)

#### 3.3.1 简洁配置界面
```swift
import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @ObservedObject var appManager: AppManager
    @State private var isTestingConnection = false
    @State private var connectionTestResult: ConnectionTestResult?
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("Hello Prompt 设置")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("关闭") {
                    appManager.showSettings = false
                }
                .keyboardShortcut(.escape)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            // 设置内容
            Form {
                // API配置区域
                Section("OpenAI API 配置") {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Base URL")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("https://api.openai.com/v1", text: $configManager.config.baseURL)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("API Token")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            SecureField("sk-...", text: $configManager.config.apiKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        HStack {
                            Button(action: testConnection) {
                                HStack(spacing: 6) {
                                    if isTestingConnection {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                    } else {
                                        Image(systemName: testIconName)
                                    }
                                    Text("测试连接")
                                }
                            }
                            .disabled(configManager.config.apiKey.isEmpty || isTestingConnection)
                            
                            if let result = connectionTestResult {
                                Text(result.message)
                                    .font(.caption)
                                    .foregroundColor(result.isSuccess ? .green : .red)
                            }
                        }
                    }
                }
                
                // 快捷键配置
                Section("快捷键配置") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("录制快捷键")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        KeyboardShortcuts.Recorder(for: .recordPrompt)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                // 启动设置
                Section("启动设置") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("开机自动启动", isOn: $configManager.config.autoStart)
                        Toggle("启动时最小化到菜单栏", isOn: $configManager.config.minimizeOnStart)
                    }
                }
                
                // 高级设置
                Section("高级设置") {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("自动停止延迟: \(String(format: "%.1f", configManager.config.autoStopDelay))秒")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Slider(
                                value: $configManager.config.autoStopDelay,
                                in: 0.3...2.0,
                                step: 0.1
                            )
                        }
                        
                        Toggle("使用端到端模式 (实验性)", isOn: $configManager.config.useEndToEnd)
                            .help("直接使用OpenAI语音模型，可能更快但可控性较低")
                    }
                }
            }
            .formStyle(.grouped)
            .padding()
        }
        .frame(width: 500, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - 连接测试
    private func testConnection() {
        isTestingConnection = true
        connectionTestResult = nil
        
        Task {
            let success = await appManager.testAPIConnection()
            
            await MainActor.run {
                isTestingConnection = false
                connectionTestResult = ConnectionTestResult(
                    isSuccess: success,
                    message: success ? "连接成功" : "连接失败"
                )
                
                // 3秒后清除测试结果
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    connectionTestResult = nil
                }
            }
        }
    }
    
    private var testIconName: String {
        if let result = connectionTestResult {
            return result.isSuccess ? "checkmark.circle" : "xmark.circle"
        }
        return "wifi"
    }
}

// MARK: - 连接测试结果
struct ConnectionTestResult {
    let isSuccess: Bool
    let message: String
}
```

## 4. 配置管理与存储

### 4.1 配置管理器 (ConfigManager)

#### 4.1.1 安全配置存储
```swift
import Foundation
import Security
import Defaults

class ConfigManager: ObservableObject {
    @Published var config = AppConfiguration()
    
    private let keychainService = "com.hellprompt.api"
    
    init() {
        loadConfiguration()
    }
    
    // MARK: - 配置加载与保存
    func loadConfiguration() {
        // 从Keychain加载敏感信息
        config.apiKey = loadFromKeychain(key: "openai_api_key") ?? ""
        
        // 从UserDefaults加载其他配置
        config.baseURL = Defaults[.baseURL]
        config.autoStart = Defaults[.autoStart]
        config.minimizeOnStart = Defaults[.minimizeOnStart]
        config.autoStopDelay = Defaults[.autoStopDelay]
        config.useEndToEnd = Defaults[.useEndToEnd]
    }
    
    func saveConfiguration() {
        // 保存敏感信息到Keychain
        saveToKeychain(key: "openai_api_key", value: config.apiKey)
        
        // 保存其他配置到UserDefaults
        Defaults[.baseURL] = config.baseURL
        Defaults[.autoStart] = config.autoStart
        Defaults[.minimizeOnStart] = config.minimizeOnStart
        Defaults[.autoStopDelay] = config.autoStopDelay
        Defaults[.useEndToEnd] = config.useEndToEnd
        
        LogManager.shared.info("ConfigManager", "配置已保存")
    }
    
    // MARK: - Keychain操作
    private func saveToKeychain(key: String, value: String) {
        let data = value.data(using: .utf8) ?? Data()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // 删除已存在的项
        SecItemDelete(query as CFDictionary)
        
        // 添加新项
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            LogManager.shared.error("ConfigManager", "Keychain保存失败: \(status)")
        }
    }
    
    private func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess,
              let data = dataTypeRef as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
}

// MARK: - 配置结构体
struct AppConfiguration {
    var apiKey: String = ""
    var baseURL: String = "https://api.openai.com/v1"
    var autoStart: Bool = true
    var minimizeOnStart: Bool = true
    var autoStopDelay: Double = 0.5
    var useEndToEnd: Bool = false
}

// MARK: - Defaults扩展
extension Defaults.Keys {
    static let baseURL = Key<String>("baseURL", default: "https://api.openai.com/v1")
    static let autoStart = Key<Bool>("autoStart", default: true)
    static let minimizeOnStart = Key<Bool>("minimizeOnStart", default: true)
    static let autoStopDelay = Key<Double>("autoStopDelay", default: 0.5)
    static let useEndToEnd = Key<Bool>("useEndToEnd", default: false)
}
```

## 5. 系统集成与启动管理

### 5.1 启动代理管理 (LaunchAgentManager)

#### 5.1.1 自动启动实现
```swift
import Foundation
import ServiceManagement

class LaunchAgentManager {
    private let launchAgentIdentifier = "com.hellprompt.launchagent"
    private let launchAgentPlistName = "com.hellprompt.plist"
    
    // MARK: - 启动代理管理
    func enableAutoStart() -> Bool {
        do {
            try createLaunchAgentPlist()
            return registerLaunchAgent()
        } catch {
            LogManager.shared.error("LaunchAgentManager", "启用自动启动失败: \(error)")
            return false
        }
    }
    
    func disableAutoStart() -> Bool {
        return unregisterLaunchAgent() && removeLaunchAgentPlist()
    }
    
    func isAutoStartEnabled() -> Bool {
        return FileManager.default.fileExists(atPath: launchAgentPlistPath)
    }
    
    // MARK: - LaunchAgent Plist创建
    private func createLaunchAgentPlist() throws {
        guard let executablePath = Bundle.main.executablePath else {
            throw LaunchAgentError.executablePathNotFound
        }
        
        let plistContent: [String: Any] = [
            "Label": launchAgentIdentifier,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "KeepAlive": false,
            "StandardOutPath": "/dev/null",
            "StandardErrorPath": "/dev/null"
        ]
        
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plistContent,
            format: .xml,
            options: 0
        )
        
        // 确保LaunchAgents目录存在
        let launchAgentsDir = launchAgentsDirectory
        try FileManager.default.createDirectory(
            at: launchAgentsDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // 写入plist文件
        let plistURL = launchAgentsDir.appendingPathComponent(launchAgentPlistName)
        try plistData.write(to: plistURL)
        
        LogManager.shared.info("LaunchAgentManager", "LaunchAgent plist已创建: \(plistURL.path)")
    }
    
    // MARK: - LaunchAgent注册/注销
    private func registerLaunchAgent() -> Bool {
        let plistURL = URL(fileURLWithPath: launchAgentPlistPath)
        
        do {
            if #available(macOS 13.0, *) {
                try SMAppService.loginItem(identifier: launchAgentIdentifier).register()
            } else {
                // macOS 12兼容性处理
                return registerLaunchAgentLegacy(plistURL: plistURL)
            }
            
            LogManager.shared.info("LaunchAgentManager", "LaunchAgent已注册")
            return true
        } catch {
            LogManager.shared.error("LaunchAgentManager", "LaunchAgent注册失败: \(error)")
            return false
        }
    }
    
    private func unregisterLaunchAgent() -> Bool {
        do {
            if #available(macOS 13.0, *) {
                try SMAppService.loginItem(identifier: launchAgentIdentifier).unregister()
            } else {
                // macOS 12兼容性处理
                return unregisterLaunchAgentLegacy()
            }
            
            LogManager.shared.info("LaunchAgentManager", "LaunchAgent已注销")
            return true
        } catch {
            LogManager.shared.error("LaunchAgentManager", "LaunchAgent注销失败: \(error)")
            return false
        }
    }
    
    // MARK: - 兼容性方法 (macOS 12)
    private func registerLaunchAgentLegacy(plistURL: URL) -> Bool {
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = ["load", plistURL.path]
        task.launch()
        task.waitUntilExit()
        
        return task.terminationStatus == 0
    }
    
    private func unregisterLaunchAgentLegacy() -> Bool {
        let plistURL = URL(fileURLWithPath: launchAgentPlistPath)
        
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = ["unload", plistURL.path]
        task.launch()
        task.waitUntilExit()
        
        return task.terminationStatus == 0
    }
    
    // MARK: - 文件管理
    private func removeLaunchAgentPlist() -> Bool {
        let plistURL = URL(fileURLWithPath: launchAgentPlistPath)
        
        do {
            try FileManager.default.removeItem(at: plistURL)
            LogManager.shared.info("LaunchAgentManager", "LaunchAgent plist已删除")
            return true
        } catch {
            LogManager.shared.error("LaunchAgentManager", "删除LaunchAgent plist失败: \(error)")
            return false
        }
    }
    
    // MARK: - 路径计算
    private var launchAgentsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("LaunchAgents")
    }
    
    private var launchAgentPlistPath: String {
        launchAgentsDirectory
            .appendingPathComponent(launchAgentPlistName)
            .path
    }
}

// MARK: - 错误定义
enum LaunchAgentError: LocalizedError {
    case executablePathNotFound
    case plistCreationFailed
    case registrationFailed
    
    var errorDescription: String? {
        switch self {
        case .executablePathNotFound:
            return "无法找到应用程序可执行文件路径"
        case .plistCreationFailed:
            return "LaunchAgent配置文件创建失败"
        case .registrationFailed:
            return "LaunchAgent注册失败"
        }
    }
}
```

## 6. 日志管理系统

### 6.1 统一日志管理器 (LogManager)

#### 6.1.1 结构化日志系统
```swift
import Foundation
import OSLog

class LogManager {
    static let shared = LogManager()
    
    private let logger: Logger
    private let fileLogger: FileLogger
    
    private init() {
        // 使用OSLog进行系统级日志记录
        self.logger = Logger(subsystem: "com.hellprompt.app", category: "general")
        
        // 使用文件日志进行调试和分析
        self.fileLogger = FileLogger()
    }
    
    // MARK: - 公共日志接口
    func debug(_ module: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let formattedMessage = formatMessage(level: "DEBUG", module: module, message: message, file: file, function: function, line: line)
        logger.debug("\(formattedMessage)")
        fileLogger.write(level: .debug, message: formattedMessage)
    }
    
    func info(_ module: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let formattedMessage = formatMessage(level: "INFO", module: module, message: message, file: file, function: function, line: line)
        logger.info("\(formattedMessage)")
        fileLogger.write(level: .info, message: formattedMessage)
    }
    
    func warning(_ module: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let formattedMessage = formatMessage(level: "WARNING", module: module, message: message, file: file, function: function, line: line)
        logger.warning("\(formattedMessage)")
        fileLogger.write(level: .warning, message: formattedMessage)
    }
    
    func error(_ module: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let formattedMessage = formatMessage(level: "ERROR", module: module, message: message, file: file, function: function, line: line)
        logger.error("\(formattedMessage)")
        fileLogger.write(level: .error, message: formattedMessage)
    }
    
    // MARK: - 专用日志方法
    func audioLog(_ event: AudioEvent, details: [String: Any] = [:]) {
        let message = "Audio Event: \(event.rawValue) - \(details)"
        info("AudioService", message)
    }
    
    func apiLog(_ event: APIEvent, duration: TimeInterval? = nil, details: [String: Any] = [:]) {
        var message = "API Event: \(event.rawValue)"
        if let duration = duration {
            message += " - Duration: \(String(format: "%.3f", duration))s"
        }
        if !details.isEmpty {
            message += " - Details: \(details)"
        }
        info("OpenAIService", message)
    }
    
    func uiLog(_ event: UIEvent, details: [String: Any] = [:]) {
        let message = "UI Event: \(event.rawValue) - \(details)"
        debug("UI", message)
    }
    
    // MARK: - 日志格式化
    private func formatMessage(level: String, module: String, message: String, file: String, function: String, line: Int) -> String {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        
        return "[\(timestamp)] [\(level)] [\(module)] [\(fileName):\(line)] \(function) - \(message)"
    }
    
    // MARK: - 日志导出
    func exportLogs() -> URL? {
        return fileLogger.exportLogs()
    }
    
    func clearLogs() {
        fileLogger.clearLogs()
    }
}

// MARK: - 文件日志器
private class FileLogger {
    private let logFileURL: URL
    private let maxFileSize: Int = 10 * 1024 * 1024 // 10MB
    private let maxFiles: Int = 5
    
    init() {
        let logsDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HelloPrompt")
            .appendingPathComponent("Logs")
        
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        
        self.logFileURL = logsDir.appendingPathComponent("hellprompt.log")
    }
    
    func write(level: LogLevel, message: String) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.writeToFile(message: message)
        }
    }
    
    private func writeToFile(message: String) {
        let logEntry = message + "\n"
        
        if FileManager.default.fileExists(atPath: logFileURL.path) {
            // 检查文件大小，必要时轮转
            if let fileSize = try? FileManager.default.attributesOfItem(atPath: logFileURL.path)[.size] as? Int,
               fileSize > maxFileSize {
                rotateLogFile()
            }
            
            // 追加到现有文件
            if let data = logEntry.data(using: .utf8),
               let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            // 创建新文件
            try? logEntry.write(to: logFileURL, atomically: true, encoding: .utf8)
        }
    }
    
    private func rotateLogFile() {
        let logsDir = logFileURL.deletingLastPathComponent()
        
        // 移动现有日志文件
        for i in (1..<maxFiles).reversed() {
            let oldFile = logsDir.appendingPathComponent("hellprompt.\(i).log")
            let newFile = logsDir.appendingPathComponent("hellprompt.\(i + 1).log")
            
            try? FileManager.default.moveItem(at: oldFile, to: newFile)
        }
        
        // 移动当前日志文件
        let archivedFile = logsDir.appendingPathComponent("hellprompt.1.log")
        try? FileManager.default.moveItem(at: logFileURL, to: archivedFile)
        
        // 删除最旧的日志文件
        let oldestFile = logsDir.appendingPathComponent("hellprompt.\(maxFiles).log")
        try? FileManager.default.removeItem(at: oldestFile)
    }
    
    func exportLogs() -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let exportFile = tempDir.appendingPathComponent("hellprompt_logs_\(Date().timeIntervalSince1970).log")
        
        do {
            try FileManager.default.copyItem(at: logFileURL, to: exportFile)
            return exportFile
        } catch {
            return nil
        }
    }
    
    func clearLogs() {
        try? FileManager.default.removeItem(at: logFileURL)
    }
}

// MARK: - 日志级别和事件定义
enum LogLevel {
    case debug, info, warning, error
}

enum AudioEvent: String {
    case recordingStarted = "RecordingStarted"
    case recordingStopped = "RecordingStopped"
    case vadDetected = "VADDetected"
    case silenceDetected = "SilenceDetected"
    case audioProcessed = "AudioProcessed"
}

enum APIEvent: String {
    case transcriptionStarted = "TranscriptionStarted"
    case transcriptionCompleted = "TranscriptionCompleted"
    case optimizationStarted = "OptimizationStarted"
    case optimizationCompleted = "OptimizationCompleted"
    case modificationStarted = "ModificationStarted"
    case modificationCompleted = "ModificationCompleted"
    case connectionTest = "ConnectionTest"
    case apiError = "APIError"
}

enum UIEvent: String {
    case floatingBallShown = "FloatingBallShown"
    case floatingBallHidden = "FloatingBallHidden"
    case resultOverlayShown = "ResultOverlayShown"
    case resultOverlayHidden = "ResultOverlayHidden"
    case settingsOpened = "SettingsOpened"
    case settingsClosed = "SettingsClosed"
    case promptConfirmed = "PromptConfirmed"
    case modificationRequested = "ModificationRequested"
}

// MARK: - DateFormatter扩展
extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}
```

## 7. 主应用入口

### 7.1 应用主结构 (HelloPromptApp)

#### 7.1.1 应用生命周期管理
```swift
import SwiftUI

@main
struct HelloPromptApp: App {
    @StateObject private var appManager = AppManager()
    @StateObject private var configManager = ConfigManager()
    
    @State private var isFirstLaunch = true
    
    var body: some Scene {
        // 菜单栏应用 - 主要界面
        MenuBarExtra("Hello Prompt", systemImage: "mic.circle") {
            MenuBarContent(appManager: appManager)
        }
        .menuBarExtraStyle(.window)
        
        // 设置窗口
        Window("设置", id: "settings") {
            SettingsView(configManager: configManager, appManager: appManager)
        }
        .windowResizability(.contentSize)
        .windowStyle(.titleBar)
        .defaultPosition(.center)
        
        // 全屏覆盖层 - 用于显示结果
        Window("Result", id: "result") {
            if appManager.showResultOverlay {
                ResultOverlay(appManager: appManager)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear)
            }
        }
        .windowLevel(.floating)
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

// MARK: - 菜单栏内容
struct MenuBarContent: View {
    @ObservedObject var appManager: AppManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 状态显示
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            Divider()
            
            // 手动录制按钮
            Button(action: {
                Task {
                    await appManager.handleRecordingToggle()
                }
            }) {
                HStack {
                    Image(systemName: "mic.circle")
                    Text("开始录制")
                    Spacer()
                    Text("⌃M")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(appManager.currentState != .idle)
            
            // 设置按钮
            Button(action: {
                appManager.showSettings = true
            }) {
                HStack {
                    Image(systemName: "gearshape")
                    Text("设置")
                }
            }
            
            Divider()
            
            // 退出按钮
            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 200)
    }
    
    private var statusColor: Color {
        switch appManager.currentState {
        case .idle: return .green
        case .recording: return .red
        case .processing: return .orange
        case .result: return .blue
        }
    }
    
    private var statusText: String {
        switch appManager.currentState {
        case .idle: return "就绪"
        case .recording: return "录音中..."
        case .processing: return "处理中..."
        case .result: return "显示结果"
        }
    }
}
```

## 8. 构建配置

### 8.1 项目配置文件

#### 8.1.1 Package.swift
```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "HelloPrompt",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "HelloPrompt", targets: ["HelloPrompt"])
    ],
    dependencies: [
        .package(url: "https://github.com/AudioKit/AudioKit.git", from: "5.6.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "1.14.0"),
        .package(url: "https://github.com/sindresorhus/Defaults.git", from: "7.1.0"),
        .package(url: "https://github.com/MacPaw/OpenAI.git", from: "0.2.4")
    ],
    targets: [
        .executableTarget(
            name: "HelloPrompt",
            dependencies: [
                "AudioKit",
                "KeyboardShortcuts", 
                "Defaults",
                "OpenAI"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "HelloPromptTests",
            dependencies: ["HelloPrompt"]
        )
    ]
)
```

## 9. 性能优化与监控

### 9.1 性能监控指标

#### 9.1.1 关键性能指标 (KPI)
- **启动时间**: 冷启动 ≤ 2秒
- **响应时间**: 快捷键响应 ≤ 100ms
- **处理时延**: 语音转提示词 ≤ 3秒
- **内存占用**: 空闲 ≤ 50MB，峰值 ≤ 100MB
- **电池消耗**: 后台运行每小时 ≤ 2%

#### 9.1.2 性能优化策略
1. **音频处理优化**：使用低缓冲延迟配置，优化VAD算法
2. **网络请求优化**：启用HTTP/2，使用连接池
3. **内存管理**：及时释放音频缓冲区，避免内存泄漏
4. **UI优化**：使用懒加载，减少不必要的重绘

## 10. 错误处理与故障恢复

### 10.1 错误处理策略

#### 10.1.1 分级错误处理
1. **用户可恢复错误**：显示友好提示，提供重试选项
2. **系统错误**：记录详细日志，优雅降级
3. **致命错误**：保存用户数据，安全退出

#### 10.1.2 自动恢复机制
- API调用失败自动重试（最多3次）
- 音频设备异常自动重新初始化
- 配置损坏自动重置为默认值

---

**文档状态**：开发版本  
**最后更新**：2025-07-25  
**技术审批**：待开发团队评审