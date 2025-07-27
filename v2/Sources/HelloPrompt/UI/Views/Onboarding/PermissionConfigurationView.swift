//
//  PermissionConfigurationView.swift
//  HelloPrompt
//
//  Modern permission configuration view with latest macOS APIs
//  Provides clear explanations and guided permission setup
//

import SwiftUI
import AVFoundation

// MARK: - Permission Configuration View
public struct PermissionConfigurationView: View {
    
    // MARK: - Properties
    @ObservedObject private var flowManager = OnboardingFlowManager.shared
    @ObservedObject private var permissionManager = PermissionManager.shared
    @State private var isRequestingPermissions = false
    @State private var showingDetailedGuide = false
    @State private var animatePermissions = false
    @State private var lastPermissionCheck = Date()
    
    // MARK: - Callbacks
    let onContinue: () -> Void
    let onSkip: () -> Void
    let onBack: () -> Void
    
    // MARK: - Permission Details
    private let permissions: [PermissionInfo] = [
        PermissionInfo(
            type: .microphone,
            title: "Microphone Access",
            description: "Required for voice recording and speech-to-text conversion",
            icon: "mic.fill",
            isRequired: true,
            whyNeeded: "HelloPrompt needs microphone access to record your voice and convert it to text using advanced speech recognition.",
            troubleshooting: [
                "Open System Preferences > Security & Privacy > Privacy",
                "Click on 'Microphone' in the left sidebar",
                "Ensure HelloPrompt is checked in the list",
                "If not listed, click the '+' button to add it"
            ]
        ),
        PermissionInfo(
            type: .accessibility,
            title: "Accessibility Access",
            description: "Enables global keyboard shortcuts and text insertion",
            icon: "lock.shield.fill",
            isRequired: true,
            whyNeeded: "Accessibility access allows HelloPrompt to detect keyboard shortcuts globally and insert optimized text into other applications.",
            troubleshooting: [
                "Open System Preferences > Security & Privacy > Privacy",
                "Click on 'Accessibility' in the left sidebar",
                "Click the lock icon and enter your password",
                "Check the box next to HelloPrompt",
                "You may need to restart the app after granting access"
            ]
        ),
        PermissionInfo(
            type: .notification,
            title: "Notification Access",
            description: "Shows status updates and completion notifications",
            icon: "bell.fill",
            isRequired: false,
            whyNeeded: "Notifications keep you informed about processing status, errors, and when your optimized prompts are ready.",
            troubleshooting: [
                "Open System Preferences > Notifications",
                "Find HelloPrompt in the list",
                "Ensure 'Allow Notifications' is enabled",
                "Configure your preferred notification style"
            ]
        )
    ]
    
    // MARK: - Main Body
    public var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                headerSection
                
                // Permission Status Overview
                permissionOverview
                
                // Individual Permission Cards
                permissionCards
                
                // Help Section
                helpSection
                
                // Action Buttons
                actionButtons
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
        }
        .background(backgroundGradient)
        .onAppear {
            startAnimations()
            checkPermissions()
            LogManager.shared.info("PermissionConfigurationView", "Permission configuration view appeared")
        }
        .sheet(isPresented: $showingDetailedGuide) {
            detailedPermissionGuide
        }
        .onChange(of: permissionManager.permissionStates) { _ in
            lastPermissionCheck = Date()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(animatePermissions ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animatePermissions)
            
            VStack(spacing: 12) {
                Text("Grant Permissions")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("HelloPrompt needs specific permissions to provide the best experience")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Progress Indicator
            PermissionProgressView(
                totalPermissions: permissions.count,
                grantedPermissions: grantedPermissionsCount,
                requiredPermissions: requiredPermissionsCount
            )
        }
    }
    
    // MARK: - Permission Overview
    private var permissionOverview: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Permission Status")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Refresh Status") {
                    checkPermissions()
                }
                .buttonStyle(.borderless)
                .foregroundColor(.blue)
                .font(.caption)
            }
            
            HStack(spacing: 24) {
                StatusIndicator(
                    title: "Required",
                    count: requiredPermissionsGrantedCount,
                    total: requiredPermissionsCount,
                    color: .red,
                    icon: "exclamationmark.triangle.fill"
                )
                
                StatusIndicator(
                    title: "Optional",
                    count: optionalPermissionsGrantedCount,
                    total: optionalPermissionsCount,
                    color: .blue,
                    icon: "info.circle.fill"
                )
                
                StatusIndicator(
                    title: "Overall",
                    count: grantedPermissionsCount,
                    total: permissions.count,
                    color: .green,
                    icon: "checkmark.circle.fill"
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
    
    // MARK: - Permission Cards
    private var permissionCards: some View {
        VStack(spacing: 16) {
            Text("Permission Details")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            LazyVStack(spacing: 12) {
                ForEach(Array(permissions.enumerated()), id: \.offset) { index, permission in
                    PermissionCard(
                        permission: permission,
                        status: getPermissionStatus(permission.type),
                        onRequest: {
                            requestPermission(permission.type)
                        },
                        onTroubleshoot: {
                            showTroubleshootingFor(permission)
                        }
                    )
                    .opacity(animatePermissions ? 1.0 : 0.0)
                    .offset(y: animatePermissions ? 0 : 20)
                    .animation(
                        .easeOut(duration: 0.5)
                        .delay(Double(index) * 0.1),
                        value: animatePermissions
                    )
                }
            }
        }
    }
    
    // MARK: - Help Section
    private var helpSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                
                Text("Need Help?")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HelpTip(
                    icon: "lightbulb.fill",
                    text: "You can change permissions later in System Preferences"
                )
                
                HelpTip(
                    icon: "arrow.clockwise",
                    text: "Restart HelloPrompt after granting accessibility access"
                )
                
                HelpTip(
                    icon: "gear",
                    text: "Some features may be limited without required permissions"
                )
            }
            
            Button("View Detailed Permission Guide") {
                showingDetailedGuide = true
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
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
            // Primary Actions
            HStack(spacing: 16) {
                // Request All Permissions
                Button(action: requestAllPermissions) {
                    HStack {
                        if isRequestingPermissions {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.title3)
                        }
                        
                        Text(isRequestingPermissions ? "Requesting..." : "Request All Permissions")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(isRequestingPermissions || allRequiredPermissionsGranted)
                
                // Test Permissions
                Button(action: testPermissions) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                        
                        Text("Test Permissions")
                            .font(.headline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isRequestingPermissions)
            }
            
            // Navigation Buttons
            HStack(spacing: 20) {
                Button("Back") {
                    onBack()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                if canProceed {
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
                Color.orange.opacity(0.02)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Detailed Permission Guide
    private var detailedPermissionGuide: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    Text("Detailed Permission Guide")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    ForEach(permissions, id: \.type) { permission in
                        DetailedPermissionSection(permission: permission)
                    }
                    
                    Spacer(minLength: 32)
                }
                .padding()
            }
            .navigationTitle("Permission Guide")
            .navigationBarItems(
                trailing: Button("Done") {
                    showingDetailedGuide = false
                }
            )
        }
    }
    
    // MARK: - Computed Properties
    private var grantedPermissionsCount: Int {
        permissions.filter { getPermissionStatus($0.type) == .granted }.count
    }
    
    private var requiredPermissionsCount: Int {
        permissions.filter { $0.isRequired }.count
    }
    
    private var requiredPermissionsGrantedCount: Int {
        permissions.filter { $0.isRequired && getPermissionStatus($0.type) == .granted }.count
    }
    
    private var optionalPermissionsCount: Int {
        permissions.filter { !$0.isRequired }.count
    }
    
    private var optionalPermissionsGrantedCount: Int {
        permissions.filter { !$0.isRequired && getPermissionStatus($0.type) == .granted }.count
    }
    
    private var allRequiredPermissionsGranted: Bool {
        requiredPermissionsGrantedCount == requiredPermissionsCount
    }
    
    private var canProceed: Bool {
        allRequiredPermissionsGranted
    }
    
    // MARK: - Methods
    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.8)) {
            animatePermissions = true
        }
    }
    
    private func checkPermissions() {
        Task {
            await permissionManager.checkAllPermissions(reason: "Onboarding permission check")
            LogManager.shared.info("PermissionConfigurationView", "Permission status refreshed")
        }
    }
    
    private func getPermissionStatus(_ type: PermissionType) -> PermissionStatus {
        return permissionManager.getPermissionStatus(type)
    }
    
    private func requestPermission(_ type: PermissionType) {
        Task {
            isRequestingPermissions = true
            let status = await permissionManager.requestPermission(type)
            isRequestingPermissions = false
            
            LogManager.shared.info("PermissionConfigurationView", "Requested \(type.rawValue) permission: \(status.statusText)")
        }
    }
    
    private func requestAllPermissions() {
        Task {
            isRequestingPermissions = true
            await flowManager.requestPermissions()
            isRequestingPermissions = false
            
            LogManager.shared.info("PermissionConfigurationView", "Requested all permissions")
        }
    }
    
    private func testPermissions() {
        Task {
            await checkPermissions()
            
            // Show test results
            let grantedCount = grantedPermissionsCount
            let totalCount = permissions.count
            
            let message = "Permission Test Complete\n\nGranted: \(grantedCount)/\(totalCount) permissions"
            
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Permission Test"
                alert.informativeText = message
                alert.alertStyle = grantedCount == totalCount ? .informational : .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
            
            LogManager.shared.info("PermissionConfigurationView", "Permission test completed: \(grantedCount)/\(totalCount)")
        }
    }
    
    private func showTroubleshootingFor(_ permission: PermissionInfo) {
        let alert = NSAlert()
        alert.messageText = "Troubleshooting: \(permission.title)"
        alert.informativeText = permission.troubleshooting.joined(separator: "\n\n")
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "OK")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openSystemPreferences(for: permission.type)
        }
    }
    
    private func openSystemPreferences(for type: PermissionType) {
        let prefPaneIdentifier: String
        
        switch type {
        case .microphone:
            prefPaneIdentifier = "com.apple.preference.security"
        case .accessibility:
            prefPaneIdentifier = "com.apple.preference.security"
        case .notification:
            prefPaneIdentifier = "com.apple.preference.notifications"
        }
        
        if let url = URL(string: "x-apple.systempreferences:\(prefPaneIdentifier)") {
            NSWorkspace.shared.open(url)
        }
        
        LogManager.shared.info("PermissionConfigurationView", "Opened system preferences for \(type.rawValue)")
    }
    
    // MARK: - Initialization
    public init(onContinue: @escaping () -> Void, onSkip: @escaping () -> Void, onBack: @escaping () -> Void) {
        self.onContinue = onContinue
        self.onSkip = onSkip
        self.onBack = onBack
    }
}

// MARK: - Supporting Data Types

private struct PermissionInfo {
    let type: PermissionType
    let title: String
    let description: String
    let icon: String
    let isRequired: Bool
    let whyNeeded: String
    let troubleshooting: [String]
}

// MARK: - Supporting Views

private struct PermissionProgressView: View {
    let totalPermissions: Int
    let grantedPermissions: Int
    let requiredPermissions: Int
    
    private var progress: Double {
        guard totalPermissions > 0 else { return 0 }
        return Double(grantedPermissions) / Double(totalPermissions)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Setup Progress")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(grantedPermissions)/\(totalPermissions)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                .scaleEffect(y: 2)
            
            if grantedPermissions < requiredPermissions {
                Text("Required permissions needed to continue")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else if grantedPermissions == totalPermissions {
                Text("All permissions granted!")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                Text("Ready to continue (optional permissions can be granted later)")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
    }
}

private struct StatusIndicator: View {
    let title: String
    let count: Int
    let total: Int
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            VStack(spacing: 2) {
                Text("\(count)/\(total)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.1))
        )
    }
}

private struct PermissionCard: View {
    let permission: PermissionInfo
    let status: PermissionStatus
    let onRequest: () -> Void
    let onTroubleshoot: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                // Permission Icon
                Image(systemName: permission.icon)
                    .font(.title2)
                    .foregroundColor(statusColor)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(statusColor.opacity(0.1))
                    )
                
                // Permission Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(permission.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        if permission.isRequired {
                            Text("REQUIRED")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(permission.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status Badge
                PermissionStatusBadge(status: status)
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                if status != .granted {
                    Button("Grant Permission") {
                        onRequest()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accentColor(statusColor)
                }
                
                Button("Troubleshoot") {
                    onTroubleshoot()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(statusColor.opacity(0.3), lineWidth: status == .granted ? 0 : 1)
                )
        )
        .shadow(color: status == .granted ? .green.opacity(0.1) : .clear, radius: 4, x: 0, y: 2)
    }
    
    private var statusColor: Color {
        switch status {
        case .granted:
            return .green
        case .denied:
            return .red
        case .unknown:
            return .gray
        }
    }
}

private struct PermissionStatusBadge: View {
    let status: PermissionStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.caption)
            
            Text(status.statusText)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor)
        .clipShape(Capsule())
    }
    
    private var statusColor: Color {
        switch status {
        case .granted:
            return .green
        case .denied:
            return .red
        case .unknown:
            return .gray
        }
    }
    
    private var iconName: String {
        switch status {
        case .granted:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
}

private struct HelpTip: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

private struct DetailedPermissionSection: View {
    let permission: PermissionInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: permission.icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text(permission.title)
                    .font(.title3)
                    .fontWeight(.bold)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Why This Permission is Needed")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(permission.whyNeeded)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text("How to Grant This Permission")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(permission.troubleshooting.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                            
                            Text(step)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
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
}

// MARK: - Preview
#if DEBUG
struct PermissionConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        PermissionConfigurationView(
            onContinue: { print("Continue") },
            onSkip: { print("Skip") },
            onBack: { print("Back") }
        )
        .frame(width: 800, height: 1000)
        .previewDisplayName("Permission Configuration")
    }
}
#endif