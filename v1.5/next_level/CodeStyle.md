# Hello Prompt - 代码风格与规范文档
**版本：V1.0**  
**日期：2025-07-25**  
**状态：正式版本**

## 1. 全局代码风格要求

### 1.1 代码风格原则
Hello Prompt项目遵循苹果官方Swift风格指南，并结合项目特性制定以下核心原则：

#### 1.1.1 可读性优先
- **清晰胜过简洁**：代码应该表达清晰的意图，避免过度简化导致的可读性下降
- **自解释代码**：变量和函数命名应该清楚表达其用途，减少注释依赖
- **一致性维护**：在整个项目中保持命名、格式和结构的一致性

#### 1.1.2 安全性保障
- **类型安全**：优先使用Swift的类型系统避免运行时错误
- **内存安全**：正确使用ARC，避免循环引用和内存泄漏
- **错误处理**：所有可能失败的操作都应有明确的错误处理机制

#### 1.1.3 性能意识
- **值类型优先**：优先使用struct和enum而非class，减少ARC开销
- **懒加载应用**：非关键组件采用lazy初始化，优化启动性能
- **资源管理**：主动管理音频缓冲区、网络连接等系统资源

### 1.2 SwiftLint配置

#### 1.2.1 基础配置文件
```yaml
# .swiftlint.yml
excluded:
  - Examples/
  - Tests/Mocks/
  - Package.swift
  - .build/

disabled_rules:
  - trailing_whitespace
  - force_cast # 临时例外，计划重构

opt_in_rules:
  - anyobject_protocol
  - collection_alignment
  - convenience_type
  - empty_count
  - enum_case_associated_values_count
  - explicit_acl
  - explicit_enum_raw_value
  - explicit_init
  - explicit_type_interface
  - function_default_parameter_at_end
  - implicitly_unwrapped_optional
  - multiline_arguments
  - multiline_function_chains
  - multiline_literal_brackets
  - multiline_parameters
  - operator_usage_whitespace
  - overridden_super_call
  - private_action
  - private_outlet
  - prohibited_interface_builder
  - redundant_nil_coalescing
  - redundant_type_annotation
  - sorted_first_last
  - switch_case_on_newline
  - toggle_bool
  - unneeded_parentheses_in_closure_argument
  - vertical_parameter_alignment_on_call
  - yoda_condition

# 规则参数配置
line_length:
  warning: 120
  error: 150
  ignores_function_declarations: true
  ignores_comments: true
  ignores_urls: true

type_name:
  min_length: 3
  max_length:
    warning: 40
    error: 50
  excluded:
    - iPhone
    - URL
    - UUID
    - API
    - HTTP
    - UI
    - ID

identifier_name:
  min_length:
    warning: 2
    error: 1
  max_length:
    warning: 40
    error: 60
  excluded:
    - id
    - url
    - db
    - ui
    - x
    - y
    - z

function_body_length:
  warning: 50
  error: 100

file_length:
  warning: 400
  error: 500

type_body_length:
  warning: 200
  error: 300

cyclomatic_complexity:
  warning: 10
  error: 20

nesting:
  type_level:
    warning: 2
    error: 3
  statement_level:
    warning: 5
    error: 10

# 自定义规则
custom_rules:
  force_https:
    name: "Force HTTPS"
    regex: "((?i)http(?!s))"
    match_kinds:
      - string
    message: "HTTPS should be favored over HTTP"
    severity: warning

  no_direct_standard_out_logs:
    name: "No Direct Standard Out Logs"
    regex: "(print|NSLog)\\s*\\("
    message: "Use Logger instead of print() or NSLog()"
    severity: warning

  no_hardcoded_strings:
    name: "No Hardcoded Strings in UI"
    regex: 'Text\s*\(\s*"[^"]*"\s*\)'
    match_kinds:
      - string
    message: "Use NSLocalizedString for UI text"
    severity: warning
```

#### 1.2.2 代码格式化规则
```swift
// 正确的代码格式示例

// 1. 导入语句分组排序
import Foundation
import Combine
import SwiftUI

import Alamofire
import AudioKit

// 2. MARK注释分区
class SpeechRecognitionService: ObservableObject {
    
    // MARK: - Properties
    
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var recordingState: RecordingState = .idle
    
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // MARK: - Initialization
    
    init(locale: Locale = .current) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        super.init()
        setupAudioEngine()
    }
    
    deinit {
        stopRecording()
        audioEngine.stop()
    }
    
    // MARK: - Public Methods
    
    func startRecording() async throws {
        guard let speechRecognizer = speechRecognizer,
              speechRecognizer.isAvailable else {
            throw SpeechError.recognizerNotAvailable
        }
        
        try await requestPermissions()
        try setupRecognitionRequest()
        
        await MainActor.run {
            self.isRecording = true
            self.recordingState = .recording(duration: 0)
        }
    }
    
    func stopRecording() async throws -> AudioBuffer {
        guard isRecording else {
            throw SpeechError.notRecording
        }
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        let audioBuffer = try extractAudioBuffer()
        
        await MainActor.run {
            self.isRecording = false
            self.recordingState = .idle
        }
        
        return audioBuffer
    }
    
    // MARK: - Private Methods
    
    private func requestPermissions() async throws {
        let speechAuthStatus = await SFSpeechRecognizer.requestAuthorization()
        guard speechAuthStatus == .authorized else {
            throw SpeechError.permissionDenied
        }
        
        let audioAuthStatus = await AVCaptureDevice.requestAccess(for: .audio)
        guard audioAuthStatus else {
            throw SpeechError.microphonePermissionDenied
        }
    }
    
    private func setupRecognitionRequest() throws {
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.unableToCreateRequest
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        if #available(macOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = true
        }
    }
}

// 3. 扩展按功能分组
extension SpeechRecognitionService {
    
    // MARK: - Audio Engine Setup
    
    private func setupAudioEngine() {
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: recordingFormat
        ) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
    }
}

// 4. 协议遵循单独扩展
extension SpeechRecognitionService: SpeechRecognitionServiceProtocol {
    
    var recordingStatePublisher: AnyPublisher<RecordingState, Never> {
        $recordingState.eraseToAnyPublisher()
    }
}
```

### 1.3 命名规范

#### 1.3.1 类型命名
```swift
// 类名：名词，UpperCamelCase
class SpeechRecognitionService { }
class PromptGenerationService { }

// 结构体：名词，UpperCamelCase
struct AudioBuffer { }
struct PromptContext { }

// 协议：形容词（-able/-ible结尾）或名词
protocol SpeechRecognitionServiceProtocol { }
protocol Recordable { }
protocol AudioProcessible { }

// 枚举：名词，UpperCamelCase
enum RecordingState {
    case idle
    case recording
    case processing
}

// 枚举案例：lowerCamelCase
enum PromptDomain {
    case coding(language: ProgrammingLanguage)
    case design(style: ArtStyle)
    case writing(genre: WritingGenre)
    case general
}
```

#### 1.3.2 方法命名
```swift
// 动作方法：动词开头
func startRecording() { }
func stopRecording() -> AudioBuffer { }
func generatePrompt(from text: String) -> Prompt { }

// 查询方法：get/is/has/can开头
func getRecordingState() -> RecordingState { }
func isRecording() -> Bool { }
func hasPermission() -> Bool { }
func canStartRecording() -> Bool { }

// 转换方法：动词+介词
func convert(text: String, to format: OutputFormat) { }
func transform(audio: AudioBuffer, with processor: AudioProcessor) { }

// 工厂方法：make/create开头
static func makeDefaultConfiguration() -> Configuration { }
static func createPromptTemplate(for domain: PromptDomain) -> PromptTemplate { }

// 参数标签清晰表达意图
func save(_ prompt: Prompt, to repository: PromptRepository) { }
func load(promptWith id: UUID, from repository: PromptRepository) -> Prompt? { }
```

#### 1.3.3 属性命名
```swift
// 存储属性：名词
private let audioEngine: AVAudioEngine
private var recordingState: RecordingState
private let speechRecognizer: SFSpeechRecognizer?

// 计算属性：名词或形容词
var isRecording: Bool { }
var recordingDuration: TimeInterval { }
var qualityScore: Double { }

// 布尔属性：is/has/can/should开头
var isEnabled: Bool
var hasPermission: Bool
var canRecord: Bool
var shouldAutoStop: Bool

// 集合属性：复数形式
var availableTemplates: [PromptTemplate]
var recordedSamples: [Float]
var activeConnections: Set<WebSocketConnection>
```

## 2. 组件特定代码规范

### 2.1 UI层代码规范

#### 2.1.1 SwiftUI视图结构
```swift
// 视图文件结构标准
struct PromptGeneratorView: View {
    
    // MARK: - Properties
    
    @StateObject private var viewModel: PromptGeneratorViewModel
    @State private var showingSettings = false
    @State private var recordingAnimation = false
    
    // MARK: - Initialization
    
    init(speechService: SpeechRecognitionServiceProtocol = SpeechRecognitionService.shared) {
        self._viewModel = StateObject(wrappedValue: PromptGeneratorViewModel(speechService: speechService))
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 16) {
            headerView
            recordingView
            promptPreviewView
            actionButtonsView
        }
        .padding()
        .background(backgroundView)
        .onAppear { viewModel.setupInitialState() }
        .onChange(of: viewModel.recordingState) { oldValue, newValue in
            handleRecordingStateChange(from: oldValue, to: newValue)
        }
        .sheet(isPresented: $showingSettings) {
            PreferencesView()
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK") { viewModel.dismissError() }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var headerView: some View {
        HStack {
            Text("Hello Prompt")
                .font(.title)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gear")
                    .font(.title2)
            }
            .buttonStyle(.borderless)
        }
    }
    
    @ViewBuilder
    private var recordingView: some View {
        ZStack {
            Circle()
                .fill(recordingBackgroundColor)
                .frame(width: 80, height: 80)
                .scaleEffect(recordingAnimation ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: recordingAnimation)
            
            Image(systemName: recordingIcon)
                .font(.system(size: 32))
                .foregroundColor(.white)
        }
        .onTapGesture {
            Task {
                await viewModel.toggleRecording()
            }
        }
    }
    
    @ViewBuilder
    private var promptPreviewView: some View {
        if let prompt = viewModel.currentPrompt {
            VStack(alignment: .leading, spacing: 8) {
                Text("Generated Prompt")
                    .font(.headline)
                
                ScrollView {
                    Text(prompt.content)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    @ViewBuilder
    private var actionButtonsView: some View {
        if viewModel.currentPrompt != nil {
            HStack(spacing: 12) {
                Button("Modify") {
                    Task {
                        await viewModel.startModification()
                    }
                }
                .buttonStyle(.bordered)
                
                Button("Copy") {
                    viewModel.copyPromptToClipboard()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Insert") {
                    Task {
                        await viewModel.insertPromptAtCursor()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .transition(.move(edge: .bottom))
        }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
            .ignoresSafeArea()
    }
    
    // MARK: - Computed Properties
    
    private var recordingBackgroundColor: Color {
        switch viewModel.recordingState {
        case .idle:
            return .secondary
        case .recording:
            return .green
        case .processing:
            return .blue
        case .error:
            return .red
        }
    }
    
    private var recordingIcon: String {
        switch viewModel.recordingState {
        case .idle:
            return "mic"
        case .recording:
            return "mic.fill"
        case .processing:
            return "waveform"
        case .error:
            return "exclamationmark.triangle"
        }
    }
    
    // MARK: - Private Methods
    
    private func handleRecordingStateChange(from oldState: RecordingState, to newState: RecordingState) {
        withAnimation(.easeInOut(duration: 0.3)) {
            recordingAnimation = newState == .recording
        }
        
        // 提供触觉反馈
        if case .recording = newState {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct PromptGeneratorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 默认状态
            PromptGeneratorView()
                .previewDisplayName("Default State")
            
            // 录音状态
            PromptGeneratorView()
                .previewDisplayName("Recording State")
                .onAppear {
                    // 模拟录音状态
                }
            
            // 深色模式
            PromptGeneratorView()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
        .frame(width: 400, height: 600)
    }
}
#endif
```

#### 2.1.2 ViewModel规范
```swift
// ViewModel应遵循MVVM模式的严格分离
@MainActor
class PromptGeneratorViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var recordingState: RecordingState = .idle
    @Published private(set) var currentPrompt: Prompt?
    @Published private(set) var isProcessing = false
    @Published private(set) var errorMessage = ""
    @Published var showingError = false
    
    // MARK: - Dependencies
    
    private let speechService: SpeechRecognitionServiceProtocol
    private let promptService: PromptGenerationServiceProtocol
    private let clipboardService: ClipboardServiceProtocol
    private let insertionService: TextInsertionServiceProtocol
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.helloprompt", category: "PromptGenerator")
    
    // MARK: - Initialization
    
    init(
        speechService: SpeechRecognitionServiceProtocol,
        promptService: PromptGenerationServiceProtocol = PromptGenerationService.shared,
        clipboardService: ClipboardServiceProtocol = ClipboardService.shared,
        insertionService: TextInsertionServiceProtocol = TextInsertionService.shared
    ) {
        self.speechService = speechService
        self.promptService = promptService
        self.clipboardService = clipboardService
        self.insertionService = insertionService
        
        setupSubscriptions()
    }
    
    // MARK: - Public Methods
    
    func setupInitialState() {
        logger.info("Setting up initial state")
        
        // 验证权限
        Task {
            await checkPermissions()
        }
    }
    
    func toggleRecording() async {
        switch recordingState {
        case .idle:
            await startRecording()
        case .recording:
            await stopRecording()
        case .processing:
            logger.warning("Cannot toggle recording while processing")
        case .error:
            await resetState()
        }
    }
    
    func startModification() async {
        guard let currentPrompt = currentPrompt else {
            logger.error("No current prompt to modify")
            return
        }
        
        logger.info("Starting modification for prompt: \(currentPrompt.id)")
        
        do {
            try await speechService.startRecording()
            recordingState = .recording
        } catch {
            await handleError(error)
        }
    }
    
    func copyPromptToClipboard() {
        guard let prompt = currentPrompt else { return }
        
        clipboardService.copy(prompt.content)
        logger.info("Copied prompt to clipboard")
        
        // 显示成功反馈
        showTemporarySuccess("Copied to clipboard")
    }
    
    func insertPromptAtCursor() async {
        guard let prompt = currentPrompt else { return }
        
        do {
            try await insertionService.insertText(prompt.content)
            logger.info("Inserted prompt at cursor position")
            showTemporarySuccess("Prompt inserted")
        } catch {
            await handleError(error)
        }
    }
    
    func dismissError() {
        showingError = false
        errorMessage = ""
    }
    
    // MARK: - Private Methods
    
    private func setupSubscriptions() {
        // 监听语音服务状态变化
        speechService.recordingStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.recordingState = state
            }
            .store(in: &cancellables)
        
        // 监听错误
        speechService.errorPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                Task {
                    await self?.handleError(error)
                }
            }
            .store(in: &cancellables)
    }
    
    private func startRecording() async {
        logger.info("Starting recording")
        
        do {
            try await speechService.startRecording()
        } catch {
            await handleError(error)
        }
    }
    
    private func stopRecording() async {
        logger.info("Stopping recording")
        
        do {
            isProcessing = true
            let audioBuffer = try await speechService.stopRecording()
            let prompt = try await promptService.generatePrompt(from: audioBuffer)
            
            currentPrompt = prompt
            logger.info("Generated prompt with \(prompt.content.count) characters")
        } catch {
            await handleError(error)
        }
        
        isProcessing = false
    }
    
    private func checkPermissions() async {
        let speechPermission = await speechService.requestSpeechPermission()
        let microphonePermission = await speechService.requestMicrophonePermission()
        
        if !speechPermission || !microphonePermission {
            await handleError(PermissionError.permissionsRequired)
        }
    }
    
    private func resetState() async {
        logger.info("Resetting state after error")
        recordingState = .idle
        currentPrompt = nil
        isProcessing = false
        dismissError()
    }
    
    private func handleError(_ error: Error) async {
        logger.error("Error occurred: \(error.localizedDescription)")
        
        errorMessage = error.localizedDescription
        showingError = true
        recordingState = .error(error)
        isProcessing = false
    }
    
    private func showTemporarySuccess(_ message: String) {
        // 实现临时成功提示
        // 可以使用第三方通知库或自定义实现
    }
}

// MARK: - Error Types

enum PermissionError: LocalizedError {
    case permissionsRequired
    
    var errorDescription: String? {
        switch self {
        case .permissionsRequired:
            return "Speech and microphone permissions are required to use this feature."
        }
    }
}
```

### 2.2 Service层代码规范

#### 2.2.1 服务类设计模式
```swift
// 协议定义服务接口
protocol PromptGenerationServiceProtocol {
    var isProcessing: Bool { get }
    var processingState: AnyPublisher<ProcessingState, Never> { get }
    
    func generatePrompt(
        from audioBuffer: AudioBuffer,
        context: PromptContext,
        options: GenerationOptions
    ) async throws -> Prompt
    
    func optimizePrompt(
        _ prompt: Prompt,
        with modifications: [ModificationInstruction]
    ) async throws -> Prompt
    
    func validatePrompt(
        _ prompt: Prompt,
        for platform: TargetPlatform
    ) async throws -> ValidationResult
}

// 具体实现类
final class PromptGenerationService: PromptGenerationServiceProtocol {
    
    // MARK: - Properties
    
    @Published private(set) var isProcessing = false
    @Published private(set) var currentState: ProcessingState = .idle
    
    // MARK: - Dependencies
    
    private let apiClient: OpenAIClientProtocol
    private let templateEngine: TemplateEngineProtocol
    private let cacheService: CacheServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol
    
    // MARK: - Private Properties
    
    private let processingQueue = DispatchQueue(label: "prompt.generation", qos: .userInitiated)
    private let logger = Logger(subsystem: "com.helloprompt", category: "PromptGeneration")
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        apiClient: OpenAIClientProtocol,
        templateEngine: TemplateEngineProtocol = TemplateEngine.shared,
        cacheService: CacheServiceProtocol = CacheService.shared,
        analyticsService: AnalyticsServiceProtocol = AnalyticsService.shared
    ) {
        self.apiClient = apiClient
        self.templateEngine = templateEngine
        self.cacheService = cacheService
        self.analyticsService = analyticsService
    }
    
    // MARK: - Public Methods
    
    func generatePrompt(
        from audioBuffer: AudioBuffer,
        context: PromptContext = .default,
        options: GenerationOptions = .default
    ) async throws -> Prompt {
        
        logger.info("Starting prompt generation for audio buffer of \(audioBuffer.duration) seconds")
        
        // 更新状态
        await updateState(.transcribing)
        
        do {
            // 1. 转录音频
            let transcription = try await transcribeAudio(audioBuffer)
            logger.debug("Transcription completed: \(transcription.text.prefix(50))...")
            
            // 2. 检查缓存
            let cacheKey = generateCacheKey(text: transcription.text, context: context)
            if let cachedPrompt = await cacheService.get(key: cacheKey, type: Prompt.self) {
                logger.info("Found cached prompt")
                await updateState(.completed)
                return cachedPrompt
            }
            
            // 3. 选择模板
            await updateState(.analyzing)
            let template = try templateEngine.selectOptimalTemplate(
                for: transcription.text,
                context: context
            )
            
            // 4. 生成提示词
            await updateState(.generating)
            let generatedPrompt = try await generatePromptFromTemplate(
                text: transcription.text,
                template: template,
                context: context,
                options: options
            )
            
            // 5. 缓存结果
            await cacheService.set(key: cacheKey, value: generatedPrompt, ttl: 600) // 10分钟
            
            // 6. 记录分析数据
            await recordAnalytics(
                prompt: generatedPrompt,
                transcription: transcription,
                template: template
            )
            
            await updateState(.completed)
            logger.info("Prompt generation completed successfully")
            
            return generatedPrompt
            
        } catch {
            logger.error("Prompt generation failed: \(error)")
            await updateState(.error(error))
            throw error
        }
    }
    
    func optimizePrompt(
        _ prompt: Prompt,
        with modifications: [ModificationInstruction]
    ) async throws -> Prompt {
        
        logger.info("Optimizing prompt with \(modifications.count) modifications")
        
        await updateState(.optimizing)
        
        do {
            var optimizedContent = prompt.content
            
            for modification in modifications {
                optimizedContent = try await applyModification(
                    modification,
                    to: optimizedContent,
                    originalPrompt: prompt
                )
            }
            
            var optimizedPrompt = prompt
            optimizedPrompt.content = optimizedContent
            optimizedPrompt.addModification(
                PromptModification(
                    type: .optimize,
                    instruction: "Applied \(modifications.count) modifications",
                    previousContent: prompt.content,
                    newContent: optimizedContent,
                    timestamp: Date()
                )
            )
            
            await updateState(.completed)
            logger.info("Prompt optimization completed")
            
            return optimizedPrompt
            
        } catch {
            logger.error("Prompt optimization failed: \(error)")
            await updateState(.error(error))
            throw error
        }
    }
    
    // MARK: - Computed Properties
    
    var processingState: AnyPublisher<ProcessingState, Never> {
        $currentState.eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func updateState(_ state: ProcessingState) {
        currentState = state
        isProcessing = !state.isTerminal
    }
    
    private func transcribeAudio(_ audioBuffer: AudioBuffer) async throws -> TranscriptionResult {
        let request = TranscriptionRequest(
            audio: audioBuffer,
            model: "whisper-1",
            language: nil,
            temperature: 0.0
        )
        
        return try await apiClient.transcribe(request)
    }
    
    private func generatePromptFromTemplate(
        text: String,
        template: PromptTemplate,
        context: PromptContext,
        options: GenerationOptions
    ) async throws -> Prompt {
        
        let systemPrompt = template.buildSystemPrompt(for: context)
        let userPrompt = template.buildUserPrompt(from: text)
        
        let chatRequest = ChatCompletionRequest(
            model: selectModel(for: context),
            messages: [
                .system(systemPrompt),
                .user(userPrompt)
            ],
            temperature: options.creativity,
            maxTokens: options.maxLength
        )
        
        let response = try await apiClient.chatCompletion(chatRequest)
        let generatedContent = response.choices.first?.message.content ?? ""
        
        return Prompt(
            content: generatedContent,
            originalText: text,
            domain: context.domain,
            confidence: response.usage.confidenceScore
        )
    }
    
    private func applyModification(
        _ modification: ModificationInstruction,
        to content: String,
        originalPrompt: Prompt
    ) async throws -> String {
        
        let modificationPrompt = buildModificationPrompt(
            instruction: modification,
            currentContent: content,
            originalPrompt: originalPrompt
        )
        
        let request = ChatCompletionRequest(
            model: "gpt-4",
            messages: [.user(modificationPrompt)],
            temperature: 0.3,
            maxTokens: 1000
        )
        
        let response = try await apiClient.chatCompletion(request)
        return response.choices.first?.message.content ?? content
    }
    
    private func selectModel(for context: PromptContext) -> String {
        switch context.domain {
        case .coding:
            return "gpt-4-turbo"
        case .design:
            return "gpt-4o"
        case .writing:
            return "gpt-4"
        case .general:
            return "gpt-4o-mini"
        }
    }
    
    private func generateCacheKey(text: String, context: PromptContext) -> String {
        let contextData = "\(context.domain)-\(context.targetPlatform)"
        let textHash = text.sha256
        return "prompt_\(textHash)_\(contextData.sha256)"
    }
    
    private func buildModificationPrompt(
        instruction: ModificationInstruction,
        currentContent: String,
        originalPrompt: Prompt
    ) -> String {
        return """
        Please modify the following prompt according to the instruction:
        
        Current prompt:
        \(currentContent)
        
        Modification instruction:
        \(instruction.description)
        
        Please return only the modified prompt without any explanation.
        """
    }
    
    private func recordAnalytics(
        prompt: Prompt,
        transcription: TranscriptionResult,
        template: PromptTemplate
    ) async {
        let analytics = PromptGenerationAnalytics(
            promptId: prompt.id,
            templateId: template.id,
            domain: prompt.domain,
            transcriptionDuration: transcription.duration,
            generationDuration: 0, // 计算实际生成时间
            qualityScore: prompt.qualityScore,
            wordCount: prompt.metadata.wordCount,
            tokenCount: prompt.metadata.estimatedTokens
        )
        
        await analyticsService.record(analytics)
    }
}

// MARK: - Supporting Types

enum ProcessingState {
    case idle
    case transcribing
    case analyzing
    case generating
    case optimizing
    case completed
    case error(Error)
    
    var isTerminal: Bool {
        switch self {
        case .completed, .error:
            return true
        default:
            return false
        }
    }
}

struct GenerationOptions {
    let creativity: Double // 0.0 - 1.0
    let maxLength: Int
    let includeExamples: Bool
    let optimizeFor: TargetPlatform
    
    static let `default` = GenerationOptions(
        creativity: 0.7,
        maxLength: 500,
        includeExamples: true,
        optimizeFor: .chatGPT
    )
}
```

### 2.3 Core层代码规范

#### 2.3.1 数据模型设计
```swift
// 使用值类型优先原则
struct Prompt: Identifiable, Codable, Equatable, Hashable {
    
    // MARK: - Properties
    
    let id: UUID
    var content: String
    let originalText: String
    private(set) var history: [PromptModification]
    let timestamp: Date
    let confidence: Double
    let domain: PromptDomain
    var metadata: PromptMetadata
    
    // MARK: - Initialization
    
    init(
        content: String,
        originalText: String,
        domain: PromptDomain = .general,
        confidence: Double = 0.0,
        metadata: PromptMetadata = PromptMetadata()
    ) {
        self.id = UUID()
        self.content = content
        self.originalText = originalText
        self.history = []
        self.timestamp = Date()
        self.confidence = confidence
        self.domain = domain
        self.metadata = metadata
        
        // 自动计算初始元数据
        self.metadata.updateWordCount(from: content)
        self.metadata.updateTokenEstimate(from: content)
    }
    
    // MARK: - Computed Properties
    
    /// 计算提示词质量评分（0-100）
    var qualityScore: Double {
        let components = QualityComponents(
            lengthScore: calculateLengthScore(),
            structureScore: calculateStructureScore(),
            clarityScore: calculateClarityScore(),
            completenessScore: calculateCompletenessScore()
        )
        
        return components.weightedAverage
    }
    
    /// 估算token数量（基于OpenAI tokenizer规则）
    var estimatedTokenCount: Int {
        // 简化估算：1 token ≈ 4 characters for English
        let baseCount = content.count / 4
        
        // 调整：中文字符通常需要更多token
        let chineseCharCount = content.unicodeScalars.filter { 
            $0.value >= 0x4E00 && $0.value <= 0x9FFF 
        }.count
        let adjustment = chineseCharCount / 2
        
        return baseCount + adjustment
    }
    
    /// 检查是否包含敏感内容
    var containsSensitiveContent: Bool {
        let sensitiveKeywords = ["password", "secret", "private", "confidential"]
        return sensitiveKeywords.contains { content.lowercased().contains($0) }
    }
    
    // MARK: - Mutating Methods
    
    /// 添加修改记录
    mutating func addModification(_ modification: PromptModification) {
        history.append(modification)
        
        // 限制历史记录长度
        if history.count > 10 {
            history.removeFirst()
        }
        
        // 更新元数据
        metadata.updateUsageStatistics()
        metadata.updateWordCount(from: content)
        metadata.updateTokenEstimate(from: content)
    }
    
    /// 更新内容并记录修改
    mutating func updateContent(
        _ newContent: String,
        modification: ModificationType,
        instruction: String = ""
    ) {
        let previousContent = content
        content = newContent
        
        let modification = PromptModification(
            type: modification,
            instruction: instruction,
            previousContent: previousContent,
            newContent: newContent,
            timestamp: Date()
        )
        
        addModification(modification)
    }
    
    /// 重置到指定历史版本
    mutating func revertToVersion(_ version: Int) throws {
        guard version >= 0 && version < history.count else {
            throw PromptError.invalidVersion
        }
        
        let targetModification = history[version]
        content = targetModification.previousContent
        
        // 移除后续历史记录
        history = Array(history.prefix(version))
    }
    
    // MARK: - Private Methods
    
    private func calculateLengthScore() -> Double {
        // 适中的长度得分最高
        let optimalLength = 300.0
        let actualLength = Double(content.count)
        
        if actualLength <= optimalLength {
            return actualLength / optimalLength
        } else {
            return max(0.0, 1.0 - (actualLength - optimalLength) / optimalLength)
        }
    }
    
    private func calculateStructureScore() -> Double {
        var score = 0.0
        
        // 检查结构化元素
        if content.contains(#/\d+\.//) { score += 0.25 } // 编号列表
        if content.contains(#/[•\-\*]//) { score += 0.25 } // 项目符号
        if content.contains(#/#{1,6}\s//) { score += 0.25 } // 标题
        if content.contains("```") { score += 0.25 } // 代码块
        
        return score
    }
    
    private func calculateClarityScore() -> Double {
        // 基于句子长度和复杂度计算清晰度
        let sentences = content.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        let averageLength = sentences.map(\.count).reduce(0, +) / max(sentences.count, 1)
        
        // 适中的句子长度得分更高
        let optimalLength = 20.0
        let lengthFactor = min(1.0, optimalLength / Double(averageLength))
        
        return lengthFactor
    }
    
    private func calculateCompletenessScore() -> Double {
        // 检查关键元素的完整性
        var completeness = 0.0
        
        // 有明确的指令动词
        let actionWords = ["create", "generate", "write", "design", "build", "implement"]
        if actionWords.contains(where: { content.lowercased().contains($0) }) {
            completeness += 0.3
        }
        
        // 有具体的要求或约束
        if content.contains(":") || content.contains("requirements") || content.contains("constraints") {
            completeness += 0.4
        }
        
        // 有输出格式说明
        if content.contains("format") || content.contains("style") || content.contains("output") {
            completeness += 0.3
        }
        
        return min(1.0, completeness)
    }
}

// MARK: - Supporting Types

struct QualityComponents {
    let lengthScore: Double
    let structureScore: Double
    let clarityScore: Double
    let completenessScore: Double
    
    var weightedAverage: Double {
        let weights = (length: 0.2, structure: 0.3, clarity: 0.3, completeness: 0.2)
        
        return (lengthScore * weights.length +
                structureScore * weights.structure +
                clarityScore * weights.clarity +
                completenessScore * weights.completeness) * 100
    }
}

struct PromptModification: Identifiable, Codable {
    let id: UUID
    let type: ModificationType
    let instruction: String
    let previousContent: String
    let newContent: String
    let timestamp: Date
    
    init(
        type: ModificationType,
        instruction: String,
        previousContent: String,
        newContent: String,
        timestamp: Date = Date()
    ) {
        self.id = UUID()
        self.type = type
        self.instruction = instruction
        self.previousContent = previousContent
        self.newContent = newContent
        self.timestamp = timestamp
    }
}

enum ModificationType: String, Codable, CaseIterable {
    case add = "add"
    case remove = "remove"
    case modify = "modify"
    case format = "format"
    case tone = "tone"
    case optimize = "optimize"
    
    var displayName: String {
        switch self {
        case .add: return "Added Content"
        case .remove: return "Removed Content"
        case .modify: return "Modified Content"
        case .format: return "Format Change"
        case .tone: return "Tone Adjustment"
        case .optimize: return "Optimization"
        }
    }
}

enum PromptError: LocalizedError {
    case invalidVersion
    case contentTooLong
    case sensitiveContentDetected
    
    var errorDescription: String? {
        switch self {
        case .invalidVersion:
            return "Invalid version number for prompt history"
        case .contentTooLong:
            return "Prompt content exceeds maximum length"
        case .sensitiveContentDetected:
            return "Prompt contains sensitive content that should not be shared"
        }
    }
}
```

## 3. 全局日志配置与要求

### 3.1 日志系统架构

#### 3.1.1 Logger配置
```swift
import OSLog

// 全局日志配置
extension Logger {
    
    // MARK: - Subsystem Definition
    
    private static let subsystem = "com.helloprompt"
    
    // MARK: - Category Loggers
    
    static let ui = Logger(subsystem: subsystem, category: "UI")
    static let service = Logger(subsystem: subsystem, category: "Service")
    static let network = Logger(subsystem: subsystem, category: "Network")
    static let audio = Logger(subsystem: subsystem, category: "Audio")
    static let speech = Logger(subsystem: subsystem, category: "Speech")
    static let prompt = Logger(subsystem: subsystem, category: "Prompt")
    static let system = Logger(subsystem: subsystem, category: "System")
    static let storage = Logger(subsystem: subsystem, category: "Storage")
    static let security = Logger(subsystem: subsystem, category: "Security")
    static let performance = Logger(subsystem: subsystem, category: "Performance")
    static let analytics = Logger(subsystem: subsystem, category: "Analytics")
    
    // MARK: - Convenience Methods
    
    /// 记录方法进入
    func entering(_ function: String = #function, file: String = #file) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        self.debug("→ Entering \(fileName).\(function)")
    }
    
    /// 记录方法退出
    func exiting(_ function: String = #function, file: String = #file) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        self.debug("← Exiting \(fileName).\(function)")
    }
    
    /// 记录方法执行时间
    func measureTime<T>(
        _ operation: String,
        function: String = #function,
        _ block: () throws -> T
    ) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            self.info("⏱️ \(operation) completed in \(String(format: "%.3f", timeElapsed))s [\(function)]")
        }
        return try block()
    }
    
    /// 记录异步方法执行时间
    func measureTime<T>(
        _ operation: String,
        function: String = #function,
        _ block: () async throws -> T
    ) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            self.info("⏱️ \(operation) completed in \(String(format: "%.3f", timeElapsed))s [\(function)]")
        }
        return try await block()
    }
    
    /// 记录网络请求详情
    func networkRequest(
        method: String,
        url: String,
        headers: [String: String]? = nil,
        function: String = #function
    ) {
        var logMessage = "🌐 \(method) \(url)"
        if let headers = headers, !headers.isEmpty {
            logMessage += " | Headers: \(headers.description)"
        }
        logMessage += " [\(function)]"
        self.info("\(logMessage)")
    }
    
    /// 记录网络响应
    func networkResponse(
        statusCode: Int,
        url: String,
        responseTime: TimeInterval,
        function: String = #function
    ) {
        let statusEmoji = statusCode < 400 ? "✅" : "❌"
        self.info("\(statusEmoji) \(statusCode) \(url) in \(String(format: "%.3f", responseTime))s [\(function)]")
    }
    
    /// 记录用户操作
    func userAction(_ action: String, parameters: [String: Any]? = nil) {
        var logMessage = "👤 User: \(action)"
        if let parameters = parameters, !parameters.isEmpty {
            logMessage += " | Parameters: \(parameters)"
        }
        self.info("\(logMessage)")
    }
    
    /// 记录状态变化
    func stateChange(from oldState: String, to newState: String, context: String = "") {
        let contextInfo = context.isEmpty ? "" : " | \(context)"
        self.info("🔄 State: \(oldState) → \(newState)\(contextInfo)")
    }
    
    /// 记录性能指标
    func performance(metric: String, value: Double, unit: String = "") {
        let unitInfo = unit.isEmpty ? "" : " \(unit)"
        self.info("📊 Performance: \(metric) = \(value)\(unitInfo)")
    }
    
    /// 记录安全相关事件
    func security(_ event: String, severity: SecuritySeverity = .info) {
        let emoji = severity.emoji
        let level = severity.rawValue.uppercased()
        self.info("\(emoji) Security [\(level)]: \(event)")
    }
}

enum SecuritySeverity: String {
    case info = "info"
    case warning = "warning"  
    case critical = "critical"
    
    var emoji: String {
        switch self {
        case .info: return "🔒"
        case .warning: return "⚠️"
        case .critical: return "🚨"
        }
    }
}
```

### 3.2 模块特定日志要求

#### 3.2.1 UI模块日志规范
```swift
// UI模块日志示例
class PromptGeneratorViewModel: ObservableObject {
    
    private let logger = Logger.ui
    
    @Published private(set) var recordingState: RecordingState = .idle {
        didSet {
            logger.stateChange(
                from: oldValue.description,
                to: recordingState.description,
                context: "RecordingState"
            )
        }
    }
    
    func toggleRecording() async {
        logger.entering()
        logger.userAction("Toggle Recording", parameters: ["currentState": recordingState.description])
        
        switch recordingState {
        case .idle:
            await startRecording()
        case .recording:
            await stopRecording()
        case .processing:
            logger.warning("Cannot toggle recording while processing")
        case .error(let error):
            logger.info("Resetting from error state: \(error.localizedDescription)")
            await resetState()
        }
        
        logger.exiting()
    }
    
    private func startRecording() async {
        logger.info("Starting recording session")
        
        do {
            try await speechService.startRecording()
            logger.info("Recording started successfully")
        } catch {
            logger.error("Failed to start recording: \(error.localizedDescription)")
            await handleError(error)
        }
    }
    
    private func handleError(_ error: Error) async {
        logger.error("Handling error: \(error)")
        
        // 记录错误上下文
        let context = [
            "currentState": recordingState.description,
            "isProcessing": isProcessing,
            "hasCurrentPrompt": currentPrompt != nil
        ]
        
        logger.error("Error context: \(context)")
        
        // 实现错误处理逻辑
        errorMessage = error.localizedDescription
        showingError = true
        recordingState = .error(error)
    }
}
```

#### 3.2.2 Service模块日志规范
```swift
// Service模块日志示例
class SpeechRecognitionService: ObservableObject {
    
    private let logger = Logger.speech
    
    func startRecording() async throws {
        logger.entering()
        
        // 验证前置条件
        guard !isRecording else {
            logger.warning("Attempted to start recording while already recording")
            throw SpeechError.alreadyRecording
        }
        
        logger.info("Requesting permissions")
        let hasPermissions = await requestPermissions()
        guard hasPermissions else {
            logger.error("Permissions denied for speech recognition")
            throw SpeechError.permissionDenied
        }
        
        logger.info("Setting up audio engine")
        try setupAudioEngine()
        
        logger.info("Starting audio engine")
        try audioEngine.start()
        
        logger.performance(metric: "AudioEngineStartupTime", value: startupTime)
        
        await MainActor.run {
            self.isRecording = true
            self.recordingState = .recording
        }
        
        logger.info("Recording started successfully")
        logger.exiting()
    }
    
    func stopRecording() async throws -> AudioBuffer {
        logger.entering()
        
        guard isRecording else {
            logger.warning("Attempted to stop recording when not recording")
            throw SpeechError.notRecording
        }
        
        logger.info("Stopping audio engine")
        audioEngine.stop()
        
        logger.info("Processing recorded audio")
        let audioBuffer = try await logger.measureTime("Audio Processing") {
            try processRecordedAudio()
        }
        
        logger.info("Audio processed: \(audioBuffer.duration)s, \(audioBuffer.samples.count) samples")
        logger.performance(metric: "AudioBufferDuration", value: audioBuffer.duration, unit: "seconds")
        logger.performance(metric: "AudioBufferSamples", value: Double(audioBuffer.samples.count), unit: "samples")
        
        // 质量检查
        let qualityMetrics = audioBuffer.qualityMetrics
        logger.performance(metric: "AudioQuality", value: qualityMetrics.signalToNoiseRatio, unit: "dB")
        
        if qualityMetrics.clippingDetected {
            logger.warning("Audio clipping detected in recording")
        }
        
        await MainActor.run {
            self.isRecording = false
            self.recordingState = .idle
        }
        
        logger.exiting()
        return audioBuffer
    }
    
    private func processRecordedAudio() throws -> AudioBuffer {
        logger.info("Applying noise reduction")
        let denoisedBuffer = AudioProcessor.applyNoiseReduction(rawAudioBuffer)
        
        logger.info("Detecting voice activity")
        let vadResult = AudioProcessor.detectVoiceActivity(denoisedBuffer)
        logger.info("VAD result: \(vadResult.isSilent ? "Silent" : "Voice") detected")
        
        return denoisedBuffer
    }
}
```

#### 3.2.3 Network模块日志规范
```swift
// Network模块日志示例
class OpenAIService {
    
    private let logger = Logger.network
    
    func transcribe(_ request: TranscriptionRequest) async throws -> TranscriptionResult {
        logger.entering()
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let url = "\(baseURL)/audio/transcriptions"
        
        logger.networkRequest(
            method: "POST",
            url: url,
            headers: ["Content-Type": "multipart/form-data"]
        )
        
        do {
            let httpRequest = try buildHTTPRequest(request, url: url)
            
            logger.info("Sending transcription request: \(request.audio.duration)s audio")
            
            let (data, response) = try await URLSession.shared.data(for: httpRequest)
            let responseTime = CFAbsoluteTimeGetCurrent() - startTime
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response type")
                throw NetworkError.invalidResponse
            }
            
            logger.networkResponse(
                statusCode: httpResponse.statusCode,
                url: url,
                responseTime: responseTime
            )
            
            // 记录API使用统计
            logger.info("API Usage: \(data.count) bytes received")
            
            let result = try parseTranscriptionResponse(data)
            
            logger.info("Transcription completed: \(result.text.count) characters")
            logger.performance(metric: "TranscriptionLatency", value: responseTime, unit: "seconds")
            logger.performance(metric: "TranscriptionSpeed", value: request.audio.duration / responseTime, unit: "x realtime")
            
            logger.exiting()
            return result
            
        } catch let error as NetworkError {
            logger.error("Network error during transcription: \(error)")
            throw error
        } catch {
            logger.error("Unexpected error during transcription: \(error)")
            throw NetworkError.unknown(error)
        }
    }
    
    private func buildHTTPRequest(_ request: TranscriptionRequest, url: String) throws -> URLRequest {
        logger.info("Building multipart request")
        
        var httpRequest = URLRequest(url: URL(string: url)!)
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let boundary = UUID().uuidString
        httpRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let body = try buildMultipartBody(request, boundary: boundary)
        httpRequest.httpBody = body
        
        logger.info("Request body size: \(body.count) bytes")
        
        return httpRequest
    }
}
```

#### 3.2.4 Storage模块日志规范
```swift
// Storage模块日志示例
class KeychainService {
    
    private let logger = Logger.security
    
    func store(apiKey: String, for account: String = "default") throws {
        logger.entering()
        logger.security("Attempting to store API key", severity: .info)
        
        // 验证输入
        guard !apiKey.isEmpty else {
            logger.security("Attempted to store empty API key", severity: .warning)
            throw KeychainError.invalidInput
        }
        
        guard apiKey.hasPrefix("sk-") else {
            logger.security("API key format validation failed", severity: .warning)
            throw KeychainError.invalidFormat
        }
        
        logger.info("Preparing keychain query for account: \(account)")
        
        let data = apiKey.data(using: .utf8)!
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // 删除现有项
        let deleteStatus = SecItemDelete(query as CFDictionary)
        if deleteStatus == errSecSuccess {
            logger.info("Removed existing keychain item")
        } else if deleteStatus != errSecItemNotFound {
            logger.warning("Failed to delete existing keychain item: \(deleteStatus)")
        }
        
        // 添加新项
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            logger.security("Failed to store API key in keychain: \(status)", severity: .critical)
            throw KeychainError.storageError(status: status)
        }
        
        logger.security("API key stored successfully", severity: .info)
        logger.exiting()
    }
    
    func retrieve(for account: String = "default") throws -> String? {
        logger.entering()
        logger.security("Attempting to retrieve API key", severity: .info)
        
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let apiKey = String(data: data, encoding: .utf8) else {
                logger.security("Retrieved keychain data is corrupted", severity: .critical)
                throw KeychainError.dataCorrupted
            }
            
            logger.security("API key retrieved successfully", severity: .info)
            logger.exiting()
            return apiKey
            
        case errSecItemNotFound:
            logger.info("No API key found in keychain for account: \(account)")
            logger.exiting()
            return nil
            
        default:
            logger.security("Failed to retrieve API key from keychain: \(status)", severity: .critical)
            throw KeychainError.retrievalError(status: status)
        }
    }
}
```

### 3.3 性能监控与分析

#### 3.3.1 性能日志记录
```swift
// 性能监控工具
class PerformanceMonitor: ObservableObject {
    
    private let logger = Logger.performance
    
    @Published private(set) var metrics: PerformanceMetrics = PerformanceMetrics()
    
    private var startTimes: [String: CFAbsoluteTime] = [:]
    private let metricsQueue = DispatchQueue(label: "performance.metrics", qos: .utility)
    
    // MARK: - Time Measurement
    
    func startMeasurement(_ operation: String) {
        metricsQueue.async {
            self.startTimes[operation] = CFAbsoluteTimeGetCurrent()
            self.logger.debug("Started measuring: \(operation)")
        }
    }
    
    func endMeasurement(_ operation: String) {
        metricsQueue.async {
            guard let startTime = self.startTimes.removeValue(forKey: operation) else {
                self.logger.warning("No start time found for operation: \(operation)")
                return
            }
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            self.logger.performance(metric: operation, value: duration, unit: "seconds")
            
            DispatchQueue.main.async {
                self.metrics.recordDuration(operation, duration: duration)
            }
        }
    }
    
    // MARK: - Memory Monitoring
    
    func recordMemoryUsage() {
        metricsQueue.async {
            let memoryUsage = self.getCurrentMemoryUsage()
            self.logger.performance(metric: "MemoryUsage", value: Double(memoryUsage), unit: "bytes")
            
            DispatchQueue.main.async {
                self.metrics.currentMemoryUsage = memoryUsage
                
                if memoryUsage > self.metrics.peakMemoryUsage {
                    self.metrics.peakMemoryUsage = memoryUsage
                    self.logger.info("New peak memory usage: \(memoryUsage) bytes")
                }
            }
        }
    }
    
    // MARK: - CPU Monitoring
    
    func recordCPUUsage() {
        metricsQueue.async {
            let cpuUsage = self.getCurrentCPUUsage()
            self.logger.performance(metric: "CPUUsage", value: cpuUsage, unit: "percent")
            
            DispatchQueue.main.async {
                self.metrics.currentCPUUsage = cpuUsage
            }
        }
    }
    
    // MARK: - Audio Performance
    
    func recordAudioMetrics(_ audioBuffer: AudioBuffer, processingTime: TimeInterval) {
        logger.performance(metric: "AudioProcessingTime", value: processingTime, unit: "seconds")
        logger.performance(metric: "AudioDuration", value: audioBuffer.duration, unit: "seconds")
        logger.performance(metric: "AudioSampleRate", value: audioBuffer.sampleRate, unit: "Hz")
        logger.performance(metric: "AudioChannels", value: Double(audioBuffer.channelCount), unit: "channels")
        
        let realTimeRatio = audioBuffer.duration / processingTime
        logger.performance(metric: "AudioRealtimeRatio", value: realTimeRatio, unit: "x")
        
        if realTimeRatio < 1.0 {
            logger.warning("Audio processing slower than realtime: \(realTimeRatio)x")
        }
        
        DispatchQueue.main.async {
            self.metrics.recordAudioProcessing(audioBuffer.duration, processingTime: processingTime)
        }
    }
    
    // MARK: - Network Performance
    
    func recordNetworkMetrics(requestSize: Int, responseSize: Int, latency: TimeInterval) {
        logger.performance(metric: "NetworkRequestSize", value: Double(requestSize), unit: "bytes")
        logger.performance(metric: "NetworkResponseSize", value: Double(responseSize), unit: "bytes")
        logger.performance(metric: "NetworkLatency", value: latency, unit: "seconds")
        
        let throughput = Double(responseSize) / latency
        logger.performance(metric: "NetworkThroughput", value: throughput, unit: "bytes/second")
        
        DispatchQueue.main.async {
            self.metrics.recordNetworkRequest(requestSize: requestSize, responseSize: responseSize, latency: latency)
        }
    }
    
    // MARK: - System Information
    
    private func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    private func getCurrentCPUUsage() -> Double {
        var info = task_thread_times_info()
        var count = mach_msg_type_number_t(MemoryLayout<task_thread_times_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_THREAD_TIMES_INFO), $0, &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else { return 0.0 }
        
        let totalTime = info.user_time.seconds + info.user_time.microseconds / 1_000_000 +
                       info.system_time.seconds + info.system_time.microseconds / 1_000_000
        
        // 这里需要与之前的测量值比较来计算CPU使用率
        // 简化实现，实际应用中需要更复杂的计算
        return Double(totalTime) * 100.0
    }
}

struct PerformanceMetrics {
    var currentMemoryUsage: Int64 = 0
    var peakMemoryUsage: Int64 = 0
    var currentCPUUsage: Double = 0.0
    
    var operationDurations: [String: [TimeInterval]] = [:]
    var audioProcessingStats = AudioProcessingStats()
    var networkStats = NetworkStats()
    
    mutating func recordDuration(_ operation: String, duration: TimeInterval) {
        if operationDurations[operation] == nil {
            operationDurations[operation] = []
        }
        operationDurations[operation]?.append(duration)
        
        // 保持最近100次记录
        if operationDurations[operation]!.count > 100 {
            operationDurations[operation]?.removeFirst()
        }
    }
    
    mutating func recordAudioProcessing(_ audioDuration: TimeInterval, processingTime: TimeInterval) {
        audioProcessingStats.totalAudioProcessed += audioDuration
        audioProcessingStats.totalProcessingTime += processingTime
        audioProcessingStats.processedCount += 1
    }
    
    mutating func recordNetworkRequest(requestSize: Int, responseSize: Int, latency: TimeInterval) {
        networkStats.totalRequests += 1
        networkStats.totalRequestSize += requestSize
        networkStats.totalResponseSize += responseSize
        networkStats.totalLatency += latency
    }
}

struct AudioProcessingStats {
    var totalAudioProcessed: TimeInterval = 0
    var totalProcessingTime: TimeInterval = 0
    var processedCount: Int = 0
    
    var averageRealtimeRatio: Double {
        guard totalProcessingTime > 0 else { return 0 }
        return totalAudioProcessed / totalProcessingTime
    }
}

struct NetworkStats {
    var totalRequests: Int = 0
    var totalRequestSize: Int = 0
    var totalResponseSize: Int = 0
    var totalLatency: TimeInterval = 0
    
    var averageLatency: TimeInterval {
        guard totalRequests > 0 else { return 0 }
        return totalLatency / Double(totalRequests)
    }
    
    var averageThroughput: Double {
        guard totalLatency > 0 else { return 0 }
        return Double(totalResponseSize) / totalLatency
    }
}
```

### 3.4 错误追踪与调试

#### 3.4.1 错误日志标准
```swift
// 错误处理和日志记录的最佳实践
enum AppError: LocalizedError {
    case speechRecognitionFailed(underlying: Error)
    case promptGenerationFailed(underlying: Error)
    case networkTimeout(url: String)
    case invalidAPIKey
    case permissionDenied(permission: String)
    case configurationError(message: String)
    
    var errorDescription: String? {
        switch self {
        case .speechRecognitionFailed(let error):
            return "Speech recognition failed: \(error.localizedDescription)"
        case .promptGenerationFailed(let error):
            return "Prompt generation failed: \(error.localizedDescription)"
        case .networkTimeout(let url):
            return "Network request timed out: \(url)"
        case .invalidAPIKey:
            return "Invalid or expired API key"
        case .permissionDenied(let permission):
            return "\(permission) permission is required"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .speechRecognitionFailed:
            return "Please check your microphone settings and try again."
        case .promptGenerationFailed:
            return "Please check your internet connection and API key."
        case .networkTimeout:
            return "Please check your internet connection and try again."
        case .invalidAPIKey:
            return "Please verify your OpenAI API key in settings."
        case .permissionDenied(let permission):
            return "Please grant \(permission) permission in System Preferences."
        case .configurationError:
            return "Please check your configuration settings."
        }
    }
    
    func log(to logger: Logger, context: [String: Any] = [:]) {
        let errorId = UUID().uuidString
        let contextInfo = context.isEmpty ? "" : " | Context: \(context)"
        
        logger.error("❌ Error [\(errorId)]: \(self.localizedDescription)\(contextInfo)")
        
        if let recovery = self.recoverySuggestion {
            logger.info("💡 Recovery suggestion [\(errorId)]: \(recovery)")
        }
        
        // 记录错误堆栈（如果有）
        if case .speechRecognitionFailed(let underlyingError) = self,
           let nsError = underlyingError as NSError? {
            logger.debug("📋 Error details [\(errorId)]: \(nsError.debugDescription)")
        }
    }
}

// 错误处理装饰器
func withErrorLogging<T>(
    _ operation: String,
    logger: Logger,
    context: [String: Any] = [:],
    _ block: () throws -> T
) rethrows -> T {
    do {
        logger.debug("🎬 Starting: \(operation)")
        let result = try block()
        logger.debug("✅ Completed: \(operation)")
        return result
    } catch {
        let appError = error as? AppError ?? AppError.configurationError(message: error.localizedDescription)
        appError.log(to: logger, context: context)
        throw error
    }
}

func withErrorLogging<T>(
    _ operation: String,
    logger: Logger,
    context: [String: Any] = [:],
    _ block: () async throws -> T
) async rethrows -> T {
    do {
        logger.debug("🎬 Starting: \(operation)")
        let result = try await block()
        logger.debug("✅ Completed: \(operation)")
        return result
    } catch {
        let appError = error as? AppError ?? AppError.configurationError(message: error.localizedDescription)
        appError.log(to: logger, context: context)
        throw error
    }
}
```

#### 3.4.2 调试工具与实用函数
```swift
// 调试工具集合
struct DebugUtils {
    
    // MARK: - Memory Debugging
    
    static func logMemorySnapshot(_ label: String, logger: Logger = Logger.performance) {
        let memoryUsage = getCurrentMemoryUsage()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        
        logger.debug("📊 Memory snapshot [\(label)]: \(formatter.string(fromByteCount: memoryUsage))")
    }
    
    static func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    // MARK: - Object Lifecycle Tracking
    
    static func trackObject<T: AnyObject>(_ object: T, name: String, logger: Logger = Logger.ui) {
        let objectId = ObjectIdentifier(object)
        logger.debug("🎯 Object created: \(name) [\(objectId)]")
        
        // 使用deinit跟踪对象销毁需要在对象内部实现
        // 这里提供一个通用的跟踪机制
    }
    
    // MARK: - Thread Safety Debugging
    
    static func assertMainThread(_ function: String = #function, file: String = #file, line: Int = #line) {
        assert(Thread.isMainThread, "❌ \(function) must be called on main thread [\(file):\(line)]")
    }
    
    static func assertBackgroundThread(_ function: String = #function, file: String = #file, line: Int = #line) {
        assert(!Thread.isMainThread, "❌ \(function) must be called on background thread [\(file):\(line)]")
    }
    
    // MARK: - Network Debugging
    
    static func logRequest(_ request: URLRequest, logger: Logger = Logger.network) {
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "Unknown URL"
        
        logger.debug("🌐 Request: \(method) \(url)")
        
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            for (key, value) in headers {
                let displayValue = key.lowercased().contains("authorization") ? "***" : value
                logger.debug("   Header: \(key) = \(displayValue)")
            }
        }
        
        if let body = request.httpBody {
            logger.debug("   Body: \(body.count) bytes")
        }
    }
    
    static func logResponse(_ response: URLResponse?, data: Data?, error: Error?, logger: Logger = Logger.network) {
        if let error = error {
            logger.error("❌ Response error: \(error)")
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.warning("⚠️ Non-HTTP response received")
            return
        }
        
        let statusEmoji = httpResponse.statusCode < 400 ? "✅" : "❌"
        logger.debug("\(statusEmoji) Response: \(httpResponse.statusCode)")
        
        if let data = data {
            logger.debug("   Data: \(data.count) bytes")
            
            // 如果是JSON响应，尝试格式化输出
            if let json = try? JSONSerialization.jsonObject(with: data),
               let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                logger.debug("   JSON:\n\(prettyString)")
            }
        }
    }
    
    // MARK: - State Debugging
    
    static func logState<T>(_ state: T, label: String, logger: Logger = Logger.ui) where T: CustomStringConvertible {
        logger.debug("🔍 State [\(label)]: \(state.description)")
    }
    
    static func logStateChange<T>(from oldState: T, to newState: T, label: String, logger: Logger = Logger.ui) 
    where T: CustomStringConvertible, T: Equatable {
        if oldState != newState {
            logger.debug("🔄 State change [\(label)]: \(oldState.description) → \(newState.description)")
        }
    }
}

// MARK: - Conditional Compilation for Debug

#if DEBUG
extension DebugUtils {
    
    static func debugOnly(_ block: () -> Void) {
        block()
    }
    
    static func simulateSlowOperation(_ delay: TimeInterval = 1.0) async {
        await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }
    
    static func injectError(_ probability: Double = 0.1) -> Bool {
        return Double.random(in: 0...1) < probability
    }
}
#else
extension DebugUtils {
    
    static func debugOnly(_ block: () -> Void) {
        // No-op in release builds
    }
    
    static func simulateSlowOperation(_ delay: TimeInterval = 1.0) async {
        // No-op in release builds
    }
    
    static func injectError(_ probability: Double = 0.1) -> Bool {
        return false
    }
}
#endif
```

---

**文档状态**：正式版本  
**审批**：需技术负责人和团队Lead签字确认  
**更新日志**：
- V1.0 (2025-07-25)：初始版本，包含全局代码风格、组件特定规范、日志配置和调试工具

<function_calls>
<invoke name="TodoWrite">
<parameter name="todos">[{"id": "1", "content": "Read and analyze the complete Research.md document", "status": "completed", "priority": "high"}, {"id": "2", "content": "Create PRD document with product definition and 10 complex user flows", "status": "completed", "priority": "high"}, {"id": "3", "content": "Create technical design document with system architecture and module relationships", "status": "completed", "priority": "high"}, {"id": "4", "content": "Create code style documentation with global standards and logging requirements", "status": "completed", "priority": "high"}]