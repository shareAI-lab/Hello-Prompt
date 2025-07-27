#!/bin/bash

echo "🎯 Hello Prompt - AI 语音转提示词工具"
echo "================================"

# 检查构建状态
if [ ! -f ".build/arm64-apple-macosx/debug/HelloPrompt" ]; then
    echo "📦 正在构建应用..."
    swift build
    
    if [ $? -ne 0 ]; then
        echo "❌ 构建失败"
        exit 1
    fi
fi

echo "✅ 构建成功！"
echo ""
echo "🚀 正在启动 Hello Prompt..."
echo ""

# 启动GUI应用
./.build/arm64-apple-macosx/debug/HelloPrompt &

# 等待应用启动
sleep 2

echo "📱 应用已启动！"
echo ""
echo "🎤 使用说明："
echo "• ⌥⌘Space - 开始录音"
echo "• ⌥Escape - 停止录音"
echo "• ⌥Return - 插入结果"
echo "• ⌥⌘C - 复制结果"
echo "• 点击菜单栏图标查看更多功能"
echo ""
echo "⚙️ 首次使用请："
echo "1. 配置 OpenAI API 密钥"
echo "2. 授权麦克风和辅助功能权限"
echo ""
echo "📚 详细说明请查看：使用指南.md"