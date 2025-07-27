# Hello Prompt - 技术设计文档 (TDD)
**版本：V1.0**  
**日期：2025-07-25**  
**状态：正式版本**

## 1. 技术架构概述

### 1.1 系统架构概述
Hello Prompt采用分层架构设计，遵循"高内聚、低耦合"原则，分为五层：表示层（UI）、应用层（Services）、领域层（Core）、基础设施层（System）和数据层（Models）。

```
┌─────────────────────────────────────────────────────────────┐
│                    表示层 (UI Layer)                          │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐            │
│  │ FloatingWidget│ │ Preferences │ │ Components  │            │
│  │   (SwiftUI)   │ │  (SwiftUI)  │ │  (SwiftUI)  │            │
│  └─────────────┘ └─────────────┘ └─────────────┘            │
└─────────────────────────────────────────────────────────────┘
                            │ Combine Binding
┌─────────────────────────────────────────────────────────────┐
│                   应用层 (Service Layer)                      │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐            │
│  │ SpeechService│ │PromptService│ │ HotkeyService│            │
│  │             │ │             │ │             │            │
│  └─────────────┘ └─────────────┘ └─────────────┘            │
└─────────────────────────────────────────────────────────────┘
                            │ Protocol Interface
┌─────────────────────────────────────────────────────────────┐
│                   领域层 (Core Layer)                         │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐            │
│  │  Entities   │ │  UseCases   │ │ Repositories│            │
│  │  (Models)   │ │ (Business)  │ │ (Data)      │            │
│  └─────────────┘ └─────────────┘ └─────────────┘            │
└─────────────────────────────────────────────────────────────┘
                            │ Dependency Injection
┌─────────────────────────────────────────────────────────────┐
│                基础设施层 (System Layer)                       │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐            │
│  │   Hotkey    │ │LaunchAgent  │ │Accessibility│            │
│  │ Management  │ │ Management  │ │ Services    │            │
│  └─────────────┘ └─────────────┘ └─────────────┘            │
└─────────────────────────────────────────────────────────────┘
                            │ System API
┌─────────────────────────────────────────────────────────────┐
│                    数据层 (Data Layer)                        │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐            │
│  │  Keychain   │ │UserDefaults │ │  FileSystem │            │
│  │   Storage   │ │   Storage   │ │   Storage   │            │
│  └─────────────┘ └─────────────┘ └─────────────┘            │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 技术栈选型

#### 1.2.1 核心技术栈
- **编程语言**：Swift 5.10+
- **UI框架**：SwiftUI + AppKit (混合架构)
- **音频处理**：AVFoundation + AudioKit 5.6.0
- **网络通信**：AsyncHTTPClient (基于SwiftNIO)
- **状态管理**：Combine Framework
- **依赖管理**：Swift Package Manager

#### 1.2.2 关键依赖库
```swift
// Package.swift dependencies
dependencies: [
    .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.9.1")),
    .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", .upToNextMajor(from: "5.0.1")),
    .package(url: "https://github.com/AudioKit/AudioKit.git", .upToNextMajor(from: "5.6.0")),
    .package(url: "https://github.com/sindresorhus/Defaults.git", .upToNextMajor(from: "7.1.0")),
    .package(url: "https://github.com/argon/WhisperKit.git", .upToNextMajor(from: "1.2.0"))
]
```

### 1.3 架构决策记录 (ADR)

#### ADR-001: 采用SwiftUI+AppKit混合架构
**决策**：使用SwiftUI构建主要界面，AppKit处理系统集成  
**理由**：SwiftUI开发效率高且支持实时预览，AppKit提供底层系统API访问能力  
**替代方案**：纯AppKit（开发效率低）、纯SwiftUI（系统集成能力不足）  
**风险**：混合架构增加复杂度，需要维护两套UI范式

#### ADR-002: 选择AsyncHTTPClient替代URLSession
**决策**：使用基于SwiftNIO的AsyncHTTPClient进行网络请求  
**理由**：性能比URLSession提升30%，支持连接池和并发优化  
**替代方案**：URLSession（性能较低）、Alamofire（功能过重）  
**风险**：第三方库依赖，学习成本较高

#### ADR-003: 采用LaunchAgent实现开机启动
**决策**：使用LaunchAgent而非LoginItems实现开机启动  
**理由**：更精细的启动控制、更好的系统兼容性、符合macOS最佳实践  
**替代方案**：LoginItems（功能有限）、SMAppService（需要额外权限）  
**风险**：配置复杂度较高，需要处理版本兼容性

## 2. 系统模块详细设计

### 2.1 语音识别模块 (SpeechRecognition)

#### 2.1.1 模块架构
```swift
// 语音识别模块协议定义
protocol SpeechRecognitionServiceProtocol {
    func startRecording() async throws
    func stopRecording() async throws -> AudioBuffer
    func transcribe(audio: AudioBuffer) async throws -> TranscriptionResult
    var isRecording: Bool { get }
    var recordingStatePublisher: AnyPublisher<RecordingState, Never> { get }
}

// 录音状态枚举
enum RecordingState {
    case idle
    case recording
    case processing
    case completed
    case error(SpeechError)
}

// 音频缓冲区数据结构
struct AudioBuffer {
    let samples: [Float]
    let sampleRate: Double
    let channelCount: Int
    let duration: TimeInterval
    
    // 音频指纹生成（用于缓存）
    var fingerprint: String {
        return samples.prefix(1024).withUnsafeBytes { bytes in
            SHA256.hash(data: bytes).compactMap { String(format: "%02x", $0) }.joined()
        }
    }
}
```

#### 2.1.2 音频捕获实现
```swift
class AudioCaptureService: ObservableObject {
    private var captureSession: AVCaptureSession?
    private var audioOutput: AVCaptureAudioDataOutput?
    private let audioQueue = DispatchQueue(label: "audio.capture", qos: .userInitiated)
    
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published var captureState: CaptureState = .idle
    
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    self.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    func startCapture() throws {
        guard authorizationStatus == .authorized else {
            throw AudioError.permissionDenied
        }
        
        let session = AVCaptureSession()
        session.sessionPreset = .medium // 44.1kHz
        
        // 配置音频输入
        guard let audioDevice = AVCaptureDevice.default(for: .audio),
              let audioInput = try? AVCaptureDeviceInput(device: audioDevice) else {
            throw AudioError.deviceNotAvailable
        }
        
        session.addInput(audioInput)
        
        // 配置音频输出
        let audioOutput = AVCaptureAudioDataOutput()
        audioOutput.setSampleBufferDelegate(self, queue: audioQueue)
        session.addOutput(audioOutput)
        
        // 音频格式配置
        if let connection = audioOutput.connection(with: .audio) {
            connection.audioSettings = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 16000.0,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false
            ]
        }
        
        self.captureSession = session
        self.audioOutput = audioOutput
        
        session.startRunning()
        captureState = .recording
    }
}

// AVCaptureAudioDataOutputSampleBufferDelegate实现
extension AudioCaptureService: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, 
                      didOutput sampleBuffer: CMSampleBuffer, 
                      from connection: AVCaptureConnection) {
        processAudioSample(sampleBuffer)
    }
    
    private func processAudioSample(_ sampleBuffer: CMSampleBuffer) {
        guard let audioBuffer = sampleBuffer.audioBuffer else { return }
        
        // 应用降噪处理
        let denoisedBuffer = AudioProcessor.applyNoiseReduction(audioBuffer)
        
        // VAD检测
        let voiceActivity = AudioProcessor.detectVoiceActivity(denoisedBuffer)
        
        if voiceActivity.isSilent && voiceActivity.duration > 0.5 {
            // 检测到500ms静音，停止录音
            Task { @MainActor in
                try await stopCapture()
            }
        }
    }
}
```

#### 2.1.3 信号处理算法
```swift
struct AudioProcessor {
    // LogMMSE降噪算法实现
    static func applyNoiseReduction(_ buffer: AudioBuffer) -> AudioBuffer {
        let frameSize = 512
        let hopSize = frameSize / 2
        let windowFunction = hanningWindow(size: frameSize)
        
        var processedSamples: [Float] = []
        
        for frameStart in stride(from: 0, to: buffer.samples.count - frameSize, by: hopSize) {
            let frame = Array(buffer.samples[frameStart..<frameStart + frameSize])
            
            // 加窗
            let windowedFrame = zip(frame, windowFunction).map { $0 * $1 }
            
            // FFT变换
            let spectrum = fft(windowedFrame)
            
            // 噪声频谱估计和抑制
            let denoisedSpectrum = logMMSE(spectrum: spectrum, noiseSpectrum: estimateNoiseSpectrum())
            
            // IFFT逆变换
            let denoisedFrame = ifft(denoisedSpectrum)
            
            // 重叠相加
            processedSamples.append(contentsOf: denoisedFrame)
        }
        
        return AudioBuffer(
            samples: processedSamples,
            sampleRate: buffer.sampleRate,
            channelCount: buffer.channelCount,
            duration: TimeInterval(processedSamples.count) / buffer.sampleRate
        )
    }
    
    // VAD算法实现
    static func detectVoiceActivity(_ buffer: AudioBuffer) -> VoiceActivityResult {
        let energyThreshold: Float = -26.0 // dB
        let frameSize = 512
        
        var silentFrames = 0
        var totalFrames = 0
        
        for frameStart in stride(from: 0, to: buffer.samples.count - frameSize, by: frameSize) {
            let frame = Array(buffer.samples[frameStart..<frameStart + frameSize])
            
            // 计算帧能量
            let energy = 20 * log10(sqrt(frame.map { $0 * $0 }.reduce(0, +) / Float(frame.count)))
            
            if energy < energyThreshold {
                silentFrames += 1
            }
            totalFrames += 1
        }
        
        let silentRatio = Float(silentFrames) / Float(totalFrames)
        let frameDuration = Double(frameSize) / buffer.sampleRate
        let silentDuration = Double(silentFrames) * frameDuration
        
        return VoiceActivityResult(
            isSilent: silentRatio > 0.8,
            duration: silentDuration,
            energyLevel: energy
        )
    }
}
```

### 2.2 提示词生成模块 (PromptGeneration)

#### 2.2.1 模块架构
```swift
// 提示词生成服务协议
protocol PromptGenerationServiceProtocol {
    func generatePrompt(from text: String, context: PromptContext) async throws -> Prompt
    func optimizePrompt(_ prompt: Prompt, instructions: [ModificationInstruction]) async throws -> Prompt
    var availableTemplates: [PromptTemplate] { get }
}

// 提示词上下文
struct PromptContext {
    let domain: PromptDomain
    let targetPlatform: TargetPlatform
    let userPreferences: UserPreferences
    let conversationHistory: [Prompt]
}

enum PromptDomain {
    case coding(language: ProgrammingLanguage, framework: String?)
    case design(style: ArtStyle, format: OutputFormat)
    case writing(genre: WritingGenre, audience: Audience)
    case general
}

enum TargetPlatform {
    case chatGPT
    case claude
    case midjourney
    case stableDiffusion
    case custom(String)
}
```

#### 2.2.2 智能模板匹配系统
```swift
class TemplateMatchingEngine {
    private let templates: [PromptTemplate]
    private let keywordExtractor: KeywordExtractor
    
    func selectOptimalTemplate(for input: String, context: PromptContext) -> PromptTemplate {
        let keywords = keywordExtractor.extract(from: input)
        let candidates = templates.filter { template in
            template.domain == context.domain
        }
        
        // 计算匹配分数
        let scoredTemplates = candidates.map { template in
            let score = calculateMatchScore(template: template, keywords: keywords, context: context)
            return ScoredTemplate(template: template, score: score)
        }
        
        // 返回最高分模板
        return scoredTemplates.max(by: { $0.score < $1.score })?.template ?? DefaultTemplate.general
    }
    
    private func calculateMatchScore(template: PromptTemplate, 
                                   keywords: [Keyword], 
                                   context: PromptContext) -> Double {
        var score: Double = 0.0
        
        // 关键词匹配得分 (40%)
        let keywordScore = keywords.compactMap { keyword in
            template.keywords.contains(keyword) ? keyword.weight : 0.0
        }.reduce(0, +)
        score += keywordScore * 0.4
        
        // 领域匹配得分 (30%)
        let domainScore = template.domain == context.domain ? 1.0 : 0.0
        score += domainScore * 0.3
        
        // 历史使用频率 (20%)
        let usageScore = Double(template.usageCount) / Double(templates.map(\.usageCount).max() ?? 1)
        score += usageScore * 0.2
        
        // 用户偏好匹配 (10%)
        let preferenceScore = template.matchesPreferences(context.userPreferences) ? 1.0 : 0.0
        score += preferenceScore * 0.1
        
        return score
    }
}
```

#### 2.2.3 OpenAI API集成
```swift
class OpenAIService: PromptGenerationServiceProtocol {
    private let apiKey: String
    private let httpClient: HTTPClient
    private let cache: NSCache<NSString, CachedResponse>
    
    func generatePrompt(from text: String, context: PromptContext) async throws -> Prompt {
        // 检查缓存
        let cacheKey = generateCacheKey(text: text, context: context)
        if let cached = cache.object(forKey: cacheKey as NSString) {
            return cached.prompt
        }
        
        // 选择最优模板
        let template = TemplateMatchingEngine.shared.selectOptimalTemplate(for: text, context: context)
        
        // 构建请求
        let request = buildAPIRequest(text: text, template: template, context: context)
        
        // 发送请求
        let response = try await sendRequest(request)
        
        // 解析响应
        let prompt = try parseResponse(response, originalText: text)
        
        // 缓存结果
        cache.setObject(CachedResponse(prompt: prompt), forKey: cacheKey as NSString)
        
        return prompt
    }
    
    private func buildAPIRequest(text: String, 
                                template: PromptTemplate, 
                                context: PromptContext) -> APIRequest {
        let systemPrompt = template.buildSystemPrompt(for: context)
        let userPrompt = template.buildUserPrompt(from: text)
        
        return APIRequest(
            model: selectModel(for: context),
            messages: [
                .system(systemPrompt),
                .user(userPrompt)
            ],
            temperature: context.userPreferences.creativity,
            maxTokens: calculateMaxTokens(for: context),
            stream: false
        )
    }
    
    private func selectModel(for context: PromptContext) -> String {
        switch context.domain {
        case .coding:
            return "gpt-4-turbo" // 代码生成使用更强模型
        case .design, .writing:
            return "gpt-4o" // 创意任务使用视觉理解能力强的模型
        case .general:
            return "gpt-4o-mini" // 通用任务使用经济型模型
        }
    }
}
```

### 2.3 多轮修改模块 (ConversationManager)

#### 2.3.1 对话状态管理
```swift
class ConversationManager: ObservableObject {
    @Published var currentPrompt: Prompt?
    @Published var conversationHistory: [ConversationTurn] = []
    
    private let maxHistoryLength = 5
    private let intentRecognizer: IntentRecognizer
    private let contextTracker: ContextTracker
    
    func processModificationRequest(_ input: String) async throws -> Prompt {
        guard let currentPrompt = currentPrompt else {
            throw ConversationError.noActivePrompt
        }
        
        // 识别修改意图
        let intent = try await intentRecognizer.recognize(input, context: currentContext)
        
        // 解析修改指令
        let modification = try parseModificationInstruction(from: input, intent: intent)
        
        // 应用修改
        let modifiedPrompt = try await applyModification(to: currentPrompt, modification: modification)
        
        // 更新对话历史
        updateConversationHistory(
            userInput: input,
            modification: modification,
            result: modifiedPrompt
        )
        
        self.currentPrompt = modifiedPrompt
        return modifiedPrompt
    }
    
    private func parseModificationInstruction(from input: String, 
                                            intent: ModificationIntent) throws -> ModificationInstruction {
        switch intent {
        case .addContent:
            return .add(content: extractNewContent(from: input))
        case .removeContent:
            return .remove(target: extractRemovalTarget(from: input))
        case .modifyContent:
            let target = extractModificationTarget(from: input)
            let newContent = extractReplacementContent(from: input)
            return .modify(target: target, newContent: newContent)
        case .changeFormat:
            return .changeFormat(newFormat: extractDesiredFormat(from: input))
        case .adjustTone:
            return .adjustTone(newTone: extractDesiredTone(from: input))
        }
    }
}

// 意图识别器
class IntentRecognizer {
    private let nlpProcessor: NLPProcessor
    
    func recognize(_ input: String, context: ConversationContext) async throws -> ModificationIntent {
        // 预处理输入文本
        let processedInput = nlpProcessor.preprocess(input)
        
        // 关键词匹配
        let keywordMatches = matchIntentKeywords(processedInput)
        
        // 句法分析
        let syntacticFeatures = nlpProcessor.analyzeSyntax(processedInput)
        
        // 上下文分析
        let contextualFeatures = analyzeContext(context)
        
        // 综合判断
        return classifyIntent(
            keywordMatches: keywordMatches,
            syntacticFeatures: syntacticFeatures,
            contextualFeatures: contextualFeatures
        )
    }
    
    private func matchIntentKeywords(_ input: String) -> [IntentKeyword] {
        let intentKeywords: [String: ModificationIntent] = [
            "添加": .addContent, "增加": .addContent, "加上": .addContent,
            "删除": .removeContent, "去掉": .removeContent, "移除": .removeContent,
            "修改": .modifyContent, "改为": .modifyContent, "替换": .modifyContent,
            "格式": .changeFormat, "样式": .changeFormat,
            "语气": .adjustTone, "风格": .adjustTone
        ]
        
        return intentKeywords.compactMap { keyword, intent in
            input.contains(keyword) ? IntentKeyword(keyword: keyword, intent: intent) : nil
        }
    }
}
```

### 2.4 系统集成模块 (SystemIntegration)

#### 2.4.1 全局快捷键管理
```swift
class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()
    
    @Published var currentHotkey: HotkeyConfiguration
    @Published var isEnabled: Bool = false
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    func registerHotkey(_ configuration: HotkeyConfiguration) throws {
        // 注销现有快捷键
        unregisterCurrentHotkey()
        
        // 检测冲突
        let conflicts = try detectConflicts(configuration)
        if !conflicts.isEmpty {
            throw HotkeyError.conflictDetected(conflicts)
        }
        
        // 注册新快捷键
        let hotKeyID = EventHotKeyID(signature: OSType('HlPr'), id: UInt32(configuration.hashValue))
        
        let status = RegisterEventHotKey(
            UInt32(configuration.keyCode),
            UInt32(configuration.modifierFlags.rawValue),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        guard status == noErr else {
            throw HotkeyError.registrationFailed(status: status)
        }
        
        // 安装事件处理器
        try installEventHandler()
        
        self.currentHotkey = configuration
        self.isEnabled = true
    }
    
    private func detectConflicts(_ configuration: HotkeyConfiguration) throws -> [HotkeyConflict] {
        var conflicts: [HotkeyConflict] = []
        
        // 检测系统快捷键冲突
        let systemConflicts = SystemHotkeyScanner.scan(configuration)
        conflicts.append(contentsOf: systemConflicts)
        
        // 检测应用快捷键冲突
        let appConflicts = try ApplicationHotkeyScanner.scan(configuration)
        conflicts.append(contentsOf: appConflicts)
        
        return conflicts
    }
    
    private func installEventHandler() throws {
        let spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), 
                                eventKind: OSType(kEventHotKeyPressed))
        
        let status = InstallApplicationEventHandler(
            { (_, event, _) -> OSStatus in
                HotkeyManager.shared.handleHotkeyEvent(event)
                return noErr
            },
            1,
            &spec,
            nil,
            &eventHandler
        )
        
        guard status == noErr else {
            throw HotkeyError.eventHandlerInstallationFailed(status: status)
        }
    }
    
    @objc private func handleHotkeyEvent(_ event: EventRef?) -> OSStatus {
        guard let event = event else { return eventNotHandledErr }
        
        // 提取快捷键ID
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            OSType(kEventParamDirectObject),
            OSType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        
        guard status == noErr else { return status }
        
        // 触发快捷键事件
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .hotkeyTriggered,
                object: self,
                userInfo: ["keyID": hotKeyID.id]
            )
        }
        
        return noErr
    }
}

// 快捷键配置结构
struct HotkeyConfiguration: Codable, Hashable {
    let keyCode: Int
    let modifierFlags: ModifierFlags
    let description: String
    
    struct ModifierFlags: OptionSet, Codable {
        let rawValue: UInt32
        
        static let command = ModifierFlags(rawValue: UInt32(cmdKey))
        static let option = ModifierFlags(rawValue: UInt32(optionKey))
        static let control = ModifierFlags(rawValue: UInt32(controlKey))
        static let shift = ModifierFlags(rawValue: UInt32(shiftKey))
    }
    
    static let defaultConfiguration = HotkeyConfiguration(
        keyCode: kVK_Space,
        modifierFlags: [.command, .option, .control],
        description: "⌃⌥⌘Space"
    )
}
```

#### 2.4.2 开机启动管理
```swift
class LaunchAgentManager: ObservableObject {
    static let shared = LaunchAgentManager()
    
    @Published var isEnabled: Bool = false
    @Published var launchOptions: LaunchOptions = LaunchOptions()
    
    private let agentPlistPath: URL
    private let launchAgentDirectory: URL
    
    init() {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        launchAgentDirectory = homeDirectory
            .appendingPathComponent("Library")
            .appendingPathComponent("LaunchAgents")
        
        agentPlistPath = launchAgentDirectory
            .appendingPathComponent("com.promptvoice.agent.plist")
    }
    
    func enableLaunchAtLogin(options: LaunchOptions = LaunchOptions()) throws {
        // 创建LaunchAgent目录（如果不存在）
        try FileManager.default.createDirectory(
            at: launchAgentDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // 生成plist内容
        let plistContent = try generatePlistContent(options: options)
        
        // 写入plist文件
        try plistContent.write(to: agentPlistPath, atomically: true, encoding: .utf8)
        
        // 设置文件权限
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o644],
            ofItemAtPath: agentPlistPath.path
        )
        
        // 加载LaunchAgent
        try loadLaunchAgent()
        
        self.isEnabled = true
        self.launchOptions = options
    }
    
    func disableLaunchAtLogin() throws {
        // 卸载LaunchAgent
        try unloadLaunchAgent()
        
        // 删除plist文件
        if FileManager.default.fileExists(atPath: agentPlistPath.path) {
            try FileManager.default.removeItem(at: agentPlistPath)
        }
        
        self.isEnabled = false
    }
    
    private func generatePlistContent(_ options: LaunchOptions) throws -> String {
        let appBundle = Bundle.main
        guard let executablePath = appBundle.executablePath else {
            throw LaunchAgentError.executablePathNotFound
        }
        
        var plistDict: [String: Any] = [
            "Label": "com.promptvoice.agent",
            "ProgramArguments": [executablePath, "--autostart"],
            "RunAtLoad": true,
            "KeepAlive": false
        ]
        
        // 添加可选配置
        if options.startDelay > 0 {
            plistDict["StartInterval"] = Int(options.startDelay)
        }
        
        if options.batteryProtection {
            plistDict["StartOnlyOnBattery"] = false
        }
        
        if options.networkAware {
            plistDict["StartRequiredCondition"] = "NetworkUp"
        }
        
        // 日志配置
        let logDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Logs")
            .appendingPathComponent("HelloPrompt")
        
        plistDict["StandardOutPath"] = logDirectory
            .appendingPathComponent("agent.log").path
        plistDict["StandardErrorPath"] = logDirectory
            .appendingPathComponent("agent_error.log").path
        
        // 转换为XML格式
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plistDict,
            format: .xml,
            options: 0
        )
        
        return String(data: plistData, encoding: .utf8) ?? ""
    }
    
    private func loadLaunchAgent() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", agentPlistPath.path]
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw LaunchAgentError.loadFailed(status: process.terminationStatus)
        }
    }
}

// 启动选项配置
struct LaunchOptions: Codable {
    var startDelay: TimeInterval = 0
    var batteryProtection: Bool = false
    var networkAware: Bool = false
    var autoUpdate: Bool = true
}
```

### 2.5 数据存储模块 (DataPersistence)

#### 2.5.1 API密钥安全存储
```swift
class KeychainService {
    static let shared = KeychainService()
    
    private let service = "com.promptvoice.openai-api-key"
    private let accessGroup: String? = nil
    
    func store(apiKey: String, for account: String = "default") throws {
        let data = apiKey.data(using: .utf8)!
        
        // 删除现有项（如果存在）
        try? delete(for: account)
        
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.storageError(status: status)
        }
    }
    
    func retrieve(for account: String = "default") throws -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            throw KeychainError.retrievalError(status: status)
        }
        
        guard let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataCorrupted
        }
        
        return apiKey
    }
    
    func update(apiKey: String, for account: String = "default") throws {
        let data = apiKey.data(using: .utf8)!
        
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        
        let attributes: [CFString: Any] = [
            kSecValueData: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                // 项不存在，创建新项
                try store(apiKey: apiKey, for: account)
            } else {
                throw KeychainError.updateError(status: status)
            }
        }
    }
    
    func delete(for account: String = "default") throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deletionError(status: status)
        }
    }
}

// Keychain错误定义
enum KeychainError: LocalizedError {
    case storageError(status: OSStatus)
    case retrievalError(status: OSStatus)
    case updateError(status: OSStatus)
    case deletionError(status: OSStatus)
    case dataCorrupted
    
    var errorDescription: String? {
        switch self {
        case .storageError(let status):
            return "Failed to store API key: \(status)"
        case .retrievalError(let status):
            return "Failed to retrieve API key: \(status)"
        case .updateError(let status):
            return "Failed to update API key: \(status)"
        case .deletionError(let status):
            return "Failed to delete API key: \(status)"
        case .dataCorrupted:
            return "Stored API key data is corrupted"
        }
    }
}
```

## 3. 数据结构与接口定义

### 3.1 核心数据模型

#### 3.1.1 Prompt数据模型
```swift
struct Prompt: Identifiable, Codable, Equatable {
    let id: UUID
    var content: String
    let originalText: String
    var history: [PromptModification]
    let timestamp: Date
    let confidence: Double
    let domain: PromptDomain
    let metadata: PromptMetadata
    
    init(content: String, 
         originalText: String, 
         domain: PromptDomain = .general,
         confidence: Double = 0.0) {
        self.id = UUID()
        self.content = content
        self.originalText = originalText
        self.history = []
        self.timestamp = Date()
        self.confidence = confidence
        self.domain = domain
        self.metadata = PromptMetadata()
    }
    
    // 添加修改记录
    mutating func addModification(_ modification: PromptModification) {
        history.append(modification)
        
        // 限制历史记录长度
        if history.count > 5 {
            history.removeFirst()
        }
    }
    
    // 计算质量评分
    var qualityScore: Double {
        let lengthScore = min(Double(content.count) / 100.0, 1.0) * 0.3
        let structureScore = calculateStructureScore() * 0.4
        let confidenceScore = confidence * 0.3
        
        return lengthScore + structureScore + confidenceScore
    }
    
    private func calculateStructureScore() -> Double {
        let hasNumberedList = content.contains(#/\d+\.//)
        let hasBulletPoints = content.contains(#/[•\-\*]//)
        let hasHeaders = content.contains(#/#{1,6}\s//)
        let hasCodeBlocks = content.contains("```")
        
        let structuralElements = [hasNumberedList, hasBulletPoints, hasHeaders, hasCodeBlocks]
        return Double(structuralElements.filter { $0 }.count) / Double(structuralElements.count)
    }
}

struct PromptModification: Codable {
    let id: UUID
    let type: ModificationType
    let instruction: String
    let previousContent: String
    let newContent: String
    let timestamp: Date
    
    enum ModificationType: String, Codable {
        case add, remove, modify, format, tone
    }
}

struct PromptMetadata: Codable {
    var wordCount: Int = 0
    var estimatedTokens: Int = 0
    var targetPlatform: TargetPlatform = .chatGPT
    var tags: [String] = []
    var usageCount: Int = 0
    var lastUsed: Date?
    
    mutating func updateUsageStatistics() {
        usageCount += 1
        lastUsed = Date()
    }
}
```

#### 3.1.2 AudioBuffer数据模型
```swift
struct AudioBuffer: Codable {
    let samples: [Float]
    let sampleRate: Double
    let channelCount: Int
    let duration: TimeInterval
    let format: AudioFormat
    private let _fingerprint: String
    
    init(samples: [Float], 
         sampleRate: Double, 
         channelCount: Int = 1) {
        self.samples = samples
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.duration = Double(samples.count) / sampleRate
        self.format = AudioFormat(sampleRate: sampleRate, channelCount: channelCount)
        self._fingerprint = Self.generateFingerprint(samples: samples)
    }
    
    var fingerprint: String {
        return _fingerprint
    }
    
    // 音频指纹生成（用于缓存和去重）
    private static func generateFingerprint(samples: [Float]) -> String {
        let significantSamples = Array(samples.prefix(1024))
        let data = Data(bytes: significantSamples, count: significantSamples.count * MemoryLayout<Float>.size)
        return SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // 音频质量检测
    var qualityMetrics: AudioQualityMetrics {
        let peakAmplitude = samples.map(abs).max() ?? 0.0
        let rmsLevel = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))
        let signalToNoiseRatio = calculateSNR()
        
        return AudioQualityMetrics(
            peakAmplitude: peakAmplitude,
            rmsLevel: rmsLevel,
            signalToNoiseRatio: signalToNoiseRatio,
            clippingDetected: peakAmplitude > 0.95
        )
    }
    
    private func calculateSNR() -> Double {
        // 简化的SNR计算
        let signalPower = samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count)
        let estimatedNoisePower: Float = 0.01 // 假设底噪水平
        return 10 * log10(Double(signalPower / estimatedNoisePower))
    }
}

struct AudioFormat: Codable {
    let sampleRate: Double
    let channelCount: Int
    let bitDepth: Int
    let isFloat: Bool
    
    init(sampleRate: Double, channelCount: Int, bitDepth: Int = 16, isFloat: Bool = true) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.bitDepth = bitDepth
        self.isFloat = isFloat
    }
    
    static let standard = AudioFormat(sampleRate: 16000, channelCount: 1)
    static let highQuality = AudioFormat(sampleRate: 44100, channelCount: 1)
}

struct AudioQualityMetrics {
    let peakAmplitude: Float
    let rmsLevel: Float
    let signalToNoiseRatio: Double
    let clippingDetected: Bool
    
    var qualityRating: AudioQuality {
        if clippingDetected || signalToNoiseRatio < 10 {
            return .poor
        } else if signalToNoiseRatio < 20 || rmsLevel < 0.1 {
            return .fair
        } else if signalToNoiseRatio < 30 {
            return .good
        } else {
            return .excellent
        }
    }
}

enum AudioQuality: String, CaseIterable {
    case poor = "Poor"
    case fair = "Fair"
    case good = "Good"
    case excellent = "Excellent"
}
```

### 3.2 服务接口定义

#### 3.2.1 语音识别服务接口
```swift
protocol SpeechRecognitionServiceProtocol {
    var isRecording: Bool { get }
    var recordingState: AnyPublisher<RecordingState, Never> { get }
    var audioQuality: AnyPublisher<AudioQualityMetrics, Never> { get }
    
    func requestPermissions() async -> PermissionResult
    func startRecording(quality: AudioQuality) async throws
    func stopRecording() async throws -> AudioBuffer
    func cancelRecording() async
    func transcribe(audio: AudioBuffer, options: TranscriptionOptions) async throws -> TranscriptionResult
}

struct TranscriptionOptions {
    let language: String?
    let model: String
    let temperature: Double
    let enableVAD: Bool
    let noiseReduction: Bool
    
    static let `default` = TranscriptionOptions(
        language: nil,
        model: "whisper-1",
        temperature: 0.0,
        enableVAD: true,
        noiseReduction: true
    )
}

struct TranscriptionResult {
    let text: String
    let confidence: Double
    let segments: [TranscriptionSegment]
    let language: String
    let duration: TimeInterval
    
    struct TranscriptionSegment {
        let text: String
        let startTime: TimeInterval
        let endTime: TimeInterval
        let confidence: Double
    }
}

enum RecordingState {
    case idle
    case requesting
    case recording(duration: TimeInterval)
    case processing
    case completed(AudioBuffer)
    case error(SpeechError)
}

enum PermissionResult {
    case granted
    case denied
    case restricted
    case undetermined
}
```

#### 3.2.2 提示词生成服务接口
```swift
protocol PromptGenerationServiceProtocol {
    var availableTemplates: [PromptTemplate] { get }
    var generationState: AnyPublisher<GenerationState, Never> { get }
    
    func generatePrompt(from text: String, 
                       context: PromptContext, 
                       options: GenerationOptions) async throws -> GenerationResult
    
    func optimizePrompt(_ prompt: Prompt, 
                       modifications: [ModificationInstruction]) async throws -> Prompt
    
    func validatePrompt(_ prompt: Prompt, 
                       for platform: TargetPlatform) async throws -> ValidationResult
    
    func suggestImprovements(for prompt: Prompt) async throws -> [ImprovementSuggestion]
}

struct GenerationOptions {
    let creativity: Double // 0.0 - 1.0
    let maxLength: Int
    let includeExamples: Bool
    let targetAudience: Audience
    let optimizeFor: TargetPlatform
    
    static let `default` = GenerationOptions(
        creativity: 0.7,
        maxLength: 500,
        includeExamples: true,
        targetAudience: .general,
        optimizeFor: .chatGPT
    )
}

struct GenerationResult {
    let prompt: Prompt
    let template: PromptTemplate
    let processingTime: TimeInterval
    let tokens: TokenUsage
    let qualityScore: Double
    let suggestions: [ImprovementSuggestion]
}

struct TokenUsage {
    let input: Int
    let output: Int
    let total: Int
    let estimatedCost: Double
}

enum GenerationState {
    case idle
    case analyzing
    case generating
    case optimizing
    case completed(GenerationResult)
    case error(GenerationError)
}
```

## 4. 存储与数据接口

### 4.1 数据持久化策略

#### 4.1.1 分层存储架构
```swift
protocol StorageServiceProtocol {
    associatedtype T: Codable
    
    func save(_ item: T) async throws
    func load(id: String) async throws -> T?
    func loadAll() async throws -> [T]
    func delete(id: String) async throws
    func search(criteria: SearchCriteria) async throws -> [T]
}

// 安全存储（Keychain）- 敏感数据
class SecureStorageService: StorageServiceProtocol {
    typealias T = SecureData
    
    private let keychain = KeychainService.shared
    
    func save(_ item: SecureData) async throws {
        try keychain.store(apiKey: item.value, for: item.key)
    }
    
    func load(id: String) async throws -> SecureData? {
        guard let value = try keychain.retrieve(for: id) else { return nil }
        return SecureData(key: id, value: value)
    }
    
    // ... 其他方法实现
}

// 偏好设置存储（UserDefaults）- 配置数据
class PreferencesStorageService: StorageServiceProtocol {
    typealias T = AppPreferences
    
    private let userDefaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    func save(_ item: AppPreferences) async throws {
        let data = try encoder.encode(item)
        userDefaults.set(data, forKey: "app_preferences")
    }
    
    func load(id: String) async throws -> AppPreferences? {
        guard let data = userDefaults.data(forKey: "app_preferences") else { return nil }
        return try decoder.decode(AppPreferences.self, from: data)
    }
    
    // ... 其他方法实现
}

// 文件存储（Documents目录）- 业务数据
class FileStorageService: StorageServiceProtocol {
    typealias T = Prompt
    
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let storageDirectory: URL
    
    init() throws {
        let documentsPath = fileManager.urls(for: .documentDirectory, 
                                           in: .userDomainMask).first!
        storageDirectory = documentsPath.appendingPathComponent("HelloPrompt")
        
        // 创建存储目录
        if !fileManager.fileExists(atPath: storageDirectory.path) {
            try fileManager.createDirectory(at: storageDirectory, 
                                          withIntermediateDirectories: true)
        }
    }
    
    func save(_ item: Prompt) async throws {
        let filename = "\(item.id.uuidString).json"
        let fileURL = storageDirectory.appendingPathComponent(filename)
        let data = try encoder.encode(item)
        try data.write(to: fileURL)
    }
    
    func load(id: String) async throws -> Prompt? {
        let filename = "\(id).json"
        let fileURL = storageDirectory.appendingPathComponent(filename)
        
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(Prompt.self, from: data)
    }
    
    func loadAll() async throws -> [Prompt] {
        let files = try fileManager.contentsOfDirectory(at: storageDirectory, 
                                                       includingPropertiesForKeys: nil)
        
        var prompts: [Prompt] = []
        for file in files.filter({ $0.pathExtension == "json" }) {
            let data = try Data(contentsOf: file)
            let prompt = try decoder.decode(Prompt.self, from: data)
            prompts.append(prompt)
        }
        
        return prompts.sorted { $0.timestamp > $1.timestamp }
    }
}
```

### 4.2 数据同步与备份

#### 4.2.1 数据备份服务
```swift
class BackupService: ObservableObject {
    @Published var backupState: BackupState = .idle
    @Published var lastBackupDate: Date?
    
    private let fileStorage: FileStorageService
    private let preferencesStorage: PreferencesStorageService
    
    func createBackup() async throws -> BackupResult {
        backupState = .creating
        
        do {
            // 收集所有数据
            let prompts = try await fileStorage.loadAll()
            let preferences = try await preferencesStorage.load(id: "main")
            
            // 创建备份包
            let backup = BackupPackage(
                version: Bundle.main.version,
                timestamp: Date(),
                prompts: prompts,
                preferences: preferences,
                metadata: createBackupMetadata()
            )
            
            // 压缩并保存
            let backupData = try JSONEncoder().encode(backup)
            let compressedData = try backup.compress(data: backupData)
            
            let backupURL = try saveBackupToFile(compressedData)
            
            lastBackupDate = Date()
            backupState = .completed
            
            return BackupResult(url: backupURL, size: compressedData.count)
            
        } catch {
            backupState = .error(error)
            throw error
        }
    }
    
    func restoreFromBackup(_ backupURL: URL) async throws {
        backupState = .restoring
        
        do {
            // 读取并解压备份文件
            let compressedData = try Data(contentsOf: backupURL)
            let backupData = try BackupPackage.decompress(data: compressedData)
            let backup = try JSONDecoder().decode(BackupPackage.self, from: backupData)
            
            // 验证备份完整性
            try validateBackup(backup)
            
            // 恢复数据
            for prompt in backup.prompts {
                try await fileStorage.save(prompt)
            }
            
            if let preferences = backup.preferences {
                try await preferencesStorage.save(preferences)
            }
            
            backupState = .completed
            
        } catch {
            backupState = .error(error)
            throw error
        }
    }
    
    private func createBackupMetadata() -> BackupMetadata {
        return BackupMetadata(
            appVersion: Bundle.main.version,
            systemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            deviceModel: getDeviceModel(),
            backupType: .manual
        )
    }
}

struct BackupPackage: Codable {
    let version: String
    let timestamp: Date
    let prompts: [Prompt]
    let preferences: AppPreferences?
    let metadata: BackupMetadata
    
    static func compress(data: Data) throws -> Data {
        return try (data as NSData).compressed(using: .lzfse) as Data
    }
    
    static func decompress(data: Data) throws -> Data {
        return try (data as NSData).decompressed(using: .lzfse) as Data
    }
}

enum BackupState {
    case idle
    case creating
    case restoring
    case completed
    case error(Error)
}
```

## 5. 接口规范与API设计

### 5.1 RESTful API接口（用于插件扩展）

#### 5.1.1 本地HTTP服务器
```swift
class LocalAPIServer: ObservableObject {
    private var server: HTTPServer?
    private let port: Int = 8080
    
    @Published var isRunning: Bool = false
    @Published var connectedClients: Int = 0
    
    func start() throws {
        let router = Router()
        
        // 配置路由
        setupRoutes(router)
        
        // 启动服务器
        server = HTTPServer(router: router)
        try server?.start(port: port)
        
        isRunning = true
        
        print("Local API server started on port \(port)")
    }
    
    private func setupRoutes(_ router: Router) {
        // 获取应用状态
        router.get("/api/v1/status") { request, response in
            let status = AppStatus(
                version: Bundle.main.version,
                isRecording: SpeechService.shared.isRecording,
                uptime: ProcessInfo.processInfo.systemUptime
            )
            try response.json(status)
        }
        
        // 触发语音录制
        router.post("/api/v1/speech/start") { request, response in
            Task {
                do {
                    try await SpeechService.shared.startRecording()
                    try response.json(["status": "recording_started"])
                } catch {
                    try response.status(.badRequest).json(["error": error.localizedDescription])
                }
            }
        }
        
        // 停止录制并获取结果
        router.post("/api/v1/speech/stop") { request, response in
            Task {
                do {
                    let audioBuffer = try await SpeechService.shared.stopRecording()
                    let result = try await PromptService.shared.generatePrompt(from: audioBuffer)
                    try response.json(result)
                } catch {
                    try response.status(.badRequest).json(["error": error.localizedDescription])
                }
            }
        }
        
        // 获取提示词历史
        router.get("/api/v1/prompts") { request, response in
            Task {
                do {
                    let prompts = try await PromptRepository.shared.loadAll()
                    try response.json(prompts)
                } catch {
                    try response.status(.internalServerError).json(["error": error.localizedDescription])
                }
            }
        }
        
        // 创建新的提示词
        router.post("/api/v1/prompts") { request, response in
            Task {
                do {
                    let createRequest = try request.decode(CreatePromptRequest.self)
                    let prompt = try await PromptService.shared.generatePrompt(
                        from: createRequest.text,
                        context: createRequest.context
                    )
                    try response.status(.created).json(prompt)
                } catch {
                    try response.status(.badRequest).json(["error": error.localizedDescription])
                }
            }
        }
        
        // 修改现有提示词
        router.put("/api/v1/prompts/:id") { request, response in
            let promptId = request.parameters["id"]!
            
            Task {
                do {
                    let modifyRequest = try request.decode(ModifyPromptRequest.self)
                    guard var prompt = try await PromptRepository.shared.load(id: promptId) else {
                        try response.status(.notFound).json(["error": "Prompt not found"])
                        return
                    }
                    
                    let modifiedPrompt = try await PromptService.shared.modifyPrompt(
                        prompt,
                        instructions: modifyRequest.instructions
                    )
                    
                    try response.json(modifiedPrompt)
                } catch {
                    try response.status(.badRequest).json(["error": error.localizedDescription])
                }
            }
        }
        
        // WebSocket端点用于实时通信
        router.webSocket("/api/v1/ws") { webSocket in
            WebSocketManager.shared.addConnection(webSocket)
            
            webSocket.onText { text in
                Task {
                    await WebSocketManager.shared.handleMessage(text, from: webSocket)
                }
            }
            
            webSocket.onClose {
                WebSocketManager.shared.removeConnection(webSocket)
            }
        }
    }
}

// API请求/响应模型
struct CreatePromptRequest: Codable {
    let text: String
    let context: PromptContext
    let options: GenerationOptions?
}

struct ModifyPromptRequest: Codable {
    let instructions: [ModificationInstruction]
    let preserveHistory: Bool
}

struct AppStatus: Codable {
    let version: String
    let isRecording: Bool
    let uptime: TimeInterval
    let memoryUsage: Int64
    let cpuUsage: Double
}
```

### 5.2 插件接口规范

#### 5.2.1 插件协议定义
```swift
// 插件基础协议
protocol PromptPlugin {
    var identifier: String { get }
    var version: String { get }
    var name: String { get }
    var description: String { get }
    var author: String { get }
    var supportedDomains: [PromptDomain] { get }
    
    func initialize(context: PluginContext) throws
    func processPrompt(_ prompt: Prompt, context: PromptContext) async throws -> Prompt
    func cleanup()
}

// 模板提供插件
protocol TemplateProviderPlugin: PromptPlugin {
    var templates: [PromptTemplate] { get }
    func getTemplate(for domain: PromptDomain) -> PromptTemplate?
    func createCustomTemplate(from specification: TemplateSpecification) throws -> PromptTemplate
}

// 语音处理插件
protocol AudioProcessorPlugin: PromptPlugin {
    func preprocessAudio(_ buffer: AudioBuffer) async throws -> AudioBuffer
    func postprocessTranscription(_ result: TranscriptionResult) async throws -> TranscriptionResult
}

// 用户界面扩展插件
protocol UIExtensionPlugin: PromptPlugin {
    func createSettingsView() -> AnyView
    func createQuickActionView() -> AnyView?
    func handleUserAction(_ action: UserAction) async
}

// 插件管理器
class PluginManager: ObservableObject {
    static let shared = PluginManager()
    
    @Published var loadedPlugins: [PromptPlugin] = []
    @Published var isLoading: Bool = false
    
    private let pluginsDirectory: URL
    private let sandboxedEnvironment: PluginSandbox
    
    init() {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, 
                                                         in: .userDomainMask).first!
        pluginsDirectory = applicationSupport.appendingPathComponent("HelloPrompt/Plugins")
        sandboxedEnvironment = PluginSandbox()
        
        createPluginsDirectoryIfNeeded()
    }
    
    func loadAllPlugins() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let pluginURLs = try FileManager.default.contentsOfDirectory(
                at: pluginsDirectory,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == "promptplugin" }
            
            var plugins: [PromptPlugin] = []
            
            for pluginURL in pluginURLs {
                do {
                    let plugin = try await loadPlugin(at: pluginURL)
                    plugins.append(plugin)
                    print("Loaded plugin: \(plugin.name) v\(plugin.version)")
                } catch {
                    print("Failed to load plugin at \(pluginURL): \(error)")
                }
            }
            
            await MainActor.run {
                self.loadedPlugins = plugins
            }
            
        } catch {
            print("Failed to scan plugins directory: \(error)")
        }
    }
    
    private func loadPlugin(at url: URL) async throws -> PromptPlugin {
        // 验证插件签名
        try validatePluginSignature(at: url)
        
        // 加载插件元数据
        let metadata = try loadPluginMetadata(at: url)
        
        // 在沙盒环境中执行插件
        let plugin = try await sandboxedEnvironment.loadPlugin(url: url, metadata: metadata)
        
        // 初始化插件
        let context = PluginContext(
            appVersion: Bundle.main.version,
            pluginsDirectory: pluginsDirectory,
            dataDirectory: getPluginDataDirectory(for: plugin.identifier)
        )
        
        try plugin.initialize(context: context)
        
        return plugin
    }
    
    func installPlugin(from url: URL) async throws {
        // 下载插件文件（如果是远程URL）
        let localURL = try await downloadPlugin(from: url)
        
        // 验证插件
        try validatePlugin(at: localURL)
        
        // 移动到插件目录
        let destinationURL = pluginsDirectory.appendingPathComponent(localURL.lastPathComponent)
        try FileManager.default.moveItem(at: localURL, to: destinationURL)
        
        // 重新加载插件
        await loadAllPlugins()
    }
    
    func uninstallPlugin(_ plugin: PromptPlugin) throws {
        // 清理插件
        plugin.cleanup()
        
        // 删除插件文件
        let pluginURL = pluginsDirectory.appendingPathComponent("\(plugin.identifier).promptplugin")
        try FileManager.default.removeItem(at: pluginURL)
        
        // 删除插件数据
        let dataDirectory = getPluginDataDirectory(for: plugin.identifier)
        try FileManager.default.removeItem(at: dataDirectory)
        
        // 从加载列表中移除
        loadedPlugins.removeAll { $0.identifier == plugin.identifier }
    }
}
```

## 6. 测试策略与质量保证

### 6.1 测试架构设计

#### 6.1.1 测试金字塔
```swift
// 单元测试 - 测试独立组件
class PromptGenerationServiceTests: XCTestCase {
    var service: PromptGenerationService!
    var mockAPIClient: MockOpenAIClient!
    var mockTemplateEngine: MockTemplateEngine!
    
    override func setUp() {
        super.setUp()
        mockAPIClient = MockOpenAIClient()
        mockTemplateEngine = MockTemplateEngine()
        service = PromptGenerationService(
            apiClient: mockAPIClient,
            templateEngine: mockTemplateEngine
        )
    }
    
    func testGeneratePromptWithValidInput() async throws {
        // Given
        let inputText = "Create a React component with form validation"
        let expectedPrompt = "Generated prompt for React component"
        mockAPIClient.stubbedResponse = expectedPrompt
        
        let context = PromptContext(
            domain: .coding(language: .javascript, framework: "React"),
            targetPlatform: .chatGPT,
            userPreferences: UserPreferences.default,
            conversationHistory: []
        )
        
        // When
        let result = try await service.generatePrompt(from: inputText, context: context)
        
        // Then
        XCTAssertEqual(result.content, expectedPrompt)
        XCTAssertTrue(mockAPIClient.generatePromptCalled)
        XCTAssertEqual(mockAPIClient.lastRequestText, inputText)
    }
    
    func testGeneratePromptWithEmptyInput() async {
        // Given
        let emptyInput = ""
        let context = PromptContext.default
        
        // When & Then
        await XCTAssertThrowsError(
            try await service.generatePrompt(from: emptyInput, context: context)
        ) { error in
            XCTAssertTrue(error is ValidationError)
        }
    }
    
    func testCachingBehavior() async throws {
        // Given
        let inputText = "test input"
        let context = PromptContext.default
        mockAPIClient.stubbedResponse = "cached response"
        
        // When - 第一次调用
        let firstResult = try await service.generatePrompt(from: inputText, context: context)
        
        // 重置mock状态
        mockAPIClient.reset()
        
        // 第二次调用相同输入
        let secondResult = try await service.generatePrompt(from: inputText, context: context)
        
        // Then
        XCTAssertEqual(firstResult.content, secondResult.content)
        XCTAssertFalse(mockAPIClient.generatePromptCalled) // 应该使用缓存，不调用API
    }
}

// 集成测试 - 测试模块间交互
class SpeechToPromptIntegrationTests: XCTestCase {
    var speechService: SpeechRecognitionService!
    var promptService: PromptGenerationService!
    var coordinator: SpeechToPromptCoordinator!
    
    override func setUp() {
        super.setUp()
        // 使用真实服务但配置为测试模式
        speechService = SpeechRecognitionService(mode: .testing)
        promptService = PromptGenerationService(apiKey: "test-key")
        coordinator = SpeechToPromptCoordinator(
            speechService: speechService,
            promptService: promptService
        )
    }
    
    func testCompleteWorkflow() async throws {
        // Given
        let expectation = XCTestExpectation(description: "Complete workflow")
        let testAudioFile = Bundle(for: Self.self).url(forResource: "test_audio", withExtension: "wav")!
        
        var receivedPrompt: Prompt?
        
        // When
        coordinator.processAudioFile(testAudioFile) { result in
            switch result {
            case .success(let prompt):
                receivedPrompt = prompt
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Workflow failed: \(error)")
            }
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 10.0)
        XCTAssertNotNil(receivedPrompt)
        XCTAssertFalse(receivedPrompt!.content.isEmpty)
    }
}

// UI测试 - 测试用户交互
class HelloPromptUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }
    
    func testFirstLaunchConfiguration() {
        // Given - 首次启动应显示配置界面
        XCTAssertTrue(app.staticTexts["Welcome to Hello Prompt"].exists)
        
        // When - 用户输入API密钥
        let apiKeyField = app.secureTextFields["API Key"]
        XCTAssertTrue(apiKeyField.exists)
        apiKeyField.tap()
        apiKeyField.typeText("test-api-key")
        
        // 点击测试连接
        app.buttons["Test Connection"].tap()
        
        // Then - 应该显示成功信息并进入主界面
        let successMessage = app.staticTexts["Connection successful"]
        XCTAssertTrue(successMessage.waitForExistence(timeout: 5))
        
        app.buttons["Continue"].tap()
        
        // 验证进入主界面
        XCTAssertTrue(app.buttons["Start Recording"].waitForExistence(timeout: 3))
    }
    
    func testHotkeyConfiguration() {
        // Given - 进入偏好设置
        app.menuBars.menuItems["Preferences"].click()
        app.buttons["Hotkey"].click()
        
        // When - 录制新的快捷键
        let recordButton = app.buttons["Record Hotkey"]
        recordButton.click()
        
        // 模拟按键（需要使用辅助功能权限）
        app.typeKey("p", modifierFlags: [.command, .option])
        
        // Then - 验证快捷键已更新
        let hotkeyDisplay = app.staticTexts["⌥⌘P"]
        XCTAssertTrue(hotkeyDisplay.exists)
        
        // 保存设置
        app.buttons["Save"].click()
    }
    
    func testVoiceInputWorkflow() {
        // Given - 确保已配置完成
        skipOnboardingIfNeeded()
        
        // When - 触发语音输入（通过按钮，因为快捷键在UI测试中难以模拟）
        let recordButton = app.buttons["Start Recording"]
        recordButton.tap()
        
        // 验证录音界面出现
        XCTAssertTrue(app.otherElements["Recording Orb"].exists)
        
        // 模拟停止录音（等待自动停止或点击停止）
        if app.buttons["Stop Recording"].waitForExistence(timeout: 2) {
            app.buttons["Stop Recording"].tap()
        }
        
        // Then - 验证提示词预览出现
        let promptPreview = app.textViews["Prompt Preview"]
        XCTAssertTrue(promptPreview.waitForExistence(timeout: 10))
        XCTAssertFalse(promptPreview.value as! String).isEmpty()
        
        // 确认提示词
        app.buttons["Confirm"].tap()
        
        // 验证提示词已插入（这里可能需要检查剪贴板或其他指示器）
        XCTAssertTrue(app.alerts["Prompt Inserted"].waitForExistence(timeout: 3))
    }
    
    private func skipOnboardingIfNeeded() {
        if app.staticTexts["Welcome to Hello Prompt"].exists {
            // 快速配置以跳过引导
            app.textFields["API Key"].tap()
            app.textFields["API Key"].typeText("test-key")
            app.buttons["Skip Setup"].tap()
        }
    }
}
```

### 6.2 性能测试与监控

#### 6.2.1 性能基准测试
```swift
class PerformanceTests: XCTestCase {
    var speechService: SpeechRecognitionService!
    var promptService: PromptGenerationService!
    
    override func setUp() {
        super.setUp()
        speechService = SpeechRecognitionService()
        promptService = PromptGenerationService(apiKey: getTestAPIKey())
    }
    
    func testAudioProcessingPerformance() {
        // 测试音频处理性能
        let audioBuffer = generateTestAudioBuffer(duration: 10) // 10秒音频
        
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            _ = AudioProcessor.applyNoiseReduction(audioBuffer)
        }
    }
    
    func testPromptGenerationLatency() async {
        // 测试提示词生成延迟
        let testInputs = [
            "Create a simple React component",
            "Generate a Python function for data processing",
            "Design a minimalist logo for a tech startup"
        ]
        
        let options = XCTMeasureOptions()
        options.iterationCount = 10
        
        measure(options: options) {
            let expectation = XCTestExpectation()
            
            Task {
                for input in testInputs {
                    do {
                        let start = CFAbsoluteTimeGetCurrent()
                        _ = try await promptService.generatePrompt(
                            from: input,
                            context: PromptContext.default
                        )
                        let latency = CFAbsoluteTimeGetCurrent() - start
                        
                        // 断言延迟小于1.5秒
                        XCTAssertLessThan(latency, 1.5)
                    } catch {
                        XCTFail("Generation failed: \(error)")
                    }
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testMemoryUsageUnderLoad() async {
        // 测试高负载下的内存使用
        let initialMemory = getMemoryUsage()
        
        // 执行100次语音处理
        for i in 0..<100 {
            autoreleasepool {
                let audioBuffer = generateTestAudioBuffer(duration: 5)
                _ = AudioProcessor.applyNoiseReduction(audioBuffer)
                
                // 每10次检查一次内存使用
                if i % 10 == 0 {
                    let currentMemory = getMemoryUsage()
                    let memoryIncrease = currentMemory - initialMemory
                    
                    // 内存增长不应超过100MB
                    XCTAssertLessThan(memoryIncrease, 100 * 1024 * 1024)
                }
            }
        }
    }
    
    func testConcurrentOperations() async {
        // 测试并发操作性能
        let operationCount = 10
        let expectations = (0..<operationCount).map { _ in
            XCTestExpectation(description: "Concurrent operation")
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 启动并发操作
        for (index, expectation) in expectations.enumerated() {
            Task {
                do {
                    let input = "Test input \(index)"
                    _ = try await promptService.generatePrompt(
                        from: input,
                        context: PromptContext.default
                    )
                    expectation.fulfill()
                } catch {
                    XCTFail("Concurrent operation \(index) failed: \(error)")
                }
            }
        }
        
        await fulfillment(of: expectations, timeout: 20)
        
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // 10个并发操作应在10秒内完成
        XCTAssertLessThan(totalTime, 10.0)
    }
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    private func generateTestAudioBuffer(duration: TimeInterval) -> AudioBuffer {
        let sampleRate: Double = 16000
        let sampleCount = Int(duration * sampleRate)
        let samples = (0..<sampleCount).map { _ in Float.random(in: -1...1) }
        
        return AudioBuffer(
            samples: samples,
            sampleRate: sampleRate,
            channelCount: 1
        )
    }
}
```

### 6.3 自动化测试流程

#### 6.3.1 CI/CD集成测试
```yaml
# .github/workflows/test.yml
name: Automated Testing

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: '15.0'
    
    - name: Cache SPM dependencies
      uses: actions/cache@v3
      with:
        path: .build
        key: ${{ runner.os }}-spm-${{ hashFiles('**/Package.resolved') }}
        restore-keys: |
          ${{ runner.os }}-spm-
    
    - name: Resolve dependencies
      run: swift package resolve
    
    - name: Run SwiftLint
      run: |
        brew install swiftlint
        swiftlint --strict
    
    - name: Build project
      run: swift build -c release
    
    - name: Run unit tests
      run: swift test --enable-code-coverage
    
    - name: Generate coverage report
      run: |
        xcrun llvm-cov export \
          .build/debug/HelloPromptPackageTests.xctest/Contents/MacOS/HelloPromptPackageTests \
          -instr-profile .build/debug/codecov/default.profdata \
          -format="lcov" > coverage.lcov
    
    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        file: ./coverage.lcov
        flags: unittests
        name: codecov-umbrella
    
    - name: Run UI tests
      run: |
        xcodebuild test \
          -scheme HelloPrompt \
          -destination 'platform=macOS' \
          -enableCodeCoverage YES \
          -derivedDataPath DerivedData \
          -only-testing:HelloPromptUITests
    
    - name: Archive test results
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: test-results
        path: |
          DerivedData/Logs/Test
          coverage.lcov
```

## 7. 部署与运维

### 7.1 构建与打包流程

#### 7.1.1 自动化构建脚本
```bash
#!/bin/bash
# build_release.sh - 自动化发布构建脚本

set -e

# 配置变量
PROJECT_NAME="HelloPrompt"
SCHEME_NAME="HelloPrompt"
BUILD_DIR="build"
ARCHIVE_DIR="archives"
EXPORT_DIR="export"
VERSION=$(git describe --abbrev=0 --tags)

echo "🚀 Building ${PROJECT_NAME} v${VERSION}..."

# 清理之前的构建
echo "🧹 Cleaning previous builds..."
rm -rf "${BUILD_DIR}"
rm -rf "${ARCHIVE_DIR}"
rm -rf "${EXPORT_DIR}"

mkdir -p "${BUILD_DIR}"
mkdir -p "${ARCHIVE_DIR}"
mkdir -p "${EXPORT_DIR}"

# 验证环境
echo "🔍 Verifying build environment..."
xcode-select --print-path
swift --version

# 运行代码质量检查
echo "📝 Running code quality checks..."
swiftlint --strict
if [ $? -ne 0 ]; then
    echo "❌ SwiftLint check failed"
    exit 1
fi

# 运行测试
echo "🧪 Running tests..."
swift test --enable-code-coverage
if [ $? -ne 0 ]; then
    echo "❌ Tests failed"
    exit 1
fi

# 构建项目
echo "🔨 Building project..."
xcodebuild archive \
    -scheme "${SCHEME_NAME}" \
    -destination "generic/platform=macOS" \
    -archivePath "${ARCHIVE_DIR}/${PROJECT_NAME}.xcarchive" \
    -configuration Release \
    CODE_SIGN_IDENTITY="Developer ID Application" \
    OTHER_CODE_SIGN_FLAGS="--timestamp" \
    -allowProvisioningUpdates

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

# 导出应用
echo "📦 Exporting application..."
xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_DIR}/${PROJECT_NAME}.xcarchive" \
    -exportPath "${EXPORT_DIR}" \
    -exportOptionsPlist "ExportOptions.plist"

if [ $? -ne 0 ]; then
    echo "❌ Export failed"
    exit 1
fi

# 公证应用
echo "🔐 Notarizing application..."
BUNDLE_ID=$(defaults read "${EXPORT_DIR}/${PROJECT_NAME}.app/Contents/Info" CFBundleIdentifier)

xcrun notarytool submit "${EXPORT_DIR}/${PROJECT_NAME}.app" \
    --apple-id "${APPLE_ID}" \
    --team-id "${TEAM_ID}" \
    --password "${APP_SPECIFIC_PASSWORD}" \
    --wait

if [ $? -ne 0 ]; then
    echo "❌ Notarization failed"
    exit 1
fi

# 装订公证票据
echo "📎 Stapling notarization ticket..."
xcrun stapler staple "${EXPORT_DIR}/${PROJECT_NAME}.app"

# 创建DMG
echo "💿 Creating DMG..."
create-dmg \
    --volname "${PROJECT_NAME}" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "${PROJECT_NAME}.app" 175 250 \
    --app-drop-link 425 250 \
    --background "Assets/DMG/background.png" \
    "${EXPORT_DIR}/${PROJECT_NAME}-${VERSION}.dmg" \
    "${EXPORT_DIR}/"

# 公证DMG
echo "🔐 Notarizing DMG..."
xcrun notarytool submit "${EXPORT_DIR}/${PROJECT_NAME}-${VERSION}.dmg" \
    --apple-id "${APPLE_ID}" \
    --team-id "${TEAM_ID}" \
    --password "${APP_SPECIFIC_PASSWORD}" \
    --wait

xcrun stapler staple "${EXPORT_DIR}/${PROJECT_NAME}-${VERSION}.dmg"

# 生成校验和
echo "🔒 Generating checksums..."
cd "${EXPORT_DIR}"
shasum -a 256 "${PROJECT_NAME}-${VERSION}.dmg" > "${PROJECT_NAME}-${VERSION}.dmg.sha256"

echo "✅ Build completed successfully!"
echo "📁 Output: ${EXPORT_DIR}/${PROJECT_NAME}-${VERSION}.dmg"
echo "🔒 Checksum: ${EXPORT_DIR}/${PROJECT_NAME}-${VERSION}.dmg.sha256"
```

### 7.2 发布与分发

#### 7.2.1 GitHub Releases自动化
```yaml
# .github/workflows/release.yml
name: Release Build

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0
    
    - name: Setup Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: '15.0'
    
    - name: Import signing certificate
      env:
        SIGNING_CERTIFICATE_P12_DATA: ${{ secrets.SIGNING_CERTIFICATE_P12_DATA }}
        SIGNING_CERTIFICATE_PASSWORD: ${{ secrets.SIGNING_CERTIFICATE_PASSWORD }}
      run: |
        echo $SIGNING_CERTIFICATE_P12_DATA | base64 --decode > certificate.p12
        security create-keychain -p "" build.keychain
        security default-keychain -s build.keychain
        security unlock-keychain -p "" build.keychain
        security import certificate.p12 -k build.keychain -P $SIGNING_CERTIFICATE_PASSWORD -T /usr/bin/codesign
        security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" build.keychain
    
    - name: Build and package
      env:
        APPLE_ID: ${{ secrets.APPLE_ID }}
        TEAM_ID: ${{ secrets.TEAM_ID }}
        APP_SPECIFIC_PASSWORD: ${{ secrets.APP_SPECIFIC_PASSWORD }}
      run: |
        chmod +x Scripts/build_release.sh
        Scripts/build_release.sh
    
    - name: Generate release notes
      id: release_notes
      run: |
        python Scripts/generate_release_notes.py ${{ github.ref_name }} > release_notes.md
        echo "RELEASE_NOTES<<EOF" >> $GITHUB_OUTPUT
        cat release_notes.md >> $GITHUB_OUTPUT
        echo "EOF" >> $GITHUB_OUTPUT
    
    - name: Create GitHub Release
      uses: softprops/action-gh-release@v1
      with:
        name: Hello Prompt ${{ github.ref_name }}
        body: ${{ steps.release_notes.outputs.RELEASE_NOTES }}
        files: |
          export/HelloPrompt-*.dmg
          export/HelloPrompt-*.dmg.sha256
        draft: false
        prerelease: ${{ contains(github.ref_name, 'beta') || contains(github.ref_name, 'alpha') }}
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    
    - name: Update Homebrew formula
      if: ${{ !contains(github.ref_name, 'beta') && !contains(github.ref_name, 'alpha') }}
      run: |
        python Scripts/update_homebrew_formula.py \
          --version ${{ github.ref_name }} \
          --download-url "https://github.com/${{ github.repository }}/releases/download/${{ github.ref_name }}/HelloPrompt-${{ github.ref_name }}.dmg" \
          --checksum-file export/HelloPrompt-${{ github.ref_name }}.dmg.sha256
```

---

**文档状态**：正式版本  
**审批**：需技术负责人和架构师签字确认  
**更新日志**：
- V1.0 (2025-07-25)：初始版本，包含完整系统架构、模块设计、接口定义和测试策略