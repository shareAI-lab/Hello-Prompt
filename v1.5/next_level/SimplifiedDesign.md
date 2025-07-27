# Hello Prompt - 简化设计文档
**版本：V3.0 - 回归本质版**  
**日期：2025-07-25**  
**设计原则：简单、快速、可靠**

## 1. 产品核心定义

### 1.1 产品价值
Hello Prompt是一个极简的语音到提示词转换工具：用户说话，系统生成专业AI提示词。

**核心价值**：3秒内完成"模糊想法 → 精确提示词"的转换

### 1.2 目标用户
- **开发者**：快速生成代码相关提示词
- **设计师**：快速生成图像生成提示词  
- **创作者**：快速生成文本创作提示词

### 1.3 核心使用场景
1. 开发者在IDE中按快捷键说"帮我写个登录组件"
2. 设计师在设计软件中说"未来主义的城市夜景"
3. 写作者说"写一段关于AI伦理的讨论"

## 2. 简化架构设计

### 2.1 系统架构图
```
┌─────────────────────────────────────────────────────┐
│                   UI Layer                          │
│  ┌──────────────┐    ┌─────────────────────────┐    │
│  │ FloatingBall │    │    ResultPreview        │    │
│  │ (录音状态)     │    │    (结果展示)            │    │
│  └──────────────┘    └─────────────────────────┘    │
└─────────────────────────────────────────────────────┘
                         │
                    Combine Events
                         │
┌─────────────────────────────────────────────────────┐
│                Service Layer                        │
│  ┌──────────────┐              ┌─────────────────┐  │
│  │AudioService  │              │  OpenAIService  │  │
│  │(录音+VAD)     │              │  (ASR + LLM)    │  │
│  └──────────────┘              └─────────────────┘  │
└─────────────────────────────────────────────────────┘
                         │
                   System APIs
                         │
┌─────────────────────────────────────────────────────┐
│                 Foundation                          │
│  ┌──────────────┐              ┌─────────────────┐  │
│  │ AVFoundation │              │   Keychain      │  │
│  │ (音频捕获)     │              │  (API密钥)       │  │
│  └──────────────┘              └─────────────────┘  │
└─────────────────────────────────────────────────────┘
```

### 2.2 核心组件

#### 2.2.1 AudioService - 音频录制服务
```swift
class AudioService: ObservableObject {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    
    private let audioEngine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    
    func startRecording() async throws {
        isRecording = true
        // 配置音频录制
        // 实时VAD检测
        // 自动停止录制
    }
    
    func stopRecording() async -> Data? {
        isRecording = false
        // 返回音频数据
        return prepareAudioForAPI()
    }
}
```

#### 2.2.2 OpenAIService - AI服务
```swift
class OpenAIService {
    private let apiKey: String
    
    // ASR: 语音转文本
    func transcribeAudio(_ audioData: Data) async throws -> String {
        // 调用 OpenAI Whisper API
        let request = WhisperRequest(
            file: audioData,
            model: "whisper-1",
            language: "zh"
        )
        return try await openAI.audioTranscriptions(request)
    }
    
    // LLM: 文本优化为提示词
    func optimizePrompt(_ rawText: String, context: PromptContext) async throws -> String {
        let systemPrompt = """
        你是一个AI提示词优化专家。用户会说出他们的想法，你需要将其转换为清晰、专业的AI提示词。
        
        根据上下文类型优化：
        - 代码类：包含技术栈、功能要求、代码规范
        - 设计类：包含风格、颜色、构图、技术参数
        - 写作类：包含内容结构、风格、目标受众
        """
        
        let userPrompt = "原始输入: \(rawText)\n上下文类型: \(context.type)\n请优化为专业提示词："
        
        let request = ChatRequest(
            model: "gpt-4",
            messages: [
                .system(content: systemPrompt),
                .user(content: userPrompt)
            ],
            temperature: 0.3
        )
        
        return try await openAI.chatCompletions(request).choices.first?.message.content ?? ""
    }
}
```

## 3. 用户体验流程

### 3.1 核心使用流程
```
1. 用户按快捷键 (Ctrl+M)
   ↓
2. 悬浮球出现，开始录音
   ↓ 
3. 用户说话 (例：帮我写个登录组件)
   ↓
4. 检测500ms静音，自动停止
   ↓
5. 显示处理动画 (1-3秒)
   ↓
6. 显示结果预览窗口
   ┌─────────────────────────────┐
   │ 优化后的提示词                │
   │                             │
   │ 创建一个React登录组件，包含：    │
   │ 1. 用户名/密码输入框           │
   │ 2. 表单验证功能               │
   │ 3. 响应式设计                │
   │ 4. TypeScript类型定义        │
   │                             │
   │ [确认使用] [重新录制] [取消]    │
   └─────────────────────────────┘
   ↓
7. 用户确认，文本插入当前光标位置
```

### 3.2 错误处理流程
```
网络错误 → 显示"网络连接问题，请重试" → 提供重试按钮
API错误 → 显示"AI服务暂时不可用" → 原始文本作为备选
语音不清晰 → 显示"请重新录制，说话更清晰" → 重录按钮
```

## 4. 技术实现详情

### 4.1 音频处理
```swift
class AudioProcessor {
    // 简单的VAD检测
    func detectVoiceActivity(in buffer: AVAudioPCMBuffer) -> Bool {
        let rms = calculateRMS(buffer)
        return rms > 0.01 // 简单阈值检测
    }
    
    // 音频格式转换
    func convertToAPIFormat(_ buffer: AVAudioPCMBuffer) -> Data {
        // 转换为OpenAI API要求的格式
        // 16kHz, 单声道, WAV格式
    }
}
```

### 4.2 上下文检测（简化版）
```swift
enum PromptContext {
    case code    // 检测到IDE环境
    case design  // 检测到设计软件
    case writing // 检测到文本编辑器
    case general // 默认通用
}

class ContextDetector {
    func detectCurrentContext() -> PromptContext {
        let activeApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        
        switch activeApp {
        case let app where app.contains("xcode"):
            return .code
        case let app where app.contains("figma"), let app where app.contains("sketch"):
            return .design
        case let app where app.contains("typora"), let app where app.contains("notion"):
            return .writing
        default:
            return .general
        }
    }
}
```

### 4.3 配置管理
```swift
struct AppConfig {
    var apiKey: String = ""
    var hotkey: String = "ctrl+m"
    var autoStopDelay: Double = 0.5  // 静音多久后停止录制
    var useEndToEnd: Bool = false    // 是否使用端到端模式（设置选项）
}

class ConfigManager: ObservableObject {
    @Published var config = AppConfig()
    
    func saveToKeychain() {
        // 保存API密钥到Keychain
    }
    
    func loadFromUserDefaults() {
        // 从UserDefaults加载其他配置
    }
}
```

## 5. 界面设计

### 5.1 悬浮球设计
```swift
struct FloatingBall: View {
    @StateObject private var audioService = AudioService()
    @State private var isRecording = false
    @State private var pulseAnimation = false
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: isRecording ? 
                        [.red.opacity(0.8), .red.opacity(0.3)] :
                        [.green.opacity(0.8), .green.opacity(0.3)],
                    center: .center,
                    startRadius: 5,
                    endRadius: pulseAnimation ? 25 : 15
                )
            )
            .frame(width: 50, height: 50)
            .scaleEffect(pulseAnimation ? 1.2 : 1.0)
            .animation(
                .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: pulseAnimation
            )
            .onAppear {
                pulseAnimation = true
            }
    }
}
```

### 5.2 结果预览窗口
```swift
struct ResultPreview: View {
    let promptText: String
    let onConfirm: () -> Void
    let onRetry: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView {
                Text(promptText)
                    .font(.system(.body, design: .rounded))
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .frame(maxHeight: 150)
            
            HStack(spacing: 12) {
                Button("确认使用") { onConfirm() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
                
                Button("重新录制") { onRetry() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("r")
                
                Button("取消") { onCancel() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.escape)
            }
        }
        .frame(width: 400, height: 250)
        .padding()
        .background(Material.ultraThin)
        .cornerRadius(12)
        .shadow(radius: 20)
    }
}
```

## 6. 部署和分发

### 6.1 应用打包
- 使用Xcode构建macOS应用
- 代码签名确保安全性
- 不需要App Store，直接分发DMG

### 6.2 系统要求
- macOS 12.0+
- 麦克风权限
- 网络连接（访问OpenAI API）

### 6.3 配置要求
- 用户提供OpenAI API密钥
- 一次性配置，长期使用

## 7. 设置选项

### 7.1 基础设置
```swift
struct SettingsView: View {
    @StateObject private var config = ConfigManager()
    
    var body: some View {
        Form {
            Section("API配置") {
                SecureField("OpenAI API密钥", text: $config.config.apiKey)
                Button("测试连接") { testConnection() }
            }
            
            Section("快捷键") {
                HotkeyField("录制快捷键", value: $config.config.hotkey)
            }
            
            Section("高级选项") {
                Toggle("使用端到端模式", isOn: $config.config.useEndToEnd)
                    .help("直接使用OpenAI语音模型，可能更快但可控性较低")
                
                Slider(value: $config.config.autoStopDelay, in: 0.3...2.0) {
                    Text("自动停止延迟: \(config.config.autoStopDelay, specifier: "%.1f")秒")
                }
            }
        }
        .frame(width: 500, height: 400)
    }
}
```

## 8. 总结

这个简化版本：

**保留核心价值**：
- 语音快速转换为优质提示词
- 3秒内完成整个流程
- 支持多种使用场景

**移除过度设计**：
- 不需要复杂的情感分析
- 不需要多AI提供商支持
- 不需要过度的个性化学习
- 架构简单清晰

**技术实现务实**：
- 分离ASR和LLM调用
- 端到端作为可选项
- 简单有效的错误处理
- 最小化的状态管理

**用户体验专注**：
- 一个快捷键启动
- 自动检测停止
- 清晰的结果预览
- 快速确认使用

这个版本更贴近实际需求，开发难度适中，用户体验流畅。