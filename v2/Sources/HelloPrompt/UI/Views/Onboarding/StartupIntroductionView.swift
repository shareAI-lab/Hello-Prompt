//
//  StartupIntroductionView.swift
//  HelloPrompt
//
//  Welcome screen explaining HelloPrompt features and starting the onboarding journey
//  Modern SwiftUI implementation with animations and professional design
//

import SwiftUI

// MARK: - Startup Introduction View
public struct StartupIntroductionView: View {
    
    // MARK: - Properties
    @ObservedObject private var flowManager = OnboardingFlowManager.shared
    @State private var animateFeatures = false
    @State private var showingPrivacyInfo = false
    @State private var currentFeatureIndex = 0
    
    // MARK: - Callbacks
    let onContinue: () -> Void
    let onSkip: () -> Void
    
    // MARK: - Feature Highlights
    private let features: [FeatureHighlight] = [
        FeatureHighlight(
            icon: "mic.and.signal.meter.fill",
            title: "AI-Powered Voice Recording",
            description: "Use advanced speech recognition to convert your voice into text with exceptional accuracy",
            color: .blue,
            benefits: ["High accuracy speech-to-text", "Background noise filtering", "Multiple language support"]
        ),
        FeatureHighlight(
            icon: "brain.head.profile",
            title: "Intelligent Prompt Optimization",
            description: "Transform your rough ideas into polished, effective prompts using GPT-4's intelligence",
            color: .purple,
            benefits: ["Context-aware improvements", "Professional tone enhancement", "Clarity optimization"]
        ),
        FeatureHighlight(
            icon: "keyboard.badge.ellipsis",
            title: "Global Keyboard Shortcuts",
            description: "Access HelloPrompt instantly from any application with customizable hotkeys",
            color: .green,
            benefits: ["System-wide availability", "Customizable shortcuts", "Seamless workflow integration"]
        ),
        FeatureHighlight(
            icon: "text.insert",
            title: "Smart Text Insertion",
            description: "Automatically detect your current app and insert optimized prompts where you need them",
            color: .orange,
            benefits: ["App context detection", "Intelligent insertion", "Clipboard integration"]
        )
    ]
    
    // MARK: - Main Body
    public var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header Section
                headerSection
                
                // Feature Showcase
                featureShowcase
                
                // Getting Started Section
                gettingStartedSection
                
                // Privacy & Security
                privacySection
                
                // Action Buttons
                actionButtons
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
        }
        .background(backgroundGradient)
        .onAppear {
            startAnimations()
            LogManager.shared.info("StartupIntroductionView", "Startup introduction view appeared")
        }
        .sheet(isPresented: $showingPrivacyInfo) {
            privacyInfoSheet
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 24) {
            // App Icon and Title
            VStack(spacing: 16) {
                // Animated App Icon
                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 80, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(animateFeatures ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animateFeatures)
                
                VStack(spacing: 8) {
                    Text("Welcome to HelloPrompt")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Transform your voice into perfect AI prompts")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Value Proposition
            VStack(spacing: 12) {
                Text("Streamline Your AI Workflow")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("HelloPrompt combines advanced speech recognition with AI-powered prompt optimization to help you communicate more effectively with AI assistants.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Feature Showcase
    private var featureShowcase: some View {
        VStack(spacing: 24) {
            Text("Key Features")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            LazyVStack(spacing: 16) {
                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    FeatureCard(
                        feature: feature,
                        isExpanded: currentFeatureIndex == index,
                        onTap: {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                currentFeatureIndex = currentFeatureIndex == index ? -1 : index
                            }
                        }
                    )
                    .opacity(animateFeatures ? 1.0 : 0.0)
                    .offset(y: animateFeatures ? 0 : 30)
                    .animation(
                        .easeOut(duration: 0.6)
                        .delay(Double(index) * 0.15),
                        value: animateFeatures
                    )
                }
            }
        }
    }
    
    // MARK: - Getting Started Section
    private var gettingStartedSection: some View {
        VStack(spacing: 20) {
            Text("Quick Setup")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                SetupStepView(
                    number: "1",
                    title: "Grant Permissions",
                    description: "Allow microphone and accessibility access",
                    icon: "lock.shield.fill",
                    estimatedTime: "1-2 minutes"
                )
                
                SetupStepView(
                    number: "2",
                    title: "Configure API",
                    description: "Connect your OpenAI API key",
                    icon: "key.fill",
                    estimatedTime: "1 minute"
                )
                
                SetupStepView(
                    number: "3",
                    title: "Test & Optimize",
                    description: "Test your setup and choose optimal settings",
                    icon: "cpu.fill",
                    estimatedTime: "1-2 minutes"
                )
            }
            
            // Time Estimate
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                
                Text("Total setup time: 3-5 minutes")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Privacy Section
    private var privacySection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "shield.checkerboard")
                    .font(.title2)
                    .foregroundColor(.green)
                
                Text("Privacy & Security")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                PrivacyFeature(
                    icon: "lock.fill",
                    title: "Local Processing",
                    description: "Voice processing happens on your device when possible"
                )
                
                PrivacyFeature(
                    icon: "key.horizontal.fill",
                    title: "Secure Storage",
                    description: "API keys are stored securely in macOS Keychain"
                )
                
                PrivacyFeature(
                    icon: "eye.slash.fill",
                    title: "No Data Collection",
                    description: "We don't collect or store your personal data"
                )
                
                PrivacyFeature(
                    icon: "network",
                    title: "Direct API Communication",
                    description: "Your data goes directly to OpenAI, not through our servers"
                )
            }
            
            Button("Learn More About Privacy") {
                showingPrivacyInfo = true
            }
            .buttonStyle(.borderless)
            .foregroundColor(.blue)
            .font(.subheadline)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 16) {
            // Primary Action - Start Setup
            Button(action: onContinue) {
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                    
                    Text("Start Setup")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .scaleEffect(animateFeatures ? 1.0 : 0.95)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.8), value: animateFeatures)
            
            // Secondary Action - Skip for Now
            Button("Skip Setup (Use Basic Features)") {
                onSkip()
            }
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)
            .font(.subheadline)
        }
        .padding(.top, 16)
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(.windowBackgroundColor),
                Color(.controlBackgroundColor).opacity(0.3)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Privacy Info Sheet
    private var privacyInfoSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Privacy & Security Details")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        PrivacyDetailSection(
                            icon: "mic.fill",
                            title: "Voice Data",
                            content: "Your voice recordings are processed locally when possible. For speech-to-text conversion, audio may be sent to OpenAI's Whisper API, but is not stored by OpenAI or HelloPrompt."
                        )
                        
                        PrivacyDetailSection(
                            icon: "key.fill",
                            title: "API Keys",
                            content: "Your OpenAI API key is stored securely in the macOS Keychain. It never leaves your device except to authenticate with OpenAI's servers."
                        )
                        
                        PrivacyDetailSection(
                            icon: "network",
                            title: "Network Communication",
                            content: "HelloPrompt communicates directly with OpenAI's servers. We don't proxy your requests or store any of your data on our servers."
                        )
                        
                        PrivacyDetailSection(
                            icon: "chart.bar.fill",
                            title: "Analytics",
                            content: "We collect minimal, anonymous usage analytics to improve the app. No personal data or content is included in analytics."
                        )
                    }
                    
                    Spacer(minLength: 32)
                }
                .padding()
            }
            .navigationTitle("Privacy Information")
            .navigationBarItems(
                trailing: Button("Done") {
                    showingPrivacyInfo = false
                }
            )
        }
    }
    
    // MARK: - Animation Control
    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.8)) {
            animateFeatures = true
        }
        
        // Start feature rotation
        Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                currentFeatureIndex = (currentFeatureIndex + 1) % features.count
            }
        }
    }
    
    // MARK: - Initialization
    public init(onContinue: @escaping () -> Void, onSkip: @escaping () -> Void) {
        self.onContinue = onContinue
        self.onSkip = onSkip
    }
}

// MARK: - Supporting Data Types

private struct FeatureHighlight {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let benefits: [String]
}

// MARK: - Supporting Views

private struct FeatureCard: View {
    let feature: FeatureHighlight
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: feature.icon)
                    .font(.title)
                    .foregroundColor(feature.color)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(feature.color.opacity(0.1))
                    )
                
                // Title and Description
                VStack(alignment: .leading, spacing: 4) {
                    Text(feature.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(feature.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(isExpanded ? nil : 2)
                }
                
                Spacer()
                
                // Expansion Indicator
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            
            // Expanded Benefits
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Key Benefits:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    ForEach(feature.benefits, id: \.self) { benefit in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(feature.color)
                            
                            Text(benefit)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.leading, 60)
                .transition(.opacity.combined(with: .slide))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
                .shadow(color: isExpanded ? feature.color.opacity(0.2) : .clear, radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isExpanded ? feature.color.opacity(0.3) : .clear, lineWidth: 1)
        )
        .onTapGesture {
            onTap()
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isExpanded)
    }
}

private struct SetupStepView: View {
    let number: String
    let title: String
    let description: String
    let icon: String
    let estimatedTime: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Step Number
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 32, height: 32)
                
                Text(number)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // Step Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Time Estimate
            VStack(alignment: .trailing) {
                Text(estimatedTime)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct PrivacyFeature: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.green)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct PrivacyDetailSection: View {
    let icon: String
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
struct StartupIntroductionView_Previews: PreviewProvider {
    static var previews: some View {
        StartupIntroductionView(
            onContinue: {
                print("Continue tapped")
            },
            onSkip: {
                print("Skip tapped")
            }
        )
        .frame(width: 800, height: 1000)
        .previewDisplayName("Startup Introduction")
    }
}
#endif