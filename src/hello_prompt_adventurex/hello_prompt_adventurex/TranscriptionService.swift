import AVFoundation
import OpenAI
import Foundation

final class TranscriptionService: @unchecked Sendable {
    private let openAI: OpenAI
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFile: AVAudioFile?
    private var audioFileURL: URL?
    private var recordingCompletion: ((String?) -> Void)?
    
    init() {
        Logger.shared.info("Initializing TranscriptionService", category: "TranscriptionService")
        
        let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? "YOUR_API_KEY"
        if apiKey == "YOUR_API_KEY" {
            Logger.shared.error("⚠️ CRITICAL: OpenAI API key not set! Replace 'YOUR_API_KEY' with your actual key", category: "TranscriptionService")
            Logger.shared.error("💡 This will cause 401 errors when trying to transcribe", category: "TranscriptionService")
        } else {
            Logger.shared.info("OpenAI API key configured (length: \(apiKey.count))", category: "TranscriptionService")
        }
        
        self.openAI = OpenAI(apiToken: apiKey)
        Logger.shared.info("TranscriptionService initialized successfully", category: "TranscriptionService")
    }
    
    func startRecording(completion: @escaping (String?) -> Void) {
        Logger.shared.info("Starting audio recording", category: "TranscriptionService")
        self.recordingCompletion = completion
        
        // Check microphone permission first
        checkMicrophonePermission { [weak self] hasPermission in
            if hasPermission {
                Logger.shared.info("Microphone permission granted, setting up recording", category: "TranscriptionService")
                self?.setupAudioRecording()
            } else {
                Logger.shared.error("❌ MICROPHONE PERMISSION DENIED!", category: "TranscriptionService")
                Logger.shared.error("💡 Fix: Go to System Settings > Privacy & Security > Microphone", category: "TranscriptionService")
                Logger.shared.error("💡 Add 'hello_prompt_adventurex' to allowed apps", category: "TranscriptionService")
                completion(nil)
            }
        }
    }
    
    private func checkMicrophonePermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            Logger.shared.info("Microphone access already authorized", category: "TranscriptionService")
            completion(true)
        case .notDetermined:
            Logger.shared.info("Requesting microphone permission...", category: "TranscriptionService")
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    if granted {
                        Logger.shared.info("Microphone permission granted by user", category: "TranscriptionService")
                    } else {
                        Logger.shared.error("Microphone permission denied by user", category: "TranscriptionService")
                    }
                    completion(granted)
                }
            }
        case .denied, .restricted:
            Logger.shared.error("Microphone access denied or restricted", category: "TranscriptionService")
            completion(false)
        @unknown default:
            Logger.shared.error("Unknown microphone permission status", category: "TranscriptionService")
            completion(false)
        }
    }
    
    private func setupAudioRecording() {
        Logger.shared.info("Setting up audio recording engine", category: "TranscriptionService")
        do {
            // Create audio engine and input node
            Logger.shared.debug("Creating AVAudioEngine", category: "TranscriptionService")
            audioEngine = AVAudioEngine()
            guard let audioEngine = audioEngine else {
                Logger.shared.error("❌ Failed to create AVAudioEngine", category: "TranscriptionService")
                Logger.shared.error("💡 This may indicate audio system issues", category: "TranscriptionService")
                recordingCompletion?(nil)
                return
            }
            
            Logger.shared.debug("Getting audio input node", category: "TranscriptionService")
            inputNode = audioEngine.inputNode
            guard let inputNode = inputNode else {
                Logger.shared.error("❌ Failed to get audio input node", category: "TranscriptionService")
                Logger.shared.error("💡 Check if microphone is connected and accessible", category: "TranscriptionService")
                recordingCompletion?(nil)
                return
            }
            
            // Create temporary file for recording
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = "recording_\(Date().timeIntervalSince1970).wav"
            audioFileURL = documentsPath.appendingPathComponent(fileName)
            
            guard let audioFileURL = audioFileURL else {
                Logger.shared.error("❌ Failed to create audio file URL", category: "TranscriptionService")
                recordingCompletion?(nil)
                return
            }
            
            Logger.shared.debug("Creating audio file at: \(audioFileURL.path)", category: "TranscriptionService")
            
            // Set up audio format
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            Logger.shared.debug("Audio format - Sample Rate: \(recordingFormat.sampleRate), Channels: \(recordingFormat.channelCount)", category: "TranscriptionService")
            
            // Create audio file
            audioFile = try AVAudioFile(forWriting: audioFileURL, settings: recordingFormat.settings)
            Logger.shared.debug("Audio file created successfully", category: "TranscriptionService")
            
            // Install tap on input node
            Logger.shared.debug("Installing audio tap on input node", category: "TranscriptionService")
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                do {
                    try self?.audioFile?.write(from: buffer)
                } catch {
                    Logger.shared.error("Error writing audio buffer: \(error.localizedDescription)", category: "TranscriptionService")
                }
            }
            
            // Start audio engine
            Logger.shared.debug("Starting audio engine", category: "TranscriptionService")
            try audioEngine.start()
            Logger.shared.info("✅ Audio recording started successfully", category: "TranscriptionService")
            
        } catch {
            Logger.shared.error("❌ Error setting up audio recording: \(error.localizedDescription)", category: "TranscriptionService")
            if error.localizedDescription.contains("permissions") {
                Logger.shared.error("💡 This looks like a permissions issue. Check microphone access in System Settings", category: "TranscriptionService")
            }
            Logger.shared.error("💡 Full error: \(error)", category: "TranscriptionService")
            recordingCompletion?(nil)
        }
    }
    
    func stopRecording() {
        Logger.shared.info("Stopping audio recording", category: "TranscriptionService")
        
        // Stop audio engine and remove tap
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        Logger.shared.debug("Audio engine stopped and tap removed", category: "TranscriptionService")
        
        // Close audio file
        audioFile = nil
        
        guard let audioFileURL = audioFileURL else {
            Logger.shared.error("❌ No audio file URL available for transcription", category: "TranscriptionService")
            recordingCompletion?(nil)
            return
        }
        
        // Check if file exists and has content
        do {
            let fileSize = try FileManager.default.attributesOfItem(atPath: audioFileURL.path)[.size] as? Int64 ?? 0
            Logger.shared.info("Audio file size: \(fileSize) bytes", category: "TranscriptionService")
            
            if fileSize == 0 {
                Logger.shared.error("❌ Audio file is empty - no audio was recorded", category: "TranscriptionService")
                Logger.shared.error("💡 Check microphone permissions and connection", category: "TranscriptionService")
                recordingCompletion?(nil)
                return
            }
        } catch {
            Logger.shared.error("❌ Could not check audio file: \(error.localizedDescription)", category: "TranscriptionService")
        }
        
        // Transcribe audio using OpenAI
        Logger.shared.info("Starting transcription process", category: "TranscriptionService")
        transcribeAudio(from: audioFileURL)
    }
    
    private func transcribeAudio(from url: URL) {
        Task {
            do {
                Logger.shared.debug("Loading audio data from file", category: "TranscriptionService")
                let audioData = try Data(contentsOf: url)
                Logger.shared.info("Loaded \(audioData.count) bytes of audio data", category: "TranscriptionService")
                
                // Get the file extension from the URL and initialize the correct enum type.
                let fileExtension = url.pathExtension.lowercased()
                Logger.shared.debug("Audio file extension: \(fileExtension)", category: "TranscriptionService")
                
                guard let fileType = AudioTranscriptionQuery.FileType(rawValue: fileExtension) else {
                    Logger.shared.error("❌ Unsupported file type: \(fileExtension)", category: "TranscriptionService")
                    Logger.shared.error("💡 Supported formats: wav, mp3, m4a, etc.", category: "TranscriptionService")
                    DispatchQueue.main.async { [weak self] in
                        self?.recordingCompletion?(nil)
                        self?.cleanup()
                    }
                    return
                }

                // Create the query with the correct fileType enum.
                Logger.shared.debug("Creating OpenAI transcription query", category: "TranscriptionService")
                let query = AudioTranscriptionQuery(
                    file: audioData,
                    fileType: fileType,
                    model: "whisper-1"
                )
                
                Logger.shared.info("Sending transcription request to OpenAI...", category: "TranscriptionService")
                let result = try await openAI.audioTranscriptions(query: query)
                Logger.shared.info("✅ Transcription completed successfully", category: "TranscriptionService")
                Logger.shared.debug("Transcribed text length: \(result.text.count) characters", category: "TranscriptionService")
                
                DispatchQueue.main.async { [weak self] in
                    self?.recordingCompletion?(result.text)
                    self?.cleanup()
                }

            } catch {
                Logger.shared.error("❌ Error transcribing audio: \(error.localizedDescription)", category: "TranscriptionService")

                // Check for specific error types
                let nsError = error as NSError
                // The 'if let' around 'error as? NSError' was removed because Any Error can always be cast to NSError.
                // Now, direct checking of nsError.code
                if nsError.code == 401 {
                    Logger.shared.error("🔑 OPENAI API KEY ERROR (401 Unauthorized)", category: "TranscriptionService")
                    Logger.shared.error("💡 Your API key is invalid, missing, or you don't have access", category: "TranscriptionService")
                    Logger.shared.error("💡 Check your OpenAI API key in TranscriptionService.swift", category: "TranscriptionService")
                    Logger.shared.error("💡 Verify your OpenAI account has credits and Whisper API access", category: "TranscriptionService")
                } else if nsError.code == 429 {
                    Logger.shared.error("⚠️ RATE LIMIT ERROR (429 Too Many Requests)", category: "TranscriptionService")
                    Logger.shared.error("💡 You've exceeded your OpenAI API rate limit", category: "TranscriptionService")
                } else if nsError.code == -1009 {
                    Logger.shared.error("🌐 NETWORK ERROR - No internet connection", category: "TranscriptionService")
                    Logger.shared.error("💡 Check your internet connection", category: "TranscriptionService")
                }

                Logger.shared.error("💡 Full error details: \(error)", category: "TranscriptionService")

                DispatchQueue.main.async { [weak self] in
                    self?.recordingCompletion?(nil)
                    self?.cleanup()
                }
            }
        }
    }

    private func cleanup() {
        Logger.shared.debug("Cleaning up TranscriptionService resources", category: "TranscriptionService")

        // Clean up temporary audio file
        if let audioFileURL = audioFileURL {
            do {
                try FileManager.default.removeItem(at: audioFileURL)
                Logger.shared.debug("Temporary audio file deleted successfully", category: "TranscriptionService")
            } catch {
                Logger.shared.warning("Could not delete temporary audio file: \(error.localizedDescription)", category: "TranscriptionService")
            }
            self.audioFileURL = nil
        }

        // Reset properties
        audioEngine = nil
        inputNode = nil
        audioFile = nil
        recordingCompletion = nil

        Logger.shared.debug("TranscriptionService cleanup completed", category: "TranscriptionService")
    }
}