import Foundation
import Combine
import OSLog

/// `LogManager` provides centralized logging capabilities with support for multiple
/// destinations, log levels, filtering, and structured metadata.
public final class LogManager {
    
    // MARK: - Types and Constants
    
    /// Log level, used to filter logs by severity
    public enum LogLevel: Int, Comparable, CustomStringConvertible {
        /// Verbose debugging information (only for development)
        case debug = 0
        /// Informational messages about normal operation
        case info = 1
        /// Warning conditions that might need attention
        case warning = 2
        /// Error conditions that prevent normal operation
        case error = 3
        /// Critical errors that might lead to application crash
        case critical = 4
        
        /// The string representation of the log level
        public var description: String {
            switch self {
            case .debug: return "DEBUG"
            case .info: return "INFO"
            case .warning: return "WARNING"
            case .error: return "ERROR"
            case .critical: return "CRITICAL"
            }
        }
        
        /// The emoji representation of the log level (for visual identification)
        public var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .critical: return "🔥"
            }
        }
        
        /// Compare log levels
        public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    /// A log entry representing a single log message
    public struct LogEntry: Codable {
        /// Unique identifier for the log entry
        public let id: UUID
        /// The timestamp when the log was created
        public let timestamp: Date
        /// The log level
        public let level: LogLevel
        /// The source of the log (file, function, line)
        public let source: LogSource
        /// The log message
        public let message: String
        /// Additional metadata associated with the log
        public let metadata: [String: String]?
        /// Error information (if applicable)
        public let error: LogError?
        
        /// Creates a new log entry
        /// - Parameters:
        ///   - level: The log level
        ///   - message: The log message
        ///   - source: The source of the log
        ///   - metadata: Additional metadata
        ///   - error: Error information
        public init(
            level: LogLevel,
            message: String,
            source: LogSource,
            metadata: [String: String]? = nil,
            error: LogError? = nil
        ) {
            self.id = UUID()
            self.timestamp = Date()
            self.level = level
            self.message = message
            self.source = source
            self.metadata = metadata
            self.error = error
        }
        
        /// The formatted log message for display
        public var formattedMessage: String {
            var components = [String]()
            
            // Add timestamp
            let dateFormatter = ISO8601DateFormatter()
            components.append("[\(dateFormatter.string(from: timestamp))]")
            
            // Add level
            components.append("[\(level.emoji) \(level.description)]")
            
            // Add source
            components.append("[\(source.file):\(source.line) \(source.function)]")
            
            // Add message
            components.append(message)
            
            // Add error information if available
            if let error = error {
                components.append("Error: \(error.message) (\(error.code))")
                if let stackTrace = error.stackTrace {
                    components.append("Stack trace: \(stackTrace)")
                }
            }
            
            // Add metadata if available
            if let metadata = metadata, !metadata.isEmpty {
                let metadataStr = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
                components.append("Metadata: {\(metadataStr)}")
            }
            
            return components.joined(separator: " ")
        }
        
        /// The log entry as a JSON object
        public var asJSON: [String: Any] {
            var json: [String: Any] = [
                "id": id.uuidString,
                "timestamp": ISO8601DateFormatter().string(from: timestamp),
                "level": level.description,
                "message": message,
                "source": [
                    "file": source.file,
                    "function": source.function,
                    "line": source.line
                ]
            ]
            
            if let metadata = metadata {
                json["metadata"] = metadata
            }
            
            if let error = error {
                var errorDict: [String: Any] = [
                    "message": error.message,
                    "code": error.code
                ]
                if let domain = error.domain {
                    errorDict["domain"] = domain
                }
                if let stackTrace = error.stackTrace {
                    errorDict["stackTrace"] = stackTrace
                }
                json["error"] = errorDict
            }
            
            return json
        }
    }
    
    /// Source information for a log entry
    public struct LogSource: Codable, Equatable {
        /// The file name
        public let file: String
        /// The function name
        public let function: String
        /// The line number
        public let line: Int
        
        /// Creates a new log source
        /// - Parameters:
        ///   - file: The file name
        ///   - function: The function name
        ///   - line: The line number
        public init(file: String, function: String, line: Int) {
            // Extract just the file name from the path
            if let lastPathComponent = file.components(separatedBy: "/").last {
                self.file = lastPathComponent
            } else {
                self.file = file
            }
            self.function = function
            self.line = line
        }
    }
    
    /// Error information for a log entry
    public struct LogError: Codable, Equatable {
        /// The error message
        public let message: String
        /// The error code
        public let code: Int
        /// The error domain (optional)
        public let domain: String?
        /// The stack trace (optional)
        public let stackTrace: String?
        
        /// Creates a new log error
        /// - Parameters:
        ///   - message: The error message
        ///   - code: The error code
        ///   - domain: The error domain
        ///   - stackTrace: The stack trace
        public init(
            message: String,
            code: Int,
            domain: String? = nil,
            stackTrace: String? = nil
        ) {
            self.message = message
            self.code = code
            self.domain = domain
            self.stackTrace = stackTrace
        }
        
        /// Creates a log error from an Error object
        /// - Parameter error: The error
        /// - Returns: A log error
        public static func from(_ error: Error) -> LogError {
            if let xtError = error as? XTError {
                return LogError(
                    message: xtError.localizedDescription,
                    code: xtError.code,
                    domain: xtError.domain.rawValue,
                    stackTrace: Thread.callStackSymbols.joined(separator: "\n")
                )
            } else {
                let nsError = error as NSError
                return LogError(
                    message: nsError.localizedDescription,
                    code: nsError.code,
                    domain: nsError.domain,
                    stackTrace: Thread.callStackSymbols.joined(separator: "\n")
                )
            }
        }
    }
    
    /// Log destination protocol for receiving log entries
    public protocol LogDestination {
        /// The minimum log level accepted by this destination
        var minimumLevel: LogLevel { get set }
        
        /// Filters that determine which logs are accepted
        var filters: [LogFilter] { get set }
        
        /// Processes a log entry
        /// - Parameter entry: The log entry to process
        func process(entry: LogEntry)
        
        /// Flushes any buffered logs
        func flush()
        
        /// Cleans up resources used by the destination
        func cleanup()
    }
    
    /// Console log destination that outputs to stdout/stderr
    public class ConsoleLogDestination: LogDestination {
        /// The minimum log level accepted by this destination
        public var minimumLevel: LogLevel
        
        /// Filters that determine which logs are accepted
        public var filters: [LogFilter]
        
        /// Whether to use emoji in console output
        public let useEmoji: Bool
        
        /// Whether to output in color (when supported)
        public let useColor: Bool
        
        /// Creates a new console log destination
        /// - Parameters:
        ///   - minimumLevel: The minimum log level
        ///   - filters: Log filters
        ///   - useEmoji: Whether to use emoji
        ///   - useColor: Whether to use color
        public init(
            minimumLevel: LogLevel = .debug,
            filters: [LogFilter] = [],
            useEmoji: Bool = true,
            useColor: Bool = true
        ) {
            self.minimumLevel = minimumLevel
            self.filters = filters
            self.useEmoji = useEmoji
            self.useColor = useColor
        }
        
        /// Processes a log entry
        /// - Parameter entry: The log entry to process
        public func process(entry: LogEntry) {
            // Skip logs below minimum level
            guard entry.level >= minimumLevel else { return }
            
            // Apply filters
            for filter in filters {
                if !filter.shouldInclude(entry: entry) {
                    return
                }
            }
            
            // Format the log entry
            let formattedLog = formatLog(entry: entry)
            
            // Output to appropriate stream based on level
            if entry.level >= .error {
                fputs("\(formattedLog)\n", stderr)
            } else {
                print(formattedLog)
            }
        }
        
        /// Formats a log entry for console output
        /// - Parameter entry: The log entry
        /// - Returns: Formatted log string
        private func formatLog(entry: LogEntry) -> String {
            var result = ""
            
            // Add timestamp
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            result += "[\(dateFormatter.string(from: entry.timestamp))]"
            
            // Add level with emoji if enabled
            if useEmoji {
                result += " [\(entry.level.emoji) \(entry.level.description)]"
            } else {
                result += " [\(entry.level.description)]"
            }
            
            // Add source information
            result += " [\(entry.source.file):\(entry.source.line)]"
            
            // Add message with color if enabled
            let message = entry.message
            if useColor {
                switch entry.level {
                case .debug: result += " \u{001B}[37m\(message)\u{001B}[0m" // White
                case .info: result += " \u{001B}[34m\(message)\u{001B}[0m" // Blue
                case .warning: result += " \u{001B}[33m\(message)\u{001B}[0m" // Yellow
                case .error: result += " \u{001B}[31m\(message)\u{001B}[0m" // Red
                case .critical: result += " \u{001B}[1;31m\(message)\u{001B}[0m" // Bold Red
                }
            } else {
                result += " \(message)"
            }
            
            // Add error information if available
            if let error = entry.error {
                result += " Error: \(error.message) (Code: \(error.code))"
            }
            
            // Add metadata if available
            if let metadata = entry.metadata, !metadata.isEmpty {
                let metadataStr = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
                result += " {" + metadataStr + "}"
            }
            
            return result
        }
        
        /// Flushes any buffered logs
        public func flush() {
            // Console output is not buffered, so no need to flush
        }
        
        /// Cleans up resources
        public func cleanup() {
            // No cleanup needed for console output
        }
    }
    
    /// File log destination that writes logs to a file
    public class FileLogDestination: LogDestination {
        /// The minimum log level accepted by this destination
        public var minimumLevel: LogLevel
        
        /// Filters that determine which logs are accepted
        public var filters: [LogFilter]
        
        /// The URL of the log file
        private let fileURL: URL
        
        /// The maximum size of the log file before rotation
        private let maxFileSize: UInt64
        
        /// The number of log files to keep
        private let maxFileCount: Int
        
        /// The file handle for writing
        private var fileHandle: FileHandle?
        
        /// Queue for file operations
        private let fileQueue = DispatchQueue(label: "com.fraqtiv.logManager.fileQueue", qos: .utility)
        
        /// Creates a new file log destination
        /// - Parameters:
        ///   - fileURL: The URL of the log file
        ///   - minimumLevel: The minimum log level
        ///   - filters: Log filters
        ///   - maxFileSize: The maximum size of the log file before rotation (in bytes)
        ///   - maxFileCount: The number of log files to keep
        public init(
            fileURL: URL,
            minimumLevel: LogLevel = .info,
            filters: [LogFilter] = [],
            maxFileSize: UInt64 = 10 * 1024 * 1024, // 10MB
            maxFileCount: Int = 5
        ) {
            self.fileURL = fileURL
            self.minimumLevel = minimumLevel
            self.filters = filters
            self.maxFileSize = maxFileSize
            self.maxFileCount = maxFileCount
            
            // Create the log directory if it doesn't exist
            let directoryURL = fileURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            
            // Create the log file if it doesn't exist
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            }
            
            // Open the file for writing
            do {
                let fileHandle = try FileHandle(forWritingTo: fileURL)
                fileHandle.seekToEndOfFile()
                self.fileHandle = fileHandle
            } catch {
                ErrorReporter.shared.error(
                    XTError.io(.fileOperationFailed(path: fileURL.path, operation: "open", underlyingError: error)),
                    context: ["component": "LogManager"]
                )
            }
        }
        
        /// Processes a log entry
        /// - Parameter entry: The log entry to process
        public func process(entry: LogEntry) {
            // Skip logs below minimum level
            guard entry.level >= minimumLevel else { return }
            
            // Apply filters
            for filter in filters {
                if !filter.shouldInclude(entry: entry) {
                    return
                }
            }
            
            // Format the log entry
            let formattedLog = formatLog(entry: entry)
            
            // Write to file asynchronously
            fileQueue.async { [weak self] in
                guard let self = self else { return }
                
                // Check if we need to rotate the log file
                self.checkAndRotateLogFileIfNeeded()
                
                // Append to the log file
                guard let fileHandle = self.fileHandle else { return }
                
                do {
                    if #available(iOS 13.4, macOS 10.15.4, *) {
                        try fileHandle.seekToEnd()
                        if let data = (formattedLog + "\n").data(using: .utf8) {
                            try fileHandle.write(contentsOf: data)
                        }
                    } else {
                        // Legacy API (deprecated but needed for older OS versions)
                        fileHandle.seekToEndOfFile()
                        if let data = (formattedLog + "\n").data(using: .utf8) {
                            fileHandle.write(data)
                        }
                    }
                } catch {
                    ErrorReporter.shared.error(
                        XTError.io(.fileOperationFailed(path: self.fileURL.path, operation: "write", underlyingError: error)),
                        context: ["component": "LogManager"]
                    )
                }
            }
        }
        
        /// Formats a log entry for file output
        /// - Parameter entry: The log entry
        /// - Returns: Formatted log string
        private func formatLog(entry: LogEntry) -> String {
            var result = ""
            
            // Add timestamp
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            result += "[\(dateFormatter.string(from: entry.timestamp))]"
            
            // Add level
            result += " [\(entry.level.description)]"
            
            // Add source information
            result += " [\(entry.source.file):\(entry.source.line)] \(entry.source.function)"
            
            // Add message
            result += " - \(entry.message)"
            
            // Add error information if available
            if let error = entry.error {
                result += " | Error: \(error.message) (Code: \(error.code))"
                if let domain = error.domain {
                    result += " Domain: \(domain)"
                }
                if let stackTrace = error.stackTrace {
                    result += " | Stack: \(stackTrace)"
                }
            }
            
            // Add metadata if available
            if let metadata = entry.metadata, !metadata.isEmpty {
                let metadataStr = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
                result += " | Metadata: {" + metadataStr + "}"
            }
            
            return result
        }
        
        /// Checks if log file needs rotation and rotates if necessary
        private func checkAndRotateLogFileIfNeeded() {
            // Get current file size
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                if let fileSize = attributes[.size] as? UInt64, fileSize >= maxFileSize {
                    rotateLogFiles()
                }
            } catch {
                ErrorReporter.shared.warning("Failed to get log file size: \(error.localizedDescription)")
            }
        }
        
        /// Rotates log files
        private func rotateLogFiles() {
            // Close current file
            if #available(iOS 13.0, macOS 10.15, *) {
                try? fileHandle?.close()
            } else {
                fileHandle?.closeFile()
            }
            fileHandle = nil
            
            let fileManager = FileManager.default
            let directoryURL = fileURL.deletingLastPathComponent()
            let fileName = fileURL.lastPathComponent
            let fileExtension = fileURL.pathExtension
            let baseName = fileName.replacingOccurrences(of: ".\(fileExtension)", with: "")
            
            // Remove oldest log file if we've reached max count
            if maxFileCount > 0 {
                let oldestFileURL = directoryURL.appendingPathComponent("\(baseName).\(maxFileCount).\(fileExtension)")
                try? fileManager.removeItem(at: oldestFileURL)
            }
            
            // Shift existing log files
            for i in stride(from: maxFileCount - 1, through: 1, by: -1) {
                let sourceURL = directoryURL.appendingPathComponent("\(baseName).\(i).\(fileExtension)")
                let destURL = directoryURL.appendingPathComponent("\(baseName).\(i + 1).\(fileExtension)")
                if fileManager.fileExists(atPath: sourceURL.path) {
                    try? fileManager.moveItem(at: sourceURL, to: destURL)
                }
            }
            
            // Move current log file
            let newFileURL = directoryURL.appendingPathComponent("\(baseName).1.\(fileExtension)")
            try? fileManager.moveItem(at: fileURL, to: newFileURL)
            
            // Create a new log file
            fileManager.createFile(atPath: fileURL.path, contents: nil)
            
            // Open the new file for writing
            do {
                let fileHandle = try FileHandle(forWritingTo: fileURL)
                self.fileHandle = fileHandle
            } catch {
                ErrorReporter.shared.error(
                    XTError.io(.fileOperationFailed(path: fileURL.path, operation: "open after rotation", underlyingError: error)),
                    context: ["component": "LogManager"]
                )
            }
        }
        
        /// Flushes any buffered logs
        public func flush() {
            if #available(iOS 13.0, macOS 10.15, *) {
                try? fileHandle?.synchronize()
            } else {
                fileHandle?.synchronizeFile()
            }
        }
        
        /// Cleans up resources
        public func cleanup() {
            if #available(iOS 13.0, macOS 10.15, *) {
                try? fileHandle?.close()
            } else {
                fileHandle?.closeFile()
            }
            fileHandle = nil
        }
        
        /// Deinitializer
        deinit {
            cleanup()
        }
    }
    
    /// OS system log destination that uses the native logging system
    public class SystemLogDestination: LogDestination {
        /// The minimum log level accepted by this destination
        public var minimumLevel: LogLevel
        
        /// Filters that determine which logs are accepted
        public var filters: [LogFilter]
        
        /// The OS log subsystem
        private let subsystem: String
        
        /// The OS logger
        private let logger: OSLog
        
        /// Creates a new system log destination
        /// - Parameters:
        ///   - subsystem: The OS log subsystem (typically the bundle identifier)
        ///   - category: The OS log category
        ///   - minimumLevel: The minimum log level
        ///   - filters: Log filters
        public init(
            subsystem: String,
            category: String = "default",
            minimumLevel: LogLevel = .info,
            filters: [LogFilter] = []
        ) {
            self.subsystem = subsystem
            self.minimumLevel = minimumLevel
            self.filters = filters
            self.logger = OSLog(subsystem: subsystem, category: category)
        }
        
        /// Processes a log entry
        /// - Parameter entry: The log entry to process
        public func process(entry: LogEntry) {
            // Skip logs below minimum level
            guard entry.level >= minimumLevel else { return }
            
            // Apply filters
            for filter in filters {
                if !filter.shouldInclude(entry: entry) {
                    return
                }
            }
            
            // Create the log message
            var message = entry.message
            
            // Add error information if available
            if let error = entry.error {
                message += " Error: \(error.message) (\(error.code))"
            }
            
            // Convert log level to OS log type
            let type: OSLogType
            switch entry.level {
            case .debug:
                type = .debug
            case .info:
                type = .info
            case .warning:
                type = .default
            case .error:
                type = .error
            case .critical:
                type = .fault
            }
            
            // Log to system log
            os_log("%{public}s", log: logger, type: type, message)
        }
        
        /// Flushes any buffered logs
        public func flush() {
            // System log is not buffered, so no need to flush
        }
        
        /// Cleans up resources
        public func cleanup() {
            // No cleanup needed for system log
        }
    }
    
    /// Network log destination that sends logs to a remote endpoint
    public class NetworkLogDestination: LogDestination {
        /// The minimum log level accepted by this destination
        public var minimumLevel: LogLevel
        
        /// Filters that determine which logs are accepted
        public var filters: [LogFilter]
        
        /// The URL of the remote endpoint
        private let url: URL
        
        /// The HTTP method to use
        private let httpMethod: String
        
        /// HTTP headers to include
        private let headers: [String: String]
        
        /// The maximum number of logs to batch send
        private let batchSize: Int
        
        /// The interval between batch sends
        private let batchInterval: TimeInterval
        
        /// Queue for network operations
        private let networkQueue = DispatchQueue(label: "com.fraqtiv.logManager.networkQueue", qos: .utility)
        
        /// Buffered logs waiting to be sent
        private var logBuffer: [LogEntry] = []
        
        /// Timer for batch sending
        private var batchTimer: Timer?
        
        /// Creates a new network log destination
        /// - Parameters:
        ///   - url: The URL of the remote endpoint
        ///   - httpMethod: The HTTP method to use
        ///   - headers: HTTP headers to include
        ///   - minimumLevel: The minimum log level
        ///   - filters: Log filters
        ///   - batchSize: The maximum number of logs to batch send
        ///   - batchInterval: The interval between batch sends (in seconds)
        public init(
            url: URL,
            httpMethod: String = "POST",
            headers: [String: String] = ["Content-Type": "application/json"],
            minimumLevel: LogLevel = .warning,
            filters: [LogFilter] = [],
            batchSize: Int = 50,
            batchInterval: TimeInterval = 60
        ) {
            self.url = url
            self.httpMethod = httpMethod
            self.headers = headers
            self.minimumLevel = minimumLevel
            self.filters = filters
            self.batchSize = batchSize
            self.batchInterval = batchInterval
            
            // Set up batch timer
            setupBatchTimer()
        }
        
        /// Sets up the batch timer
        private func setupBatchTimer() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.batchTimer = Timer.scheduledTimer(
                    withTimeInterval: self.batchInterval,
                    repeats: true
                ) { [weak self] _ in
                    self?.sendBatchLogs()
                }
                
                // Ensure timer fires even when scrolling
                if let timer = self.batchTimer {
                    RunLoop.current.add(timer, forMode: .common)
                }
            }
        }
        
        /// Processes a log entry
        /// - Parameter entry: The log entry to process
        public func process(entry: LogEntry) {
            // Skip logs below minimum level
            guard entry.level >= minimumLevel else { return }
            
            // Apply filters
            for filter in filters {
                if !filter.shouldInclude(entry: entry) {
                    return
                }
            }
            
            // Add to buffer
            networkQueue.async { [weak self] in
                guard let self = self else { return }
                
                // Add to buffer
                self.logBuffer.append(entry)
                
                // Send batch if buffer size exceeds limit
                if self.logBuffer.count >= self.batchSize {
                    self.sendBatchLogs()
                }
            }
        }
        
        /// Sends buffered logs to the remote endpoint
        private func sendBatchLogs() {
            networkQueue.async { [weak self] in
                guard let self = self, !self.logBuffer.isEmpty else { return }
                
                // Create a copy of logs to send
                let logsToSend = self.logBuffer
                
                // Clear the buffer
                self.logBuffer.removeAll()
                
                // Create JSON payload
                let jsonLogs = logsToSend.map { $0.asJSON }
                let payload: [String: Any] = [
                    "logs": jsonLogs,
                    "timestamp": ISO8601DateFormatter().string(from: Date()),
                    "count": jsonLogs.count
                ]
                
                // Create request
                var request = URLRequest(url: self.url)
                request.httpMethod = self.httpMethod
                
                // Add headers
                for (key, value) in self.headers {
                    request.setValue(value, forHTTPHeaderField: key)
                }
                
                // Serialize payload
                do {
                    request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                    
                    // Send request
                    let task = URLSession.shared.dataTask(with: request) { data, response, error in
                        if let error = error {
                            ErrorReporter.shared.error(
                                XTError.network(.requestFailed(reason: error.localizedDescription)),
                                context: ["component": "LogManager", "destination": "network"]
                            )
                            
                            // Re-add logs to buffer for retry
                            self.networkQueue.async {
                                self.logBuffer.insert(contentsOf: logsToSend, at: 0)
                                
                                // Trim buffer if it gets too large
                                if self.logBuffer.count > self.batchSize * 3 {
                                    self.logBuffer = Array(self.logBuffer.prefix(self.batchSize * 2))
                                }
                            }
                        } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                            ErrorReporter.shared.warning("Failed to send logs to remote endpoint. Status: \(httpResponse.statusCode)")
                            
                            // Re-add logs to buffer for retry if it's a server error (5xx)
                            if httpResponse.statusCode >= 500 {
                                self.networkQueue.async {
                                    self.logBuffer.insert(contentsOf: logsToSend, at: 0)
                                    
                                    // Trim buffer if it gets too large
                                    if self.logBuffer.count > self.batchSize * 3 {
                                        self.logBuffer = Array(self.logBuffer.prefix(self.batchSize * 2))
                                    }
                                }
                            }
                        }
                    }
                    
                    task.resume()
                } catch {
                    ErrorReporter.shared.error(
                        XTError.serialization(.jsonSerializationFailed(reason: error.localizedDescription)),
                        context: ["component": "LogManager", "destination": "network"]
                    )
                }
            }
        }
        
        /// Flushes any buffered logs
        public func flush() {
            sendBatchLogs()
        }
        
        /// Cleans up resources
        public func cleanup() {
            // Stop timer
            batchTimer?.invalidate()
            batchTimer = nil
            
            // Send any remaining logs
            flush()
        }
        
        /// Deinitializer
        deinit {
            cleanup()
        }
    }
    
    // MARK: - Log Filtering
    
    /// Protocol for filtering log entries
    public protocol LogFilter {
        /// Determines whether a log entry should be included
        /// - Parameter entry: The log entry to filter
        /// - Returns: Whether the entry should be included
        func shouldInclude(entry: LogEntry) -> Bool
    }
    
    /// Filter that includes logs only from specific sources
    public class SourceFilter: LogFilter {
        /// The file pattern to include (substring match)
        private let filePattern: String?
        
        /// The function pattern to include (substring match)
        private let functionPattern: String?
        
        /// Whether this is an exclusion filter
        private let isExclusion: Bool
        
        /// Creates a new source filter
        /// - Parameters:
        ///   - filePattern: The file pattern to include (substring match)
        ///   - functionPattern: The function pattern to include (substring match)
        ///   - isExclusion: Whether this is an exclusion filter
        public init(filePattern: String? = nil, functionPattern: String? = nil, isExclusion: Bool = false) {
            self.filePattern = filePattern
            self.functionPattern = functionPattern
            self.isExclusion = isExclusion
        }
        
        /// Determines whether a log entry should be included
        /// - Parameter entry: The log entry to filter
        /// - Returns: Whether the entry should be included
        public func shouldInclude(entry: LogEntry) -> Bool {
            var matches = true
            
            if let filePattern = filePattern {
                matches = matches && entry.source.file.contains(filePattern)
            }
            
            if let functionPattern = functionPattern {
                matches = matches && entry.source.function.contains(functionPattern)
            }
            
            return matches != isExclusion
        }
    }
    
    /// Filter that includes logs only with specific metadata
    public class MetadataFilter: LogFilter {
        /// The metadata key to filter on
        private let key: String
        
        /// The value pattern to match (substring match)
        private let valuePattern: String?
        
        /// Whether this is an exclusion filter
        private let isExclusion: Bool
        
        /// Creates a new metadata filter
        /// - Parameters:
        ///   - key: The metadata key to filter on
        ///   - valuePattern: The value pattern to match (substring match)
        ///   - isExclusion: Whether this is an exclusion filter
        public init(key: String, valuePattern: String? = nil, isExclusion: Bool = false) {
            self.key = key
            self.valuePattern = valuePattern
            self.isExclusion = isExclusion
        }
        
        /// Determines whether a log entry should be included
        /// - Parameter entry: The log entry to filter
        /// - Returns: Whether the entry should be included
        public func shouldInclude(entry: LogEntry) -> Bool {
            guard let metadata = entry.metadata else {
                // If no metadata, don't include if we're looking for a specific key
                return isExclusion
            }
            
            guard let value = metadata[key] else {
                // If key doesn't exist, don't include
                return isExclusion
            }
            
            if let valuePattern = valuePattern {
                // Check if value matches pattern
                let matches = value.contains(valuePattern)
                return matches != isExclusion
            }
            
            // If no value pattern, include if key exists
            return !isExclusion
        }
    }
    
    /// Filter that includes logs only with messages matching a pattern
    public class MessageFilter: LogFilter {
        /// The message pattern to match (substring match)
        private let pattern: String
        
        /// Whether this is an exclusion filter
        private let isExclusion: Bool
        
        /// Creates a new message filter
        /// - Parameters:
        ///   - pattern: The message pattern to match (substring match)
        ///   - isExclusion: Whether this is an exclusion filter
        public init(pattern: String, isExclusion: Bool = false) {
            self.pattern = pattern
            self.isExclusion = isExclusion
        }
        
        /// Determines whether a log entry should be included
        /// - Parameter entry: The log entry to filter
        /// - Returns: Whether the entry should be included
        public func shouldInclude(entry: LogEntry) -> Bool {
            let matches = entry.message.contains(pattern)
            return matches != isExclusion
        }
    }
    
    // MARK: - Log Manager Implementation
    
    /// Shared instance
    public static let shared = LogManager()
    
    /// The global minimum log level (overrides destination minimum levels)
    public var globalMinimumLevel: LogLevel
    
    /// Whether to enable logging
    public var isEnabled: Bool
    
    /// Log destinations
    private var destinations: [LogDestination]
    
    /// The serial queue for log processing
    private let logQueue = DispatchQueue(label: "com.fraqtiv.logManager", qos: .utility)
    
    /// Creates a new log manager
    private init() {
        // Load configuration from ConfigurationManager or use defaults
        do {
            let configManager = ConfigurationManager.shared
            
            // Get global settings
            self.isEnabled = try configManager.bool("log.enabled", defaultValue: true)
            
            // Get global minimum log level
            let logLevelString = try configManager.string("log.minimumLevel", defaultValue: "debug")
            switch logLevelString.lowercased() {
            case "debug": self.globalMinimumLevel = .debug
            case "info": self.globalMinimumLevel = .info
            case "warning": self.globalMinimumLevel = .warning
            case "error": self.globalMinimumLevel = .error
            case "critical": self.globalMinimumLevel = .critical
            default: self.globalMinimumLevel = .debug
            }
            
            // Configure destinations
            var destinations: [LogDestination] = []
            
            // Add console destination if enabled
            let consoleEnabled = try configManager.bool("log.console.enabled", defaultValue: true)
            if consoleEnabled {
                let consoleLevelString = try configManager.string("log.console.minimumLevel", defaultValue: "debug")
                let consoleLevel: LogLevel
                switch consoleLevelString.lowercased() {
                case "debug": consoleLevel = .debug
                case "info": consoleLevel = .info
                case "warning": consoleLevel = .warning
                case "error": consoleLevel = .error
                case "critical": consoleLevel = .critical
                default: consoleLevel = .debug
                }
                
                let useEmoji = try configManager.bool("log.console.useEmoji", defaultValue: true)
                let useColor = try configManager.bool("log.console.useColor", defaultValue: true)
                
                destinations.append(
                    ConsoleLogDestination(
                        minimumLevel: consoleLevel,
                        useEmoji: useEmoji,
                        useColor: useColor
                    )
                )
            }
            
            // Add file destination if enabled
            let fileEnabled = try configManager.bool("log.file.enabled", defaultValue: true)
            if fileEnabled {
                let fileLevelString = try configManager.string("log.file.minimumLevel", defaultValue: "info")
                let fileLevel: LogLevel
                switch fileLevelString.lowercased() {
                case "debug": fileLevel = .debug
                case "info": fileLevel = .info
                case "warning": fileLevel = .warning
                case "error": fileLevel = .error
                case "critical": fileLevel = .critical
                default: fileLevel = .info
                }
                
                let maxFileSize = try configManager.uInt64("log.file.maxFileSize", defaultValue: 10 * 1024 * 1024)
                let maxFileCount = try configManager.int("log.file.maxFileCount", defaultValue: 5)
                
                // Get log directory
                var logDirectoryURL: URL
                if let logDirectoryPath = try? configManager.string("log.file.directory") {
                    logDirectoryURL = URL(fileURLWithPath: logDirectoryPath)
                } else {
                    // Use default location in Application Support
                    let appSupportURL = try fileManager.url(
                        for: .applicationSupportDirectory,
                        in: .userDomainMask,
                        appropriateFor: nil,
                        create: true
                    )
                    let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.fraqtiv.xtraqtiv"
                    logDirectoryURL = appSupportURL.appendingPathComponent(bundleIdentifier).appendingPathComponent("Logs")
                }
                
                // Create log file URL
                let logFileURL = logDirectoryURL.appendingPathComponent("xtraqtiv.log")
                
                destinations.append(
                    FileLogDestination(
                        fileURL: logFileURL,
                        minimumLevel: fileLevel,
                        maxFileSize: maxFileSize,
                        maxFileCount: maxFileCount
                    )
                )
            }
            
            // Add system log destination if enabled
            let systemLogEnabled = try configManager.bool("log.system.enabled", defaultValue: true)
            if systemLogEnabled {
                let systemLevelString = try configManager.string("log.system.minimumLevel", defaultValue: "info")
                let systemLevel: LogLevel
                switch systemLevelString.lowercased() {
                case "debug": systemLevel = .debug
                case "info": systemLevel = .info
                case "warning": systemLevel = .warning
                case "error": systemLevel = .error
                case "critical": systemLevel = .critical
                default: systemLevel = .info
                }
                
                let subsystem = try configManager.string("log.system.subsystem", defaultValue: Bundle.main.bundleIdentifier ?? "com.fraqtiv.xtraqtiv")
                let category = try configManager.string("log.system.category", defaultValue: "default")
                
                destinations.append(
                    SystemLogDestination(
                        subsystem: subsystem,
                        category: category,
                        minimumLevel: systemLevel
                    )
                )
            }
            
            // Add network log destination if enabled
            let networkEnabled = try configManager.bool("log.network.enabled", defaultValue: false)
            if networkEnabled, let urlString = try? configManager.string("log.network.url") {
                if let url = URL(string: urlString) {
                    let networkLevelString = try configManager.string("log.network.minimumLevel", defaultValue: "warning")
                    let networkLevel: LogLevel
                    switch networkLevelString.lowercased() {
                    case "debug": networkLevel = .debug
                    case "info": networkLevel = .info
                    case "warning": networkLevel = .warning
                    case "error": networkLevel = .error
                    case "critical": networkLevel = .critical
                    default: networkLevel = .warning
                    }
                    
                    let httpMethod = try configManager.string("log.network.httpMethod", defaultValue: "POST")
                    let batchSize = try configManager.int("log.network.batchSize", defaultValue: 50)
                    let batchInterval = try configManager.double("log.network.batchInterval", defaultValue: 60.0)
                    
                    // Configure headers
                    var headers: [String: String] = ["Content-Type": "application/json"]
                    if let headersDict = try? configManager.dictionary("log.network.headers") as? [String: String] {
                        for (key, value) in headersDict {
                            headers[key] = value
                        }
                    }
                    
                    destinations.append(
                        NetworkLogDestination(
                            url: url,
                            httpMethod: httpMethod,
                            headers: headers,
                            minimumLevel: networkLevel,
                            batchSize: batchSize,
                            batchInterval: batchInterval
                        )
                    )
                } else {
                    ErrorReporter.shared.warning("Invalid network log URL: \(urlString). Network logging will be disabled.")
                }
            }
            
            self.destinations = destinations
            
        } catch {
            // If there's an error loading from config, use default values
            ErrorReporter.shared.warning("Failed to load logging configuration: \(error.localizedDescription). Using default configuration.")
            
            // Set default values
            self.isEnabled = true
            self.globalMinimumLevel = .debug
            
            // Add default console destination
            self.destinations = [
                ConsoleLogDestination(minimumLevel: .debug)
            ]
        }
        
        ErrorReporter.shared.debug("LogManager initialized with \(destinations.count) destinations")
    }
    
    // MARK: - Logging Methods
    
    /// Logs a message at the debug level
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: The file where the log was called
    ///   - function: The function where the log was called
    ///   - line: The line where the log was called
    ///   - metadata: Additional metadata to include with the log
    public func debug(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        metadata: [String: String]? = nil
    ) {
        log(
            level: .debug,
            message: message,
            file: file,
            function: function,
            line: line,
            metadata: metadata
        )
    }
    
    /// Logs a message at the info level
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: The file where the log was called
    ///   - function: The function where the log was called
    ///   - line: The line where the log was called
    ///   - metadata: Additional metadata to include with the log
    public func info(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        metadata: [String: String]? = nil
    ) {
        log(
            level: .info,
            message: message,
            file: file,
            function: function,
            line: line,
            metadata: metadata
        )
    }
    
    /// Logs a message at the warning level
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: The file where the log was called
    ///   - function: The function where the log was called
    ///   - line: The line where the log was called
    ///   - metadata: Additional metadata to include with the log
    public func warning(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        metadata: [String: String]? = nil
    ) {
        log(
            level: .warning,
            message: message,
            file: file,
            function: function,
            line: line,
            metadata: metadata
        )
    }
    
    /// Logs a message at the error level
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: The file where the log was called
    ///   - function: The function where the log was called
    ///   - line: The line where the log was called
    ///   - metadata: Additional metadata to include with the log
    ///   - error: Optional error to include with the log
    public func error(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        metadata: [String: String]? = nil,
        error: Error? = nil
    ) {
        let logError: LogError?
        if let error = error {
            logError = LogError.from(error)
        } else {
            logError = nil
        }
        
        log(
            level: .error,
            message: message,
            file: file,
            function: function,
            line: line,
            metadata: metadata,
            error: logError
        )
    }
    
    /// Logs a message at the critical level
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: The file where the log was called
    ///   - function: The function where the log was called
    ///   - line: The line where the log was called
    ///   - metadata: Additional metadata to include with the log
    ///   - error: Optional error to include with the log
    public func critical(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        metadata: [String: String]? = nil,
        error: Error? = nil
    ) {
        let logError: LogError?
        if let error = error {
            logError = LogError.from(error)
        } else {
            logError = nil
        }
        
        log(
            level: .critical,
            message: message,
            file: file,
            function: function,
            line: line,
            metadata: metadata,
            error: logError
        )
    }
    
    /// Logs an error object at the error level
    /// - Parameters:
    ///   - error: The error to log
    ///   - file: The file where the log was called
    ///   - function: The function where the log was called
    ///   - line: The line where the log was called
    ///   - metadata: Additional metadata to include with the log
    public func error(
        _ error: Error,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        metadata: [String: String]? = nil
    ) {
        let message: String
        if let xtError = error as? XTError {
            message = "Error: \(xtError.domain.rawValue) - \(xtError.localizedDescription)"
        } else {
            message = "Error: \(error.localizedDescription)"
        }
        
        self.error(
            message,
            file: file,
            function: function,
            line: line,
            metadata: metadata,
            error: error
        )
    }
    
    /// Logs a message at the specified level
    /// - Parameters:
    ///   - level: The log level
    ///   - message: The message to log
    ///   - file: The file where the log was called
    ///   - function: The function where the log was called
    ///   - line: The line where the log was called
    ///   - metadata: Additional metadata to include with the log
    ///   - error: Optional error to include with the log
    public func log(
        level: LogLevel,
        message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        metadata: [String: String]? = nil,
        error: LogError? = nil
    ) {
        // Skip if logging is disabled or level is below global minimum
        guard isEnabled, level >= globalMinimumLevel else { return }
        
        // Create the log entry
        let source = LogSource(file: file, function: function, line: line)
        let entry = LogEntry(
            level: level,
            message: message,
            source: source,
            metadata: metadata,
            error: error
        )
        
        // Process the log entry asynchronously
        logQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Process the log entry in each destination
            for destination in self.destinations {
                destination.process(entry: entry)
            }
        }
    }
    
    // MARK: - Utility Methods
    
    /// Adds a log destination
    /// - Parameter destination: The destination to add
    public func addDestination(_ destination: LogDestination) {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            self.destinations.append(destination)
        }
    }
    
    /// Removes a log destination
    /// - Parameter destination: The destination to remove
    public func removeDestination(_ destination: LogDestination) {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            self.destinations.removeAll { $0 === (destination as AnyObject) }
        }
    }
    
    /// Clears all log destinations
    public func clearDestinations() {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            self.destinations.removeAll()
        }
    }
    
    /// Sets the global minimum log level
    /// - Parameter level: The minimum log level
    public func setGlobalMinimumLevel(_ level: LogLevel) {
        globalMinimumLevel = level
    }
    
    /// Sets the minimum log level for a specific destination type
    /// - Parameters:
    ///   - level: The minimum log level
    ///   - destinationType: The type of destination to set the level for
    public func setMinimumLevel(_ level: LogLevel, forDestinationType destinationType: Any.Type) {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            for destination in self.destinations {
                if type(of: destination) == destinationType {
                    destination.minimumLevel = level
                }
            }
        }
    }
    
    /// Adds a filter to all destinations
    /// - Parameter filter: The filter to add
    public func addFilter(_ filter: LogFilter) {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            for destination in self.destinations {
                destination.filters.append(filter)
            }
        }
    }
    
    /// Adds a filter to a specific destination type
    /// - Parameters:
    ///   - filter: The filter to add
    ///   - destinationType: The type of destination to add the filter to
    public func addFilter(_ filter: LogFilter, forDestinationType destinationType: Any.Type) {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            for destination in self.destinations {
                if type(of: destination) == destinationType {
                    destination.filters.append(filter)
                }
            }
        }
    }
    
    /// Clears all filters from all destinations
    public func clearFilters() {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            for destination in self.destinations {
                destination.filters.removeAll()
            }
        }
    }
    
    /// Clears all filters from a specific destination type
    /// - Parameter destinationType: The type of destination to clear filters from
    public func clearFilters(forDestinationType destinationType: Any.Type) {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            for destination in self.destinations {
                if type(of: destination) == destinationType {
                    destination.filters.removeAll()
                }
            }
        }
    }
    
    /// Flushes all log destinations
    public func flush() {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            for destination in self.destinations {
                destination.flush()
            }
        }
    }
    
    /// Enables or disables logging
    /// - Parameter enabled: Whether logging is enabled
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }
    
    /// Configures the LogManager from a dictionary
    /// - Parameter config: The configuration dictionary
    public func configure(with config: [String: Any]) {
        do {
            // Configure enabled state
            if let enabled = config["enabled"] as? Bool {
                self.isEnabled = enabled
            }
            
            // Configure global minimum level
            if let levelString = config["minimumLevel"] as? String {
                switch levelString.lowercased() {
                case "debug": self.globalMinimumLevel = .debug
                case "info": self.globalMinimumLevel = .info
                case "warning": self.globalMinimumLevel = .warning
                case "error": self.globalMinimumLevel = .error
                case "critical": self.globalMinimumLevel = .critical
                default: self.globalMinimumLevel = .debug
                }
            }
            
            // Configure destinations
            if let destinations = config["destinations"] as? [[String: Any]] {
                // Clear existing destinations
                self.destinations.removeAll()
                
                // Add configured destinations
                for destinationConfig in destinations {
                    if let type = destinationConfig["type"] as? String {
                        switch type.lowercased() {
                        case "console":
                            let level = parseLogLevel(from: destinationConfig["minimumLevel"] as? String, defaultLevel: .debug)
                            let useEmoji = destinationConfig["useEmoji"] as? Bool ?? true
                            let useColor = destinationConfig["useColor"] as? Bool ?? true
                            
                            self.destinations.append(
                                ConsoleLogDestination(
                                    minimumLevel: level,
                                    useEmoji: useEmoji,
                                    useColor: useColor
                                )
                            )
                            
                        case "file":
                            guard let fileURLString = destinationConfig["fileURL"] as? String else {
                                ErrorReporter.shared.warning("Missing fileURL in file destination configuration")
                                continue
                            }
                            
                            let fileURL = URL(fileURLWithPath: fileURLString)
                            let level = parseLogLevel(from: destinationConfig["minimumLevel"] as? String, defaultLevel: .info)
                            let maxFileSize = destinationConfig["maxFileSize"] as? UInt64 ?? 10 * 1024 * 1024
                            let maxFileCount = destinationConfig["maxFileCount"] as? Int ?? 5
                            
                            self.destinations.append(
                                FileLogDestination(
                                    fileURL: fileURL,
                                    minimumLevel: level,
                                    maxFileSize: maxFileSize,
                                    maxFileCount: maxFileCount
                                )
                            )
                            
                        case "system":
                            let subsystem = destinationConfig["subsystem"] as? String ?? Bundle.main.bundleIdentifier ?? "com.fraqtiv.xtraqtiv"
                            let category = destinationConfig["category"] as? String ?? "default"
                            let level = parseLogLevel(from: destinationConfig["minimumLevel"] as? String, defaultLevel: .info)
                            
                            self.destinations.append(
                                SystemLogDestination(
                                    subsystem: subsystem,
                                    category: category,
                                    minimumLevel: level
                                )
                            )
                            
                        case "network":
                            guard let urlString = destinationConfig["url"] as? String,
                                  let url = URL(string: urlString) else {
                                ErrorReporter.shared.warning("Missing or invalid URL in network destination configuration")
                                continue
                            }
                            
                            let httpMethod = destinationConfig["httpMethod"] as? String ?? "POST"
                            let headers = destinationConfig["headers"] as? [String: String] ?? ["Content-Type": "application/json"]
                            let level = parseLogLevel(from: destinationConfig["minimumLevel"] as? String, defaultLevel: .warning)
                            let batchSize = destinationConfig["batchSize"] as? Int ?? 50
                            let batchInterval = destinationConfig["batchInterval"] as? TimeInterval ?? 60.0
                            
                            self.destinations.append(
                                NetworkLogDestination(
                                    url: url,
                                    httpMethod: httpMethod,
                                    headers: headers,
                                    minimumLevel: level,
                                    batchSize: batchSize,
                                    batchInterval: batchInterval
                                )
                            )
                            
                        default:
                            ErrorReporter.shared.warning("Unknown destination type: \(type)")
                        }
                    }
                }
            }
            
            ErrorReporter.shared.debug("LogManager reconfigured with \(self.destinations.count) destinations")
            
        } catch {
            ErrorReporter.shared.error(
                XTError.configuration(.invalidValue(key: "log", reason: error.localizedDescription)),
                context: ["component": "LogManager"]
            )
        }
    }
    
    /// Parses a log level from a string
    /// - Parameters:
    ///   - levelString: The string representation of the log level
    ///   - defaultLevel: The default level to use if parsing fails
    /// - Returns: The parsed log level
    private func parseLogLevel(from levelString: String?, defaultLevel: LogLevel) -> LogLevel {
        guard let levelString = levelString else {
            return defaultLevel
        }
        
        switch levelString.lowercased() {
        case "debug": return .debug
        case "info": return .info
        case "warning": return .warning
        case "error": return .error
        case "critical": return .critical
        default: return defaultLevel
        }
    }
    
    // MARK: - Cleanup
    
    /// Cleans up resources used by the log manager
    public func cleanup() {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Flush and clean up each destination
            for destination in self.destinations {
                destination.flush()
                destination.cleanup()
            }
            
            // Clear destinations
            self.destinations.removeAll()
        }
    }
    
    /// Prepares for app termination
    public func prepareForTermination() {
        // Flush all destinations
        flush()
        
        // We don't clean up destinations here as they might still be needed
        // to log final messages before termination
    }
    
    /// Deinitializer
    deinit {
        // Clean up resources
        cleanup()
    }
}

// MARK: - Global Logging Functions

/// Logs a message at the debug level
/// - Parameters:
///   - message: The message to log
///   - file: The file where the log was called
///   - function: The function where the log was called
///   - line: The line where the log was called
///   - metadata: Additional metadata to include with the log
public func logDebug(
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line,
    metadata: [String: String]? = nil
) {
    LogManager.shared.debug(message, file: file, function: function, line: line, metadata: metadata)
}

/// Logs a message at the info level
/// - Parameters:
///   - message: The message to log
///   - file: The file where the log was called
///   - function: The function where the log was called
///   - line: The line where the log was called
///   - metadata: Additional metadata to include with the log
public func logInfo(
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line,
    metadata: [String: String]? = nil
) {
    LogManager.shared.info(message, file: file, function: function, line: line, metadata: metadata)
}

/// Logs a message at the warning level
/// - Parameters:
///   - message: The message to log
///   - file: The file where the log was called
///   - function: The function where the log was called
///   - line: The line where the log was called
///   - metadata: Additional metadata to include with the log
public func logWarning(
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line,
    metadata: [String: String]? = nil
) {
    LogManager.shared.warning(message, file: file, function: function, line: line, metadata: metadata)
}

/// Logs a message at the error level
/// - Parameters:
///   - message: The message to log
///   - file: The file where the log was called
///   - function: The function where the log was called
///   - line: The line where the log was called
///   - metadata: Additional metadata to include with the log
///   - error: Optional error to include with the log
public func logError(
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line,
    metadata: [String: String]? = nil,
    error: Error? = nil
) {
    LogManager.shared.error(message, file: file, function: function, line: line, metadata: metadata, error: error)
}

/// Logs an error object at the error level
/// - Parameters:
///   - error: The error to log
///   - file: The file where the log was called
///   - function: The function where the log was called
///   - line: The line where the log was called
///   - metadata: Additional metadata to include with the log
public func logError(
    _ error: Error,
    file: String = #file,
    function: String = #function,
    line: Int = #line,
    metadata: [String: String]? = nil
) {
    LogManager.shared.error(error, file: file, function: function, line: line, metadata: metadata)
}

/// Logs a message at the critical level
/// - Parameters:
///   - message: The message to log
///   - file: The file where the log was called
///   - function: The function where the log was called
///   - line: The line where the log was called
///   - metadata: Additional metadata to include with the log
///   - error: Optional error to include with the log
public func logCritical(
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line,
    metadata: [String: String]? = nil,
    error: Error? = nil
) {
    LogManager.shared.critical(message, file: file, function: function, line: line, metadata: metadata, error: error)
}

/// Logs an error object at the critical level
/// - Parameters:
///   - error: The error to log
///   - file: The file where the log was called
///   - function: The function where the log was called
///   - line: The line where the log was called
///   - metadata: Additional metadata to include with the log
public func logCritical(
    _ error: Error,
    file: String = #file,
    function: String = #function,
    line: Int = #line,
    metadata: [String: String]? = nil
) {
    let message: String
    if let xtError = error as? XTError {
        message = "Critical Error: \(xtError.domain.rawValue) - \(xtError.localizedDescription)"
    } else {
        message = "Critical Error: \(error.localizedDescription)"
    }
    
    LogManager.shared.critical(message, file: file, function: function, line: line, metadata: metadata, error: error)
}

// MARK: - Error Extensions

extension Error {
    /// Logs this error at the error level
    /// - Parameters:
    ///   - file: The file where the log was called
    ///   - function: The function where the log was called
    ///   - line: The line where the log was called
    ///   - metadata: Additional metadata to include with the log
    public func log(
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        metadata: [String: String]? = nil
    ) {
        logError(self, file: file, function: function, line: line, metadata: metadata)
    }
    
    /// Logs this error at the critical level
    /// - Parameters:
    ///   - file: The file where the log was called
    ///   - function: The function where the log was called
    ///   - line: The line where the log was called
    ///   - metadata: Additional metadata to include with the log
    public func logCritical(
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        metadata: [String: String]? = nil
    ) {
        logCritical(self, file: file, function: function, line: line, metadata: metadata)
    }
}

extension XTError {
    /// Logs this XTError at the appropriate level based on severity
    /// - Parameters:
    ///   - file: The file where the log was called
    ///   - function: The function where the log was called
    ///   - line: The line where the log was called
    ///   - metadata: Additional metadata to include with the log
    public func logAppropriately(
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        metadata: [String: String]? = nil
    ) {
        // Create combined metadata with error details
        var combinedMetadata = metadata ?? [:]
        combinedMetadata["errorDomain"] = self.domain.rawValue
        combinedMetadata["errorCode"] = String(self.code)
        
        // Log at the appropriate level based on error severity
        switch self.severity {
        case .low:
            logInfo("XTError: \(self.localizedDescription)", file: file, function: function, line: line, metadata: combinedMetadata)
        case .medium:
            logWarning("XTError: \(self.localizedDescription)", file: file, function: function, line: line, metadata: combinedMetadata)
        case .high:
            logError(self, file: file, function: function, line: line, metadata: combinedMetadata)
        case .critical:
            logCritical(self, file: file, function: function, line: line, metadata: combinedMetadata)
        }
    }
}
