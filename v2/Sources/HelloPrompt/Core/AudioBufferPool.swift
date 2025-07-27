//
//  AudioBufferPool.swift
//  HelloPrompt
//
//  音频缓冲区对象池 - 优化内存分配和减少GC压力
//  提供高效的音频缓冲区复用机制
//

import Foundation
import AVFoundation

// MARK: - 音频缓冲区池
public final class AudioBufferPool: @unchecked Sendable {
    
    // MARK: - 单例
    public static let shared = AudioBufferPool()
    
    // MARK: - 私有属性
    private let queue = DispatchQueue(label: "com.helloprompt.audiobufferpool", qos: .userInitiated)
    private var bufferPool: [String: [AVAudioPCMBuffer]] = [:]
    private let maxPoolSize = 10
    private let maxFrameCapacity: AVAudioFrameCount = 4096
    
    // MARK: - 初始化
    private init() {
        LogManager.shared.info("AudioBufferPool", "音频缓冲区池初始化完成")
    }
    
    // MARK: - 公共方法
    
    /// 获取音频缓冲区
    public func getBuffer(format: AVAudioFormat, frameCapacity: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        let key = bufferKey(format: format, frameCapacity: frameCapacity)
        
        return queue.sync {
            // 检查池中是否有可用的缓冲区
            if var buffers = bufferPool[key], !buffers.isEmpty {
                let buffer = buffers.removeLast()
                bufferPool[key] = buffers
                
                // 重置缓冲区状态
                buffer.frameLength = 0
                return buffer
            }
            
            // 创建新的缓冲区
            guard let newBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
                LogManager.shared.error("AudioBufferPool", "创建音频缓冲区失败")
                return nil
            }
            
            LogManager.shared.debug("AudioBufferPool", "创建新的音频缓冲区: \(key)")
            return newBuffer
        }
    }
    
    /// 归还音频缓冲区到池中
    public func returnBuffer(_ buffer: AVAudioPCMBuffer) {
        let key = bufferKey(format: buffer.format, frameCapacity: buffer.frameCapacity)
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // 检查池的大小限制
            var buffers = self.bufferPool[key] ?? []
            guard buffers.count < self.maxPoolSize else {
                // 池已满，丢弃缓冲区
                return
            }
            
            // 清理缓冲区数据
            buffer.frameLength = 0
            if let channelData = buffer.floatChannelData {
                for channel in 0..<Int(buffer.format.channelCount) {
                    memset(channelData[channel], 0, Int(buffer.frameCapacity) * MemoryLayout<Float>.size)
                }
            }
            
            // 添加到池中
            buffers.append(buffer)
            self.bufferPool[key] = buffers
        }
    }
    
    // MARK: - 内存管理优化
    
    /// 清理未使用的缓冲区
    public func cleanupUnusedBuffers() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let beforeCount = self.bufferPool.values.reduce(0) { $0 + $1.count }
            
            // 保留最近使用的缓冲区，清理过多的缓冲区
            for (key, buffers) in self.bufferPool {
                if buffers.count > self.maxPoolSize / 2 {
                    let keepCount = self.maxPoolSize / 2
                    let trimmedBuffers = Array(buffers.suffix(keepCount))
                    self.bufferPool[key] = trimmedBuffers
                }
            }
            
            let afterCount = self.bufferPool.values.reduce(0) { $0 + $1.count }
            
            if beforeCount != afterCount {
                LogManager.shared.info("AudioBufferPool", "清理完成: 从\(beforeCount)个缓冲区减少到\(afterCount)个")
            }
        }
    }
    
    /// 获取内存使用统计
    public func getMemoryUsage() -> (totalBuffers: Int, estimatedMemoryMB: Double) {
        return queue.sync {
            let totalBuffers = self.bufferPool.values.reduce(0) { $0 + $1.count }
            
            // 估算内存使用（假设每个缓冲区平均使用4096帧，每帧 4 字节）
            let averageBufferSize = 4096 * 4 // 4 bytes per float sample
            let totalMemoryBytes = Double(totalBuffers * averageBufferSize)
            let totalMemoryMB = totalMemoryBytes / (1024 * 1024)
            
            return (totalBuffers, totalMemoryMB)
        }
    }
    
    /// 强制清理所有缓冲区（内存压力情况下使用）
    public func emergencyCleanup() {
        queue.sync {
            let beforeCount = self.bufferPool.values.reduce(0) { $0 + $1.count }
            self.bufferPool.removeAll()
            LogManager.shared.warning("AudioBufferPool", "紧急清理: 释放了\(beforeCount)个缓冲区")
        }
    }
    
    /// 获取池的统计信息
    public func getPoolStats() -> [String: Any] {
        return queue.sync {
            var stats: [String: Any] = [:]
            var totalBuffers = 0
            
            for (key, buffers) in bufferPool {
                stats[key] = buffers.count
                totalBuffers += buffers.count
            }
            
            stats["totalBuffers"] = totalBuffers
            stats["poolTypes"] = bufferPool.keys.count
            
            return stats
        }
    }
    
    // MARK: - 私有方法
    
    /// 生成缓冲区键值
    private func bufferKey(format: AVAudioFormat, frameCapacity: AVAudioFrameCount) -> String {
        return "\(format.sampleRate)_\(format.channelCount)_\(frameCapacity)"
    }
}