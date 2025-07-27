#!/bin/bash

echo "🚀 启动 Hello Prompt 应用..."

# 检查是否在正确的目录
if [ ! -f "Package.swift" ]; then
    echo "❌ 错误：请在项目根目录运行此脚本"
    exit 1
fi

# 构建项目
echo "📦 正在构建项目..."
swift build

if [ $? -eq 0 ]; then
    echo "✅ 构建成功！"
    echo ""
    echo "📋 使用说明："
    echo "由于这是一个 macOS GUI 应用，需要在 Xcode 中运行才能看到界面。"
    echo ""
    echo "请按照以下步骤操作："
    echo "1. 打开 Terminal，执行：open Hello-Prompt.xcodeproj"
    echo "2. 在 Xcode 中按 ⌘+R 运行应用"
    echo "3. 查看 '使用指南.md' 了解详细使用方法"
    echo ""
    echo "🔑 首次使用请确保："
    echo "- 配置 OpenAI API 密钥"
    echo "- 授权麦克风和辅助功能权限"
    echo ""
    echo "📚 详细说明请查看：使用指南.md"
else
    echo "❌ 构建失败，请检查错误信息"
    exit 1
fi