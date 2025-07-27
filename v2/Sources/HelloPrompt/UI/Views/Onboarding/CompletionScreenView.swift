//
//  CompletionScreenView.swift
//  HelloPrompt
//
//  Completion screen for onboarding with setup summary and next steps
//  Celebrates successful setup and guides users to start using the app
//

import SwiftUI

// MARK: - Completion Screen View
public struct CompletionScreenView: View {
    
    // MARK: - Properties
    @ObservedObject private var flowManager = OnboardingFlowManager.shared
    @ObservedObject private var storageService = OnboardingStorageService.shared
    @State private var animateCompletion = false
    @State private var showingNextStepsDetail = false
    @State private var confettiPhase: Int = 0
    
    // MARK: - Completion State
    private let completionState: OnboardingCompletionState?
    
    // MARK: - Callbacks
    let onComplete: () -> Void
    let onOpenSettings: () -> Void
    
    // MARK: - Main Body
    public var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                // Celebration Header
                celebrationHeader
                
                // Setup Summary
                setupSummarySection
                
                // Configuration Quality
                qualityAssessmentSection
                
                // Next Steps
                nextStepsSection
                
                // Quick Actions
                quickActionsSection
                
                // Completion Actions
                completionActions
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
        }
        .background(backgroundGradient)
        .onAppear {
            startCelebrationAnimations()
            LogManager.shared.info("CompletionScreenView", "Completion screen view appeared")
        }
        .sheet(isPresented: $showingNextStepsDetail) {
            nextStepsDetailSheet
        }
    }
    
    // MARK: - Celebration Header
    private var celebrationHeader: some View {
        VStack(spacing: 32) {
            // Animated Success Icon
            ZStack {
                // Confetti Background
                ForEach(0..<12, id: \.self) { index in
                    ConfettiParticle(
                        delay: Double(index) * 0.1,
                        phase: confettiPhase
                    )
                }
                
                // Main Success Icon
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(animateCompletion ? 1.2 : 1.0)
                    .rotationEffect(.degrees(animateCompletion ? 360 : 0))
                    .animation(
                        .spring(response: 1.0, dampingFraction: 0.6)
                        .delay(0.5),
                        value: animateCompletion
                    )
            }
            .frame(height: 120)
            
            // Success Message
            VStack(spacing: 16) {
                Text("🎉 Setup Complete!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .opacity(animateCompletion ? 1.0 : 0.0)
                    .offset(y: animateCompletion ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(0.8), value: animateCompletion)
                
                Text("HelloPrompt is ready to transform your voice into perfect AI prompts")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(animateCompletion ? 1.0 : 0.0)
                    .offset(y: animateCompletion ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(1.0), value: animateCompletion)
            }
            
            // Setup Duration
            if let completionState = completionState {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        
                        Text("Setup completed in \(formatDuration(completionState.configurationSummary.totalSetupTime))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    Text("Great job! You're all set to start using HelloPrompt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                )
                .opacity(animateCompletion ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.8).delay(1.2), value: animateCompletion)
            }
        }
    }
    
    // MARK: - Setup Summary Section
    private var setupSummarySection: some View {
        VStack(spacing: 20) {
            Text("Setup Summary")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if let completionState = completionState {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    SummaryCard(
                        icon: "lock.shield.fill",
                        title: "Permissions",
                        value: "\(completionState.configurationSummary.permissionsGranted.count)/3",
                        subtitle: "System permissions granted",
                        color: completionState.configurationSummary.permissionsGranted.count >= 2 ? .green : .orange,
                        isComplete: completionState.configurationSummary.permissionsGranted.count >= 2
                    )
                    
                    SummaryCard(
                        icon: "key.fill",
                        title: "API Setup",
                        value: completionState.configurationSummary.apiConfigured ? "✓" : "✗",
                        subtitle: "OpenAI API configured",
                        color: completionState.configurationSummary.apiConfigured ? .green : .red,
                        isComplete: completionState.configurationSummary.apiConfigured
                    )
                    
                    SummaryCard(
                        icon: "cpu.fill",
                        title: "Model Selection",
                        value: completionState.configurationSummary.modelSelected != nil ? "✓" : "✗",
                        subtitle: completionState.configurationSummary.modelSelected ?? "No model selected",
                        color: completionState.configurationSummary.modelSelected != nil ? .green : .orange,
                        isComplete: completionState.configurationSummary.modelSelected != nil
                    )
                    
                    SummaryCard(
                        icon: "checkmark.circle.fill",
                        title: "Optional Steps",
                        value: "\(completionState.configurationSummary.optionalStepsCompleted)/3",
                        subtitle: "Additional features configured",
                        color: .blue,
                        isComplete: completionState.configurationSummary.optionalStepsCompleted > 0
                    )
                }
            }
        }
        .opacity(animateCompletion ? 1.0 : 0.0)
        .offset(y: animateCompletion ? 0 : 30)
        .animation(.easeOut(duration: 0.8).delay(1.4), value: animateCompletion)
    }
    
    // MARK: - Quality Assessment Section
    private var qualityAssessmentSection: some View {
        VStack(spacing: 20) {
            Text("Configuration Quality")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if let completionState = completionState {
                let quality = completionState.configurationSummary.setupQuality
                
                QualityBadgeView(quality: quality)
                
                Text(quality.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Recommendations for improvement (if needed)
                if quality != .excellent {
                    VStack(spacing: 12) {
                        Text("Suggestions for Enhancement")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        LazyVStack(spacing: 8) {
                            ForEach(getImprovementSuggestions(for: completionState.configurationSummary), id: \.title) { suggestion in
                                ImprovementSuggestionRow(suggestion: suggestion)
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.orange.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
            }
        }
        .opacity(animateCompletion ? 1.0 : 0.0)
        .offset(y: animateCompletion ? 0 : 30)
        .animation(.easeOut(duration: 0.8).delay(1.6), value: animateCompletion)
    }
    
    // MARK: - Next Steps Section
    private var nextStepsSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Next Steps")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("View All") {
                    showingNextStepsDetail = true
                }
                .buttonStyle(.borderless)
                .foregroundColor(.blue)
                .font(.subheadline)
            }
            
            if let completionState = completionState {
                LazyVStack(spacing: 12) {
                    ForEach(Array(completionState.nextSteps.prefix(3).enumerated()), id: \.offset) { index, nextStep in
                        NextStepCard(
                            step: nextStep,
                            index: index + 1,
                            onAction: {
                                handleNextStepAction(nextStep)
                            }
                        )
                        .opacity(animateCompletion ? 1.0 : 0.0)
                        .offset(x: animateCompletion ? 0 : -30)
                        .animation(
                            .easeOut(duration: 0.6)
                            .delay(1.8 + Double(index) * 0.1),
                            value: animateCompletion
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        VStack(spacing: 20) {
            Text("Quick Start")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                QuickActionCard(
                    icon: "mic.circle.fill",
                    title: "Try Voice Recording",
                    description: "Press Ctrl+U to test your first voice prompt",
                    color: .blue,
                    onAction: {
                        // This would trigger a test recording
                        LogManager.shared.info("CompletionScreenView", "User wants to try voice recording")
                    }
                )
                
                QuickActionCard(
                    icon: "gearshape.fill",
                    title: "Open Settings",
                    description: "Customize shortcuts and preferences",
                    color: .gray,
                    onAction: onOpenSettings
                )
                
                QuickActionCard(
                    icon: "book.fill",
                    title: "View Guide",
                    description: "Learn advanced features and tips",
                    color: .green,
                    onAction: {
                        if let url = URL(string: "https://helloprompt.ai/guide") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                )
                
                QuickActionCard(
                    icon: "questionmark.circle.fill",
                    title: "Get Help",
                    description: "Access support and troubleshooting",
                    color: .orange,
                    onAction: {
                        if let url = URL(string: "https://helloprompt.ai/support") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                )
            }
        }
        .opacity(animateCompletion ? 1.0 : 0.0)
        .offset(y: animateCompletion ? 0 : 30)
        .animation(.easeOut(duration: 0.8).delay(2.0), value: animateCompletion)
    }
    
    // MARK: - Completion Actions
    private var completionActions: some View {
        VStack(spacing: 16) {
            // Primary Action - Start Using
            Button(action: onComplete) {
                HStack {
                    Image(systemName: "rocket.fill")
                        .font(.title3)
                    
                    Text("Start Using HelloPrompt")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .green.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .scaleEffect(animateCompletion ? 1.0 : 0.9)
            .opacity(animateCompletion ? 1.0 : 0.0)
            .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(2.2), value: animateCompletion)
            
            // Secondary Actions
            HStack(spacing: 20) {
                Button("Review Settings") {
                    onOpenSettings()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button("Share Feedback") {
                    shareFeedback()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .opacity(animateCompletion ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.6).delay(2.4), value: animateCompletion)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(.windowBackgroundColor),
                Color.green.opacity(0.02),
                Color.mint.opacity(0.01)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Next Steps Detail Sheet
    private var nextStepsDetailSheet: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    Text("Complete Setup Guide")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    if let completionState = completionState {
                        ForEach(Array(completionState.nextSteps.enumerated()), id: \.offset) { index, nextStep in
                            DetailedNextStepCard(
                                step: nextStep,
                                index: index + 1,
                                onAction: {
                                    handleNextStepAction(nextStep)
                                    showingNextStepsDetail = false
                                }
                            )
                        }
                    }
                    
                    Spacer(minLength: 32)
                }
                .padding()
            }
            .navigationTitle("Next Steps")
            .navigationBarItems(
                trailing: Button("Done") {
                    showingNextStepsDetail = false
                }
            )
        }
    }
    
    // MARK: - Methods
    private func startCelebrationAnimations() {
        withAnimation(.easeOut(duration: 1.0)) {
            animateCompletion = true
        }
        
        // Start confetti animation
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 2.0)) {
                confettiPhase = 1
            }
        }
        
        // Second wave of confetti
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 1.5)) {
                confettiPhase = 2
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    private func getImprovementSuggestions(for summary: ConfigurationSummary) -> [ImprovementSuggestion] {
        var suggestions: [ImprovementSuggestion] = []
        
        if summary.permissionsGranted.count < 3 {
            let missingPerms = 3 - summary.permissionsGranted.count
            suggestions.append(ImprovementSuggestion(
                title: "Grant Remaining Permissions",
                description: "Grant \(missingPerms) more permission(s) for full functionality",
                priority: .high,
                icon: "lock.shield.fill"
            ))
        }
        
        if !summary.apiConfigured {
            suggestions.append(ImprovementSuggestion(
                title: "Configure OpenAI API",
                description: "Set up your API key to enable AI features",
                priority: .high,
                icon: "key.fill"
            ))
        }
        
        if summary.modelSelected == nil {
            suggestions.append(ImprovementSuggestion(
                title: "Select AI Model",
                description: "Choose an optimal model for better performance",
                priority: .medium,
                icon: "cpu.fill"
            ))
        }
        
        return suggestions
    }
    
    private func handleNextStepAction(_ nextStep: NextStep) {
        LogManager.shared.info("CompletionScreenView", "Handling next step action: \(nextStep.actionType.rawValue)")
        
        switch nextStep.actionType {
        case .openSettings:
            onOpenSettings()
        case .testFeature:
            // This would trigger a feature test
            break
        case .readDocumentation:
            if let url = URL(string: "https://helloprompt.ai/docs") {
                NSWorkspace.shared.open(url)
            }
        case .configureShortcuts:
            onOpenSettings() // Open settings to shortcuts section
        case .exploreFeatures:
            // This would show a feature tour
            break
        case .joinCommunity:
            if let url = URL(string: "https://helloprompt.ai/community") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    private func shareFeedback() {
        let feedbackURL = "mailto:feedback@helloprompt.ai?subject=HelloPrompt%20Onboarding%20Feedback"
        if let url = URL(string: feedbackURL) {
            NSWorkspace.shared.open(url)
        }
        
        LogManager.shared.info("CompletionScreenView", "User shared feedback")
    }
    
    // MARK: - Initialization
    public init(
        completionState: OnboardingCompletionState?,
        onComplete: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.completionState = completionState
        self.onComplete = onComplete
        self.onOpenSettings = onOpenSettings
    }
}

// MARK: - Supporting Data Types

private struct ImprovementSuggestion {
    let title: String
    let description: String
    let priority: NextStepPriority
    let icon: String
}

// MARK: - Supporting Views

private struct ConfettiParticle: View {
    let delay: Double
    let phase: Int
    
    @State private var offset: CGSize = .zero
    @State private var opacity: Double = 0
    @State private var rotation: Double = 0
    
    private let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange, .pink]
    private let shapes = ["circle.fill", "diamond.fill", "star.fill", "heart.fill"]
    
    var body: some View {
        Image(systemName: shapes.randomElement() ?? "circle.fill")
            .font(.system(size: CGFloat.random(in: 8...16)))
            .foregroundColor(colors.randomElement() ?? .blue)
            .opacity(opacity)
            .offset(offset)
            .rotationEffect(.degrees(rotation))
            .onChange(of: phase) { newPhase in
                if newPhase > 0 {
                    startAnimation()
                }
            }
    }
    
    private func startAnimation() {
        let randomX = CGFloat.random(in: -200...200)
        let randomY = CGFloat.random(in: -100...300)
        let randomRotation = Double.random(in: 0...720)
        
        withAnimation(.easeOut(duration: 2.0).delay(delay)) {
            offset = CGSize(width: randomX, height: randomY)
            opacity = 1.0
            rotation = randomRotation
        }
        
        withAnimation(.easeIn(duration: 1.0).delay(delay + 1.5)) {
            opacity = 0.0
        }
    }
}

private struct SummaryCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let isComplete: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
                
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                }
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: isComplete ? 2 : 1)
                )
        )
        .shadow(color: isComplete ? color.opacity(0.1) : .clear, radius: 4, x: 0, y: 2)
    }
}

private struct QualityBadgeView: View {
    let quality: SetupQuality
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: quality.iconName)
                    .font(.title2)
                    .foregroundColor(quality.color)
                
                Text(quality.displayText)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            // Progress indicator
            let progress = qualityProgress(for: quality)
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: quality.color))
                .scaleEffect(y: 3)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(quality.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(quality.color.opacity(0.3), lineWidth: 2)
                )
        )
    }
    
    private func qualityProgress(for quality: SetupQuality) -> Double {
        switch quality {
        case .minimal: return 0.25
        case .basic: return 0.5
        case .good: return 0.75
        case .excellent: return 1.0
        }
    }
}

private struct ImprovementSuggestionRow: View {
    let suggestion: ImprovementSuggestion
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: suggestion.icon)
                .font(.subheadline)
                .foregroundColor(suggestion.priority.color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(suggestion.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(suggestion.priority.rawValue.uppercased())
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(suggestion.priority.color)
                .clipShape(Capsule())
        }
    }
}

private struct NextStepCard: View {
    let step: NextStep
    let index: Int
    let onAction: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Step Number
            ZStack {
                Circle()
                    .fill(step.priority.color)
                    .frame(width: 32, height: 32)
                
                Text("\(index)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // Step Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: step.iconName)
                        .font(.subheadline)
                        .foregroundColor(step.priority.color)
                    
                    Text(step.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Text(step.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button("Go") {
                onAction()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(step.priority.color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

private struct QuickActionCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let onAction: () -> Void
    
    var body: some View {
        Button(action: onAction) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(color)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct DetailedNextStepCard: View {
    let step: NextStep
    let index: Int
    let onAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ZStack {
                    Circle()
                        .fill(step.priority.color)
                        .frame(width: 40, height: 40)
                    
                    Text("\(index)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(step.title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Image(systemName: step.iconName)
                            .font(.caption)
                            .foregroundColor(step.priority.color)
                        
                        Text("Priority: \(step.priority.rawValue.capitalized)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(step.actionType.displayText) {
                    onAction()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accentColor(step.priority.color)
            }
            
            Text(step.description)
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.leading, 56)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
    }
}

// MARK: - Preview
#if DEBUG
struct CompletionScreenView_Previews: PreviewProvider {
    static var previews: some View {
        let mockCompletion = OnboardingCompletionState(
            configurationSummary: ConfigurationSummary(
                permissionsGranted: [.microphone, .accessibility],
                apiConfigured: true,
                modelSelected: "gpt-4",
                optionalStepsCompleted: 2,
                totalSetupTime: 240
            ),
            nextSteps: [
                NextStep(
                    title: "Test Voice Recording",
                    description: "Try using Ctrl+U to test your first voice prompt",
                    actionType: .testFeature,
                    priority: .high,
                    iconName: "mic.circle.fill"
                ),
                NextStep(
                    title: "Customize Shortcuts",
                    description: "Configure keyboard shortcuts to match your workflow",
                    actionType: .configureShortcuts,
                    priority: .medium,
                    iconName: "keyboard"
                )
            ]
        )
        
        CompletionScreenView(
            completionState: mockCompletion,
            onComplete: { print("Complete") },
            onOpenSettings: { print("Open Settings") }
        )
        .frame(width: 800, height: 1200)
        .previewDisplayName("Completion Screen")
    }
}
#endif