import Foundation
import ENSDKObjC // Evernote SDK import

/// Represents errors that can occur during note fetching operations
public enum NoteFetcherError: Error {
    /// Authentication is missing or invalid
    case notAuthenticated
    /// Failed to fetch data from Evernote API
    case fetchFailed(String)
    /// Rate limit exceeded for Evernote API
    case rateLimitExceeded(retryAfterSeconds: Int)
    /// Note not found with specified identifier
    case noteNotFound(String)
    /// Notebook not found with specified identifier
    case notebookNotFound(String)
    /// Invalid search parameters provided
    case invalidSearchParameters(String)
    /// Network error occurred during fetching
    case networkError(Error)
    /// Failed to parse response data
    case parsingError(Error)
}

/// Represents the sorting order for fetched notes
public enum NotesSortOrder {
    /// Sort by creation date, newest first
    case createdNewest
    /// Sort by creation date, oldest first
    case createdOldest
    /// Sort by update date, newest first
    case updatedNewest
    /// Sort by update date, oldest first
    case updatedOldest
    /// Sort by title, alphabetically
    case title
}

/// Protocol defining operations for fetching notes from Evernote
public protocol NoteFetcher {
    /// Fetches a list of all notebooks available to the user
    /// - Parameter completion: Callback with result containing notebooks or error
    func fetchNotebooks(completion: @escaping (Result<[ENNotebook], NoteFetcherError>) -> Void)
    
    /// Fetches a specific notebook by its identifier
    /// - Parameters:
    ///   - notebookGuid: Unique identifier of the notebook to fetch
    ///   - completion: Callback with result containing notebook or error
    func fetchNotebook(notebookGuid: String, completion: @escaping (Result<ENNotebook, NoteFetcherError>) -> Void)
    
    /// Fetches metadata for notes in a notebook with pagination support
    /// - Parameters:
    ///   - notebookGuid: Unique identifier of the notebook containing notes
    ///   - offset: Starting position for pagination
    ///   - maxResults: Maximum number of results to return
    ///   - sortOrder: Sorting order for the returned notes
    ///   - completion: Callback with result containing note metadata or error
    func fetchNoteMetadata(
        notebookGuid: String,
        offset: Int,
        maxResults: Int,
        sortOrder: NotesSortOrder,
        completion: @escaping (Result<[ENNoteMetadata], NoteFetcherError>) -> Void
    )
    
    /// Fetches the complete note content including resources
    /// - Parameters:
    ///   - noteGuid: Unique identifier of the note to fetch
    ///   - includeResources: Whether to include resources (attachments) in the response
    ///   - completion: Callback with result containing the complete note or error
    func fetchNote(
        noteGuid: String,
        includeResources: Bool,
        completion: @escaping (Result<ENNote, NoteFetcherError>) -> Void
    )
    
    /// Searches for notes matching the provided query
    /// - Parameters:
    ///   - searchQuery: ENML search query string
    ///   - notebookGuid: Optional notebook to scope the search (nil for all notebooks)
    ///   - offset: Starting position for pagination
    ///   - maxResults: Maximum number of results to return
    ///   - completion: Callback with result containing matching notes or error
    func searchNotes(
        searchQuery: String,
        notebookGuid: String?,
        offset: Int,
        maxResults: Int,
        completion: @escaping (Result<[ENNoteMetadata], NoteFetcherError>) -> Void
    )
    
    /// Cancels any ongoing fetch operations
    func cancelFetchOperations()
}

/// Implementation of NoteFetcher using Evernote SDK
public class EvernoteNoteFetcher: NoteFetcher {
    
    /// The note store client used to interact with Evernote API
    private let noteStore: ENNoteStoreClient
    
    /// Operation queue for managing concurrent fetch operations
    private let fetchQueue: OperationQueue
    
    /// Maximum number of retry attempts for failed operations
    private let maxRetryAttempts: Int
    
    /// The delay between retry attempts in seconds
    private let retryDelayInSeconds: TimeInterval
    
    /// Initializes a new EvernoteNoteFetcher
    /// - Parameters:
    ///   - noteStore: The note store client for Evernote API interactions
    ///   - maxRetryAttempts: Maximum number of retry attempts for failed operations (default: 3)
    ///   - retryDelayInSeconds: The delay between retry attempts in seconds (default: 2.0)
    public init(
        noteStore: ENNoteStoreClient,
        maxRetryAttempts: Int = 3,
        retryDelayInSeconds: TimeInterval = 2.0
    ) {
        self.noteStore = noteStore
        self.maxRetryAttempts = maxRetryAttempts
        self.retryDelayInSeconds = retryDelayInSeconds
        
        self.fetchQueue = OperationQueue()
        self.fetchQueue.name = "com.fraqtiv.extraqtiv.notefetcher"
        self.fetchQueue.maxConcurrentOperationCount = 4
    }
    
    /// Fetches a list of all notebooks available to the user
    /// - Parameter completion: Callback with result containing notebooks or error
    public func fetchNotebooks(completion: @escaping (Result<[ENNotebook], NoteFetcherError>) -> Void) {
        // Implementation of notebook fetching with retry logic
        fetchWithRetry(retryCount: 0) { [weak self] retryCompletion in
            guard let self = self else {
                retryCompletion(.failure(.fetchFailed("NoteFetcher instance was deallocated")))
                return
            }
            
            self.noteStore.listNotebooks { notebooks, error in
                if let error = error {
                    let fetchError = self.mapEvernoteError(error)
                    retryCompletion(.failure(fetchError))
                    return
                }
                
                guard let notebooks = notebooks else {
                    retryCompletion(.failure(.fetchFailed("No notebooks were returned")))
                    return
                }
                
                retryCompletion(.success(notebooks))
            }
        } completion: { result in
            completion(result)
        }
    }
    
    /// Fetches a specific notebook by its identifier
    /// - Parameters:
    ///   - notebookGuid: Unique identifier of the notebook to fetch
    ///   - completion: Callback with result containing notebook or error
    public func fetchNotebook(notebookGuid: String, completion: @escaping (Result<ENNotebook, NoteFetcherError>) -> Void) {
        // Implementation of specific notebook fetching with retry logic
        fetchWithRetry(retryCount: 0) { [weak self] retryCompletion in
            guard let self = self else {
                retryCompletion(.failure(.fetchFailed("NoteFetcher instance was deallocated")))
                return
            }
            
            self.noteStore.getNotebook(notebookGuid) { notebook, error in
                if let error = error {
                    let fetchError = self.mapEvernoteError(error)
                    retryCompletion(.failure(fetchError))
                    return
                }
                
                guard let notebook = notebook else {
                    retryCompletion(.failure(.notebookNotFound(notebookGuid)))
                    return
                }
                
                retryCompletion(.success(notebook))
            }
        } completion: { result in
            completion(result)
        }
    }
    
    /// Fetches metadata for notes in a notebook with pagination support
    /// - Parameters:
    ///   - notebookGuid: Unique identifier of the notebook containing notes
    ///   - offset: Starting position for pagination
    ///   - maxResults: Maximum number of results to return
    ///   - sortOrder: Sorting order for the returned notes
    ///   - completion: Callback with result containing note metadata or error
    public func fetchNoteMetadata(
        notebookGuid: String,
        offset: Int,
        maxResults: Int,
        sortOrder: NotesSortOrder,
        completion: @escaping (Result<[ENNoteMetadata], NoteFetcherError>) -> Void
    ) {
        fetchWithRetry(retryCount: 0) { [weak self] retryCompletion in
            guard let self = self else {
                retryCompletion(.failure(.fetchFailed("NoteFetcher instance was deallocated")))
                return
            }
            
            let filter = ENNoteStoreClient.NoteFilter()
            filter.notebookGuid = notebookGuid
            filter.order = self.mapSortOrder(sortOrder)
            
            let resultSpec = ENNoteStoreClient.NotesMetadataResultSpec()
            resultSpec.includeTitle = true
            resultSpec.includeCreated = true
            resultSpec.includeUpdated = true
            resultSpec.includeTagGuids = true
            resultSpec.includeContentLength = true
            
            self.noteStore.findNotesMetadata(filter, offset: Int32(offset), maxNotes: Int32(maxResults), resultSpec: resultSpec) { result, error in
                if let error = error {
                    let fetchError = self.mapEvernoteError(error)
                    retryCompletion(.failure(fetchError))
                    return
                }
                
                guard let result = result, let notes = result.notes else {
                    retryCompletion(.failure(.fetchFailed("Failed to retrieve note metadata")))
                    return
                }
                
                retryCompletion(.success(notes))
            }
        } completion: { result in
            completion(result)
        }
    }
    
    /// Fetches the complete note content including resources
    /// - Parameters:
    ///   - noteGuid: Unique identifier of the note to fetch
    ///   - includeResources: Whether to include resources (attachments) in the response
    ///   - completion: Callback with result containing the complete note or error
    public func fetchNote(
        noteGuid: String,
        includeResources: Bool,
        completion: @escaping (Result<ENNote, NoteFetcherError>) -> Void
    ) {
        fetchWithRetry(retryCount: 0) { [weak self] retryCompletion in
            guard let self = self else {
                retryCompletion(.failure(.fetchFailed("NoteFetcher instance was deallocated")))
                return
            }
            
            self.noteStore.getNoteWithContent(noteGuid, withResourcesData: includeResources, withResourcesRecognition: false, withResourcesAlternateData: false) { note, error in
                if let error = error {
                    let fetchError = self.mapEvernoteError(error)
                    retryCompletion(.failure(fetchError))
                    return
                }
                
                guard let note = note else {
                    retryCompletion(.failure(.noteNotFound(noteGuid)))
                    return
                }
                
                // Convert the Evernote note to ENNote format
                let enNote = ENNote()
                enNote.title = note.title
                enNote.content = ENNoteContent(ENMLContent: note.content ?? "")
                
                // Add resources if requested and available
                if includeResources, let resources = note.resources {
                    for resource in resources {
                        guard let data = resource.data?.body else { continue }
                        let enResource = ENResource(data: data, mimeType: resource.mime, filename: resource.attributes?.fileName)
                        enNote.addResource(enResource)
                    }
                }
                
                retryCompletion(.success(enNote))
            }
        } completion: { result in
            completion(result)
        }
    }
    
    /// Searches for notes matching the provided query
    /// - Parameters:
    ///   - searchQuery: ENML search query string
    ///   - notebookGuid: Optional notebook to scope the search (nil for all notebooks)
    ///   - offset: Starting position for pagination
    ///   - maxResults: Maximum number of results to return
    ///   - completion: Callback with result containing matching notes or error
    public func searchNotes(
        searchQuery: String,
        notebookGuid: String?,
        offset: Int,
        maxResults: Int,
        completion: @escaping (Result<[ENNoteMetadata], NoteFetcherError>) -> Void
    ) {
        fetchWithRetry(retryCount: 0) { [weak self] retryCompletion in
            guard let self = self else {
                retryCompletion(.failure(.fetchFailed("NoteFetcher instance was deallocated")))
                return
            }
            
            let filter = ENNoteStoreClient.NoteFilter()
            filter.words = searchQuery
            if let notebookGuid = notebookGuid {
                filter.notebookGuid = notebookGuid
            }
            
            let resultSpec = ENNoteStoreClient.NotesMetadataResultSpec()
            resultSpec.includeTitle = true
            resultSpec.includeCreated = true
            resultSpec.includeUpdated = true
            resultSpec.includeTagGuids = true
            resultSpec.includeContentLength = true
            
            self.noteStore.findNotesMetadata(filter, offset: Int32(offset), maxNotes: Int32(maxResults), resultSpec: resultSpec) { result, error in
                if let error = error {
                    let fetchError = self.mapEvernoteError(error)
                    retryCompletion(.failure(fetchError))
                    return
                }
                
                guard let result = result, let notes = result.notes else {
                    retryCompletion(.failure(.fetchFailed("Failed to retrieve search results")))
                    return
                }
                
                retryCompletion(.success(notes))
            }
        } completion: { result in
            completion(result)
        }
    }
    
    /// Cancels any ongoing fetch operations
    public func cancelFetchOperations() {
        fetchQueue.cancelAllOperations()
    }
    
    // MARK: - Private Helper Methods
    
    /// Maps Evernote specific errors to NoteFetcherError types
    /// - Parameter error: The original Evernote error
    /// - Returns: A corresponding NoteFetcherError
    private func mapEvernoteError(_ error: Error) -> NoteFetcherError {
        // ENSDK errors can be mapped to appropriate NoteFetcherError cases
        let nsError = error as NSError
        
        // Check for rate limiting errors (specific to Evernote API)
        if nsError.domain == "EDAMErrorDomain" && nsError.code == 19 { // EDAMErrorCode.RATE_LIMIT_REACHED
            // Extract retry after seconds from the user info if available
            let retryAfter = nsError.userInfo["rateLimitDuration"] as? Int ?? 60
            return .rateLimitExceeded(retryAfterSeconds: retryAfter)
        }
        
        // Map other common Evernote API errors
        switch nsError.domain {
        case "EDAMErrorDomain":
            switch nsError.code {
            case 1: // EDAMErrorCode.UNKNOWN
                return .fetchFailed("Unknown error: \(nsError.localizedDescription

