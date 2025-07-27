# Hello Prompt - Xcode构建指南

## 🎯 已修复的问题

✅ **SwiftUI兼容性问题**
- 修复了 `SwiftUI/arm64e-apple-macos.swiftinterface:14730: Fatal error: Unavailable` 错误
- 移除了导致兼容性问题的macOS 14.0版本检查
- 统一使用兼容性更好的代码实现

✅ **快捷键更新**
- 全局快捷键从 Command+U 更改为 **Ctrl+U**
- 更新了ModernGlobalShortcuts.swift配置

✅ **权限描述完善**
- 添加了所有必需的权限描述
- 包含输入监控、辅助功能、麦克风权限

✅ **初始化流程优化**
- 修复了应用初始化阻塞问题
- 改进了异步启动流程

## 🚀 Xcode构建步骤

### 1. 准备环境
```bash
cd /Users/baicai/Desktop/Hello-Prompt
./build_xcode.sh
```

### 2. 在Xcode中构建
1. 项目应该已经在Xcode中打开
2. 选择 **HelloPrompt** scheme
3. 确保目标是 **"My Mac"**
4. 按 `⌘+R` 构建并运行

### 3. 权限设置
构建成功后，需要授予以下权限：

#### 输入监控权限
- 打开 **系统设置** > **隐私与安全性** > **输入监控**
- 点击 **+** 添加Hello Prompt应用
- 勾选启用

#### 辅助功能权限
- 打开 **系统设置** > **隐私与安全性** > **辅助功能**
- 点击 **+** 添加Hello Prompt应用
- 勾选启用

#### 麦克风权限
- 首次使用录音功能时会自动弹出授权对话框
- 点击 **允许**

## 🎮 使用方法

### 全局快捷键
- **Ctrl+U**: 开始/停止语音录制

### 功能流程
1. 按 `Ctrl+U` 开始录音
2. 说出要转换的内容
3. 再次按 `Ctrl+U` 停止录音
4. 查看识别结果和AI优化建议
5. 选择插入文本或进行修改

## 📁 项目结构

```
Hello-Prompt/
├── Package.swift           # Swift Package配置
├── Sources/
│   ├── HelloPrompt/        # 主要源代码
│   │   ├── main.swift      # 应用入口
│   │   ├── RealAppManager.swift  # 应用管理器
│   │   ├── ModernGlobalShortcuts.swift  # 全局快捷键
│   │   ├── AudioService.swift  # 音频服务
│   │   ├── OpenAIService.swift # OpenAI服务
│   │   └── ...
│   └── Resources/
│       └── Info.plist      # 应用信息和权限
├── build_xcode.sh          # Xcode构建脚本
└── XCODE_BUILD_GUIDE.md    # 本指南
```

## 🔧 配置文件

### Package.swift 主要配置
- Swift Tools Version: 5.9
- 最低系统版本: macOS 13.0
- 启用严格并发检查

### Info.plist 权限说明
- NSMicrophoneUsageDescription: 麦克风权限
- NSInputMonitoringUsageDescription: 输入监控权限
- NSAppleEventsUsageDescription: Apple Events权限

## 🐛 故障排除

### 如果遇到构建错误
1. 清理构建缓存: `⌘+Shift+K`
2. 删除DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData/Hello-Prompt-*`
3. 重新运行 `./build_xcode.sh`

### 如果快捷键不工作
1. 确保已授予输入监控权限
2. 检查系统设置中应用是否正确添加
3. 重启应用程序

### 如果录音不工作
1. 确保已授予麦克风权限
2. 检查系统音频设置
3. 确认麦克风未被其他应用占用

## 📞 技术支持

如果遇到问题，请检查：
1. macOS版本是否为13.0+
2. Xcode版本是否为最新
3. 所有系统权限是否已正确授予
4. 应用日志: `~/Library/Application Support/HelloPrompt/Logs/`

## 🎉 修复成功验证

应用正常工作的标志：
- ✅ 应用启动无错误
- ✅ 能看到悬浮球界面
- ✅ Ctrl+U触发录音界面
- ✅ 能正常录制和识别语音
- ✅ 能将结果插入到其他应用

Happy Coding! 🚀