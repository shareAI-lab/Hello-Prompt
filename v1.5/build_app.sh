#!/bin/bash

# Hello Prompt 应用构建脚本

echo "🚀 开始构建 Hello Prompt.app..."

# 创建应用目录结构
APP_NAME="Hello Prompt"
APP_DIR="$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# 清理旧的应用包
if [ -d "$APP_DIR" ]; then
    echo "🗑️  清理旧的应用包..."
    rm -rf "$APP_DIR"
fi

# 创建目录结构
echo "📁 创建应用目录结构..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 构建可执行文件
echo "🔨 构建可执行文件..."
swift build -c release

# 复制可执行文件
echo "📋 复制可执行文件..."
cp .build/release/HelloPrompt "$MACOS_DIR/Hello Prompt"

# 创建 Info.plist
echo "📝 创建 Info.plist..."
cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>Hello Prompt</string>
    <key>CFBundleIdentifier</key>
    <string>com.helloprompt.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Hello Prompt</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Hello Prompt 需要访问麦克风来录制语音，以便进行语音识别和AI提示词优化。</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Hello Prompt 需要发送 Apple Events 来与其他应用程序交互，实现文本插入功能。</string>
    <key>NSSystemAdministrationUsageDescription</key>
    <string>Hello Prompt 需要系统管理权限来注册全局快捷键和实现跨应用文本插入。</string>
    <key>NSInputMonitoringUsageDescription</key>
    <string>Hello Prompt 需要输入监控权限来注册全局快捷键 Ctrl+U，以便您可以在任何应用中快速启动语音录制功能。</string>
</dict>
</plist>
EOF

# 创建应用图标（可选）
echo "🎨 创建应用资源..."
# 这里可以添加图标文件，现在先跳过

# 设置执行权限
chmod +x "$MACOS_DIR/Hello Prompt"

echo "✅ Hello Prompt.app 构建完成！"
echo "📍 应用位置: $(pwd)/$APP_DIR"
echo ""
echo "🔧 使用方法："
echo "1. 双击 '$APP_DIR' 启动应用"
echo "2. 系统会提示授权麦克风权限，点击允许"
echo "3. 前往 系统偏好设置 > 安全性与隐私 > 辅助功能"
echo "4. 点击锁定图标解锁，然后添加 'Hello Prompt'"
echo "5. 重新启动应用即可正常使用"
echo ""
echo "🚀 现在可以正常在系统设置中找到并授权 Hello Prompt 了！"