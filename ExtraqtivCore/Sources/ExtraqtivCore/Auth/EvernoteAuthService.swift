import Foundation
import Security
import AuthenticationServices

/// Errors specific to the Evernote authentication process
public enum EvernoteAuthError: Error {
    /// Failed to generate the OAuth URL
    case failedToGenerateOAuthURL
    /// Failed to complete OAuth process
    case oauthCompletionFailed(String)
    /// Authentication token was not found
    case tokenNotFound
    /// Failed to refresh the authentication token
    case tokenRefreshFailed(String)
    /// Failed to save the authentication token securely
    case tokenStorageFailed
    /// Failed to retrieve the authentication token
    case tokenRetrievalFailed
    /// Invalid token format or data
    case invalidTokenData
    
    public var localizedDescription: String {
        switch self {
        case .failedToGenerateOAuthURL:
            return "Failed to generate Evernote OAuth URL"
        case .oauthCompletionFailed(let reason):
            return "OAuth completion failed: \(reason)"
        case .tokenNotFound:
            return "Authentication token not found"
        case .tokenRefreshFailed(let reason):
            return "Failed to refresh authentication token: \(reason)"
        case .tokenStorageFailed:
            return "Failed to save authentication token securely"
        case .tokenRetrievalFailed:
            return "Failed to retrieve authentication token"
        case .invalidTokenData:
            return "Invalid token format or data"
        }
    }
}

/// Represents an Evernote authentication token with its associated data
public struct EvernoteToken: Codable {
    /// The authentication token string
    public let tokenString: String
    /// The date when the token was issued
    public let issuedDate: Date
    /// The token's expiration date (if available)
    public let expirationDate: Date?
    /// Whether this token is for the production environment
    public let isProduction: Bool
    /// The Evernote user ID associated with this token
    public let userId: String
    /// The Evernote notebook URL (if available)
    public let notebookUrl: URL?
    
    /// Checks if the token has expired
    public var isExpired: Bool {
        guard let expirationDate = expirationDate else {
            // If no expiration date, conservatively assume it's valid for 1 year from issue
            return Date().timeIntervalSince(issuedDate) > (365 * 24 * 60 * 60)
        }
        return Date() > expirationDate
    }
    
    /// Returns the time until token expiration, or nil if no expiration date
    public var timeUntilExpiration: TimeInterval? {
        guard let expirationDate = expirationDate else { return nil }
        return expirationDate.timeIntervalSinceNow
    }
}

/// Protocol defining the requirements for an authentication service
public protocol AuthenticationService {
    /// The type of token used by this authentication service
    associatedtype TokenType
    
    /// Initiates the authentication process
    /// - Parameter completion: Closure called with the result of the authentication process
    func authenticate(completion: @escaping (Result<TokenType, Error>) -> Void)
    
    /// Checks if the user is currently authenticated
    /// - Returns: True if the user is authenticated, false otherwise
    func isAuthenticated() -> Bool
    
    /// Retrieves the current authentication token, if available
    /// - Returns: The current token, or nil if not authenticated
    func getCurrentToken() -> TokenType?
    
    /// Refreshes the authentication token if needed
    /// - Parameter completion: Closure called with the result of the refresh operation
    func refreshTokenIfNeeded(completion: @escaping (Result<TokenType, Error>) -> Void)
    
    /// Logs the user out, clearing any stored authentication data
    /// - Parameter completion: Closure called when the logout process completes
    func logout(completion: @escaping (Bool) -> Void)
}

/// Protocol for a secure token storage service
public protocol TokenStorage {
    /// Saves a token to secure storage
    /// - Parameters:
    ///   - tokenData: The token data to store
    ///   - service: The service identifier
    ///   - account: The account identifier
    /// - Returns: True if successful, false otherwise
    func saveToken(_ tokenData: Data, service: String, account: String) -> Bool
    
    /// Retrieves a token from secure storage
    /// - Parameters:
    ///   - service: The service identifier
    ///   - account: The account identifier
    /// - Returns: The token data if found, nil otherwise
    func retrieveToken(service: String, account: String) -> Data?
    
    /// Deletes a token from secure storage
    /// - Parameters:
    ///   - service: The service identifier
    ///   - account: The account identifier
    /// - Returns: True if successful, false otherwise
    func deleteToken(service: String, account: String) -> Bool
}

/// Keychain-based implementation of token storage
public class KeychainTokenStorage: TokenStorage {
    
    /// Shared instance for convenient access
    public static let shared = KeychainTokenStorage()
    
    private init() {}
    
    /// Saves a token to the keychain
    /// - Parameters:
    ///   - tokenData: The token data to store
    ///   - service: The service identifier
    ///   - account: The account identifier
    /// - Returns: True if successful, false otherwise
    public func saveToken(_ tokenData: Data, service: String, account: String) -> Bool {
        // Create a query dictionary for the keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: tokenData
        ]
        
        // First attempt to delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Retrieves a token from the keychain
    /// - Parameters:
    ///   - service: The service identifier
    ///   - account: The account identifier
    /// - Returns: The token data if found, nil otherwise
    public func retrieveToken(service: String, account: String) -> Data? {
        // Create a query dictionary for the keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            return data
        }
        return nil
    }
    
    /// Deletes a token from the keychain
    /// - Parameters:
    ///   - service: The service identifier
    ///   - account: The account identifier
    /// - Returns: True if successful, false otherwise
    public func deleteToken(service: String, account: String) -> Bool {
        // Create a query dictionary for the keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

/// Service for handling Evernote authentication through OAuth
public class EvernoteAuthService: AuthenticationService {
    /// Evernote authentication environments
    public enum Environment {
        /// Sandbox environment for development and testing
        case sandbox
        /// Production environment for released applications
        case production
        
        /// The base URL for the environment
        var baseURL: String {
            switch self {
            case .sandbox:
                return "https://sandbox.evernote.com"
            case .production:
                return "https://www.evernote.com"
            }
        }
    }
    
    /// Configuration for Evernote authentication
    public struct Configuration {
        /// The consumer key (from Evernote Developer portal)
        let consumerKey: String
        /// The consumer secret (from Evernote Developer portal)
        let consumerSecret: String
        /// The environment to use
        let environment: Environment
        /// The callback URL for OAuth
        let callbackURL: URL
        
        /// Creates a new configuration
        public init(consumerKey: String, consumerSecret: String, environment: Environment, callbackURL: URL) {
            self.consumerKey = consumerKey
            self.consumerSecret = consumerSecret
            self.environment = environment
            self.callbackURL = callbackURL
        }
    }
    
    private let configuration: Configuration
    private let tokenStorage: TokenStorage
    private let serviceName = "com.fraqtiv.extraqtiv.evernote"
    private let accountName = "evernoteAuth"
    
    private var webAuthSession: ASWebAuthenticationSession?
    
    /// Creates a new Evernote authentication service
    /// - Parameters:
    ///   - configuration: The configuration for the service
    ///   - tokenStorage: The storage mechanism for tokens (defaults to KeychainTokenStorage)
    public init(configuration: Configuration, tokenStorage: TokenStorage = KeychainTokenStorage.shared) {
        self.configuration = configuration
        self.tokenStorage = tokenStorage
    }
    
    /// Initiates the OAuth authentication process with Evernote
    /// - Parameter completion: Closure called with the result of the authentication process
    public func authenticate(completion: @escaping (Result<EvernoteToken, Error>) -> Void) {
        // Step 1: Generate the OAuth URL
        let oauthURL = generateOAuthURL()
        guard let oauthURL = oauthURL else {
            completion(.failure(EvernoteAuthError.failedToGenerateOAuthURL))
            return
        }
        
        // Step 2: Present the OAuth web flow
        webAuthSession = ASWebAuthenticationSession(
            url: oauthURL,
            callbackURLScheme: configuration.callbackURL.scheme,
            completionHandler: { [weak self] callbackURL, error in
                guard let self = self else { return }
                
                // Handle authentication error
                if let error = error {
                    completion(.failure(EvernoteAuthError.oauthCompletionFailed(error.localizedDescription)))
                    return
                }
                
                // Parse callback URL for token
                guard let callbackURL = callbackURL,
                      let token = self.parseOAuthCallbackURL(callbackURL) else {
                    completion(.failure(EvernoteAuthError.oauthCompletionFailed("Invalid callback URL")))
                    return
                }
                
                // Save token to secure storage
                self.saveToken(token) { success in
                    if success {
                        completion(.success(token))
                    } else {
                        completion(.failure(EvernoteAuthError.tokenStorageFailed))
                    }
                }
            }
        )
        
        // Configure and start the authentication session
        webAuthSession?.presentationContextProvider = getPresentationContextProvider()
        webAuthSession?.prefersEphemeralWebBrowserSession = false
        webAuthSession?.start()
    }
    
    /// Checks if the user is currently authenticated
    /// - Returns: True if authenticated with a valid token, false otherwise
    public func isAuthenticated() -> Bool {
        guard let token = getCurrentToken() else {
            return false
        }
        return !token.isExpired
    }
    
    /// Retrieves the current authentication token, if available
    /// - Returns: The current token, or nil if not authenticated
    public func getCurrentToken() -> EvernoteToken? {
        guard let tokenData = tokenStorage.retrieveToken(service: serviceName, account: accountName) else {
            return nil
        }
        
        do {
            let token = try JSONDecoder().decode(EvernoteToken.self, from: tokenData)
            return token
        } catch {
            print("Error decoding token: \(error)")
            return nil
        }
    }
    
    /// Refreshes the authentication token if needed
    /// - Parameter completion: Closure called with the result of the refresh operation
    public func refreshTokenIfNeeded(completion: @escaping (Result<EvernoteToken, Error>) -> Void) {
        guard let currentToken = getCurrentToken() else {
            completion(.failure(EvernoteAuthError.tokenNotFound))
            return
        }
        
        // Check if token needs refresh
        if !currentToken.isExpired {
            completion(.success(currentToken))
            return
        }
        
        // In Evernote's case, we need to reauthenticate as they don't offer a refresh token flow
        authenticate(completion: completion)
    }
    
    /// Logs the user out, clearing any stored authentication data
    /// - Parameter completion: Closure called when the logout process completes
    public func logout(completion: @escaping (Bool) -> Void) {
        let success = tokenStorage.deleteToken(service: serviceName, account: accountName)
        completion(success)
    }
    
    // MARK: - Private Methods
    
    /// Generates the OAuth URL for Evernote authentication
    /// - Returns: The OAuth URL
    private func generateOAuthURL() -> URL? {
        let baseURL = configuration.environment.baseURL
        let oauthPath = "/oauth"
        
        var components = URLComponents(string: baseURL + oauthPath)
        components?.queryItems = [
            URLQueryItem(name: "oauth_consumer_key", value: configuration.consumerKey),
            URLQueryItem(name: "oauth_signature", value: configuration.consumerSecret),
            URLQueryItem(name: "oauth_signature_method", value: "PLAINTEXT"),
            URLQueryItem(name: "oauth_timestamp", value: String(Int(Date().timeIntervalSince1970))),
            URLQueryItem(name: "oauth_nonce", value: UUID().uuidString),
            URLQueryItem(name: "oauth_callback", value: configuration.callbackURL.absoluteString),
            URLQueryItem(name: "oauth_version", value: "1.0")
        ]
        
        return components?.url
    }
    
    /// Parses the OAuth callback URL to extract the token information
    /// - Parameter url: The callback URL
    /// - Returns: An EvernoteToken if parsing was successful, nil otherwise
    private func parseOAuthCallbackURL(_ url: URL) -> EvernoteToken? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        
        // Extract token from query parameters
        var tokenString: String?
        var userId: String?
        var notebookUrl: URL?
        
        for item in queryItems {
            switch item.name {
            case "oauth_token":
                tokenString = item.value
            case "edam_userId":
                userId = item.value
            case "edam_notebookUrl":
                if let urlString = item.value {
                    notebookUrl = URL(string: urlString)
                }
            default:
                break
            }
        }
        
        // Validate required fields
        guard let tokenString = tokenString,
              let userId = userId else {
            return nil
        }
        
        // Create token with current date as issue date
        // Note: Evernote doesn't typically provide expiration dates for tokens
        return EvernoteToken(
            tokenString: tokenString,
            issuedDate: Date(),
            expiration

