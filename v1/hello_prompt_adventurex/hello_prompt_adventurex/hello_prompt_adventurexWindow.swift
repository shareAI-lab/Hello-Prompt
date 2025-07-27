import SwiftUI

struct hello_prompt_adventurexWindow: View {
    var body: some View {
        ContentView()
            .onAppear {
                Logger.shared.info("Main window appeared", category: "Window")
            }
            .onDisappear {
                Logger.shared.info("Main window disappeared", category: "Window")
            }
    }
}