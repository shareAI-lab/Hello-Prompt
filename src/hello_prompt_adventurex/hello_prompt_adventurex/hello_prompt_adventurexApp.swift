//
//  hello_prompt_adventurexApp.swift
//  hello_prompt_adventurex
//
//  Created by Jason Y on 25/7/2025.
//

import SwiftUI
import HotKey

@main
struct hello_prompt_adventurexApp: App {
    @StateObject private var viewModel = AppViewModel()
    @Environment(\.openWindow) private var openWindow
    
    init() {
        Logger.shared.info("Application launching", category: "App")
    }
    
    var body: some Scene {
        Window("hello_prompt_adventurex", id: "hello_prompt_adventurex-window") {
            hello_prompt_adventurexWindow()
                .environmentObject(viewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 300, height: 350)
        .windowResizability(.contentSize)
        
        MenuBarExtra("hello_prompt_adventurex", systemImage: "mic.fill") {
            Button("Quit hello_prompt_adventurex") {
                Logger.shared.info("User requested app termination", category: "App")
                NSApplication.shared.terminate(nil)
            }
            .onAppear {
                Logger.shared.info("MenuBarExtra appeared, setting up hotkey", category: "App")
                viewModel.setupHotkey(openWindowAction: {
                    Logger.shared.info("Opening main window via hotkey", category: "App")
                    openWindow(id: "hello_prompt_adventurex-window")
                })
            }
        }
    }
}
