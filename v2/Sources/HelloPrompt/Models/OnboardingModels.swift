//
//  OnboardingModels.swift
//  HelloPrompt
//
//  Comprehensive data models for the onboarding flow system
//  Manages state, configuration, and progression through setup steps
//

import SwiftUI
import Foundation

// MARK: - Onboarding Step Definition
public enum OnboardingStepType: Int, CaseIterable, Identifiable {
    case startupIntroduction = 0
    case permissionConfiguration = 1
    case apiKeySetup = 2
    case modelTesting = 3
    case completionScreen = 4
    
    public var id: Int { rawValue }
    
    public var title: String {
        switch self {
        case .startupIntroduction:
            return "Welcome to HelloPrompt"
        case .permissionConfiguration:
            return "Permission Configuration"
        case .apiKeySetup:
            return "API Key Setup"
        case .modelTesting:
            return "Model Testing"
        case .completionScreen:
            return "Setup Complete"
        }
    }
    
    public var description: String {
        switch self {
        case .startupIntroduction:
            return "Let's get you set up with HelloPrompt's AI-powered voice-to-prompt transformation"
        case .permissionConfiguration:
            return "Grant necessary permissions for optimal functionality"
        case .apiKeySetup:
            return "Configure your OpenAI API key and settings"
        case .modelTesting:
            return "Test your API connection and select optimal models"
        case .completionScreen:
            return "You're all set! Let's start using HelloPrompt"
        }
    }
    
    public var iconName: String {
        switch self {
        case .startupIntroduction:
            return "hand.wave.fill"
        case .permissionConfiguration:
            return "lock.shield.fill"
        case .apiKeySetup:
            return "key.fill"
        case .modelTesting:
            return "cpu.fill"
        case .completionScreen:
            return "checkmark.seal.fill"
        }
    }
    
    public var accentColor: Color {
        switch self {
        case .startupIntroduction:
            return .blue
        case .permissionConfiguration:
            return .orange
        case .apiKeySetup:
            return .purple
        case .modelTesting:
            return .green
        case .completionScreen:
            return .mint
        }
    }
    
    public var isOptional: Bool {
        switch self {
        case .startupIntroduction, .completionScreen:
            return false
        case .permissionConfiguration, .apiKeySetup, .modelTesting:
            return true // Users can proceed without completing these
        }
    }
    
    public var estimatedDurationMinutes: Int {
        switch self {
        case .startupIntroduction:
            return 1
        case .permissionConfiguration:
            return 2
        case .apiKeySetup:
            return 2
        case .modelTesting:
            return 1
        case .completionScreen:
            return 1
        }
    }
}

// MARK: - Onboarding Progress State
public struct OnboardingProgress: Codable, Equatable {
    public let currentStep: OnboardingStepType
    public let completedSteps: Set<OnboardingStepType>
    public let skippedSteps: Set<OnboardingStepType>
    public let startedAt: Date
    public let lastUpdatedAt: Date
    public let estimatedTimeRemaining: TimeInterval
    
    public init(
        currentStep: OnboardingStepType = .startupIntroduction,
        completedSteps: Set<OnboardingStepType> = [],
        skippedSteps: Set<OnboardingStepType> = [],
        startedAt: Date = Date(),
        lastUpdatedAt: Date = Date(),
        estimatedTimeRemaining: TimeInterval = 0
    ) {
        self.currentStep = currentStep
        self.completedSteps = completedSteps
        self.skippedSteps = skippedSteps
        self.startedAt = startedAt
        self.lastUpdatedAt = lastUpdatedAt
        self.estimatedTimeRemaining = estimatedTimeRemaining
    }
    
    public var progressPercentage: Double {
        let totalSteps = OnboardingStepType.allCases.count
        let completedCount = completedSteps.count
        return Double(completedCount) / Double(totalSteps)
    }
    
    public var isCompleted: Bool {
        return completedSteps.count == OnboardingStepType.allCases.count
    }
    
    public func isStepCompleted(_ step: OnboardingStepType) -> Bool {
        return completedSteps.contains(step)
    }
    
    public func isStepSkipped(_ step: OnboardingStepType) -> Bool {
        return skippedSteps.contains(step)
    }
    
    public func isStepAccessible(_ step: OnboardingStepType) -> Bool {
        return step.rawValue <= currentStep.rawValue
    }
}

// MARK: - Permission Setup State
public struct PermissionSetupState: Codable, Equatable {
    public let microphoneStatus: PermissionStatus
    public let accessibilityStatus: PermissionStatus
    public let notificationStatus: PermissionStatus
    public let lastCheckedAt: Date
    public let setupAttempts: Int
    
    public init(
        microphoneStatus: PermissionStatus = .unknown,
        accessibilityStatus: PermissionStatus = .unknown,
        notificationStatus: PermissionStatus = .unknown,
        lastCheckedAt: Date = Date(),
        setupAttempts: Int = 0
    ) {
        self.microphoneStatus = microphoneStatus
        self.accessibilityStatus = accessibilityStatus
        self.notificationStatus = notificationStatus
        self.lastCheckedAt = lastCheckedAt
        self.setupAttempts = setupAttempts
    }
    
    public var allPermissionsGranted: Bool {
        return microphoneStatus == .granted && 
               accessibilityStatus == .granted && 
               notificationStatus == .granted
    }
    
    public var corePermissionsGranted: Bool {
        return microphoneStatus == .granted && accessibilityStatus == .granted
    }
    
    public var deniedPermissions: [PermissionType] {
        var denied: [PermissionType] = []
        if microphoneStatus == .denied { denied.append(.microphone) }
        if accessibilityStatus == .denied { denied.append(.accessibility) }
        if notificationStatus == .denied { denied.append(.notification) }
        return denied
    }
}

// MARK: - API Configuration State
public struct APIConfigurationState: Codable, Equatable {
    public let apiKey: String?
    public let baseURL: String
    public let organizationID: String?
    public let selectedModel: String
    public let testStatus: APITestStatus
    public let availableModels: [OpenAIModelInfo]
    public let lastTestedAt: Date?
    public let configurationAttempts: Int
    
    public init(
        apiKey: String? = nil,
        baseURL: String = "https://api.openai.com/v1",
        organizationID: String? = nil,
        selectedModel: String = "gpt-4",
        testStatus: APITestStatus = .untested,
        availableModels: [OpenAIModelInfo] = [],
        lastTestedAt: Date? = nil,
        configurationAttempts: Int = 0
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.organizationID = organizationID
        self.selectedModel = selectedModel
        self.testStatus = testStatus
        self.availableModels = availableModels
        self.lastTestedAt = lastTestedAt
        self.configurationAttempts = configurationAttempts
    }
    
    public var isConfigured: Bool {
        return apiKey != nil && !apiKey!.isEmpty && testStatus == .success
    }
    
    public var hasValidKey: Bool {
        guard let key = apiKey else { return false }
        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && key.count >= 10
    }
}

// MARK: - API Test Status
public enum APITestStatus: String, Codable, CaseIterable {
    case untested = "untested"
    case testing = "testing"
    case success = "success"
    case failure = "failure"
    case timeout = "timeout"
    case networkError = "networkError"
    case authenticationError = "authenticationError"
    case quotaExceeded = "quotaExceeded"
    
    public var displayText: String {
        switch self {
        case .untested:
            return "Not tested"
        case .testing:
            return "Testing..."
        case .success:
            return "Connection successful"
        case .failure:
            return "Connection failed"
        case .timeout:
            return "Connection timeout"
        case .networkError:
            return "Network error"
        case .authenticationError:
            return "Authentication failed"
        case .quotaExceeded:
            return "API quota exceeded"
        }
    }
    
    public var isError: Bool {
        switch self {
        case .success, .testing, .untested:
            return false
        case .failure, .timeout, .networkError, .authenticationError, .quotaExceeded:
            return true
        }
    }
    
    public var statusColor: Color {
        switch self {
        case .untested:
            return .secondary
        case .testing:
            return .blue
        case .success:
            return .green
        case .failure, .timeout, .networkError, .authenticationError, .quotaExceeded:
            return .red
        }
    }
}

// MARK: - OpenAI Model Information
public struct OpenAIModelInfo: Codable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let contextLength: Int?
    public let pricing: ModelPricing?
    public let capabilities: ModelCapabilities
    public let isRecommended: Bool
    public let category: ModelCategory
    
    public init(
        id: String,
        name: String,
        description: String,
        contextLength: Int? = nil,
        pricing: ModelPricing? = nil,
        capabilities: ModelCapabilities = ModelCapabilities(),
        isRecommended: Bool = false,
        category: ModelCategory = .chat
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.contextLength = contextLength
        self.pricing = pricing
        self.capabilities = capabilities
        self.isRecommended = isRecommended
        self.category = category
    }
}

// MARK: - Model Pricing
public struct ModelPricing: Codable, Equatable {
    public let inputTokenPrice: Double // Price per 1K tokens
    public let outputTokenPrice: Double // Price per 1K tokens
    public let currency: String
    
    public init(inputTokenPrice: Double, outputTokenPrice: Double, currency: String = "USD") {
        self.inputTokenPrice = inputTokenPrice
        self.outputTokenPrice = outputTokenPrice
        self.currency = currency
    }
}

// MARK: - Model Capabilities
public struct ModelCapabilities: Codable, Equatable {
    public let supportsChat: Bool
    public let supportsCompletion: Bool
    public let supportsFunctionCalling: Bool
    public let supportsVision: Bool
    public let supportsCodeInterpreter: Bool
    
    public init(
        supportsChat: Bool = true,
        supportsCompletion: Bool = false,
        supportsFunctionCalling: Bool = false,
        supportsVision: Bool = false,
        supportsCodeInterpreter: Bool = false
    ) {
        self.supportsChat = supportsChat
        self.supportsCompletion = supportsCompletion
        self.supportsFunctionCalling = supportsFunctionCalling
        self.supportsVision = supportsVision
        self.supportsCodeInterpreter = supportsCodeInterpreter
    }
}

// MARK: - Model Category
public enum ModelCategory: String, Codable, CaseIterable {
    case chat = "chat"
    case completion = "completion"
    case embedding = "embedding"
    case audio = "audio"
    case vision = "vision"
    case multimodal = "multimodal"
    
    public var displayName: String {
        switch self {
        case .chat:
            return "Chat Models"
        case .completion:
            return "Completion Models"
        case .embedding:
            return "Embedding Models"
        case .audio:
            return "Audio Models"
        case .vision:
            return "Vision Models"
        case .multimodal:
            return "Multimodal Models"
        }
    }
}

// MARK: - Model Testing State
public struct ModelTestingState: Codable, Equatable {
    public let selectedModel: String?
    public let testStatus: ModelTestStatus
    public let testResults: ModelTestResults?
    public let lastTestedAt: Date?
    public let testAttempts: Int
    
    public init(
        selectedModel: String? = nil,
        testStatus: ModelTestStatus = .untested,
        testResults: ModelTestResults? = nil,
        lastTestedAt: Date? = nil,
        testAttempts: Int = 0
    ) {
        self.selectedModel = selectedModel
        self.testStatus = testStatus
        self.testResults = testResults
        self.lastTestedAt = lastTestedAt
        self.testAttempts = testAttempts
    }
    
    public var isConfigured: Bool {
        return selectedModel != nil && testStatus == .success
    }
}

// MARK: - Model Test Status
public enum ModelTestStatus: String, Codable, CaseIterable {
    case untested = "untested"
    case testing = "testing"
    case success = "success"
    case failure = "failure"
    
    public var displayText: String {
        switch self {
        case .untested:
            return "Not tested"
        case .testing:
            return "Testing model..."
        case .success:
            return "Model test successful"
        case .failure:
            return "Model test failed"
        }
    }
    
    public var statusColor: Color {
        switch self {
        case .untested:
            return .secondary
        case .testing:
            return .blue
        case .success:
            return .green
        case .failure:
            return .red
        }
    }
}

// MARK: - Model Test Results
public struct ModelTestResults: Codable, Equatable {
    public let modelId: String
    public let responseTime: TimeInterval
    public let tokensUsed: Int
    public let cost: Double?
    public let testPrompt: String
    public let testResponse: String
    public let testedAt: Date
    
    public init(
        modelId: String,
        responseTime: TimeInterval,
        tokensUsed: Int,
        cost: Double? = nil,
        testPrompt: String,
        testResponse: String,
        testedAt: Date = Date()
    ) {
        self.modelId = modelId
        self.responseTime = responseTime
        self.tokensUsed = tokensUsed
        self.cost = cost
        self.testPrompt = testPrompt
        self.testResponse = testResponse
        self.testedAt = testedAt
    }
    
    public var qualityScore: Double {
        // Simple quality scoring based on response time and length
        let responseTimeScore = max(0, 1 - (responseTime / 10.0)) // Penalize slow responses
        let responseQualityScore = min(1, Double(testResponse.count) / 200.0) // Reward detailed responses
        return (responseTimeScore + responseQualityScore) / 2.0
    }
}

// MARK: - Onboarding Completion State
public struct OnboardingCompletionState: Codable, Equatable {
    public let completedAt: Date
    public let configurationSummary: ConfigurationSummary
    public let userFeedback: String?
    public let nextSteps: [NextStep]
    public let version: String
    
    public init(
        completedAt: Date = Date(),
        configurationSummary: ConfigurationSummary,
        userFeedback: String? = nil,
        nextSteps: [NextStep] = [],
        version: String = "1.0.0"
    ) {
        self.completedAt = completedAt
        self.configurationSummary = configurationSummary
        self.userFeedback = userFeedback
        self.nextSteps = nextSteps
        self.version = version
    }
}

// MARK: - Configuration Summary
public struct ConfigurationSummary: Codable, Equatable {
    public let permissionsGranted: [PermissionType]
    public let apiConfigured: Bool
    public let modelSelected: String?
    public let optionalStepsCompleted: Int
    public let totalSetupTime: TimeInterval
    
    public init(
        permissionsGranted: [PermissionType],
        apiConfigured: Bool,
        modelSelected: String? = nil,
        optionalStepsCompleted: Int = 0,
        totalSetupTime: TimeInterval = 0
    ) {
        self.permissionsGranted = permissionsGranted
        self.apiConfigured = apiConfigured
        self.modelSelected = modelSelected
        self.optionalStepsCompleted = optionalStepsCompleted
        self.totalSetupTime = totalSetupTime
    }
    
    public var setupQuality: SetupQuality {
        let permissionScore = Double(permissionsGranted.count) / 3.0 // 3 total permissions
        let apiScore = apiConfigured ? 1.0 : 0.0
        let modelScore = modelSelected != nil ? 1.0 : 0.0
        
        let overallScore = (permissionScore + apiScore + modelScore) / 3.0
        
        if overallScore >= 0.9 {
            return .excellent
        } else if overallScore >= 0.7 {
            return .good
        } else if overallScore >= 0.5 {
            return .basic
        } else {
            return .minimal
        }
    }
}

// MARK: - Setup Quality
public enum SetupQuality: String, Codable, CaseIterable {
    case minimal = "minimal"
    case basic = "basic"
    case good = "good"
    case excellent = "excellent"
    
    public var displayText: String {
        switch self {
        case .minimal:
            return "Minimal Setup"
        case .basic:
            return "Basic Setup"
        case .good:
            return "Good Setup"
        case .excellent:
            return "Excellent Setup"
        }
    }
    
    public var description: String {
        switch self {
        case .minimal:
            return "Basic functionality available. Consider completing remaining setup steps."
        case .basic:
            return "Core features configured. You can enhance your experience by completing additional setup."
        case .good:
            return "Most features are available. Great job on the setup!"
        case .excellent:
            return "Perfect setup! All features are optimally configured for the best experience."
        }
    }
    
    public var color: Color {
        switch self {
        case .minimal:
            return .red
        case .basic:
            return .orange
        case .good:
            return .blue
        case .excellent:
            return .green
        }
    }
    
    public var iconName: String {
        switch self {
        case .minimal:
            return "exclamationmark.triangle.fill"
        case .basic:
            return "checkmark.circle"
        case .good:
            return "checkmark.circle.fill"
        case .excellent:
            return "star.circle.fill"
        }
    }
}

// MARK: - Next Step
public struct NextStep: Codable, Equatable, Identifiable {
    public let id = UUID()
    public let title: String
    public let description: String
    public let actionType: NextStepActionType
    public let priority: NextStepPriority
    public let iconName: String
    
    public init(
        title: String,
        description: String,
        actionType: NextStepActionType,
        priority: NextStepPriority = .medium,
        iconName: String
    ) {
        self.title = title
        self.description = description
        self.actionType = actionType
        self.priority = priority
        self.iconName = iconName
    }
}

// MARK: - Next Step Action Type
public enum NextStepActionType: String, Codable, CaseIterable {
    case openSettings = "openSettings"
    case testFeature = "testFeature"
    case readDocumentation = "readDocumentation"
    case configureShortcuts = "configureShortcuts"
    case exploreFeatures = "exploreFeatures"
    case joinCommunity = "joinCommunity"
    
    public var displayText: String {
        switch self {
        case .openSettings:
            return "Open Settings"
        case .testFeature:
            return "Test Feature"
        case .readDocumentation:
            return "Read Documentation"
        case .configureShortcuts:
            return "Configure Shortcuts"
        case .exploreFeatures:
            return "Explore Features"
        case .joinCommunity:
            return "Join Community"
        }
    }
}

// MARK: - Next Step Priority
public enum NextStepPriority: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    public var color: Color {
        switch self {
        case .low:
            return .secondary
        case .medium:
            return .blue
        case .high:
            return .red
        }
    }
}

// MARK: - Onboarding Analytics
public struct OnboardingAnalytics: Codable {
    public let sessionId: UUID
    public let startedAt: Date
    public let completedAt: Date?
    public let stepsCompleted: [OnboardingStepType]
    public let stepsSkipped: [OnboardingStepType]
    public let totalTimeSpent: TimeInterval
    public let timePerStep: [OnboardingStepType: TimeInterval]
    public let userInteractions: [UserInteraction]
    public let errorOccurred: [OnboardingError]
    
    public init(
        sessionId: UUID = UUID(),
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        stepsCompleted: [OnboardingStepType] = [],
        stepsSkipped: [OnboardingStepType] = [],
        totalTimeSpent: TimeInterval = 0,
        timePerStep: [OnboardingStepType: TimeInterval] = [:],
        userInteractions: [UserInteraction] = [],
        errorOccurred: [OnboardingError] = []
    ) {
        self.sessionId = sessionId
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.stepsCompleted = stepsCompleted
        self.stepsSkipped = stepsSkipped
        self.totalTimeSpent = totalTimeSpent
        self.timePerStep = timePerStep
        self.userInteractions = userInteractions
        self.errorOccurred = errorOccurred
    }
}

// MARK: - User Interaction
public struct UserInteraction: Codable {
    public let timestamp: Date
    public let type: InteractionType
    public let step: OnboardingStepType
    public let details: String?
    
    public init(timestamp: Date = Date(), type: InteractionType, step: OnboardingStepType, details: String? = nil) {
        self.timestamp = timestamp
        self.type = type
        self.step = step
        self.details = details
    }
}

// MARK: - Interaction Type
public enum InteractionType: String, Codable, CaseIterable {
    case stepEntered = "stepEntered"
    case stepCompleted = "stepCompleted"
    case stepSkipped = "stepSkipped"
    case buttonClicked = "buttonClicked"
    case permissionRequested = "permissionRequested"
    case apiKeyEntered = "apiKeyEntered"
    case modelSelected = "modelSelected"
    case testCompleted = "testCompleted"
    case errorEncountered = "errorEncountered"
}

// MARK: - Onboarding Error
public struct OnboardingError: Codable, Error, LocalizedError {
    public let timestamp: Date
    public let step: OnboardingStepType
    public let errorType: OnboardingErrorType
    public let message: String
    public let underlyingError: String?
    
    public init(
        timestamp: Date = Date(),
        step: OnboardingStepType,
        errorType: OnboardingErrorType,
        message: String,
        underlyingError: String? = nil
    ) {
        self.timestamp = timestamp
        self.step = step
        self.errorType = errorType
        self.message = message
        self.underlyingError = underlyingError
    }
    
    public var errorDescription: String? {
        return message
    }
}

// MARK: - Onboarding Error Type
public enum OnboardingErrorType: String, Codable, CaseIterable {
    case permissionDenied = "permissionDenied"
    case apiConnectionFailed = "apiConnectionFailed"
    case invalidApiKey = "invalidApiKey"
    case modelTestFailed = "modelTestFailed"
    case configurationSaveFailed = "configurationSaveFailed"
    case networkError = "networkError"
    case unknownError = "unknownError"
    
    public var displayText: String {
        switch self {
        case .permissionDenied:
            return "Permission Denied"
        case .apiConnectionFailed:
            return "API Connection Failed"
        case .invalidApiKey:
            return "Invalid API Key"
        case .modelTestFailed:
            return "Model Test Failed"
        case .configurationSaveFailed:
            return "Configuration Save Failed"
        case .networkError:
            return "Network Error"
        case .unknownError:
            return "Unknown Error"
        }
    }
}