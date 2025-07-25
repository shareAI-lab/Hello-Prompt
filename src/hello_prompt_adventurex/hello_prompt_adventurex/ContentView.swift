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
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppViewModel())
}
