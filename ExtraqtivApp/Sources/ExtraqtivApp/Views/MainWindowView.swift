import SwiftUI
import ExtraqtivCore

/// # MainWindowView
/// 
/// The primary view for the Extraqtiv application's main window.
/// 
/// This view establishes the core layout of the application, including:
/// - A sidebar for navigating notebooks and other content
/// - A content area for displaying notes and their details
/// - A toolbar with action buttons for common operations
/// 
/// The view uses SwiftUI's NavigationSplitView for a three-column layout that
/// adapts to different window sizes and user preferences.
struct MainWindowView: View {
    // MARK: - State Properties
    
    /// The currently selected notebook in the sidebar
    @State private var selectedNotebook: NotebookItem?
    
    /// The currently selected note in the content list
    @State private var selectedNote: NoteItem?
    
    /// Controls whether the authentication sheet is presented
    @State private var isAuthenticating = false
    
    /// Controls whether the export sheet is presented
    @State private var isExporting = false
    
    /// Search text for filtering notes and notebooks
    @State private var searchText = ""
    
    // MARK: - Sample Data (To be replaced with actual data from ExtraqtivCore)
    
    /// Sample notebooks for preview and development
    @State private var notebooks = [
        NotebookItem(id: "1", name: "Work", noteCount: 42),
        NotebookItem(id: "2", name: "Personal", noteCount: 27),
        NotebookItem(id: "3", name: "Research", noteCount: 15),
        NotebookItem(id: "4", name: "Projects", noteCount: 8)
    ]
    
    /// Sample notes for preview and development
    @State private var notes = [
        NoteItem(id: "1", title: "Meeting Notes", preview: "Discussion about new project...", dateModified: Date()),
        NoteItem(id: "2", title: "Ideas", preview: "New feature concepts for the app...", dateModified: Date().addingTimeInterval(-86400)),
        NoteItem(id: "3", title: "To-Do", preview: "1. Finish documentation\n2. Test export...", dateModified: Date().addingTimeInterval(-172800))
    ]
    
    // MARK: - Body
    
    var body: some View {
        NavigationSplitView {
            // MARK: Sidebar (First Column)
            sidebarView
        } content: {
            // MARK: Content List (Second Column)
            if let selectedNotebook = selectedNotebook {
                noteListView(for: selectedNotebook)
            } else {
                Text("Select a notebook")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        } detail: {
            // MARK: Detail View (Third Column)
            if let selectedNote = selectedNote {
                noteDetailView(for: selectedNote)
            } else {
                Text("Select a note to view its contents")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Extraqtiv")
        .toolbar {
            // MARK: Toolbar Items
            ToolbarItemGroup {
                refreshButton
                exportButton
                Spacer()
                authButton
            }
        }
        .searchable(text: $searchText, prompt: "Search notes and notebooks")
        .sheet(isPresented: $isAuthenticating) {
            AuthenticationView()
        }
        .sheet(isPresented: $isExporting) {
            ExportView(notebooks: notebooks, selectedNotebook: selectedNotebook)
        }
    }
    
    // MARK: - Component Views
    
    /// Sidebar view displaying notebooks and navigation options
    private var sidebarView: some View {
        List(selection: $selectedNotebook) {
            Section("Notebooks") {
                ForEach(notebooks) { notebook in
                    notebookRow(notebook)
                }
            }
            
            Section("Smart Filters") {
                NavigationLink(destination: EmptyView()) {
                    Label("Recently Modified", systemImage: "clock")
                }
                NavigationLink(destination: EmptyView()) {
                    Label("With Attachments", systemImage: "paperclip")
                }
                NavigationLink(destination: EmptyView()) {
                    Label("Favorites", systemImage: "star")
                }
            }
        }
        .listStyle(.sidebar)
    }
    
    /// Creates a row for displaying a notebook in the sidebar
    /// - Parameter notebook: The notebook to display
    /// - Returns: A view representing the notebook row
    private func notebookRow(_ notebook: NotebookItem) -> some View {
        NavigationLink(value: notebook) {
            HStack {
                Label(notebook.name, systemImage: "notebook")
                Spacer()
                Text("\(notebook.noteCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
        }
    }
    
    /// Creates the note list view for a selected notebook
    /// - Parameter notebook: The notebook whose notes should be displayed
    /// - Returns: A view containing the list of notes
    private func noteListView(for notebook: NotebookItem) -> some View {
        List(selection: $selectedNote) {
            ForEach(notes) { note in
                noteRow(note)
            }
        }
        .listStyle(.plain)
        .navigationTitle(notebook.name)
    }
    
    /// Creates a row for displaying a note in the note list
    /// - Parameter note: The note to display
    /// - Returns: A view representing the note row
    private func noteRow(_ note: NoteItem) -> some View {
        NavigationLink(value: note) {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(.headline)
                Text(note.preview)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                Text(note.dateModified, style: .date)
                    .font(.caption)
                    .foregroundColor(.tertiary)
            }
            .padding(.vertical, 4)
        }
    }
    
    /// Creates the detailed view for a selected note
    /// - Parameter note: The note to display in detail
    /// - Returns: A view containing the note's full content
    private func noteDetailView(for note: NoteItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(note.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Modified: \(note.dateModified, style: .date)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Divider()
                
                // This would be replaced with actual note content rendering
                Text("This is a placeholder for the actual note content. In the final implementation, this would render the full note content with proper formatting, images, and other attachments.")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding()
        }
        .navigationTitle(note.title)
        .toolbar {
            ToolbarItemGroup {
                Button(action: {
                    // Action to share note
                }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                
                Menu {
                    Button("Export as PDF") { }
                    Button("Export as HTML") { }
                    Button("Export as Markdown") { }
                } label: {
                    Label("Export Note", systemImage: "arrow.down.doc")
                }
            }
        }
    }
    
    // MARK: - Toolbar Buttons
    
    /// Button to refresh notes and notebooks from Evernote
    private var refreshButton: some View {
        Button(action: {
            // Refresh action would be implemented here
        }) {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
    }
    
    /// Button to open the export dialog
    private var exportButton: some View {
        Button(action: {
            isExporting = true
        }) {
            Label("Export", systemImage: "square.and.arrow.down")
        }
    }
    
    /// Button to authenticate with Evernote
    private var authButton: some View {
        Button(action: {
            isAuthenticating = true
        }) {
            Label("Account", systemImage: "person.crop.circle")
        }
    }
}

// MARK: - Model Structures

/// Represents a notebook in the sidebar
struct NotebookItem: Identifiable, Hashable {
    var id: String
    var name: String
    var noteCount: Int
}

/// Represents a note in the note list
struct NoteItem: Identifiable, Hashable {
    var id: String
    var title: String
    var preview: String
    var dateModified: Date
}

// MARK: - Preview Providers

/// Provides a preview of the main window view for SwiftUI previews
struct MainWindowView_Previews: PreviewProvider {
    static var previews: some View {
        MainWindowView()
            .frame(width: 1200, height: 800)
    }
}

// MARK: - Placeholder Views

/// Placeholder for the authentication view
/// This would be replaced with the actual implementation
struct AuthenticationView: View {
    var body: some View {
        VStack {
            Text("Evernote Authentication")
                .font(.title)
            
            Text("This is a placeholder for the Evernote authentication view.")
                .padding()
            
            Button("Authenticate") {
                // Authentication logic would go here
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .frame(width: 400, height: 300)
    }
}

/// Placeholder for the export view
/// This would be replaced with the actual implementation
struct ExportView: View {
    var notebooks: [NotebookItem]
    var selectedNotebook: NotebookItem?
    
    var body: some View {
        VStack {
            Text("Export Notes")
                .font(.title)
            
            Form {
                Section("What to Export") {
                    Picker("Select Notebook", selection: .constant(selectedNotebook)) {
                        Text("All Notebooks").tag(nil as NotebookItem?)
                        ForEach(notebooks) { notebook in
                            Text(notebook.name).tag(notebook as NotebookItem?)
                        }
                    }
                }
                
                Section("Export Format") {
                    Picker("Format", selection: .constant(0)) {
                        Text("ENEX (Evernote Export)").tag(0)
                        Text("HTML").tag(1)
                        Text("PDF").tag(2)
                        Text("Markdown").tag(3)
                    }
                }
                
                Section("Options") {
                    Toggle("Include Attachments", isOn: .constant(true))
                    Toggle("Preserve Formatting", isOn: .constant(true))
                    Toggle("Export Tags", isOn: .constant(true))
                }
            }
            
            HStack {
                Button("Cancel") {
                    // Cancel logic
                }
                .buttonStyle(.bordered)
                
                Button("Export") {
                    // Export logic
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }
}

