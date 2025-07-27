//
//  OnboardingStorageService.swift
//  HelloPrompt
//
//  Comprehensive storage service for onboarding flow
//  Handles persistence of settings, progress, and completion status
//

import Foundation
import Combine

// MARK: - Onboarding Storage Service
@MainActor
public class OnboardingStorageService: ObservableObject {
    public static let shared = OnboardingStorageService()
    
    // MARK: - Published Properties
    @Published public private(set) var isOnboardingCompleted: Bool = false
    @Published public private(set) var currentProgress: OnboardingProgress?
    @Published public private(set) var completionState: OnboardingCompletionState?
    
    // MARK: - Storage Keys
    private enum StorageKeys {
        static let onboardingCompleted = "HelloPrompt_OnboardingCompleted"
        static let onboardingProgress = "HelloPrompt_OnboardingProgress"
        static let onboardingCompletion = "HelloPrompt_OnboardingCompletion"
        static let onboardingVersion = "HelloPrompt_OnboardingVersion"
        static let onboardingAnalytics = "HelloPrompt_OnboardingAnalytics"
        static let skipOnboarding = "HelloPrompt_SkipOnboarding"
        static let onboardingFirstRun = "HelloPrompt_OnboardingFirstRun"
    }
    
    // MARK: - Configuration
    private let currentOnboardingVersion = "2.0.0"
    private let userDefaults = UserDefaults.standard
    private let logManager = LogManager.shared
    
    // MARK: - Analytics
    @Published public private(set) var currentAnalytics: OnboardingAnalytics?
    
    // MARK: - Initialization
    private init() {
        loadStoredData()
        logManager.info("OnboardingStorageService", "Storage service initialized")
    }
    
    // MARK: - Data Loading
    private func loadStoredData() {
        // Load completion status
        isOnboardingCompleted = userDefaults.bool(forKey: StorageKeys.onboardingCompleted)
        
        // Load progress
        if let progressData = userDefaults.data(forKey: StorageKeys.onboardingProgress),
           let progress = try? JSONDecoder().decode(OnboardingProgress.self, from: progressData) {
            currentProgress = progress
        }
        
        // Load completion state
        if let completionData = userDefaults.data(forKey: StorageKeys.onboardingCompletion),
           let completion = try? JSONDecoder().decode(OnboardingCompletionState.self, from: completionData) {
            completionState = completion
        }
        
        // Load analytics
        if let analyticsData = userDefaults.data(forKey: StorageKeys.onboardingAnalytics),
           let analytics = try? JSONDecoder().decode(OnboardingAnalytics.self, from: analyticsData) {
            currentAnalytics = analytics
        }
        
        logManager.info("OnboardingStorageService", "Loaded stored data - Completed: \(isOnboardingCompleted)")
    }
    
    // MARK: - Onboarding Status Management
    
    /// Check if this is the first run of the application
    public func isFirstRun() -> Bool {
        let hasRunBefore = userDefaults.bool(forKey: StorageKeys.onboardingFirstRun)
        if !hasRunBefore {
            userDefaults.set(true, forKey: StorageKeys.onboardingFirstRun)
            logManager.info("OnboardingStorageService", "First run detected")
            return true
        }
        return false
    }
    
    /// Check if onboarding should be shown
    public func shouldShowOnboarding() -> Bool {
        // Show onboarding if:
        // 1. Not completed, OR
        // 2. Version has been updated, OR  
        // 3. User explicitly requested it, OR
        // 4. It's the first run
        
        let versionChanged = hasOnboardingVersionChanged()
        let skipRequested = userDefaults.bool(forKey: StorageKeys.skipOnboarding)
        let firstRun = isFirstRun()
        
        let shouldShow = !isOnboardingCompleted || versionChanged || firstRun
        
        logManager.info("OnboardingStorageService", """
            Onboarding decision:
            - Completed: \(isOnboardingCompleted)
            - Version changed: \(versionChanged)
            - Skip requested: \(skipRequested)
            - First run: \(firstRun)
            - Result: \(shouldShow && !skipRequested)
            """)
        
        return shouldShow && !skipRequested
    }
    
    /// Check for version changes that require re-onboarding
    private func hasOnboardingVersionChanged() -> Bool {
        let storedVersion = userDefaults.string(forKey: StorageKeys.onboardingVersion)
        return storedVersion != currentOnboardingVersion
    }
    
    /// Start a new onboarding session
    public func startOnboardingSession() {
        let analytics = OnboardingAnalytics(
            sessionId: UUID(),
            startedAt: Date()
        )
        
        currentAnalytics = analytics
        saveAnalytics()
        
        // Initialize progress
        let progress = OnboardingProgress(
            currentStep: .startupIntroduction,
            startedAt: Date()
        )
        
        updateProgress(progress)
        
        logManager.info("OnboardingStorageService", "Started new onboarding session: \(analytics.sessionId)")
    }
    
    /// Mark onboarding as completed
    public func completeOnboarding(with completionState: OnboardingCompletionState) {
        self.completionState = completionState
        isOnboardingCompleted = true
        
        // Update version
        userDefaults.set(currentOnboardingVersion, forKey: StorageKeys.onboardingVersion)
        
        // Save completion state
        saveCompletionState()
        
        // Complete analytics
        if var analytics = currentAnalytics {
            analytics = OnboardingAnalytics(
                sessionId: analytics.sessionId,
                startedAt: analytics.startedAt,
                completedAt: Date(),
                stepsCompleted: Array(currentProgress?.completedSteps ?? []),
                stepsSkipped: Array(currentProgress?.skippedSteps ?? []),
                totalTimeSpent: Date().timeIntervalSince(analytics.startedAt),
                timePerStep: analytics.timePerStep,
                userInteractions: analytics.userInteractions,
                errorOccurred: analytics.errorOccurred
            )
            currentAnalytics = analytics
            saveAnalytics()
        }
        
        // Clear progress
        currentProgress = nil
        clearProgress()
        
        logManager.info("OnboardingStorageService", "Onboarding completed and saved")
    }
    
    /// Skip onboarding (temporary or permanent)
    public func skipOnboarding(permanent: Bool = false) {
        if permanent {
            userDefaults.set(true, forKey: StorageKeys.skipOnboarding)
            isOnboardingCompleted = true
            userDefaults.set(currentOnboardingVersion, forKey: StorageKeys.onboardingVersion)
        }
        
        // Record skip in analytics
        if var analytics = currentAnalytics {
            let interaction = UserInteraction(
                type: .stepSkipped,
                step: currentProgress?.currentStep ?? .startupIntroduction,
                details: permanent ? "Permanent skip" : "Temporary skip"
            )
            analytics.userInteractions.append(interaction)
            currentAnalytics = analytics
            saveAnalytics()
        }
        
        logManager.info("OnboardingStorageService", "Onboarding skipped - Permanent: \(permanent)")
    }
    
    /// Reset onboarding (for testing or re-configuration)
    public func resetOnboarding() {
        isOnboardingCompleted = false
        currentProgress = nil
        completionState = nil
        currentAnalytics = nil
        
        userDefaults.removeObject(forKey: StorageKeys.onboardingCompleted)
        userDefaults.removeObject(forKey: StorageKeys.onboardingProgress)
        userDefaults.removeObject(forKey: StorageKeys.onboardingCompletion)
        userDefaults.removeObject(forKey: StorageKeys.onboardingAnalytics)
        userDefaults.removeObject(forKey: StorageKeys.skipOnboarding)
        userDefaults.removeObject(forKey: StorageKeys.onboardingVersion)
        
        logManager.info("OnboardingStorageService", "Onboarding reset completed")
    }
    
    // MARK: - Progress Management
    
    /// Update onboarding progress
    public func updateProgress(_ progress: OnboardingProgress) {
        currentProgress = progress
        saveProgress()
        logManager.debug("OnboardingStorageService", "Progress updated: \(progress.currentStep.title)")
    }
    
    /// Mark a step as completed
    public func markStepCompleted(_ step: OnboardingStepType) {
        guard var progress = currentProgress else {
            logManager.warning("OnboardingStorageService", "Cannot mark step completed: no current progress")
            return
        }
        
        var completedSteps = progress.completedSteps
        completedSteps.insert(step)
        
        // Remove from skipped if it was previously skipped
        var skippedSteps = progress.skippedSteps
        skippedSteps.remove(step)
        
        let updatedProgress = OnboardingProgress(
            currentStep: progress.currentStep,
            completedSteps: completedSteps,
            skippedSteps: skippedSteps,
            startedAt: progress.startedAt,
            lastUpdatedAt: Date(),
            estimatedTimeRemaining: calculateEstimatedTimeRemaining(for: progress.currentStep)
        )
        
        updateProgress(updatedProgress)
        
        // Record in analytics
        recordUserInteraction(.stepCompleted, step: step)
        
        logManager.info("OnboardingStorageService", "Step marked as completed: \(step.title)")
    }
    
    /// Mark a step as skipped
    public func markStepSkipped(_ step: OnboardingStepType) {
        guard var progress = currentProgress else {
            logManager.warning("OnboardingStorageService", "Cannot mark step skipped: no current progress")
            return
        }
        
        var skippedSteps = progress.skippedSteps
        skippedSteps.insert(step)
        
        let updatedProgress = OnboardingProgress(
            currentStep: progress.currentStep,
            completedSteps: progress.completedSteps,
            skippedSteps: skippedSteps,
            startedAt: progress.startedAt,
            lastUpdatedAt: Date(),
            estimatedTimeRemaining: calculateEstimatedTimeRemaining(for: progress.currentStep)
        )
        
        updateProgress(updatedProgress)
        
        // Record in analytics
        recordUserInteraction(.stepSkipped, step: step)
        
        logManager.info("OnboardingStorageService", "Step marked as skipped: \(step.title)")
    }
    
    /// Move to next step
    public func moveToNextStep() {
        guard let currentProgress = currentProgress else { return }
        
        let allSteps = OnboardingStepType.allCases
        guard let currentIndex = allSteps.firstIndex(of: currentProgress.currentStep),
              currentIndex + 1 < allSteps.count else {
            logManager.info("OnboardingStorageService", "Already at last step")
            return
        }
        
        let nextStep = allSteps[currentIndex + 1]
        moveToStep(nextStep)
    }
    
    /// Move to previous step
    public func moveToPreviousStep() {
        guard let currentProgress = currentProgress else { return }
        
        let allSteps = OnboardingStepType.allCases
        guard let currentIndex = allSteps.firstIndex(of: currentProgress.currentStep),
              currentIndex > 0 else {
            logManager.info("OnboardingStorageService", "Already at first step")
            return
        }
        
        let previousStep = allSteps[currentIndex - 1]
        moveToStep(previousStep)
    }
    
    /// Move to specific step
    public func moveToStep(_ step: OnboardingStepType) {
        guard var progress = currentProgress else { return }
        
        let updatedProgress = OnboardingProgress(
            currentStep: step,
            completedSteps: progress.completedSteps,
            skippedSteps: progress.skippedSteps,
            startedAt: progress.startedAt,
            lastUpdatedAt: Date(),
            estimatedTimeRemaining: calculateEstimatedTimeRemaining(for: step)
        )
        
        updateProgress(updatedProgress)
        
        // Record in analytics
        recordUserInteraction(.stepEntered, step: step)
        
        logManager.info("OnboardingStorageService", "Moved to step: \(step.title)")
    }
    
    /// Calculate estimated time remaining
    private func calculateEstimatedTimeRemaining(for currentStep: OnboardingStepType) -> TimeInterval {
        let allSteps = OnboardingStepType.allCases
        guard let currentIndex = allSteps.firstIndex(of: currentStep) else { return 0 }
        
        let remainingSteps = allSteps.dropFirst(currentIndex + 1)
        let totalMinutes = remainingSteps.reduce(0) { $0 + $1.estimatedDurationMinutes }
        
        return TimeInterval(totalMinutes * 60) // Convert to seconds
    }
    
    // MARK: - Analytics Management
    
    /// Record a user interaction
    public func recordUserInteraction(_ type: InteractionType, step: OnboardingStepType, details: String? = nil) {
        guard var analytics = currentAnalytics else { return }
        
        let interaction = UserInteraction(
            timestamp: Date(),
            type: type,
            step: step,
            details: details
        )
        
        analytics.userInteractions.append(interaction)
        currentAnalytics = analytics
        saveAnalytics()
        
        logManager.debug("OnboardingStorageService", "Recorded interaction: \(type.rawValue) for \(step.title)")
    }
    
    /// Record an error
    public func recordError(_ error: OnboardingError) {
        guard var analytics = currentAnalytics else { return }
        
        analytics.errorOccurred.append(error)
        currentAnalytics = analytics
        saveAnalytics()
        
        logManager.error("OnboardingStorageService", "Recorded error: \(error.message) in \(error.step.title)")
    }
    
    /// Update time spent on a step
    public func updateStepTime(_ step: OnboardingStepType, timeSpent: TimeInterval) {
        guard var analytics = currentAnalytics else { return }
        
        analytics.timePerStep[step] = timeSpent
        currentAnalytics = analytics
        saveAnalytics()
        
        logManager.debug("OnboardingStorageService", "Updated time for \(step.title): \(timeSpent)s")
    }
    
    // MARK: - Data Persistence
    
    private func saveProgress() {
        guard let progress = currentProgress else { return }
        
        do {
            let data = try JSONEncoder().encode(progress)
            userDefaults.set(data, forKey: StorageKeys.onboardingProgress)
        } catch {
            logManager.error("OnboardingStorageService", "Failed to save progress: \(error)")
        }
    }
    
    private func clearProgress() {
        userDefaults.removeObject(forKey: StorageKeys.onboardingProgress)
    }
    
    private func saveCompletionState() {
        guard let completionState = completionState else { return }
        
        do {
            let data = try JSONEncoder().encode(completionState)
            userDefaults.set(data, forKey: StorageKeys.onboardingCompletion)
            userDefaults.set(true, forKey: StorageKeys.onboardingCompleted)
        } catch {
            logManager.error("OnboardingStorageService", "Failed to save completion state: \(error)")
        }
    }
    
    private func saveAnalytics() {
        guard let analytics = currentAnalytics else { return }
        
        do {
            let data = try JSONEncoder().encode(analytics)
            userDefaults.set(data, forKey: StorageKeys.onboardingAnalytics)
        } catch {
            logManager.error("OnboardingStorageService", "Failed to save analytics: \(error)")
        }
    }
    
    // MARK: - Configuration Integration
    
    /// Save API configuration from onboarding
    public func saveAPIConfiguration(_ state: APIConfigurationState) throws {
        let configManager = AppConfigManager.shared
        
        // Save API key securely
        if let apiKey = state.apiKey {
            try configManager.setOpenAIAPIKey(apiKey)
        }
        
        // Save other configuration
        configManager.openAIBaseURL = state.baseURL
        configManager.openAIOrganization = state.organizationID
        configManager.openAIModel = state.selectedModel
        
        logManager.info("OnboardingStorageService", "API configuration saved from onboarding")
    }
    
    /// Save permission preferences
    public func savePermissionPreferences(_ state: PermissionSetupState) {
        // Store permission preferences in UserDefaults for future reference
        let preferences = [
            "microphone_requested": state.microphoneStatus != .unknown,
            "accessibility_requested": state.accessibilityStatus != .unknown,
            "notification_requested": state.notificationStatus != .unknown,
            "setup_attempts": state.setupAttempts
        ]
        
        for (key, value) in preferences {
            userDefaults.set(value, forKey: "HelloPrompt_Permission_\(key)")
        }
        
        logManager.info("OnboardingStorageService", "Permission preferences saved")
    }
    
    // MARK: - Export and Import
    
    /// Export onboarding configuration for backup
    public func exportConfiguration() -> Data? {
        let exportData = OnboardingExportData(
            version: currentOnboardingVersion,
            completionState: completionState,
            analytics: currentAnalytics,
            exportedAt: Date()
        )
        
        do {
            return try JSONEncoder().encode(exportData)
        } catch {
            logManager.error("OnboardingStorageService", "Failed to export configuration: \(error)")
            return nil
        }
    }
    
    /// Import onboarding configuration from backup
    public func importConfiguration(_ data: Data) throws {
        let importData = try JSONDecoder().decode(OnboardingExportData.self, from: data)
        
        if let completionState = importData.completionState {
            self.completionState = completionState
            isOnboardingCompleted = true
        }
        
        if let analytics = importData.analytics {
            currentAnalytics = analytics
        }
        
        saveCompletionState()
        saveAnalytics()
        
        userDefaults.set(importData.version, forKey: StorageKeys.onboardingVersion)
        
        logManager.info("OnboardingStorageService", "Configuration imported successfully")
    }
}

// MARK: - Export Data Structure
private struct OnboardingExportData: Codable {
    let version: String
    let completionState: OnboardingCompletionState?
    let analytics: OnboardingAnalytics?
    let exportedAt: Date
}

// MARK: - Extension for UserDefaults Keys
extension OnboardingStorageService {
    /// Get all onboarding-related keys for debugging
    public func getAllStorageKeys() -> [String: Any] {
        let keys = [
            StorageKeys.onboardingCompleted,
            StorageKeys.onboardingProgress,
            StorageKeys.onboardingCompletion,
            StorageKeys.onboardingVersion,
            StorageKeys.onboardingAnalytics,
            StorageKeys.skipOnboarding,
            StorageKeys.onboardingFirstRun
        ]
        
        var result: [String: Any] = [:]
        for key in keys {
            result[key] = userDefaults.object(forKey: key)
        }
        
        return result
    }
    
    /// Debug method to print all stored data
    public func debugPrintStoredData() {
        let data = getAllStorageKeys()
        logManager.debug("OnboardingStorageService", "All stored data: \(data)")
    }
}