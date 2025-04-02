import SwiftUI
import xtraqtivCore

/// A view that displays a list of notebooks with metadata, search functionality, and multi-selection support.
///
/// This view is typically used in the sidebar of the application to display all available notebooks
/// from an Evernote account. It supports:
/// - Displaying notebook count and last updated timestamps
/// - Searching and filtering notebooks by name
/// - Multi-selection for batch operations
/// - Sorting by different criteria
struct NotebookListView: View {
    /// The available notebooks to display
    @Binding var notebooks: [Notebook]
    
    /// The currently selected notebooks
    @Binding var selectedNotebooks: Set<Notebook.ID>
    
    /// Search text for filtering notebooks
    @State private var searchText = ""
    
    /// Sort criteria for the notebook list
    @State private var sortCriteria: SortCriteria = .name
    
    /// Sort direction for the list
    @State private var sortAscending = true
    
    /// Specifies the criteria used for sorting notebooks
    enum SortCriteria: String, CaseIterable, Identifiable {
        case name = "Name"
        case lastUpdated = "Last Updated"
        case noteCount = "Note Count"
        
        var id: String { self.rawValue }
    }
    
    /// The filtered and sorted list of notebooks based on search text and sort settings
    private var filteredNotebooks: [Notebook] {
        let filtered = searchText.isEmpty 
            ? notebooks 
            : notebooks.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        
        return filtered.sorted { lhs, rhs in
            switch sortCriteria {
            case .name:
                return sortAscending 
                    ? lhs.name < rhs.name 
                    : lhs.name > rhs.name
            case .lastUpdated:
                return sortAscending 
                    ? lhs.lastUpdated < rhs.lastUpdated 
                    : lhs.lastUpdated > rhs.lastUpdated
            case .noteCount:
                return sortAscending 
                    ? lhs.noteCount < rhs.noteCount 
                    : lhs.noteCount > rhs.noteCount
            }
        }
    }
    
    var body: some View {
        VStack {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search notebooks", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            .padding(.horizontal)
            
            // Sort options
            HStack {
                Text("Sort by:")
                    .font(.caption)
                Picker("Sort criteria", selection: $sortCriteria) {
                    ForEach(SortCriteria.allCases) { criteria in
                        Text(criteria.rawValue).tag(criteria)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Button(action: { sortAscending.toggle() }) {
                    Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                }
                .buttonStyle(BorderlessButtonStyle())
                
                Spacer()
            }
            .padding(.horizontal)
            
            // Notebook list
            List(selection: $selectedNotebooks) {
                ForEach(filteredNotebooks) { notebook in
                    NotebookRow(notebook: notebook)
                        .tag(notebook.id)
                }
            }
            .listStyle(SidebarListStyle())
            
            // Selection controls
            HStack {
                Text("\(selectedNotebooks.count) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Select All") {
                    selectedNotebooks = Set(notebooks.map { $0.id })
                }
                .buttonStyle(BorderlessButtonStyle())
                .font(.caption)
                
                Button("Clear") {
                    selectedNotebooks.removeAll()
                }
                .buttonStyle(BorderlessButtonStyle())
                .font(.caption)
                .disabled(selectedNotebooks.isEmpty)
            }
            .padding(.horizontal)
        }
        .frame(minWidth: 250)
    }
}

/// A row in the notebook list displaying a notebook with its metadata
struct NotebookRow: View {
    let notebook: Notebook
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "notebook")
                    .foregroundColor(.accentColor)
                Text(notebook.name)
                    .font(.headline)
                Spacer()
                if notebook.isShared {
                    Image(systemName: "person.2")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            HStack {
                Text("\(notebook.noteCount) notes")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(notebook.lastUpdated, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// A preview provider for the NotebookListView
struct NotebookListView_Previews: PreviewProvider {
    static var previews: some View {
        // Sample notebooks for preview
        let sampleNotebooks = [
            Notebook(id: "1", name: "Work Notes", noteCount: 42, lastUpdated: Date(), isShared: false),
            Notebook(id: "2", name: "Personal", noteCount: 103, lastUpdated: Date().addingTimeInterval(-86400 * 3), isShared: true),
            Notebook(id: "3", name: "Research", noteCount: 18, lastUpdated: Date().addingTimeInterval(-86400 * 7), isShared: false),
            Notebook(id: "4", name: "Projects", noteCount: 72, lastUpdated: Date().addingTimeInterval(-3600), isShared: true)
        ]
        
        return Group {
            NotebookListView(
                notebooks: .constant(sampleNotebooks),
                selectedNotebooks: .constant(["1", "3"].reduce(into: Set<String>()) { $0.insert($1) })
            )
            .previewDisplayName("Light Mode")
            
            NotebookListView(
                notebooks: .constant(sampleNotebooks),
                selectedNotebooks: .constant(Set<String>())
            )
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
}

/// Model representing a notebook in the application
/// - Note: This is a placeholder definition - the actual implementation would be in xtraqtivCore
struct Notebook: Identifiable, Hashable {
    /// Unique identifier for the notebook
    let id: String
    
    /// Name of the notebook
    let name: String
    
    /// Number of notes in the notebook
    let noteCount: Int
    
    /// Date when the notebook was last updated
    let lastUpdated: Date
    
    /// Whether the notebook is shared with others
    let isShared: Bool
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Notebook, rhs: Notebook) -> Bool {
        lhs.id == rhs.id
    }
}

