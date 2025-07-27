import Foundation
import HotKey
import ApplicationServices

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
        
        // Check if we have accessibility permissions
        let trusted = AXIsProcessTrusted()
        if !trusted {
            Logger.shared.error("⚠️ ACCESSIBILITY PERMISSIONS REQUIRED!", category: "AppViewModel")
            Logger.shared.error("💡 Go to System Settings > Privacy & Security > Accessibility", category: "AppViewModel")
            Logger.shared.error("💡 Add 'hello_prompt_adventurex' to the allowed apps list", category: "AppViewModel")
            Logger.shared.error("💡 The global hotkey (Shift+Command+V) won't work without this!", category: "AppViewModel")
        } else {
            Logger.shared.info("✅ Accessibility permissions granted", category: "AppViewModel")
        }
        
        Logger.shared.debug("Creating HotKey instance", category: "AppViewModel")
        hotKey = HotKey(key: .v, modifiers: [.command, .shift])
        
        guard let hotKey = hotKey else {
            Logger.shared.error("❌ Failed to create HotKey instance", category: "AppViewModel")
            Logger.shared.error("💡 This may indicate accessibility permission issues", category: "AppViewModel")
            return
        }
        
        hotKey.keyDownHandler = {
            Logger.shared.info("🔥 Global hotkey activated (Shift+Command+V)", category: "AppViewModel")
            openWindowAction()
        }
        
        Logger.shared.info("✅ Global hotkey setup completed successfully", category: "AppViewModel")
        
        // Test the hotkey setup
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if !trusted {
                Logger.shared.warning("⚠️ Remember: Hotkey won't work until accessibility permissions are granted!", category: "AppViewModel")
            }
        }
    }
    
    func startListening() {
        Logger.shared.info("🎤 Starting voice recording session", category: "AppViewModel")
        
        guard appState != .listening else {
            Logger.shared.warning("Already listening - ignoring duplicate start request", category: "AppViewModel")
            return
        }
        
        appState = .listening
        transcribedText = ""
        Logger.shared.debug("App state changed to .listening, transcribed text cleared", category: "AppViewModel")
        
        transcriptionService.startRecording { [weak self] transcribedText in
            DispatchQueue.main.async {
                guard let self = self else {
                    Logger.shared.warning("AppViewModel was deallocated during transcription", category: "AppViewModel")
                    return
                }
                
                if let text = transcribedText, !text.isEmpty {
                    self.transcribedText = text
                    Logger.shared.info("✅ Transcription completed successfully (\(text.count) characters)", category: "AppViewModel")
                    Logger.shared.debug("Transcribed text preview: \(String(text.prefix(50)))...", category: "AppViewModel")
                } else {
                    self.transcribedText = "Error transcribing."
                    Logger.shared.error("❌ Transcription failed - received nil or empty text", category: "AppViewModel")
                    Logger.shared.error("💡 Check microphone permissions and OpenAI API key", category: "AppViewModel")
                }
                
                self.appState = .idle
                Logger.shared.debug("App state changed back to .idle", category: "AppViewModel")
            }
        }
    }
    
    func stopListening() {
        Logger.shared.info("🛑 Stopping voice recording", category: "AppViewModel")
        
        guard appState == .listening else {
            Logger.shared.warning("Not currently listening - ignoring stop request", category: "AppViewModel")
            return
        }
        
        Logger.shared.debug("Calling transcriptionService.stopRecording()", category: "AppViewModel")
        transcriptionService.stopRecording()
        
        // Don't change state here - let the completion handler do it
        Logger.shared.debug("Stop recording request sent, waiting for completion", category: "AppViewModel")
    }
    
    func startTranscribing() {
        Logger.shared.info("Starting transcription", category: "AppViewModel")
        appState = .transcribing
    }
}