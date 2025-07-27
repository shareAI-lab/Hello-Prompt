#!/bin/bash

echo "🚀 Hello Prompt v2 - GUI修复测试"
echo "============================"
echo ""
echo "🔧 主要修复："
echo "   ✅ 应用激活策略设置为.regular"
echo "   ✅ 强制显示设置窗口"
echo "   ✅ 应用启动后自动激活"
echo "   ✅ 权限申请窗口显示逻辑修复"
echo ""
echo "🎯 期待结果："
echo "   📱 应用启动后自动显示设置窗口"
echo "   🔑 权限不足时显示权限申请界面" 
echo "   ⌨️  按Ctrl+U显示快捷键测试对话框"
echo "   🎤 录音界面在屏幕中央正确显示"
echo ""

# 检查系统
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ 此应用只能在macOS上运行"
    exit 1
fi

echo "🚀 启动修复后的应用..."
echo "========================="
echo ""

# 启动应用
./.build/debug/HelloPromptV2 2>&1 | while IFS= read -r line; do
    case "$line" in
        *"设置应用激活策略"*)
            echo "🔧 $line" ;;
        *"应用已激活并尝试显示界面"*)
            echo "⚡ $line" ;;
        *"设置窗口已创建并显示"*)
            echo "📱 $line" ;;
        *"权限申请窗口"*)
            echo "🔐 $line" ;;
        *"🎙️ 快捷键触发"*)
            echo "🎯 $line" ;;
        *"录音界面"*)
            echo "🎬 $line" ;;
        *"ERROR"*|*"错误"*)
            echo "❌ $line" ;;
        *"WARNING"*|*"警告"*)
            echo "⚠️  $line" ;;
        *)
            echo "$line" ;;
    esac
done