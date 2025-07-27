#!/bin/bash

echo "🔧 Hello Prompt v2 - 快捷键修复测试"
echo "================================="
echo ""

# 检查系统
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ 此应用只能在macOS上运行"
    exit 1
fi

echo "📦 启动修复后的应用..."
echo "⚠️  如果快捷键正常工作，您应该看到："
echo "   1. 应用正常启动并显示初始化日志"
echo "   2. 按下 Ctrl+U 后立即弹出'快捷键测试'对话框"
echo "   3. 在日志中看到🎙️开始录音的信息"
echo "   4. 屏幕中央出现Siri风格的录音界面"
echo ""
echo "🎯 测试步骤："
echo "   1. 等待应用完全启动"
echo "   2. 按下 Ctrl+U 测试快捷键"
echo "   3. 观察是否有弹窗和录音界面"
echo "   4. 按 Cmd+Q 退出应用"
echo ""
echo "🚀 启动应用..."

# 启动应用并显示实时日志
./.build/debug/HelloPromptV2 2>&1 | while IFS= read -r line; do
    # 高亮重要的日志信息
    if [[ "$line" == *"🎙️ 快捷键触发"* ]]; then
        echo "✅ $line"
    elif [[ "$line" == *"快捷键注册成功"* ]]; then
        echo "🎹 $line"
    elif [[ "$line" == *"录音界面"* ]]; then
        echo "🎬 $line"
    elif [[ "$line" == *"ERROR"* ]] || [[ "$line" == *"错误"* ]]; then
        echo "❌ $line"
    elif [[ "$line" == *"WARNING"* ]] || [[ "$line" == *"警告"* ]]; then
        echo "⚠️  $line"
    else
        echo "$line"
    fi
done