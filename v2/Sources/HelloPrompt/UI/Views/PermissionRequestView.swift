//
//  PermissionRequestView.swift
//  HelloPrompt
//
//  权限申请界面 - 引导用户授权必要的系统权限
//  包含辅助功能权限、麦克风权限的申请和状态检查
//

import SwiftUI
import AVFAudio
import AVFoundation
import ApplicationServices

// MARK: - 权限申请视图
public struct PermissionRequestView: View {
    
    // MARK: - 权限管理器
    @StateObject private var permissionManager = PermissionManager.shared
    
    // MARK: - 状态属性
    @State private var isCheckingPermissions = false
    
    // MARK: - 回调
    let onPermissionsGranted: () -> Void
    let onSkipped: () -> Void
    
    // MARK: - 初始化
    public init(
        onPermissionsGranted: @escaping () -> Void,
        onSkipped: @escaping () -> Void
    ) {
        self.onPermissionsGranted = onPermissionsGranted
        self.onSkipped = onSkipped
    }
    
    // MARK: - 主视图
    public var body: some View {
        VStack(spacing: 30) {
            // 标题
            VStack(spacing: 10) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
                
                Text("权限申请")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Hello Prompt v2 需要以下权限来正常工作")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // 权限列表
            VStack(spacing: 20) {
                ForEach(PermissionType.allCases, id: \.self) { type in
                    permissionRow(for: type)
                }
            }
            .padding(.horizontal, 20)
            
            // 操作按钮
            VStack(spacing: 12) {
                Button("检查权限状态") {
                    Task {
                        await permissionManager.immediatePermissionCheck()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(permissionManager.isCheckingPermissions)
                
                HStack(spacing: 20) {
                    if permissionManager.allPermissionsGranted {
                        Button("继续") {
                            onPermissionsGranted()
                        }
                        .buttonStyle(.borderedProminent)
                    } else if permissionManager.corePermissionsGranted {
                        Button("使用基础功能") {
                            onPermissionsGranted()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    Button("稍后设置") {
                        onSkipped()
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // 权限建议
            if !permissionManager.getPermissionSuggestions().isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("权限建议")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    ForEach(permissionManager.getPermissionSuggestions(), id: \.self) { suggestion in
                        Text("• \(suggestion)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(.horizontal, 20)
            }
            
            // 状态指示
            if permissionManager.isCheckingPermissions {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("检查权限状态中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(40)
        .frame(width: 500, height: 600)
        .onAppear {
            Task {
                await permissionManager.immediatePermissionCheck()
            }
        }
        .onChange(of: permissionManager.allPermissionsGranted) { allGranted in
            if allGranted {
                // 所有权限已授权，自动关闭窗口
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onPermissionsGranted()
                }
            }
        }
        .onChange(of: permissionManager.corePermissionsGranted) { coreGranted in
            if coreGranted {
                // 核心权限已授权，检查是否需要关闭窗口
                Task {
                    await permissionManager.immediatePermissionCheck()
                }
            }
        }
    }
    
    // MARK: - 权限行视图
    private func permissionRow(for type: PermissionType) -> some View {
        let status = permissionManager.getPermissionStatus(type)
        
        return HStack(spacing: 15) {
            // 图标
            Image(systemName: type.icon)
                .font(.title2)
                .foregroundColor(type.isRequired ? .blue : .secondary)
                .frame(width: 30)
            
            // 内容
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(type.rawValue)
                        .font(.headline)
                    
                    if type.isRequired {
                        Text("必需")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                }
                
                Text(type.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // 状态和按钮
            VStack(alignment: .trailing, spacing: 8) {
                HStack {
                    Circle()
                        .fill(status.statusColor)
                        .frame(width: 8, height: 8)
                    
                    Text(status.statusText)
                        .font(.caption)
                        .foregroundColor(status.statusColor)
                }
                
                if status != .granted {
                    Button("授权") {
                        Task {
                            _ = await permissionManager.requestPermission(type)
                            
                            // 无论成功与否，都立即检查权限状态
                            await permissionManager.immediatePermissionCheck()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(permissionManager.currentPermissionRequest == type)
                }
            }
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(status == .granted ? Color.green.opacity(0.3) : Color.clear, lineWidth: 2)
                )
        )
    }
}

// MARK: - 预览
#if DEBUG
struct PermissionRequestView_Previews: PreviewProvider {
    static var previews: some View {
        PermissionRequestView(
            onPermissionsGranted: {
                print("All permissions granted!")
            },
            onSkipped: {
                print("Permission request skipped")
            }
        )
        .previewDisplayName("权限申请界面")
    }
}
#endif