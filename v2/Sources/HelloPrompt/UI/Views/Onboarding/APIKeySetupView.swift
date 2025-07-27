//
//  APIKeySetupView.swift
//  HelloPrompt
//
//  Modern API key setup view with validation, testing, and guidance
//  Provides secure configuration of OpenAI API settings
//

import SwiftUI

// MARK: - API Key Setup View
public struct APIKeySetupView: View {
    
    // MARK: - Properties
    @ObservedObject private var flowManager = OnboardingFlowManager.shared
    @ObservedObject private var configManager = AppConfigManager.shared
    
    // Form State
    @State private var apiKey: String = ""
    @State private var baseURL: String = "https://api.openai.com/v1"
    @State private var organizationID: String = ""
    @State private var showApiKey: Bool = false
    
    // UI State
    @State private var isTestingConnection = false
    @State private var showingAPIKeyGuide = false
    @State private var animateForm = false
    @State private var validationErrors: [ValidationError] = []
    
    // Real-time validation
    @State private var apiKeyValidation: ValidationState = .idle
    @State private var baseURLValidation: ValidationState = .idle
    
    // MARK: - Callbacks
    let onContinue: () -> Void
    let onSkip: () -> Void
    let onBack: () -> Void
    
    // MARK: - Main Body
    public var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                headerSection
                
                // Configuration Form
                configurationForm
                
                // Connection Testing
                connectionTestingSection
                
                // Help and Guidance
                helpSection
                
                // Action Buttons
                actionButtons
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
        }
        .background(backgroundGradient)
        .onAppear {
            setupInitialState()
            startAnimations()
            LogManager.shared.info("APIKeySetupView", "API key setup view appeared")
        }
        .sheet(isPresented: $showingAPIKeyGuide) {
            apiKeyGuideSheet
        }
        .onChange(of: apiKey) { newValue in
            validateAPIKey(newValue)
        }
        .onChange(of: baseURL) { newValue in
            validateBaseURL(newValue)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: "key.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(animateForm ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animateForm)
            
            VStack(spacing: 12) {
                Text("API Configuration")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Connect your OpenAI API key to enable AI-powered features")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Configuration Status
            ConfigurationStatusView(
                isConfigured: flowManager.apiConfigState.isConfigured,
                testStatus: flowManager.apiConfigState.testStatus,
                lastTested: flowManager.apiConfigState.lastTestedAt
            )
        }
    }
    
    // MARK: - Configuration Form
    private var configurationForm: some View {
        VStack(spacing: 24) {
            Text("API Settings")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 20) {
                // API Key Field
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("OpenAI API Key", systemImage: "key.fill")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Required")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                        
                        Spacer()
                        
                        Button(showApiKey ? "Hide" : "Show") {
                            showApiKey.toggle()
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.blue)
                        .font(.caption)
                    }
                    
                    Group {
                        if showApiKey {
                            TextField("sk-...", text: $apiKey)
                        } else {
                            SecureField("sk-...", text: $apiKey)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .overlay(alignment: .trailing) {
                        ValidationIndicator(state: apiKeyValidation)
                            .padding(.trailing, 8)
                    }
                    
                    if !validationErrors.filter({ $0.field == .apiKey }).isEmpty {
                        ForEach(validationErrors.filter { $0.field == .apiKey }, id: \.id) { error in
                            Label(error.message, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    Text("Your API key will be stored securely in the macOS Keychain")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Base URL Field
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Base URL", systemImage: "link")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Optional")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(Capsule())
                        
                        Spacer()
                        
                        Button("Reset to Default") {
                            baseURL = "https://api.openai.com/v1"
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.blue)
                        .font(.caption)
                        .disabled(baseURL == "https://api.openai.com/v1")
                    }
                    
                    TextField("https://api.openai.com/v1", text: $baseURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .overlay(alignment: .trailing) {
                            ValidationIndicator(state: baseURLValidation)
                                .padding(.trailing, 8)
                        }
                    
                    if !validationErrors.filter({ $0.field == .baseURL }).isEmpty {
                        ForEach(validationErrors.filter { $0.field == .baseURL }, id: \.id) { error in
                            Label(error.message, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    Text("Use the default URL unless you have a custom OpenAI endpoint")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Organization ID Field
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Organization ID", systemImage: "building.2")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Optional")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(Capsule())
                        
                        Spacer()
                    }
                    
                    TextField("org-...", text: $organizationID)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    
                    Text("Only needed if you belong to multiple OpenAI organizations")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .opacity(animateForm ? 1.0 : 0.0)
        .offset(y: animateForm ? 0 : 20)
        .animation(.easeOut(duration: 0.6).delay(0.2), value: animateForm)
    }
    
    // MARK: - Connection Testing Section
    private var connectionTestingSection: some View {
        VStack(spacing: 20) {
            Text("Connection Testing")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                // Test Button
                Button(action: testConnection) {
                    HStack {
                        if isTestingConnection {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "network")
                                .font(.title3)
                        }
                        
                        Text(isTestingConnection ? "Testing Connection..." : "Test API Connection")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: canTestConnection ? [.purple, .blue] : [.gray, .gray],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: canTestConnection ? .purple.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(!canTestConnection || isTestingConnection)
                
                // Test Results
                if flowManager.apiConfigState.testStatus != .untested {
                    ConnectionTestResultView(
                        status: flowManager.apiConfigState.testStatus,
                        lastTested: flowManager.apiConfigState.lastTestedAt,
                        availableModels: flowManager.apiConfigState.availableModels
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Help Section
    private var helpSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                
                Text("Need Help Getting an API Key?")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                APIKeyStep(
                    number: "1",
                    title: "Visit OpenAI Platform",
                    description: "Go to platform.openai.com and sign in or create an account"
                )
                
                APIKeyStep(
                    number: "2",
                    title: "Navigate to API Keys",
                    description: "Click on your profile, then 'View API keys' or go directly to the API keys section"
                )
                
                APIKeyStep(
                    number: "3",
                    title: "Create New Key",
                    description: "Click 'Create new secret key', give it a name, and copy the generated key"
                )
                
                APIKeyStep(
                    number: "4",
                    title: "Add Billing Information",
                    description: "Ensure you have billing set up to use the API (required for most models)"
                )
            }
            
            HStack(spacing: 12) {
                Button("Open OpenAI Platform") {
                    if let url = URL(string: "https://platform.openai.com/api-keys") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                
                Button("Detailed Guide") {
                    showingAPIKeyGuide = true
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 16) {
            // Save Configuration
            Button(action: saveConfiguration) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                    
                    Text("Save Configuration")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSaveConfiguration ? Color.green : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: canSaveConfiguration ? .green.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(!canSaveConfiguration)
            
            // Navigation Buttons
            HStack(spacing: 20) {
                Button("Back") {
                    onBack()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                if flowManager.apiConfigState.isConfigured {
                    Button("Continue") {
                        onContinue()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Skip for Now") {
                        onSkip()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(.top, 16)
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(.windowBackgroundColor),
                Color.purple.opacity(0.02)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - API Key Guide Sheet
    private var apiKeyGuideSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Complete API Key Setup Guide")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    APIKeyGuideContent()
                    
                    Spacer(minLength: 32)
                }
                .padding()
            }
            .navigationTitle("API Key Guide")
            .navigationBarItems(
                trailing: Button("Done") {
                    showingAPIKeyGuide = false
                }
            )
        }
    }
    
    // MARK: - Computed Properties
    private var canTestConnection: Bool {
        return !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               apiKeyValidation == .valid &&
               baseURLValidation == .valid
    }
    
    private var canSaveConfiguration: Bool {
        return canTestConnection && flowManager.apiConfigState.testStatus == .success
    }
    
    // MARK: - Methods
    private func setupInitialState() {
        // Load existing configuration
        if let existingKey = flowManager.apiConfigState.apiKey {
            apiKey = existingKey
        }
        baseURL = flowManager.apiConfigState.baseURL
        organizationID = flowManager.apiConfigState.organizationID ?? ""
        
        // Validate initial values
        validateAPIKey(apiKey)
        validateBaseURL(baseURL)
    }
    
    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.8)) {
            animateForm = true
        }
    }
    
    private func validateAPIKey(_ key: String) {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Clear previous API key validation errors
        validationErrors.removeAll { $0.field == .apiKey }
        
        if trimmedKey.isEmpty {
            apiKeyValidation = .idle
        } else if configManager.validateAPIKeyFormat(trimmedKey) {
            apiKeyValidation = .valid
        } else {
            apiKeyValidation = .invalid
            validationErrors.append(ValidationError(
                field: .apiKey,
                message: "Invalid API key format. Keys should start with 'sk-' and be at least 10 characters long."
            ))
        }
        
        LogManager.shared.debug("APIKeySetupView", "API key validation: \(apiKeyValidation)")
    }
    
    private func validateBaseURL(_ url: String) {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Clear previous base URL validation errors
        validationErrors.removeAll { $0.field == .baseURL }
        
        if trimmedURL.isEmpty {
            baseURLValidation = .invalid
            validationErrors.append(ValidationError(
                field: .baseURL,
                message: "Base URL cannot be empty."
            ))
        } else if URL(string: trimmedURL) != nil {
            baseURLValidation = .valid
        } else {
            baseURLValidation = .invalid
            validationErrors.append(ValidationError(
                field: .baseURL,
                message: "Invalid URL format."
            ))
        }
        
        LogManager.shared.debug("APIKeySetupView", "Base URL validation: \(baseURLValidation)")
    }
    
    private func testConnection() {
        Task {
            isTestingConnection = true
            
            await flowManager.configureAPI(
                apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                baseURL: baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
                organizationID: organizationID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : organizationID.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            isTestingConnection = false
            
            LogManager.shared.info("APIKeySetupView", "API connection test completed: \(flowManager.apiConfigState.testStatus)")
        }
    }
    
    private func saveConfiguration() {
        guard canSaveConfiguration else { return }
        
        LogManager.shared.info("APIKeySetupView", "Saving API configuration")
        
        // Configuration is already saved by the flow manager during testing
        // Just log the successful save
        LogManager.shared.info("APIKeySetupView", "API configuration saved successfully")
    }
    
    // MARK: - Initialization
    public init(onContinue: @escaping () -> Void, onSkip: @escaping () -> Void, onBack: @escaping () -> Void) {
        self.onContinue = onContinue
        self.onSkip = onSkip
        self.onBack = onBack
    }
}

// MARK: - Supporting Data Types

private enum ValidationField {
    case apiKey
    case baseURL
    case organizationID
}

private enum ValidationState {
    case idle
    case valid
    case invalid
}

private struct ValidationError: Identifiable {
    let id = UUID()
    let field: ValidationField
    let message: String
}

// MARK: - Supporting Views

private struct ConfigurationStatusView: View {
    let isConfigured: Bool
    let testStatus: APITestStatus
    let lastTested: Date?
    
    var body: some View {
        HStack(spacing: 16) {
            // Status Icon
            Image(systemName: statusIcon)
                .font(.title3)
                .foregroundColor(statusColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(statusDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(statusColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(statusColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var statusIcon: String {
        if isConfigured {
            return "checkmark.circle.fill"
        } else {
            switch testStatus {
            case .untested:
                return "questionmark.circle"
            case .testing:
                return "arrow.clockwise"
            case .success:
                return "checkmark.circle.fill"
            default:
                return "xmark.circle.fill"
            }
        }
    }
    
    private var statusColor: Color {
        if isConfigured {
            return .green
        } else {
            return testStatus.statusColor
        }
    }
    
    private var statusTitle: String {
        if isConfigured {
            return "Configuration Complete"
        } else {
            return testStatus.displayText
        }
    }
    
    private var statusDescription: String {
        if isConfigured {
            return "API connection verified and ready to use"
        } else if let lastTested = lastTested {
            let formatter = RelativeDateTimeFormatter()
            return "Last tested \(formatter.localizedString(for: lastTested, relativeTo: Date()))"
        } else {
            return "Enter your API key above and test the connection"
        }
    }
}

private struct ValidationIndicator: View {
    let state: ValidationState
    
    var body: some View {
        Group {
            switch state {
            case .idle:
                EmptyView()
            case .valid:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .invalid:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .font(.caption)
    }
}

private struct ConnectionTestResultView: View {
    let status: APITestStatus
    let lastTested: Date?
    let availableModels: [OpenAIModelInfo]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: status.isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundColor(status.statusColor)
                
                Text(status.displayText)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let lastTested = lastTested {
                    Text(RelativeDateTimeFormatter().localizedString(for: lastTested, relativeTo: Date()))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if status == .success && !availableModels.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Available Models (\(availableModels.count))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(availableModels.prefix(6)) { model in
                            ModelBadge(model: model)
                        }
                        
                        if availableModels.count > 6 {
                            Text("+ \(availableModels.count - 6) more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(status.statusColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(status.statusColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

private struct ModelBadge: View {
    let model: OpenAIModelInfo
    
    var body: some View {
        HStack(spacing: 4) {
            if model.isRecommended {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundColor(.yellow)
            }
            
            Text(model.name)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(.primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.controlBackgroundColor))
        )
    }
}

private struct APIKeyStep: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Step Number
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 24, height: 24)
                
                Text(number)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct APIKeyGuideContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            APIKeyGuideSection(
                title: "Getting Your OpenAI API Key",
                icon: "key.fill",
                content: [
                    "Visit platform.openai.com and sign in to your account",
                    "Navigate to the API keys section in your account settings",
                    "Click 'Create new secret key' and give it a descriptive name",
                    "Copy the generated key immediately (you won't be able to see it again)",
                    "Store the key securely - HelloPrompt will encrypt it in your Keychain"
                ]
            )
            
            APIKeyGuideSection(
                title: "Setting Up Billing",
                icon: "creditcard.fill",
                content: [
                    "Go to the Billing section in your OpenAI account",
                    "Add a payment method (credit card or other supported method)",
                    "Set up usage limits to control your spending",
                    "Monitor your usage regularly to avoid unexpected charges",
                    "Most models require billing to be set up, even for small usage"
                ]
            )
            
            APIKeyGuideSection(
                title: "Understanding API Costs",
                icon: "chart.line.uptrend.xyaxis",
                content: [
                    "OpenAI charges based on token usage (input + output tokens)",
                    "GPT-4 models are more expensive but provide better quality",
                    "GPT-3.5 models are cheaper and faster for simpler tasks",
                    "Speech-to-text (Whisper) has separate, typically lower costs",
                    "Set usage alerts to monitor your spending"
                ]
            )
            
            APIKeyGuideSection(
                title: "Security Best Practices",
                icon: "shield.checkered",
                content: [
                    "Never share your API key with others",
                    "Don't commit API keys to version control systems",
                    "Use different keys for different applications if needed",
                    "Regularly rotate your API keys for security",
                    "Monitor usage for any unexpected activity"
                ]
            )
        }
    }
}

private struct APIKeyGuideSection: View {
    let title: String
    let icon: String
    let content: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(content.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .frame(minWidth: 20, alignment: .leading)
                        
                        Text(item)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
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
struct APIKeySetupView_Previews: PreviewProvider {
    static var previews: some View {
        APIKeySetupView(
            onContinue: { print("Continue") },
            onSkip: { print("Skip") },
            onBack: { print("Back") }
        )
        .frame(width: 800, height: 1200)
        .previewDisplayName("API Key Setup")
    }
}
#endif