import Foundation
import Security

/// `SecureCredentialsManager` provides secure storage and retrieval of sensitive credentials
/// using the system keychain.
public final class SecureCredentialsManager {
    
    // MARK: - Types and Constants
    
    /// Errors that can occur during credential operations
    public enum CredentialError: Error, LocalizedError {
        /// Failed to store credential in keychain
        case storeFailed(reason: String)
        /// Failed to retrieve credential from keychain
        case retrieveFailed(reason: String)
        /// Failed to delete credential from keychain
        case deleteFailed(reason: String)
        /// Credential not found
        case notFound(key: String)
        /// Invalid value provided for credential
        case invalidValue
        
        public var errorDescription: String? {
            switch self {
            case .storeFailed(let reason):
                return "Failed to store credential: \(reason)"
            case .retrieveFailed(let reason):
                return "Failed to retrieve credential: \(reason)"
            case .deleteFailed(let reason):
                return "Failed to delete credential: \(reason)"
            case .notFound(let key):
                return "Credential not found: \(key)"
            case .invalidValue:
                return "Invalid credential value provided"
            }
        }
    }
    
    /// Service identifier for the app
    private let serviceIdentifier: String
    
    /// Access group for shared keychain access (optional)
    private let accessGroup: String?
    
    // MARK: - Singleton Instance
    
    /// Shared instance of SecureCredentialsManager
    public static let shared = SecureCredentialsManager()
    
    // MARK: - Initialization
    
    /// Creates a new secure credentials manager
    /// - Parameters:
    ///   - serviceIdentifier: The service identifier for the app (default: bundle identifier)
    ///   - accessGroup: Optional access group for shared keychain access
    public init(serviceIdentifier: String? = nil, accessGroup: String? = nil) {
        // Use provided service identifier or bundle identifier as fallback
        self.serviceIdentifier = serviceIdentifier ?? Bundle.main.bundleIdentifier ?? "com.fraqtiv.xtraqtiv"
        self.accessGroup = accessGroup
        
        // Initialize with credentials from ConfigurationManager if available
        loadInitialCredentials()
    }
    
    // MARK: - Credential Management
    
    /// Stores a string credential in the keychain
    /// - Parameters:
    ///   - value: The credential value to store
    ///   - key: The key to associate with the credential
    /// - Throws: A CredentialError if storing fails
    public func storeCredential(_ value: String, forKey key: String) throws {
        guard !value.isEmpty else {
            throw CredentialError.invalidValue
        }
        
        // Convert the string to data
        guard let valueData = value.data(using: .utf8) else {
            throw CredentialError.invalidValue
        }
        
        try storeCredential(valueData, forKey: key)
    }
    
    /// Stores a data credential in the keychain
    /// - Parameters:
    ///   - valueData: The credential data to store
    ///   - key: The key to associate with the credential
    /// - Throws: A CredentialError if storing fails
    public func storeCredential(_ valueData: Data, forKey key: String) throws {
        // Create a query for storing the credential
        var query = baseQuery()
        query[kSecAttrAccount as String] = key
        query[kSecValueData as String] = valueData
        
        // Attempt to delete any existing credential with this key
        _ = try? deleteCredential(forKey: key)
        
        // Add the credential to the keychain
        let status = SecItemAdd(query as CFDictionary, nil)
        
        // Check for errors
        guard status == errSecSuccess else {
            throw CredentialError.storeFailed(reason: "Keychain error: \(status)")
        }
        
        // Log success
        LogManager.shared.debug("Stored credential for key: \(key)")
    }
    
    /// Retrieves a string credential from the keychain
    /// - Parameter key: The key associated with the credential
    /// - Returns: The credential value
    /// - Throws: A CredentialError if retrieval fails
    public func retrieveCredential(forKey key: String) throws -> String {
        let data = try retrieveCredentialData(forKey: key)
        
        // Convert the data to a string
        guard let string = String(data: data, encoding: .utf8) else {
            throw CredentialError.retrieveFailed(reason: "Failed to convert data to string")
        }
        
        return string
    }
    
    /// Retrieves a data credential from the keychain
    /// - Parameter key: The key associated with the credential
    /// - Returns: The credential data
    /// - Throws: A CredentialError if retrieval fails
    public func retrieveCredentialData(forKey key: String) throws -> Data {
        // Create a query for retrieving the credential
        var query = baseQuery()
        query[kSecAttrAccount as String] = key
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        
        // Retrieve the credential from the keychain
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        // Check for errors
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw CredentialError.notFound(key: key)
            } else {
                throw CredentialError.retrieveFailed(reason: "Keychain error: \(status)")
            }
        }
        
        // Convert the result to data
        guard let data = result as? Data else {
            throw CredentialError.retrieveFailed(reason: "Invalid data format")
        }
        
        return data
    }
    
    /// Deletes a credential from the keychain
    /// - Parameter key: The key associated with the credential
    /// - Throws: A CredentialError if deletion fails
    public func deleteCredential(forKey key: String) throws {
        // Create a query for deleting the credential
        var query = baseQuery()
        query[kSecAttrAccount as String] = key
        
        // Delete the credential from the keychain
        let status = SecItemDelete(query as CFDictionary)
        
        // Check for errors (ignoring "not found" errors)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialError.deleteFailed(reason: "Keychain error: \(status)")
        }
        
        if status == errSecSuccess {
            LogManager.shared.debug("Deleted credential for key: \(key)")
        }
    }
    
    /// Checks if a credential exists in the keychain
    /// - Parameter key: The key to check
    /// - Returns: True if the credential exists, false otherwise
    public func hasCredential(forKey key: String) -> Bool {
        do {
            _ = try retrieveCredentialData(forKey: key)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Evernote Specific Credentials
    
    /// Keys for Evernote credentials
    private enum EvernoteCredentialKey {
        static let username = "evernote.username"
        static let apiToken = "evernote.apiToken"
        static let consumerKey = "evernote.consumerKey"
        static let consumerSecret = "evernote.consumerSecret"
        static let notebook = "evernote.defaultNotebook"
    }
    
    /// Stores Evernote credentials in the keychain
    /// - Parameters:
    ///   - username: The Evernote username
    ///   - apiToken: The Evernote API token
    ///   - consumerKey: Optional consumer key (for OAuth)
    ///   - consumerSecret: Optional consumer secret (for OAuth)
    ///   - defaultNotebook: Optional default notebook name
    /// - Throws: A CredentialError if storing fails
    public func storeEvernoteCredentials(
        username: String,
        apiToken: String,
        consumerKey: String? = nil,
        consumerSecret: String? = nil,
        defaultNotebook: String? = nil
    ) throws {
        try storeCredential(username, forKey: EvernoteCredentialKey.username)
        try storeCredential(apiToken, forKey: EvernoteCredentialKey.apiToken)
        
        if let consumerKey = consumerKey {
            try storeCredential(consumerKey, forKey: EvernoteCredentialKey.consumerKey)
        }
        
        if let consumerSecret = consumerSecret {
            try storeCredential(consumerSecret, forKey: EvernoteCredentialKey.consumerSecret)
        }
        
        if let defaultNotebook = defaultNotebook {
            try storeCredential(defaultNotebook, forKey: EvernoteCredentialKey.notebook)
        }
        
        LogManager.shared.info("Stored Evernote credentials for user: \(username)")
    }
    
    /// Retrieves Evernote credentials from the keychain
    /// - Returns: A dictionary containing the Evernote credentials
    /// - Throws: A CredentialError if retrieval fails
    public func retrieveEvernoteCredentials() throws -> [String: String] {
        // Retrieve the required credentials
        let username = try retrieveCredential(forKey: EvernoteCredentialKey.username)
        let apiToken = try retrieveCredential(forKey: EvernoteCredentialKey.apiToken)
        
        // Create the credentials dictionary
        var credentials: [String: String] = [
            "username": username,
            "apiToken": apiToken
        ]
        
        // Add optional credentials if they exist
        do {
            credentials["consumerKey"] = try retrieveCredential(forKey: EvernoteCredentialKey.consumerKey)
        } catch {
            // Ignore not found errors for optional credentials
        }
        
        do {
            credentials["consumerSecret"] = try retrieveCredential(forKey: EvernoteCredentialKey.consumerSecret)
        } catch {
            // Ignore not found errors for optional credentials
        }
        
        do {
            credentials["defaultNotebook"] = try retrieveCredential(forKey: EvernoteCredentialKey.notebook)
        } catch {
            // Ignore not found errors for optional credentials
        }
        
        return credentials
    }
    
    /// Checks if Evernote credentials are available
    /// - Returns: True if all required Evernote credentials are available, false otherwise
    public func hasEvernoteCredentials() -> Bool {
        return hasCredential(forKey: EvernoteCredentialKey.username) &&
               hasCredential(forKey: EvernoteCredentialKey.apiToken)
    }
    
    /// Deletes all Evernote credentials from the keychain
    /// - Throws: A CredentialError if deletion fails
    public func deleteEvernoteCredentials() throws {
        try deleteCredential(forKey: EvernoteCredentialKey.username)
        try deleteCredential(forKey: EvernoteCredentialKey.apiToken)
        try? deleteCredential(forKey: EvernoteCredentialKey.consumerKey)
        try? deleteCredential(forKey: EvernoteCredentialKey.consumerSecret)
        try? deleteCredential(forKey: EvernoteCredentialKey.notebook)
        
        LogManager.shared.info("Deleted all Evernote credentials")
    }
    
    // MARK: - Configuration Integration
    
    /// Loads initial credentials from the ConfigurationManager if available
    private func loadInitialCredentials() {
        do {
            let configManager = ConfigurationManager.shared
            
            // Check if Evernote credentials are available in the configuration
            if !hasEvernoteCredentials() {
                // Try to load Evernote credentials from configuration
                if let username = try? configManager.string("evernote.username"),
                   let apiToken = try? configManager.string("evernote.apiToken") {
                    
                    let consumerKey = try? configManager.string("evernote.consumerKey")
                    let consumerSecret = try? configManager.string("evernote.consumerSecret")
                    let defaultNotebook = try? configManager.string("evernote.defaultNotebook")
                    
                    // Store the credentials securely
                    try storeEvernoteCredentials(
                        username: username,
                        apiToken: apiToken,
                        consumerKey: consumerKey,
                        consumerSecret: consumerSecret,
                        defaultNotebook: defaultNotebook
                    )
                    
                    LogManager.shared.info("Loaded Evernote credentials from configuration")
                }
            }
        } catch {
            LogManager.shared.error(
                "Failed to load initial credentials from configuration",
                error: error
            )
        }
    }
    
    /// Updates the ConfigurationManager with the stored credentials for use by other components
    public func updateConfigurationWithStoredCredentials() {
        do {
            // Check if Evernote credentials are available
            if hasEvernoteCredentials() {
                // Retrieve the credentials
                let credentials = try retrieveEvernoteCredentials()
                
                // Create a dictionary for ConfigurationManager
                var configDict: [String: Any] = [:]
                
                // Add the credentials to the configuration dictionary
                for (key, value) in credentials {
                    configDict["evernote.\(key)"] = value
                }
                
                // Update the ConfigurationManager
                ConfigurationManager.shared.updateFromDictionary(configDict)
                
                LogManager.shared.debug("Updated configuration with stored credentials")
            }
        } catch {
            LogManager.shared.error(
                "Failed to update configuration with stored credentials",
                error: error
            )
        }
    }
    
    // MARK: - Helper Methods
    
    /// Creates a base query dictionary for keychain operations
    /// - Returns: A dictionary with base keychain query attributes
    private func baseQuery() -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier
        ]
        
        // Add access group if specified
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        return query
    }
}

// MARK: - Error Extension

extension XTError {
    /// A credential error domain
    public struct CredentialErrorDomain: ErrorDomain {
        public static let rawValue = "credential"
    }
    
    /// Creates a credential error from a CredentialError
    /// - Parameter error: The credential error
    /// - Returns: An XTError
    public static func credential(_ error: SecureCredentialsManager.CredentialError) -> XTError {
        return XTError(domain: .credential, code: 7000, underlyingError: error)
    }
}

// MARK: - ConfigurationManager Extension

extension ConfigurationManager {
    /// Updates configuration with values from a dictionary
    /// - Parameter dictionary: The dictionary containing configuration values
    public func updateFromDictionary(_ dictionary: [String: Any]) {
        // This method allows for dynamic updates to configuration values
        // Implementation may vary depending on the ConfigurationManager implementation
        // For now, we'll implement a simple version
        
        for (key, value) in dictionary {
            if let stringValue = value as? String {

