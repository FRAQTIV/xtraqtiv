import Foundation

/// A representation of a note exported from Evernote.
///
/// `Note` encapsulates all the data associated with an Evernote note, including
/// its content, metadata, and any attached resources. It conforms to `Codable` to
/// enable easy serialization and deserialization.
///
/// Example usage:
/// ```swift
/// let note = Note(
///     id: "123456",
///     title: "Meeting Notes",
///     content: "<div>Important points from today's meeting...</div>",
///     createdAt: Date(),
///     updatedAt: Date(),
///     metadata: Metadata(
///         author: "John Doe",
///         sourceURL: URL(string: "https://example.com"),
///         tags: ["meeting", "work", "project"]
///     ),
///     resources: [
///         Resource(
///             id: "res123",
///             filename: "presentation.pdf",
///             mimeType: "application/pdf",
///             data: presentationData,
///             size: 1024000
///         )
///     ]
/// )
/// ```
public struct Note: Codable, Identifiable, Equatable {
    /// Unique identifier for the note.
    public let id: String
    
    /// The title of the note.
    public let title: String
    
    /// The main content of the note, typically in ENML or HTML format.
    public let content: String
    
    /// The timestamp when the note was originally created.
    public let createdAt: Date
    
    /// The timestamp when the note was last updated.
    public let updatedAt: Date
    
    /// Additional metadata associated with the note.
    public let metadata: Metadata
    
    /// Collection of resources (attachments) associated with the note.
    public let resources: [Resource]
    
    /// Creates a new Note instance.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for the note
    ///   - title: The title of the note
    ///   - content: The main content of the note
    ///   - createdAt: Timestamp when the note was created
    ///   - updatedAt: Timestamp when the note was last updated
    ///   - metadata: Additional metadata for the note
    ///   - resources: Collection of resources attached to the note
    public init(
        id: String,
        title: String,
        content: String,
        createdAt: Date,
        updatedAt: Date,
        metadata: Metadata,
        resources: [Resource] = []
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
        self.resources = resources
    }
}

/// Additional metadata associated with a note.
///
/// `Metadata` encapsulates supplementary information about a note that isn't
/// part of its primary content but provides context and categorization.
public struct Metadata: Codable, Equatable {
    /// The author or creator of the note.
    public let author: String?
    
    /// The source URL, if the note was created from a web page or external source.
    public let sourceURL: URL?
    
    /// Tags associated with the note for categorization.
    public let tags: [String]
    
    /// The notebook that contains this note.
    public let notebook: String?
    
    /// Additional custom attributes as key-value pairs.
    public let attributes: [String: String]
    
    /// Creates a new Metadata instance.
    ///
    /// - Parameters:
    ///   - author: The author or creator of the note
    ///   - sourceURL: The source URL if note was created from web content
    ///   - tags: Tags for categorization
    ///   - notebook: The name of the containing notebook
    ///   - attributes: Additional custom attributes
    public init(
        author: String? = nil,
        sourceURL: URL? = nil,
        tags: [String] = [],
        notebook: String? = nil,
        attributes: [String: String] = [:]
    ) {
        self.author = author
        self.sourceURL = sourceURL
        self.tags = tags
        self.notebook = notebook
        self.attributes = attributes
    }
}

/// A resource (attachment) associated with a note.
///
/// `Resource` represents files, images, or other binary data that is attached to a note.
/// It includes metadata about the resource as well as the binary data itself.
public struct Resource: Codable, Identifiable, Equatable {
    /// Unique identifier for the resource.
    public let id: String
    
    /// The original filename of the resource.
    public let filename: String?
    
    /// The MIME type of the resource.
    public let mimeType: String
    
    /// The binary data of the resource.
    public let data: Data
    
    /// The size of the resource in bytes.
    public let size: Int
    
    /// Hash of the resource data, useful for verification and deduplication.
    public let hash: Data?
    
    /// Alternative text description, especially useful for images.
    public let alternateText: String?
    
    /// Creates a new Resource instance.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for the resource
    ///   - filename: Original filename of the resource
    ///   - mimeType: MIME type of the resource
    ///   - data: Binary data of the resource
    ///   - size: Size of the resource in bytes
    ///   - hash: Hash of the resource data
    ///   - alternateText: Alternative text description
    public init(
        id: String,
        filename: String? = nil,
        mimeType: String,
        data: Data,
        size: Int,
        hash: Data? = nil,
        alternateText: String? = nil
    ) {
        self.id = id
        self.filename = filename
        self.mimeType = mimeType
        self.data = data
        self.size = size
        self.hash = hash
        self.alternateText = alternateText
    }
    
    /// Returns a Boolean value indicating whether two resources are equal.
    public static func == (lhs: Resource, rhs: Resource) -> Bool {
        lhs.id == rhs.id &&
        lhs.filename == rhs.filename &&
        lhs.mimeType == rhs.mimeType &&
        lhs.size == rhs.size &&
        lhs.hash == rhs.hash &&
        lhs.alternateText == rhs.alternateText &&
        lhs.data == rhs.data
    }
}

