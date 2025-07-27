//
//  OnboardingFlowManager.swift
//  HelloPrompt
//
//  Comprehensive onboarding flow manager for HelloPrompt
//  Manages the entire onboarding experience with state management, logging, and error handling
//

import SwiftUI
import Combine
import AVFoundation

// MARK: - Onboarding Flow Manager
@MainActor
public class OnboardingFlowManager: ObservableObject {
    public static let shared = OnboardingFlowManager()
    
    // MARK: - Published Properties
    @Published public private(set) var currentStep: OnboardingStepType = .startupIntroduction
    @Published public private(set) var progress: OnboardingProgress?
    @Published public private(set) var isActive: Bool = false
    @Published public private(set) var canProceed: Bool = true
    @Published public private(set) var isLoading: Bool = false
    
    // Step-specific states
    @Published public var permissionState: PermissionSetupState = PermissionSetupState()
    @Published public var apiConfigState: APIConfigurationState = APIConfigurationState()
    @Published public var modelTestingState: ModelTestingState = ModelTestingState()
    
    // Error handling
    @Published public private(set) var currentError: OnboardingError?
    @Published public private(set) var hasError: Bool = false
    
    // Analytics and timing
    @Published public private(set) var stepStartTime: Date = Date()
    @Published public private(set) var totalElapsedTime: TimeInterval = 0
    
    // MARK: - Dependencies
    private let storageService = OnboardingStorageService.shared
    private let permissionManager = PermissionManager.shared
    private let configManager = AppConfigManager.shared
    private let openAIService = OpenAIService()
    private let logManager = LogManager.shared
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var stepTimer: Timer?
    private var sessionStartTime: Date?
    
    // MARK: - Callbacks
    public var onStepChanged: ((OnboardingStepType) -> Void)?
    public var onCompleted: ((OnboardingCompletionState) -> Void)?
    public var onSkipped: (() -> Void)?
    public var onError: ((OnboardingError) -> Void)?
    
    // MARK: - Initialization
    private init() {
        setupObservers()
        loadExistingState()
        logManager.info("OnboardingFlowManager", "Onboarding flow manager initialized")
    }
    
    // MARK: - Public Interface
    
    /// Start the onboarding flow
    public func startOnboarding() {
        guard !isActive else {
            logManager.warning("OnboardingFlowManager", "Onboarding already active")
            return
        }
        
        logManager.info("OnboardingFlowManager", "🚀 Starting onboarding flow")
        
        isActive = true
        sessionStartTime = Date()
        stepStartTime = Date()
        
        // Initialize storage session
        storageService.startOnboardingSession()
        
        // Reset state
        currentStep = .startupIntroduction
        clearError()
        
        // Load existing progress or create new
        if let existingProgress = storageService.currentProgress {
            progress = existingProgress
            currentStep = existingProgress.currentStep
        } else {
            progress = OnboardingProgress(currentStep: .startupIntroduction)
        }
        
        // Start step timer
        startStepTimer()
        
        // Validate initial step
        validateCurrentStep()
        
        logManager.info("OnboardingFlowManager", "Onboarding flow started at step: \(currentStep.title)")
    }
    
    /// Stop the onboarding flow
    public func stopOnboarding() {
        logManager.info("OnboardingFlowManager", "🛑 Stopping onboarding flow")
        
        isActive = false
        stopStepTimer()
        
        // Save current state
        if let progress = progress {
            storageService.updateProgress(progress)
        }
        
        recordStepTime()
        
        logManager.info("OnboardingFlowManager", "Onboarding flow stopped")
    }
    
    /// Move to next step
    public func nextStep() {
        guard canProceed else {
            logManager.warning("OnboardingFlowManager", "Cannot proceed to next step")
            return
        }
        
        recordStepTime()
        
        let allSteps = OnboardingStepType.allCases
        guard let currentIndex = allSteps.firstIndex(of: currentStep),
              currentIndex + 1 < allSteps.count else {
            // Reached the end, complete onboarding
            completeOnboarding()
            return
        }
        
        let nextStep = allSteps[currentIndex + 1]
        moveToStep(nextStep)
    }
    
    /// Move to previous step
    public func previousStep() {
        recordStepTime()
        
        let allSteps = OnboardingStepType.allCases
        guard let currentIndex = allSteps.firstIndex(of: currentStep),
              currentIndex > 0 else {
            logManager.warning("OnboardingFlowManager", "Already at first step")
            return
        }
        
        let previousStep = allSteps[currentIndex - 1]
        moveToStep(previousStep)
    }
    
    /// Move to specific step
    public func moveToStep(_ step: OnboardingStepType) {
        logManager.info("OnboardingFlowManager", "Moving to step: \(step.title)")
        
        // Record step completion if moving forward
        if step.rawValue > currentStep.rawValue {
            markCurrentStepCompleted()
        }
        
        currentStep = step
        stepStartTime = Date()
        clearError()
        
        // Update progress
        updateProgress()
        
        // Validate step
        validateCurrentStep()
        
        // Notify observers
        onStepChanged?(step)
        
        // Record analytics
        storageService.recordUserInteraction(.stepEntered, step: step)
        
        logManager.info("OnboardingFlowManager", "Moved to step: \(step.title)")
    }
    
    /// Skip current step
    public func skipCurrentStep() {
        logManager.info("OnboardingFlowManager", "Skipping step: \(currentStep.title)")
        
        guard currentStep.isOptional else {
            logManager.warning("OnboardingFlowManager", "Cannot skip required step: \(currentStep.title)")
            return
        }
        
        // Mark as skipped
        storageService.markStepSkipped(currentStep)
        
        // Move to next step
        nextStep()
    }
    
    /// Complete the onboarding
    public func completeOnboarding() {
        logManager.info("OnboardingFlowManager", "🎉 Completing onboarding flow")
        
        recordStepTime()
        markCurrentStepCompleted()
        
        let completionState = createCompletionState()
        
        // Save completion
        storageService.completeOnboarding(with: completionState)
        
        // Stop the flow
        isActive = false
        stopStepTimer()
        
        // Notify completion
        onCompleted?(completionState)
        
        logManager.info("OnboardingFlowManager", "Onboarding completed successfully")
    }
    
    /// Skip the entire onboarding
    public func skipOnboarding(permanent: Bool = false) {
        logManager.info("OnboardingFlowManager", "Skipping onboarding - Permanent: \(permanent)")
        
        storageService.skipOnboarding(permanent: permanent)
        
        isActive = false
        stopStepTimer()
        
        onSkipped?()
        
        logManager.info("OnboardingFlowManager", "Onboarding skipped")
    }
    
    // MARK: - Step-Specific Actions
    
    /// Handle startup introduction completion
    public func completeStartupIntroduction() {
        logManager.info("OnboardingFlowManager", "Completing startup introduction")
        nextStep()
    }
    
    /// Request permissions for the permission configuration step
    public func requestPermissions() async {
        logManager.info("OnboardingFlowManager", "Requesting permissions")
        
        isLoading = true
        clearError()
        
        do {
            // Request microphone permission
            let micStatus = await permissionManager.requestPermission(.microphone)
            
            // Request accessibility permission (this will guide user to system preferences)
            let accessibilityStatus = await permissionManager.requestPermission(.accessibility)
            
            // Request notification permission
            let notificationStatus = await permissionManager.requestPermission(.notification)
            
            // Update permission state
            permissionState = PermissionSetupState(
                microphoneStatus: micStatus,
                accessibilityStatus: accessibilityStatus,
                notificationStatus: notificationStatus,
                lastCheckedAt: Date(),
                setupAttempts: permissionState.setupAttempts + 1
            )
            
            // Save preferences
            storageService.savePermissionPreferences(permissionState)
            
            isLoading = false
            validateCurrentStep()
            
            logManager.info("OnboardingFlowManager", "Permission request completed")
            
        } catch {
            let onboardingError = OnboardingError(
                step: .permissionConfiguration,
                errorType: .permissionDenied,
                message: "Failed to request permissions: \(error.localizedDescription)"
            )
            handleError(onboardingError)
        }
    }
    
    /// Configure API settings
    public func configureAPI(apiKey: String, baseURL: String, organizationID: String? = nil) async {
        logManager.info("OnboardingFlowManager", "Configuring API settings")
        
        isLoading = true
        clearError()
        
        // Validate API key format
        guard configManager.validateAPIKeyFormat(apiKey) else {
            let error = OnboardingError(
                step: .apiKeySetup,
                errorType: .invalidApiKey,
                message: "Invalid API key format"
            )
            handleError(error)
            return
        }
        
        // Update API configuration state
        apiConfigState = APIConfigurationState(
            apiKey: apiKey,
            baseURL: baseURL,
            organizationID: organizationID,
            selectedModel: apiConfigState.selectedModel,
            testStatus: .testing,
            availableModels: apiConfigState.availableModels,
            lastTestedAt: nil,
            configurationAttempts: apiConfigState.configurationAttempts + 1
        )
        
        do {
            // Save API configuration
            try configManager.setOpenAIAPIKey(apiKey)
            configManager.openAIBaseURL = baseURL
            configManager.openAIOrganization = organizationID
            
            // Test API connection
            let testResult = await configManager.testAPIConnection()
            
            switch testResult {
            case .success:
                apiConfigState = APIConfigurationState(
                    apiKey: apiKey,
                    baseURL: baseURL,
                    organizationID: organizationID,
                    selectedModel: apiConfigState.selectedModel,
                    testStatus: .success,
                    availableModels: apiConfigState.availableModels,
                    lastTestedAt: Date(),
                    configurationAttempts: apiConfigState.configurationAttempts
                )
                
                // Load available models
                await loadAvailableModels()
                
            case .failure(let error):
                let errorType: OnboardingErrorType
                if error.localizedDescription.contains("authentication") {
                    errorType = .invalidApiKey
                } else if error.localizedDescription.contains("network") {
                    errorType = .networkError
                } else {
                    errorType = .apiConnectionFailed
                }
                
                apiConfigState = APIConfigurationState(
                    apiKey: apiKey,
                    baseURL: baseURL,
                    organizationID: organizationID,
                    selectedModel: apiConfigState.selectedModel,
                    testStatus: .failure,
                    availableModels: apiConfigState.availableModels,
                    lastTestedAt: Date(),
                    configurationAttempts: apiConfigState.configurationAttempts
                )
                
                let onboardingError = OnboardingError(
                    step: .apiKeySetup,
                    errorType: errorType,
                    message: "API connection failed: \(error.localizedDescription)",
                    underlyingError: error.localizedDescription
                )
                handleError(onboardingError)
            }
            
        } catch {
            let onboardingError = OnboardingError(
                step: .apiKeySetup,
                errorType: .configurationSaveFailed,
                message: "Failed to save API configuration: \(error.localizedDescription)"
            )
            handleError(onboardingError)
        }
        
        isLoading = false
        validateCurrentStep()
        
        logManager.info("OnboardingFlowManager", "API configuration completed")
    }
    
    /// Test a specific model
    public func testModel(_ modelId: String) async {
        logManager.info("OnboardingFlowManager", "Testing model: \(modelId)")
        
        isLoading = true
        clearError()
        
        modelTestingState = ModelTestingState(
            selectedModel: modelId,
            testStatus: .testing,
            testResults: modelTestingState.testResults,
            lastTestedAt: nil,
            testAttempts: modelTestingState.testAttempts + 1
        )
        
        do {
            // Configure OpenAI service with the model
            openAIService.configure(
                apiKey: apiConfigState.apiKey ?? "",
                baseURL: apiConfigState.baseURL
            )
            
            let startTime = Date()
            let testPrompt = "Hello! Please respond with a brief greeting to test the connection."
            
            // Test the model
            let response = try await openAIService.optimizePrompt(testPrompt)
            let endTime = Date()
            
            let testResults = ModelTestResults(
                modelId: modelId,
                responseTime: endTime.timeIntervalSince(startTime),
                tokensUsed: response.count / 4, // Rough estimate
                cost: nil, // Could calculate if pricing info available
                testPrompt: testPrompt,
                testResponse: response,
                testedAt: endTime
            )
            
            modelTestingState = ModelTestingState(
                selectedModel: modelId,
                testStatus: .success,
                testResults: testResults,
                lastTestedAt: Date(),
                testAttempts: modelTestingState.testAttempts
            )
            
            // Update API config with selected model
            configManager.openAIModel = modelId
            
            logManager.info("OnboardingFlowManager", "Model test successful: \(modelId)")
            
        } catch {
            modelTestingState = ModelTestingState(
                selectedModel: modelId,
                testStatus: .failure,
                testResults: modelTestingState.testResults,
                lastTestedAt: Date(),
                testAttempts: modelTestingState.testAttempts
            )
            
            let onboardingError = OnboardingError(
                step: .modelTesting,
                errorType: .modelTestFailed,
                message: "Model test failed: \(error.localizedDescription)",
                underlyingError: error.localizedDescription
            )
            handleError(onboardingError)
        }
        
        isLoading = false
        validateCurrentStep()
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe permission changes
        permissionManager.$permissionStates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] states in
                self?.updatePermissionState(from: states)
            }
            .store(in: &cancellables)
        
        // Observe configuration changes
        configManager.$configurationValid
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isValid in
                if isValid {
                    self?.validateCurrentStep()
                }
            }
            .store(in: &cancellables)
        
        logManager.debug("OnboardingFlowManager", "Observers set up")
    }
    
    private func loadExistingState() {
        // Load any existing progress
        if let existingProgress = storageService.currentProgress {
            progress = existingProgress
            currentStep = existingProgress.currentStep
        }
        
        // Load permission state
        updatePermissionStateFromManager()
        
        // Load API configuration
        loadAPIConfigurationFromManager()
        
        logManager.debug("OnboardingFlowManager", "Existing state loaded")
    }
    
    private func updatePermissionState(from states: [PermissionType: PermissionState]) {
        let micStatus = states[.microphone]?.status ?? .unknown
        let accessibilityStatus = states[.accessibility]?.status ?? .unknown
        let notificationStatus = states[.notification]?.status ?? .unknown
        
        permissionState = PermissionSetupState(
            microphoneStatus: micStatus,
            accessibilityStatus: accessibilityStatus,
            notificationStatus: notificationStatus,
            lastCheckedAt: Date(),
            setupAttempts: permissionState.setupAttempts
        )
        
        if currentStep == .permissionConfiguration {
            validateCurrentStep()
        }
    }
    
    private func updatePermissionStateFromManager() {
        let micStatus = permissionManager.getPermissionStatus(.microphone)
        let accessibilityStatus = permissionManager.getPermissionStatus(.accessibility)
        let notificationStatus = permissionManager.getPermissionStatus(.notification)
        
        permissionState = PermissionSetupState(
            microphoneStatus: micStatus,
            accessibilityStatus: accessibilityStatus,
            notificationStatus: notificationStatus,
            lastCheckedAt: Date(),
            setupAttempts: 0
        )
    }
    
    private func loadAPIConfigurationFromManager() {
        let apiKey = try? configManager.getOpenAIAPIKey()
        
        apiConfigState = APIConfigurationState(
            apiKey: apiKey,
            baseURL: configManager.openAIBaseURL,
            organizationID: configManager.openAIOrganization,
            selectedModel: configManager.openAIModel,
            testStatus: apiKey != nil ? .success : .untested,
            availableModels: [],
            lastTestedAt: nil,
            configurationAttempts: 0
        )
    }
    
    private func loadAvailableModels() async {
        do {
            // This would load actual models from OpenAI
            // For now, provide common models
            let models = getCommonModels()
            
            apiConfigState = APIConfigurationState(
                apiKey: apiConfigState.apiKey,
                baseURL: apiConfigState.baseURL,
                organizationID: apiConfigState.organizationID,
                selectedModel: apiConfigState.selectedModel,
                testStatus: apiConfigState.testStatus,
                availableModels: models,
                lastTestedAt: apiConfigState.lastTestedAt,
                configurationAttempts: apiConfigState.configurationAttempts
            )
            
            logManager.info("OnboardingFlowManager", "Loaded \(models.count) available models")
            
        } catch {
            logManager.error("OnboardingFlowManager", "Failed to load available models: \(error)")
        }
    }
    
    private func getCommonModels() -> [OpenAIModelInfo] {
        return [
            OpenAIModelInfo(
                id: "gpt-4",
                name: "GPT-4",
                description: "Most capable model, best for complex tasks",
                contextLength: 8192,
                pricing: ModelPricing(inputTokenPrice: 0.03, outputTokenPrice: 0.06),
                capabilities: ModelCapabilities(supportsChat: true, supportsFunctionCalling: true),
                isRecommended: true,
                category: .chat
            ),
            OpenAIModelInfo(
                id: "gpt-4-turbo-preview",
                name: "GPT-4 Turbo",
                description: "Latest GPT-4 model with improved performance",
                contextLength: 128000,
                pricing: ModelPricing(inputTokenPrice: 0.01, outputTokenPrice: 0.03),
                capabilities: ModelCapabilities(supportsChat: true, supportsFunctionCalling: true),
                isRecommended: true,
                category: .chat
            ),
            OpenAIModelInfo(
                id: "gpt-3.5-turbo",
                name: "GPT-3.5 Turbo",
                description: "Fast and efficient model for most tasks",
                contextLength: 4096,
                pricing: ModelPricing(inputTokenPrice: 0.0015, outputTokenPrice: 0.002),
                capabilities: ModelCapabilities(supportsChat: true, supportsFunctionCalling: true),
                isRecommended: false,
                category: .chat
            )
        ]
    }
    
    private func validateCurrentStep() {
        switch currentStep {
        case .startupIntroduction:
            canProceed = true
            
        case .permissionConfiguration:
            // Can proceed if core permissions are granted or user chooses to skip
            canProceed = permissionState.corePermissionsGranted || currentStep.isOptional
            
        case .apiKeySetup:
            // Can proceed if API is configured or user chooses to skip
            canProceed = apiConfigState.isConfigured || currentStep.isOptional
            
        case .modelTesting:
            // Can proceed if model is tested or user chooses to skip
            canProceed = modelTestingState.isConfigured || currentStep.isOptional
            
        case .completionScreen:
            canProceed = true
        }
        
        logManager.debug("OnboardingFlowManager", "Step validation: \(currentStep.title) - Can proceed: \(canProceed)")
    }
    
    private func updateProgress() {
        guard var currentProgress = progress else { return }
        
        currentProgress = OnboardingProgress(
            currentStep: currentStep,
            completedSteps: currentProgress.completedSteps,
            skippedSteps: currentProgress.skippedSteps,
            startedAt: currentProgress.startedAt,
            lastUpdatedAt: Date(),
            estimatedTimeRemaining: calculateEstimatedTimeRemaining()
        )
        
        progress = currentProgress
        storageService.updateProgress(currentProgress)
    }
    
    private func calculateEstimatedTimeRemaining() -> TimeInterval {
        let allSteps = OnboardingStepType.allCases
        guard let currentIndex = allSteps.firstIndex(of: currentStep) else { return 0 }
        
        let remainingSteps = allSteps.dropFirst(currentIndex + 1)
        let totalMinutes = remainingSteps.reduce(0) { $0 + $1.estimatedDurationMinutes }
        
        return TimeInterval(totalMinutes * 60)
    }
    
    private func markCurrentStepCompleted() {
        storageService.markStepCompleted(currentStep)
        
        // Update progress
        if var currentProgress = progress {
            var completedSteps = currentProgress.completedSteps
            completedSteps.insert(currentStep)
            
            currentProgress = OnboardingProgress(
                currentStep: currentProgress.currentStep,
                completedSteps: completedSteps,
                skippedSteps: currentProgress.skippedSteps,
                startedAt: currentProgress.startedAt,
                lastUpdatedAt: Date(),
                estimatedTimeRemaining: currentProgress.estimatedTimeRemaining
            )
            
            progress = currentProgress
        }
        
        logManager.info("OnboardingFlowManager", "Marked step as completed: \(currentStep.title)")
    }
    
    private func createCompletionState() -> OnboardingCompletionState {
        let summary = ConfigurationSummary(
            permissionsGranted: getGrantedPermissions(),
            apiConfigured: apiConfigState.isConfigured,
            modelSelected: modelTestingState.selectedModel,
            optionalStepsCompleted: getOptionalStepsCompleted(),
            totalSetupTime: Date().timeIntervalSince(sessionStartTime ?? Date())
        )
        
        let nextSteps = generateNextSteps(for: summary)
        
        return OnboardingCompletionState(
            completedAt: Date(),
            configurationSummary: summary,
            userFeedback: nil,
            nextSteps: nextSteps,
            version: "2.0.0"
        )
    }
    
    private func getGrantedPermissions() -> [PermissionType] {
        var granted: [PermissionType] = []
        
        if permissionState.microphoneStatus == .granted {
            granted.append(.microphone)
        }
        if permissionState.accessibilityStatus == .granted {
            granted.append(.accessibility)
        }
        if permissionState.notificationStatus == .granted {
            granted.append(.notification)
        }
        
        return granted
    }
    
    private func getOptionalStepsCompleted() -> Int {
        guard let progress = progress else { return 0 }
        
        let optionalSteps: [OnboardingStepType] = [.permissionConfiguration, .apiKeySetup, .modelTesting]
        return optionalSteps.filter { progress.completedSteps.contains($0) }.count
    }
    
    private func generateNextSteps(for summary: ConfigurationSummary) -> [NextStep] {
        var nextSteps: [NextStep] = []
        
        // Always suggest testing the main feature
        nextSteps.append(NextStep(
            title: "Test Voice Recording",
            description: "Try using Ctrl+U to test voice recording and prompt optimization",
            actionType: .testFeature,
            priority: .high,
            iconName: "mic.circle.fill"
        ))
        
        // Suggest permission setup if missing
        if summary.permissionsGranted.count < 3 {
            nextSteps.append(NextStep(
                title: "Complete Permission Setup",
                description: "Grant remaining permissions for full functionality",
                actionType: .openSettings,
                priority: .medium,
                iconName: "lock.shield.fill"
            ))
        }
        
        // Suggest API configuration if missing
        if !summary.apiConfigured {
            nextSteps.append(NextStep(
                title: "Configure API Settings",
                description: "Set up your OpenAI API key for AI features",
                actionType: .openSettings,
                priority: .high,
                iconName: "key.fill"
            ))
        }
        
        // Suggest shortcut customization
        nextSteps.append(NextStep(
            title: "Customize Shortcuts",
            description: "Configure keyboard shortcuts to match your workflow",
            actionType: .configureShortcuts,
            priority: .low,
            iconName: "keyboard"
        ))
        
        return nextSteps
    }
    
    private func startStepTimer() {
        stepTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.totalElapsedTime = Date().timeIntervalSince(self.sessionStartTime ?? Date())
            }
        }
    }
    
    private func stopStepTimer() {
        stepTimer?.invalidate()
        stepTimer = nil
    }
    
    private func recordStepTime() {
        let timeSpent = Date().timeIntervalSince(stepStartTime)
        storageService.updateStepTime(currentStep, timeSpent: timeSpent)
        
        logManager.debug("OnboardingFlowManager", "Step \(currentStep.title) took \(timeSpent) seconds")
    }
    
    private func handleError(_ error: OnboardingError) {
        currentError = error
        hasError = true
        isLoading = false
        
        storageService.recordError(error)
        onError?(error)
        
        logManager.error("OnboardingFlowManager", "Onboarding error: \(error.message)")
    }
    
    private func clearError() {
        currentError = nil
        hasError = false
    }
    
    // MARK: - Public Utility Methods
    
    /// Get progress percentage (0.0 to 1.0)
    public var progressPercentage: Double {
        return progress?.progressPercentage ?? 0.0
    }
    
    /// Get estimated time remaining in minutes
    public var estimatedTimeRemainingMinutes: Int {
        let seconds = progress?.estimatedTimeRemaining ?? 0
        return Int(seconds / 60)
    }
    
    /// Check if a specific step is accessible
    public func isStepAccessible(_ step: OnboardingStepType) -> Bool {
        return progress?.isStepAccessible(step) ?? (step == .startupIntroduction)
    }
    
    /// Check if a specific step is completed
    public func isStepCompleted(_ step: OnboardingStepType) -> Bool {
        return progress?.isStepCompleted(step) ?? false
    }
    
    /// Check if a specific step is skipped
    public func isStepSkipped(_ step: OnboardingStepType) -> Bool {
        return progress?.isStepSkipped(step) ?? false
    }
    
    /// Reset the onboarding flow (for testing)
    public func resetOnboarding() {
        logManager.info("OnboardingFlowManager", "Resetting onboarding flow")
        
        isActive = false
        currentStep = .startupIntroduction
        progress = nil
        clearError()
        
        permissionState = PermissionSetupState()
        apiConfigState = APIConfigurationState()
        modelTestingState = ModelTestingState()
        
        storageService.resetOnboarding()
        
        stopStepTimer()
        sessionStartTime = nil
        
        logManager.info("OnboardingFlowManager", "Onboarding flow reset completed")
    }
}