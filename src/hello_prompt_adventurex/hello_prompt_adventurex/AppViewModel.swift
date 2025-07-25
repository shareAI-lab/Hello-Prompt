import Foundation
import HotKey

final class AppViewModel: ObservableObject {
    private var hotKey: HotKey?
    private let transcriptionService = TranscriptionService()
    
    enum AppState {
        case idle
        case listening
        case transcribing
    }
    
    @Published var appState: AppState = .idle {
        didSet {
            Logger.shared.info("App state changed from \(oldValue) to \(appState)", category: "AppViewModel")
        }
    }
    
    @Published var transcribedText: String = ""
    
    var isListening: Bool {
        appState == .listening
    }
    
    init() {
        Logger.shared.info("AppViewModel initialized", category: "AppViewModel")
    }
    
    func setupHotkey(openWindowAction: @escaping () -> Void) {
        Logger.shared.info("Setting up global hotkey (Shift+Command+V)", category: "AppViewModel")
        
        do {
            hotKey = HotKey(key: .v, modifiers: [.command, .shift])
            hotKey?.keyDownHandler = {
                Logger.shared.info("Global hotkey activated", category: "AppViewModel")
                openWindowAction()
            }
            Logger.shared.info("Global hotkey setup completed successfully", category: "AppViewModel")
        } catch {
            Logger.shared.error("Failed to setup global hotkey: \(error.localizedDescription)", category: "AppViewModel")
        }
    }
    
    func startListening() {
        Logger.shared.info("Starting voice recording", category: "AppViewModel")
        appState = .listening
        transcribedText = ""
        
        transcriptionService.startRecording { [weak self] transcribedText in
            DispatchQueue.main.async {
                if let text = transcribedText {
                    self?.transcribedText = text
                    Logger.shared.info("Transcription completed successfully", category: "AppViewModel")
                } else {
                    self?.transcribedText = "Error transcribing."
                    Logger.shared.error("Transcription failed", category: "AppViewModel")
                }
                self?.appState = .idle
            }
        }
    }
    
    func stopListening() {
        Logger.shared.info("Stopping voice recording", category: "AppViewModel")
        transcriptionService.stopRecording()
    }
    
    func startTranscribing() {
        Logger.shared.info("Starting transcription", category: "AppViewModel")
        appState = .transcribing
    }
}