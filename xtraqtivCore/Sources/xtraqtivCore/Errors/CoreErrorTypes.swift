import Foundation

/// `XTError` represents all error types within the FRAQTIV application.
/// This enum conforms to `LocalizedError` to provide user-friendly error messages.
public enum XTError: Error {
    // MARK: - Authentication Errors
    
    /// Errors related to user authentication and authorization
    case auth(AuthError)
    
    /// Specific authentication error types
    public enum AuthError {
        /// Failed to authenticate with the service
        case authenticationFailed(reason: String)
        /// Token expired and requires renewal
        case tokenExpired
        /// User is not authorized to perform the requested action
        case notAuthorized(operation: String)
        /// Missing required credentials
        case missingCredentials(description: String)
        /// Invalid authentication state
        case invalidAuthState(description: String)
    }
    
    // MARK: - Database Errors
    
    /// Errors related to local database operations
    case database(DatabaseError)
    
    /// Specific database error types
    public enum DatabaseError {
        /// Failed to save data to the database
        case saveFailed(entity: String, underlyingError: Error?)
        /// Failed to fetch data from the database
        case fetchFailed(entity: String, underlyingError: Error?)
        /// Failed to delete data from the database
        case deleteFailed(entity: String, underlyingError: Error?)
        /// Data corruption detected
        case dataCorruption(description: String)
        /// Database schema mismatch
        case schemaMismatch(expected: String, found: String)
        /// Failed to initialize or open database
        case initializationFailed(reason: String)
    }
    
    // MARK: - Network Errors
    
    /// Errors related to network operations
    case network(NetworkError)
    
    /// Specific network error types
    public enum NetworkError {
        /// No internet connection available
        case noConnection
        /// Request timed out
        case timeout(after: TimeInterval)
        /// Server returned an error response
        case serverError(statusCode: Int, message: String?)
        /// Failed to decode response data
        case decodingFailed(description: String)
        /// Invalid or malformed request
        case invalidRequest(description: String)
        /// Rate limit exceeded
        case rateLimitExceeded(resetTime: Date?)
    }
    
    // MARK: - Configuration Errors
    
    /// Errors related to application configuration
    case configuration(ConfigurationError)
    
    /// Specific configuration error types
    public enum ConfigurationError {
        /// Missing required configuration value
        case missingValue(key: String)
        /// Invalid configuration value
        case invalidValue(key: String, expectedType: String)
        /// Failed to load configuration file
        case loadFailed(file: String, reason: String)
        /// Configuration validation failed
        case validationFailed(reason: String)
    }
    
    // MARK: - Export Errors
    
    /// Errors related to exporting notes and resources
    case export(ExportError)
    
    /// Specific export error types
    public enum ExportError {
        /// Failed to export content
        case exportFailed(reason: String)
        /// Invalid export format
        case invalidFormat(requested: String, supported: [String])
        /// File system error during export
        case fileSystemError(description: String)
        /// Missing required export data
        case missingData(description: String)
    }
    
    // MARK: - Search Errors
    
    /// Errors related to search and indexing operations
    case search(SearchError)
    
    /// Specific search error types
    public enum SearchError {
        /// Search index is unavailable
        case indexUnavailable(reason: String)
        /// Failed to index content
        case indexingFailed(content: String, reason: String)
        /// Invalid search query
        case invalidQuery(query: String, reason: String)
        /// Search operation timed out
        case searchTimeout(after: TimeInterval)
    }
    
    // MARK: - Uncategorized Errors
    
    /// Generic error with description
    case generic(description: String)
    /// Unexpected error with underlying system error
    case unexpected(description: String, underlyingError: Error?)
}

// MARK: - LocalizedError Conformance

extension XTError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .auth(let error):
            return authErrorDescription(error)
        case .database(let error):
            return databaseErrorDescription(error)
        case .network(let error):
            return networkErrorDescription(error)
        case .configuration(let error):
            return configurationErrorDescription(error)
        case .export(let error):
            return exportErrorDescription(error)
        case .search(let error):
            return searchErrorDescription(error)
        case .generic(let description):
            return "An error occurred: \(description)"
        case .unexpected(let description, _):
            return "An unexpected error occurred: \(description)"
        }
    }
    
    private func authErrorDescription(_ error: AuthError) -> String {
        switch error {
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .tokenExpired:
            return "Your authentication session has expired. Please log in again."
        case .notAuthorized(let operation):
            return "You are not authorized to \(operation). Please check your permissions."
        case .missingCredentials(let description):
            return "Missing credentials: \(description)"
        case .invalidAuthState(let description):
            return "Invalid authentication state: \(description)"
        }
    }
    
    private func databaseErrorDescription(_ error: DatabaseError) -> String {
        switch error {
        case .saveFailed(let entity, _):
            return "Failed to save \(entity) to the database."
        case .fetchFailed(let entity, _):
            return "Failed to retrieve \(entity) from the database."
        case .deleteFailed(let entity, _):
            return "Failed to delete \(entity) from the database."
        case .dataCorruption(let description):
            return "Data corruption detected: \(description)"
        case .schemaMismatch(let expected, let found):
            return "Database schema mismatch. Expected: \(expected), Found: \(found)"
        case .initializationFailed(let reason):
            return "Failed to initialize database: \(reason)"
        }
    }
    
    private func networkErrorDescription(_ error: NetworkError) -> String {
        switch error {
        case .noConnection:
            return "No internet connection. Please check your network settings."
        case .timeout(let time):
            return "Network request timed out after \(Int(time)) seconds."
        case .serverError(let code, let message):
            if let message = message {
                return "Server error (\(code)): \(message)"
            } else {
                return "Server error with status code: \(code)"
            }
        case .decodingFailed(let description):
            return "Failed to process response data: \(description)"
        case .invalidRequest(let description):
            return "Invalid request: \(description)"
        case .rateLimitExceeded(let resetTime):
            if let resetTime = resetTime {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                return "Rate limit exceeded. Please try again after \(formatter.string(from: resetTime))."
            } else {
                return "Rate limit exceeded. Please try again later."
            }
        }
    }
    
    private func configurationErrorDescription(_ error: ConfigurationError) -> String {
        switch error {
        case .missingValue(let key):
            return "Missing configuration value for key: \(key)"
        case .invalidValue(let key, let expectedType):
            return "Invalid configuration value for key: \(key). Expected type: \(expectedType)"
        case .loadFailed(let file, let reason):
            return "Failed to load configuration file '\(file)': \(reason)"
        case .validationFailed(let reason):
            return "Configuration validation failed: \(reason)"
        }
    }
    
    private func exportErrorDescription(_ error: ExportError) -> String {
        switch error {
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .invalidFormat(let requested, let supported):
            return "Invalid export format '\(requested)'. Supported formats: \(supported.joined(separator: ", "))"
        case .fileSystemError(let description):
            return "File system error during export: \(description)"
        case .missingData(let description):
            return "Missing data required for export: \(description)"
        }
    }
    
    private func searchErrorDescription(_ error: SearchError) -> String {
        switch error {
        case .indexUnavailable(let reason):
            return "Search index is unavailable: \(reason)"
        case .indexingFailed(_, let reason):
            return "Failed to index content: \(reason)"
        case .invalidQuery(let query, let reason):
            return "Invalid search query '\(query)': \(reason)"
        case .searchTimeout(let time):
            return "Search operation timed out after \(Int(time)) seconds."
        }
    }
}

