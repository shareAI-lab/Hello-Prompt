# Hello Prompt v2 - AI语音转提示词工具

## 🎯 项目概述

Hello Prompt v2 是一款基于AI的语音转提示词工具，专为macOS设计。它能够将您的语音输入转换为优化的文字提示词，并支持多种AI模型进行处理。该应用具备Siri风格的用户界面，提供流畅的语音交互体验。

## ✨ 核心功能

### 🎤 智能语音识别
- **高质量录音**: 16kHz采样率，专为AI语音识别优化
- **实时VAD检测**: 自动检测语音活动，智能停止录音
- **音频增强**: 内置降噪、自动增益控制和动态压缩
- **Siri风格界面**: 系统级录音气泡，提供直观的视觉反馈

### 🤖 AI驱动的提示词优化
- **OpenAI集成**: 支持Whisper语音识别和GPT文本优化
- **上下文感知**: 根据当前应用环境优化提示词
- **多模型支持**: 灵活配置不同的AI模型和参数
- **实时处理**: 快速转换和优化，提供即时结果

### ⌨️ 全局快捷键
- **Ctrl+U**: 开始/停止录音（全局可用）
- **Esc+Option**: 取消录音
- **系统级**: 在任何应用中都可使用快捷键

### 🔒 完整权限管理
- **麦克风权限**: 录音功能必需
- **辅助功能权限**: 全局快捷键和文本插入功能
- **引导式设置**: 自动检测权限状态并提供设置指导

## 🚀 快速开始

### 构建和运行

1. **使用测试脚本（推荐）**：
   ```bash
   chmod +x test_app.sh
   ./test_app.sh
   ```

2. **手动构建**：
   ```bash
   swift build
   ./.build/debug/HelloPromptV2
   ```

3. **在Xcode中运行**：
   ```bash
   open Package.swift
   # 在Xcode中按 ⌘+R 运行
   ```

## ⚙️ 首次配置

### 1. 系统权限设置

启动应用后，会自动检查权限并引导设置：

**麦克风权限**：
- 系统会自动弹出权限申请
- 点击"允许"授权麦克风权限

**辅助功能权限**：
1. 点击应用中的"申请系统权限"
2. 系统将打开"隐私与安全性" → "辅助功能"
3. 添加Hello Prompt v2到列表并启用
4. 返回应用点击"检查权限状态"

### 2. OpenAI API配置

1. **获取API密钥**: 访问 https://platform.openai.com/api-keys
2. **打开设置**: 在应用主窗口配置API参数
3. **输入配置**:
   - API Key: 粘贴您的OpenAI API密钥
   - Base URL: 保持默认 `https://api.openai.com/v1`
   - 选择合适的模型
4. **测试连接**: 点击"测试连接"确保配置正确

## 🎯 使用指南

### 基本工作流程

1. **启动录音**: 按下 `Ctrl+U` 快捷键
2. **语音输入**: 看到Siri风格录音气泡后开始清晰说话
3. **自动停止**: 停止说话0.5秒后自动结束录音
4. **处理过程**: 应用自动进行语音识别和文本优化
5. **查看结果**: 在结果界面查看优化的提示词
6. **使用结果**: 复制或插入到目标应用

### 完整功能测试

使用测试脚本进行完整功能验证：

```bash
./test_app.sh
```

测试内容包括：
- ✅ 权限状态检查
- ✅ 快捷键响应测试
- ✅ 录音功能测试
- ✅ 设置界面功能
- ✅ 系统集成测试

## ⌨️ 快捷键参考

| 功能 | 快捷键 | 说明 |
|------|--------|------|
| 开始录音 | `Ctrl+U` | 全局快捷键，任何应用中可用 |
| 停止录音 | `Esc+Option` | 强制停止当前录音 |
| 偏好设置 | `Cmd+,` | 打开设置窗口 |
| 关于应用 | `Cmd+A` | 显示应用信息 |

## 📁 项目架构

### 核心组件结构
```
Sources/HelloPrompt/
├── HelloPromptApp.swift          # 应用主入口
├── Core/
│   ├── AppManager.swift          # 应用状态管理和工作流协调
│   ├── ErrorHandler.swift       # 统一错误处理
│   └── LogManager.swift          # 日志管理系统
├── Services/
│   ├── AudioService.swift        # 高质量音频录制和处理
│   ├── OpenAIService.swift       # OpenAI API集成
│   ├── HotkeyService.swift       # 全局快捷键服务
│   └── ConfigManager.swift       # 配置管理
├── UI/Views/
│   ├── SettingsView.swift        # 设置界面
│   ├── RecordingOverlayView.swift # Siri风格录音覆盖层
│   ├── PermissionRequestView.swift # 权限申请界面
│   └── Components/               # UI组件
└── Models/
    ├── AudioSystemError.swift    # 音频系统错误定义
    └── AppConfig.swift          # 配置数据模型
```

### 技术架构特点
- **Swift 6.0**: 现代Swift并发和类型安全
- **SwiftUI + AppKit**: 混合UI架构，原生macOS体验
- **AVFoundation**: 专业音频处理和VAD算法
- **Combine**: 响应式状态管理
- **OpenAI API**: Whisper语音识别 + GPT文本优化
- **Carbon API**: 系统级全局快捷键
- **macOS 15.5+**: 支持最新macOS系统特性

## ✅ 开发状态

**🎉 v1.0.0 已完成功能**：
- ✅ 完整的语音录制和VAD检测系统
- ✅ OpenAI Whisper + GPT集成
- ✅ Siri风格系统级录音界面
- ✅ Ctrl+U全局快捷键支持
- ✅ 完整权限管理流程
- ✅ 音频质量优化和增强
- ✅ 状态机式应用流程管理
- ✅ 错误处理和日志系统
- ✅ 完整测试套件

**🔄 计划功能**：
- 本地语音识别支持
- 多语言界面支持
- 历史记录管理
- 批量处理功能
- 自定义快捷键配置

## 📋 系统要求

- **操作系统**: macOS 15.5+
- **架构**: Apple Silicon (M1/M2/M3) 或 Intel
- **开发工具**: Xcode 16.4+ (如需编译)
- **网络**: 互联网连接 (调用OpenAI API)
- **权限**: 麦克风访问权限、辅助功能权限

## 🛠️ 故障排除

### 常见问题解决

#### 🔴 快捷键无响应
**症状**: 按下Ctrl+U没有任何反应
**解决方案**:
1. 检查辅助功能权限是否已授权
2. 在控制台应用中查看错误日志（过滤"com.helloprompt.app"）
3. 重新启动应用或重新授权权限

#### 🔴 SwiftUI兼容性问题
**症状**: 应用启动时显示"SwiftUI/arm64e-apple-macos.swiftinterface: Fatal error: Unavailable"
**解决方案**:
- 应用已自动切换到简化版本，移除了有问题的MenuBarExtra组件
- 核心功能完全保留：录音、快捷键、设置界面等
- 如果仍有问题，请重新构建：`swift build`

#### 🔴 录音质量差
**症状**: 语音识别准确率低
**解决方案**:
1. 确保在安静环境中录音
2. 检查麦克风设备工作状态
3. 查看设置中的音频质量指标
4. 调整麦克风输入音量

#### 🔴 API连接失败
**症状**: "连接测试失败"或处理错误
**解决方案**:
1. 验证OpenAI API密钥正确性
2. 检查网络连接状态
3. 确认OpenAI账户余额充足
4. 尝试更换Base URL设置

#### 🔴 权限申请失败
**症状**: 权限检查显示未授权
**解决方案**:
1. 手动打开"系统设置" → "隐私与安全性"
2. 分别检查"麦克风"和"辅助功能"权限
3. 手动添加应用到权限列表
4. 重启应用验证权限状态

### 调试信息获取

**查看应用日志**:
```bash
# 实时监控应用日志
log stream --predicate 'subsystem == "com.helloprompt.app"' --style compact

# 查看特定时间段日志
log show --predicate 'subsystem == "com.helloprompt.app"' --last 1h
```

**状态指示器**:
- 🟢 绿色: 空闲状态，准备就绪
- 🔵 蓝色: 录音中
- 🟠 橙色: 处理中
- 🟣 紫色: 展示结果
- 🔴 红色: 错误状态

## 📚 相关资源

- **OpenAI API文档**: https://platform.openai.com/docs
- **Swift并发编程**: https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html
- **macOS开发指南**: https://developer.apple.com/macos/
- **AVFoundation框架**: https://developer.apple.com/av-foundation/

## 🤝 支持和贡献

### 获取帮助
1. 查看本README的故障排除部分
2. 检查应用日志获取详细错误信息
3. 确保系统满足最低要求

### 开发贡献
1. Fork项目仓库
2. 创建功能分支
3. 提交更改并添加测试
4. 创建Pull Request

欢迎提交Issue和功能建议！

## 📄 许可证

本项目采用 MIT 许可证。详见 LICENSE 文件。

---

**Hello Prompt v2** - 让语音交互更智能，让AI协作更高效。

© 2024 Hello Prompt Team