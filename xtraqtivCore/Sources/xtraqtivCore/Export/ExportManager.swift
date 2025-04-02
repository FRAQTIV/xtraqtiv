//
//  ExportManager.swift
//  xtraqtivCore
//
//  Created by FRAQTIV
//

import Foundation
import Combine

/// Represents different export formats supported by the application
public enum ExportFormat: String, CaseIterable, Identifiable {
    case enex = "ENEX"
    case html = "HTML"
    case pdf = "PDF"
    
    public var id: String { rawValue }
    
    /// File extension associated with the export format
    public var fileExtension: String {
        switch self {
        case .enex: return "enex"
        case .html: return "html"
        case .pdf: return "pdf"
        }
    }
    
    /// MIME type associated with the export format
    public var mimeType: String {
        switch self {
        case .enex: return "application/enex+xml"
        case .html: return "text/html"
        case .pdf: return "application/pdf"
        }
    }
}

/// Represents errors that can occur during export operations
public enum ExportError: Error {
    /// Failed to create the export file
    case fileCreationFailed(String)
    
    /// Failed to write contents to the export file
    case writeError(String)
    
    /// Failed to convert note content to the selected format
    case conversionError(String)
    
    /// The export operation was cancelled by the user
    case cancelled
    
    /// Authentication error occurred during export
    case authenticationError(String)
    
    /// Error occurred while fetching resources
    case resourceFetchError(String)
    
    /// General export error with a description
    case general(String)
}

/// Represents the progress of an export operation
public struct ExportProgress {
    /// Total number of notes to export
    public let total: Int
    
    /// Number of notes successfully exported
    public let completed: Int
    
    /// Number of notes that failed to export
    public let failed: Int
    
    /// Calculated percentage of completion (0-100)
    public var percentComplete: Double {
        guard total > 0 else { return 0 }
        return Double(completed + failed) / Double(total) * 100.0
    }
    
    /// Current status message
    public let statusMessage: String
    
    /// Creates a new export progress instance
    /// - Parameters:
    ///   - total: Total number of notes to export
    ///   - completed: Number of notes successfully exported
    ///   - failed: Number of notes that failed to export
    ///   - statusMessage: Current status message
    public init(total: Int, completed: Int, failed: Int, statusMessage: String) {
        self.total = total
        self.completed = completed
        self.failed = failed
        self.statusMessage = statusMessage
    }
}

/// Protocol defining export operations
public protocol ExportService {
    /// Exports notes to the specified format
    /// - Parameters:
    ///   - notes: Array of notes to export
    ///   - format: Format to export the notes in
    ///   - destination: URL where the export should be saved
    ///   - progressHandler: Closure to handle progress updates
    ///   - cancellationToken: Token used to cancel the operation
    /// - Returns: A publisher that emits the export result
    func exportNotes(
        notes: [Note],
        to format: ExportFormat,
        at destination: URL,
        progressHandler: @escaping (ExportProgress) -> Void,
        cancellationToken: CancellationToken
    ) -> AnyPublisher<URL, ExportError>
    
    /// Checks if a specific export format is supported
    /// - Parameter format: The export format to check
    /// - Returns: Boolean indicating if the format is supported
    func isFormatSupported(_ format: ExportFormat) -> Bool
    
    /// Gets available export formats
    /// - Returns: Array of supported export formats
    func availableFormats() -> [ExportFormat]
}

/// Class used to cancel ongoing operations
public class CancellationToken {
    /// Whether the operation has been cancelled
    private var _isCancelled: Bool = false
    
    /// Thread-safe access to isCancelled property
    private let lock = NSLock()
    
    /// Whether the operation has been cancelled
    public var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isCancelled
    }
    
    /// Cancels the operation
    public func cancel() {
        lock.lock()
        _isCancelled = true
        lock.unlock()
    }
    
    /// Resets the cancellation state
    public func reset() {
        lock.lock()
        _isCancelled = false
        lock.unlock()
    }
    
    /// Creates a new cancellation token
    public init() {}
}

/// Concrete implementation of the ExportService protocol
public class ExportManager: ExportService {
    /// Singleton instance
    public static let shared = ExportManager()
    
    /// Export formatters for different formats
    private let formatters: [ExportFormat: ExportFormatter]
    
    /// Private initializer to enforce singleton pattern
    private init() {
        var formatters: [ExportFormat: ExportFormatter] = [:]
        formatters[.enex] = ENEXFormatter()
        formatters[.html] = HTMLFormatter()
        formatters[.pdf] = PDFFormatter()
        
        self.formatters = formatters
    }
    
    /// Returns whether a specific export format is supported
    /// - Parameter format: The format to check
    /// - Returns: Boolean indicating if the format is supported
    public func isFormatSupported(_ format: ExportFormat) -> Bool {
        return formatters.keys.contains(format)
    }
    
    /// Returns all available export formats
    /// - Returns: Array of supported export formats
    public func availableFormats() -> [ExportFormat] {
        return Array(formatters.keys).sorted(by: { $0.rawValue < $1.rawValue })
    }
    
    /// Exports notes to the specified format
    /// - Parameters:
    ///   - notes: Array of notes to export
    ///   - format: Format to export the notes in
    ///   - destination: URL where the export should be saved
    ///   - progressHandler: Closure to handle progress updates
    ///   - cancellationToken: Token used to cancel the operation
    /// - Returns: A publisher that emits the export result
    public func exportNotes(
        notes: [Note],
        to format: ExportFormat,
        at destination: URL,
        progressHandler: @escaping (ExportProgress) -> Void,
        cancellationToken: CancellationToken
    ) -> AnyPublisher<URL, ExportError> {
        
        return Future<URL, ExportError> { promise in
            // Check if the requested format is supported
            guard let formatter = self.formatters[format] else {
                promise(.failure(.general("Export format not supported: \(format.rawValue)")))
                return
            }
            
            // Initialize progress
            let total = notes.count
            var completed = 0
            var failed = 0
            
            // Report initial progress
            progressHandler(ExportProgress(
                total: total,
                completed: completed,
                failed: failed,
                statusMessage: "Starting export to \(format.rawValue)..."
            ))
            
            // Create background task for export operation
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // Check if the operation was cancelled before starting
                    if cancellationToken.isCancelled {
                        promise(.failure(.cancelled))
                        return
                    }
                    
                    // Create temporary directory for export if needed
                    var isDirectory: ObjCBool = false
                    if !FileManager.default.fileExists(atPath: destination.path, isDirectory: &isDirectory) {
                        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                    }
                    
                    // Process each note
                    for (index, note) in notes.enumerated() {
                        // Check cancellation
                        if cancellationToken.isCancelled {
                            promise(.failure(.cancelled))
                            return
                        }
                        
                        // Update progress with current note
                        progressHandler(ExportProgress(
                            total: total,
                            completed: completed,
                            failed: failed,
                            statusMessage: "Exporting note \(index + 1) of \(total): \(note.title)"
                        ))
                        
                        do {
                            // Export the note using the appropriate formatter
                            try formatter.formatNote(note, at: destination)
                            completed += 1
                        } catch {
                            // Handle individual note export failure
                            failed += 1
                            NSLog("Failed to export note: \(note.title). Error: \(error.localizedDescription)")
                            // Continue with next note instead of failing the entire operation
                        }
                        
                        // Update progress after processing the note
                        progressHandler(ExportProgress(
                            total: total,
                            completed: completed,
                            failed: failed,
                            statusMessage: "Exported \(completed) of \(total) notes"
                        ))
                    }
                    
                    // Report final progress
                    progressHandler(ExportProgress(
                        total: total,
                        completed: completed,
                        failed: failed,
                        statusMessage: "Export completed with \(completed) notes exported and \(failed) failures"
                    ))
                    
                    // Return the destination URL
                    promise(.success(destination))
                } catch {
                    // Handle general export errors
                    promise(.failure(.general("Export failed: \(error.localizedDescription)")))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

/// Protocol for formatting notes to specific export formats
protocol ExportFormatter {
    /// Formats a note and saves it to the specified location
    /// - Parameters:
    ///   - note: The note to format
    ///   - destination: The destination directory
    /// - Throws: ExportError if formatting or saving fails
    func formatNote(_ note: Note, at destination: URL) throws
}

/// Formatter for ENEX (Evernote Export) format
class ENEXFormatter: ExportFormatter {
    func formatNote(_ note: Note, at destination: URL) throws {
        // Implement ENEX formatting logic
        // This would include creating Evernote's XML format
        let enexContent = try generateENEXContent(from: note)
        let fileURL = destination.appendingPathComponent("\(note.safeFileName).enex")
        
        do {
            try enexContent.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw ExportError.writeError("Failed to write ENEX file: \(error.localizedDescription)")
        }
    }
    
    private func generateENEXContent(from note: Note) throws -> String {
        // TODO: Implement actual ENEX generation
        // This would include proper XML formatting according to Evernote's specifications
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE en-export SYSTEM "http://xml.evernote.com/pub/evernote-export3.dtd">
        <en-export export-date="\(Date().ISO8601Format())" application="xtraqtiv" version="1.0">
          <note>
            <title>\(note.title)</title>
            <content><![CDATA[\(note.content)]]></content>
            <created>\(note.createdAt.ISO8601Format())</created>
            <updated>\(note.updatedAt.ISO8601Format())</updated>
            <tag>\(note.tags.joined(separator: "</tag><tag>"))</tag>
          </note>
        </en-export>
        """
    }
}

/// Formatter for HTML format
class HTMLFormatter: ExportFormatter {
    func formatNote(_ note: Note, at destination: URL) throws {
        // Implement HTML formatting logic
        let htmlContent = try generateHTMLContent(from: note)
        let fileURL = destination.appendingPathComponent("\(note.safeFileName).html")
        
        do {
            try htmlContent.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw ExportError.writeError("Failed to write HTML file: \(error.localizedDescription)")
        }
    }
    
    private func generateHTMLContent(from note: Note) throws -> String {
        // TODO: Implement actual HTML generation
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>\(note.title)</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; margin: 20px; }
                .note-title { font-size: 24px; font-weight: bold; margin-bottom: 10px; }
                .note-meta { color: #666; font-size: 12px; margin-bottom: 20px; }
                .note-content { line-height: 1.5; }
                .note-tags { margin-top: 20px; }
                .tag { background-color: #f0f0f0; padding: 3px 8px; border-radius: 3px; margin-right: 5px; font-size: 12px; }
            </style>
        </head>
        <body>
            <div class="note-title">\(note.title)</div>
            <div class="note-meta">
                Created: \(note.createdAt.formatted())
                <br>
                Updated: \(note.updatedAt.formatted())
            </div>
            <div class="note-content">
                \(note.content)
            </div>
            <div class="note-tags">
                \(note.tags.map { "<span class=\"tag\">\($0)</span>" }.joined(separator: " "))
            </div>
        </body>
        </html>
        """
    }
}

/// Formatter for PDF format
class PDFFormatter: ExportFormatter {
    func formatNote(_ note: Note, at destination: URL) throws {
        // In a real implementation, this would use PDFKit or another PDF generation library
        // For now, this is a placeholder that would convert HTML to PDF
        
        // First generate HTML
        let htmlFormatter = HTMLFormatter()
        let htmlDestination = FileManager.default.temporaryDirectory
        try htmlFormatter.formatNote(note, at: htmlDestination)
        
        let htmlFile = htmlDestination.appendingPathComponent("\(note.safeFileName).html")
        let pdfFile = destination.appendingPathComponent("\(note.safeFileName).pdf")
        
        // In a real implementation, convert HTML to PDF here
        // This is a placeholder that would use a library or system service to convert HTML to PDF
        throw ExportError.general("PDF conversion not fully implemented yet")
    }
}

/// Extension to Note for file name safety
extension Note {
    /// A file system safe version of the note title
    var safeFileName: String {
        let illegalCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        var safeName = title.components(separatedBy: illegalCharacters).joined(separator: "-")
        
        // Limit length and remove leading/trailing spaces
        safeName = safeName.trimmingCharacters(in: .whitespacesAndNewlines)
        if safeName.count > 100 {
            safeName = String(safeName.prefix(100))
        }
        
        // Ensure we have a valid filename
        if safeName.isEmpty {
            

