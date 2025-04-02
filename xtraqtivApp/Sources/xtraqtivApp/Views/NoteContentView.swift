import SwiftUI
import WebKit
import xtraqtivCore

/// `NoteContentView` is responsible for rendering Evernote note content.
///
/// This view handles the conversion of ENML (Evernote Markup Language) to visually
/// appropriate content, displaying formatted text, embedded images, and other attachments.
/// It serves as the primary content display component for viewing notes within the application.
struct NoteContentView: View {
    /// The note to be displayed
    let note: Note?
    
    /// The content processor responsible for ENML conversion
    @EnvironmentObject private var contentProcessor: NoteContentProcessor
    
    /// The resource manager for handling attachments
    @EnvironmentObject private var resourceManager: ResourceManager
    
    /// State for tracking loading state
    @State private var isLoading = false
    
    /// State for storing converted HTML content
    @State private var htmlContent: String = ""
    
    /// State for storing any error during content processing
    @State private var error: Error? = nil
    
    /// Computed property to determine if an error is present
    private var hasError: Bool {
        error != nil
    }
    
    var body: some View {
        ZStack {
            if isLoading {
                loadingView
            } else if hasError {
                errorView
            } else if let note = note {
                contentView(for: note)
            } else {
                emptyView
            }
        }
        .onAppear {
            loadContent()
        }
        .onChange(of: note) { _ in
            loadContent()
        }
    }
    
    /// Loading indicator view
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading note content...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
    
    /// Error display view
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text("Error displaying note content")
                .font(.headline)
            
            if let error = error {
                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Try Again") {
                loadContent()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding()
    }
    
    /// Empty state view when no note is selected
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Note Selected")
                .font(.headline)
            Text("Select a note from the sidebar to view its content.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
    
    /// Main content view for displaying the note
    private func contentView(for note: Note) -> some View {
        VStack(spacing: 0) {
            // Title header
            titleHeader(note: note)
            
            // Note content as HTML
            htmlContentView
            
            // Attachments section if applicable
            if !note.resources.isEmpty {
                attachmentsSection(resources: note.resources)
            }
        }
    }
    
    /// Title header for the note
    private func titleHeader(note: Note) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(note.title)
                .font(.title)
                .fontWeight(.bold)
            
            HStack {
                Text("Last updated: \(formattedDate(note.updatedAt))")
                Spacer()
                if let notebookName = note.notebookName {
                    Label(notebookName, systemImage: "book")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            if !note.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(note.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.2))
                                .cornerRadius(6)
                        }
                    }
                }
            }
            
            Divider()
        }
        .padding()
    }
    
    /// WebKit-based HTML content view
    private var htmlContentView: some View {
        WebViewRepresentable(htmlContent: htmlContent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// Section displaying note attachments
    private func attachmentsSection(resources: [Resource]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            
            Text("Attachments (\(resources.count))")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(resources, id: \.id) { resource in
                        resourceThumbnail(resource)
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 140)
            .padding(.bottom)
        }
    }
    
    /// Thumbnail view for a resource/attachment
    private func resourceThumbnail(_ resource: Resource) -> some View {
        Button(action: {
            openResource(resource)
        }) {
            VStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 100, height: 80)
                    
                    if resource.isImage {
                        // For images, try to display a thumbnail
                        AsyncResourceImageView(resource: resource)
                            .frame(width: 100, height: 80)
                            .cornerRadius(8)
                    } else {
                        // For non-images, show an appropriate icon
                        Image(systemName: iconForResource(resource))
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(resource.filename ?? "Attachment")
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: 100)
                
                Text(formattedSize(resource.size))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
    
    /// Determines the appropriate icon for a resource based on its type
    private func iconForResource(_ resource: Resource) -> String {
        if resource.isImage {
            return "photo"
        } else if resource.isPDF {
            return "doc.text"
        } else if resource.isAudio {
            return "music.note"
        } else if resource.isVideo {
            return "film"
        } else {
            return "paperclip"
        }
    }
    
    /// Opens a resource for viewing or saving
    private func openResource(_ resource: Resource) {
        // Implementation would involve presenting a detail view or saving dialog
        // This would interact with ResourceManager to access the actual file
    }
    
    /// Loads and processes the note content
    private func loadContent() {
        guard let note = note else {
            htmlContent = ""
            return
        }
        
        isLoading = true
        error = nil
        
        // In a real implementation, this would use the injected contentProcessor
        Task {
            do {
                // Convert ENML to HTML with the content processor
                let html = try await contentProcessor.convertENMLToHTML(
                    note.content,
                    resources: note.resources
                )
                
                // Update the UI on the main thread
                await MainActor.run {
                    htmlContent = html
                    isLoading = false
                }
            } catch {
                // Handle any errors during conversion
                await MainActor.run {
                    self.error = error
                    isLoading = false
                }
            }
        }
    }
    
    /// Formats a date for display
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Formats a file size for display
    private func formattedSize(_ sizeInBytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(sizeInBytes))
    }
}

/// A SwiftUI wrapper for WKWebView to display HTML content
struct WebViewRepresentable: NSViewRepresentable {
    let htmlContent: String
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        if !htmlContent.isEmpty {
            // Apply custom CSS for styling the note content
            let styledHTML = """
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <style>
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                        line-height: 1.5;
                        margin: 0;
                        padding: 16px;
                        color: #333;
                    }
                    img {
                        max-width: 100%;
                        height: auto;
                    }
                    pre, code {
                        background-color: #f5f5f5;
                        border-radius: 4px;
                        padding: 8px;
                        font-family: monospace;
                    }
                    table {
                        border-collapse: collapse;
                        width: 100%;
                    }
                    table, th, td {
                        border: 1px solid #ddd;
                        padding: 8px;
                    }
                    th {
                        background-color: #f2f2f2;
                    }
                    a {
                        color: #0077cc;
                        text-decoration: none;
                    }
                    a:hover {
                        text-decoration: underline;
                    }
                    blockquote {
                        border-left: 4px solid #ddd;
                        margin: 16px 0;
                        padding: 8px 16px;
                        color: #666;
                    }
                    @media (prefers-color-scheme: dark) {
                        body {
                            background-color: #1e1e1e;
                            color: #ddd;
                        }
                        pre, code {
                            background-color: #2a2a2a;
                        }
                        table, th, td {
                            border-color: #444;
                        }
                        th {
                            background-color: #333;
                        }
                        a {
                            color: #3b9aff;
                        }
                        blockquote {
                            border-left-color: #444;
                            color: #aaa;
                        }
                    }
                </style>
            </head>
            <body>
                \(htmlContent)
            </body>
            </html>
            """
            
            webView.loadHTMLString(styledHTML, baseURL: nil)
        } else {
            webView.loadHTMLString("<html><body></body></html>", baseURL: nil)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Handle link clicks here
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}

/// A view for asynchronously loading and displaying resource images
struct AsyncResourceImageView: View {
    let resource: Resource
    @EnvironmentObject private var resourceManager: ResourceManager
    @State private var image: NSImage? = nil
    @State private var isLoading = false
    @State private var error: Error? = nil
    
    var body: some View {
        ZStack {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                ProgressView()
            } else if error != nil {
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
            } else {
                Color.clear
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        guard resource.isImage, !isLoading else { return }
        
        isLoading = true
        
        Task {
            do {
                // In a real implementation, this would use resourceManager to fetch the image data
                let imageData = try await resourceManager.fetchResourceData(resource)
                let nsImage = NSImage(data: imageData)
                
                await MainActor.run {
                    self.image = nsImage
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Previews

struct NoteContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview with a sample note
            NoteContentView(note: previewNote)
                .frame(width: 800, height: 600)
                .previewDisplayName("With Note")
            
            // Preview with no note selected
            NoteContentView(note: nil)
                .frame(width: 800, height: 600)
                .previewDisplayName("No Note Selected")
            
            // Preview with error state
            NoteContentView(note: previewNote)
                .onAppear {
                    // Force the error state for preview
                    if let view = NSApp.windows.first?.contentView?.subviews.first,
                       let contentView = Mirror(reflecting: view).descendant("content") as? NoteContentView {
                        // This is a hack for previews only
                        var mutableContentView = contentView
                        mutableContentView.

