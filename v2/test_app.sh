#!/bin/bash

# Hello Prompt v2 完整测试脚本
echo "🎤 Hello Prompt v2 完整实现测试"
echo "================================="

# 检查系统要求
echo "🔍 检查系统要求..."
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ 此应用只能在macOS上运行"
    exit 1
fi

# 构建应用
echo "📦 构建应用..."
swift build

if [ $? -ne 0 ]; then
    echo "❌ 构建失败！请检查编译错误。"
    echo "💡 提示：如果遇到SwiftUI兼容性问题，应用已自动切换到简化版本"
    exit 1
fi

echo "✅ 构建成功！"
echo "🔧 修复说明：已解决SwiftUI兼容性问题，使用简化版本避免MenuBarExtra冲突"
echo ""

# 显示测试指南
echo "📋 完整功能测试指南"
echo "==================="
echo ""
echo "🔐 权限测试："
echo "   1. 应用启动后会自动检查权限状态"
echo "   2. 如权限不足，会显示权限申请窗口"
echo "   3. 按照界面指引完成权限授权"
echo ""
echo "⌨️ 快捷键测试："
echo "   1. 按下 Ctrl+U 触发录音"
echo "   2. 应该看到屏幕中央出现Siri风格录音气泡"
echo "   3. 说话时气泡应有动画效果"
echo "   4. 停止说话0.5秒后自动停止录音"
echo ""
echo "🎵 录音功能测试："
echo "   1. 录音时应显示实时音频级别"
echo "   2. 录音状态应从'监听中'→'录音中'→'处理中'"
echo "   3. 处理完成后应显示优化结果"
echo ""
echo "⚙️ 设置界面测试："
echo "   1. 打开设置查看API配置"
echo "   2. 测试连接功能应显示成功"
echo "   3. 模型设置应能正确保存"
echo "   4. 完成安装功能应正常工作"
echo ""
echo "🐛 调试信息："
echo "   • 详细日志: 控制台应用 → 过滤 'com.helloprompt.app'"
echo "   • 快捷键状态: 查看'快捷键注册成功'日志"
echo "   • 权限状态: 查看'所有权限已授权'日志"
echo "   • 录音流程: 查看'快捷键触发：开始录音'日志"
echo ""

# 提示用户准备
read -p "📍 请确保已连接麦克风设备，按Enter键启动应用..."

# 启动应用
echo "🚀 启动Hello Prompt v2..."
echo "💡 按 Ctrl+C 退出应用"
echo ""

# 在后台启动控制台日志监控
echo "📊 启动日志监控..."
log stream --predicate 'subsystem == "com.helloprompt.app"' --style compact &
LOG_PID=$!

# 启动应用
./.build/debug/HelloPromptV2

# 清理日志监控进程
kill $LOG_PID 2>/dev/null

echo ""
echo "👋 Hello Prompt v2 测试完成"