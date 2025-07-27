#!/bin/bash

# Hello Prompt Xcode构建脚本

echo "🚀 准备在Xcode中构建 Hello Prompt..."

# 清理之前的构建数据
echo "🧹 清理之前的构建数据..."
rm -rf .build
rm -rf ~/Library/Developer/Xcode/DerivedData/Hello-Prompt-*

# 确保Info.plist存在
if [ ! -f "Sources/Resources/Info.plist" ]; then
    echo "❌ Info.plist文件不存在，请确保已创建"
    exit 1
fi

# 在Xcode中打开项目
echo "📱 在Xcode中打开项目..."
xed .

echo "✅ 项目已在Xcode中打开！"
echo ""
echo "🔧 下一步操作："
echo "1. 在Xcode中，选择 HelloPrompt scheme"
echo "2. 确保目标是 'My Mac'"
echo "3. 按 ⌘+R 构建并运行"
echo ""
echo "📋 如果遇到权限问题："
echo "1. 前往 系统设置 > 隐私与安全性 > 输入监控"
echo "2. 添加构建后的应用程序"
echo "3. 前往 系统设置 > 隐私与安全性 > 辅助功能"
echo "4. 添加构建后的应用程序"
echo ""
echo "🎯 快捷键: Ctrl+U (开始/停止录音)"