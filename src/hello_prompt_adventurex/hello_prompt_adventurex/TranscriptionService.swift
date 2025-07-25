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
        // TODO: Replace with your actual OpenAI API key
        // Consider using Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") or similar
        self.openAI = OpenAI(apiToken: "YOUR_API_KEY")
    }
    
    func startRecording(completion: @escaping (String?) -> Void) {
        self.recordingCompletion = completion
        setupAudioRecording()
    }
    
    private func setupAudioRecording() {
        do {
            // Create audio engine and input node
            audioEngine = AVAudioEngine()
            guard let audioEngine = audioEngine else {
                recordingCompletion?(nil)
                return
            }
            
            inputNode = audioEngine.inputNode
            guard let inputNode = inputNode else {
                recordingCompletion?(nil)
                return
            }
            
            // Create temporary file for recording
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            audioFileURL = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).wav")
            
            guard let audioFileURL = audioFileURL else {
                recordingCompletion?(nil)
                return
            }
            
            // Set up audio format
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            // Create audio file
            audioFile = try AVAudioFile(forWriting: audioFileURL, settings: recordingFormat.settings)
            
            // Install tap on input node
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                try? self?.audioFile?.write(from: buffer)
            }
            
            // Start audio engine
            try audioEngine.start()
            
        } catch {
            print("Error setting up audio recording: \(error)")
            recordingCompletion?(nil)
        }
    }
    
    func stopRecording() {
        // Stop audio engine and remove tap
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        
        // Close audio file
        audioFile = nil
        
        guard let audioFileURL = audioFileURL else {
            recordingCompletion?(nil)
            return
        }
        
        // Transcribe audio using OpenAI
        transcribeAudio(from: audioFileURL)
    }
    
    private func transcribeAudio(from url: URL) {
        Task {
            do {
                let audioData = try Data(contentsOf: url)
                
                // Get the file extension from the URL and initialize the correct enum type.
                guard let fileType = AudioTranscriptionQuery.FileType(rawValue: url.pathExtension.lowercased()) else {
                    print("Unsupported file type: \(url.pathExtension)")
                    DispatchQueue.main.async { [weak self] in
                        self?.recordingCompletion?(nil)
                        self?.cleanup()
                    }
                    return
                }

                // Create the query with the correct fileType enum.
                let query = AudioTranscriptionQuery(
                    file: audioData,
                    fileType: fileType,
                    model: "whisper-1"
                )
                
                let result = try await openAI.audioTranscriptions(query: query)
                
                DispatchQueue.main.async { [weak self] in
                    self?.recordingCompletion?(result.text)
                    self?.cleanup()
                }
                
            } catch {
                print("Error transcribing audio: \(error)")
                DispatchQueue.main.async { [weak self] in
                    self?.recordingCompletion?(nil)
                    self?.cleanup()
                }
            }
        }
    }
    
    private func cleanup() {
        // Clean up temporary audio file
        if let audioFileURL = audioFileURL {
            try? FileManager.default.removeItem(at: audioFileURL)
            self.audioFileURL = nil
        }
        
        // Reset properties
        audioEngine = nil
        inputNode = nil
        audioFile = nil
        recordingCompletion = nil
    }
}