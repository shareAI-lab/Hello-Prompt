//
//  UIModels.swift
//  HelloPrompt
//
//  UI相关的数据模型定义
//  包含覆盖层、操作、状态等UI组件使用的类型
//

import Foundation
import SwiftUI

// MARK: - 覆盖层结果
public struct OverlayResult {
    public let originalText: String
    public let optimizedText: String
    public let improvements: [String]
    public let processingTime: TimeInterval
    public let context: String?
    public let wordCount: Int
    public let characterCount: Int
    public let confidence: Double
    public let timestamp: Date
    
    public init(
        originalText: String,
        optimizedText: String,
        improvements: [String] = [],
        processingTime: TimeInterval = 0.0,
        context: String? = nil,
        confidence: Double = 1.0,
        timestamp: Date = Date()
    ) {
        self.originalText = originalText
        self.optimizedText = optimizedText
        self.improvements = improvements
        self.processingTime = processingTime
        self.context = context
        self.confidence = confidence
        self.timestamp = timestamp
        
        // 计算字数和字符数
        self.wordCount = optimizedText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        self.characterCount = optimizedText.count
    }
}

// MARK: - 覆盖层操作
public enum OverlayAction: String, CaseIterable, Identifiable {
    case copy = "复制"
    case paste = "粘贴"
    case edit = "编辑"
    case save = "保存"
    case share = "分享"
    case retry = "重试"
    case optimize = "重新优化"
    case cancel = "取消"
    case accept = "接受"
    case reject = "拒绝"
    case insert = "插入"
    case modify = "修改"
    case regenerate = "重新生成"
    case close = "关闭"
    
    public var id: String { rawValue }
    
    var systemImage: String {
        switch self {
        case .copy: return "doc.on.doc"
        case .paste: return "doc.on.clipboard"
        case .edit: return "pencil"
        case .save: return "square.and.arrow.down"
        case .share: return "square.and.arrow.up"
        case .retry: return "arrow.clockwise"
        case .optimize: return "wand.and.rays"
        case .cancel: return "xmark"
        case .accept: return "checkmark"
        case .reject: return "xmark.circle"
        case .insert: return "doc.badge.plus"
        case .modify: return "pencil.and.outline"
        case .regenerate: return "arrow.triangle.2.circlepath"
        case .close: return "xmark.circle.fill"
        }
    }
    
    var icon: String {
        return systemImage
    }
    
    var color: Color {
        switch self {
        case .copy, .paste: return .blue
        case .edit: return .orange
        case .save: return .green
        case .share: return .purple
        case .retry, .optimize, .regenerate: return .blue
        case .cancel, .reject, .close: return .red
        case .accept: return .green
        case .insert: return .green
        case .modify: return .orange
        }
    }
    
    var keyboardShortcut: KeyEquivalent {
        switch self {
        case .copy: return "c"
        case .paste: return "v"
        case .edit: return "e"
        case .save: return "s"
        case .retry: return "r"
        case .cancel, .close: return .escape
        case .accept: return .return
        case .insert: return "i"
        case .modify: return "m"
        case .regenerate: return "g"
        default: return " "
        }
    }
    
    var modifiers: EventModifiers {
        switch self {
        case .copy, .paste, .edit, .save, .insert, .modify: return .command
        case .retry, .regenerate: return [.command, .shift]
        default: return []
        }
    }
}

// MARK: - 窗口配置
public struct WindowConfiguration {
    public let title: String
    public let size: CGSize
    public let position: WindowPosition
    public let style: WindowStyle
    public let behavior: WindowBehavior
    public let animation: WindowAnimation?
    
    public init(
        title: String,
        size: CGSize = CGSize(width: 800, height: 600),
        position: WindowPosition = .center,
        style: WindowStyle = .default,
        behavior: WindowBehavior = .default,
        animation: WindowAnimation? = nil
    ) {
        self.title = title
        self.size = size
        self.position = position
        self.style = style
        self.behavior = behavior
        self.animation = animation
    }
    
    // 窗口位置
    public enum WindowPosition {
        case center
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
        case custom(CGPoint)
        case followMouse
        case followCursor
    }
    
    // 窗口样式
    public enum WindowStyle {
        case `default`
        case overlay
        case hudWindow
        case panel
        case sheet
        case popover
        case fullScreen
    }
    
    // 窗口行为
    public struct WindowBehavior {
        public let isResizable: Bool
        public let isMovable: Bool
        public let canHide: Bool
        public let canMinimize: Bool
        public let canClose: Bool
        public let alwaysOnTop: Bool
        public let hideOnDeactivate: Bool
        public let showInTaskbar: Bool
        
        public init(
            isResizable: Bool = true,
            isMovable: Bool = true,
            canHide: Bool = true,
            canMinimize: Bool = true,
            canClose: Bool = true,
            alwaysOnTop: Bool = false,
            hideOnDeactivate: Bool = false,
            showInTaskbar: Bool = true
        ) {
            self.isResizable = isResizable
            self.isMovable = isMovable
            self.canHide = canHide
            self.canMinimize = canMinimize
            self.canClose = canClose
            self.alwaysOnTop = alwaysOnTop
            self.hideOnDeactivate = hideOnDeactivate
            self.showInTaskbar = showInTaskbar
        }
        
        public static let `default` = WindowBehavior()
        public static let overlay = WindowBehavior(
            isResizable: false,
            canMinimize: false,
            alwaysOnTop: true,
            hideOnDeactivate: true,
            showInTaskbar: false
        )
    }
    
    // 窗口动画
    public struct WindowAnimation {
        public let appearAnimation: Animation?
        public let disappearAnimation: Animation?
        public let resizeAnimation: Animation?
        public let moveAnimation: Animation?
        
        public init(
            appearAnimation: Animation? = .easeInOut(duration: 0.3),
            disappearAnimation: Animation? = .easeInOut(duration: 0.2),
            resizeAnimation: Animation? = .spring(),
            moveAnimation: Animation? = .easeInOut(duration: 0.25)
        ) {
            self.appearAnimation = appearAnimation
            self.disappearAnimation = disappearAnimation
            self.resizeAnimation = resizeAnimation
            self.moveAnimation = moveAnimation
        }
        
        public static let `default` = WindowAnimation()
        public static let fast = WindowAnimation(
            appearAnimation: .easeInOut(duration: 0.15),
            disappearAnimation: .easeInOut(duration: 0.1),
            resizeAnimation: .easeInOut(duration: 0.2),
            moveAnimation: .easeInOut(duration: 0.15)
        )
        public static let smooth = WindowAnimation(
            appearAnimation: .spring(response: 0.6, dampingFraction: 0.8),
            disappearAnimation: .easeInOut(duration: 0.3),
            resizeAnimation: .spring(response: 0.5, dampingFraction: 0.9),
            moveAnimation: .spring(response: 0.4, dampingFraction: 0.85)
        )
    }
}

// MARK: - 主题配置
public struct ThemeConfiguration {
    public let name: String
    public let colorScheme: ColorScheme
    public let primaryColor: Color
    public let secondaryColor: Color
    public let backgroundColor: Color
    public let textColor: Color
    public let accentColor: Color
    public let fonts: FontConfiguration
    public let corners: CornerConfiguration
    public let shadows: ShadowConfiguration
    
    public init(
        name: String,
        colorScheme: ColorScheme = .dark,
        primaryColor: Color = .blue,
        secondaryColor: Color = .purple,
        backgroundColor: Color = Color(.windowBackgroundColor),
        textColor: Color = Color(.labelColor),
        accentColor: Color = .blue,
        fonts: FontConfiguration = .default,
        corners: CornerConfiguration = .default,
        shadows: ShadowConfiguration = .default
    ) {
        self.name = name
        self.colorScheme = colorScheme
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.accentColor = accentColor
        self.fonts = fonts
        self.corners = corners
        self.shadows = shadows
    }
    
    // 字体配置
    public struct FontConfiguration {
        public let title: Font
        public let headline: Font
        public let body: Font
        public let caption: Font
        public let code: Font
        
        public init(
            title: Font = .largeTitle.weight(.bold),
            headline: Font = .headline.weight(.semibold),
            body: Font = .body,
            caption: Font = .caption,
            code: Font = .system(.body, design: .monospaced)
        ) {
            self.title = title
            self.headline = headline
            self.body = body
            self.caption = caption
            self.code = code
        }
        
        public static let `default` = FontConfiguration()
    }
    
    // 圆角配置
    public struct CornerConfiguration {
        public let small: CGFloat
        public let medium: CGFloat
        public let large: CGFloat
        
        public init(small: CGFloat = 4, medium: CGFloat = 8, large: CGFloat = 16) {
            self.small = small
            self.medium = medium
            self.large = large
        }
        
        public static let `default` = CornerConfiguration()
    }
    
    // 阴影配置
    public struct ShadowConfiguration {
        public let small: ShadowStyle
        public let medium: ShadowStyle
        public let large: ShadowStyle
        
        public init(
            small: ShadowStyle = ShadowStyle(color: .black.opacity(0.1), radius: 2, x: 0, y: 1),
            medium: ShadowStyle = ShadowStyle(color: .black.opacity(0.15), radius: 8, x: 0, y: 4),
            large: ShadowStyle = ShadowStyle(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
        ) {
            self.small = small
            self.medium = medium
            self.large = large
        }
        
        public static let `default` = ShadowConfiguration()
    }
    
    public struct ShadowStyle {
        public let color: Color
        public let radius: CGFloat
        public let x: CGFloat
        public let y: CGFloat
        
        public init(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            self.color = color
            self.radius = radius
            self.x = x
            self.y = y
        }
    }
}

// MARK: - 通知配置
public struct NotificationConfiguration {
    public let title: String
    public let message: String
    public let type: NotificationType
    public let duration: TimeInterval
    public let position: NotificationPosition
    public let actions: [NotificationAction]
    public let sound: NotificationSound?
    
    public init(
        title: String,
        message: String,
        type: NotificationType = .info,
        duration: TimeInterval = 3.0,
        position: NotificationPosition = .topRight,
        actions: [NotificationAction] = [],
        sound: NotificationSound? = nil
    ) {
        self.title = title
        self.message = message
        self.type = type
        self.duration = duration
        self.position = position
        self.actions = actions
        self.sound = sound
    }
    
    // 通知类型
    public enum NotificationType: String, CaseIterable {
        case info = "信息"
        case success = "成功"
        case warning = "警告"
        case error = "错误"
        
        var icon: String {
            switch self {
            case .info: return "info.circle"
            case .success: return "checkmark.circle"
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            }
        }
    }
    
    // 通知位置
    public enum NotificationPosition: String, CaseIterable {
        case topLeft = "左上"
        case topCenter = "上中"
        case topRight = "右上"
        case centerLeft = "左中"
        case center = "中央"
        case centerRight = "右中"
        case bottomLeft = "左下"
        case bottomCenter = "下中"
        case bottomRight = "右下"
    }
    
    // 通知操作
    public struct NotificationAction {
        public let title: String
        public let action: () -> Void
        public let style: ActionStyle
        
        public init(title: String, style: ActionStyle = .default, action: @escaping () -> Void) {
            self.title = title
            self.action = action
            self.style = style
        }
        
        public enum ActionStyle {
            case `default`
            case primary
            case destructive
        }
    }
    
    // 通知声音
    public enum NotificationSound: String, CaseIterable {
        case none = "无"
        case `default` = "默认"
        case glass = "玻璃"
        case hero = "英雄"
        case input = "输入"
        case tink = "叮"
        case pop = "弹出"
        
        var systemSoundName: String? {
            switch self {
            case .none: return nil
            case .default: return "NSSystemSoundID.DefaultSound"
            case .glass: return "Glass"
            case .hero: return "Hero"
            case .input: return "Tink"
            case .tink: return "Tink"
            case .pop: return "Pop"
            }
        }
    }
}

// MARK: - 预设主题
extension ThemeConfiguration {
    public static let light = ThemeConfiguration(
        name: "浅色",
        colorScheme: .light,
        primaryColor: .blue,
        secondaryColor: .purple,
        backgroundColor: Color(.windowBackgroundColor),
        textColor: Color(.labelColor)
    )
    
    public static let dark = ThemeConfiguration(
        name: "深色",
        colorScheme: .dark,
        primaryColor: .blue,
        secondaryColor: .purple,
        backgroundColor: Color(.windowBackgroundColor),
        textColor: Color(.labelColor)
    )
    
    public static let siri = ThemeConfiguration(
        name: "Siri风格",
        colorScheme: .dark,
        primaryColor: .blue,
        secondaryColor: .purple,
        backgroundColor: .black.opacity(0.8),
        textColor: .white,
        accentColor: .blue
    )
}