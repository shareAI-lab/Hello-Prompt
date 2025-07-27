#!/bin/bash

# Hello Prompt v2 应用构建脚本
# 构建完整的 macOS .app 包

set -e  # 遇到错误立即退出

echo "🚀 开始构建 Hello Prompt v2.app..."
echo ""

# 配置变量
APP_NAME="Hello Prompt v2"
APP_DIR="$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
BUNDLE_ID="com.helloprompt.v2.app"
EXECUTABLE_NAME="Hello Prompt v2"

# 清理旧构建
if [ -d "$APP_DIR" ]; then
    echo "🗑️  清理旧的应用包..."
    rm -rf "$APP_DIR"
fi

# 创建应用包目录结构
echo "📁 创建应用目录结构..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 构建Swift项目
echo "🔨 构建 Swift 项目..."
echo "   使用 Release 配置以获得最佳性能..."
swift build -c release

if [ ! -f ".build/release/HelloPromptV2" ]; then
    echo "❌ 构建失败：找不到可执行文件"
    exit 1
fi

# 复制可执行文件到应用包
echo "📋 复制可执行文件..."
cp ".build/release/HelloPromptV2" "$MACOS_DIR/$EXECUTABLE_NAME"

# 设置执行权限
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"

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
    <string>$EXECUTABLE_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0.0</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Hello Prompt v2 需要访问麦克风来录制语音，以便进行语音识别和AI提示词优化。</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Hello Prompt v2 需要发送 Apple Events 来与其他应用程序交互，实现文本插入功能。</string>
    <key>NSSystemAdministrationUsageDescription</key>
    <string>Hello Prompt v2 需要系统管理权限来注册全局快捷键和实现跨应用文本插入。</string>
    <key>NSInputMonitoringUsageDescription</key>
    <string>Hello Prompt v2 需要输入监控权限来检测全局快捷键输入。</string>
    <key>NSAccessibilityUsageDescription</key>
    <string>Hello Prompt v2 需要辅助功能权限来实现全局快捷键监听和跨应用文本插入。</string>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <key>com.apple.security.device.microphone</key>
    <true/>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>NSHumanReadableCopyright</key>
    <string>© 2024 Hello Prompt v2. All rights reserved.</string>
</dict>
</plist>
EOF

# 创建 PkgInfo 文件
echo "📦 创建 PkgInfo..."
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

# 创建应用图标（如果存在）
echo "🎨 处理应用资源..."
if [ -f "AppIcon.icns" ]; then
    echo "   复制应用图标..."
    cp "AppIcon.icns" "$RESOURCES_DIR/"
else
    echo "   ⚠️  未找到 AppIcon.icns，跳过图标设置"
fi

# 验证构建结果
echo ""
echo "🔍 验证构建结果..."
if [ -f "$MACOS_DIR/$EXECUTABLE_NAME" ]; then
    echo "   ✅ 可执行文件: $MACOS_DIR/$EXECUTABLE_NAME"
else
    echo "   ❌ 可执行文件缺失"
    exit 1
fi

if [ -f "$CONTENTS_DIR/Info.plist" ]; then
    echo "   ✅ Info.plist: $CONTENTS_DIR/Info.plist"
else
    echo "   ❌ Info.plist 缺失"
    exit 1
fi

# 显示应用包信息
echo ""
echo "📊 应用包信息:"
echo "   应用名称: $APP_NAME"
echo "   Bundle ID: $BUNDLE_ID"
echo "   版本: 2.0.0"
echo "   最低系统: macOS 12.0+"
echo "   架构: $(file "$MACOS_DIR/$EXECUTABLE_NAME" | cut -d: -f2)"

echo ""
echo "✅ Hello Prompt v2.app 构建完成！"
echo "📍 应用位置: $(pwd)/$APP_DIR"
echo "📦 应用大小: $(du -sh "$APP_DIR" | cut -f1)"

echo ""
echo "🔧 使用方法："
echo "1. 双击 '$APP_DIR' 启动应用"
echo "2. 首次启动时，系统会提示授权麦克风权限，点击允许"
echo "3. 前往 系统偏好设置 > 安全性与隐私 > 辅助功能"
echo "4. 点击锁定图标解锁，然后添加 'Hello Prompt v2'"
echo "5. 重新启动应用即可正常使用全局快捷键功能"

echo ""
echo "⌨️  默认快捷键："
echo "   • ⌥⌘Space - 开始录音"
echo "   • ⌥Escape - 停止录音"
echo "   • ⌥Return - 插入结果到当前应用"
echo "   • ⌥⌘C - 复制结果到剪贴板"

echo ""
echo "🚀 Hello Prompt v2 已准备就绪，可以与原版本并存使用！"

# 可选：打开应用包所在目录
if command -v open >/dev/null 2>&1; then
    echo ""
    read -p "是否打开应用包所在目录？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open .
    fi
fi