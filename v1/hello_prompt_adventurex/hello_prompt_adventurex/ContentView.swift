//
//  ContentView.swift
//  hello_prompt_adventurex
//
//  Created by Jason Y on 25/7/2025.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var isAnimating = false
    
    var body: some View {
        VStack {
            if viewModel.isListening {
                Circle()
                    .fill(.blue)
                    .frame(width: 100, height: 100)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
                    .onAppear {
                        Logger.shared.debug("Listening animation started", category: "UI")
                        isAnimating = true
                    }
                    .onDisappear {
                        Logger.shared.debug("Listening animation stopped", category: "UI")
                        isAnimating = false
                    }
                
                Text("Listening...")
                    .font(.headline)
                    .padding(.top, 8)
            } else {
                ScrollView {
                    Text(viewModel.transcribedText.isEmpty ? "Press Shift+Command+V to start." : viewModel.transcribedText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
        }
        .frame(width: 300, height: 350)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onAppear {
            Logger.shared.info("ContentView appeared", category: "UI")
            
            // Safety check to prevent crashes
            guard !viewModel.isListening else {
                Logger.shared.warning("Already listening when ContentView appeared - skipping start", category: "UI")
                return
            }
            
            // Add a small delay to ensure the view is fully loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                Logger.shared.debug("Starting voice recording after view setup", category: "UI")
                viewModel.startListening()
            }
        }
        .onDisappear {
            Logger.shared.info("ContentView disappeared", category: "UI")
            
            // Safety check before stopping
            if viewModel.isListening {
                Logger.shared.debug("Stopping recording because view disappeared", category: "UI")
                viewModel.stopListening()
            } else {
                Logger.shared.debug("Not listening when view disappeared - no action needed", category: "UI")
            }
        }
        .onKeyPress(.space) {
            Logger.shared.debug("Spacebar pressed", category: "UI")
            
            // Safety check and detailed logging
            if viewModel.isListening {
                Logger.shared.info("User pressed spacebar to stop recording", category: "UI")
                viewModel.stopListening()
                return .handled
            } else {
                Logger.shared.debug("Spacebar pressed but not listening - ignoring", category: "UI")
                return .ignored
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppViewModel())
}
