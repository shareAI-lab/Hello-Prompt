import Foundation

final class AppViewModel: ObservableObject {
    
    enum AppState {
        case idle
        case listening
        case transcribing
    }
    
    @Published var appState: AppState = .idle
    @Published var transcribedText: String = ""
    
    var isListening: Bool {
        appState == .listening
    }
}