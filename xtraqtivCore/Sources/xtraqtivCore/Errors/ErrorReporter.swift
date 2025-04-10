import Foundation
import os.log

/// `ErrorReporter` provides centralized error reporting and logging functionality for the FRAQTIV application.
/// It supports multiple logging levels and destinations for error reports.
public final class ErrorReporter {
    
    // MARK: - Singleton Instance
    
    /// Shared instance of ErrorReporter
    public static let shared = ErrorReporter()
    
    // MARK: - Logging Levels
    
    /// Logging levels supported by the ErrorReporter
    public enum LogLevel: Int, Comparable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        case fatal = 4
        
        public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
        
        /// Returns the string representation of the log level
        var name: String {
            switch self {
            case .debug: return "DEBUG"
            case .info: return "INFO"
            case .warning: return "WARNING"
            case .error: return "ERROR"
            case .fatal: return "FATAL"
            }
        }
        
        /// Returns the OSLog type corresponding to this log level
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .fatal: return .fault
            }
        }
    }
    
    // MARK: - Reporting Destinations
    
    /// Destinations where error reports can be sent
    public struct ReportDestination: OptionSet {
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        /// Log to console
        public static let console = ReportDestination(rawValue: 1 << 0)
        /// Log to file
        public static let file = ReportDestination(rawValue: 1 << 1)
        /// Send to remote monitoring service
        public static let remote = ReportDestination(rawValue: 1 << 2)
        /// Default set of destinations (console only)
        public static let `default`: ReportDestination = [.console]
        /// All available destinations
        public static let all: ReportDestination = [.console, .file, .remote]
    }
    
    // MARK: - Properties
    
    /// The minimum log level that will be reported
    public var minimumLogLevel: LogLevel = .info
    
    /// The destinations where reports will be sent
    public var destinations: ReportDestination = .default
    
    /// Path to the log file if file logging is enabled
    public var logFilePath: URL? {
        didSet {
            createLogFileIfNeeded()
        }
    }
    
    /// URL for remote reporting service if enabled
    public var remoteReportingURL: URL?
    
    /// Whether to include extended debug information with error reports
    public var includeExtendedDebugInfo: Bool = true
    
    /// Maximum size of log file before rotation (in bytes)
    public var maxLogFileSize: Int = 10 * 1024 * 1024 // 10 MB
    
    /// Internal OS logger
    private let osLog: OSLog
    
    /// Serial queue for thread safety
    private let reportQueue = DispatchQueue(label: "com.fraqtiv.errorReporter", qos: .utility)
    
    /// File handle for log file if file logging is enabled
    private var logFileHandle: FileHandle?
    
    // MARK: - Initialization
    
    private init() {
        osLog = OSLog(subsystem: "com.fraqtiv.xtraqtiv", category: "ErrorReporting")
        
        // Default log file path in Documents directory
        if logFilePath == nil {
            let fileManager = FileManager.default
            if let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                logFilePath = documentDirectory.appendingPathComponent("xtraqtiv.log")
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Reports a debug message
    /// - Parameters:
    ///   - message: The debug message to report
    ///   - file: The file where the debug message originated
    ///   - function: The function where the debug message originated
    ///   - line: The line number where the debug message originated
    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        report(level: .debug, message: message, file: file, function: function, line: line)
    }
    
    /// Reports an informational message
    /// - Parameters:
    ///   - message: The info message to report
    ///   - file: The file where the info message originated
    ///   - function: The function where the info message originated
    ///   - line: The line number where the info message originated
    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        report(level: .info, message: message, file: file, function: function, line: line)
    }
    
    /// Reports a warning message
    /// - Parameters:
    ///   - message: The warning message to report
    ///   - file: The file where the warning originated
    ///   - function: The function where the warning originated
    ///   - line: The line number where the warning originated
    public func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        report(level: .warning, message: message, file: file, function: function, line: line)
    }
    
    /// Reports an error
    /// - Parameters:
    ///   - error: The error to report
    ///   - context: Additional context about the error
    ///   - file: The file where the error originated
    ///   - function: The function where the error originated
    ///   - line: The line number where the error originated
    public func error(_ error: Error, context: [String: Any]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        let message: String
        
        if let xtError = error as? XTError {
            message = xtError.errorDescription ?? "Unknown XTError"
        } else {
            message = error.localizedDescription
        }
        
        var contextInfo = ""
        if let context = context, !context.isEmpty {
            contextInfo = " - Context: \(context)"
        }
        
        report(level: .error, message: "\(message)\(contextInfo)", file: file, function: function, line: line, error: error)
    }
    
    /// Reports a custom error message
    /// - Parameters:
    ///   - message: The error message to report
    ///   - context: Additional context about the error
    ///   - file: The file where the error originated
    ///   - function: The function where the error originated
    ///   - line: The line number where the error originated
    public func error(_ message: String, context: [String: Any]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var contextInfo = ""
        if let context = context, !context.isEmpty {
            contextInfo = " - Context: \(context)"
        }
        
        report(level: .error, message: "\(message)\(contextInfo)", file: file, function: function, line: line)
    }
    
    /// Reports a fatal error
    /// - Parameters:
    ///   - error: The fatal error to report
    ///   - context: Additional context about the error
    ///   - file: The file where the fatal error originated
    ///   - function: The function where the fatal error originated
    ///   - line: The line number where the fatal error originated
    public func fatal(_ error: Error, context: [String: Any]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        let message: String
        
        if let xtError = error as? XTError {
            message = xtError.errorDescription ?? "Unknown XTError"
        } else {
            message = error.localizedDescription
        }
        
        var contextInfo = ""
        if let context = context, !context.isEmpty {
            contextInfo = " - Context: \(context)"
        }
        
        report(level: .fatal, message: "\(message)\(contextInfo)", file: file, function: function, line: line, error: error)
    }
    
    /// Reports a custom fatal error message
    /// - Parameters:
    ///   - message: The fatal error message to report
    ///   - context: Additional context about the error
    ///   - file: The file where the fatal error originated
    ///   - function: The function where the fatal error originated
    ///   - line: The line number where the fatal error originated
    public func fatal(_ message: String, context: [String: Any]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var contextInfo = ""
        if let context = context, !context.isEmpty {
            contextInfo = " - Context: \(context)"
        }
        
        report(level: .fatal, message: "\(message)\(contextInfo)", file: file, function: function, line: line)
    }
    
    // MARK: - Private Methods
    
    /// Central reporting method that handles reporting to all configured destinations
    /// - Parameters:
    ///   - level: The log level of the report
    ///   - message: The message to report
    ///   - file: The file where the report originated
    ///   - function: The function where the report originated
    ///   - line: The line number where the report originated
    ///   - error: The error object if applicable
    private func report(level: LogLevel, message: String, file: String, function: String, line: Int, error: Error? = nil) {
        // Skip if below minimum log level
        guard level >= minimumLogLevel else { return }
        
        // Extract filename from path
        let filename = (file as NSString).lastPathComponent
        
        // Format report
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let baseReport = "[\(timestamp)] [\(level.name)] [\(filename):\(line) \(function)] \(message)"
        
        // Get extended debug info if needed for error levels
        var extendedInfo = ""
        if includeExtendedDebugInfo && (level == .error || level == .fatal) {
            extendedInfo = "\n" + collectDebugInformation(error: error)
        }
        
        let fullReport = baseReport + extendedInfo
        
        // Report to all configured destinations on the serial queue
        reportQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Log to system console
            if self.destinations.contains(.console) {
                os_log("%{public}@", log: self.osLog, type: level.osLogType, fullReport)
                
                // For debug builds, also print to Swift console
                #if DEBUG
                print(fullReport)
                #endif
            }
            
            // Log to file
            if self.destinations.contains(.file) {
                self.writeToLogFile(fullReport)
            }
            
            // Send to remote service
            if self.destinations.contains(.remote) && (level == .error || level == .fatal) {
                self.sendToRemoteService(level: level, message: message, file: file, function: function, line: line, error: error)
            }
        }
    }
    
    /// Collects extended debug information
    /// - Parameter error: The error object if applicable
    /// - Returns: A string containing debug information
    private func collectDebugInformation(error: Error? = nil) -> String {
        var debugInfo = "--- Debug Information ---\n"
        
        // App information
        if let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            debugInfo += "App Version: \(appVersion) (\(buildNumber))\n"
        }
        
        // Device information
        let device = ProcessInfo.processInfo.hostName
        debugInfo += "Device: \(device)\n"
        
        // OS information
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        debugInfo += "OS Version: \(osVersion)\n"
        
        // Memory usage
        let memoryUsage = Int(ProcessInfo.processInfo.physicalFootprint / 1024 / 1024)
        debugInfo += "Memory Usage: \(memoryUsage) MB\n"
        
        // Free disk space
        if let freeSpace = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())[.systemFreeSize] as? Int64 {
            let freeSpaceMB = freeSpace / 1024 / 1024
            debugInfo += "Free Disk Space: \(freeSpaceMB) MB\n"
        }
        
        // Thread information
        debugInfo += "Thread: \(Thread.current.description)\n"
        
        // Error specific info
        if let error = error {
            debugInfo += "Error Type: \(type(of: error))\n"
            debugInfo += "Error Code: \(error is NSError ? (error as NSError).code : 0)\n"
            debugInfo += "Error Domain: \(error is NSError ? (error as NSError).domain : "N/A")\n"
            
            // User info for NSError
            if let nsError = error as NSError?, !nsError.userInfo.isEmpty {
                debugInfo += "Error UserInfo: \(nsError.userInfo)\n"
            }
        }
        
        // Stack trace (if possible)
        let symbols = Thread.callStackSymbols
        if !symbols.isEmpty {
            debugInfo += "\nStack Trace:\n"
            for (index, symbol) in symbols.enumerated() {
                debugInfo += "[\(index)] \(symbol)\n"
            }
        }
        
        return debugInfo
    }
    
    /// Creates the log file if it doesn't exist
    private func createLogFileIfNeeded() {
        guard let logFilePath = logFilePath else { return }
        
        let fileManager = FileManager.default
        
        // Close any existing file handle
        try? logFileHandle?.close()
        logFileHandle = nil
        
        // Create the log file if it doesn't exist
        if !fileManager.fileExists(atPath: logFilePath.path) {
            fileManager.createFile(atPath: logFilePath.path, contents: nil)
        }
        
        // Open the log file for writing
        do {
            logFileHandle = try FileHandle(forWritingTo: logFilePath)
            try logFileHandle?.seekToEnd()
        } catch {
            os_log("Failed to open log file: %{public}@", log: osLog, type: .error, error.localizedDescription)
        }
    }
    
    /// Writes a log entry to the log file
    /// - Parameter message: The message to write to the log file
    private func writeToLogFile(_ message: String) {
        guard let logFilePath = logFilePath, let logFileHandle = logFileHandle else {
            createLogFileIfNeeded()
            return
        }
        
        // Check if the log file needs rotation
        checkLogFileRotation()
        
        // Write the message to the log file
        if let data = (message + "\n").data(using: .utf8) {
            do {
                try logFileHandle.write(contentsOf: data)
                try logFileHandle.synchronize()
            } catch {
                os_log("Failed to write to log file: %{public}@", log: osLog, type: .error, error.localizedDescription)
                
                // Attempt to recreate the log file on error
                createLogFileIfNeeded()
            }
        }
    }
    
    /// Checks if the log file needs rotation and rotates it if necessary
    private func checkLogFileRotation() {
        guard let logFilePath = logFilePath else { return }
        
        let fileManager = FileManager.default
        
        do {
            // Get the attributes of the log file
            let attributes = try fileManager.attributesOfItem(atPath: logFilePath.path)
            
            // Get the file size
            if let fileSize = attributes[.size] as? Int, fileSize > maxLogFileSize {
                // Close the current file handle
                try logFileHandle?.close()
                logFileHandle = nil
                
                // Create a backup file name with timestamp
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
                let timestamp = dateFormatter.string(from: Date())
                let backupPath = logFilePath.deletingLastPathComponent()
                    .appendingPathComponent(logFilePath.deletingPathExtension().lastPathComponent + "-\(timestamp)")
                    .appendingPathExtension(logFilePath.pathExtension)
                
                // Rename the current log file to the backup name
                try fileManager.moveItem(at: logFilePath, to: backupPath)
                
                // Create a new log file
                createLogFileIfNeeded()
                
                // Clean up old log files if there are too many
                cleanupOldLogFiles()
            }
        } catch {
            os_log("Failed to check log file size: %{public}@", log: osLog, type: .error, error.localizedDescription)
        }
    }
    
    /// Cleans up old log files, keeping only the most recent ones
    private func cleanupOldLogFiles() {
        guard let logFilePath = logFilePath else { return }
        
        let fileManager = FileManager.default
        let logDirectory = logFilePath.deletingLastPathComponent()
        let logFilePrefix = logFilePath.deletingPathExtension().lastPathComponent
        let logFileExtension = logFilePath.pathExtension
        
        do {
            // Get all files in the log directory
            let fileURLs = try fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles])
            
            // Filter to find backup log files
            let logBackups = fileURLs.filter { url in
                let filename = url.deletingPathExtension().lastPathComponent
                return filename.hasPrefix(logFilePrefix) && 
                       filename != logFilePrefix && 
                       url.pathExtension == logFileExtension
            }
            
            // Sort by creation date (oldest first)
            let sortedLogBackups = try logBackups.sorted { url1, url2 in
                let date1 = try url1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                let date2 = try url2.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                return date1 < date2
            }
            
            // Keep only the 5 most recent backups, delete the rest
            let maxBackupFiles = 5
            if sortedLogBackups.count > maxBackupFiles {
                for i in 0..<(sortedLogBackups.count - maxBackupFiles) {
                    try fileManager.removeItem(at: sortedLogBackups[i])
                }
            }
        } catch {
            os_log("Failed to clean up old log files: %{public}@", log: osLog, type: .error, error.localizedDescription)
        }
    }
    
    /// Sends an error report to a remote service
    /// - Parameters:
    ///   - level: The log level of the report
    ///   - message: The message to report
    ///   - file: The file where the report originated
    ///   - function: The function where the report originated
    ///   - line: The line number where the report originated
    ///   - error: The error object if applicable
    private func sendToRemoteService(level: LogLevel, message: String, file: String, function: String, line: Int, error: Error? = nil) {
        guard let remoteURL = remoteReportingURL else { return }
        
        // Create a dictionary with error information
        var errorData: [String: Any] = [
            "level": level.name,
            "message": message,
            "file": file,
            "function": function,
            "line": line,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        // Add app information
        if let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            errorData["appVersion"] = "\(appVersion) (\(buildNumber))"
        }
        
        // Add system information
        errorData["device"] = ProcessInfo.processInfo.hostName
        errorData["osVersion"] = ProcessInfo.processInfo.operatingSystemVersionString
        
        // Add error specific information
        if let error = error {
            errorData["errorType"] = String(describing: type(of: error))
            
            if let nsError = error as NSError? {
                errorData["errorCode"] = nsError.code
                errorData["errorDomain"] = nsError.domain
                
                if !nsError.userInfo.isEmpty {
                    // Convert userInfo to a dictionary with string keys and string values
                    var userInfoStrings: [String: String] = [:]
                    for (key, value) in nsError.userInfo {
                        userInfoStrings[key.description] = String(describing: value)
                    }
                    errorData["errorUserInfo"] = userInfoStrings
                }
            }
            
            // Add localized description
            errorData["errorDescription"] = error.localizedDescription
        }
        
        // Create the request
        var request = URLRequest(url: remoteURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            // Convert the error data to JSON
            let jsonData = try JSONSerialization.data(withJSONObject: errorData)
            request.httpBody = jsonData
            
            // Send the request
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    os_log("Failed to send error to remote service: %{public}@", log: self.osLog, type: .error, error.localizedDescription)
                    return
                }
                
                // Check the response
                if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                    os_log("Remote service returned non-success status code: %d", log: self.osLog, type: .error, httpResponse.statusCode)
                    return
                }
                
                os_log("Successfully sent error report to remote service", log: self.osLog, type: .debug)
            }
            
            task.resume()
            
        } catch {
            os_log("Failed to serialize error data: %{public}@", log: osLog, type: .error, error.localizedDescription)
        }
    }
    
    /// Flushes any pending log messages
    public func flush() {
        reportQueue.sync {
            try? logFileHandle?.synchronize()
        }
    }
    
    /// Deinitializer to clean up resources
    deinit {
        flush()
        
        // Close the log file handle
        reportQueue.sync {
            try? logFileHandle?.close()
            logFileHandle = nil
        }
    }
}
