import Foundation
import CoreData

/// `DatabaseManager` provides centralized access to the application's local database,
/// handling persistence, CRUD operations, and migrations in a thread-safe manner.
public final class DatabaseManager {
    
    // MARK: - Singleton Instance
    
    /// Shared instance of DatabaseManager
    public static let shared = DatabaseManager()
    
    // MARK: - Database Configuration
    
    /// Configuration options for the database
    public struct Configuration {
        /// The name of the data model
        let modelName: String
        
        /// The bundle containing the data model
        let bundle: Bundle
        
        /// Storage type for the persistent store
        let storeType: StoreType
        
        /// Options for the persistent store
        let storeOptions: [String: Any]?
        
        /// Migration options
        let migrationOptions: MigrationOptions
        
        /// Creates a new database configuration
        /// - Parameters:
        ///   - modelName: The name of the data model
        ///   - bundle: The bundle containing the data model (defaults to main bundle)
        ///   - storeType: Storage type for the persistent store (defaults to .sqlite)
        ///   - storeOptions: Options for the persistent store (defaults to nil)
        ///   - migrationOptions: Migration options (defaults to .automatic)
        public init(
            modelName: String,
            bundle: Bundle = .main,
            storeType: StoreType = .sqlite,
            storeOptions: [String: Any]? = nil,
            migrationOptions: MigrationOptions = .automatic
        ) {
            self.modelName = modelName
            self.bundle = bundle
            self.storeType = storeType
            self.storeOptions = storeOptions
            self.migrationOptions = migrationOptions
        }
    }
    
    /// Persistent store type options
    public enum StoreType {
        /// SQLite database
        case sqlite
        /// In-memory database
        case inMemory
        /// Binary store
        case binary
        
        /// Converts to NSPersistentStore type
        var persistentStoreType: String {
            switch self {
            case .sqlite:
                return NSSQLiteStoreType
            case .inMemory:
                return NSInMemoryStoreType
            case .binary:
                return NSBinaryStoreType
            }
        }
    }
    
    /// Migration strategy options
    public enum MigrationOptions {
        /// Automatic migration with model inference
        case automatic
        /// Light-weight migration only
        case lightweight
        /// Manual migration using migration manager
        case manual
        /// No migration (will fail if model version mismatch)
        case none
        
        /// Returns the appropriate store options for this migration strategy
        var storeOptions: [String: Any] {
            switch self {
            case .automatic:
                return [
                    NSMigratePersistentStoresAutomaticallyOption: true,
                    NSInferMappingModelAutomaticallyOption: true
                ]
            case .lightweight:
                return [
                    NSMigratePersistentStoresAutomaticallyOption: true,
                    NSInferMappingModelAutomaticallyOption: false
                ]
            case .manual, .none:
                return [:]
            }
        }
    }
    
    // MARK: - Properties
    
    /// The database configuration
    private let configuration: Configuration
    
    /// Core Data model container
    private let persistentContainer: NSPersistentContainer
    
    /// Serial queue for thread safety with database setup
    private let setupQueue = DispatchQueue(label: "com.fraqtiv.databaseSetup", qos: .userInitiated)
    
    /// Barrier queue for thread safety with background operations
    private let barrierQueue = DispatchQueue(label: "com.fraqtiv.databaseBarrier", attributes: .concurrent)
    
    /// Flag to track whether the database has been initialized
    private var isInitialized = false
    
    /// Connection pool for context reuse
    private var contextPool: [NSManagedObjectContext] = []
    
    /// Maximum number of contexts to keep in the pool
    private let maxPoolSize = 5
    
    /// Lock for context pool access
    private let poolLock = NSLock()
    
    // MARK: - Initialization
    
    /// Creates a new database manager with the specified configuration
    /// - Parameter configuration: Database configuration
    private init(configuration: Configuration? = nil) {
        // Try to load configuration from ConfigurationManager or use default
        if let config = configuration {
            self.configuration = config
        } else {
            do {
                let modelName = try ConfigurationManager.shared.string("database.modelName", defaultValue: "XTModel")
                let storeTypeString = try ConfigurationManager.shared.string("database.storeType", defaultValue: "sqlite")
                let storeType: StoreType
                switch storeTypeString.lowercased() {
                case "inmemory":
                    storeType = .inMemory
                case "binary":
                    storeType = .binary
                default:
                    storeType = .sqlite
                }
                
                let migrationOptionString = try ConfigurationManager.shared.string("database.migrationOption", defaultValue: "automatic")
                let migrationOption: MigrationOptions
                switch migrationOptionString.lowercased() {
                case "lightweight":
                    migrationOption = .lightweight
                case "manual":
                    migrationOption = .manual
                case "none":
                    migrationOption = .none
                default:
                    migrationOption = .automatic
                }
                
                self.configuration = Configuration(
                    modelName: modelName,
                    storeType: storeType,
                    migrationOptions: migrationOption
                )
            } catch {
                // If there's an error loading from config, use default values
                ErrorReporter.shared.warning("Failed to load database configuration: \(error.localizedDescription). Using default configuration.")
                self.configuration = Configuration(modelName: "XTModel")
            }
        }
        
        // Initialize the persistent container
        persistentContainer = NSPersistentContainer(name: self.configuration.modelName)
    }
    
    // MARK: - Database Setup
    
    /// Sets up the database for use
    /// - Parameter completion: Callback indicating success or failure
    public func setup(completion: ((Result<Void, XTError>) -> Void)? = nil) {
        setupQueue.async { [weak self] in
            guard let self = self else {
                completion?(.failure(.database(.initializationFailed(reason: "Database manager was deallocated"))))
                return
            }
            
            // Skip if already initialized
            if self.isInitialized {
                completion?(.success(()))
                return
            }
            
            // Combine store options
            var storeOptions = self.configuration.storeOptions ?? [:]
            let migrationOptions = self.configuration.migrationOptions.storeOptions
            for (key, value) in migrationOptions {
                storeOptions[key] = value
            }
            
            // Load the persistent stores
            self.persistentContainer.loadPersistentStores { storeDescription, error in
                if let error = error {
                    ErrorReporter.shared.error(
                        XTError.database(.initializationFailed(reason: error.localizedDescription))
                    )
                    completion?(.failure(.database(.initializationFailed(reason: error.localizedDescription))))
                    return
                }
                
                // Configure the persistent store description
                storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
                storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                
                // Set up automatic merge of changes
                self.persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
                self.persistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                
                // Initialize context pool
                self.initializeContextPool()
                
                self.isInitialized = true
                ErrorReporter.shared.info("Database initialized successfully with model: \(self.configuration.modelName)")
                completion?(.success(()))
            }
        }
    }
    
    /// Initializes the context pool with a few contexts ready for use
    private func initializeContextPool() {
        for _ in 0..<maxPoolSize/2 {
            let context = createBackgroundContext()
            poolLock.lock()
            contextPool.append(context)
            poolLock.unlock()
        }
    }
    
    /// Gets a context from the pool or creates a new one
    /// - Returns: A managed object context for background operations
    private func getContextFromPool() -> NSManagedObjectContext {
        poolLock.lock()
        defer { poolLock.unlock() }
        
        if let context = contextPool.popLast() {
            return context
        }
        
        return createBackgroundContext()
    }
    
    /// Returns a context to the pool for reuse
    /// - Parameter context: The context to return to the pool
    private func returnContextToPool(_ context: NSManagedObjectContext) {
        // Reset the context to clear its object cache
        context.reset()
        
        poolLock.lock()
        defer { poolLock.unlock() }
        
        // Only add back to the pool if we're under the max pool size
        if contextPool.count < maxPoolSize {
            contextPool.append(context)
        }
    }
    
    /// Creates a new background context
    /// - Returns: A managed object context for background operations
    private func createBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    // MARK: - Context Access
    
    /// The main managed object context, for use on the main thread
    public var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    /// Performs a block on the main context, synchronously
    /// - Parameter block: The block to execute
    /// - Returns: The result of the block
    /// - Throws: Any error thrown by the block
    public func performOnViewContext<T>(_ block: (NSManagedObjectContext) throws -> T) throws -> T {
        try viewContext.performAndWait { try block(viewContext) }
    }
    
    /// Performs a block on a background context, asynchronously
    /// - Parameters:
    ///   - block: The block to execute
    ///   - completion: Callback with the result or error
    public func performInBackground<T>(_ block: @escaping (NSManagedObjectContext) throws -> T, 
                                 completion: @escaping (Result<T, Error>) -> Void) {
        barrierQueue.async { [weak self] in
            guard let self = self else {
                completion(.failure(XTError.database(.initializationFailed(reason: "Database manager was deallocated"))))
                return
            }
            
            let context = self.getContextFromPool()
            
            context.perform {
                do {
                    let result = try block(context)
                    completion(.success(result))
                } catch {
                    if let xtError = error as? XTError {
                        completion(.failure(xtError))
                    } else {
                        completion(.failure(XTError.database(.initializationFailed(reason: error.localizedDescription))))
                    }
                }
                
                self.returnContextToPool(context)
            }
        }
    }
    
    /// Performs a block on a background context and saves the context if successful
    /// - Parameters:
    ///   - block: The block to execute
    ///   - completion: Callback with the result or error
    public func performAndSave<T>(_ block: @escaping (NSManagedObjectContext) throws -> T, 
                                 completion: @escaping (Result<T, Error>) -> Void) {
        performInBackground { context in
            let result = try block(context)
            
            if context.hasChanges {
                try context.save()
            }
            
            return result
        } completion: { result in
            completion(result)
        }
    }
    
    // MARK: - CRUD Operations
    
    /// Creates a new managed object of the specified type
    /// - Parameters:
    ///   - entityType: The entity type to create
    ///   - context: The managed object context to use (defaults to view context)
    /// - Returns: The new managed object
    public func create<T: NSManagedObject>(_ entityType: T.Type, in context: NSManagedObjectContext? = nil) -> T {
        let ctx = context ?? viewContext
        let entityName = String(describing: entityType)
        let entity = NSEntityDescription.entity(forEntityName: entityName, in: ctx)!
        return T(entity: entity, insertInto: ctx)
    }
    
    /// Fetches objects that match the provided predicate
    /// - Parameters:
    ///   - entityType: The entity type to fetch
    ///   - predicate: Optional predicate to filter the results
    ///   - sortDescriptors: Optional sort descriptors for the results
    ///   - context: The managed object context to use (defaults to view context)
    /// - Returns: An array of matching objects
    /// - Throws: An error if the fetch fails
    public func fetch<T: NSManagedObject>(_ entityType: T.Type, 
                                      predicate: NSPredicate? = nil, 
                                      sortDescriptors: [NSSortDescriptor]? = nil, 
                                      in context: NSManagedObjectContext? = nil) throws -> [T] {
        let ctx = context ?? viewContext
        let request = entityType.fetchRequest()
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        
        do {
            let results = try ctx.fetch(request)
            return results as! [T]
        } catch {
            let entityName = String(describing: entityType)
            ErrorReporter.shared.error(
                XTError.database(.fetchFailed(entity: entityName, underlyingError: error)),
                context: ["predicate": String(describing: predicate)]
            )
            throw XTError.database(.fetchFailed(entity: entityName, underlyingError: error))
        }
    }
    
    /// Fetches a single object that matches the provided predicate
    /// - Parameters:
    ///   - entityType: The entity type to fetch
    ///   - predicate: The predicate to filter the results
    ///   - sortDescriptors: Optional sort descriptors for the results
    ///   - context: The managed object context to use (defaults to view context)
    /// - Returns: The matching object, or nil if no match is found
    /// - Throws: An error if the fetch fails
    public func fetchOne<T: NSManagedObject>(_ entityType: T.Type, 
                                        predicate: NSPredicate, 
                                        sortDescriptors: [NSSortDescriptor]? = nil, 
                                        in context: NSManagedObjectContext? = nil) throws -> T? {
        let ctx = context ?? viewContext
        let request = entityType.fetchRequest()
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        request.fetchLimit = 1
        
        do {
            let results = try ctx.fetch(request)
            return results.first as? T
        } catch {
            let entityName = String(describing: entityType)
            ErrorReporter.shared.error(
                XTError.database(.fetchFailed(entity: entityName, underlyingError: error)),
                context: ["predicate": String(describing: predicate)]
            )
            throw XTError.database(.fetchFailed(entity: entityName, underlyingError: error))
        }
    }
    
    /// Counts objects that match the provided predicate
    /// - Parameters:
    ///   - entityType: The entity type to count
    ///   - predicate: Optional predicate to filter the results
    ///   - context: The managed object context to use (defaults to view context)
    /// - Returns: The count of matching objects
    /// - Throws: An error if the fetch fails
    public func count<T: NSManagedObject>(_ entityType: T.Type, 
                                     predicate: NSPredicate? = nil, 
                                     in context: NSManagedObjectContext? = nil) throws -> Int {
        let ctx = context ?? viewContext
        let request = entityType.fetchRequest()
        request.predicate = predicate
        
        do {
            return try ctx.count(for: request)
        } catch {
            let entityName = String(describing: entityType)
            ErrorReporter.shared.error(
                XTError.database(.fetchFailed(entity: entityName, underlyingError: error)),
                context: ["predicate": String(describing: predicate)]
            )
            throw XTError.database(.fetchFailed(entity: entityName, underlyingError: error))
        }
    }
    
    /// Saves changes in the given context
    /// - Parameter context: The managed object context to save (defaults to view context)
    /// - Throws: An error if the save fails
    public func save(context: NSManagedObjectContext? = nil) throws {
        let ctx = context ?? viewContext
        
        guard ctx.hasChanges else { return }
        
        do {
            try ctx.save()
        } catch {
            ErrorReporter.shared.error(
                XTError.database(.saveFailed(reason: error.localizedDescription)),
                context: ["context": String(describing: ctx)]
            )
            throw XTError.database(.saveFailed(reason: error.localizedDescription))
        }
    }
    
    /// Deletes an object from the database
    /// - Parameters:
    ///   - object: The object to delete
    ///   - context: The managed object context to use (defaults to view context)
    /// - Throws: An error if the delete fails
    public func delete(_ object: NSManagedObject, in context: NSManagedObjectContext? = nil) throws {
        let ctx = context ?? viewContext
        
        ctx.delete(object)
        
        try save(context: ctx)
    }
    
    /// Deletes objects that match the provided predicate
    /// - Parameters:
    ///   - entityType: The entity type to delete
    ///   - predicate: The predicate to filter the objects to delete
    ///   - context: The managed object context to use (defaults to view context)
    /// - Returns: The number of objects deleted
    /// - Throws: An error if the delete fails
    public func deleteAll<T: NSManagedObject>(_ entityType: T.Type, 
                                         matching predicate: NSPredicate? = nil, 
                                         in context: NSManagedObjectContext? = nil) throws -> Int {
        let ctx = context ?? viewContext
        let objects = try fetch(entityType, predicate: predicate, in: ctx)
        
        for object in objects {
            ctx.delete(object)
        }
        
        try save(context: ctx)
        return objects.count
    }
    
    // MARK: - Batch Operations
    
    /// Performs a batch update operation
    /// - Parameters:
    ///   - entityType: The entity type to update
    ///   - predicate: Optional predicate to filter the objects to update
    ///   - propertiesToUpdate: Dictionary of property names and their new values
    /// - Returns: The number of objects updated
    /// - Throws: An error if the batch update fails
    public func batchUpdate<T: NSManagedObject>(_ entityType: T.Type, 
                                           matching predicate: NSPredicate? = nil, 
                                           propertiesToUpdate: [String: Any]) throws -> Int {
        let entityName = String(describing: entityType)
        let batchUpdateRequest = NSBatchUpdateRequest(entityName: entityName)
        batchUpdateRequest.predicate = predicate
        batchUpdateRequest.propertiesToUpdate = propertiesToUpdate
        batchUpdateRequest.resultType = .updatedObjectIDsResultType
        
        do {
            let result = try persistentContainer.viewContext.execute(batchUpdateRequest) as? NSBatchUpdateResult
            
            guard let objectIDs = result?.result as? [NSManagedObjectID] else {
                return 0
            }
            
            // Merge changes into view context
            let changes = [NSUpdatedObjectsKey: objectIDs]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [persistentContainer.viewContext])
            
            // Return the number of updates
            return objectIDs.count
        } catch {
            ErrorReporter.shared.error(
                XTError.database(.updateFailed(entity: entityName, underlyingError: error)),
                context: ["predicate": String(describing: predicate), "properties": propertiesToUpdate]
            )
            throw XTError.database(.updateFailed(entity: entityName, underlyingError: error))
        }
    }
    
    /// Performs a batch delete operation
    /// - Parameters:
    ///   - entityType: The entity type to delete
    ///   - predicate: Optional predicate to filter the objects to delete
    /// - Returns: The number of objects deleted
    /// - Throws: An error if the batch delete fails
    public func batchDelete<T: NSManagedObject>(_ entityType: T.Type, matching predicate: NSPredicate? = nil) throws -> Int {
        let entityName = String(describing: entityType)
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        fetchRequest.predicate = predicate
        
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        batchDeleteRequest.resultType = .resultTypeObjectIDs
        
        do {
            let result = try persistentContainer.viewContext.execute(batchDeleteRequest) as? NSBatchDeleteResult
            
            guard let objectIDs = result?.result as? [NSManagedObjectID] else {
                return 0
            }
            
            // Merge changes into view context
            let changes = [NSDeletedObjectsKey: objectIDs]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [persistentContainer.viewContext])
            
            // Return the number of deletions
            return objectIDs.count
        } catch {
            ErrorReporter.shared.error(
                XTError.database(.deleteFailed(entity: entityName, underlyingError: error)),
                context: ["predicate": String(describing: predicate)]
            )
            throw XTError.database(.deleteFailed(entity: entityName, underlyingError: error))
        }
    }
    
    // MARK: - Transaction Support
    
    /// Performs a transaction with multiple operations
    /// - Parameters:
    ///   - block: The block containing multiple operations to perform as a single transaction
    ///   - context: The context to use for the transaction (a new one will be created if nil)
    /// - Returns: The result of the transaction block
    /// - Throws: Any error that occurs during the transaction
    public func performTransaction<T>(_ block: (NSManagedObjectContext) throws -> T, in context: NSManagedObjectContext? = nil) throws -> T {
        let transactionContext = context ?? createBackgroundContext()
        
        // Begin transaction
        var result: T!
        var transactionError: Error?
        
        transactionContext.performAndWait {
            do {
                result = try block(transactionContext)
                
                // Save the changes if there are any
                if transactionContext.hasChanges {
                    try transactionContext.save()
                }
            } catch {
                transactionError = error
                transactionContext.rollback()
            }
        }
        
        // If we created a new context for this transaction, don't return it to the pool
        if context == nil {
            transactionContext.reset()
        }
        
        // Propagate any error
        if let error = transactionError {
            if let xtError = error as? XTError {
                throw xtError
            } else {
                throw XTError.database(.transactionFailed(reason: error.localizedDescription))
            }
        }
        
        return result
    }
    
    /// Asynchronously performs a transaction with multiple operations
    /// - Parameters:
    ///   - block: The block containing multiple operations to perform as a single transaction
    ///   - completion: Callback with the result or error
    public func performTransactionAsync<T>(_ block: @escaping (NSManagedObjectContext) throws -> T, 
                                     completion: @escaping (Result<T, Error>) -> Void) {
        let context = createBackgroundContext()
        
        barrierQueue.async { [weak self] in
            guard let self = self else {
                completion(.failure(XTError.database(.initializationFailed(reason: "Database manager was deallocated"))))
                return
            }
            
            context.perform {
                do {
                    let result = try block(context)
                    
                    if context.hasChanges {
                        try context.save()
                    }
                    
                    completion(.success(result))
                } catch {
                    context.rollback()
                    
                    if let xtError = error as? XTError {
                        completion(.failure(xtError))
                    } else {
                        completion(.failure(XTError.database(.transactionFailed(reason: error.localizedDescription))))
                    }
                }
                
                context.reset()
            }
        }
    }
    
    // MARK: - Migration Support
    
    /// Checks if the current model requires migration
    /// - Returns: True if migration is needed, false otherwise
    public func needsMigration() -> Bool {
        guard let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else {
            return false
        }
        
        do {
            let sourceMetadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: configuration.storeType.persistentStoreType,
                at: storeURL
            )
            
            let managedObjectModel = persistentContainer.managedObjectModel
            return !managedObjectModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: sourceMetadata)
        } catch {
            ErrorReporter.shared.warning("Failed to check migration status: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Performs a manual migration of the database
    /// - Parameter completion: Callback indicating success or failure
    public func performManualMigration(completion: @escaping (Result<Void, XTError>) -> Void) {
        guard let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else {
            completion(.failure(.database(.migrationFailed(reason: "No persistent store URL"))))
            return
        }
        
        setupQueue.async { [weak self] in
            guard let self = self else {
                completion(.failure(.database(.initializationFailed(reason: "Database manager was deallocated"))))
                return
            }
            
            do {
                // Create a model from the current model bundle
                guard let sourceModel = NSManagedObjectModel.mergedModel(from: [self.configuration.bundle]) else {
                    throw XTError.database(.migrationFailed(reason: "Failed to create source model"))
                }
                
                // Get the destination model
                guard let destinationModel = persistentContainer.managedObjectModel else {
                    throw XTError.database(.migrationFailed(reason: "Failed to get destination model"))
                }
                
                // Create the mapping model
                guard let mappingModel = NSMappingModel(from: [self.configuration.bundle], forSourceModel: sourceModel, destinationModel: destinationModel) else {
                    throw XTError.database(.migrationFailed(reason: "Failed to create mapping model"))
                }
                
                // Create the migration manager
                let migrationManager = NSMigrationManager(sourceModel: sourceModel, destinationModel: destinationModel)
                
                // Create a temporary destination URL
                let temporaryURL = storeURL.deletingLastPathComponent().appendingPathComponent("migration_temp.sqlite")
                
                // Remove any existing temporary store
                try? FileManager.default.removeItem(at: temporaryURL)
                
                // Perform the migration
                try migrationManager.migrateStore(
                    from: storeURL,
                    sourceType: self.configuration.storeType.persistentStoreType,
                    options: nil,
                    with: mappingModel,
                    toDestinationURL: temporaryURL,
                    destinationType: self.configuration.storeType.persistentStoreType,
                    destinationOptions: nil
                )
                
                // Close the current store
                try self.closeDatabase()
                
                // Replace the old store with the new one
                try FileManager.default.removeItem(at: storeURL)
                try FileManager.default.moveItem(at: temporaryURL, to: storeURL)
                
                // Reinitialize the persistent container
                self.isInitialized = false
                self.setup { result in
                    switch result {
                    case .success:
                        ErrorReporter.shared.info("Manual database migration completed successfully")
                        completion(.success(()))
                    case .failure(let error):
                        ErrorReporter.shared.error(error, context: ["step": "Reinitializing database after migration"])
                        completion(.failure(error))
                    }
                }
            } catch {
                let xtError = error as? XTError ?? .database(.migrationFailed(reason: error.localizedDescription))
                ErrorReporter.shared.error(xtError, context: ["storeURL": storeURL.absoluteString])
                completion(.failure(xtError))
            }
        }
    }
    
    /// Returns the list of available model versions in the bundle
    /// - Returns: Array of model version names, sorted by version
    public func availableModelVersions() -> [String] {
        let modelName = configuration.modelName
        let bundle = configuration.bundle
        
        // Look for .momd bundle
        guard let modelURL = bundle.url(forResource: modelName, withExtension: "momd") else {
            // If no versioned model exists, check for a single model
            if bundle.url(forResource: modelName, withExtension: "mom") != nil {
                return [modelName]
            }
            return []
        }
        
        // List the contents of the .momd bundle
        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(at: modelURL, includingPropertiesForKeys: nil, options: [])
            
            // Filter for .mom files and extract the version names
            let versions = contents.filter { $0.pathExtension == "mom" }
                .map { $0.deletingPathExtension().lastPathComponent }
                .sorted()
            
            return versions
        } catch {
            ErrorReporter.shared.warning("Failed to list model versions: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Gets the current model version of the database
    /// - Returns: The current model version or nil if unknown
    public func currentModelVersion() -> String? {
        guard let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else {
            return nil
        }
        
        do {
            // Get metadata from the store
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: configuration.storeType.persistentStoreType,
                at: storeURL
            )
            
            // Extract the model version from metadata
            if let versionIdentifiers = metadata[NSStoreModelVersionIdentifiersKey] as? [String],
               let firstVersion = versionIdentifiers.first {
                return firstVersion
            }
            
            return nil
        } catch {
            ErrorReporter.shared.warning("Failed to get current model version: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Database Maintenance
    
    /// Performs database maintenance operations
    /// - Parameter completion: Callback indicating success or failure
    public func performMaintenance(completion: @escaping (Result<Void, XTError>) -> Void) {
        // Only SQLite stores can be maintained
        guard configuration.storeType == .sqlite,
              let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else {
            completion(.success(()))
            return
        }
        
        setupQueue.async { [weak self] in
            guard let self = self else {
                completion(.failure(.database(.initializationFailed(reason: "Database manager was deallocated"))))
                return
            }
            
            do {
                // First close the database
                try self.closeDatabase()
                
                // Open a direct connection to the SQLite database
                var db: OpaquePointer? = nil
                let result = sqlite3_open(storeURL.path, &db)
                
                defer {
                    // Always close the database
                    if db != nil {
                        sqlite3_close(db)
                    }
                }
                
                guard result == SQLITE_OK else {
                    throw XTError.database(.maintenanceFailed(reason: "Failed to open database: \(result)"))
                }
                
                // Perform integrity check
                var errorMsg: UnsafeMutablePointer<Int8>? = nil
                let checkQuery = "PRAGMA integrity_check;"
                let checkResult = sqlite3_exec(db, checkQuery, nil, nil, &errorMsg)
                
                if checkResult != SQLITE_OK {
                    let errorString = String(cString: errorMsg!)
                    sqlite3_free(errorMsg)
                    throw XTError.database(.maintenanceFailed(reason: "Integrity check failed: \(errorString)"))
                }
                
                // Perform vacuum
                let vacuumQuery = "VACUUM;"
                let vacuumResult = sqlite3_exec(db, vacuumQuery, nil, nil, &errorMsg)
                
                if vacuumResult != SQLITE_OK {
                    let errorString = String(cString: errorMsg!)
                    sqlite3_free(errorMsg)
                    throw XTError.database(.maintenanceFailed(reason: "Vacuum failed: \(errorString)"))
                }
                
                // Analyze for query optimization
                let analyzeQuery = "ANALYZE;"
                let analyzeResult = sqlite3_exec(db, analyzeQuery, nil, nil, &errorMsg)
                
                if analyzeResult != SQLITE_OK {
                    let errorString = String(cString: errorMsg!)
                    sqlite3_free(errorMsg)
                    throw XTError.database(.maintenanceFailed(reason: "Analyze failed: \(errorString)"))
                }
                
                // Reinitialize the database
                self.isInitialized = false
                self.setup { result in
                    switch result {
                    case .success:
                        ErrorReporter.shared.info("Database maintenance completed successfully")
                        completion(.success(()))
                    case .failure(let error):
                        ErrorReporter.shared.error(error, context: ["step": "Reinitializing database after maintenance"])
                        completion(.failure(error))
                    }
                }
            } catch {
                let xtError = error as? XTError ?? .database(.maintenanceFailed(reason: error.localizedDescription))
                ErrorReporter.shared.error(xtError, context: ["storeURL": storeURL.absoluteString])
                completion(.failure(xtError))
                
                // Try to reinitialize even after failure
                self.isInitialized = false
                self.setup { _ in }
            }
        }
    }
    
    /// Checks the integrity of the database
    /// - Parameter completion: Callback with the result indicating if the database is intact
    public func checkIntegrity(completion: @escaping (Result<Bool, XTError>) -> Void) {
        // Only SQLite stores can be checked
        guard configuration.storeType == .sqlite,
              let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else {
            completion(.success(true))
            return
        }
        
        setupQueue.async { [weak self] in
            guard let self = self else {
                completion(.failure(.database(.initializationFailed(reason: "Database manager was deallocated"))))
                return
            }
            
            do {
                // Open a direct connection to the SQLite database
                var db: OpaquePointer? = nil
                let result = sqlite3_open(storeURL.path, &db)
                
                defer {
                    // Always close the database
                    if db != nil {
                        sqlite3_close(db)
                    }
                }
                
                guard result == SQLITE_OK else {
                    throw XTError.database(.maintenanceFailed(reason: "Failed to open database: \(result)"))
                }
                
                // Perform integrity check
                var errorMsg: UnsafeMutablePointer<Int8>? = nil
                let checkQuery = "PRAGMA integrity_check;"
                let checkResult = sqlite3_exec(db, checkQuery, nil, nil, &errorMsg)
                
                if checkResult != SQLITE_OK {
                    let errorString = String(cString: errorMsg!)
                    sqlite3_free(errorMsg)
                    completion(.success(false))
                    return
                }
                
                completion(.success(true))
            } catch {
                let xtError = error as? XTError ?? .database(.maintenanceFailed(reason: error.localizedDescription))
                ErrorReporter.shared.error(xtError, context: ["storeURL": storeURL.absoluteString])
                completion(.failure(xtError))
            }
        }
    }
    
    /// Closes the database, releasing all resources
    /// - Throws: An error if the close fails
    public func closeDatabase() throws {
        guard isInitialized else { return }
        
        // Reset all contexts in the pool
        poolLock.lock()
        for context in contextPool {
            context.reset()
        }
        contextPool.removeAll()
        poolLock.unlock()
        
        // Reset the view context
        persistentContainer.viewContext.reset()
        
        // Get the persistent store coordinator
        let coordinator = persistentContainer.persistentStoreCoordinator
        
        // Remove all persistent stores
        for store in coordinator.persistentStores {
            do {
                try coordinator.remove(store)
            } catch {
                throw XTError.database(.closeFailed(reason: error.localizedDescription))
            }
        }
        
        isInitialized = false
    }
    
    /// Resets the database by removing all data
    /// - Parameter completion: Callback indicating success or failure
    public func resetDatabase(completion: @escaping (Result<Void, XTError>) -> Void) {
        guard let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else {
            completion(.failure(.database(.resetFailed(reason: "No persistent store URL"))))
            return
        }
        
        setupQueue.async { [weak self] in
            guard let self = self else {
                completion(.failure(.database(.initializationFailed(reason: "Database manager was deallocated"))))
                return
            }
            
            do {
                // Close the database
                try self.closeDatabase()
                
                // Delete the database file and all related files
                let fileManager = FileManager.default
                let storeDirectory = storeURL.deletingLastPathComponent()
                let storeName = storeURL.lastPathComponent
                
                // Get all files related to this store
                let dirContents = try fileManager.contentsOfDirectory(
                    at: storeDirectory,
                    includingPropertiesForKeys: nil
                )
                
                // Find all related database files (main db, wal, journal, etc)
                let storeFiles = dirContents.filter { url in
                    let filename = url.lastPathComponent
                    return filename == storeName ||
                           filename.hasPrefix("\(storeName)-wal") ||
                           filename.hasPrefix("\(storeName)-shm") ||
                           filename.hasPrefix("\(storeName)-journal")
                }
                
                // Delete all related files
                for fileURL in storeFiles {
                    try fileManager.removeItem(at: fileURL)
                }
                
                ErrorReporter.shared.info("Database reset: Deleted \(storeFiles.count) database files")
                
                // Reinitialize the database
                self.isInitialized = false
                self.setup { result in
                    switch result {
                    case .success:
                        ErrorReporter.shared.info("Database reset completed successfully")
                        completion(.success(()))
                    case .failure(let error):
                        ErrorReporter.shared.error(error, context: ["step": "Reinitializing database after reset"])
                        completion(.failure(error))
                    }
                }
            } catch {
                let xtError = error as? XTError ?? .database(.resetFailed(reason: error.localizedDescription))
                ErrorReporter.shared.error(xtError, context: ["storeURL": storeURL.absoluteString])
                completion(.failure(xtError))
                
                // Try to reinitialize even after failure
                self.isInitialized = false
                self.setup { _ in }
            }
        }
    }
    
    /// Cleans up temporary files created during operations like migrations
    public func cleanupTemporaryFiles() {
        guard let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else {
            return
        }
        
        setupQueue.async {
            do {
                let fileManager = FileManager.default
                let storeDirectory = storeURL.deletingLastPathComponent()
                
                // Get all files in the directory
                let dirContents = try fileManager.contentsOfDirectory(
                    at: storeDirectory,
                    includingPropertiesForKeys: nil
                )
                
                // Find all temporary database files
                let tempFiles = dirContents.filter { url in
                    let filename = url.lastPathComponent
                    return filename.contains("migration_temp") ||
                           filename.contains("temp_store") ||
                           filename.hasSuffix(".bak")
                }
                
                // Delete all temporary files
                var deletedCount = 0
                for fileURL in tempFiles {
                    do {
                        try fileManager.removeItem(at: fileURL)
                        deletedCount += 1
                    } catch {
                        ErrorReporter.shared.warning("Failed to delete temporary file: \(fileURL.lastPathComponent), error: \(error.localizedDescription)")
                    }
                }
                
                if deletedCount > 0 {
                    ErrorReporter.shared.info("Cleaned up \(deletedCount) temporary database files")
                }
            } catch {
                ErrorReporter.shared.warning("Failed to clean up temporary files: \(error.localizedDescription)")
            }
        }
    }
    
    /// Backs up the database to a specified URL
    /// - Parameters:
    ///   - backupURL: The URL to save the backup to
    ///   - completion: Callback indicating success or failure
    public func backupDatabase(to backupURL: URL, completion: @escaping (Result<Void, XTError>) -> Void) {
        guard let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else {
            completion(.failure(.database(.backupFailed(reason: "No persistent store URL"))))
            return
        }
        
        setupQueue.async { [weak self] in
            guard let self = self else {
                completion(.failure(.database(.initializationFailed(reason: "Database manager was deallocated"))))
                return
            }
            
            do {
                // Ensure the destination directory exists
                try FileManager.default.createDirectory(
                    at: backupURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                
                // Save any pending changes
                if persistentContainer.viewContext.hasChanges {
                    try persistentContainer.viewContext.save()
                }
                
                // Copy the database file
                try FileManager.default.copyItem(at: storeURL, to: backupURL)
                
                // Copy related files if they exist
                let walURL = storeURL.appendingPathExtension("wal")
                let shmURL = storeURL.appendingPathExtension("shm")
                
                if FileManager.default.fileExists(atPath: walURL.path) {
                    try FileManager.default.copyItem(at: walURL, to: backupURL.appendingPathExtension("wal"))
                }
                
                if FileManager.default.fileExists(atPath: shmURL.path) {
                    try FileManager.default.copyItem(at: shmURL, to: backupURL.appendingPathExtension("shm"))
                }
                
                ErrorReporter.shared.info("Database backed up successfully to \(backupURL.path)")
                completion(.success(()))
            } catch {
                let xtError = error as? XTError ?? .database(.backupFailed(reason: error.localizedDescription))
                ErrorReporter.shared.error(xtError, context: ["source": storeURL.path, "destination": backupURL.path])
                completion(.failure(xtError))
            }
        }
    }
    
    /// Restores the database from a backup URL
    /// - Parameters:
    ///   - backupURL: The URL of the backup file
    ///   - completion: Callback indicating success or failure
    public func restoreDatabase(from backupURL: URL, completion: @escaping (Result<Void, XTError>) -> Void) {
        guard let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else {
            completion(.failure(.database(.restoreFailed(reason: "No persistent store URL"))))
            return
        }
        
        setupQueue.async { [weak self] in
            guard let self = self else {
                completion(.failure(.database(.initializationFailed(reason: "Database manager was deallocated"))))
                return
            }
            
            do {
                // Close the database
                try self.closeDatabase()
                
                // Remove existing database files
                if FileManager.default.fileExists(atPath: storeURL.path) {
                    try FileManager.default.removeItem(at: storeURL)
                }
                
                let walURL = storeURL.appendingPathExtension("wal")
                let shmURL = storeURL.appendingPathExtension("shm")
                
                if FileManager.default.fileExists(atPath: walURL.path) {
                    try FileManager.default.removeItem(at: walURL)
                }
                
                if FileManager.default.fileExists(atPath: shmURL.path) {
                    try FileManager.default.removeItem(at: shmURL)
                }
                
                // Copy the backup files
                try FileManager.default.copyItem(at: backupURL, to: storeURL)
                
                // Copy related backup files if they exist
                let backupWalURL = backupURL.appendingPathExtension("wal")
                let backupShmURL = backupURL.appendingPathExtension("shm")
                
                if FileManager.default.fileExists(atPath: backupWalURL.path) {
                    try FileManager.default.copyItem(at: backupWalURL, to: walURL)
                }
                
                if FileManager.default.fileExists(atPath: backupShmURL.path) {
                    try FileManager.default.copyItem(at: backupShmURL, to: shmURL)
                }
                
                // Reinitialize the database
                self.setup { result in
                    switch result {
                    case .success:
                        ErrorReporter.shared.info("Database restored successfully from \(backupURL.path)")
                        completion(.success(()))
                    case .failure(let error):
                        ErrorReporter.shared.error(error, context: ["step": "Reinitializing database after restore"])
                        completion(.failure(error))
                    }
                }
            } catch {
                let xtError = error as? XTError ?? .database(.restoreFailed(reason: error.localizedDescription))
                ErrorReporter.shared.error(xtError, context: ["source": backupURL.path, "destination": storeURL.path])
                completion(.failure(xtError))
                
                // Try to reinitialize even after failure
                self.isInitialized = false
                self.setup { _ in }
            }
        }
    }
    
    // MARK: - Resource Management
    
    /// Releases all resources used by the database manager
    public func shutdown() {
        setupQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                try self.closeDatabase()
                ErrorReporter.shared.info("Database manager shutdown successfully")
            } catch {
                ErrorReporter.shared.error(
                    XTError.database(.closeFailed(reason: error.localizedDescription))
                )
            }
        }
    }
    
    /// Deinitializer to clean up resources
    deinit {
        // Reset all contexts in the pool
        poolLock.lock()
        for context in contextPool {
            context.reset()
        }
        contextPool.removeAll()
        poolLock.unlock()
        
        // Reset the view context if possible
        persistentContainer.viewContext.reset()
        
        ErrorReporter.shared.debug("DatabaseManager deinitializing")
    }
}

// MARK: - SQLite Integration

// Import SQLite for direct database maintenance
import SQLite3
