import Foundation
import os.log

final class Logger {
    static let shared = Logger()
    
    private let subsystem = "com.example.hello-prompt-adventurex"
    private let logger: os.Logger
    
    enum LogLevel: String, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        
        var osLogType: OSLogType {
            switch self {
            case .debug:
                return .debug
            case .info:
                return .info
            case .warning:
                return .default
            case .error:
                return .error
            }
        }
    }
    
    private init() {
        self.logger = os.Logger(subsystem: subsystem, category: "main")
    }
    
    func log(_ message: String, level: LogLevel = .info, category: String = "main", file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let formattedMessage = "[\(level.rawValue)] [\(fileName):\(line)] \(function): \(message)"
        
        logger.log(level: level.osLogType, "\(formattedMessage)")
        
        #if DEBUG
        print("\(Date()) \(formattedMessage)")
        #endif
    }
    
    func debug(_ message: String, category: String = "main", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }
    
    func info(_ message: String, category: String = "main", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, category: String = "main", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }
    
    func error(_ message: String, category: String = "main", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }
}