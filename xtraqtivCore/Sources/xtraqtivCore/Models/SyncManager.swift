import Foundation
import Combine

/// `SyncManager` handles synchronization of data between local storage and remote services,
/// with support for conflict resolution, incremental syncing, and retry mechanisms.
public final class SyncManager {
    
    // MARK: - Types and Constants
    
    /// Represents the current state of the synchronization process
    public enum SyncState: Equatable {
        /// No sync operation is in progress
        case idle
        /// Preparing for sync (gathering changes, etc.)
        case preparing
        /// Sync is in progress with specified progress
        case syncing(progress: Double)
        /// Sync completed successfully
        case completed
        /// Sync failed with error
        case failed(error: XTError)
        /// Sync was cancelled
        case cancelled
    }
    
    /// Direction of the data synchronization
    public enum SyncDirection {
        /// Upload local changes to remote
        case upload
        /// Download remote changes to local
        case download
        /// Both upload and download (bidirectional sync)
        case bidirectional
    }
    
    /// Strategy for resolving conflicts between local and remote data
    public enum ConflictResolutionStrategy {
        /// Local data takes precedence
        case localWins
        /// Remote data takes precedence
        case remoteWins
        /// Most recently modified data takes precedence
        case mostRecent
        /// Merge data from both sources according to defined rules
        case merge
        /// Ask the user to resolve the conflict
        case askUser
    }
    
    /// Configuration for sync operations
    public struct SyncConfiguration {
        /// Base URL for the sync API
        let baseURL: URL
        /// Authentication token
        let authToken: String?
        /// Headers to include in API requests
        let headers: [String: String]
        /// Default conflict resolution strategy
        let conflictStrategy: ConflictResolutionStrategy
        /// Maximum number of retry attempts for failed operations
        let maxRetryAttempts: Int
        /// Delay between retry attempts (in seconds)
        let retryDelay: TimeInterval
        /// Batch size for sync operations
        let batchSize: Int
        /// Whether to sync automatically when app becomes active
        let automaticSyncOnAppActive: Bool
        /// Whether to sync automatically when network becomes available
        let automaticSyncOnNetworkAvailable: Bool
        /// Interval for automatic background sync (in seconds, 0 means disabled)
        let backgroundSyncInterval: TimeInterval
        
        /// Creates a new sync configuration
        /// - Parameters:
        ///   - baseURL: Base URL for the sync API
        ///   - authToken: Authentication token (optional)
        ///   - headers: Headers to include in API requests
        ///   - conflictStrategy: Default conflict resolution strategy
        ///   - maxRetryAttempts: Maximum number of retry attempts for failed operations
        ///   - retryDelay: Delay between retry attempts (in seconds)
        ///   - batchSize: Batch size for sync operations
        ///   - automaticSyncOnAppActive: Whether to sync automatically when app becomes active
        ///   - automaticSyncOnNetworkAvailable: Whether to sync automatically when network becomes available
        ///   - backgroundSyncInterval: Interval for automatic background sync (in seconds, 0 means disabled)
        public init(
            baseURL: URL,
            authToken: String? = nil,
            headers: [String: String] = [:],
            conflictStrategy: ConflictResolutionStrategy = .mostRecent,
            maxRetryAttempts: Int = 3,
            retryDelay: TimeInterval = 5.0,
            batchSize: Int = 50,
            automaticSyncOnAppActive: Bool = true,
            automaticSyncOnNetworkAvailable: Bool = true,
            backgroundSyncInterval: TimeInterval = 900.0  // 15 minutes
        ) {
            self.baseURL = baseURL
            self.authToken = authToken
            self.headers = headers
            self.conflictStrategy = conflictStrategy
            self.maxRetryAttempts = maxRetryAttempts
            self.retryDelay = retryDelay
            self.batchSize = batchSize
            self.automaticSyncOnAppActive = automaticSyncOnAppActive
            self.automaticSyncOnNetworkAvailable = automaticSyncOnNetworkAvailable
            self.backgroundSyncInterval = backgroundSyncInterval
        }
    }
    
    /// Metadata for tracking sync status for an entity
    public struct SyncMetadata: Codable {
        /// The last time a successful sync was completed
        public let lastSyncTimestamp: Date
        /// The server timestamp from the last sync
        public let serverTimestamp: String
        /// The sync token from the server (if applicable)
        public let syncToken: String?
        /// Hash of the last synced data (for change detection)
        public let dataHash: String?
        
        /// Creates a new sync metadata instance
        /// - Parameters:
        ///   - lastSyncTimestamp: The last time a successful sync was completed
        ///   - serverTimestamp: The server timestamp from the last sync
        ///   - syncToken: The sync token from the server (if applicable)
        ///   - dataHash: Hash of the last synced data (for change detection)
        public init(
            lastSyncTimestamp: Date = Date(),
            serverTimestamp: String,
            syncToken: String? = nil,
            dataHash: String? = nil
        ) {
            self.lastSyncTimestamp = lastSyncTimestamp
            self.serverTimestamp = serverTimestamp
            self.syncToken = syncToken
            self.dataHash = dataHash
        }
    }
    
    /// Progress information for sync operations
    public struct SyncProgress {
        /// Total number of items to process
        public let total: Int
        /// Number of items processed so far
        public let completed: Int
        /// Number of items that failed to sync
        public let failed: Int
        /// Current progress (0.0 to 1.0)
        public var progress: Double {
            total > 0 ? Double(completed) / Double(total) : 0.0
        }
        
        /// Creates a new sync progress instance
        /// - Parameters:
        ///   - total: Total number of items to process
        ///   - completed: Number of items processed so far
        ///   - failed: Number of items that failed to sync
        public init(total: Int = 0, completed: Int = 0, failed: Int = 0) {
            self.total = total
            self.completed = completed
            self.failed = failed
        }
    }
    
    // MARK: - Singleton Instance
    
    /// Shared instance of SyncManager
    public static let shared = SyncManager()
    
    // MARK: - Properties
    
    /// The sync configuration
    private var configuration: SyncConfiguration
    
    /// Current state of the sync process
    private var state: SyncState = .idle {
        didSet {
            // Publish state change
            stateSubject.send(state)
            
            // Log state change if it's not just a progress update
            if case .syncing = state, case .syncing = oldValue {
                // Don't log every progress update
            } else {
                let stateDescription: String
                switch state {
                case .idle:
                    stateDescription = "Idle"
                case .preparing:
                    stateDescription = "Preparing"
                case .syncing(let progress):
                    stateDescription = "Syncing (\(Int(progress * 100))%)"
                case .completed:
                    stateDescription = "Completed"
                case .failed(let error):
                    stateDescription = "Failed: \(error.localizedDescription)"
                case .cancelled:
                    stateDescription = "Cancelled"
                }
                
                ErrorReporter.shared.info("Sync state changed to: \(stateDescription)")
            }
        }
    }
    
    /// Subject for publishing state changes
    private let stateSubject = PassthroughSubject<SyncState, Never>()
    
    /// Publisher for sync state changes
    public var statePublisher: AnyPublisher<SyncState, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    
    /// Progress information for the current sync operation
    private var progress = SyncProgress() {
        didSet {
            state = .syncing(progress: progress.progress)
        }
    }
    
    /// Queue for serializing sync operations
    private let syncQueue = DispatchQueue(label: "com.fraqtiv.syncManager", qos: .userInitiated)
    
    /// Network session for API requests
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 300.0
        return URLSession(configuration: config)
    }()
    
    /// Background sync timer
    private var backgroundSyncTimer: Timer?
    
    /// Map of sync metadata by entity type
    private var syncMetadataCache: [String: SyncMetadata] = [:]
    
    /// Set of entity types that have pending changes
    private var entitiesWithPendingChanges = Set<String>()
    
    /// Current sync operation cancellation token
    private var currentSyncCancellationToken: UUID?
    
    /// Set to true when a sync operation is in progress
    private var isSyncing: Bool {
        switch state {
        case .preparing, .syncing:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Initialization
    
    /// Creates a new sync manager with the specified configuration
    /// - Parameter configuration: Sync configuration
    private init(configuration: SyncConfiguration? = nil) {
        // Try to load configuration from ConfigurationManager or use default
        if let config = configuration {
            self.configuration = config
        } else {
            do {
                // Attempt to load configuration from ConfigurationManager
                let baseURLString = try ConfigurationManager.shared.string("sync.baseURL", required: true)
                guard let baseURL = URL(string: baseURLString) else {
                    throw XTError.configuration(.invalidValue(key: "sync.baseURL", expectedType: "URL"))
                }
                
                let authToken = try ConfigurationManager.shared.string("sync.authToken")
                
                let conflictStrategyString = try ConfigurationManager.shared.string("sync.conflictStrategy", defaultValue: "mostRecent")
                let conflictStrategy: ConflictResolutionStrategy
                switch conflictStrategyString.lowercased() {
                case "localwins":
                    conflictStrategy = .localWins
                case "remotewins":
                    conflictStrategy = .remoteWins
                case "merge":
                    conflictStrategy = .merge
                case "askuser":
                    conflictStrategy = .askUser
                default:
                    conflictStrategy = .mostRecent
                }
                
                let maxRetryAttempts = try ConfigurationManager.shared.int("sync.maxRetryAttempts", defaultValue: 3)
                let retryDelay = try ConfigurationManager.shared.double("sync.retryDelay", defaultValue: 5.0)
                let batchSize = try ConfigurationManager.shared.int("sync.batchSize", defaultValue: 50)
                let automaticSyncOnAppActive = try ConfigurationManager.shared.bool("sync.automaticSyncOnAppActive", defaultValue: true)
                let automaticSyncOnNetworkAvailable = try ConfigurationManager.shared.bool("sync.automaticSyncOnNetworkAvailable", defaultValue: true)
                let backgroundSyncInterval = try ConfigurationManager.shared.double("sync.backgroundSyncInterval", defaultValue: 900.0)
                
                // Create the configuration
                self.configuration = SyncConfiguration(
                    baseURL: baseURL,
                    authToken: authToken,
                    conflictStrategy: conflictStrategy,
                    maxRetryAttempts: maxRetryAttempts,
                    retryDelay: retryDelay,
                    batchSize: batchSize,
                    automaticSyncOnAppActive: automaticSyncOnAppActive,
                    automaticSyncOnNetworkAvailable: automaticSyncOnNetworkAvailable,
                    backgroundSyncInterval: backgroundSyncInterval
                )
            } catch {
                // If there's an error loading from config, use default values with a placeholder URL
                ErrorReporter.shared.warning("Failed to load sync configuration: \(error.localizedDescription). Using default configuration.")
                self.configuration = SyncConfiguration(
                    baseURL: URL(string: "https://api.fraqtiv.com/sync")!
                )
            }
        }
        
        // Set up observers for automatic sync triggers
        setupObservers()
        
        // Load cached sync metadata
        loadSyncMetadata()
        
        // Set up background sync if enabled
        setupBackgroundSync()
    }
    
    /// Sets up observers for automatic sync triggers
    private func setupObservers() {
        // Set up notification observers for app state changes and network availability
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNetworkAvailable),
            name: Notification.Name("NetworkAvailableNotification"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    /// Handles app entering foreground
    @objc private func handleAppWillEnterForeground() {
        if configuration.automaticSyncOnAppActive {
            syncQueue.async {
                // Only trigger a sync if we're not already syncing
                if !self.isSyncing {
                    self.syncAllEntities()
                }
            }
        }
    }
    
    /// Handles network becoming available
    @objc private func handleNetworkAvailable() {
        if configuration.automaticSyncOnNetworkAvailable {
            syncQueue.async {
                // Only trigger a sync if we're not already syncing
                if !self.isSyncing {
                    self.syncAllEntities()
                }
            }
        }
    }
    
    /// Handles app termination
    @objc private func handleAppWillTerminate() {
        // Save any cached sync metadata and cancel ongoing syncs
        saveSyncMetadata()
        cancelSync()
    }
    
    /// Sets up background sync timer if enabled
    private func setupBackgroundSync() {
        guard configuration.backgroundSyncInterval > 0 else {
            // Background sync is disabled
            return
        }
        
        // Cancel any existing timer
        backgroundSyncTimer?.invalidate()
        
        // Set up a new timer
        backgroundSyncTimer = Timer.scheduledTimer(
            withTimeInterval: configuration.backgroundSyncInterval,
            repeats: true
        ) { [weak self] _ in
            self?.syncQueue.async {
                self?.syncAllEntities()
            }
        }
    }
    
    // MARK: - Sync Metadata Management
    
    /// Loads sync metadata from persistent storage
    private func loadSyncMetadata() {
        do {
            // Try to load from UserDefaults first (for simplicity, in a real app this might use the database)
            if let syncMetadataData = UserDefaults.standard.data(forKey: "SyncMetadataCache") {
                let decoder = JSONDecoder()
                let metadataDict = try decoder.decode([String: SyncMetadata].self, from: syncMetadataData)
                self.syncMetadataCache = metadataDict
                ErrorReporter.shared.debug("Loaded sync metadata for \(metadataDict.count) entities")
            }
        } catch {
            ErrorReporter.shared.warning("Failed to load sync metadata: \(error.localizedDescription)")
        }
    }
    
    /// Saves sync metadata to persistent storage
    private func saveSyncMetadata() {
        do {
            let encoder = JSONEncoder()
            let syncMetadataData = try encoder.encode(syncMetadataCache)
            UserDefaults.standard.set(syncMetadataData, forKey: "SyncMetadataCache")
            ErrorReporter.shared.debug("Saved sync metadata for \(syncMetadataCache.count) entities")
        } catch {
            ErrorReporter.shared.warning("Failed to save sync metadata: \(error.localizedDescription)")
        }
    }
    
    /// Gets sync metadata for a specific entity
    /// - Parameter entityName: The name of the entity
    /// - Returns: The sync metadata, or nil if no metadata exists
    public func syncMetadata(for entityName: String) -> SyncMetadata? {
        return syncMetadataCache[entityName]
    }
    
    /// Updates sync metadata for a specific entity
    /// - Parameters:
    ///   - entityName: The name of the entity
    ///   - metadata: The sync metadata
    public func updateSyncMetadata(for entityName: String, metadata: SyncMetadata) {
        syncQueue.async {
            self.syncMetadataCache[entityName] = metadata
            self.saveSyncMetadata()
        }
    }
    
    /// Marks an entity as having pending changes that need to be synced
    /// - Parameter entityName: The name of the entity
    public func markEntityHasPendingChanges(_ entityName: String) {
        syncQueue.async {
            self.entitiesWithPendingChanges.insert(entityName)
        }
    }
    
    /// Clears the pending changes flag for an entity after sync
    /// - Parameter entityName: The name of the entity
    private func clearPendingChangesFlag(for entityName: String) {
        entitiesWithPendingChanges.remove(entityName)
    }
    
    // MARK: - Sync Operations
    
    /// Generates a hash for data to detect changes
    /// - Parameter data: The data to hash
    /// - Returns: A string hash of the data
    private func generateDataHash(for data: Data) -> String {
        // Use SHA-256 or similar for real implementation
        return data.base64EncodedString()
    }
    
    /// Syncs all entities with the remote server
    /// - Parameter completion: Optional callback with the result of the operation
    public func syncAllEntities(completion: ((Result<Void, XTError>) -> Void)? = nil) {
        syncQueue.async { [weak self] in
            guard let self = self else {
                completion?(.failure(.sync(.managerDeallocated)))
                return
            }
            
            // Check if we're already syncing
            if self.isSyncing {
                completion?(.failure(.sync(.alreadyInProgress)))
                return
            }
            
            // Initialize cancellation token and state
            self.currentSyncCancellationToken = UUID()
            self.state = .preparing
            
            // Determine which entities need syncing
            // For now, we'll just use a predefined list
            // In a real app, this would come from the data model or configuration
            let entityNames = self.getEntityNamesForSync()
            
            // Initialize progress tracking
            self.progress = SyncProgress(total: entityNames.count)
            
            // Start the sync process for all entities
            self.syncEntitiesBatch(
                entityNames: entityNames,
                currentIndex: 0,
                failedEntities: [],
                cancellationToken: self.currentSyncCancellationToken!,
                completion: completion
            )
        }
    }
    
    /// Syncs a single entity with the remote server
    /// - Parameters:
    ///   - entityName: The name of the entity to sync
    ///   - direction: The sync direction (default: bidirectional)
    ///   - completion: Optional callback with the result of the operation
    public func syncEntity(
        _ entityName: String,
        direction: SyncDirection = .bidirectional,
        completion: ((Result<Void, XTError>) -> Void)? = nil
    ) {
        syncQueue.async { [weak self] in
            guard let self = self else {
                completion?(.failure(.sync(.managerDeallocated)))
                return
            }
            
            // Check if we're already syncing
            if self.isSyncing {
                completion?(.failure(.sync(.alreadyInProgress)))
                return
            }
            
            // Initialize cancellation token and state
            self.currentSyncCancellationToken = UUID()
            self.state = .preparing
            
            // Initialize progress tracking for a single entity
            self.progress = SyncProgress(total: 1)
            
            // Start the sync process for the entity
            self.syncEntityWithRetry(
                entityName: entityName,
                direction: direction,
                attempt: 1,
                cancellationToken: self.currentSyncCancellationToken!
            ) { result in
                // Update progress
                var updatedProgress = self.progress
                if case .success = result {
                    updatedProgress = SyncProgress(total: 1, completed: 1)
                } else {
                    updatedProgress = SyncProgress(total: 1, completed: 0, failed: 1)
                }
                self.progress = updatedProgress
                
                // Update state
                if case .failure(let error) = result {
                    self.state = .failed(error: error)
                } else {
                    self.state = .completed
                }
                
                // Call completion handler
                completion?(result)
            }
        }
    }
    
    /// Syncs a batch of entities one by one
    /// - Parameters:
    ///   - entityNames: The names of the entities to sync
    ///   - currentIndex: The current index in the batch
    ///   - failedEntities: Array of entities that failed to sync
    ///   - cancellationToken: The token to check for cancellation
    ///   - completion: Optional callback with the result of the operation
    private func syncEntitiesBatch(
        entityNames: [String],
        currentIndex: Int,
        failedEntities: [String],
        cancellationToken: UUID,
        completion: ((Result<Void, XTError>) -> Void)? = nil
    ) {
        // Check if the sync operation has been cancelled
        if currentSyncCancellationToken != cancellationToken {
            self.state = .cancelled
            completion?(.failure(.sync(.cancelled)))
            return
        }
        
        // Check if we've processed all entities
        if currentIndex >= entityNames.count {
            // We're done with all entities
            if failedEntities.isEmpty {
                // All entities synced successfully
                self.state = .completed
                completion?(.success(()))
            } else {
                // Some entities failed to sync
                let error = XTError.sync(.partialFailure(failedEntities: failedEntities))
                self.state = .failed(error: error)
                completion?(.failure(error))
            }
            return
        }
        
        // Get the next entity to sync
        let entityName = entityNames[currentIndex]
        
        // Sync the entity with retry support
        syncEntityWithRetry(
            entityName: entityName,
            attempt: 1,
            cancellationToken: cancellationToken
        ) { [weak self] result in
            guard let self = self else {
                completion?(.failure(.sync(.managerDeallocated)))
                return
            }
            
            // Update progress and track failures
            var updatedFailedEntities = failedEntities
            var updatedProgress = self.progress
            
            if case .failure = result {
                updatedFailedEntities.append(entityName)
                updatedProgress = SyncProgress(
                    total: updatedProgress.total,
                    completed: updatedProgress.completed + 1,
                    failed: updatedProgress.failed + 1
                )
            } else {
                updatedProgress = SyncProgress(
                    total: updatedProgress.total,
                    completed: updatedProgress.completed + 1,
                    failed: updatedProgress.failed
                )
            }
            
            self.progress = updatedProgress
            
            // Continue with the next entity
            self.syncEntitiesBatch(
                entityNames: entityNames,
                currentIndex: currentIndex + 1,
                failedEntities: updatedFailedEntities,
                cancellationToken: cancellationToken,
                completion: completion
            )
        }
    }
    
    /// Syncs an entity with retry support
    /// - Parameters:
    ///   - entityName: The name of the entity to sync
    ///   - direction: The sync direction (default: bidirectional)
    ///   - attempt: The current attempt number
    ///   - cancellationToken: The token to check for cancellation
    ///   - completion: Callback with the result of the operation
    private func syncEntityWithRetry(
        entityName: String,
        direction: SyncDirection = .bidirectional,
        attempt: Int,
        cancellationToken: UUID,
        completion: @escaping (Result<Void, XTError>) -> Void
    ) {
        // Check if the sync operation has been cancelled
        if currentSyncCancellationToken != cancellationToken {
            completion(.failure(.sync(.cancelled)))
            return
        }
        
        // Log the sync attempt
        let attemptString = attempt > 1 ? " (attempt \(attempt)/\(configuration.maxRetryAttempts))" : ""
        ErrorReporter.shared.debug("Syncing entity \(entityName)\(attemptString)")
        
        // Get the last sync metadata for this entity
        let metadata = syncMetadata(for: entityName)
        
        // Perform the sync operation
        performEntitySync(entityName: entityName, metadata: metadata, direction: direction) { [weak self] result in
            guard let self = self else {
                completion(.failure(.sync(.managerDeallocated)))
                return
            }
            
            switch result {
            case .success(let newMetadata):
                // Sync succeeded, update metadata and clear pending changes flag
                self.updateSyncMetadata(for: entityName, metadata: newMetadata)
                self.clearPendingChangesFlag(for: entityName)
                completion(.success(()))
                
            case .failure(let error):
                // Check if we should retry
                if attempt < self.configuration.maxRetryAttempts {
                    // Log the retry
                    ErrorReporter.shared.warning(
                        "Sync failed for entity \(entityName): \(error.localizedDescription). Retrying in \(Int(self.configuration.retryDelay)) seconds..."
                    )
                    
                    // Retry after delay
                    DispatchQueue.global().asyncAfter(deadline: .now() + self.configuration.retryDelay) {
                        self.syncEntityWithRetry(
                            entityName: entityName,
                            direction: direction,
                            attempt: attempt + 1,
                            cancellationToken: cancellationToken,
                            completion: completion
                        )
                    }
                } else {
                    // We've exhausted all retry attempts
                    ErrorReporter.shared.error(
                        error,
                        context: ["entityName": entityName, "attempts": attempt]
                    )
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Performs the actual sync operation for an entity
    /// - Parameters:
    ///   - entityName: The name of the entity to sync
    ///   - metadata: The last sync metadata for this entity
    ///   - direction: The sync direction
    ///   - completion: Callback with the result of the operation
    private func performEntitySync(
        entityName: String,
        metadata: SyncMetadata?,
        direction: SyncDirection = .bidirectional,
        completion: @escaping (Result<SyncMetadata, XTError>) -> Void
    ) {
        // In a real implementation, this would:
        // 1. Fetch local changes since last sync
        // 2. Fetch remote changes since last sync
        // 3. Detect and resolve conflicts
        // 4. Apply changes in the appropriate direction
        // 5. Update the sync metadata
        
        // For this example, we'll simulate the sync process with a delay
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else {
                completion(.failure(.sync(.managerDeallocated)))
                return
            }
            
            do {
                // Step 1: Fetch local changes
                let localChanges = try self.fetchLocalChanges(for: entityName, since: metadata)
                
                // Step 2: Fetch remote changes
                let remoteChanges = try self.fetchRemoteChanges(for: entityName, since: metadata)
                
                // Step 3: Detect and resolve conflicts
                let (localChangesToApply, remoteChangesToApply) = self.resolveConflicts(
                    entityName: entityName,
                    localChanges: localChanges,
                    remoteChanges: remoteChanges
                )
                
                // Step 4: Apply changes based on sync direction
                switch direction {
                case .upload:
                    // Only send local changes to remote
                    try self.applyLocalChangesToRemote(entityName: entityName, changes: localChangesToApply)
                    
                case .download:
                    // Only apply remote changes locally
                    try self.applyRemoteChangesToLocal(entityName: entityName, changes: remoteChangesToApply)
                    
                case .bidirectional:
                    // Send local changes to remote
                    try self.applyLocalChangesToRemote(entityName: entityName, changes: localChangesToApply)
                    
                    // Apply remote changes locally
                    try self.applyRemoteChangesToLocal(entityName: entityName, changes: remoteChangesToApply)
                }
                
                // Step 5: Create new sync metadata
                let serverTimestamp = ISO8601DateFormatter().string(from: Date())
                let syncToken = UUID().uuidString // Simulated sync token
                let dataHash = self.generateDataHash(for: Data()) // Placeholder for actual data hash
                
                let newMetadata = SyncMetadata(
                    lastSyncTimestamp: Date(),
                    serverTimestamp: serverTimestamp,
                    syncToken: syncToken,
                    dataHash: dataHash
                )
                
                // Return success with the new metadata
                completion(.success(newMetadata))
                
            } catch {
                // Convert any error to an XTError
                let xtError: XTError
                if let error = error as? XTError {
                    xtError = error
                } else {
                    xtError = .sync(.syncFailed(entity: entityName, reason: error.localizedDescription))
                }
                
                ErrorReporter.shared.error(
                    xtError,
                    context: ["entityName": entityName]
                )
                
                completion(.failure(xtError))
            }
        }
    }
    
    // MARK: - Helper Methods for Sync
    
    /// Gets the entity names that should be synced
    /// - Returns: Array of entity names
    private func getEntityNamesForSync() -> [String] {
        // In a real app, this would come from the data model or configuration
        // For this example, we'll just return a predefined list
        
        // First include entities with pending changes
        var entities = Array(entitiesWithPendingChanges)
        
        // Then add standard entities if not already included
        let standardEntities = ["User", "Profile", "Activity", "Workout", "Nutrition"]
        for entity in standardEntities {
            if !entities.contains(entity) {
                entities.append(entity)
            }
        }
        
        return entities
    }
    
    /// Fetches local changes for an entity since the last sync
    /// - Parameters:
    ///   - entityName: The name of the entity
    ///   - metadata: The last sync metadata for this entity
    /// - Returns: The local changes
    /// - Throws: An error if the fetch fails
    private func fetchLocalChanges(for entityName: String, since metadata: SyncMetadata?) throws -> [String: Any] {
        // In a real implementation, this would query the local database for changes
        // since the last sync timestamp
        
        // For this example, we'll just return an empty dictionary
        return [:]
    }
    
    /// Fetches remote changes for an entity since the last sync
    /// - Parameters:
    ///   - entityName: The name of the entity
    ///   - metadata: The last sync metadata for this entity
    /// - Returns: The remote changes
    /// - Throws: An error if the fetch fails
    private func fetchRemoteChanges(for entityName: String, since metadata: SyncMetadata?) throws -> [String: Any] {
        // In a real implementation, this would make an API request to the server
        // to fetch changes since the last sync
        
        // Simulate network request
        // For this example, we'll just return an empty dictionary
        return [:]
    }
    
    /// Detects changes in data
    /// - Parameters:
    ///   - newData: The new data
    ///   - oldHash: The hash of the old data
    /// - Returns: True if the data has changed
    private func detectChanges(in newData: Data, oldHash: String?) -> Bool {
        guard let oldHash = oldHash else {
            // No previous hash, assume data has changed
            return true
        }
        
        let newHash = generateDataHash(for: newData)
        return newHash != oldHash
    }
    
    // MARK: - Conflict Resolution
    
    /// Resolves conflicts between local and remote changes
    /// - Parameters:
    ///   - entityName: The name of the entity
    ///   - localChanges: The local changes
    ///   - remoteChanges: The remote changes
    /// - Returns: Tuple of (localChangesToApply, remoteChangesToApply)
    private func resolveConflicts(
        entityName: String,
        localChanges: [String: Any],
        remoteChanges: [String: Any]
    ) -> ([String: Any], [String: Any]) {
        // In a real implementation, this would detect conflicts by comparing
        // changes to the same fields and applying the conflict resolution strategy
        
        // For simplicity, assume no conflicts and return the original changes
        return (localChanges, remoteChanges)
    }
    
    /// Resolves a conflict between local and remote values
    /// - Parameters:
    ///   - localValue: The local value
    ///   - remoteValue: The remote value
    ///   - localModified: When the local value was last modified
    ///   - remoteModified: When the remote value was last modified
    ///   - strategy: The conflict resolution strategy to use
    /// - Returns: The resolved value
    private func resolveValueConflict<T>(
        localValue: T,
        remoteValue: T,
        localModified: Date,
        remoteModified: Date,
        strategy: ConflictResolutionStrategy? = nil
    ) -> T {
        // Use the provided strategy or fall back to the default
        let conflictStrategy = strategy ?? configuration.conflictStrategy
        
        switch conflictStrategy {
        case .localWins:
            return localValue
            
        case .remoteWins:
            return remoteValue
            
        case .mostRecent:
            return localModified > remoteModified ? localValue : remoteValue
            
        case .merge:
            // For merge, we would need to know the type and merging rules
            // For simplicity, we'll use most recent as a fallback
            return localModified > remoteModified ? localValue : remoteValue
            
        case .askUser:
            // Can't ask the user in a background operation, so use most recent as a fallback
            // In a real implementation, we might store the conflict for later resolution
            return localModified > remoteModified ? localValue : remoteValue
        }
    }
    
    /// Applies local changes to the remote server
    /// - Parameters:
    ///   - entityName: The name of the entity
    ///   - changes: The changes to apply
    /// - Throws: An error if the operation fails
    private func applyLocalChangesToRemote(entityName: String, changes: [String: Any]) throws {
        // In a real implementation, this would make API requests to update the remote server
        
        // Simulate a network request with a small chance of failure
        if Int.random(in: 0...20) == 0 {
            throw XTError.network(.requestFailed(error: NSError(domain: "NetworkError", code: 500, userInfo: nil)))
        }
    }
    
    /// Applies remote changes to the local database
    /// - Parameters:
    ///   - entityName: The name of the entity
    ///   - changes: The changes to apply
    /// - Throws: An error if the operation fails
    private func applyRemoteChangesToLocal(entityName: String, changes: [String: Any]) throws {
        // In a real implementation, this would update the local database
        
        // Simulate a database operation with a small chance of failure
        if Int.random(in: 0...20) == 0 {
            throw XTError.database(.updateFailed(entity: entityName, underlyingError: NSError(domain: "DatabaseError", code: 500, userInfo: nil)))
        }
    }
    
    // MARK: - Sync Control
    
    /// Cancels any ongoing sync operation
    /// - Returns: True if a sync operation was cancelled, false otherwise
    @discardableResult
    public func cancelSync() -> Bool {
        if isSyncing {
            // Invalidate the current sync token to signal cancellation
            currentSyncCancellationToken = nil
            state = .cancelled
            ErrorReporter.shared.info("Sync operation cancelled by user")
            return true
        }
        return false
    }
    
    /// Resets all sync metadata
    /// - Parameter completion: Callback when complete
    public func resetSyncMetadata(completion: ((Result<Void, XTError>) -> Void)? = nil) {
        syncQueue.async { [weak self] in
            guard let self = self else {
                completion?(.failure(.sync(.managerDeallocated)))
                return
            }
            
            // Check if we're currently syncing
            if self.isSyncing {
                completion?(.failure(.sync(.alreadyInProgress)))
                return
            }
            
            // Clear all metadata
            self.syncMetadataCache.removeAll()
            self.entitiesWithPendingChanges.removeAll()
            self.saveSyncMetadata()
            
            ErrorReporter.shared.info("Sync metadata has been reset")
            completion?(.success(()))
        }
    }
    
    /// Checks if an entity has pending changes
    /// - Parameter entityName: The name of the entity
    /// - Returns: True if the entity has pending changes
    public func entityHasPendingChanges(_ entityName: String) -> Bool {
        return entitiesWithPendingChanges.contains(entityName)
    }
    
    // MARK: - Cleanup and Deinitialization
    
    /// Performs cleanup before the app terminates
    public func prepareForTermination() {
        // Save metadata
        saveSyncMetadata()
        
        // Cancel any ongoing sync
        cancelSync()
        
        // Stop background timer
        backgroundSyncTimer?.invalidate()
        backgroundSyncTimer = nil
    }
    
    /// Stops the background sync timer
    public func stopBackgroundSync() {
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.backgroundSyncTimer?.invalidate()
            self.backgroundSyncTimer = nil
            ErrorReporter.shared.info("Background sync stopped")
        }
    }
    
    /// Starts the background sync timer with the configured interval
    /// - Parameter forceStart: Whether to start the timer even if the interval is 0
    /// - Returns: True if the timer was started, false if it was already running or disabled
    @discardableResult
    public func startBackgroundSync(forceStart: Bool = false) -> Bool {
        if backgroundSyncTimer != nil {
            // Timer is already running
            return false
        }
        
        guard forceStart || configuration.backgroundSyncInterval > 0 else {
            // Background sync is disabled
            return false
        }
        
        // Set up the timer on the main thread (required for Timer)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let interval = max(60.0, self.configuration.backgroundSyncInterval) // Minimum 60 seconds
            self.backgroundSyncTimer = Timer.scheduledTimer(
                withTimeInterval: interval,
                repeats: true
            ) { [weak self] _ in
                self?.syncQueue.async {
                    self?.syncAllEntities()
                }
            }
            
            // Ensure timer fires even when scrolling
            RunLoop.current.add(self.backgroundSyncTimer!, forMode: .common)
            
            ErrorReporter.shared.info("Background sync started with interval: \(Int(interval)) seconds")
        }
        
        return true
    }
    
    /// Updates the background sync interval
    /// - Parameter interval: The new interval in seconds (0 to disable)
    public func updateBackgroundSyncInterval(_ interval: TimeInterval) {
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            
            var updatedConfig = self.configuration
            updatedConfig.backgroundSyncInterval = interval
            self.configuration = updatedConfig
            
            // Restart the timer with the new interval
            self.stopBackgroundSync()
            
            if interval > 0 {
                self.startBackgroundSync()
            }
        }
    }
    
    /// Registers a custom sync handler for an entity type
    /// - Parameters:
    ///   - entityName: The name of the entity
    ///   - handler: The custom sync handler
    public func registerCustomSyncHandler(for entityName: String, handler: @escaping () -> Void) {
        // In a real implementation, this would allow custom sync logic for specific entities
        // We're just stubbing it here for future expansion
        ErrorReporter.shared.debug("Registered custom sync handler for entity: \(entityName)")
    }
    
    /// Pauses all sync operations temporarily
    /// - Parameter completion: Called when sync operations have been paused
    public func pauseSync(completion: (() -> Void)? = nil) {
        syncQueue.async { [weak self] in
            guard let self = self else {
                completion?()
                return
            }
            
            // Cancel any ongoing sync
            self.cancelSync()
            
            // Stop background timer
            self.stopBackgroundSync()
            
            ErrorReporter.shared.info("Sync operations paused")
            completion?()
        }
    }
    
    /// Resumes sync operations after a pause
    public func resumeSync() {
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Restart background timer if it was enabled
            if self.configuration.backgroundSyncInterval > 0 {
                self.startBackgroundSync()
            }
            
            ErrorReporter.shared.info("Sync operations resumed")
        }
    }
    
    /// Removes all observers and cleans up resources
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Deinitializer that cleans up resources
    deinit {
        // Stop background timer
        backgroundSyncTimer?.invalidate()
        backgroundSyncTimer = nil
        
        // Remove notification observers
        removeObservers()
        
        // Save any pending metadata
        saveSyncMetadata()
        
        ErrorReporter.shared.debug("SyncManager is being deinitialized")
    }
}

// MARK: - Error Extensions

extension XTError {
    /// Sync-specific errors
    public enum SyncError: Error, LocalizedError {
        /// Sync manager was deallocated during operation
        case managerDeallocated
        /// A sync operation is already in progress
        case alreadyInProgress
        /// The sync operation was cancelled
        case cancelled
        /// Sync failed for a specific entity
        case syncFailed(entity: String, reason: String)
        /// Some entities failed to sync
        case partialFailure(failedEntities: [String])
        /// Conflict could not be resolved
        case unresolvableConflict(entity: String, field: String)
        
        /// A localized description of the error
        public var errorDescription: String? {
            switch self {
            case .managerDeallocated:
                return "Sync manager was deallocated during operation"
            case .alreadyInProgress:
                return "A sync operation is already in progress"
            case .cancelled:
                return "The sync operation was cancelled"
            case .syncFailed(let entity, let reason):
                return "Sync failed for entity '\(entity)': \(reason)"
            case .partialFailure(let failedEntities):
                let entityList = failedEntities.joined(separator: ", ")
                return "Some entities failed to sync: \(entityList)"
            case .unresolvableConflict(let entity, let field):
                return "Could not resolve conflict for entity '\(entity)', field '\(field)'"
            }
        }
    }
    
    /// Creates a sync error
    /// - Parameter error: The sync error
    /// - Returns: An XTError with the sync error
    public static func sync(_ error: SyncError) -> XTError {
        return XTError(domain: .sync, code: 9000, underlyingError: error)
    }
}
