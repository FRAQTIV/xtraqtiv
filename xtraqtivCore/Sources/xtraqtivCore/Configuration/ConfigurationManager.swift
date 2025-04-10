import Foundation

/// `ConfigurationManager` provides centralized access to application configuration settings
/// across different environments with support for multiple configuration sources.
public final class ConfigurationManager {
    
    // MARK: - Singleton Instance
    
    /// Shared instance of ConfigurationManager
    public static let shared = ConfigurationManager()
    
    // MARK: - Environment
    
    /// Represents different application environments
    public enum Environment: String, CaseIterable {
        case development
        case staging
        case production
        
        /// Returns the current environment based on build configuration
        static var current: Environment {
            #if DEBUG
            return .development
            #elseif STAGING
            return .staging
            #else
            return .production
            #endif
        }
    }
    
    // MARK: - Configuration Source Types
    
    /// Represents different configuration source types
    public enum SourceType {
        /// Property list file
        case plist(URL)
        /// JSON file
        case json(URL)
        /// Environment variables with optional prefix
        case environment(prefix: String?)
        /// In-memory dictionary
        case dictionary([String: Any])
        /// Remote configuration endpoint
        case remote(URL, refreshInterval: TimeInterval, headers: [String: String]?)
    }
    
    // MARK: - Configuration Item Definition
    
    /// Defines a configuration item with validation
    public struct ConfigurationItem<T> {
        let key: String
        let defaultValue: T?
        let isRequired: Bool
        let validation: ((T) -> Bool)?
        
        /// Creates a new configuration item
        /// - Parameters:
        ///   - key: The key used to access this configuration value
        ///   - defaultValue: Optional default value if the configuration is not found
        ///   - required: Whether this configuration value is required
        ///   - validation: Optional validation function
        public init(key: String, defaultValue: T? = nil, required: Bool = false, validation: ((T) -> Bool)? = nil) {
            self.key = key
            self.defaultValue = defaultValue
            self.isRequired = required
            self.validation = validation
        }
    }
    
    // MARK: - Properties
    
    /// The current application environment
    public private(set) var environment: Environment
    
    /// Configuration sources in order of priority (highest first)
    private var sources: [SourceType] = []
    
    /// Cached configuration values
    private var configCache: [String: Any] = [:]
    
    /// Queue for thread-safe access to configuration values
    private let configQueue = DispatchQueue(label: "com.fraqtiv.configManager", attributes: .concurrent)
    
    /// Map of required configuration keys and their expected types
    private var requiredConfigs: [String: String] = [:]
    
    /// Timer for automatic refresh of remote configurations
    private var refreshTimers: [Timer] = []
    
    // MARK: - Initialization
    
    /// Creates a new configuration manager with the specified environment
    /// - Parameter environment: The application environment
    private init(environment: Environment = Environment.current) {
        self.environment = environment
        setupDefaultSources()
    }
    
    /// Sets up default configuration sources
    private func setupDefaultSources() {
        // Add environment variables as the lowest priority source
        sources.append(.environment(prefix: "XTRAQTIV_"))
        
        // Add bundle configuration files with environment-specific versions
        if let bundleURL = Bundle.main.url(forResource: "Config", withExtension: "plist") {
            sources.append(.plist(bundleURL))
        }
        
        if let envBundleURL = Bundle.main.url(forResource: "Config.\(environment.rawValue)", withExtension: "plist") {
            // Environment-specific config has higher priority
            sources.insert(.plist(envBundleURL), at: 0)
        }
    }
    
    // MARK: - Configuration Source Management
    
    /// Adds a new configuration source with the specified priority
    /// - Parameters:
    ///   - source: The configuration source to add
    ///   - priority: The priority level of the source (higher values = higher priority)
    public func addSource(_ source: SourceType, priority: Int = 0) {
        configQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Clear cache when adding a new source
            self.configCache.removeAll()
            
            // Add source at the appropriate position based on priority
            if priority >= self.sources.count {
                self.sources.insert(source, at: 0)
            } else if priority <= 0 {
                self.sources.append(source)
            } else {
                self.sources.insert(source, at: self.sources.count - priority)
            }
            
            // Set up refresh timer for remote source
            if case .remote(let url, let interval, _) = source, interval > 0 {
                self.setupRefreshTimer(for: url, interval: interval)
            }
        }
    }
    
    /// Removes a configuration source
    /// - Parameter source: The source type to remove
    public func removeSource(_ source: SourceType) {
        configQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Clear cache when removing a source
            self.configCache.removeAll()
            
            // Remove matching sources
            // Note: This is a simplistic approach and might not work for all cases
            // A more robust implementation would need equality comparison for SourceType
            switch source {
            case .plist(let url):
                self.sources.removeAll { 
                    if case .plist(let existingURL) = $0 {
                        return existingURL == url
                    }
                    return false
                }
            case .json(let url):
                self.sources.removeAll { 
                    if case .json(let existingURL) = $0 {
                        return existingURL == url
                    }
                    return false
                }
            case .environment(let prefix):
                self.sources.removeAll { 
                    if case .environment(let existingPrefix) = $0 {
                        return existingPrefix == prefix
                    }
                    return false
                }
            case .dictionary:
                // For dictionaries, we just remove all dictionary sources
                // since they can't be easily identified
                self.sources.removeAll { 
                    if case .dictionary = $0 {
                        return true
                    }
                    return false
                }
            case .remote(let url, _, _):
                // Remove matching remote source and its timer
                self.sources.removeAll { 
                    if case .remote(let existingURL, _, _) = $0 {
                        if existingURL == url {
                            self.removeRefreshTimer(for: url)
                            return true
                        }
                    }
                    return false
                }
            }
        }
    }
    
    /// Sets up a timer to refresh a remote configuration source
    /// - Parameters:
    ///   - url: The URL of the remote source
    ///   - interval: The refresh interval in seconds
    private func setupRefreshTimer(for url: URL, interval: TimeInterval) {
        // Remove any existing timer for this URL
        removeRefreshTimer(for: url)
        
        // Create a new timer
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refreshRemoteConfiguration(from: url)
        }
        
        refreshTimers.append(timer)
    }
    
    /// Removes a refresh timer for a remote configuration source
    /// - Parameter url: The URL of the remote source
    private func removeRefreshTimer(for url: URL) {
        for (index, timer) in refreshTimers.enumerated().reversed() {
            // This is a simple approach and might need to be enhanced to correctly identify
            // which timer corresponds to which URL
            timer.invalidate()
            refreshTimers.remove(at: index)
        }
    }
    
    /// Refreshes a remote configuration
    /// - Parameter url: The URL of the remote configuration to refresh
    private func refreshRemoteConfiguration(from url: URL) {
        // Find the source configuration for this URL
        var headers: [String: String]? = nil
        
        for source in sources {
            if case .remote(let sourceURL, _, let sourceHeaders) = source, sourceURL == url {
                headers = sourceHeaders
                break
            }
        }
        
        // Create a request with the appropriate headers
        var request = URLRequest(url: url)
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        // Fetch the remote configuration
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                ErrorReporter.shared.error(
                    XTError.configuration(.loadFailed(file: url.lastPathComponent, reason: error.localizedDescription)),
                    context: ["url": url.absoluteString]
                )
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                ErrorReporter.shared.error(
                    XTError.configuration(.loadFailed(file: url.lastPathComponent, reason: "HTTP error \(statusCode)")),
                    context: ["url": url.absoluteString, "statusCode": statusCode]
                )
                return
            }
            
            guard let data = data else {
                ErrorReporter.shared.error(
                    XTError.configuration(.loadFailed(file: url.lastPathComponent, reason: "No data received")),
                    context: ["url": url.absoluteString]
                )
                return
            }
            
            // Parse the JSON data
            do {
                let json = try JSONSerialization.jsonObject(with: data)
                
                if let configDict = json as? [String: Any] {
                    // Update the configuration cache
                    self.configQueue.async(flags: .barrier) {
                        // First remove any values that came from this source
                        self.configCache.removeAll()
                        
                        // Then add the new values
                        for (key, value) in configDict {
                            self.configCache[key] = value
                        }
                        
                        // Validate required configurations
                        self.validateRequiredConfigurations()
                    }
                } else {
                    ErrorReporter.shared.error(
                        XTError.configuration(.loadFailed(file: url.lastPathComponent, reason: "Invalid JSON format")),
                        context: ["url": url.absoluteString]
                    )
                }
            } catch {
                ErrorReporter.shared.error(
                    XTError.configuration(.loadFailed(file: url.lastPathComponent, reason: error.localizedDescription)),
                    context: ["url": url.absoluteString]
                )
            }
        }.resume()
    }
    
    // MARK: - Configuration Access
    
    /// Gets a configuration value for the specified item
    /// - Parameter item: The configuration item
    /// - Returns: The configuration value or the default value
    /// - Throws: An error if the configuration is required but not found or validation fails
    public func value<T>(for item: ConfigurationItem<T>) throws -> T {
        // Check if this is a required configuration
        if item.isRequired {
            requiredConfigs[item.key] = String(describing: T.self)
        }
        
        // Try to get from cache first
        if let cachedValue = configQueue.sync(execute: { configCache[item.key] }) as? T {
            // Validate if needed
            if let validation = item.validation, !validation(cachedValue) {
                throw XTError.configuration(.validationFailed(reason: "Validation failed for key: \(item.key)"))
            }
            return cachedValue
        }
        
        // Not in cache, search in all sources
        for source in sources {
            if let value = try? getValue(of: T.self, for: item.key, from: source) {
                // Cache the value
                configQueue.async(flags: .barrier) { [weak self] in
                    self?.configCache[item.key] = value
                }
                
                // Validate if needed
                if let validation = item.validation, !validation(value) {
                    throw XTError.configuration(.validationFailed(reason: "Validation failed for key: \(item.key)"))
                }
                
                return value
            }
        }
        
        // No value found in any source, use default if available
        if let defaultValue = item.defaultValue {
            return defaultValue
        }
        
        // No value found and no default, throw an error if required
        if item.isRequired {
            throw XTError.configuration(.missingValue(key: item.key))
        }
        
        // This should never happen due to the required check above
        // but Swift requires all paths to return or throw
        throw XTError.configuration(.missingValue(key: item.key))
    }
    
    /// Gets a value from a specific configuration source
    /// - Parameters:
    ///   - type: The expected type of the value
    ///   - key: The configuration key
    ///   - source: The configuration source
    /// - Returns: The configuration value if found and of the correct type
    /// - Throws: An error if the value can't be found or is of the wrong type
    private func getValue<T>(of type: T.Type, for key: String, from source: SourceType) throws -> T {
        switch source {
        case .plist(let url):
            return try getValueFromPlist(of: type, for: key, from: url)
        case .json(let url):
            return try getValueFromJSON(of: type, for: key, from: url)
        case .environment(let prefix):
            return try getValueFromEnvironment(of: type, for: key, prefix: prefix)
        case .dictionary(let dict):
            return try getValueFromDictionary(of: type, for: key, from: dict)
        case .remote(let url, _, _):
            return try getValueFromRemote(of: type, for: key, from: url)
        }
    }
    
    /// Gets a value from a plist file
    private func getValueFromPlist<T>(of type: T.Type, for key: String, from url: URL) throws -> T {
        guard let dict = NSDictionary(contentsOf: url) as? [String: Any] else {
            throw XTError.configuration(.loadFailed(file: url.lastPathComponent, reason: "Cannot read plist"))
        }
        
        if let value = dict[key] as? T {
            return value
        }
        
        throw XTError.configuration(.invalidValue(key: key, expectedType: String(describing: T.self)))
    }
    
    /// Gets a value from a JSON file
    private func getValueFromJSON<T>(of type: T.Type, for key: String, from url: URL) throws -> T {
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data)
        
        guard let dict = json as? [String: Any] else {
            throw XTError.configuration(.loadFailed(file: url.lastPathComponent, reason: "Invalid JSON format"))
        }
        
        if let value = dict[key] as? T {
            return value
        }
        
        throw XTError.configuration(.invalidValue(key: key, expectedType: String(describing: T.self)))
    }
    
    /// Gets a value from environment variables
    private func getValueFromEnvironment<T>(of type: T.Type, for key: String, prefix: String?) throws -> T {
        let envKey = prefix != nil ? "\(prefix!)\(key)" : key
        
        guard let envValue = ProcessInfo.processInfo.environment[envKey] else {
            throw XTError.configuration(.missingValue(key: envKey))
        }
        
        // Handle different types of configuration values
        if type == String.self {
            return envValue as! T
        } else if type == Bool.self {
            if envValue.lowercased() == "true" || envValue == "1" {
                return true as! T
            } else if envValue.lowercased() == "false" || envValue == "0" {
                return false as! T
            } else {
                throw XTError.configuration(.invalidValue(key: envKey, expectedType: "Bool"))
            }
        } else if type == Int.self {
            guard let intValue = Int(envValue) else {
                throw XTError.configuration(.invalidValue(key: envKey, expectedType: "Int"))
            }
            return intValue as! T
        } else if type == Double.self {
            guard let doubleValue = Double(envValue) else {
                throw XTError.configuration(.invalidValue(key: envKey, expectedType: "Double"))
            }
            return doubleValue as! T
        } else if type == URL.self {
            guard let url = URL(string: envValue) else {
                throw XTError.configuration(.invalidValue(key: envKey, expectedType: "URL"))
            }
            return url as! T
        } else if type == [String].self {
            let arrayValue = envValue.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            return arrayValue as! T
        }
        
        throw XTError.configuration(.invalidValue(key: envKey, expectedType: String(describing: T.self)))
    }
    
    /// Gets a value from a dictionary
    private func getValueFromDictionary<T>(of type: T.Type, for key: String, from dict: [String: Any]) throws -> T {
        if let value = dict[key] as? T {
            return value
        }
        
        // Try to convert the value if it's not directly castable
        if let dictValue = dict[key] {
            if type == String.self && !(dictValue is String) {
                return String(describing: dictValue) as! T
            } else if type == Bool.self && dictValue is String {
                let stringValue = dictValue as! String
                if stringValue.lowercased() == "true" || stringValue == "1" {
                    return true as! T
                } else if stringValue.lowercased() == "false" || stringValue == "0" {
                    return false as! T
                }
            } else if type == Int.self {
                if let doubleValue = dictValue as? Double {
                    return Int(doubleValue) as! T
                } else if let stringValue = dictValue as? String, let intValue = Int(stringValue) {
                    return intValue as! T
                }
            } else if type == Double.self {
                if let intValue = dictValue as? Int {
                    return Double(intValue) as! T
                } else if let stringValue = dictValue as? String, let doubleValue = Double(stringValue) {
                    return doubleValue as! T
                }
            } else if type == URL.self && dictValue is String {
                if let url = URL(string: dictValue as! String) {
                    return url as! T
                }
            } else if type == [String].self && dictValue is [Any] {
                let array = dictValue as! [Any]
                let stringArray = array.map { String(describing: $0) }
                return stringArray as! T
            }
        }
        
        throw XTError.configuration(.invalidValue(key: key, expectedType: String(describing: T.self)))
    }
    
    /// Gets a value from a remote source (assumes the value is cached)
    private func getValueFromRemote<T>(of type: T.Type, for key: String, from url: URL) throws -> T {
        // For remote sources, we only check the cache since the actual remote fetching is done asynchronously
        if let cachedValue = configQueue.sync(execute: { configCache[key] }) as? T {
            return cachedValue
        }
        
        throw XTError.configuration(.missingValue(key: key))
    }
    
    /// Validates that all required configurations are present and of the correct type
    private func validateRequiredConfigurations() {
        var missingKeys: [String] = []
        var invalidKeys: [String] = []
        
        for (key, expectedType) in requiredConfigs {
            if let value = configCache[key] {
                let actualType = String(describing: type(of: value))
                if actualType != expectedType && !isCompatibleType(value: value, expectedType: expectedType) {
                    invalidKeys.append("\(key) (expected: \(expectedType), got: \(actualType))")
                }
            } else {
                missingKeys.append(key)
            }
        }
        
        if !missingKeys.isEmpty {
            ErrorReporter.shared.warning("Missing required configuration keys: \(missingKeys.joined(separator: ", "))")
        }
        
        if !invalidKeys.isEmpty {
            ErrorReporter.shared.warning("Invalid configuration types: \(invalidKeys.joined(separator: ", "))")
        }
    }
    
    /// Checks if a value is compatible with an expected type even if not directly castable
    private func isCompatibleType(value: Any, expectedType: String) -> Bool {
        // Handle common type conversions that should be considered compatible
        switch expectedType {
        case "Bool":
            return value is Bool || (value is String && (["true", "false", "0", "1"].contains((value as! String).lowercased())))
        case "Int":
            return value is Int || value is Double || (value is String && Int(value as! String) != nil)
        case "Double":
            return value is Double || value is Int || (value is String && Double(value as! String) != nil)
        case "URL":
            return value is URL || (value is String && URL(string: value as! String) != nil)
        case "[String]":
            return value is [String] || value is [Any]
        default:
            return false
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Gets a string configuration value
    /// - Parameters:
    ///   - key: The configuration key
    ///   - defaultValue: Optional default value
    ///   - required: Whether this configuration is required
    /// - Returns: The string value
    /// - Throws: An error if the value can't be found or is of the wrong type
    public func string(_ key: String, defaultValue: String? = nil, required: Bool = false) throws -> String {
        let item = ConfigurationItem<String>(key: key, defaultValue: defaultValue, required: required)
        return try value(for: item)
    }
    
    /// Gets a boolean configuration value
    /// - Parameters:
    ///   - key: The configuration key
    ///   - defaultValue: Optional default value
    ///   - required: Whether this configuration is required
    /// - Returns: The boolean value
    /// - Throws: An error if the value can't be found or is of the wrong type
    public func bool(_ key: String, defaultValue: Bool? = nil, required: Bool = false) throws -> Bool {
        let item = ConfigurationItem<Bool>(key: key, defaultValue: defaultValue, required: required)
        return try value(for: item)
    }
    
    /// Gets an integer configuration value
    /// - Parameters:
    ///   - key: The configuration key
    ///   - defaultValue: Optional default value
    ///   - required: Whether this configuration is required
    /// - Returns: The integer value
    /// - Throws: An error if the value can't be found or is of the wrong type
    public func int(_ key: String, defaultValue: Int? = nil, required: Bool = false) throws -> Int {
        let item = ConfigurationItem<Int>(key: key, defaultValue: defaultValue, required: required)
        return try value(for: item)
    }
    
    /// Gets a double configuration value
    /// - Parameters:
    ///   - key: The configuration key
    ///   - defaultValue: Optional default value
    ///   - required: Whether this configuration is required
    /// - Returns: The double value
    /// - Throws: An error if the value can't be found or is of the wrong type
    public func double(_ key: String, defaultValue: Double? = nil, required: Bool = false) throws -> Double {
        let item = ConfigurationItem<Double>(key: key, defaultValue: defaultValue, required: required)
        return try value(for: item)
    }
    
    /// Gets a URL configuration value
    /// - Parameters:
    ///   - key: The configuration key
    ///   - defaultValue: Optional default value
    ///   - required: Whether this configuration is required
    /// - Returns: The URL value
    /// - Throws: An error if the value can't be found or is of the wrong type
    public func url(_ key: String, defaultValue: URL? = nil, required: Bool = false) throws -> URL {
        let item = ConfigurationItem<URL>(key: key, defaultValue: defaultValue, required: required)
        return try value(for: item)
    }
    
    /// Gets a string array configuration value
    /// - Parameters:
    ///   - key: The configuration key
    ///   - defaultValue: Optional default value
    ///   - required: Whether this configuration is required
    /// - Returns: The string array value
    /// - Throws: An error if the value can't be found or is of the wrong type
    public func stringArray(_ key: String, defaultValue: [String]? = nil, required: Bool = false) throws -> [String] {
        let item = ConfigurationItem<[String]>(key: key, defaultValue: defaultValue, required: required)
        return try value(for: item)
    }
    
    /// Reloads the configuration from all sources
    public func reload() {
        configQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Clear the cache
            self.configCache.removeAll()
            
            // For all remote sources, trigger immediate refresh
            for source in self.sources {
                if case .remote(let url, _, _) = source {
                    self.refreshRemoteConfiguration(from: url)
                }
            }
            
            // Validate required configurations after reload
            self.validateRequiredConfigurations()
        }
    }
    
    /// Changes the current environment and reloads configuration
    /// - Parameter environment: The new environment
    public func switchEnvironment(to environment: Environment) {
        // Only do something if the environment is actually changing
        guard environment != self.environment else { return }
        
        configQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Update environment
            self.environment = environment
            
            // Remove any environment-specific sources
            self.sources = self.sources.filter { source in
                if case .plist(let url) = source, url.lastPathComponent.contains(".development") ||
                   url.lastPathComponent.contains(".staging") || url.lastPathComponent.contains(".production") {
                    return false
                }
                return true
            }
            
            // Add new environment-specific source
            if let envBundleURL = Bundle.main.url(forResource: "Config.\(environment.rawValue)", withExtension: "plist") {
                self.sources.insert(.plist(envBundleURL), at: 0)
            }
            
            // Clear the cache and validate
            self.configCache.removeAll()
            self.validateRequiredConfigurations()
        }
        
        // Log the environment change
        ErrorReporter.shared.info("Switched configuration environment to: \(environment.rawValue)")
    }
    
    /// Sets a configuration value explicitly (useful for testing or runtime changes)
    /// - Parameters:
    ///   - key: The configuration key
    ///   - value: The value to set
    public func set<T>(_ key: String, value: T) {
        configQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.configCache[key] = value
        }
    }
    
    /// Removes a configuration value from the cache
    /// - Parameter key: The configuration key to remove
    public func remove(_ key: String) {
        configQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.configCache.removeAll(where: { $0.key == key })
        }
    }
    
    /// Clears all configuration values from the cache
    public func clearCache() {
        configQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.configCache.removeAll()
        }
    }
    
    /// Cleans up resources used by the configuration manager
    public func cleanup() {
        configQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Invalidate all refresh timers
            for timer in self.refreshTimers {
                timer.invalidate()
            }
            self.refreshTimers.removeAll()
            
            // Clear the configuration cache
            self.configCache.removeAll()
            
            // Clear required config mappings
            self.requiredConfigs.removeAll()
        }
    }
    
    /// Returns the current state of the configuration as a dictionary
    /// Useful for debugging or displaying configuration state
    public func currentState() -> [String: Any] {
        return configQueue.sync {
            return self.configCache
        }
    }
    
    /// Returns a list of required configuration keys and their expected types
    public func requiredConfigurationKeys() -> [String: String] {
        return configQueue.sync {
            return self.requiredConfigs
        }
    }
    
    /// Registers a callback to be notified when a specific configuration key is updated
    /// Note: This is a simplified implementation. A more robust one would store multiple callbacks per key
    private var configCallbacks: [String: (Any) -> Void] = [:]
    
    /// Registers a callback for configuration updates
    /// - Parameters:
    ///   - key: The configuration key to watch
    ///   - callback: The callback to invoke when the value changes
    public func registerCallback(for key: String, callback: @escaping (Any) -> Void) {
        configQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.configCallbacks[key] = callback
            
            // Immediately invoke callback with current value if available
            if let currentValue = self.configCache[key] {
                callback(currentValue)
            }
        }
    }
    
    /// Removes a callback for a specific key
    /// - Parameter key: The configuration key to stop watching
    public func removeCallback(for key: String) {
        configQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.configCallbacks.removeValue(forKey: key)
        }
    }
    
    /// Deinitializer to clean up resources
    deinit {
        // Invalidate all timers
        for timer in refreshTimers {
            timer.invalidate()
        }
        refreshTimers.removeAll()
        
        // Log cleanup
        ErrorReporter.shared.debug("ConfigurationManager deinitializing, cleaned up \(refreshTimers.count) timers")
    }
}
