//
//  AudioServiceTests.swift
//  HelloPrompt
//
//  音频服务测试套件 - 测试音频录制、VAD算法、音频处理等功能
//  包含性能测试、质量测试和边界条件测试
//

import XCTest
import AVFoundation
import Combine
@testable import HelloPrompt

class AudioServiceTests: HelloPromptTestCase, AudioServiceTestable {
    
    // MARK: - 测试属性
    var audioService: AudioService!
    var mockAudioEngine: MockAVAudioEngine!
    var testAudioData: Data!
    
    override func setUp() async throws {
        try await super.setUp()
        
        audioService = AudioService()
        mockAudioEngine = MockAVAudioEngine()
        testAudioData = createTestAudioData(duration: 2.0)
        
        // 配置测试环境
        await setupAudioTestEnvironment()
    }
    
    override func tearDown() async throws {
        await cleanupAudioTestEnvironment()
        
        audioService = nil
        mockAudioEngine = nil
        testAudioData = nil
        
        try await super.tearDown()
    }
    
    // MARK: - 环境设置
    
    @MainActor
    private func setupAudioTestEnvironment() async {
        // 设置音频会话为测试模式
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("Warning: Could not configure audio session for testing: \(error)")
        }
    }
    
    @MainActor
    private func cleanupAudioTestEnvironment() async {
        // 停止所有音频操作
        if audioService.isRecording {
            audioService.cancelRecording()
        }
        
        // 重置音频会话
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Warning: Could not deactivate audio session: \(error)")
        }
    }
    
    // MARK: - 基础功能测试
    
    func testAudioInitialization() async throws {
        // 测试音频服务初始化
        let expectation = XCTestExpectation(description: "Audio initialization")
        
        XCTAssertFalse(audioService.isRecording)
        XCTAssertFalse(audioService.isInitialized)
        
        Task {
            do {
                try await audioService.initialize()
                
                await MainActor.run {
                    XCTAssertTrue(audioService.isInitialized)
                    expectation.fulfill()
                }
            } catch {
                XCTFail("Audio initialization failed: \(error)")
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
    }
    
    func testAudioRecording() async throws {
        // 测试音频录制功能
        try await audioService.initialize()
        
        let recordingExpectation = XCTestExpectation(description: "Recording completion")
        var recordedData: Data?
        var recordingError: Error?
        
        // 监听录制完成事件
        audioService.recordingCompletion
            .sink { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    recordingError = error
                }
                recordingExpectation.fulfill()
            } receiveValue: { data in
                recordedData = data
            }
            .store(in: &cancellables)
        
        // 开始录制
        try await audioService.startRecording()
        XCTAssertTrue(audioService.isRecording)
        
        // 模拟录制一些时间
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
        
        // 停止录制
        audioService.stopRecording()
        
        await fulfillment(of: [recordingExpectation], timeout: 5.0)
        
        // 验证结果
        XCTAssertNil(recordingError, "Recording should not produce errors")
        XCTAssertNotNil(recordedData, "Should have recorded audio data")
        XCTAssertGreaterThan(recordedData?.count ?? 0, 0, "Recorded data should not be empty")
        XCTAssertFalse(audioService.isRecording, "Should not be recording after stop")
    }
    
    func testVoiceActivityDetection() async throws {
        // 测试语音活动检测
        try await audioService.initialize()
        
        // 测试静音检测
        let silentData = Data(repeating: 0, count: 1024 * 2) // 2KB的静音数据
        let silentResult = audioService.detectVoiceActivity(in: silentData)
        XCTAssertFalse(silentResult, "Should detect silence")
        
        // 测试有声音检测
        let audioData = createTestAudioData(duration: 0.1) // 100ms的测试音频
        let voiceResult = audioService.detectVoiceActivity(in: audioData)
        XCTAssertTrue(voiceResult, "Should detect voice activity")
    }
    
    func testAudioConfiguration() async throws {
        // 测试音频配置
        let config = AudioConfiguration(
            sampleRate: 44100,
            channels: 2,
            bitDepth: 24,
            silenceThreshold: 0.005,
            silenceTimeout: 1.0
        )
        
        try await audioService.initialize(with: config)
        
        XCTAssertEqual(audioService.currentConfiguration.sampleRate, 44100)
        XCTAssertEqual(audioService.currentConfiguration.channels, 2)
        XCTAssertEqual(audioService.currentConfiguration.bitDepth, 24)
        XCTAssertApproximatelyEqual(audioService.currentConfiguration.silenceThreshold, 0.005)
        XCTAssertApproximatelyEqual(audioService.currentConfiguration.silenceTimeout, 1.0)
    }
    
    // MARK: - 错误处理测试
    
    func testRecordingPermissionError() async throws {
        // 测试录音权限错误处理
        let mockService = MockAudioService()
        mockService.shouldFailPermissionRequest = true
        
        do {
            try await mockService.initialize()
            XCTFail("Should throw permission error")
        } catch let error as AudioSystemError {
            switch error {
            case .permissionDenied:
                break // 期望的错误
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    func testAudioEngineFailure() async throws {
        // 测试音频引擎故障处理
        let mockService = MockAudioService()
        mockService.shouldFailEngineStart = true
        
        do {
            try await mockService.initialize()
            try await mockService.startRecording()
            XCTFail("Should throw engine failure error")
        } catch let error as AudioSystemError {
            switch error {
            case .audioEngineFailure:
                break // 期望的错误
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    func testConcurrentRecordingError() async throws {
        // 测试并发录制错误
        try await audioService.initialize()
        
        try await audioService.startRecording()
        XCTAssertTrue(audioService.isRecording)
        
        // 尝试再次开始录制
        do {
            try await audioService.startRecording()
            XCTFail("Should not allow concurrent recording")
        } catch let error as AudioSystemError {
            switch error {
            case .recordingInProgress:
                break // 期望的错误
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        }
        
        audioService.cancelRecording()
    }
    
    // MARK: - 性能测试
    
    func testRecordingPerformance() async throws {
        // 测试录制性能
        try await audioService.initialize()
        
        await measureAsync({
            try await self.audioService.startRecording()
            
            // 模拟短时间录制
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            
            self.audioService.stopRecording()
            
            // 等待录制完成
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }, iterations: 5, name: "Audio Recording Performance")
    }
    
    func testVADPerformance() async throws {
        // 测试VAD算法性能
        let testData = createTestAudioData(duration: 1.0)
        
        measure {
            _ = audioService.detectVoiceActivity(in: testData)
        }
    }
    
    func testAudioProcessingPerformance() async throws {
        // 测试音频处理性能
        let largeAudioData = createTestAudioData(duration: 10.0)
        
        measure {
            let processedData = audioService.processAudioData(largeAudioData)
            XCTAssertNotNil(processedData)
        }
    }
    
    // MARK: - 质量测试
    
    func testAudioQuality() async throws {
        // 测试音频质量
        try await audioService.initialize()
        
        let qualityMetrics = try await audioService.testAudioQuality(duration: 2.0)
        
        XCTAssertNotNil(qualityMetrics)
        if let metrics = qualityMetrics {
            XCTAssertGreaterThan(metrics.qualityScore, 0.7, "Audio quality should be acceptable")
            XCTAssertLessThan(metrics.rmsLevel, 1.0, "RMS level should be normalized")
            XCTAssertGreaterThan(metrics.snr, 20.0, "Signal-to-noise ratio should be good")
        }
    }
    
    func testAudioFormatConversion() throws {
        // 测试音频格式转换
        let originalData = createTestAudioData(duration: 1.0, sampleRate: 44100)
        
        // 转换为16kHz单声道（Whisper所需格式）
        let convertedData = audioService.convertToWhisperFormat(originalData)
        
        XCTAssertNotNil(convertedData)
        XCTAssertNotEqual(originalData.count, convertedData?.count, "Converted data should be different size")
        
        // 验证转换后的格式
        if let converted = convertedData {
            let expectedFrameCount = Int(1.0 * 16000) // 1秒 * 16kHz
            let expectedDataSize = expectedFrameCount * 2 // 16位 = 2字节
            XCTAssertEqual(converted.count, expectedDataSize, accuracy: 100, "Converted data size should match expected")
        }
    }
    
    // MARK: - 边界条件测试
    
    func testEmptyAudioData() {
        // 测试空音频数据处理
        let emptyData = Data()
        
        let vadResult = audioService.detectVoiceActivity(in: emptyData)
        XCTAssertFalse(vadResult, "Empty data should not contain voice activity")
        
        let processedData = audioService.processAudioData(emptyData)
        XCTAssertEqual(processedData.count, 0, "Processed empty data should remain empty")
    }
    
    func testVeryShortAudioData() {
        // 测试极短音频数据
        let shortData = Data(repeating: 127, count: 32) // 16个16位样本
        
        let vadResult = audioService.detectVoiceActivity(in: shortData)
        // 结果可以是true或false，取决于阈值设置
        
        let processedData = audioService.processAudioData(shortData)
        XCTAssertEqual(processedData.count, shortData.count, "Short data should be processed correctly")
    }
    
    func testVeryLongAudioData() {
        // 测试超长音频数据
        let longData = createTestAudioData(duration: 300.0) // 5分钟
        
        let vadResult = audioService.detectVoiceActivity(in: longData)
        XCTAssertTrue(vadResult, "Long test audio should contain voice activity")
        
        let processedData = audioService.processAudioData(longData)
        XCTAssertGreaterThan(processedData.count, 0, "Long data should be processed")
    }
    
    func testExtremeAudioLevels() {
        // 测试极端音频电平
        let maxVolumeData = Data(repeating: 255, count: 1024 * 2) // 最大音量
        let vadMaxResult = audioService.detectVoiceActivity(in: maxVolumeData)
        XCTAssertTrue(vadMaxResult, "Maximum volume should be detected as voice activity")
        
        let minVolumeData = Data(repeating: 1, count: 1024 * 2) // 最小音量
        let vadMinResult = audioService.detectVoiceActivity(in: minVolumeData)
        // 结果取决于阈值设置
    }
    
    // MARK: - 实时性测试
    
    func testRealTimeProcessing() async throws {
        // 测试实时音频处理
        try await audioService.initialize()
        
        let processingDelays: [TimeInterval] = []
        let expectation = XCTestExpectation(description: "Real-time processing")
        
        // 模拟实时音频数据流
        let bufferSize = 1024 * 2 // 1024个16位样本
        let numberOfBuffers = 10
        
        Task {
            for i in 0..<numberOfBuffers {
                let startTime = CFAbsoluteTimeGetCurrent()
                
                let buffer = createTestAudioData(duration: 0.1) // 100ms缓冲区
                let processedBuffer = audioService.processAudioData(buffer)
                
                let processingTime = CFAbsoluteTimeGetCurrent() - startTime
                
                // 实时处理应该快于音频数据的持续时间
                XCTAssertLessThan(processingTime, 0.1, "Processing should be faster than real-time")
                
                if i == numberOfBuffers - 1 {
                    expectation.fulfill()
                }
                
                // 模拟实时间隔
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    func testAudioLatency() async throws {
        // 测试音频延迟
        try await audioService.initialize()
        
        let latencyExpectation = XCTestExpectation(description: "Audio latency test")
        var measuredLatency: TimeInterval = 0
        
        // 设置延迟测量回调
        audioService.onAudioProcessed = { processedData in
            measuredLatency = CFAbsoluteTimeGetCurrent() - self.recordingStartTime
            latencyExpectation.fulfill()
        }
        
        recordingStartTime = CFAbsoluteTimeGetCurrent()
        try await audioService.startRecording()
        
        // 快速停止以测量最小延迟
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.audioService.stopRecording()
        }
        
        await fulfillment(of: [latencyExpectation], timeout: 2.0)
        
        // 音频延迟应该在可接受范围内（通常<100ms）
        XCTAssertLessThan(measuredLatency, 0.1, "Audio latency should be less than 100ms")
    }
    
    private var recordingStartTime: CFAbsoluteTime = 0
}

// MARK: - Mock对象

class MockAVAudioEngine: AVAudioEngine {
    var shouldFailToStart = false
    var isRunningOverride: Bool = false
    
    override var isRunning: Bool {
        return isRunningOverride
    }
    
    override func start() throws {
        if shouldFailToStart {
            throw NSError(domain: "MockAudioEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock engine start failure"])
        }
        isRunningOverride = true
    }
    
    override func stop() {
        isRunningOverride = false
    }
}

class MockAudioService: AudioService {
    var shouldFailPermissionRequest = false
    var shouldFailEngineStart = false
    var mockAudioData: Data?
    
    override func initialize() async throws {
        if shouldFailPermissionRequest {
            throw AudioSystemError.permissionDenied
        }
        
        if shouldFailEngineStart {
            throw AudioSystemError.audioEngineFailure(NSError(domain: "MockAudioService", code: 1))
        }
        
        // 模拟成功初始化
        await MainActor.run {
            self.isInitialized = true
        }
    }
    
    override func startRecording() async throws {
        if shouldFailEngineStart {
            throw AudioSystemError.audioEngineFailure(NSError(domain: "MockAudioService", code: 2))
        }
        
        await MainActor.run {
            self.isRecording = true
        }
    }
    
    override func stopRecording() {
        isRecording = false
        
        // 模拟录制完成
        if let data = mockAudioData {
            recordingCompletion.send(data)
            recordingCompletion.send(completion: .finished)
        }
    }
}

// MARK: - 音频配置测试结构体

struct AudioConfiguration {
    let sampleRate: Double
    let channels: Int
    let bitDepth: Int
    let silenceThreshold: Float
    let silenceTimeout: TimeInterval
}