import Foundation
import Combine

/// `SearchManager` provides search capabilities across multiple entities,
/// with support for indexing, result ranking, filtering, and caching.
public final class SearchManager {
    
    // MARK: - Types and Constants
    
    /// Configuration for search operations
    public struct SearchConfiguration {
        /// Minimum character count to trigger search
        let minimumSearchLength: Int
        /// Maximum number of results to return per entity type
        let maxResultsPerEntityType: Int
        /// Default search timeout in seconds
        let searchTimeout: TimeInterval
        /// Whether to enable result caching
        let enableResultCaching: Bool
        /// Maximum age for cached results in seconds
        let maxCacheAge: TimeInterval
        /// Maximum number of items to keep in cache
        let maxCacheItems: Int
        /// Whether to enable search indexing
        let enableIndexing: Bool
        /// Time interval between index updates
        let indexUpdateInterval: TimeInterval
        /// Whether to perform fuzzy matching
        let enableFuzzyMatching: Bool
        /// Relevance threshold for fuzzy matches (0.0-1.0)
        let fuzzyMatchThreshold: Double
        
        /// Creates a search configuration with default or specified values
        /// - Parameters:
        ///   - minimumSearchLength: Minimum character count to trigger search
        ///   - maxResultsPerEntityType: Maximum number of results to return per entity type
        ///   - searchTimeout: Default search timeout in seconds
        ///   - enableResultCaching: Whether to enable result caching
        ///   - maxCacheAge: Maximum age for cached results in seconds
        ///   - maxCacheItems: Maximum number of items to keep in cache
        ///   - enableIndexing: Whether to enable search indexing
        ///   - indexUpdateInterval: Time interval between index updates
        ///   - enableFuzzyMatching: Whether to perform fuzzy matching
        ///   - fuzzyMatchThreshold: Relevance threshold for fuzzy matches (0.0-1.0)
        public init(
            minimumSearchLength: Int = 2,
            maxResultsPerEntityType: Int = 50,
            searchTimeout: TimeInterval = 30.0,
            enableResultCaching: Bool = true,
            maxCacheAge: TimeInterval = 300.0, // 5 minutes
            maxCacheItems: Int = 100,
            enableIndexing: Bool = true,
            indexUpdateInterval: TimeInterval = 3600.0, // 1 hour
            enableFuzzyMatching: Bool = true,
            fuzzyMatchThreshold: Double = 0.7
        ) {
            self.minimumSearchLength = minimumSearchLength
            self.maxResultsPerEntityType = maxResultsPerEntityType
            self.searchTimeout = searchTimeout
            self.enableResultCaching = enableResultCaching
            self.maxCacheAge = maxCacheAge
            self.maxCacheItems = maxCacheItems
            self.enableIndexing = enableIndexing
            self.indexUpdateInterval = indexUpdateInterval
            self.enableFuzzyMatching = enableFuzzyMatching
            self.fuzzyMatchThreshold = fuzzyMatchThreshold
        }
    }
    
    /// A search result item
    public struct SearchResult: Identifiable, Hashable {
        /// Unique identifier for the result
        public let id: String
        /// The entity type of the result
        public let entityType: String
        /// The display title for the result
        public let title: String
        /// Optional subtitle/description for the result
        public let subtitle: String?
        /// Optional URL for an image associated with the result
        public let imageURL: URL?
        /// Optional dictionary of additional details
        public let details: [String: String]?
        /// Relevance score (0.0-1.0)
        public let relevanceScore: Double
        /// Dictionary of facet values
        public let facets: [String: String]?
        /// The raw entity data
        public let rawData: Any
        
        /// Creates a search result
        /// - Parameters:
        ///   - id: Unique identifier for the result
        ///   - entityType: The entity type of the result
        ///   - title: The display title for the result
        ///   - subtitle: Optional subtitle/description for the result
        ///   - imageURL: Optional URL for an image associated with the result
        ///   - details: Optional dictionary of additional details
        ///   - relevanceScore: Relevance score (0.0-1.0)
        ///   - facets: Dictionary of facet values
        ///   - rawData: The raw entity data
        public init(
            id: String,
            entityType: String,
            title: String,
            subtitle: String? = nil,
            imageURL: URL? = nil,
            details: [String: String]? = nil,
            relevanceScore: Double = 1.0,
            facets: [String: String]? = nil,
            rawData: Any
        ) {
            self.id = id
            self.entityType = entityType
            self.title = title
            self.subtitle = subtitle
            self.imageURL = imageURL
            self.details = details
            self.relevanceScore = relevanceScore
            self.facets = facets
            self.rawData = rawData
        }
        
        /// Support for Hashable
        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(entityType)
        }
        
        /// Support for Equatable
        public static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
            lhs.id == rhs.id && lhs.entityType == rhs.entityType
        }
    }
    
    /// A collection of search results
    public struct SearchResults {
        /// The query that produced these results
        public let query: String
        /// The search filters that were applied
        public let filters: [SearchFilter]?
        /// The results, grouped by entity type
        public let resultsByType: [String: [SearchResult]]
        /// The total number of results
        public let totalCount: Int
        /// Whether the search was truncated due to exceeding the maximum result count
        public let isTruncated: Bool
        /// The time when the results were generated
        public let timestamp: Date
        
        /// All results as a flat array, sorted by relevance
        public var allResults: [SearchResult] {
            let flattened = resultsByType.values.flatMap { $0 }
            return flattened.sorted { $0.relevanceScore > $1.relevanceScore }
        }
        
        /// Get results for a specific entity type
        /// - Parameter entityType: The entity type
        /// - Returns: Results for the specified entity type
        public func results(for entityType: String) -> [SearchResult] {
            return resultsByType[entityType] ?? []
        }
        
        /// Get all available facet values
        /// - Returns: Dictionary of facet values grouped by facet name
        public func availableFacets() -> [String: Set<String>] {
            var facets: [String: Set<String>] = [:]
            
            for result in allResults {
                guard let resultFacets = result.facets else { continue }
                
                for (key, value) in resultFacets {
                    if facets[key] == nil {
                        facets[key] = []
                    }
                    facets[key]?.insert(value)
                }
            }
            
            return facets
        }
    }
    
    /// A filter for search results
    public struct SearchFilter: Hashable {
        /// The type of filter
        public enum FilterType {
            /// Filter by entity type
            case entityType
            /// Filter by a specific facet
            case facet(name: String)
            /// Filter by a date range
            case dateRange
            /// Filter by a numeric range
            case numericRange
            /// Custom filter
            case custom(identifier: String)
        }
        
        /// The filter type
        public let type: FilterType
        /// The value to filter on
        public let value: String
        /// Whether to include or exclude matches
        public let isExclusion: Bool
        
        /// Creates a search filter
        /// - Parameters:
        ///   - type: The filter type
        ///   - value: The value to filter on
        ///   - isExclusion: Whether to include or exclude matches (default: false)
        public init(type: FilterType, value: String, isExclusion: Bool = false) {
            self.type = type
            self.value = value
            self.isExclusion = isExclusion
        }
        
        /// Support for Hashable
        public func hash(into hasher: inout Hasher) {
            switch type {
            case .entityType:
                hasher.combine("entityType")
            case .facet(let name):
                hasher.combine("facet")
                hasher.combine(name)
            case .dateRange:
                hasher.combine("dateRange")
            case .numericRange:
                hasher.combine("numericRange")
            case .custom(let identifier):
                hasher.combine("custom")
                hasher.combine(identifier)
            }
            hasher.combine(value)
            hasher.combine(isExclusion)
        }
        
        /// Support for Equatable
        public static func == (lhs: SearchFilter, rhs: SearchFilter) -> Bool {
            if case .entityType = lhs.type, case .entityType = rhs.type,
               lhs.value == rhs.value, lhs.isExclusion == rhs.isExclusion {
                return true
            } else if case .facet(let lName) = lhs.type, case .facet(let rName) = rhs.type,
                      lName == rName, lhs.value == rhs.value, lhs.isExclusion == rhs.isExclusion {
                return true
            } else if case .dateRange = lhs.type, case .dateRange = rhs.type,
                      lhs.value == rhs.value, lhs.isExclusion == rhs.isExclusion {
                return true
            } else if case .numericRange = lhs.type, case .numericRange = rhs.type,
                      lhs.value == rhs.value, lhs.isExclusion == rhs.isExclusion {
                return true
            } else if case .custom(let lIdentifier) = lhs.type, case .custom(let rIdentifier) = rhs.type,
                      lIdentifier == rIdentifier, lhs.value == rhs.value, lhs.isExclusion == rhs.isExclusion {
                return true
            }
            return false
        }
    }
    
    /// A search query with optional filters and sort options
    public struct SearchQuery: Hashable {
        /// The search text
        public let searchText: String
        /// Optional array of filters to apply
        public let filters: [SearchFilter]?
        /// Optional property to sort results by
        public let sortBy: String?
        /// Whether to sort in ascending order
        public let sortAscending: Bool
        /// Maximum number of results to return
        public let maxResults: Int?
        
        /// Creates a search query
        /// - Parameters:
        ///   - searchText: The search text
        ///   - filters: Optional array of filters to apply
        ///   - sortBy: Optional property to sort results by
        ///   - sortAscending: Whether to sort in ascending order (default: true)
        ///   - maxResults: Maximum number of results to return
        public init(
            searchText: String,
            filters: [SearchFilter]? = nil,
            sortBy: String? = nil,
            sortAscending: Bool = true,
            maxResults: Int? = nil
        ) {
            self.searchText = searchText
            self.filters = filters
            self.sortBy = sortBy
            self.sortAscending = sortAscending
            self.maxResults = maxResults
        }
        
        /// Creates a hash value for the search query
        public func hash(into hasher: inout Hasher) {
            hasher.combine(searchText)
            if let filters = filters {
                for filter in filters {
                    hasher.combine(filter)
                }
            }
            hasher.combine(sortBy)
            hasher.combine(sortAscending)
            hasher.combine(maxResults)
        }
    }
    
    /// Protocol for indexable entity types
    public protocol Searchable {
        /// The entity type name
        static var searchableTypeName: String { get }
        /// The unique identifier for the entity
        var searchableId: String { get }
        /// The primary text to search
        var searchableText: String { get }
        /// Optional secondary text to search
        var searchableSecondaryText: String? { get }
        /// Optional dictionary of additional searchable fields
        var searchableFields: [String: String]? { get }
        /// Optional dictionary of facets for filtering
        var searchableFacets: [String: String]? { get }
    }
    
    /// Result of an indexing operation
    private struct IndexingResult {
        /// The number of items indexed
        let itemsIndexed: Int
        /// The time taken to index
        let timeTaken: TimeInterval
        /// Any error that occurred
        let error: Error?
    }
    
    /// A cache item for search results
    private class CacheItem {
        /// The search query
        let query: SearchQuery
        /// The search results
        let results: SearchResults
        /// The time the results were cached
        let timestamp: Date
        
        /// Creates a cache item
        /// - Parameters:
        ///   - query: The search query
        ///   - results: The search results
        init(query: SearchQuery, results: SearchResults) {
            self.query = query
            self.results = results
            self.timestamp = Date()
        }
    }
    
    /// A mapping of normalized words to document IDs and scores
    private typealias InvertedIndex = [String: [(id: String, entityType: String, score: Double)]]
    
    // MARK: - Singleton Instance
    
    /// Shared instance of SearchManager
    public static let shared = SearchManager()
    
    // MARK: - Properties
    
    /// The search configuration
    private var configuration: SearchConfiguration
    
    /// Queue for serializing search operations
    private let searchQueue = DispatchQueue(label: "com.fraqtiv.searchManager", qos: .userInitiated)
    
    /// Queue for indexing operations
    private let indexingQueue = DispatchQueue(label: "com.fraqtiv.searchIndexing", qos: .utility)
    
    /// Subject for publishing search results
    private let searchResultsSubject = PassthroughSubject<SearchResults, XTError>()
    
    /// Publisher for search results
    public var searchResultsPublisher: AnyPublisher<SearchResults, XTError> {
        searchResultsSubject.eraseToAnyPublisher()
    }
    
    /// The inverted index for fast search
    private var invertedIndex: InvertedIndex = [:]
    
    /// Document metadata store
    private var documentMetadata: [String: [String: Any]] = [:]
    
    /// Last time the index was updated
    private var lastIndexUpdateTime: Date?
    
    /// Timer for background index updates
    private var indexUpdateTimer: Timer?
    
    /// Cache for search results
    private var searchResultsCache: [String: CacheItem] = [:]
    
    /// Current search operations, keyed by ID
    private var activeSearchOperations: [UUID: URLSessionTask] = [:]
    
    /// Lock for thread-safe access to the cache
    private let cacheLock = NSLock()
    
    // MARK: - Initialization
    
    /// Creates a new search manager with the specified configuration
    /// - Parameter configuration: Search configuration
    private init(configuration: SearchConfiguration? = nil) {
        // Try to load configuration from ConfigurationManager or use default
        if let config = configuration {
            self.configuration = config
        } else {
            do {
                // Attempt to load configuration from ConfigurationManager
                let minimumSearchLength = try ConfigurationManager.shared.int("search.minimumSearchLength", defaultValue: 2)
                let maxResultsPerEntityType = try ConfigurationManager.shared.int("search.maxResultsPerEntityType", defaultValue: 50)
                let searchTimeout = try ConfigurationManager.shared.double("search.searchTimeout", defaultValue: 30.0)
                let enableResultCaching = try ConfigurationManager.shared.bool("search.enableResultCaching", defaultValue: true)
                let maxCacheAge = try ConfigurationManager.shared.double("search.maxCacheAge", defaultValue: 300.0)
                let maxCacheItems = try ConfigurationManager.shared.int("search.maxCacheItems", defaultValue: 100)
                let enableIndexing = try ConfigurationManager.shared.bool("search.enableIndexing", defaultValue: true)
                let indexUpdateInterval = try ConfigurationManager.shared.double("search.indexUpdateInterval", defaultValue: 3600.0)
                let enableFuzzyMatching = try ConfigurationManager.shared.bool("search.enableFuzzyMatching", defaultValue: true)
                let fuzzyMatchThreshold = try ConfigurationManager.shared.double("search.fuzzyMatchThreshold", defaultValue: 0.7)
                
                // Create the configuration
                self.configuration = SearchConfiguration(
                    minimumSearchLength: minimumSearchLength,
                    maxResultsPerEntityType: maxResultsPerEntityType,
                    searchTimeout: searchTimeout,
                    enableResultCaching: enableResultCaching,
                    maxCacheAge: maxCacheAge,
                    maxCacheItems: maxCacheItems,
                    enableIndexing: enableIndexing,
                    indexUpdateInterval: indexUpdateInterval,
                    enableFuzzyMatching: enableFuzzyMatching,
                    fuzzyMatchThreshold: fuzzyMatchThreshold
                )
            } catch {
                // If there's an error loading from config, use default values
                ErrorReporter.shared.warning("Failed to load search configuration: \(error.localizedDescription). Using default configuration.")
                self.configuration = SearchConfiguration()
            }
        }
        
        // Set up index update timer if enabled
        if self.configuration.enableIndexing {
            setupIndexUpdateTimer()
        }
        
        // Log configuration
        ErrorReporter.shared.debug("SearchManager initialized with configuration: minimumSearchLength=\(self.configuration.minimumSearchLength), maxResultsPerEntityType=\(self.configuration.maxResultsPerEntityType), enableIndexing=\(self.configuration.enableIndexing)")
    }
    
    // MARK: - Search Operations
    
    /// Performs a search with the specified query
    /// - Parameters:
    ///   - searchText: The text to search for
    ///   - filters: Optional filters to apply to the results
    ///   - completion: Callback with the search results or error
    public func search(
        searchText: String,
        filters: [SearchFilter]? = nil,
        completion: @escaping (Result<SearchResults, XTError>) -> Void
    ) {
        // Create a search query
        let query = SearchQuery(
            searchText: searchText,
            filters: filters,
            maxResults: configuration.maxResultsPerEntityType
        )
        
        // Perform the search
        search(query: query, completion: completion)
    }
    
    /// Performs a search with the specified query
    /// - Parameters:
    ///   - query: The search query
    ///   - completion: Callback with the search results or error
    public func search(
        query: SearchQuery,
        completion: @escaping (Result<SearchResults, XTError>) -> Void
    ) {
        searchQueue.async { [weak self] in
            guard let self = self else {
                completion(.failure(.search(.searchFailed(reason: "Search manager was deallocated"))))
                return
            }
            
            // Check if search text meets minimum length requirement
            if query.searchText.count < self.configuration.minimumSearchLength {
                completion(.failure(.search(.queryTooShort(minimumLength: self.configuration.minimumSearchLength))))
                return
            }
            
            // Check if we have cached results for this query
            if self.configuration.enableResultCaching {
                if let cachedResults = self.getCachedResults(for: query) {
                    ErrorReporter.shared.debug("Returning cached results for query: \(query.searchText)")
                    completion(.success(cachedResults))
                    return
                }
            }
            
            // If we have an index, search it first
            if !self.invertedIndex.isEmpty {
                do {
                    let results = try self.searchIndex(query: query)
                    
                    // Cache the results if caching is enabled
                    if self.configuration.enableResultCaching {
                        self.cacheResults(query: query, results: results)
                    }
                    
                    // Return the results
                    completion(.success(results))
                    self.searchResultsSubject.send(results)
                } catch {
                    // If index search fails, fall back to direct search
                    ErrorReporter.shared.warning("Index search failed: \(error.localizedDescription). Falling back to direct search.")
                    self.performDirectSearch(query: query, completion: completion)
                }
            } else {
                // No index, perform direct search
                self.performDirectSearch(query: query, completion: completion)
            }
        }
    }
    
    /// Cancels all active search operations
    public func cancelAllSearches() {
        searchQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Cancel all active search operations
            for (_, task) in self.activeSearchOperations {
                task.cancel()
            }
            
            self.activeSearchOperations.removeAll()
            ErrorReporter.shared.info("All search operations cancelled")
        }
    }
    
    /// Searches the index for the specified query
    /// - Parameter query: The search query
    /// - Returns: The search results
    /// - Throws: An error if the search fails
    private func searchIndex(query: SearchQuery) throws -> SearchResults {
        // Normalize and tokenize the search text
        let searchTerms = normalizeAndTokenize(query.searchText)
        
        // Make sure we have search terms
        if searchTerms.isEmpty {
            throw XTError.search(.invalidQuery(query: query.searchText, reason: "No valid search terms"))
        }
        
        // Find matching documents for each search term
        var matchesByTerm: [String: [(id: String, entityType: String, score: Double)]] = [:]
        
        for term in searchTerms {
            // Check exact matches first
            if let exactMatches = invertedIndex[term] {
                matchesByTerm[term] = exactMatches
            } else if configuration.enableFuzzyMatching {
                // If no exact matches and fuzzy matching is enabled, try fuzzy matching
                let fuzzyMatches = findFuzzyMatches(for: term, threshold: configuration.fuzzyMatchThreshold)
                if !fuzzyMatches.isEmpty {
                    matchesByTerm[term] = fuzzyMatches
                }
            }
        }
        
        // Calculate relevance scores for each document
        var scoresByDocument: [String: (score: Double, entityType: String)] = [:]
        
        // For each search term
        for (term, matches) in matchesByTerm {
            // For each document matching this term
            for match in matches {
                let documentKey = "\(match.entityType):\(match.id)"
                
                // Calculate a term frequency score
                let termScore = match.score
                
                // Add the score to the document's total score
                if let existingScore = scoresByDocument[documentKey] {
                    scoresByDocument[documentKey] = (existingScore.score + termScore, existingScore.entityType)
                } else {
                    scoresByDocument[documentKey] = (termScore, match.entityType)
                }
            }
        }
        
        // If no results, return empty results
        if scoresByDocument.isEmpty {
            return SearchResults(
                query: query.searchText,
                filters: query.filters,
                resultsByType: [:],
                totalCount: 0,
                isTruncated: false,
                timestamp: Date()
            )
        }
        
        // Convert the scores to search results
        var resultsByType: [String: [SearchResult]] = [:]
        var totalResults = 0
        var isTruncated = false
        
        // Group results by entity type
        let scoresByType = Dictionary(grouping: scoresByDocument) { $0.value.entityType }
        
        // For each entity type
        for (entityType, scores) in scoresByType {
            // Sort scores by descending score
            let sortedScores = scores.sorted { $0.value.score > $1.value.score }
            
            // Apply maximum results per entity type
            let maxResults = query.maxResults ?? configuration.maxResultsPerEntityType
            let limitedScores = sortedScores.prefix(maxResults)
            
            // Check if truncated
            if limitedScores.count < sortedScores.count {
                isTruncated = true
            }
            
            // Convert scores to search results
            var resultsForType: [SearchResult] = []
            
            for (docKey, scoreInfo) in limitedScores {
                // Get document ID from composite key
                let parts = docKey.split(separator: ":")
                let documentId = String(parts[1])
                
                // Get metadata for this document
                guard let metadata = documentMetadata[documentId] else { continue }
                
                // Create a search result
                let result = SearchResult(
                    id: documentId,
                    entityType: entityType,
                    title: metadata["title"] as? String ?? "Untitled",
                    subtitle: metadata["subtitle"] as? String,
                    imageURL: metadata["imageURL"] as? URL,
                    details: metadata["details"] as? [String: String],
                    relevanceScore: scoreInfo.score,
                    facets: metadata["facets"] as? [String: String],
                    rawData: metadata["rawData"] as Any
                )
                
                // Apply filters if needed
                if let filters = query.filters, !filters.isEmpty {
                    if shouldIncludeResult(result, filters: filters) {
                        resultsForType.append(result)
                    }
                } else {
                    resultsForType.append(result)
                }
            }
            
            // Add results for this type
            resultsByType[entityType] = resultsForType
            totalResults += resultsForType.count
        }
        
        // Create search results
        return SearchResults(
            query: query.searchText,
            filters: query.filters,
            resultsByType: resultsByType,
            totalCount: totalResults,
            isTruncated: isTruncated,
            timestamp: Date()
        )
    }
    
    /// Performs a direct search (without using the index)
    /// - Parameters:
    ///   - query: The search query
    ///   - completion: Callback with the search results or error
    private func performDirectSearch(
        query: SearchQuery,
        completion: @escaping (Result<SearchResults, XTError>) -> Void
    ) {
        // In a real implementation, this would query the database directly
        // For this example, we'll just create some placeholder results
        
        // Create operation ID
        let operationId = UUID()
        
        // Simulate an asynchronous operation
        let task = URLSession.shared.dataTask(with: URL(string: "https://example.com")!) { [weak self] _, _, _ in
            guard let self = self else {
                completion(.failure(.search(.searchFailed(reason: "Search manager was deallocated"))))
                return
            }
            
            // Remove the operation
            self.activeSearchOperations.removeValue(forKey: operationId)
            
            // Create placeholder results
            // Create placeholder results
            let resultsByType: [String: [SearchResult]] = [
                "Note": [
                    SearchResult(
                        id: "note-1",
                        entityType: "Note",
                        title: "Note containing \(query.searchText)",
                        subtitle: "This is a sample note with the search term",
                        relevanceScore: 0.95,
                        facets: ["category": "personal"],
                        rawData: ["content": "Sample note content with \(query.searchText)"]
                    ),
                    SearchResult(
                        id: "note-2",
                        entityType: "Note",
                        title: "Another note related to \(query.searchText)",
                        subtitle: "Secondary match for demonstration",
                        relevanceScore: 0.85,
                        facets: ["category": "work"],
                        rawData: ["content": "Another sample note about \(query.searchText)"]
                    )
                ],
                "Task": [
                    SearchResult(
                        id: "task-1",
                        entityType: "Task",
                        title: "Task related to \(query.searchText)",
                        subtitle: "A sample task for demonstration",
                        relevanceScore: 0.9,
                        facets: ["status": "open"],
                        rawData: ["description": "Sample task about \(query.searchText)"]
                    )
                ]
            ]
            
            // Create search results
            let results = SearchResults(
                query: query.searchText,
                filters: query.filters,
                resultsByType: resultsByType,
                totalCount: resultsByType.values.map { $0.count }.reduce(0, +),
                isTruncated: false,
                timestamp: Date()
            )
            
            // Cache the results if caching is enabled
            if self.configuration.enableResultCaching {
                self.cacheResults(query: query, results: results)
            }
            
            // Return the results
            completion(.success(results))
            self.searchResultsSubject.send(results)
        }
        
        // Store the task in active operations
        activeSearchOperations[operationId] = task
        
        // Start the task
        task.resume()
    }
    
    /// Checks if a result should be included based on the specified filters
    /// - Parameters:
    ///   - result: The search result
    ///   - filters: The filters to apply
    /// - Returns: Whether the result should be included
    private func shouldIncludeResult(_ result: SearchResult, filters: [SearchFilter]) -> Bool {
        // Apply each filter to the result
        for filter in filters {
            switch filter.type {
            case .entityType:
                // Filter by entity type
                let matches = result.entityType == filter.value
                if matches == filter.isExclusion {
                    return false
                }
                
            case .facet(let name):
                // Filter by facet value
                if let facets = result.facets, let facetValue = facets[name] {
                    let matches = facetValue == filter.value
                    if matches == filter.isExclusion {
                        return false
                    }
                } else if !filter.isExclusion {
                    // No facet value, exclude if not an exclusion filter
                    return false
                }
                
            case .dateRange, .numericRange, .custom:
                // These filter types require additional logic specific to the application
                // For this example, we'll just include all results for these filter types
                continue
            }
        }
        
        // If we reach here, the result passes all filters
        return true
    }
    
    // MARK: - Index Management
    
    /// Normalizes and tokenizes text for searching
    /// - Parameter text: The text to normalize and tokenize
    /// - Returns: Array of normalized tokens
    private func normalizeAndTokenize(_ text: String) -> [String] {
        // Convert to lowercase
        let lowercased = text.lowercased()
        
        // Remove punctuation and special characters
        let alphanumeric = lowercased.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: " ")
        
        // Split into words
        let words = alphanumeric.split(separator: " ").map { String($0) }
        
        // Filter out empty strings and common words
        let commonWords = ["the", "a", "an", "and", "or", "but", "of", "in", "on", "at", "to", "for", "with", "by"]
        return words.filter { !$0.isEmpty && !commonWords.contains($0) }
    }
    
    /// Sets up the index update timer
    private func setupIndexUpdateTimer() {
        // Cancel any existing timer
        indexUpdateTimer?.invalidate()
        
        // Set up a new timer on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.indexUpdateTimer = Timer.scheduledTimer(
                withTimeInterval: self.configuration.indexUpdateInterval,
                repeats: true
            ) { [weak self] _ in
                self?.updateIndexInBackground()
            }
            
            // Ensure timer fires even when scrolling
            RunLoop.current.add(self.indexUpdateTimer!, forMode: .common)
            
            ErrorReporter.shared.debug("Index update timer started with interval: \(Int(self.configuration.indexUpdateInterval)) seconds")
        }
    }
    
    /// Updates the search index in the background
    private func updateIndexInBackground() {
        indexingQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let result = try self.rebuildIndex()
                if let error = result.error {
                    ErrorReporter.shared.warning("Index update completed with error: \(error.localizedDescription)")
                } else {
                    ErrorReporter.shared.debug("Index update completed: \(result.itemsIndexed) items indexed in \(String(format: "%.2f", result.timeTaken)) seconds")
                }
            } catch {
                ErrorReporter.shared.error(
                    XTError.search(.indexingFailed(reason: error.localizedDescription)),
                    context: ["operation": "updateIndexInBackground"]
                )
            }
        }
    }
    
    /// Rebuilds the search index
    /// - Returns: Result of the indexing operation
    /// - Throws: An error if indexing fails
    private func rebuildIndex() throws -> IndexingResult {
        let startTime = Date().timeIntervalSince1970
        var itemsIndexed = 0
        var error: Error?
        
        do {
            // In a real implementation, this would fetch all searchable entities from the database
            // For this example, we'll create some placeholder items
            
            // Build a new index
            var newIndex: InvertedIndex = [:]
            var newMetadata: [String: [String: Any]] = [:]
            
            // Placeholder entities for demonstration
            let entities: [SearchableMock] = [
                SearchableMock(id: "note-1", type: "Note", title: "Meeting notes", content: "Discussion about product roadmap", tags: ["work", "meeting"]),
                SearchableMock(id: "note-2", type: "Note", title: "Shopping list", content: "Milk, bread, eggs", tags: ["personal", "shopping"]),
                SearchableMock(id: "task-1", type: "Task", title: "Finish report", content: "Complete quarterly financial report", tags: ["work", "finance"]),
                SearchableMock(id: "task-2", type: "Task", title: "Buy groceries", content: "Visit the supermarket", tags: ["personal", "errands"])
            ]
            
            // Index each entity
            for entity in entities {
                indexEntity(entity, index: &newIndex, metadata: &newMetadata)
                itemsIndexed += 1
            }
            
            // Replace the current index and metadata with the new ones
            invertedIndex = newIndex
            documentMetadata = newMetadata
            lastIndexUpdateTime = Date()
            
            ErrorReporter.shared.debug("Index rebuilt with \(itemsIndexed) items")
        } catch let indexError {
            error = indexError
            ErrorReporter.shared.error(
                XTError.search(.indexingFailed(reason: indexError.localizedDescription)),
                context: ["operation": "rebuildIndex"]
            )
        }
        
        let endTime = Date().timeIntervalSince1970
        let timeTaken = endTime - startTime
        
        return IndexingResult(itemsIndexed: itemsIndexed, timeTaken: timeTaken, error: error)
    }
    
    /// Adds a searchable entity to the index
    /// - Parameters:
    ///   - entity: The entity to index
    ///   - index: The index to update
    ///   - metadata: The metadata store to update
    private func indexEntity<T: Searchable>(_ entity: T, index: inout InvertedIndex, metadata: inout [String: [String: Any]]) {
        // Normalize and tokenize the primary text
        let primaryTokens = normalizeAndTokenize(entity.searchableText)
        
        // Normalize and tokenize the secondary text if available
        var secondaryTokens: [String] = []
        if let secondaryText = entity.searchableSecondaryText {
            secondaryTokens = normalizeAndTokenize(secondaryText)
        }
        
        // Normalize and tokenize additional fields if available
        var additionalTokens: [String] = []
        if let fields = entity.searchableFields {
            for (_, value) in fields {
                additionalTokens.append(contentsOf: normalizeAndTokenize(value))
            }
        }
        
        // Calculate term frequencies
        var termFrequencies: [String: Int] = [:]
        
        // Primary text terms get highest weight
        for token in primaryTokens {
            termFrequencies[token, default: 0] += 3
        }
        
        // Secondary text terms get medium weight
        for token in secondaryTokens {
            termFrequencies[token, default: 0] += 2
        }
        
        // Additional field terms get lowest weight
        for token in additionalTokens {
            termFrequencies[token, default: 0] += 1
        }
        
        // Add terms to the index
        for (term, frequency) in termFrequencies {
            // Calculate a score based on term frequency
            let score = min(1.0, Double(frequency) / 10.0)
            
            // Add the term to the index
            if index[term] == nil {
                index[term] = []
            }
            
            index[term]?.append((id: entity.searchableId, entityType: type(of: entity).searchableTypeName, score: score))
        }
        
        // Store metadata for the entity
        metadata[entity.searchableId] = [
            "title": entity.searchableText,
            "subtitle": entity.searchableSecondaryText as Any,
            "facets": entity.searchableFacets as Any,
            "rawData": entity
        ]
    }
    
    /// Updates the index with a single entity
    /// - Parameter entity: The entity to index
    /// - Returns: True if the entity was indexed successfully
    @discardableResult
    public func updateIndex<T: Searchable>(with entity: T) -> Bool {
        guard configuration.enableIndexing else {
            return false
        }
        
        indexingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Create copies of the current index and metadata
            var currentIndex = self.invertedIndex
            var currentMetadata = self.documentMetadata
            
            // Index the entity
            self.indexEntity(entity, index: &currentIndex, metadata: &currentMetadata)
            
            // Update the shared index and metadata
            self.invertedIndex = currentIndex
            self.documentMetadata = currentMetadata
            
            ErrorReporter.shared.debug("Entity added to index: \(entity.searchableId)")
        }
        
        return true
    }
    
    /// Removes an entity from the index
    /// - Parameters:
    ///   - entityId: The ID of the entity to remove
    ///   - entityType: The type of the entity to remove
    /// - Returns: True if the entity was removed successfully
    @discardableResult
    public func removeFromIndex(entityId: String, entityType: String) -> Bool {
        guard configuration.enableIndexing else {
            return false
        }
        
        indexingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Create a copy of the current index and metadata
            var currentIndex = self.invertedIndex
            var currentMetadata = self.documentMetadata
            
            // Remove the entity from the metadata store
            currentMetadata.removeValue(forKey: entityId)
            
            // Remove references to the entity from the index
            for (term, matches) in currentIndex {
                currentIndex[term] = matches.filter { $0.id != entityId || $0.entityType != entityType }
                
                // If no matches left for this term, remove the term from the index
                if currentIndex[term]?.isEmpty == true {
                    currentIndex.removeValue(forKey: term)
                }
            }
            
            // Update the shared index and metadata
            self.invertedIndex = currentIndex
            self.documentMetadata = currentMetadata
            
            ErrorReporter.shared.debug("Entity removed from index: \(entityId)")
        }
        
        return true
    }
    
    /// Clears the entire search index
    /// - Returns: True if the index was cleared successfully
    @discardableResult
    public func clearIndex() -> Bool {
        indexingQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.invertedIndex.removeAll()
            self.documentMetadata.removeAll()
            self.lastIndexUpdateTime = nil
            
            ErrorReporter.shared.info("Search index cleared")
        }
        
        return true
    }
    
    // MARK: - Fuzzy Matching
    
    /// Finds fuzzy matches for a term in the index
    /// - Parameters:
    ///   - term: The term to match
    ///   - threshold: The minimum similarity threshold (0.0-1.0)
    /// - Returns: Array of matches with adjusted scores
    private func findFuzzyMatches(for term: String, threshold: Double) -> [(id: String, entityType: String, score: Double)] {
        var matches: [(id: String, entityType: String, score: Double)] = []
        
        // Check each term in the index for a fuzzy match
        for (indexTerm, termMatches) in invertedIndex {
            let similarity = calculateSimilarity(between: term, and: indexTerm)
            
            if similarity >= threshold {
                // Adjust scores based on similarity
                let adjustedMatches = termMatches.map {
                    (id: $0.id, entityType: $0.entityType, score: $0.score * similarity)
                }
                
                matches.append(contentsOf: adjustedMatches)
            }
        }
        
        return matches
    }
    
    /// Calculates the similarity between two strings (simple Levenshtein-based approach)
    /// - Parameters:
    ///   - str1: First string
    ///   - str2: Second string
    /// - Returns: Similarity score (0.0-1.0)
    private func calculateSimilarity(between str1: String, and str2: String) -> Double {
        let distance = levenshteinDistance(between: str1, and: str2)
        let maxLength = Double(max(str1.count, str2.count))
        
        // Convert distance to similarity (1.0 = identical, 0.0 = completely different)
        guard maxLength > 0 else { return 1.0 }
        return 1.0 - (Double(distance) / maxLength)
    }
    
    /// Calculates the Levenshtein distance between two strings
    /// - Parameters:
    ///   - str1: First string
    ///   - str2: Second string
    /// - Returns: Levenshtein distance
    private func levenshteinDistance(between str1: String, and str2: String) -> Int {
        let str1Array = Array(str1)
        let str2Array = Array(str2)
        
        let m = str1.count
        let n = str2.count
        
        // Create a matrix of size (m+1) x (n+1)
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
        
        // Initialize the first row and column
        for i in 0...m {
            matrix[i][0] = i
        }
        
        for j in 0...n {
            matrix[0][j] = j
        }
        
        // Fill the matrix
        for i in 1...m {
            for j in 1...n {
                let cost = str1Array[i-1] == str2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[m][n]
    }
    
    // MARK: - Cache Management
    
    /// Gets cached search results for a query
    /// - Parameter query: The search query
    /// - Returns: Cached results if available and not expired, nil otherwise
    private func getCachedResults(for query: SearchQuery) -> SearchResults? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        // Create a string key for the query
        let queryKey = "\(query.hashValue)"
        
        guard let cacheItem = searchResultsCache[queryKey] else {
            return nil
        }
        
        // Check if cache has expired
        let cacheAge = Date().timeIntervalSince(cacheItem.timestamp)
        if cacheAge > configuration.maxCacheAge {
            // Cache has expired, remove it
            searchResultsCache.removeValue(forKey: queryKey)
            return nil
        }
        
        return cacheItem.results
    }
    
    /// Caches search results for a query
    /// - Parameters:
    ///   - query: The search query
    ///   - results: The search results
    private func cacheResults(query: SearchQuery, results: SearchResults) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        // Create a string key for the query
        let queryKey = "\(query.hashValue)"
        
        // Create a cache item
        let cacheItem = CacheItem(query: query, results: results)
        
        // Add the cache item
        searchResultsCache[queryKey] = cacheItem
        
        // Trim the cache if it exceeds the maximum size
        if searchResultsCache.count > configuration.maxCacheItems {
            trimCache()
        }
    }
    
    /// Trims the cache to the maximum size
    private func trimCache() {
        // Sort cache items by timestamp (oldest first)
        let sortedItems = searchResultsCache.sorted { $0.value.timestamp < $1.value.timestamp }
        
        // Calculate how many items to remove
        let itemsToRemove = max(0, searchResultsCache.count - configuration.maxCacheItems)
        
        // Remove the oldest items
        for i in 0..<itemsToRemove {
            if i < sortedItems.count {
                searchResultsCache.removeValue(forKey: sortedItems[i].key)
            }
        }
    }
    
    /// Clears the search results cache
    public func clearCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        searchResultsCache.removeAll()
        ErrorReporter.shared.info("Search cache cleared")
    }
    
    // MARK: - Cleanup and Resource Management
    
    /// Prepares the search manager for app termination
    public func prepareForTermination() {
        // Cancel all searches
        cancelAllSearches()
        
        // Stop index update timer
        stopIndexUpdateTimer()
        
        // Clear the cache if needed
        if !configuration.enableResultCaching {
            clearCache()
        }
        
        ErrorReporter.shared.debug("SearchManager prepared for termination")
    }
    
    /// Stops the index update timer
    private func stopIndexUpdateTimer() {
        indexUpdateTimer?.invalidate()
        indexUpdateTimer = nil
    }
    
    /// Deinitializer
    deinit {
        // Stop timer
        stopIndexUpdateTimer()
        
        // Cancel all searches
        for (_, task) in activeSearchOperations {
            task.cancel()
        }
        
        activeSearchOperations.removeAll()
        
        ErrorReporter.shared.debug("SearchManager is being deinitialized")
    }
}

// MARK: - Mock Implementation for Testing

/// A mock implementation of the Searchable protocol for testing
fileprivate struct SearchableMock: Searchable {
    static var searchableTypeName: String { return "Mock" }
    let searchableId: String
    let searchableText: String
    let searchableSecondaryText: String?
    let searchableFields: [String: String]?
    let searchableFacets: [String: String]?
    
    init(id: String, type: String, title: String, content: String, tags: [String]) {
        self.searchableId = id
        self.searchableText = title
        self.searchableSecondaryText = content
        self.searchableFields = ["type": type]
        
        // Convert tags to facets
        var facets: [String: String] = [:]
        for (index, tag) in tags.enumerated() {
            facets["tag\(index+1)"] = tag
        }
        self.searchableFacets = facets
    }
}

// MARK: - Error Extensions

extension XTError {
    /// Search-specific errors
    public enum SearchError: Error, LocalizedError {
        /// Search query is too short
        case queryTooShort(minimumLength: Int)
        /// Invalid search query
        case invalidQuery(query: String, reason: String)
        /// Search operation failed
        case searchFailed(reason: String)
        /// Search operation timed out
        case searchTimeout
        /// Indexing operation failed
        case indexingFailed(reason: String)
        
        /// A localized description of the error
        public var errorDescription: String? {
            switch self {
            case .queryTooShort(let minimumLength):
                return "Search query must be at least \(minimumLength) characters"
            case .invalidQuery(let query, let reason):
                return "Invalid search query '\(query)': \(reason)"
            case .searchFailed(let reason):
                return "Search operation failed: \(reason)"
            case .searchTimeout:
                return "Search operation timed out"
            case .indexingFailed(let reason):
                return "Indexing operation failed: \(reason)"
            }
        }
    }
    
    /// Creates a search error
    /// - Parameter error: The search error
    /// - Returns: An XTError with the search error
    public static func search(_ error: SearchError) -> XTError {
        return XTError(domain: .search, code: 8000, underlyingError: error)
    }
}
