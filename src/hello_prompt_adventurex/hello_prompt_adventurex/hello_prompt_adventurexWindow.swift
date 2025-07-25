import SwiftUI

struct hello_prompt_adventurexWindow: View {
    @StateObject private var viewModel = AppViewModel()
    
    var body: some View {
        ContentView()
            .environmentObject(viewModel)
    }
}