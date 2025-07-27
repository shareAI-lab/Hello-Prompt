//
//  OnboardingCoordinator.swift
//  HelloPrompt
//
//  Centralized coordinator for managing the complete onboarding experience
//  Integrates with existing flow manager and provides enhanced coordination
//

import SwiftUI
import Combine
import Foundation

// MARK: - Onboarding Coordinator

@MainActor
public class OnboardingCoordinator: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = OnboardingCoordinator()
    
    // MARK: - Published Properties
    @Published public var isOnboardingActive: Bool = false
    @Published public var currentPhase: OnboardingPhase = .notStarted
    @Published public var completionPercentage: Double = 0.0
    @Published public var canContinueToMainApp: Bool = false
    @Published public var hasError: Bool = false
    @Published public var currentError: OnboardingError?
    
    // MARK: - Dependencies
    private let flowManager = OnboardingFlowManager.shared
    private let storageService = OnboardingStorageService.shared
    private let permissionManager = PermissionManager.shared
    private let configManager = AppConfigManager.shared
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var onboardingStartTime: Date?
    private var phaseCompletionTimes: [OnboardingPhase: TimeInterval] = [:]
    
    // MARK: - Callbacks
    public var onOnboardingCompleted: ((OnboardingCompletionState) -> Void)?
    public var onOnboardingSkipped: (() -> Void)?
    public var onPhaseChanged: ((OnboardingPhase) -> Void)?
    public var onErrorOccurred: ((OnboardingError) -> Void)?
    
    // MARK: - Initialization
    private init() {
        setupObservers()
        checkInitialState()
        LogManager.shared.info("OnboardingCoordinator", "Onboarding coordinator initialized")
    }
    
    // MARK: - Public Methods
    
    /// Determines if onboarding should be shown based on various conditions
    public func shouldShowOnboarding() -> Bool {
        // Check if onboarding has been completed
        if storageService.isOnboardingCompleted {
            LogManager.shared.info("OnboardingCoordinator", "Onboarding already completed")
            return false
        }
        
        // Check if user has explicitly skipped onboarding permanently
        if storageService.isOnboardingSkippedPermanently {
            LogManager.shared.info("OnboardingCoordinator", "Onboarding permanently skipped")
            return false
        }
        
        // Check if this is a fresh installation
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "HasLaunchedBefore")
        if isFirstLaunch {
            LogManager.shared.info("OnboardingCoordinator", "First launch detected - showing onboarding")
            return true
        }
        
        // Check if critical components are missing configuration
        if hasCriticalConfigurationMissing() {
            LogManager.shared.info("OnboardingCoordinator", "Critical configuration missing - showing onboarding")
            return true
        }
        
        // Check if user has requested to restart onboarding
        if storageService.shouldRestartOnboarding {
            LogManager.shared.info("OnboardingCoordinator", "Restart requested - showing onboarding")
            return true
        }
        
        return false
    }
    
    /// Starts the complete onboarding process
    public func startOnboarding() {
        guard !isOnboardingActive else {
            LogManager.shared.warning("OnboardingCoordinator", "Onboarding already active")
            return
        }
        
        LogManager.shared.info("OnboardingCoordinator", "Starting onboarding process")
        
        onboardingStartTime = Date()
        isOnboardingActive = true
        currentPhase = .introduction
        hasError = false
        currentError = nil
        
        // Mark first launch
        UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
        
        // Reset any previous skip states
        storageService.resetOnboardingSkipState()
        
        // Start the flow manager
        flowManager.startOnboarding()
        
        // Notify observers
        onPhaseChanged?(.introduction)
        
        // Track analytics
        trackOnboardingEvent("onboarding_started")
    }
    
    /// Completes the onboarding process successfully
    public func completeOnboarding() {
        guard isOnboardingActive else {
            LogManager.shared.warning("OnboardingCoordinator", "Cannot complete - onboarding not active")
            return
        }
        
        LogManager.shared.info("OnboardingCoordinator", "Completing onboarding process")
        
        // Calculate completion metrics
        let completionState = generateCompletionState()
        
        // Mark as completed in storage
        storageService.completeOnboarding(
            withConfiguration: completionState.configurationSummary,
            nextSteps: completionState.nextSteps
        )
        
        // Update state
        isOnboardingActive = false
        currentPhase = .completed
        completionPercentage = 1.0
        canContinueToMainApp = true
        
        // Complete flow manager
        flowManager.completeOnboarding()
        
        // Track completion
        trackOnboardingEvent("onboarding_completed", properties: [
            "setup_time": getTotalSetupTime(),
            "permissions_granted": getGrantedPermissionsCount(),
            "api_configured": configManager.hasValidOpenAIKey,
            "quality_score": completionState.configurationSummary.setupQuality.rawValue
        ])
        
        // Notify completion
        onOnboardingCompleted?(completionState)
        
        LogManager.shared.info("OnboardingCoordinator", "Onboarding completed successfully")
    }
    
    /// Skips the onboarding process
    public func skipOnboarding(permanent: Bool = false) {
        LogManager.shared.info("OnboardingCoordinator", "Skipping onboarding (permanent: \(permanent))")
        
        // Update storage
        if permanent {
            storageService.skipOnboarding(permanent: true)
        } else {
            storageService.saveOnboardingProgress(flowManager.progress)
        }
        
        // Update state
        isOnboardingActive = false
        currentPhase = .skipped
        canContinueToMainApp = true
        
        // Track skip
        trackOnboardingEvent("onboarding_skipped", properties: [
            "permanent": permanent,
            "current_step": flowManager.currentStep.rawValue,
            "completion_percentage": completionPercentage
        ])
        
        // Notify skip
        onOnboardingSkipped?()
    }
    
    /// Resets the onboarding state to allow restart
    public func resetOnboarding() {
        LogManager.shared.info("OnboardingCoordinator", "Resetting onboarding state")
        
        // Reset storage
        storageService.resetOnboarding()
        
        // Reset flow manager
        flowManager.resetOnboarding()
        
        // Reset coordinator state
        isOnboardingActive = false
        currentPhase = .notStarted
        completionPercentage = 0.0
        canContinueToMainApp = false
        hasError = false
        currentError = nil
        
        // Reset timing data
        onboardingStartTime = nil
        phaseCompletionTimes.removeAll()
        
        trackOnboardingEvent("onboarding_reset")
    }
    
    /// Handles errors during onboarding
    public func handleError(_ error: OnboardingError) {
        LogManager.shared.error("OnboardingCoordinator", "Onboarding error: \(error.localizedDescription)")
        
        hasError = true
        currentError = error
        
        // Track error
        trackOnboardingEvent("onboarding_error", properties: [
            "error_code": error.code,
            "error_message": error.localizedDescription,
            "current_phase": currentPhase.rawValue,
            "current_step": flowManager.currentStep.rawValue
        ])
        
        // Notify error
        onErrorOccurred?(error)
        
        // Attempt recovery based on error type
        attemptErrorRecovery(error)
    }
    
    /// Clears current error state
    public func clearError() {
        hasError = false
        currentError = nil
        LogManager.shared.info("OnboardingCoordinator", "Error state cleared")
    }
    
    /// Gets current onboarding progress information
    public func getCurrentProgress() -> OnboardingProgressInfo {
        return OnboardingProgressInfo(
            phase: currentPhase,
            currentStep: flowManager.currentStep,
            completionPercentage: completionPercentage,
            canProceed: flowManager.canProceed,
            estimatedTimeRemaining: flowManager.estimatedTimeRemainingMinutes,
            setupTime: getTotalSetupTime(),
            errors: currentError != nil ? [currentError!] : []
        )
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe flow manager changes
        flowManager.$currentStep
            .sink { [weak self] step in
                self?.updatePhaseFromStep(step)
            }
            .store(in: &cancellables)
        
        flowManager.$progress
            .sink { [weak self] progress in
                self?.updateCompletionPercentage(progress)
            }
            .store(in: &cancellables)
        
        flowManager.$currentError
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.handleError(OnboardingError.flowManagerError(error))
            }
            .store(in: &cancellables)
        
        // Observe permission changes
        permissionManager.$permissionStates
            .sink { [weak self] _ in
                self?.updateCanContinue()
            }
            .store(in: &cancellables)
        
        // Observe config changes
        configManager.$hasValidOpenAIKey
            .sink { [weak self] _ in
                self?.updateCanContinue()
            }
            .store(in: &cancellables)
    }
    
    private func checkInitialState() {
        // Check if we're in the middle of onboarding
        if let savedProgress = storageService.getSavedProgress(),
           !storageService.isOnboardingCompleted {
            
            LogManager.shared.info("OnboardingCoordinator", "Resuming onboarding from saved progress")
            
            isOnboardingActive = true
            flowManager.resumeFromProgress(savedProgress)
            updatePhaseFromStep(flowManager.currentStep)
            updateCompletionPercentage(savedProgress)
        }
        
        updateCanContinue()
    }
    
    private func updatePhaseFromStep(_ step: OnboardingStepType) {
        let newPhase: OnboardingPhase
        
        switch step {
        case .startupIntroduction:
            newPhase = .introduction
        case .permissionConfiguration:
            newPhase = .permissions
        case .apiKeySetup:
            newPhase = .apiConfiguration
        case .modelTesting:
            newPhase = .modelTesting
        case .completionScreen:
            newPhase = .completion
        }
        
        if newPhase != currentPhase {
            // Record completion time for previous phase
            if let startTime = onboardingStartTime {
                phaseCompletionTimes[currentPhase] = Date().timeIntervalSince(startTime)
            }
            
            currentPhase = newPhase
            onPhaseChanged?(newPhase)
            
            LogManager.shared.info("OnboardingCoordinator", "Phase changed to: \(newPhase.rawValue)")
        }
    }
    
    private func updateCompletionPercentage(_ progress: OnboardingProgress?) {
        guard let progress = progress else {
            completionPercentage = 0.0
            return
        }
        
        let totalSteps = Double(OnboardingStepType.allCases.count)
        let completedSteps = Double(progress.completedSteps.count)
        let currentStepProgress = Double(flowManager.currentStep.rawValue) / totalSteps
        
        completionPercentage = max(completedSteps / totalSteps, currentStepProgress)
    }
    
    private func updateCanContinue() {
        // User can continue to main app if:
        // 1. Onboarding is completed
        // 2. Critical permissions are granted
        // 3. Basic configuration is present
        
        let hasRequiredPermissions = permissionManager.getPermissionStatus(.microphone) == .granted ||
                                   permissionManager.getPermissionStatus(.accessibility) == .granted
        
        let hasBasicConfig = configManager.hasValidOpenAIKey || storageService.isOnboardingCompleted
        
        canContinueToMainApp = storageService.isOnboardingCompleted || (hasRequiredPermissions && hasBasicConfig)
    }
    
    private func hasCriticalConfigurationMissing() -> Bool {
        // Check if any critical configuration is missing
        let hasMicrophonePermission = permissionManager.getPermissionStatus(.microphone) == .granted
        let hasAccessibilityPermission = permissionManager.getPermissionStatus(.accessibility) == .granted
        let hasAPIKey = configManager.hasValidOpenAIKey
        
        // At least one permission and API key should be configured
        return !(hasMicrophonePermission || hasAccessibilityPermission) || !hasAPIKey
    }
    
    private func generateCompletionState() -> OnboardingCompletionState {
        let grantedPermissions = PermissionType.allCases.filter { 
            permissionManager.getPermissionStatus($0) == .granted 
        }
        
        let configSummary = ConfigurationSummary(
            permissionsGranted: grantedPermissions,
            apiConfigured: configManager.hasValidOpenAIKey,
            modelSelected: configManager.selectedModelId,
            optionalStepsCompleted: calculateOptionalStepsCompleted(),
            totalSetupTime: getTotalSetupTime()
        )
        
        let nextSteps = generateNextSteps(for: configSummary)
        
        return OnboardingCompletionState(
            configurationSummary: configSummary,
            nextSteps: nextSteps
        )
    }
    
    private func calculateOptionalStepsCompleted() -> Int {
        var completed = 0
        
        // Count optional configurations
        if permissionManager.getPermissionStatus(.notification) == .granted {
            completed += 1
        }
        
        if configManager.selectedModelId != nil {
            completed += 1
        }
        
        // Add other optional steps as needed
        return completed
    }
    
    private func generateNextSteps(for summary: ConfigurationSummary) -> [NextStep] {
        var steps: [NextStep] = []
        
        // Always suggest testing the app
        steps.append(NextStep(
            title: "Test Voice Recording",
            description: "Try using your configured hotkey to test voice recording",
            actionType: .testFeature,
            priority: .high,
            iconName: "mic.circle.fill"
        ))
        
        // Suggest permission improvements if needed
        if summary.permissionsGranted.count < 3 {
            steps.append(NextStep(
                title: "Grant Additional Permissions",
                description: "Enable all permissions for the best experience",
                actionType: .openSettings,
                priority: .medium,
                iconName: "lock.shield.fill"
            ))
        }
        
        // Suggest model optimization if using default
        if summary.modelSelected == nil || summary.modelSelected == "gpt-3.5-turbo" {
            steps.append(NextStep(
                title: "Optimize AI Model",
                description: "Configure a more advanced model for better results",
                actionType: .openSettings,
                priority: .medium,
                iconName: "cpu.fill"
            ))
        }
        
        // Always suggest customization
        steps.append(NextStep(
            title: "Customize Shortcuts",
            description: "Set up keyboard shortcuts that match your workflow",
            actionType: .configureShortcuts,
            priority: .low,
            iconName: "keyboard"
        ))
        
        // Suggest documentation
        steps.append(NextStep(
            title: "Explore Features",
            description: "Learn about advanced features and tips",
            actionType: .readDocumentation,
            priority: .low,
            iconName: "book.fill"
        ))
        
        return steps
    }
    
    private func getTotalSetupTime() -> TimeInterval {
        guard let startTime = onboardingStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
    
    private func getGrantedPermissionsCount() -> Int {
        return PermissionType.allCases.filter { 
            permissionManager.getPermissionStatus($0) == .granted 
        }.count
    }
    
    private func attemptErrorRecovery(_ error: OnboardingError) {
        LogManager.shared.info("OnboardingCoordinator", "Attempting error recovery for: \(error.code)")
        
        switch error {
        case .permissionDenied(let type):
            // For permission errors, we can guide user to system preferences
            LogManager.shared.info("OnboardingCoordinator", "Permission denied recovery: \(type.rawValue)")
            
        case .apiKeyInvalid:
            // For API key errors, we can return to API setup
            flowManager.moveToStep(.apiKeySetup)
            
        case .networkError:
            // For network errors, we can retry after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.clearError()
            }
            
        case .configurationError:
            // For config errors, we can reset to a known good state
            LogManager.shared.info("OnboardingCoordinator", "Configuration error recovery")
            
        default:
            // For other errors, just clear after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.clearError()
            }
        }
    }
    
    private func trackOnboardingEvent(_ eventName: String, properties: [String: Any] = [:]) {
        var allProperties = properties
        allProperties["onboarding_session_id"] = UUID().uuidString
        allProperties["app_version"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        allProperties["timestamp"] = Date().timeIntervalSince1970
        
        // Track with LogManager or analytics service
        LogManager.shared.info("OnboardingCoordinator", "Event: \(eventName) - Properties: \(allProperties)")
    }
}

// MARK: - Supporting Types

public enum OnboardingPhase: String, CaseIterable {
    case notStarted = "not_started"
    case introduction = "introduction"
    case permissions = "permissions"
    case apiConfiguration = "api_configuration"
    case modelTesting = "model_testing"
    case completion = "completion"
    case completed = "completed"
    case skipped = "skipped"
    
    public var displayName: String {
        switch self {
        case .notStarted: return "Not Started"
        case .introduction: return "Introduction"
        case .permissions: return "Permissions"
        case .apiConfiguration: return "API Configuration"
        case .modelTesting: return "Model Testing"
        case .completion: return "Completion"
        case .completed: return "Completed"
        case .skipped: return "Skipped"
        }
    }
    
    public var iconName: String {
        switch self {
        case .notStarted: return "circle"
        case .introduction: return "hand.wave.fill"
        case .permissions: return "lock.shield.fill"
        case .apiConfiguration: return "key.fill"
        case .modelTesting: return "cpu.fill"
        case .completion: return "checkmark.seal.fill"
        case .completed: return "checkmark.circle.fill"
        case .skipped: return "forward.fill"
        }
    }
}

public enum OnboardingError: Error, LocalizedError {
    case permissionDenied(PermissionType)
    case apiKeyInvalid
    case networkError(String)
    case configurationError(String)
    case flowManagerError(FlowError)
    case storageError(String)
    case unknown(String)
    
    public var code: String {
        switch self {
        case .permissionDenied: return "PERMISSION_DENIED"
        case .apiKeyInvalid: return "API_KEY_INVALID"
        case .networkError: return "NETWORK_ERROR"
        case .configurationError: return "CONFIGURATION_ERROR"
        case .flowManagerError: return "FLOW_MANAGER_ERROR"
        case .storageError: return "STORAGE_ERROR"
        case .unknown: return "UNKNOWN_ERROR"
        }
    }
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied(let type):
            return "Permission denied for \(type.rawValue)"
        case .apiKeyInvalid:
            return "Invalid API key provided"
        case .networkError(let message):
            return "Network error: \(message)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .flowManagerError(let error):
            return "Flow error: \(error.message)"
        case .storageError(let message):
            return "Storage error: \(message)"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}

public struct OnboardingProgressInfo {
    public let phase: OnboardingPhase
    public let currentStep: OnboardingStepType
    public let completionPercentage: Double
    public let canProceed: Bool
    public let estimatedTimeRemaining: Int
    public let setupTime: TimeInterval
    public let errors: [OnboardingError]
    
    public var isComplete: Bool {
        return phase == .completed
    }
    
    public var hasErrors: Bool {
        return !errors.isEmpty
    }
}