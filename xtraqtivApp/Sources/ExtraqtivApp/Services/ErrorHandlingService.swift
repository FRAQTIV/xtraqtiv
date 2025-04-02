import Foundation
import OSLog

/// `ErrorHandlingService` provides centralized error handling capabilities for the Extraqtive application.
/// 
/// This service is designed to:
/// - Standardize error handling across the application
/// - Convert technical errors into user-friendly messages
/// - Log errors for debugging and analytics
/// - Provide recovery suggestions when possible
/// - Support both synchronous and asynchronous error handling
public class ErrorHandlingService {
    // MARK: - Properties
    
    /// Shared instance for application-wide error handling
    public static let shared = ErrorHandlingService()
    
    /// Logger instance for recording errors
    private let logger = Logger(subsystem: "com.fraqtiv.extraqtiv", category: "ErrorHandling")
    
    /// Dictionary of user-friendly messages for known error types
    private var knownErrorMessages: [String: String] = [
        "authenticationFailed": "Authentication with Evernote failed. Please check your credentials and try again.",
        "networkError": "Unable to connect to Evernote. Please check your internet connection.",
        "noteFetchFailed": "Could not retrieve your notes. Please try again later.",
        "exportFailed": "Export operation failed. Please check your file permissions and try again.",
        "resourceError": "Failed to process attachments in your notes.",
        "permissionDenied": "Extraqtive doesn't have necessary permissions. Please check system settings."
    ]
    
    /// Dictionary of recovery suggestions for known error types
    private var recoverySuggestions: [String: [String]] = [
        "authenticationFailed": [
            "Sign out and sign in again",
            "Check that your Evernote account is active",
            "Verify your internet connection"
        ],
        "networkError": [
            "Check your internet connection",
            "Try again later",
            "Verify that Evernote service is not experiencing downtime"
        ],
        "noteFetchFailed": [
            "Refresh your notebook list",
            "Check your internet connection", 
            "Verify your Evernote account permissions"
        ],
        "exportFailed": [
            "Choose a different export location",
            "Check if you have write permissions for the selected folder",
            "Ensure you have enough disk space"
        ],
        "resourceError": [
            "Try exporting without attachments",
            "Check your internet connection",
            "Verify that the note resources exist in your Evernote account"
        ],
        "permissionDenied": [
            "Open System Settings and grant Extraqtive the necessary permissions",
            "Restart the application after granting permissions",
            "Contact support if the issue persists"
        ]
    ]
    
    // MARK: - Initialization
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    // MARK: - Public Methods
    
    /// Handles an error by logging it and returning user-friendly information
    /// - Parameter error: The error to handle
    /// - Returns: A tuple containing a user-friendly message and recovery suggestions
    public func handle(_ error: Error) -> (message: String, suggestions: [String]) {
        // Log the error
        logError(error)
        
        // Create user-friendly message and recovery suggestions
        return createUserFriendlyError(from: error)
    }
    
    /// Processes an error and presents it to the user via alert or notification
    /// - Parameters:
    ///   - error: The error to process
    ///   - presentingHandler: A closure that will be called with user-friendly error information
    public func processAndPresent(
        _ error: Error, 
        presentingHandler: @escaping (String, [String]) -> Void
    ) {
        let (message, suggestions) = handle(error)
        presentingHandler(message, suggestions)
    }
    
    /// Registers custom error messages and recovery suggestions
    /// - Parameters:
    ///   - errorCode: The error code or type identifier
    ///   - message: The user-friendly message to display
    ///   - suggestions: Array of recovery suggestions
    public func registerCustomError(
        code errorCode: String,
        message: String,
        suggestions: [String]
    ) {
        knownErrorMessages[errorCode] = message
        recoverySuggestions[errorCode] = suggestions
    }
    
    // MARK: - Private Methods
    
    /// Logs an error to the system log
    /// - Parameter error: The error to log
    private func logError(_ error: Error) {
        // Log the error details for debugging
        logger.error("Error occurred: \(error.localizedDescription)")
        
        // Log additional context if available
        if let nsError = error as NSError? {
            logger.error("Domain: \(nsError.domain), Code: \(nsError.code)")
            if let failureReason = nsError.localizedFailureReason {
                logger.error("Failure reason: \(failureReason)")
            }
            if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                logger.error("Underlying error: \(underlyingError)")
            }
        }
    }
    
    /// Creates a user-friendly error message and recovery suggestions from a technical error
    /// - Parameter error: The original technical error
    /// - Returns: A tuple containing a user-friendly message and recovery suggestions
    private func createUserFriendlyError(from error: Error) -> (message: String, suggestions: [String]) {
        // Default error message and suggestions
        var userMessage = "An unexpected error occurred. Please try again later."
        var suggestions = ["Restart the application", "Check your internet connection"]
        
        // Try to match with known error types
        if let nsError = error as NSError? {
            // Check if we have a known error for this domain and code
            let errorKey = "\(nsError.domain):\(nsError.code)"
            
            if let knownMessage = knownErrorMessages[errorKey] {
                userMessage = knownMessage
                suggestions = recoverySuggestions[errorKey] ?? suggestions
            } else {
                // Try to match based on error domain categories
                for (key, message) in knownErrorMessages {
                    if nsError.domain.contains(key) || error.localizedDescription.contains(key) {
                        userMessage = message
                        suggestions = recoverySuggestions[key] ?? suggestions
                        break
                    }
                }
            }
        }
        
        return (userMessage, suggestions)
    }
    
    /// Determines if an error is recoverable and how it might be resolved
    /// - Parameter error: The error to analyze
    /// - Returns: Boolean indicating if the error is likely recoverable
    public func isRecoverable(_ error: Error) -> Bool {
        let nsError = error as NSError
        
        // Network errors are typically recoverable by retrying
        if nsError.domain == NSURLErrorDomain {
            return true
        }
        
        // File system errors might be recoverable depending on the code
        if nsError.domain == NSCocoaErrorDomain {
            // File not found, permission issues, etc.
            let recoverableCodes = [NSFileNoSuchFileError, NSFileWriteNoPermissionError]
            return recoverableCodes.contains(nsError.code)
        }
        
        // By default, assume errors are not automatically recoverable
        return false
    }
    
    /// Provides a standardized error alert title based on error category
    /// - Parameter error: The error to categorize
    /// - Returns: An appropriate alert title
    public func alertTitle(for error: Error) -> String {
        let nsError = error as NSError
        
        switch nsError.domain {
        case NSURLErrorDomain:
            return "Connection Error"
        case NSCocoaErrorDomain:
            if nsError.code == NSFileWriteNoPermissionError || nsError.code == NSFileReadNoPermissionError {
                return "Permission Error"
            } else if nsError.code == NSFileNoSuchFileError {
                return "File Not Found"
            } else {
                return "File System Error"
            }
        default:
            if nsError.localizedDescription.contains("auth") || nsError.localizedDescription.contains("login") {
                return "Authentication Error"
            } else if nsError.localizedDescription.contains("export") {
                return "Export Error"
            } else {
                return "Application Error"
            }
        }
    }
}

// MARK: - Error Types

/// Enumeration of common Extraqtive application errors
public enum ExtraqtiveError: Error, LocalizedError {
    case authenticationFailed(reason: String)
    case networkError(underlying: Error?)
    case noteFetchFailed(reason: String)
    case exportFailed(reason: String)
    case resourceError(reason: String)
    case permissionDenied(permission: String)
    case unexpectedError(message: String)
    
    /// User-friendly error description
    public var errorDescription: String? {
        switch self {
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .networkError:
            return "Network connection error"
        case .noteFetchFailed(let reason):
            return "Failed to fetch notes: \(reason)"
        case .exportFailed(let reason):
            return "Export operation failed: \(reason)"
        case .resourceError(let reason):
            return "Resource processing error: \(reason)"
        case .permissionDenied(let permission):
            return "Permission denied: \(permission)"
        case .unexpectedError(let message):
            return "Unexpected error: \(message)"
        }
    }
    
    /// Additional information about the error
    public var failureReason: String? {
        switch self {
        case .authenticationFailed:
            return "The application couldn't authenticate with Evernote"
        case .networkError(let underlying):
            return underlying?.localizedDescription ?? "Failed to connect to Evernote servers"
        case .noteFetchFailed:
            return "The application couldn't retrieve your notes from Evernote"
        case .exportFailed:
            return "The application encountered an issue while exporting your notes"
        case .resourceError:
            return "The application couldn't process attachments in your notes"
        case .permissionDenied:
            return "The application doesn't have the necessary system permissions"
        case .unexpectedError:
            return "The application encountered an unexpected issue"
        }
    }
    
    /// Suggestions for resolving the error
    public var recoverySuggestion: String? {
        switch self {
        case .authenticationFailed:
            return "Try signing out and signing in again. Make sure your Evernote account is active."
        case .networkError:
            return "Check your internet connection and try again. Verify that Evernote service is operational."
        case .noteFetchFailed:
            return "Try refreshing your notebook list. Check your connection and account permissions."
        case .exportFailed:
            return "Try choosing a different export location. Ensure you have write permissions for the selected folder."
        case .resourceError:
            return "Try exporting without attachments or check if the resources exist in your Evernote account."
        case .permissionDenied:
            return "Open System Settings and grant Extraqtive the necessary permissions."
        case .unexpectedError:
            return "Try restarting the application. If the problem persists, please contact support."
        }
    }
}

// MARK: - Usage Extensions

extension View {
    /// Handles errors with a standard alert presentation
    /// - Parameters:
    ///   - isPresented: Binding to control alert presentation
    ///   - error: The error to present, if any
    ///   - onDismiss: Action to perform when alert is dismissed
    /// - Returns: A view with error handling capabilities
    public func handleError(
        isPresented: Binding<Bool>,
        error: Binding<Error?>,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        let errorService = ErrorHandlingService.shared
        
        return self.alert(
            isPresented: isPresented,
            error: error.wrappedValue as NSError?,
            actions: { _ in
                if let error = error.wrappedValue {
                    let (_, suggestions) = errorService.handle(error)
                    
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(suggestion) {
                            // Action for this suggestion could be added here
                            onDismiss?()
                        }
                    }
                    
                    Button("Dismiss", role: .cancel) {
                        onDismiss?()
                    }
                }
            },
            message: { nsError in
                if let error = error.wrappedValue {
                    Text(errorService.handle(error).message)
                } else {
                    Text("An error occurred")
                }
            }
        )
    }
}

