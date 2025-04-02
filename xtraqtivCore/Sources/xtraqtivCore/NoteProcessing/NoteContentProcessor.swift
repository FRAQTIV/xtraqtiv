import Foundation

/// Errors that can occur during note content processing
public enum NoteContentProcessingError: Error {
    /// Failed to parse the input ENML content
    case invalidENMLContent(String)
    
    /// Failed to process resources referenced in note content
    case resourceProcessingFailed(String)
    
    /// Generic conversion error
    case conversionFailed(String)
    
    /// Missing required content components
    case missingContent(String)
}

/// Options for content conversion
public struct ContentProcessingOptions {
    /// Whether to include resources inline (for HTML) or as references
    public let inlineResources: Bool
    
    /// Whether to preserve original formatting
    public let preserveFormatting: Bool
    
    /// Whether to extract plain text only (no formatting)
    public let plainTextOnly: Bool
    
    /// Custom base URL for resources if not inlined
    public let resourceBaseURL: URL?
    
    /// Creates a new set of content processing options
    /// - Parameters:
    ///   - inlineResources: Whether to include resources inline (for HTML) or as references
    ///   - preserveFormatting: Whether to preserve original formatting
    ///   - plainTextOnly: Whether to extract plain text only (no formatting)
    ///   - resourceBaseURL: Custom base URL for resources if not inlined
    public init(
        inlineResources: Bool = true,
        preserveFormatting: Bool = true,
        plainTextOnly: Bool = false,
        resourceBaseURL: URL? = nil
    ) {
        self.inlineResources = inlineResources
        self.preserveFormatting = preserveFormatting
        self.plainTextOnly = plainTextOnly
        self.resourceBaseURL = resourceBaseURL
    }
    
    /// Default processing options
    public static let `default` = ContentProcessingOptions()
    
    /// Plain text extraction options
    public static let plainText = ContentProcessingOptions(
        inlineResources: false,
        preserveFormatting: false,
        plainTextOnly: true,
        resourceBaseURL: nil
    )
}

/// Result of content processing operation, containing processed content and resource information
public struct ProcessedContent {
    /// The processed content (HTML or plain text)
    public let content: String
    
    /// MIME type of the content
    public let mimeType: String
    
    /// Resources referenced in the content
    public let resources: [ResourceReference]
    
    /// Any warning messages generated during processing
    public let warnings: [String]
}

/// Reference to a resource within note content
public struct ResourceReference {
    /// Resource identifier
    public let id: String
    
    /// Resource filename
    public let filename: String
    
    /// MIME type of the resource
    public let mimeType: String
    
    /// URL to the resource (may be relative or absolute)
    public let url: URL
    
    /// Whether the resource is embedded in the content
    public let isEmbedded: Bool
}

/// Protocol defining methods for processing Evernote note content
public protocol NoteContentProcessing {
    /// Convert ENML content to HTML
    /// - Parameters:
    ///   - enml: The ENML content string to convert
    ///   - resources: Dictionary of resource data, keyed by resource hash
    ///   - options: Options for controlling the conversion process
    /// - Returns: Processed content with HTML, resource references, and any warnings
    /// - Throws: NoteContentProcessingError if conversion fails
    func convertENMLToHTML(
        enml: String,
        resources: [String: Data],
        options: ContentProcessingOptions
    ) throws -> ProcessedContent
    
    /// Convert ENML content to plain text
    /// - Parameters:
    ///   - enml: The ENML content string to convert
    ///   - options: Options for controlling the conversion process
    /// - Returns: Processed content with plain text and any warnings
    /// - Throws: NoteContentProcessingError if conversion fails
    func convertENMLToPlainText(
        enml: String,
        options: ContentProcessingOptions
    ) throws -> ProcessedContent
    
    /// Check if ENML content is valid
    /// - Parameter enml: The ENML content to validate
    /// - Returns: True if the content is valid ENML, false otherwise
    func isValidENML(_ enml: String) -> Bool
    
    /// Extract resource references from ENML content
    /// - Parameter enml: The ENML content to process
    /// - Returns: Array of resource references found in the content
    /// - Throws: NoteContentProcessingError if extraction fails
    func extractResourceReferences(from enml: String) throws -> [ResourceReference]
}

/// Default implementation of the NoteContentProcessing protocol
public class NoteContentProcessor: NoteContentProcessing {
    /// Initializes a new NoteContentProcessor
    public init() {}
    
    public func convertENMLToHTML(
        enml: String,
        resources: [String: Data],
        options: ContentProcessingOptions
    ) throws -> ProcessedContent {
        // Validate input ENML
        guard isValidENML(enml) else {
            throw NoteContentProcessingError.invalidENMLContent("Input is not valid ENML")
        }
        
        var warnings: [String] = []
        
        // Parse ENML and transform to HTML
        // This would involve using XML parsing and transformation
        // For now, this is a placeholder for the actual implementation
        
        // Extract resource references
        let resourceRefs = try extractResourceReferences(from: enml)
        
        // Process resources based on options
        let processedResourceRefs = try processResources(
            resourceRefs: resourceRefs,
            resources: resources,
            options: options,
            warnings: &warnings
        )
        
        // Transform ENML to HTML (placeholder implementation)
        let htmlContent = try transformENMLToHTML(
            enml: enml,
            resourceRefs: processedResourceRefs,
            options: options,
            warnings: &warnings
        )
        
        return ProcessedContent(
            content: htmlContent,
            mimeType: "text/html",
            resources: processedResourceRefs,
            warnings: warnings
        )
    }
    
    public func convertENMLToPlainText(
        enml: String,
        options: ContentProcessingOptions
    ) throws -> ProcessedContent {
        // Validate input ENML
        guard isValidENML(enml) else {
            throw NoteContentProcessingError.invalidENMLContent("Input is not valid ENML")
        }
        
        var warnings: [String] = []
        
        // Extract plain text from ENML (placeholder implementation)
        let plainText = try extractPlainTextFromENML(enml: enml, warnings: &warnings)
        
        return ProcessedContent(
            content: plainText,
            mimeType: "text/plain",
            resources: [],
            warnings: warnings
        )
    }
    
    public func isValidENML(_ enml: String) -> Bool {
        // Basic validation - check for ENML doctype and required elements
        let containsDoctype = enml.contains("<!DOCTYPE en-note")
        let containsEnNoteTag = enml.contains("<en-note")
        
        // In a real implementation, more thorough XML validation would be done
        return containsDoctype && containsEnNoteTag
    }
    
    public func extractResourceReferences(from enml: String) throws -> [ResourceReference] {
        // Placeholder implementation
        // In a real implementation, this would parse the ENML and extract resource references
        // from media tags and other resource references
        
        // Example resource extraction logic:
        var resources: [ResourceReference] = []
        
        // This is simplified - actual implementation would use XML parsing
        // Look for en-media tags with hash attributes
        // Example regex pattern (would need more robust XML parsing in production)
        let pattern = #"<en-media\s[^>]*hash="([^"]+)"[^>]*type="([^"]+)"[^>]*>"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            throw NoteContentProcessingError.conversionFailed("Failed to create regex for resource extraction")
        }
        
        let matches = regex.matches(in: enml, range: NSRange(enml.startIndex..., in: enml))
        
        for match in matches {
            guard 
                let hashRange = Range(match.range(at: 1), in: enml),
                let typeRange = Range(match.range(at: 2), in: enml)
            else {
                continue
            }
            
            let hash = String(enml[hashRange])
            let mimeType = String(enml[typeRange])
            
            // Generate a default filename based on hash and mime type
            let ext = mimeTypeToExtension(mimeType)
            let filename = "\(hash).\(ext)"
            
            // Create a placeholder URL
            let url = URL(string: "resource://\(hash)")!
            
            let resource = ResourceReference(
                id: hash,
                filename: filename,
                mimeType: mimeType,
                url: url,
                isEmbedded: false
            )
            
            resources.append(resource)
        }
        
        return resources
    }
    
    // MARK: - Private Helper Methods
    
    private func transformENMLToHTML(
        enml: String,
        resourceRefs: [ResourceReference],
        options: ContentProcessingOptions,
        warnings: inout [String]
    ) throws -> String {
        // Placeholder implementation
        // In a real implementation, this would parse the ENML and transform it to HTML
        
        // Steps would include:
        // 1. Parse ENML as XML
        // 2. Transform en-note to HTML body
        // 3. Transform en-media tags to img/object tags
        // 4. Handle other ENML-specific elements
        // 5. Apply styling based on options
        
        // For this placeholder, we'll just do a basic transformation
        var html = enml
        
        // Replace doctype and root element
        html = html.replacingOccurrences(of: "<!DOCTYPE en-note SYSTEM", with: "<!DOCTYPE html")
        html = html.replacingOccurrences(of: "<en-note", with: "<body")
        html = html.replacingOccurrences(of: "</en-note>", with: "</body>")
        
        // Add HTML structure
        html = "<html><head><meta charset=\"UTF-8\"></head>\(html)</html>"
        
        // Replace media tags with appropriate HTML
        for resource in resourceRefs {
            let mediaTag = #"<en-media hash="\#(resource.id)" type="\#(resource.mimeType)"[^>]*>"#
            
            let replacement: String
            if resource.mimeType.starts(with: "image/") {
                // Create image tag
                replacement = #"<img src="\#(resource.url.absoluteString)" alt="Attachment">"#
            } else {
                // Create link for other types
                replacement = #"<a href="\#(resource.url.absoluteString)" type="\#(resource.mimeType)">Attachment: \#(resource.filename)</a>"#
            }
            
            if let regex = try? NSRegularExpression(pattern: mediaTag) {
                let range = NSRange(html.startIndex..., in: html)
                html = regex.stringByReplacingMatches(in: html, range: range, withTemplate: replacement)
            } else {
                warnings.append("Failed to process media tag for resource \(resource.id)")
            }
        }
        
        return html
    }
    
    private func extractPlainTextFromENML(enml: String, warnings: inout [String]) throws -> String {
        // Placeholder implementation
        // A real implementation would parse the XML and extract text content
        
        // For this placeholder, we'll do a very simple extraction
        var text = enml
        
        // Remove XML tags
        while let startRange = text.range(of: "<"), 
              let endRange = text.range(of: ">", range: startRange.upperBound..<text.endIndex) {
            text.removeSubrange(startRange.lowerBound...endRange.upperBound)
        }
        
        // Decode HTML entities
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&apos;", with: "'")
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func processResources(
        resourceRefs: [ResourceReference],
        resources: [String: Data],
        options: ContentProcessingOptions,
        warnings: inout [String]
    ) throws -> [ResourceReference] {
        // Process each resource reference according to the options
        return try resourceRefs.map { ref in
            var resourceRef = ref
            
            // Check if resource data exists
            guard resources[ref.id] != nil else {
                warnings.append("Resource data not found for \(ref.id)")
                return resourceRef
            }
            
            // Update URL based on options
            if options.inlineResources {
                // For inline resources, we would encode the data as a data URL
                // This is just a placeholder - actual implementation would create data URLs
                resourceRef = ResourceReference(
                    id: ref.id,
                    filename: ref.filename,
                    mimeType: ref.mimeType,
                    url: URL(string: "data:\(ref.mimeType);base64,placeholder")!,
                    isEmbedded: true
                )
            } else if let baseURL = options.resourceBaseURL {
                // Use the provided base URL for resources
                let resourceURL = baseURL.appendingPathComponent(ref.filename)
                resourceRef = ResourceReference(
                    id: ref.id,
                    filename: ref.filename,
                    mimeType: ref.mimeType,
                    url: resourceURL,
                    isEmbedded: false
                )
            }
            
            return resourceRef
        }
    }
    
    private func mimeTypeToExtension(_ mimeType: String) -> String {
        switch mimeType {
        case "image/jpeg":
            return "jpg"
        case "image/png":
            return "png"
        case "image/gif":
            return "gif"
        case "application/pdf":
            return "pdf"
        case "text/plain":
            return "txt"
        case "text/html":
            return "html"
        case "application/msword":
            return "doc"
        case "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
            return "docx"
        default:
            // Default extension for unknown types
            return "bin"
        }
    }
}

