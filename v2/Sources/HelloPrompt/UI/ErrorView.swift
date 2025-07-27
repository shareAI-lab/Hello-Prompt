//
//  ErrorView.swift
//  Hello-Prompt
//
//  Created by Bai Cai on 26/7/2025.
//

import SwiftUI

// MARK: - Error Alert View
public struct ErrorAlert: View {
    let error: HelloPromptError
    let onDismiss: () -> Void
    let onRetry: (() -> Void)?
    
    public init(
        error: HelloPromptError,
        onDismiss: @escaping () -> Void,
        onRetry: (() -> Void)? = nil
    ) {
        self.error = error
        self.onDismiss = onDismiss
        self.onRetry = onRetry
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // 错误图标和标题
            HStack(spacing: 12) {
                Image(systemName: error.severity.icon)
                    .font(.title2)
                    .foregroundColor(error.severity.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(error.severity.description)
                        .font(.headline)
                        .foregroundColor(error.severity.color)
                    
                    Text("错误代码: \(error.errorCode)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // 错误描述
            Text(error.userMessage)
                .font(.body)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 恢复建议
            if case .userIntervention(let message) = error.recoveryStrategy {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.orange)
                    
                    Text(message)
                        .font(.callout)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            // 操作按钮
            HStack(spacing: 12) {
                Button("关闭") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
                
                if let onRetry = onRetry,
                   case .retry = error.recoveryStrategy {
                    Button("重试") {
                        onRetry()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 8)
        .frame(maxWidth: 400)
    }
}

// MARK: - Error Toast View
public struct ErrorToast: View {
    let error: HelloPromptError
    let onDismiss: () -> Void
    @State private var isVisible = false
    
    public init(error: HelloPromptError, onDismiss: @escaping () -> Void) {
        self.error = error
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: error.severity.icon)
                .foregroundColor(error.severity.color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(error.severity.description)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(error.severity.color)
                
                Text(error.userMessage)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 4)
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVisible)
        .onAppear {
            isVisible = true
            
            // 自动消失（除非是严重错误）
            if error.severity < .error {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    withAnimation {
                        isVisible = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onDismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Error Page View
public struct ErrorPageView: View {
    let error: HelloPromptError
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void
    
    public init(
        error: HelloPromptError,
        onRetry: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.error = error
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // 错误图标
            Image(systemName: error.severity.icon)
                .font(.system(size: 64))
                .foregroundColor(error.severity.color)
            
            // 错误信息
            VStack(spacing: 16) {
                Text(error.severity.description)
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(error.severity.color)
                
                Text(error.userMessage)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 32)
                
                Text("错误代码: \(error.errorCode)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 恢复建议
            if case .userIntervention(let message) = error.recoveryStrategy {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.orange)
                        Text("建议")
                            .font(.headline)
                            .foregroundColor(.orange)
                    }
                    
                    Text(message)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 32)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 24)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, 32)
            }
            
            // 操作按钮
            HStack(spacing: 16) {
                if let onRetry = onRetry,
                   case .retry = error.recoveryStrategy {
                    Button("重试") {
                        onRetry()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                
                Button("关闭") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}

// MARK: - Error Handler View Modifier
public struct ErrorHandlerModifier: ViewModifier {
    @ObservedObject private var errorHandler: ErrorHandler
    
    public init() {
        self.errorHandler = ErrorHandler.shared
    }
    @State private var showingErrorPage = false
    
    public func body(content: Content) -> some View {
        content
            .alert("错误", isPresented: $errorHandler.isShowingError) {
                if let error = errorHandler.currentError {
                    Button("关闭") {
                        errorHandler.dismissError()
                    }
                    
                    if case .retry = error.recoveryStrategy {
                        Button("重试") {
                            // 这里需要实现重试逻辑
                            errorHandler.dismissError()
                        }
                    }
                }
            } message: {
                if let error = errorHandler.currentError {
                    Text(error.userMessage)
                }
            }
            .sheet(isPresented: $showingErrorPage) {
                if let error = errorHandler.currentError {
                    ErrorPageView(
                        error: error,
                        onRetry: {
                            // 实现重试逻辑
                            showingErrorPage = false
                            errorHandler.dismissError()
                        },
                        onDismiss: {
                            showingErrorPage = false
                            errorHandler.dismissError()
                        }
                    )
                }
            }
            .onReceive(errorHandler.$currentError) { newError in
                if let error = newError, error.severity >= .error {
                    showingErrorPage = true
                }
            }
    }
}

// MARK: - View Extension
public extension View {
    /// 为视图添加错误处理支持
    func errorHandler() -> some View {
        modifier(ErrorHandlerModifier())
    }
}