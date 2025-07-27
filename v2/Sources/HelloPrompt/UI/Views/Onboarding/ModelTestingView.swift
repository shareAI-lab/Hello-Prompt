//
//  ModelTestingView.swift
//  HelloPrompt
//
//  Model testing and selection view for onboarding
//  Tests connection, evaluates model performance, and saves optimal configuration
//

import SwiftUI

// MARK: - Model Testing View
public struct ModelTestingView: View {
    
    // MARK: - Properties
    @ObservedObject private var flowManager = OnboardingFlowManager.shared
    @State private var selectedModelId: String = "gpt-4"
    @State private var testPrompt: String = "Help me write a professional email to schedule a meeting with my team."
    @State private var customTestPrompt: String = ""
    @State private var useCustomPrompt: Bool = false
    
    // UI State
    @State private var isTestingModel = false
    @State private var showingModelComparison = false
    @State private var animateModels = false
    @State private var expandedModelId: String? = nil
    
    // Test Results
    @State private var testResults: [String: ModelTestResults] = [:]
    @State private var comparisonMode = false
    @State private var modelsToCompare: Set<String> = []
    
    // MARK: - Callbacks
    let onContinue: () -> Void
    let onSkip: () -> Void
    let onBack: () -> Void
    
    // MARK: - Test Prompts
    private let predefinedPrompts = [
        TestPrompt(
            title: "Email Writing",
            prompt: "Help me write a professional email to schedule a meeting with my team.",
            category: .business
        ),
        TestPrompt(
            title: "Creative Writing",
            prompt: "Write a short story about a time traveler who gets stuck in the past.",
            category: .creative
        ),
        TestPrompt(
            title: "Technical Explanation",
            prompt: "Explain how machine learning works in simple terms for a beginner.",
            category: .technical
        ),
        TestPrompt(
            title: "Problem Solving",
            prompt: "I need to organize a team event for 20 people with a $500 budget. Give me ideas and a plan.",
            category: .problemSolving
        )
    ]
    
    // MARK: - Main Body
    public var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                headerSection
                
                // Model Selection
                modelSelectionSection
                
                // Test Configuration
                testConfigurationSection
                
                // Test Results
                if !testResults.isEmpty {
                    testResultsSection
                }
                
                // Model Comparison
                if comparisonMode {
                    modelComparisonSection
                }
                
                // Recommendation
                recommendationSection
                
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
            LogManager.shared.info("ModelTestingView", "Model testing view appeared")
        }
        .sheet(isPresented: $showingModelComparison) {
            modelComparisonSheet
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: "cpu.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(animateModels ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animateModels)
            
            VStack(spacing: 12) {
                Text("Model Testing")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Test AI models to find the best performance for your needs")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Testing Status
            ModelTestingStatusView(
                currentTest: isTestingModel ? selectedModelId : nil,
                testResults: testResults,
                selectedModel: flowManager.modelTestingState.selectedModel
            )
        }
    }
    
    // MARK: - Model Selection Section
    private var modelSelectionSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Available Models")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(comparisonMode ? "Exit Comparison" : "Compare Models") {
                    toggleComparisonMode()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(flowManager.apiConfigState.availableModels) { model in
                    ModelSelectionCard(
                        model: model,
                        isSelected: selectedModelId == model.id,
                        isExpanded: expandedModelId == model.id,
                        isComparing: comparisonMode,
                        isSelectedForComparison: modelsToCompare.contains(model.id),
                        testResult: testResults[model.id],
                        onSelect: {
                            if comparisonMode {
                                toggleModelForComparison(model.id)
                            } else {
                                selectModel(model.id)
                            }
                        },
                        onExpand: {
                            expandedModelId = expandedModelId == model.id ? nil : model.id
                        },
                        onTest: {
                            testModel(model.id)
                        }
                    )
                    .opacity(animateModels ? 1.0 : 0.0)
                    .offset(y: animateModels ? 0 : 20)
                    .animation(
                        .easeOut(duration: 0.5)
                        .delay(Double(flowManager.apiConfigState.availableModels.firstIndex(of: model) ?? 0) * 0.1),
                        value: animateModels
                    )
                }
            }
        }
    }
    
    // MARK: - Test Configuration Section
    private var testConfigurationSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Test Configuration")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(spacing: 16) {
                // Prompt Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Test Prompt")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Picker("Test Type", selection: $useCustomPrompt) {
                        Text("Predefined Prompts").tag(false)
                        Text("Custom Prompt").tag(true)
                    }
                    .pickerStyle(.segmented)
                    
                    if useCustomPrompt {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Custom Test Prompt")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            TextEditor(text: $customTestPrompt)
                                .frame(height: 100)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                            
                            Text("Enter a prompt that represents your typical use case")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Select a predefined test scenario:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                                ForEach(predefinedPrompts, id: \.title) { prompt in
                                    TestPromptCard(
                                        prompt: prompt,
                                        isSelected: testPrompt == prompt.prompt,
                                        onSelect: {
                                            testPrompt = prompt.prompt
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                
                // Test Actions
                HStack(spacing: 12) {
                    Button(action: testSelectedModel) {
                        HStack {
                            if isTestingModel {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "play.fill")
                            }
                            
                            Text(isTestingModel ? "Testing..." : "Test Selected Model")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: canTestModel ? [.green, .blue] : [.gray, .gray],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canTestModel || isTestingModel)
                    
                    if comparisonMode && modelsToCompare.count >= 2 {
                        Button("Test All Selected") {
                            testSelectedModelsForComparison()
                        }
                        .buttonStyle(.bordered)
                        .disabled(isTestingModel)
                    }
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
    
    // MARK: - Test Results Section
    private var testResultsSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Test Results")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Clear Results") {
                    testResults.removeAll()
                }
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)
                .font(.caption)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(Array(testResults.keys.sorted()), id: \.self) { modelId in
                    if let result = testResults[modelId] {
                        TestResultCard(result: result)
                    }
                }
            }
        }
    }
    
    // MARK: - Model Comparison Section
    private var modelComparisonSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Model Comparison")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(modelsToCompare.count) selected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if modelsToCompare.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.title)
                        .foregroundColor(.secondary)
                    
                    Text("Select 2 or more models to compare")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 100)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(modelsToCompare), id: \.self) { modelId in
                            if let model = flowManager.apiConfigState.availableModels.first(where: { $0.id == modelId }) {
                                ComparisonModelCard(
                                    model: model,
                                    testResult: testResults[modelId],
                                    onRemove: {
                                        modelsToCompare.remove(modelId)
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - Recommendation Section
    private var recommendationSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.title3)
                    .foregroundColor(.yellow)
                
                Text("Recommendation")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            if let recommendedModel = getRecommendedModel() {
                ModelRecommendationCard(
                    model: recommendedModel,
                    testResult: testResults[recommendedModel.id],
                    reasons: getRecommendationReasons(for: recommendedModel),
                    onSelect: {
                        selectModel(recommendedModel.id)
                    }
                )
            } else {
                VStack(spacing: 12) {
                    Text("Test models to get personalized recommendations")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("We'll analyze performance, cost, and speed to suggest the best model for your use case")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.yellow.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 16) {
            // Save Selection
            if flowManager.modelTestingState.selectedModel != nil {
                Button(action: saveModelSelection) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                        
                        Text("Save Model Selection")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }
            
            // Navigation Buttons
            HStack(spacing: 20) {
                Button("Back") {
                    onBack()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                if flowManager.modelTestingState.selectedModel != nil {
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
                Color.green.opacity(0.02)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Model Comparison Sheet
    private var modelComparisonSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Model Comparison Details")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    ModelComparisonDetailView(
                        models: flowManager.apiConfigState.availableModels.filter { modelsToCompare.contains($0.id) },
                        testResults: testResults
                    )
                    
                    Spacer(minLength: 32)
                }
                .padding()
            }
            .navigationTitle("Model Comparison")
            .navigationBarItems(
                trailing: Button("Done") {
                    showingModelComparison = false
                }
            )
        }
    }
    
    // MARK: - Computed Properties
    private var canTestModel: Bool {
        return !selectedModelId.isEmpty && 
               (!useCustomPrompt || !customTestPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) &&
               (!useCustomPrompt || !testPrompt.isEmpty)
    }
    
    private var currentTestPrompt: String {
        return useCustomPrompt ? customTestPrompt : testPrompt
    }
    
    // MARK: - Methods
    private func setupInitialState() {
        // Set the first available model as default
        if let firstModel = flowManager.apiConfigState.availableModels.first {
            selectedModelId = firstModel.id
        }
        
        // Load any existing selection
        if let existingSelection = flowManager.modelTestingState.selectedModel {
            selectedModelId = existingSelection
        }
        
        // Set default test prompt
        if let firstPrompt = predefinedPrompts.first {
            testPrompt = firstPrompt.prompt
        }
    }
    
    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.8)) {
            animateModels = true
        }
    }
    
    private func selectModel(_ modelId: String) {
        selectedModelId = modelId
        LogManager.shared.info("ModelTestingView", "Selected model: \(modelId)")
    }
    
    private func toggleComparisonMode() {
        comparisonMode.toggle()
        if !comparisonMode {
            modelsToCompare.removeAll()
        }
        LogManager.shared.info("ModelTestingView", "Comparison mode: \(comparisonMode)")
    }
    
    private func toggleModelForComparison(_ modelId: String) {
        if modelsToCompare.contains(modelId) {
            modelsToCompare.remove(modelId)
        } else {
            modelsToCompare.insert(modelId)
        }
        LogManager.shared.info("ModelTestingView", "Models for comparison: \(modelsToCompare)")
    }
    
    private func testSelectedModel() {
        testModel(selectedModelId)
    }
    
    private func testModel(_ modelId: String) {
        Task {
            isTestingModel = true
            
            await flowManager.testModel(modelId)
            
            // Store the result locally for UI
            if let result = flowManager.modelTestingState.testResults {
                testResults[modelId] = result
            }
            
            isTestingModel = false
            
            LogManager.shared.info("ModelTestingView", "Model test completed: \(modelId)")
        }
    }
    
    private func testSelectedModelsForComparison() {
        Task {
            for modelId in modelsToCompare {
                await testModel(modelId)
            }
        }
    }
    
    private func saveModelSelection() {
        LogManager.shared.info("ModelTestingView", "Saved model selection: \(selectedModelId)")
        // Model selection is already handled by the flow manager
    }
    
    private func getRecommendedModel() -> OpenAIModelInfo? {
        guard !testResults.isEmpty else { return nil }
        
        // Find the model with the best overall score
        let modelsWithResults = flowManager.apiConfigState.availableModels.filter { model in
            testResults[model.id] != nil
        }
        
        return modelsWithResults.max { model1, model2 in
            let score1 = testResults[model1.id]?.qualityScore ?? 0
            let score2 = testResults[model2.id]?.qualityScore ?? 0
            return score1 < score2
        }
    }
    
    private func getRecommendationReasons(for model: OpenAIModelInfo) -> [String] {
        guard let result = testResults[model.id] else { return [] }
        
        var reasons: [String] = []
        
        if result.responseTime < 3.0 {
            reasons.append("Fast response time (\(String(format: "%.1f", result.responseTime))s)")
        }
        
        if result.qualityScore > 0.8 {
            reasons.append("High quality responses")
        }
        
        if model.isRecommended {
            reasons.append("Recommended by OpenAI")
        }
        
        if let pricing = model.pricing, pricing.inputTokenPrice < 0.01 {
            reasons.append("Cost-effective pricing")
        }
        
        return reasons
    }
    
    // MARK: - Initialization
    public init(onContinue: @escaping () -> Void, onSkip: @escaping () -> Void, onBack: @escaping () -> Void) {
        self.onContinue = onContinue
        self.onSkip = onSkip
        self.onBack = onBack
    }
}

// MARK: - Supporting Data Types

private struct TestPrompt {
    let title: String
    let prompt: String
    let category: TestCategory
}

private enum TestCategory {
    case business
    case creative
    case technical
    case problemSolving
    
    var color: Color {
        switch self {
        case .business: return .blue
        case .creative: return .purple
        case .technical: return .green
        case .problemSolving: return .orange
        }
    }
    
    var icon: String {
        switch self {
        case .business: return "briefcase.fill"
        case .creative: return "paintbrush.fill"
        case .technical: return "gearshape.fill"
        case .problemSolving: return "lightbulb.fill"
        }
    }
}

// MARK: - Supporting Views

private struct ModelTestingStatusView: View {
    let currentTest: String?
    let testResults: [String: ModelTestResults]
    let selectedModel: String?
    
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
            
            // Progress Indicator
            if let currentTest = currentTest {
                VStack(alignment: .trailing, spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("Testing \(currentTest)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
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
        if currentTest != nil {
            return "arrow.clockwise"
        } else if selectedModel != nil {
            return "checkmark.circle.fill"
        } else if !testResults.isEmpty {
            return "chart.bar.fill"
        } else {
            return "cpu"
        }
    }
    
    private var statusColor: Color {
        if currentTest != nil {
            return .blue
        } else if selectedModel != nil {
            return .green
        } else if !testResults.isEmpty {
            return .orange
        } else {
            return .secondary
        }
    }
    
    private var statusTitle: String {
        if currentTest != nil {
            return "Testing in Progress"
        } else if selectedModel != nil {
            return "Model Selected"
        } else if !testResults.isEmpty {
            return "Tests Completed"
        } else {
            return "Ready to Test"
        }
    }
    
    private var statusDescription: String {
        if currentTest != nil {
            return "Please wait while we test the model performance"
        } else if let selectedModel = selectedModel {
            return "Using \(selectedModel) for AI processing"
        } else if !testResults.isEmpty {
            return "\(testResults.count) model(s) tested - ready to select"
        } else {
            return "Select a model and test its performance"
        }
    }
}

private struct ModelSelectionCard: View {
    let model: OpenAIModelInfo
    let isSelected: Bool
    let isExpanded: Bool
    let isComparing: Bool
    let isSelectedForComparison: Bool
    let testResult: ModelTestResults?
    let onSelect: () -> Void
    let onExpand: () -> Void
    let onTest: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                // Selection/Comparison Indicator
                if isComparing {
                    Button(action: onSelect) {
                        Image(systemName: isSelectedForComparison ? "checkmark.square.fill" : "square")
                            .font(.title3)
                            .foregroundColor(isSelectedForComparison ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: onSelect) {
                        Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                            .font(.title3)
                            .foregroundColor(isSelected ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                // Model Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(model.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        if model.isRecommended {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                        
                        Spacer()
                        
                        if let result = testResult {
                            TestScoreBadge(score: result.qualityScore)
                        }
                    }
                    
                    Text(model.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(isExpanded ? nil : 2)
                }
                
                // Actions
                VStack(spacing: 8) {
                    Button(action: onExpand) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                    
                    if testResult == nil {
                        Button("Test") {
                            onTest()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            
            // Expanded Details
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    // Capabilities
                    if model.capabilities.supportsChat || model.capabilities.supportsFunctionCalling {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Capabilities")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack {
                                if model.capabilities.supportsChat {
                                    CapabilityBadge(title: "Chat", icon: "bubble.left.and.bubble.right")
                                }
                                if model.capabilities.supportsFunctionCalling {
                                    CapabilityBadge(title: "Functions", icon: "function")
                                }
                                if model.capabilities.supportsVision {
                                    CapabilityBadge(title: "Vision", icon: "eye")
                                }
                            }
                        }
                    }
                    
                    // Specifications
                    HStack(spacing: 24) {
                        if let contextLength = model.contextLength {
                            SpecificationItem(
                                title: "Context",
                                value: "\(contextLength / 1000)K tokens",
                                icon: "doc.text"
                            )
                        }
                        
                        if let result = testResult {
                            SpecificationItem(
                                title: "Speed",
                                value: "\(String(format: "%.1f", result.responseTime))s",
                                icon: "speedometer"
                            )
                        }
                    }
                    
                    // Pricing
                    if let pricing = model.pricing {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pricing (per 1K tokens)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text("Input: $\(String(format: "%.4f", pricing.inputTokenPrice))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("Output: $\(String(format: "%.4f", pricing.outputTokenPrice))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.leading, 44)
                .transition(.opacity.combined(with: .slide))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isSelected || isSelectedForComparison ? Color.blue.opacity(0.5) : Color.clear,
                            lineWidth: 2
                        )
                )
        )
        .shadow(color: isSelected || isSelectedForComparison ? .blue.opacity(0.1) : .clear, radius: 4, x: 0, y: 2)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isExpanded)
    }
}

private struct TestPromptCard: View {
    let prompt: TestPrompt
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: prompt.category.icon)
                    .font(.subheadline)
                    .foregroundColor(prompt.category.color)
                
                Text(prompt.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            Text(prompt.prompt)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? prompt.category.color.opacity(0.1) : Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? prompt.category.color.opacity(0.5) : Color.clear, lineWidth: 1)
                )
        )
        .onTapGesture {
            onSelect()
        }
    }
}

private struct TestResultCard: View {
    let result: ModelTestResults
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(result.modelId)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                TestScoreBadge(score: result.qualityScore)
            }
            
            HStack(spacing: 24) {
                MetricItem(
                    title: "Response Time",
                    value: "\(String(format: "%.1f", result.responseTime))s",
                    icon: "clock"
                )
                
                MetricItem(
                    title: "Tokens Used",
                    value: "\(result.tokensUsed)",
                    icon: "text.alignleft"
                )
                
                if let cost = result.cost {
                    MetricItem(
                        title: "Cost",
                        value: "$\(String(format: "%.4f", cost))",
                        icon: "dollarsign.circle"
                    )
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Response Preview")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(result.testResponse)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray6))
                    )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

private struct TestScoreBadge: View {
    let score: Double
    
    private var scoreColor: Color {
        if score >= 0.8 {
            return .green
        } else if score >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
    
    var body: some View {
        Text("\(Int(score * 100))%")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(scoreColor)
            .clipShape(Capsule())
    }
}

private struct CapabilityBadge: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(.blue)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(Color.blue.opacity(0.1))
        )
    }
}

private struct SpecificationItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
    }
}

private struct MetricItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

private struct ComparisonModelCard: View {
    let model: OpenAIModelInfo
    let testResult: ModelTestResults?
    let onRemove: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(model.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            if let result = testResult {
                VStack(spacing: 6) {
                    HStack {
                        Text("Score:")
                        Spacer()
                        TestScoreBadge(score: result.qualityScore)
                    }
                    
                    HStack {
                        Text("Speed:")
                        Spacer()
                        Text("\(String(format: "%.1f", result.responseTime))s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .font(.caption)
            } else {
                Text("Not tested")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(width: 150)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlBackgroundColor))
        )
    }
}

private struct ModelRecommendationCard: View {
    let model: OpenAIModelInfo
    let testResult: ModelTestResults?
    let reasons: [String]
    let onSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recommended: \(model.name)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(model.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let result = testResult {
                    TestScoreBadge(score: result.qualityScore)
                }
            }
            
            if !reasons.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Why we recommend this model:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(reasons, id: \.self) { reason in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            
                            Text(reason)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Button("Select This Model") {
                onSelect()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.yellow.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

private struct ModelComparisonDetailView: View {
    let models: [OpenAIModelInfo]
    let testResults: [String: ModelTestResults]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Comparison Chart
            if !testResults.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Performance Comparison")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    // Score comparison
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quality Score")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(models, id: \.id) { model in
                            if let result = testResults[model.id] {
                                HStack {
                                    Text(model.name)
                                        .font(.caption)
                                        .frame(width: 100, alignment: .leading)
                                    
                                    ProgressView(value: result.qualityScore)
                                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                    
                                    Text("\(Int(result.qualityScore * 100))%")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .frame(width: 40, alignment: .trailing)
                                }
                            }
                        }
                    }
                    
                    // Speed comparison
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Response Speed")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(models, id: \.id) { model in
                            if let result = testResults[model.id] {
                                HStack {
                                    Text(model.name)
                                        .font(.caption)
                                        .frame(width: 100, alignment: .leading)
                                    
                                    let maxTime = testResults.values.map { $0.responseTime }.max() ?? 1.0
                                    let normalizedSpeed = 1.0 - (result.responseTime / maxTime)
                                    
                                    ProgressView(value: normalizedSpeed)
                                        .progressViewStyle(LinearProgressViewStyle(tint: .green))
                                    
                                    Text("\(String(format: "%.1f", result.responseTime))s")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .frame(width: 40, alignment: .trailing)
                                }
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
            
            // Detailed comparison table
            Text("Detailed Specifications")
                .font(.headline)
                .fontWeight(.bold)
            
            // Table implementation would go here
            // For now, showing basic info
            ForEach(models, id: \.id) { model in
                VStack(alignment: .leading, spacing: 12) {
                    Text(model.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if let result = testResults[model.id] {
                        HStack(spacing: 24) {
                            VStack(alignment: .leading) {
                                Text("Quality Score")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(Int(result.qualityScore * 100))%")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Speed")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(String(format: "%.1f", result.responseTime))s")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Tokens")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(result.tokensUsed)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.controlBackgroundColor))
                )
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
struct ModelTestingView_Previews: PreviewProvider {
    static var previews: some View {
        ModelTestingView(
            onContinue: { print("Continue") },
            onSkip: { print("Skip") },
            onBack: { print("Back") }
        )
        .frame(width: 800, height: 1200)
        .previewDisplayName("Model Testing")
    }
}
#endif