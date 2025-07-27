# Hello Prompt - 技术设计文档 (TDD)
**版本：V2.0 - 体验驱动版**  
**日期：2025-07-25**  
**设计哲学：认知优先，技术隐藏**

## 1. 以用户认知为中心的架构设计

### 1.1 认知架构理念

传统的技术架构以数据流和系统模块为中心，但Hello Prompt需要以**用户认知过程**为核心构建架构。我们采用三层认知模型：

#### 🧠 认知三层架构
1. **意识层 (Conscious Layer)** - 用户的主动意图和目标
2. **无意识层 (Subconscious Layer)** - 上下文理解和习惯学习
3. **系统层 (System Layer)** - 技术实现和资源管理

这种架构确保技术系统的每个决策都从用户认知角度出发。

### 1.2 认知流动架构图

```
┌────────────────────────────────────────────────────────────────────────────┐
│        🧠 意识层 (Conscious Layer) - 用户主动意图               │
│                                                                    │
│  🎯 Intent Recognition    🗣️ Natural Expression    ✨ Result Preview     │
│      │                          │                         │              │
│      │                          │                         │              │
│  "我需要一个登录组件"    →    AI上下文理解    →    结构化提示词   │
│   (语音输入)                     (意图解析)               (可操作结果)    │
└────────────────────────────────────────────────────────────────────────────┘
                                         │
                              Context-Aware Processing
                                         │
┌────────────────────────────────────────────────────────────────────────────┐
│      🧘 无意识层 (Subconscious Layer) - 智能适应学习              │
│                                                                    │
│ 📊 Context Engine   🧠 Habit Learning    🔄 Adaptive Templates  │
│      │                      │                        │              │
│  环境上下文感知      用户习惯学习        模板动态优化     │
│ (应用状态、工作流)   (偏好记忆、操作习惯)     (智能推荐算法)     │
└────────────────────────────────────────────────────────────────────────────┘
                                         │
                              Invisible Infrastructure
                                         │
┌────────────────────────────────────────────────────────────────────────────┐
│        🔧 系统层 (System Layer) - 技术基础设施                │
│                                                                    │
│  🎤 Audio Engine     🌐 AI Services      💾 Persistent State  │
│       │                       │                        │              │
│   高质量音频处理         多平台AI集成        数据安全存储      │
│ (阶数滤化，VAD检测)     (智能路由，失败转移)      (Keychain加密)     │
└────────────────────────────────────────────────────────────────────────────┘

💡 核心设计原则：
• 意识层为用户所见，体验极简直观
• 无意识层隐藏复杂性，提供智能支持
• 系统层完全透明，确保可靠稳定
```

### 1.3 体验驱动的技术选型

#### 1.3.1 认知优先技术栈
传统选型关注性能和模块化，但我们**以用户认知负荷为最高优先级**：

```swift
// 认知优先的技术决策
struct CognitiveTechStack {
    // 意识层技术：用户直接感知
    let userInterface: SwiftUI         // 最直观的声明式语法
    let animation: CoreAnimation       // 最自然的视觉反馈
    let haptics: CoreHaptics          // 最即时的触觉响应
    
    // 无意识层技术：智能适应学习
    let contextEngine: Combine         // 最自然的状态流动
    let machineLearning: CreateML      // 最轻量的本地学习
    let patternMining: NaturalLanguage // 最精准的意图理解
    
    // 系统层技术：无感基础设施
    let audio: AVFoundation           // Apple原生最稳定
    let security: Security            // 系统级安全保障
    let networking: URLSession        // 最可靠的网络层
}
```

#### 1.3.2 体验质量保证依赖
```swift
// Package.swift - 以体验质量为核心的依赖选择
dependencies: [
    // 🎤 音频体验优化
    .package(url: "https://github.com/AudioKit/AudioKit.git", from: "5.6.0"),
    .package(url: "https://github.com/apple/swift-algorithms.git", from: "1.0.0"),
    
    // 🧠 认知负荷优化
    .package(url: "https://github.com/sindresorhus/Defaults.git", from: "7.1.0"),
    .package(url: "https://github.com/SwiftUIX/SwiftUIX.git", from: "0.1.4"),
    
    // 🔒 用户信任保障
    .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.8.0"),
    
    // 📊 体验分析优化 (Debug only)
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", from: "1.0.0")
]
```

#### 🧠 认知负荷分析与技术决策

| 认知挑战 | 传统解决方案 | 我们的体验优先选择 | 原因 |
|------------|-------------|-----------------|------|
| 语音输入延迟 | 异步处理 | AVFoundation + 实时流处理 | 用户期望立即反馈 |
| 上下文理解 | 复杂AI模型 | NaturalLanguage + 本地学习 | 隐私保护 + 低延迟 |
| 状态管理复杂性 | Redux/MobX | Combine + SwiftUI绑定 | 声明式心智模型 |
| 网络不稳定 | 重试机制 | 多层级备份 + 本地降级 | 保证可用性优先 |

### 1.4 体验驱动的架构决策 (Experience-Driven ADR)

#### ✨ EDR-001: 采用"意识流动"架构模式
**体验目标**：用户的意识流从"想法"到"结果"应该像水一样自然流动  
**技术实现**：使用Combine + SwiftUI构建反应式数据流，每个用户操作都立即反映在界面上  
**认知依据**：用户的大脑期望在150ms内看到视觉反馈，否则会感知到"卡顿"  
**风险缓解**：实现乐观更新机制，即使处理失败也先展示结果

#### 🧠 EDR-002: 采用"上下文保持"设计模式
**体验目标**：用户不应该重复提供相同的上下文信息  
**技术实现**：使用NaturalLanguage框架 + CreateML建立用户的认知模型  
**认知依据**：人类的工作记忆只能保持7±2个信息块，超出就会产生认知负荷  
**实现策略**：自动记忆用户的技术栈、编码风格、项目上下文

#### 🔒 EDR-003: 采用"隐私意识"安全模式
**体验目标**：用户不应该担心创意想法被泄露或滥用  
**技术实现**：采用"本地优先"架构，只有在必要时才使用云端API  
**信任建立**：所有语音数据在本地处理完成后立即销毁，绝不上传  
**透明化**：用户可以随时了解数据流向和使用情况

#### 🌐 EDR-004: 采用"多层级备份"网络架构
**体验目标**：用户永远不应该因为网络问题失去创作灵感  
**技术实现**：优先使用URLSession（系统原生最稳定），备份多个AI提供商  
**认知优先**：性能不是用户最关心的，可预测性和可靠性才是  
**实现策略**：OpenAI → Claude → 本地Whisper → 简化模式的智能路由

#### 🏠 EDR-005: 采用"零配置启动"模式
**体验目标**：用户下载后应该能立即体验到价值，而不是面对复杂配置  
**技术实现**：使用macOS系统的语音识别 + 本地模板库实现基础功能  
**渐进式增强**：只有在用户主动需要高级功能时才提示API配置  
**信任建立**：让用户先感受到价值，再决定是否投入更多

## 2. 三层认知架构的技术实现

### 2.1 意识层 (Conscious Layer) - 用户感知接口

#### 2.1.1 自然表达接口设计
**设计原则**：用户不应该学习如何与工具交流，工具应该理解用户的自然表达

```swift
// 意识层核心组件
struct ConsciousInterface {
    // 🎯 意图识别引擎
    let intentRecognizer: IntentRecognitionEngine
    // 🗣️ 自然语言处理
    let naturalProcessor: NaturalExpressionEngine  
    // ✨ 结果预览系统
    let resultPreview: ResultPreviewEngine
}

// 意图识别的认知模型
struct UserIntent {
    let domain: CreativeDomain        // 编程/设计/写作
    let specificity: Float           // 具体程度 0.0-1.0
    let confidence: Float           // 识别置信度
    let context: WorkingContext      // 当前工作环境
    let emotionalTone: EmotionalContext // 情感色彩
}

// 自然表达处理
class NaturalExpressionEngine {
    func processVoiceInput(_ audio: AudioBuffer) async -> ProcessedIntent {
        // 1. 实时语音转文本 (< 500ms)
        let transcript = await speechToText(audio)
        
        // 2. 意图理解和上下文融合
        let intent = await understandIntent(transcript, context: currentContext)
        
        // 3. 认知负荷最小化 - 自动补全缺失信息
        let enrichedIntent = await enrichWithContext(intent)
        
        return enrichedIntent
    }
    
    private func understandIntent(_ text: String, context: WorkingContext) async -> UserIntent {
        // 使用NaturalLanguage框架进行本地处理
        // 避免云端依赖，保护隐私
        let tagger = NLTagger(tagSchemes: [.sentimentScore, .language])
        tagger.string = text
        
        // 情感分析 - 理解用户的迫切程度
        let sentiment = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        
        // 领域识别 - 基于关键词和上下文
        let domain = identifyDomain(text, context: context)
        
        return UserIntent(
            domain: domain,
            specificity: calculateSpecificity(text),
            confidence: calculateConfidence(text, context),
            context: context,
            emotionalTone: EmotionalContext(sentiment: sentiment)
        )
    }
}
```

#### 2.1.2 零摩擦视觉反馈系统
**设计原则**：用户的每个意图都应该得到即时、直观的视觉确认

```swift
// 结果预览的认知优化
class ResultPreviewEngine: ObservableObject {
    @Published var previewState: PreviewState = .idle
    @Published var confidence: Float = 0.0
    @Published var progressIndicator: ProgressState = .hidden
    
    func showOptimisticPreview(_ intent: UserIntent) {
        // 乐观更新：立即显示预期结果
        withAnimation(.easeOut(duration: 0.15)) {
            previewState = .generating(preview: generateOptimisticPreview(intent))
        }
        
        // 后台真实处理
        Task {
            let realResult = await processIntent(intent)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    previewState = .completed(result: realResult)
                }
            }
        }
    }
    
    private func generateOptimisticPreview(_ intent: UserIntent) -> PreviewContent {
        // 基于历史模式和机器学习快速生成预览
        // 即使AI处理失败，用户也能看到即时反馈
        switch intent.domain {
        case .programming:
            return generateCodePreview(intent)
        case .design:
            return generateDesignPreview(intent)
        case .writing:
            return generateWritingPreview(intent)
        }
    }
}

// 视觉反馈的认知心理学优化
struct CognitiveVisualFeedback: View {
    @StateObject private var previewEngine = ResultPreviewEngine()
    @State private var pulseAnimation = false
    
    var body: some View {
        VStack(spacing: 12) {
            // 听觉状态指示 - 模拟自然呼吸节律
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.green.opacity(0.8), .green.opacity(0.3)],
                        center: .center,
                        startRadius: 5,
                        endRadius: pulseAnimation ? 25 : 15
                    )
                )
                .frame(width: 50, height: 50)
                .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: pulseAnimation
                )
                .onAppear { pulseAnimation = true }
            
            // 处理状态可视化
            if case .generating(let preview) = previewEngine.previewState {
                VStack(alignment: .leading, spacing: 8) {
                    // 置信度指示器
                    HStack {
                        Text("理解程度")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(previewEngine.confidence * 100))%")
                            .font(.caption.weight(.medium))
                            .foregroundColor(confidenceColor(previewEngine.confidence))
                    }
                    
                    // 动态置信度条
                    ProgressView(value: previewEngine.confidence)
                        .tint(confidenceColor(previewEngine.confidence))
                        .animation(.easeInOut(duration: 0.5), value: previewEngine.confidence)
                }
                .padding()
                .background(Material.ultraThin, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private func confidenceColor(_ confidence: Float) -> Color {
        switch confidence {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
}
```

### 2.2 无意识层 (Subconscious Layer) - 智能适应系统

#### 2.2.1 上下文感知引擎
**设计原则**：系统应该像一个有经验的助理，理解用户的工作模式和偏好

```swift
// 上下文感知的认知模型
class ContextEngine: ObservableObject {
    @Published private(set) var currentContext: WorkingContext
    private let contextHistory: ContextHistoryManager
    private let patternAnalyzer: PatternAnalyzer
    
    init() {
        self.currentContext = WorkingContext()
        self.contextHistory = ContextHistoryManager()
        self.patternAnalyzer = PatternAnalyzer()
        
        startContextMonitoring()
    }
    
    private func startContextMonitoring() {
        // 监听系统事件，构建上下文画像
        NotificationCenter.default.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] notification in
                self?.updateApplicationContext(notification)
            }
            .store(in: &cancellables)
        
        // 监听文件系统变化
        FileSystemWatcher.shared.fileChanges
            .sink { [weak self] change in
                self?.updateFileContext(change)
            }
            .store(in: &cancellables)
    }
    
    func analyzeUserPattern(_ intent: UserIntent, result: PromptResult) {
        // 机器学习模式分析
        let pattern = UserPattern(
            timestamp: Date(),
            intent: intent,
            result: result,
            context: currentContext,
            satisfaction: result.userFeedback?.satisfaction ?? 0.5
        )
        
        patternAnalyzer.addPattern(pattern)
        
        // 实时调整预测模型
        if patternAnalyzer.hasEnoughData {
            updatePredictionModels()
        }
    }
    
    private func updatePredictionModels() {
        Task {
            // 使用CreateML进行轻量级本地学习
            let patterns = patternAnalyzer.getAllPatterns()
            let model = try await MLModelBuilder.buildIntentPredictionModel(from: patterns)
            
            await MainActor.run {
                self.predictiveModel = model
            }
        }
    }
}

// 工作上下文的多维度建模
struct WorkingContext {
    // 应用环境
    let activeApplication: String
    let openFiles: [FileContext]
    let projectType: ProjectType
    
    // 时间模式
    let timeOfDay: TimeContext
    let workSession: WorkSessionContext
    let recentActivity: [UserActivity]
    
    // 技术环境
    let codeLanguage: ProgrammingLanguage?
    let frameworks: [Framework]
    let designTools: [DesignTool]
    
    // 个人偏好 (从历史行为学习)
    let preferredStyleGuides: [StyleGuide]
    let frequentPatterns: [TemplatePattern]
    let communicationStyle: CommunicationStyle
}
```

#### 2.2.2 习惯学习与个性化
**设计原则**：系统应该学习用户的偏好，而不是让用户适应系统

```swift
// 习惯学习的认知科学模型
class HabitLearningEngine {
    private let memoryModel: LongTermMemoryModel
    private let preferenceExtractor: PreferenceExtractor
    private let adaptationEngine: AdaptationEngine
    
    func learnFromUserBehavior(_ interaction: UserInteraction) {
        // 1. 提取行为特征
        let features = extractBehaviorFeatures(interaction)
        
        // 2. 更新长期记忆模型
        memoryModel.updateMemory(features)
        
        // 3. 识别偏好变化
        let preferences = preferenceExtractor.extractPreferences(from: features)
        
        // 4. 自适应调整
        adaptationEngine.adapt(to: preferences)
    }
    
    private func extractBehaviorFeatures(_ interaction: UserInteraction) -> BehaviorFeatures {
        return BehaviorFeatures(
            // 语言偏好
            vocabularyLevel: analyzeVocabularyComplexity(interaction.input),
            technicalDepth: analyzeTechnicalDepth(interaction.input),
            communicationStyle: analyzeCommunicationStyle(interaction.input),
            
            // 修改模式
            iterationPatterns: analyzeIterationPatterns(interaction.modifications),
            commonAdjustments: findCommonAdjustments(interaction.modifications),
            
            // 满意度指标
            acceptanceRate: calculateAcceptanceRate(interaction.feedback),
            timeToAcceptance: calculateTimeToAcceptance(interaction.timeline)
        )
    }
}

// 个性化模板系统
class AdaptiveTemplateEngine {
    private var userTemplates: [UserTemplate] = []
    private let templateOptimizer: TemplateOptimizer
    
    func generatePersonalizedPrompt(_ intent: UserIntent, context: WorkingContext) async -> String {
        // 1. 选择最匹配的基础模板
        let baseTemplate = selectBestTemplate(for: intent, context: context)
        
        // 2. 基于用户历史偏好调整
        let personalizedTemplate = personalizeTemplate(baseTemplate, for: context.userProfile)
        
        // 3. 应用上下文特定的优化
        let contextOptimized = optimizeForContext(personalizedTemplate, context: context)
        
        // 4. 实时质量评估和调整
        let qualityScore = await evaluateTemplateQuality(contextOptimized, intent: intent)
        
        if qualityScore < 0.8 {
            // 质量不够，尝试替代策略
            return await generateAlternativePrompt(intent, context: context)
        }
        
        return contextOptimized
    }
    
    private func personalizeTemplate(_ template: Template, for profile: UserProfile) -> Template {
        var personalized = template
        
        // 调整技术细节层次
        if profile.prefersHighLevelAbstraction {
            personalized = simplifyTechnicalDetails(personalized)
        } else if profile.prefersImplementationDetails {
            personalized = enrichWithImplementationDetails(personalized)
        }
        
        // 调整代码风格偏好
        personalized = applyCodeStylePreferences(personalized, profile.codeStyle)
        
        // 调整交流风格
        personalized = adaptCommunicationStyle(personalized, profile.communicationStyle)
        
        return personalized
    }
}
```

### 2.3 系统层 (System Layer) - 可靠基础设施

#### 2.3.1 多层级容错架构
**设计原则**：技术故障不应该影响用户的创作流程

```swift
// 多层级AI服务架构
class AIServiceOrchestrator {
    private let primaryService: OpenAIService
    private let fallbackServices: [AIService]
    private let localService: LocalWhisperService
    private let emergencyService: RuleBasedService
    private let healthMonitor: ServiceHealthMonitor
    
    func processPromptRequest(_ request: PromptRequest) async throws -> PromptResponse {
        // 健康检查和智能路由
        let availableServices = await healthMonitor.getHealthyServices()
        
        for service in availableServices {
            do {
                let response = try await service.processPrompt(request)
                
                // 成功后更新服务质量评分
                await healthMonitor.recordSuccess(for: service)
                
                return response
            } catch {
                // 记录失败，但不中断流程
                await healthMonitor.recordFailure(for: service, error: error)
                
                // 继续尝试下一个服务
                logger.warning("Service \(service.name) failed, trying next: \(error)")
            }
        }
        
        // 所有服务都失败，使用本地降级
        logger.info("All cloud services failed, falling back to local processing")
        return try await processLocally(request)
    }
    
    private func processLocally(_ request: PromptRequest) async throws -> PromptResponse {
        // 本地Whisper模型 + 规则引擎
        let localResponse = try await localService.processPrompt(request)
        
        // 如果本地处理也失败，使用紧急规则系统
        if localResponse.confidence < 0.6 {
            return emergencyService.generateBasicResponse(request)
        }
        
        return localResponse
    }
}

// 服务健康监控系统
class ServiceHealthMonitor: ObservableObject {
    @Published private(set) var serviceStatuses: [String: ServiceStatus] = [:]
    
    private let healthCheckInterval: TimeInterval = 30.0
    private var healthCheckTimer: Timer?
    
    func startMonitoring() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: healthCheckInterval, repeats: true) { _ in
            Task { await self.performHealthChecks() }
        }
    }
    
    private func performHealthChecks() async {
        await withTaskGroup(of: (String, ServiceStatus).self) { group in
            for service in allServices {
                group.addTask {
                    let status = await self.checkServiceHealth(service)
                    return (service.name, status)
                }
            }
            
            for await (serviceName, status) in group {
                await MainActor.run {
                    self.serviceStatuses[serviceName] = status
                }
            }
        }
    }
    
    private func checkServiceHealth(_ service: AIService) async -> ServiceStatus {
        do {
            let startTime = Date()
            _ = try await service.healthCheck()
            let responseTime = Date().timeIntervalSince(startTime)
            
            return ServiceStatus(
                isHealthy: true,
                responseTime: responseTime,
                lastChecked: Date(),
                errorCount: 0
            )
        } catch {
            return ServiceStatus(
                isHealthy: false,
                responseTime: nil,
                lastChecked: Date(),
                errorCount: serviceStatuses[service.name]?.errorCount.map { $0 + 1 } ?? 1,
                lastError: error
            )
        }
    }
}
```

#### 2.3.2 隐私保护音频处理
**设计原则**：用户的创意内容是私密的，应该得到最高级别的保护

```swift
// 隐私优先的音频处理引擎
class PrivacyFirstAudioEngine {
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer: SFSpeechRecognizer
    private let localWhisper: LocalWhisperEngine
    private var audioBuffer: CircularAudioBuffer
    
    func startRecording() async throws {
        // 音频数据仅在内存中处理，从不写入磁盘
        audioBuffer = CircularAudioBuffer(maxDuration: 30.0) // 最多30秒
        
        // 配置音频会话
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // 实时音频处理
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
        
        try audioEngine.start()
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // 实时VAD检测
        let vadResult = VoiceActivityDetector.analyze(buffer)
        
        if vadResult.isSpeech {
            // 添加到循环缓冲区
            audioBuffer.append(buffer)
            
            // 实时降噪处理
            let denoisedBuffer = AudioDenoiser.denoise(buffer)
            
            // 触发实时识别预览（本地）
            Task {
                await self.updateLiveTranscription(denoisedBuffer)
            }
        } else if vadResult.isSilence && vadResult.silenceDuration > 0.5 {
            // 检测到静音，完成录制
            await finishRecording()
        }
    }
    
    private func finishRecording() async {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // 获取完整音频数据
        let finalAudio = audioBuffer.getFinalAudio()
        
        // 立即处理并清除
        let transcript = await processAudioToText(finalAudio)
        
        // 关键：立即销毁音频数据
        audioBuffer.clear()
        finalAudio.deallocate()
        
        // 仅保留文本结果用于提示词生成
        await generatePromptFromTranscript(transcript)
    }
    
    private func processAudioToText(_ audio: AVAudioPCMBuffer) async -> String {
        // 优先使用本地处理
        if LocalWhisperEngine.isAvailable {
            return await localWhisper.transcribe(audio)
        }
        
        // 必要时使用云端，但仅发送音频，不存储
        return await cloudTranscribe(audio)
    }
    
    private func cloudTranscribe(_ audio: AVAudioPCMBuffer) async -> String {
        do {
            // 压缩音频以减少传输时间和大小
            let compressedAudio = AudioCompressor.compress(audio, quality: .speech)
            
            // 发送到云端处理
            let transcript = try await OpenAIService.shared.transcribe(compressedAudio)
            
            // 立即清除压缩数据
            compressedAudio.deallocate()
            
            return transcript
        } catch {
            logger.error("Cloud transcription failed: \(error)")
            
            // 降级到本地简化处理
            return await LocalBasicTranscriber.transcribe(audio)
        }
    }
}

// 循环音频缓冲区 - 内存安全
class CircularAudioBuffer {
    private let maxSamples: Int
    private var buffer: [Float]
    private var writeIndex: Int = 0
    private var sampleCount: Int = 0
    
    init(maxDuration: TimeInterval, sampleRate: Double = 16000) {
        self.maxSamples = Int(maxDuration * sampleRate)
        self.buffer = Array(repeating: 0.0, count: maxSamples)
    }
    
    func append(_ audioBuffer: AVAudioPCMBuffer) {
        guard let floatChannelData = audioBuffer.floatChannelData else { return }
        
        let frameCount = Int(audioBuffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: floatChannelData[0], count: frameCount))
        
        for sample in samples {
            buffer[writeIndex] = sample
            writeIndex = (writeIndex + 1) % maxSamples
            sampleCount = min(sampleCount + 1, maxSamples)
        }
    }
    
    func getFinalAudio() -> AVAudioPCMBuffer {
        // 创建最终音频缓冲区
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let finalBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount))!
        
        finalBuffer.frameLength = AVAudioFrameCount(sampleCount)
        
        // 复制音频数据
        let floatChannelData = finalBuffer.floatChannelData![0]
        if writeIndex >= sampleCount {
            // 数据没有循环，直接复制
            for i in 0..<sampleCount {
                floatChannelData[i] = buffer[writeIndex - sampleCount + i]
            }
        } else {
            // 数据已循环，需要重新排列
            let firstPart = maxSamples - (sampleCount - writeIndex)
            for i in 0..<(sampleCount - writeIndex) {
                floatChannelData[i] = buffer[firstPart + i]
            }
            for i in 0..<writeIndex {
                floatChannelData[sampleCount - writeIndex + i] = buffer[i]
            }
        }
        
        return finalBuffer
    }
    
    func clear() {
        // 安全清除敏感数据
        buffer.removeAll()
        buffer = Array(repeating: 0.0, count: maxSamples)
        writeIndex = 0
        sampleCount = 0
    }
    
    deinit {
        // 确保在对象销毁时清除敏感数据
        clear()
    }
}
```

## 3. 认知优化的实现细节

### 3.1 意图理解的多维度分析

#### 3.1.1 语义理解与情感计算
```swift
// 深度语义分析引擎
class SemanticUnderstandingEngine {
    private let nlProcessor: NLProcessor
    private let intentClassifier: IntentClassifier
    private let emotionAnalyzer: EmotionAnalyzer
    
    func analyzeUserInput(_ input: String, context: WorkingContext) async -> SemanticAnalysis {
        async let semanticFeatures = extractSemanticFeatures(input)
        async let intentVector = classifyIntent(input, context)
        async let emotionalState = analyzeEmotionalState(input)
        async let urgencyLevel = calculateUrgency(input, context)
        
        let results = await (semanticFeatures, intentVector, emotionalState, urgencyLevel)
        
        return SemanticAnalysis(
            semantics: results.0,
            intent: results.1,
            emotion: results.2,
            urgency: results.3,
            confidence: calculateOverallConfidence(results)
        )
    }
    
    private func extractSemanticFeatures(_ input: String) async -> SemanticFeatures {
        // 使用NaturalLanguage框架进行本地处理
        let tagger = NLTagger(tagSchemes: [.tokenType, .lexicalClass, .nameType])
        tagger.string = input
        
        var keywords: [String] = []
        var entities: [String] = []
        var technicalTerms: [String] = []
        
        tagger.enumerateTags(in: input.startIndex..<input.endIndex, unit: .word, scheme: .tokenType) { tag, range in
            let word = String(input[range])
            
            if let tag = tag {
                switch tag {
                case .word:
                    // 技术术语识别
                    if TechnicalTermDictionary.contains(word.lowercased()) {
                        technicalTerms.append(word)
                    } else {
                        keywords.append(word)
                    }
                case .other:
                    // 可能是专有名词或实体
                    entities.append(word)
                default:
                    break
                }
            }
            
            return true
        }
        
        return SemanticFeatures(
            keywords: keywords,
            entities: entities,
            technicalTerms: technicalTerms,
            complexity: calculateSemanticComplexity(input),
            abstractionLevel: calculateAbstractionLevel(keywords)
        )
    }
    
    private func analyzeEmotionalState(_ input: String) async -> EmotionalState {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = input
        
        let sentiment = tagger.tag(at: input.startIndex, unit: .paragraph, scheme: .sentimentScore)
        let sentimentScore = Double(sentiment?.rawValue ?? "0") ?? 0.0
        
        // 分析语言模式中的情感指标
        let urgencyMarkers = countUrgencyMarkers(input)
        let uncertaintyMarkers = countUncertaintyMarkers(input)
        let frustrationMarkers = countFrustrationMarkers(input)
        
        return EmotionalState(
            sentiment: sentimentScore,
            urgency: Double(urgencyMarkers) / Double(input.count) * 1000,
            uncertainty: Double(uncertaintyMarkers) / Double(input.count) * 1000,
            frustration: Double(frustrationMarkers) / Double(input.count) * 1000
        )
    }
}
```

#### 3.1.2 上下文融合与推理
```swift
// 上下文推理引擎
class ContextualReasoningEngine {
    private let contextDB: ContextDatabase
    private let patternMatcher: PatternMatcher
    private let inferenceEngine: InferenceEngine
    
    func enrichIntentWithContext(_ intent: UserIntent, context: WorkingContext) async -> EnrichedIntent {
        // 1. 历史模式匹配
        let historicalPatterns = await findSimilarPatterns(intent, in: contextDB)
        
        // 2. 当前环境推理
        let environmentalClues = extractEnvironmentalClues(context)
        
        // 3. 缺失信息推断
        let inferredDetails = await inferMissingDetails(intent, 
                                                       patterns: historicalPatterns,
                                                       environment: environmentalClues)
        
        // 4. 质量验证
        let confidenceScore = calculateEnrichmentConfidence(intent, inferredDetails)
        
        return EnrichedIntent(
            originalIntent: intent,
            inferredDetails: inferredDetails,
            confidence: confidenceScore,
            reasoning: generateReasoningTrace(historicalPatterns, environmentalClues)
        )
    }
    
    private func extractEnvironmentalClues(_ context: WorkingContext) -> EnvironmentalClues {
        var clues = EnvironmentalClues()
        
        // 从活跃应用推断技术栈
        if context.activeApplication.contains("Xcode") {
            clues.likelyTechStack = [.swift, .ios, .macos]
        } else if context.activeApplication.contains("VSCode") {
            clues.likelyTechStack = inferTechStackFromFiles(context.openFiles)
        }
        
        // 从项目结构推断架构模式
        if context.openFiles.contains(where: { $0.path.contains("MVVM") }) {
            clues.likelyArchitecture = .mvvm
        } else if context.openFiles.contains(where: { $0.path.contains("Redux") }) {
            clues.likelyArchitecture = .redux
        }
        
        // 从时间模式推断紧急程度
        if context.timeOfDay.isWorkingHours && context.workSession.duration > .hours(4) {
            clues.likelyUrgency = .high
        }
        
        return clues
    }
    
    private func inferMissingDetails(_ intent: UserIntent, 
                                   patterns: [HistoricalPattern],
                                   environment: EnvironmentalClues) async -> InferredDetails {
        
        var details = InferredDetails()
        
        // 推断技术栈
        if intent.technicalStack.isEmpty {
            details.suggestedTechStack = environment.likelyTechStack
        }
        
        // 推断实现细节层次
        if intent.specificity < 0.5 {
            // 用户给出的信息不够具体，基于历史偏好推断
            let avgSpecificity = patterns.map(\.specificity).average()
            if avgSpecificity > 0.7 {
                details.suggestedDetailLevel = .detailed
            } else {
                details.suggestedDetailLevel = .highlevel
            }
        }
        
        // 推断代码风格偏好
        if let codeStylePattern = patterns.first(where: { $0.type == .codeStyle }) {
            details.suggestedCodeStyle = codeStylePattern.codeStyle
        } else {
            details.suggestedCodeStyle = environment.likelyCodeStyle
        }
        
        return details
    }
}
```

### 3.2 性能优化与资源管理

#### 3.2.1 智能缓存与预加载
```swift
// 认知感知的缓存系统
class CognitiveCache {
    private let memoryCache = NSCache<NSString, CacheItem>()
    private let diskCache: DiskCache
    private let usagePredictor: UsagePredictionEngine
    
    init() {
        self.diskCache = DiskCache()
        self.usagePredictor = UsagePredictionEngine()
        
        // 基于用户行为模式的智能缓存配置
        configureCacheBasedOnUserPatterns()
    }
    
    func getTemplate(for intent: UserIntent, context: WorkingContext) async -> Template? {
        let cacheKey = generateCacheKey(intent, context)
        
        // 1. 内存缓存查找
        if let cached = memoryCache.object(forKey: cacheKey as NSString) {
            await recordCacheHit(cacheKey)
            return cached.template
        }
        
        // 2. 磁盘缓存查找
        if let diskCached = await diskCache.get(key: cacheKey) {
            // 提升到内存缓存
            memoryCache.setObject(diskCached, forKey: cacheKey as NSString)
            await recordCacheHit(cacheKey)
            return diskCached.template
        }
        
        // 3. 预测性加载
        if await usagePredictor.isProbablyNeeded(intent, context) {
            Task {
                await preloadRelatedTemplates(intent, context)
            }
        }
        
        return nil
    }
    
    private func configureCacheBasedOnUserPatterns() {
        // 根据用户的内存使用习惯配置缓存大小
        let availableMemory = ProcessInfo.processInfo.physicalMemory
        let userMemoryProfile = UserProfileManager.shared.memoryUsageProfile
        
        switch userMemoryProfile {
        case .conservative:
            memoryCache.totalCostLimit = Int(availableMemory / 100) // 1%
        case .balanced:
            memoryCache.totalCostLimit = Int(availableMemory / 50)  // 2%
        case .aggressive:
            memoryCache.totalCostLimit = Int(availableMemory / 25)  // 4%
        }
        
        // 配置过期策略
        memoryCache.evictsObjectsWithDiscardedContent = true
    }
    
    private func preloadRelatedTemplates(_ intent: UserIntent, _ context: WorkingContext) async {
        // 基于机器学习预测用户接下来可能需要的模板
        let predictions = await usagePredictor.predictNextLikelyIntents(intent, context)
        
        for prediction in predictions.prefix(3) { // 最多预加载3个
            if prediction.probability > 0.6 {
                let template = await TemplateEngine.shared.generate(for: prediction.intent, context: context)
                let cacheKey = generateCacheKey(prediction.intent, context)
                
                // 存储到内存缓存，优先级较低
                let cacheItem = CacheItem(template: template, priority: .predictive)
                memoryCache.setObject(cacheItem, forKey: cacheKey as NSString)
            }
        }
    }
}

// 使用预测引擎优化用户体验
class UsagePredictionEngine {
    private let mlModel: UsagePredictionModel
    private let patternAnalyzer: UserPatternAnalyzer
    
    func predictNextLikelyIntents(_ currentIntent: UserIntent, _ context: WorkingContext) async -> [IntentPrediction] {
        // 1. 基于历史序列模式
        let sequencePatterns = patternAnalyzer.findSequencePatterns(ending: currentIntent)
        
        // 2. 基于上下文相似性
        let contextualSimilarity = await findContextuallySimilarSessions(context)
        
        // 3. 机器学习预测
        let mlPredictions = await mlModel.predict(currentIntent: currentIntent, context: context)
        
        // 4. 融合多种预测源
        return combinePrections(sequencePatterns, contextualSimilarity, mlPredictions)
    }
    
    func isProbablyNeeded(_ intent: UserIntent, _ context: WorkingContext) async -> Bool {
        // 快速启发式判断
        let quickScore = calculateQuickRelevanceScore(intent, context)
        if quickScore > 0.8 { return true }
        if quickScore < 0.3 { return false }
        
        // 详细预测分析
        let predictions = await predictNextLikelyIntents(intent, context)
        return predictions.first?.probability ?? 0.0 > 0.5
    }
}
```

## 4. 错误处理与优雅降级

### 4.1 用户友好的错误处理
```swift
// 认知友好的错误处理系统
class CognitiveErrorHandler {
    private let errorRecoveryEngine: ErrorRecoveryEngine
    private let userCommunicator: UserCommunicator
    
    func handleError(_ error: Error, context: OperationContext) async -> RecoveryResult {
        // 1. 错误分类和影响评估
        let errorClassification = classifyError(error, context: context)
        
        // 2. 自动恢复尝试
        if let autoRecovery = await attemptAutoRecovery(errorClassification) {
            return autoRecovery
        }
        
        // 3. 用户友好的错误解释
        let userMessage = generateUserFriendlyMessage(errorClassification)
        
        // 4. 提供可行的恢复选项
        let recoveryOptions = generateRecoveryOptions(errorClassification)
        
        // 5. 保持用户流程连续性
        return await presentRecoveryOptions(userMessage, recoveryOptions, context)
    }
    
    private func classifyError(_ error: Error, context: OperationContext) -> ErrorClassification {
        switch error {
        case let networkError as URLError:
            return .network(
                type: classifyNetworkError(networkError),
                impact: .disruption,
                recoverability: .automatic,
                userVisible: true
            )
            
        case let speechError as SpeechRecognitionError:
            return .speechProcessing(
                type: classifySpeechError(speechError),
                impact: .partial,
                recoverability: .withUserHelp,
                userVisible: true
            )
            
        case let aiError as AIServiceError:
            return .aiProcessing(
                type: classifyAIError(aiError),
                impact: .degradation,
                recoverability: .fallback,
                userVisible: false
            )
            
        default:
            return .unknown(
                error: error,
                impact: .unknown,
                recoverability: .manual,
                userVisible: true
            )
        }
    }
    
    private func generateUserFriendlyMessage(_ classification: ErrorClassification) -> UserMessage {
        switch classification {
        case .network(let type, _, _, _):
            switch type {
            case .timeout:
                return UserMessage(
                    title: "网络响应较慢",
                    message: "AI服务响应时间较长，我们正在尝试其他服务器",
                    tone: .reassuring,
                    actionable: true
                )
            case .noConnection:
                return UserMessage(
                    title: "网络连接问题",
                    message: "检测到网络问题，将使用本地模式继续工作",
                    tone: .informative,
                    actionable: false
                )
            }
            
        case .speechProcessing(let type, _, _, _):
            switch type {
            case .noiseInterference:
                return UserMessage(
                    title: "环境噪音较大",
                    message: "建议在安静环境中重新录制，或调高麦克风灵敏度",
                    tone: .helpful,
                    actionable: true
                )
            case .unclear:
                return UserMessage(
                    title: "语音不够清晰",
                    message: "可以重新说一遍，或者尝试更慢更清晰的语速",
                    tone: .encouraging,
                    actionable: true
                )
            }
            
        default:
            return UserMessage(
                title: "遇到了小问题",
                message: "我们正在努力解决，您可以稍后重试",
                tone: .apologetic,
                actionable: true
            )
        }
    }
}

// 优雅降级策略
class GracefulDegradationEngine {
    func createDegradedExperience(for intent: UserIntent, reason: DegradationReason) -> DegradedExperience {
        switch reason {
        case .networkUnavailable:
            return createOfflineExperience(intent)
        case .aiServiceDown:
            return createRuleBasedExperience(intent)
        case .lowQualityInput:
            return createSimplifiedExperience(intent)
        case .resourceConstrained:
            return createLightweightExperience(intent)
        }
    }
    
    private func createOfflineExperience(_ intent: UserIntent) -> DegradedExperience {
        return DegradedExperience(
            mode: .offline,
            capabilities: [
                .basicSpeechToText,     // 使用系统语音识别
                .templateBasedGeneration, // 本地模板库
                .simpleModifications    // 简单文本操作
            ],
            limitations: [
                "高级AI优化暂时不可用",
                "提示词质量可能较基础",
                "无法学习新的个性化偏好"
            ],
            userMessage: "当前处于离线模式，提供基础功能。网络恢复后将自动升级体验。"
        )
    }
    
    private func createRuleBasedExperience(_ intent: UserIntent) -> DegradedExperience {
        return DegradedExperience(
            mode: .ruleBased,
            capabilities: [
                .patternMatching,       // 基于规则的模式匹配
                .templateSubstitution,  // 模板变量替换
                .basicOptimization     // 简单的文本优化
            ],
            limitations: [
                "使用预设规则生成提示词",
                "缺少AI的创造性优化",
                "个性化程度有限"
            ],
            userMessage: "AI服务暂时不可用，使用智能规则引擎提供服务。"
        )
    }
}
```

## 5. 总结与展望

### 5.1 体验驱动架构的核心价值

这种以认知为中心的技术架构设计具有以下核心优势：

1. **认知负荷最小化**：用户无需学习复杂的操作流程，系统适应用户的自然思维模式
2. **上下文智能感知**：系统像有经验的助理一样理解用户的工作环境和习惯
3. **优雅的错误处理**：技术问题不会打断用户的创作流程，系统提供透明的降级方案
4. **隐私意识设计**：从架构层面保护用户的创意内容和个人隐私
5. **持续学习适应**：系统会随着使用而变得更智能，更符合个人偏好

### 5.2 技术实现的创新点

1. **三层认知架构**：将用户体验分解为意识层、无意识层和系统层，确保每层都有明确的责任和优化目标
2. **多模态错误恢复**：不依赖单一技术栈，通过多层级备份确保服务的连续性
3. **认知感知缓存**：基于用户行为模式的智能预加载和缓存策略
4. **隐私优先音频处理**：端到端的数据保护机制，确保敏感信息不离开用户设备

### 5.3 未来演进方向

这种体验驱动的架构为未来的功能扩展奠定了基础：

1. **多模态输入集成**：轻松扩展支持手势、眼动等其他自然交互方式
2. **团队协作智能**：基于认知模型的团队偏好学习和协作优化
3. **跨平台体验一致性**：认知架构可以移植到其他平台，保持用户体验的一致性
4. **AI能力的无缝升级**：底层AI技术的升级不会影响用户的使用体验

<function_calls>
<invoke name="TodoWrite">
<parameter name="todos">[{"content": "Read and analyze the complete Research.md document", "status": "completed", "priority": "high", "id": "1"}, {"content": "Create PRD document with product definition and 10 complex user flows", "status": "completed", "priority": "high", "id": "2"}, {"content": "Create technical design document with system architecture and module relationships", "status": "completed", "priority": "high", "id": "3"}, {"content": "Create code style documentation with global standards and logging requirements", "status": "completed", "priority": "high", "id": "4"}, {"content": "Review current system design for potential issues", "status": "completed", "priority": "high", "id": "5"}, {"content": "Deep think and experience-driven redesign of PRD & TDD", "status": "completed", "priority": "high", "id": "6"}]