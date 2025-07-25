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
    private var hotKey: HotKey?
    
    var body: some Scene {
        Window("hello_prompt_adventurex", id: "hello_prompt_adventurex-window") {
            hello_prompt_adventurexWindow()
                .environmentObject(viewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 300, height: 350)
        .windowResizability(.contentSize)
        .onAppear {
            hotKey = HotKey(key: .v, modifiers: [.command, .shift])
            hotKey?.keyDownHandler = {
                openWindow(id: "hello_prompt_adventurex-window")
            }
        }
        
        MenuBarExtra("hello_prompt_adventurex", systemImage: "mic.fill") {
            Button("Quit hello_prompt_adventurex") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
