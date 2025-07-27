//
//  OnboardingMainView.swift
//  HelloPrompt
//
//  Main onboarding view that orchestrates the entire flow
//  Integrates all onboarding steps with the flow manager
//

import SwiftUI

// MARK: - Main Onboarding View
public struct OnboardingMainView: View {
    
    // MARK: - Properties
    @ObservedObject private var flowManager = OnboardingFlowManager.shared
    @ObservedObject private var storageService = OnboardingStorageService.shared
    @State private var showingExitConfirmation = false
    @State private var isAnimatingTransition = false
    
    // MARK: - Callbacks
    let onCompleted: () -> Void
    let onSkipped: () -> Void
    
    // MARK: - Main Body
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                backgroundView
                
                // Main Content
                VStack(spacing: 0) {
                    // Progress Header
                    progressHeader
                        .background(Color(.controlBackgroundColor))
                    
                    Divider()
                    
                    // Step Content
                    stepContentView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(isAnimatingTransition ? 0.5 : 1.0)
                        .scaleEffect(isAnimatingTransition ? 0.95 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: isAnimatingTransition)
                    
                    // Error Overlay
                    if flowManager.hasError {
                        errorOverlay
                    }
                }
                
                // Loading Overlay
                if flowManager.isLoading {
                    loadingOverlay
                }
            }
        }
        .frame(minWidth: 800, minHeight: 700)
        .onAppear {
            setupOnboarding()
        }
        .confirmationDialog(
            "Exit Onboarding",
            isPresented: $showingExitConfirmation,
            titleVisibility: .visible
        ) {
            Button("Save Progress & Exit") {
                flowManager.stopOnboarding()
                onSkipped()
            }
            
            Button("Exit Without Saving") {
                storageService.skipOnboarding(permanent: false)
                onSkipped()
            }
            
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You can return to complete the setup later, or exit without saving your progress.")
        }
    }
    
    // MARK: - Background View
    private var backgroundView: some View {
        LinearGradient(
            colors: [
                Color(.windowBackgroundColor),
                flowManager.currentStep.accentColor.opacity(0.03)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Progress Header
    private var progressHeader: some View {
        VStack(spacing: 16) {
            // Title and Exit Button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("HelloPrompt Setup")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Step \(flowManager.currentStep.rawValue + 1) of \(OnboardingStepType.allCases.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    // Time Indicator
                    if flowManager.estimatedTimeRemainingMinutes > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(flowManager.estimatedTimeRemainingMinutes) min left")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(.controlBackgroundColor))
                        )
                    }
                    
                    // Exit Button
                    Button("Exit Setup") {
                        showingExitConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            // Progress Indicator
            OnboardingProgressView(
                currentStep: flowManager.currentStep,
                progress: flowManager.progress,
                canProceed: flowManager.canProceed
            )
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
    }
    
    // MARK: - Step Content View
    @ViewBuilder
    private var stepContentView: some View {
        switch flowManager.currentStep {
        case .startupIntroduction:
            StartupIntroductionView(
                onContinue: {
                    navigateToNextStep()
                },
                onSkip: {
                    flowManager.skipOnboarding(permanent: false)
                    onSkipped()
                }
            )
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            
        case .permissionConfiguration:
            PermissionConfigurationView(
                onContinue: {
                    navigateToNextStep()
                },
                onSkip: {
                    flowManager.skipCurrentStep()
                },
                onBack: {
                    navigateToPreviousStep()
                }
            )
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            
        case .apiKeySetup:
            APIKeySetupView(
                onContinue: {
                    navigateToNextStep()
                },
                onSkip: {
                    flowManager.skipCurrentStep()
                },
                onBack: {
                    navigateToPreviousStep()
                }
            )
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            
        case .modelTesting:
            ModelTestingView(
                onContinue: {
                    navigateToNextStep()
                },
                onSkip: {
                    flowManager.skipCurrentStep()
                },
                onBack: {
                    navigateToPreviousStep()
                }
            )
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            
        case .completionScreen:
            CompletionScreenView(
                completionState: storageService.completionState,
                onComplete: {
                    completeOnboarding()
                },
                onOpenSettings: {
                    // This would open settings after completion
                    completeOnboarding()
                }
            )
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
        }
    }
    
    // MARK: - Error Overlay
    private var errorOverlay: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundColor(.red)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Setup Error")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if let error = flowManager.currentError {
                        Text(error.message)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button("Dismiss") {
                    // Clear error - this should be handled by flow manager
                    LogManager.shared.info("OnboardingMainView", "User dismissed error")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: .red.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: flowManager.hasError)
    }
    
    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: flowManager.currentStep.accentColor))
                
                Text("Setting up your configuration...")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Please wait while we configure HelloPrompt")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 16, x: 0, y: 8)
            )
        }
        .animation(.easeInOut(duration: 0.3), value: flowManager.isLoading)
    }
    
    // MARK: - Navigation Methods
    private func navigateToNextStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isAnimatingTransition = true
        }
        
        Task {
            await MainActor.run {
                flowManager.nextStep()
                
                withAnimation(.easeInOut(duration: 0.3).delay(0.1)) {
                    isAnimatingTransition = false
                }
            }
        }
        
        LogManager.shared.info("OnboardingMainView", "Navigating to next step")
    }
    
    private func navigateToPreviousStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isAnimatingTransition = true
        }
        
        Task {
            await MainActor.run {
                flowManager.previousStep()
                
                withAnimation(.easeInOut(duration: 0.3).delay(0.1)) {
                    isAnimatingTransition = false
                }
            }
        }
        
        LogManager.shared.info("OnboardingMainView", "Navigating to previous step")
    }
    
    private func completeOnboarding() {
        flowManager.completeOnboarding()
        onCompleted()
        
        LogManager.shared.info("OnboardingMainView", "Onboarding completed successfully")
    }
    
    // MARK: - Setup
    private func setupOnboarding() {
        // Set up flow manager callbacks
        flowManager.onCompleted = { completionState in
            LogManager.shared.info("OnboardingMainView", "Flow manager reported completion")
        }
        
        flowManager.onSkipped = {
            LogManager.shared.info("OnboardingMainView", "Flow manager reported skip")
        }
        
        flowManager.onError = { error in
            LogManager.shared.error("OnboardingMainView", "Flow manager reported error: \(error.message)")
        }
        
        flowManager.onStepChanged = { step in
            LogManager.shared.info("OnboardingMainView", "Step changed to: \(step.title)")
        }
        
        // Start the onboarding flow
        flowManager.startOnboarding()
        
        LogManager.shared.info("OnboardingMainView", "Onboarding main view setup completed")
    }
    
    // MARK: - Initialization
    public init(onCompleted: @escaping () -> Void, onSkipped: @escaping () -> Void) {
        self.onCompleted = onCompleted
        self.onSkipped = onSkipped
    }
}

// MARK: - Progress View Component
private struct OnboardingProgressView: View {
    let currentStep: OnboardingStepType
    let progress: OnboardingProgress?
    let canProceed: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Step Indicators
            HStack(spacing: 8) {
                ForEach(OnboardingStepType.allCases, id: \.self) { step in
                    VStack(spacing: 8) {
                        // Step Circle
                        ZStack {
                            Circle()
                                .fill(stepBackgroundColor(for: step))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: stepIconName(for: step))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(stepForegroundColor(for: step))
                        }
                        .scaleEffect(currentStep == step ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                        
                        // Step Label
                        Text(step.title)
                            .font(.caption2)
                            .foregroundColor(stepLabelColor(for: step))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 80)
                            .lineLimit(2)
                    }
                    
                    // Connector Line
                    if step != OnboardingStepType.allCases.last {
                        Rectangle()
                            .fill(connectorColor(for: step))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            
            // Overall Progress Bar
            ProgressView(value: progressValue, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: currentStep.accentColor))
                .scaleEffect(y: 1.5)
            
            // Progress Text
            HStack {
                Text(progressText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(progressValue * 100))% Complete")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func stepBackgroundColor(for step: OnboardingStepType) -> Color {
        if isStepCompleted(step) {
            return .green
        } else if step == currentStep {
            return canProceed ? step.accentColor : .orange
        } else {
            return .gray.opacity(0.2)
        }
    }
    
    private func stepForegroundColor(for step: OnboardingStepType) -> Color {
        if isStepCompleted(step) || step == currentStep {
            return .white
        } else {
            return .gray
        }
    }
    
    private func stepLabelColor(for step: OnboardingStepType) -> Color {
        if isStepCompleted(step) || step == currentStep {
            return .primary
        } else {
            return .secondary
        }
    }
    
    private func stepIconName(for step: OnboardingStepType) -> String {
        if isStepCompleted(step) {
            return "checkmark"
        } else {
            return step.iconName
        }
    }
    
    private func connectorColor(for step: OnboardingStepType) -> Color {
        if isStepCompleted(step) {
            return .green
        } else {
            return .gray.opacity(0.3)
        }
    }
    
    private func isStepCompleted(_ step: OnboardingStepType) -> Bool {
        return progress?.isStepCompleted(step) ?? false
    }
    
    private var progressValue: Double {
        let completedSteps = Double(progress?.completedSteps.count ?? 0)
        let totalSteps = Double(OnboardingStepType.allCases.count)
        let currentStepProgress = Double(currentStep.rawValue) / totalSteps
        
        return max(completedSteps / totalSteps, currentStepProgress)
    }
    
    private var progressText: String {
        let completedCount = progress?.completedSteps.count ?? 0
        let totalCount = OnboardingStepType.allCases.count
        
        if completedCount == totalCount {
            return "Setup complete!"
        } else {
            return "Step \(currentStep.rawValue + 1) of \(totalCount): \(currentStep.title)"
        }
    }
}

// MARK: - Preview
#if DEBUG
struct OnboardingMainView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingMainView(
            onCompleted: {
                print("Onboarding completed")
            },
            onSkipped: {
                print("Onboarding skipped")
            }
        )
        .previewDisplayName("Onboarding Main View")
    }
}
#endif