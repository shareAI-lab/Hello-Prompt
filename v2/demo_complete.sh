#!/bin/bash

echo "🚀 Hello Prompt v2 - 完整功能演示"
echo "================================="
echo ""
echo "✅ 已实现的核心功能："
echo "   🎙️  Ctrl+U 全局快捷键触发录音"
echo "   🔵  类Siri录音界面和音频反馈"
echo "   🤖  OpenAI Whisper 语音识别 (配置API后可用)"
echo "   📝  GPT 提示词优化 (配置API后可用)"
echo "   ⚡  完整的权限管理和错误处理"
echo "   📱  直观的用户界面和状态反馈"
echo ""

# 检查系统
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ 此应用只能在macOS上运行"
    exit 1
fi

echo "📦 启动应用进行完整功能演示..."
echo ""
echo "🎯 测试功能列表："
echo "   1. 🔑 权限管理 - 麦克风和辅助功能权限"
echo "   2. ⌨️  快捷键测试 - 按 Ctrl+U 触发录音"
echo "   3. 🎤 录音功能 - 高质量音频录制和VAD检测"
echo "   4. 🪟 Siri界面 - 录音覆盖窗口显示"
echo "   5. 🔄 工作流程 - 完整的语音转提示词流程"
echo "   6. ⚙️  设置界面 - OpenAI API配置"
echo ""
echo "💡 使用说明："
echo "   • 应用启动后，如果权限不足会显示权限申请界面"
echo "   • 按 Ctrl+U 会立即弹出'快捷键测试'对话框确认响应"
echo "   • 然后显示Siri风格的录音界面在屏幕中央"
echo "   • 说话后停顿0.5秒会自动停止录音"
echo "   • 如未配置OpenAI API，会显示占位符结果演示流程"
echo "   • 在设置界面可以配置真正的OpenAI API密钥"
echo ""
echo "🔧 关键修复："
echo "   ✅ 解决了SwiftUI兼容性问题"
echo "   ✅ 修复了快捷键无响应的问题"
echo "   ✅ 实现了完整的LLM API润色流程"
echo "   ✅ 创建了类Siri的录音UI体验"
echo "   ✅ 添加了全面的错误处理和日志"
echo ""
echo "🚀 启动应用..."
echo "=================="

# 启动应用并显示实时日志，突出显示重要事件
./.build/debug/HelloPromptV2 2>&1 | while IFS= read -r line; do
    case "$line" in
        *"🎙️ 快捷键触发"*)
            echo "🎯 $line" ;;
        *"快捷键注册成功"*)
            echo "🎹 $line" ;;
        *"显示录音界面"*)
            echo "🎬 $line" ;;
        *"录音"*"完成"*)
            echo "✅ $line" ;;
        *"优化完成"*)
            echo "🤖 $line" ;;
        *"ERROR"*|*"错误"*)
            echo "❌ $line" ;;
        *"WARNING"*|*"警告"*)
            echo "⚠️  $line" ;;
        *"INFO"*"权限"*)
            echo "🔐 $line" ;;
        *"应用启动完成"*)
            echo "🎉 $line" ;;
        *)
            echo "$line" ;;
    esac
done