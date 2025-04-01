import Foundation
import Combine

/// Errors that can occur during resource operations
public enum ResourceError: Error {
    /// Failed to download the resource from the server
    case downloadFailed(Error)
    /// Failed to save the resource to the local cache
    case cacheSaveFailed(Error)
    /// The resource could not be found in the cache or remotely
    case resourceNotFound(String)
    /// The maximum retry count was exceeded while attempting the operation
    case retryLimitExceeded
    /// An unexpected error occurred during resource processing
    case generalError(String)
}

/// Represents a binary resource (attachment) with its metadata
public struct Resource: Identifiable, Codable, Equatable {
    /// Unique identifier for the resource
    public let id: String
    /// MIME type of the resource
    public let mimeType: String
    /// Original filename of the resource
    public let filename: String?
    /// Size of the resource in bytes
    public let size: Int
    /// Hash value for the resource content (for integrity verification)
    public let hash: Data
    /// Optional metadata describing the resource
    public let attributes: ResourceAttributes?
    
    /// Additional attributes for a resource
    public struct ResourceAttributes: Codable, Equatable {
        /// When the resource was created
        public let creationDate: Date?
        /// When the resource was last modified
        public let modificationDate: Date?
        /// Indicates if this is a camera capture
        public let isFromCamera: Bool?
        /// Source URL if the resource was downloaded from the web
        public let sourceURL: URL?
        /// Geographic location where the resource was created
        public let location: ResourceLocation?
    }
    
    /// Geographic location information
    public struct ResourceLocation: Codable, Equatable {
        /// Latitude coordinate
        public let latitude: Double
        /// Longitude coordinate
        public let longitude: Double
        /// Altitude in meters
        public let altitude: Double?
    }
}

/// Status of a resource download
public enum ResourceStatus {
    /// The resource is available in the cache
    case cached(URL)
    /// The resource is currently downloading
    case downloading(Progress)
    /// The resource needs to be downloaded
    case notDownloaded
    /// The resource failed to download
    case failed(ResourceError)
}

/// Protocol defining operations for managing note resources (attachments)
public protocol ResourceManaging {
    /// Get the status of a specific resource
    /// - Parameter resourceId: Unique identifier of the resource
    /// - Returns: Current status of the resource
    func status(of resourceId: String) -> ResourceStatus
    
    /// Get the local URL for a cached resource if available
    /// - Parameter resourceId: Unique identifier of the resource
    /// - Returns: Local file URL if the resource is cached, nil otherwise
    func cachedURL(for resourceId: String) -> URL?
    
    /// Download a resource and cache it locally
    /// - Parameters:
    ///   - resource: The resource to download
    ///   - cachePolicy: Policy for caching the resource
    /// - Returns: A publisher that emits download progress and completes with the local URL when finished
    func downloadResource(_ resource: Resource, cachePolicy: ResourceCachePolicy) -> AnyPublisher<Progress, ResourceError>
    
    /// Prefetch multiple resources to have them available in the cache
    /// - Parameters:
    ///   - resources: Array of resources to prefetch
    ///   - cachePolicy: Policy for caching the resources
    /// - Returns: A publisher that emits the overall progress and completes when all downloads are finished
    func prefetchResources(_ resources: [Resource], cachePolicy: ResourceCachePolicy) -> AnyPublisher<Progress, ResourceError>
    
    /// Clear cached resources based on the specified policy
    /// - Parameter policy: Policy determining which resources to clear
    /// - Returns: A publisher that completes when the operation finishes or emits an error
    func clearCache(policy: ResourceClearPolicy) -> AnyPublisher<Void, ResourceError>
}

/// Policy for resource caching
public enum ResourceCachePolicy {
    /// Cache the resource indefinitely
    case permanent
    /// Cache the resource for a specified duration
    case temporary(TimeInterval)
    /// Don't cache the resource, only keep it in memory
    case memoryOnly
}

/// Policy for clearing cached resources
public enum ResourceClearPolicy {
    /// Clear all cached resources
    case all
    /// Clear resources that haven't been accessed in the specified time
    case olderThan(TimeInterval)
    /// Clear resources for a specific note
    case forNote(String)
    /// Clear specific resources by ID
    case specificResources([String])
}

/// Default implementation of ResourceManaging protocol
public class ResourceManager: ResourceManaging {
    /// File manager used for file operations
    private let fileManager: FileManager
    /// URL session for network operations
    private let urlSession: URLSession
    /// Directory where resources are cached
    private let cacheDirectory: URL
    /// Queue for synchronizing access to shared resources
    private let queue: DispatchQueue
    /// Active download tasks
    private var activeTasks: [String: URLSessionDownloadTask] = [:]
    /// Download progress by resource ID
    private var progressByResource: [String: Progress] = [:]
    
    /// Initialize a new ResourceManager with custom configuration
    /// - Parameters:
    ///   - fileManager: File manager to use for file operations
    ///   - urlSession: URL session for network operations
    ///   - cacheDirectory: Custom directory for caching resources (defaults to app's cache directory)
    public init(
        fileManager: FileManager = .default,
        urlSession: URLSession = .shared,
        cacheDirectory: URL? = nil
    ) {
        self.fileManager = fileManager
        self.urlSession = urlSession
        self.queue = DispatchQueue(label: "com.fraqtiv.extraqtiv.resourceManager", qos: .utility)
        
        // Set up cache directory
        if let customCacheDir = cacheDirectory {
            self.cacheDirectory = customCacheDir
        } else {
            let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            self.cacheDirectory = cacheDir.appendingPathComponent("com.fraqtiv.extraqtiv/resources", isDirectory: true)
        }
        
        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
    }
    
    public func status(of resourceId: String) -> ResourceStatus {
        if let cachedURL = cachedURL(for: resourceId) {
            return .cached(cachedURL)
        }
        
        if let progress = queue.sync(execute: { progressByResource[resourceId] }) {
            return .downloading(progress)
        }
        
        return .notDownloaded
    }
    
    public func cachedURL(for resourceId: String) -> URL? {
        let resourceURL = cacheDirectory.appendingPathComponent(resourceId)
        return fileManager.fileExists(atPath: resourceURL.path) ? resourceURL : nil
    }
    
    public func downloadResource(_ resource: Resource, cachePolicy: ResourceCachePolicy) -> AnyPublisher<Progress, ResourceError> {
        let resourceId = resource.id
        
        // Check if already cached
        if let cachedURL = cachedURL(for: resourceId) {
            let progress = Progress(totalUnitCount: 1)
            progress.completedUnitCount = 1
            return Just(progress)
                .setFailureType(to: ResourceError.self)
                .eraseToAnyPublisher()
        }
        
        // Check if already downloading
        if let existingProgress = queue.sync(execute: { self.progressByResource[resourceId] }) {
            return Just(existingProgress)
                .setFailureType(to: ResourceError.self)
                .eraseToAnyPublisher()
        }
        
        // Create subject to publish progress
        let progressSubject = PassthroughSubject<Progress, ResourceError>()
        
        // Create a progress object
        let progress = Progress(totalUnitCount: 100)
        
        // Store progress in our dictionary
        queue.sync {
            self.progressByResource[resourceId] = progress
        }
        
        // TODO: This would use the actual Evernote API to fetch the resource
        // For now, we'll simulate downloading
        simulateDownload(resourceId: resourceId, progress: progress, progressSubject: progressSubject, cachePolicy: cachePolicy)
        
        return progressSubject.eraseToAnyPublisher()
    }
    
    /// Simulates a download - would be replaced with actual Evernote API calls
    private func simulateDownload(
        resourceId: String,
        progress: Progress,
        progressSubject: PassthroughSubject<Progress, ResourceError>,
        cachePolicy: ResourceCachePolicy
    ) {
        // In a real implementation, this would use URLSession to download the resource
        let task = DispatchWorkItem {
            // Simulate download progress
            for percent in 1...100 {
                Thread.sleep(forTimeInterval: 0.01)
                progress.completedUnitCount = Int64(percent)
                DispatchQueue.main.async {
                    progressSubject.send(progress)
                }
            }
            
            // Simulate saving to cache (if not memoryOnly)
            if case .memoryOnly = cachePolicy {
                // Don't save to disk
            } else {
                // Create a dummy file in the cache
                let targetURL = self.cacheDirectory.appendingPathComponent(resourceId)
                do {
                    // Create a dummy content - in reality this would be the downloaded data
                    let dummyContent = "This is a simulated resource file for \(resourceId)".data(using: .utf8)!
                    try dummyContent.write(to: targetURL)
                    
                    // If it's a temporary cache, schedule deletion
                    if case .temporary(let interval) = cachePolicy {
                        DispatchQueue.global().asyncAfter(deadline: .now() + interval) {
                            try? self.fileManager.removeItem(at: targetURL)
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        progressSubject.send(completion: .failure(.cacheSaveFailed(error)))
                    }
                    return
                }
            }
            
            // Complete the subject
            DispatchQueue.main.async {
                progressSubject.send(completion: .finished)
            }
            
            // Clean up
            self.queue.sync {
                self.progressByResource.removeValue(forKey: resourceId)
                self.activeTasks.removeValue(forKey: resourceId)
            }
        }
        
        // Store task reference (for cancellation)
        queue.sync {
            // In real implementation, this would be a URLSessionDownloadTask
            self.activeTasks[resourceId] = URLSessionDownloadTask()
        }
        
        // Start the "download"
        DispatchQueue.global(qos: .utility).async(execute: task)
    }
    
    public func prefetchResources(_ resources: [Resource], cachePolicy: ResourceCachePolicy) -> AnyPublisher<Progress, ResourceError> {
        // Create an aggregate progress
        let overallProgress = Progress(totalUnitCount: Int64(resources.count * 100))
        
        // Create a subject to publish the overall progress
        let progressSubject = PassthroughSubject<Progress, ResourceError>()
        
        // Skip if no resources
        if resources.isEmpty {
            overallProgress.completedUnitCount = 0
            progressSubject.send(overallProgress)
            progressSubject.send(completion: .finished)
            return progressSubject.eraseToAnyPublisher()
        }
        
        // Track completed downloads
        var completedDownloads = 0
        var downloadErrors = [ResourceError]()
        
        // Download each resource
        resources.forEach { resource in
            downloadResource(resource, cachePolicy: cachePolicy)
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            // Track completion
                            self.queue.sync {
                                completedDownloads += 1
                                
                                // Check if all downloads are complete
                                if completedDownloads == resources.count {
                                    if downloadErrors.isEmpty {
                                        progressSubject.send(completion: .finished)
                                    } else {
                                        // If there were errors, fail with the first one
                                        progressSubject.send(completion: .failure(downloadErrors.first!))
                                    }
                                }
                            }
                        case .failure(let error):
                            // Track error
                            self.queue.sync {
                                downloadErrors.append(error)
                                completedDownloads += 1
                                
                                // Still check if all downloads are complete
                                if completedDownloads == resources.count {
                                    progressSubject.send(completion: .failure(downloadErrors.first!))
                                }
                            }
                        }
                    },
                    receiveValue: { individualProgress in
                        // Update the overall progress
                        let resourceContribution = 100
                        let completed = Int64(individualProgress.fractionCompleted * Double(resourceContribution))
                        
                        // Update overall progress and send update
                        DispatchQueue.main.async {
                            overallProgress.completedUnitCount = Int64(completedDownloads * 100) + completed
                            progressSubject.send(overallProgress)
                        }
                    }
                )
                .store(in: &self.cancellables)
        }
        
        return progressSubject.eraseToAnyPublisher()
    }
    
    public func clearCache(policy: ResourceClearPolicy) -> AnyPublisher<Void, ResourceError> {
        let subject = PassthroughSubject<Void, ResourceError>()
        
        DispatchQueue.global(qos: .utility).async {
            do {
                switch policy {
                case .all:
                    // Remove all cached files
                    let resourceFiles = try self.fileManager.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: nil)
                    for fileURL in resourceFiles {
                        try self.fileManager.removeItem(at: fileURL)
                    }
                    
                case .olderThan(let interval):
                    // Remove files that haven't been accessed recently
                    let resourceFiles = try self.fileManager.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: [.contentAccessDateKey])
                    
                    let cutoffDate = Date().addingTimeInterval(-interval)
                    
                    for fileURL in resourceFiles {
                        if let attributes = try? self.fileManager.attributesOfItem(atPath: fileURL.path),
                           let accessDate = attributes[.contentAccessDate] as? Date,
                           accessDate < cutoffDate {
                            try self.fileManager.removeItem(at: fileURL)
                        }
                    }
                    
                case .forNote(let noteId):
                    // In a real implementation, we would track which resources belong to which notes
                    // For now, just log that we can't perform this operation
                    subject.send(completion: .failure(.generalError("Clearing by note ID not implemented")))
                    return
                    
                case .specificResources(let resourceIds):
                    // Remove specific resources
                    for resourceId in resourceIds {
                        let resourceURL = self.cacheDirectory.appendingPathComponent(resourceId)
                        if self.fileManager.fileExists(atPath: resourceURL.path) {
                            try self.fileManager.removeItem(at: resourceURL)
                        }
                    }
                }
                
                subject.send(())
                subject.

