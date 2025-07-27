# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
This is a SwiftUI macOS application called "Hello-Prompt" with a standard Xcode project structure. The app is a simple "Hello World" application targeting macOS 15.5+.

## Common Commands

### Building
- Build the project: `xcodebuild -project Hello-Prompt.xcodeproj -scheme Hello-Prompt build`
- Clean build: `xcodebuild -project Hello-Prompt.xcodeproj -scheme Hello-Prompt clean`

### Testing
- Run unit tests: `xcodebuild -project Hello-Prompt.xcodeproj -scheme Hello-Prompt test -destination 'platform=macOS'`
- Run specific test: `xcodebuild -project Hello-Prompt.xcodeproj -scheme Hello-Prompt test -destination 'platform=macOS' -only-testing:Hello-PromptTests/Hello_PromptTests/example`

### Running
- Run the app: `xcodebuild -project Hello-Prompt.xcodeproj -scheme Hello-Prompt -configuration Debug`
- Or open in Xcode: `open Hello-Prompt.xcodeproj`

## Project Structure
- `Hello-Prompt/` - Main app source code
  - `Hello_PromptApp.swift` - App entry point with `@main` struct
  - `ContentView.swift` - Main UI view containing a simple globe icon and "Hello, world!" text
  - `Assets.xcassets/` - App icons and other assets
  - `Hello_Prompt.entitlements` - App sandboxing and capabilities
- `Hello-PromptTests/` - Unit tests using Swift Testing framework
- `Hello-PromptUITests/` - UI tests

## Technical Details
- **Framework**: SwiftUI
- **Target Platform**: macOS 15.5+
- **Swift Version**: 5.10
- **Testing Framework**: Swift Testing (uses `@Test` and `#expect()`)
- **Bundle ID**: ShareAI-lab.Hello-Prompt
- **Project Format**: Xcode 16.4 with object version 77

The app uses SwiftUI's declarative syntax with a simple VStack layout containing a system globe image and text. The project follows standard macOS app development patterns with automatic code signing and SwiftUI previews enabled.