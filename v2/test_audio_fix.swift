#!/usr/bin/env swift

import Foundation
import AVFoundation

print("🔧 测试音频格式修复...")

let audioEngine = AVAudioEngine()
let inputNode = audioEngine.inputNode

// 获取硬件格式
let hardwareFormat = inputNode.inputFormat(forBus: 0)
print("硬件格式: \(hardwareFormat.channelCount)声道, \(hardwareFormat.sampleRate)Hz")

// 创建目标格式
guard let targetFormat = AVAudioFormat(
    commonFormat: .pcmFormatFloat32,
    sampleRate: 16000,
    channels: 1,
    interleaved: false
) else {
    print("❌ 无法创建目标格式")
    exit(1)
}

print("目标格式: \(targetFormat.channelCount)声道, \(targetFormat.sampleRate)Hz")

do {
    // 使用混音器进行格式转换
    let converter = audioEngine.mainMixerNode
    
    // 连接输入到混音器
    audioEngine.connect(inputNode, to: converter, format: hardwareFormat)
    
    // 在混音器上安装tap
    converter.installTap(onBus: 0, bufferSize: 1024, format: targetFormat) { buffer, time in
        print("📊 收到音频缓冲区: \(buffer.frameLength) frames")
    }
    
    // 启动音频引擎
    try audioEngine.start()
    print("✅ 音频引擎启动成功！")
    
    // 运行3秒测试
    Thread.sleep(forTimeInterval: 3.0)
    
    // 清理
    audioEngine.stop()
    converter.removeTap(onBus: 0)
    print("✅ 音频格式修复测试完成")
    
} catch {
    print("❌ 音频引擎启动失败: \(error)")
    exit(1)
}