import SwiftUI
import ExtraqtivCore

/// `NoteListView` displays a list of notes with sorting, filtering, and selection capabilities.
///
/// This view is designed to be used in the main application interface, showing notes from
/// the currently selected notebook or search results. It supports:
/// - Displaying notes with preview of content
/// - Sorting by various criteria (date, title, etc.)
/// - Filtering notes based on user input
/// - Single and multiple selection of notes for export or other operations
struct NoteListView: View {
    // MARK: - Properties
    
    /// The array of notes to display
    @Binding var notes: [Note]
    
    /// Currently selected notes (for multi-selection operations)
    @Binding var selectedNotes: Set<UUID>
    
    /// The currently active note (for detailed view)
    @Binding var activeNoteID: UUID?
    
    /// Search text for filtering notes
    @State private var searchText = ""
    
    /// Current sort option
    @State private var sortOption: SortOption = .dateModified
    
    /// Sort direction (ascending/descending)
    @State private var sortAscending = false
    
    /// Whether multi-selection mode is active
    @State private var isMultiSelectActive = false
    
    // MARK: - Computed Properties
    
    /// Filtered and sorted notes based on current search and sort settings
    private var filteredAndSortedNotes: [Note] {
        let filtered = searchText.isEmpty 
            ? notes 
            : notes.filter { note in
                note.title.localizedCaseInsensitiveContains(searchText) ||
                note.content.plainText.localizedCaseInsensitiveContains(searchText)
            }
        
        return filtered.sorted { first, second in
            switch sortOption {
            case .dateCreated:
                return sortAscending 
                    ? first.createdAt < second.createdAt
                    : first.createdAt > second.createdAt
            case .dateModified:
                return sortAscending 
                    ? first.updatedAt < second.updatedAt
                    : first.updatedAt > second.updatedAt
            case .title:
                return sortAscending 
                    ? first.title < second.title
                    : first.title > second.title
            case .size:
                return sortAscending 
                    ? first.contentSize < second.contentSize
                    : first.contentSize > second.contentSize
            }
        }
    }
    
    // MARK: - View Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Search and Filter Bar
            searchAndFilterBar
            
            // Notes List
            List(selection: $selectedNotes) {
                ForEach(filteredAndSortedNotes) { note in
                    noteRow(note)
                        .id(note.id)
                        .tag(note.id)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }
            }
            .listStyle(.inset)
            .environment(\.editMode, .constant(isMultiSelectActive ? .active : .inactive))
        }
        .frame(minWidth: 250)
        .toolbar {
            ToolbarItemGroup {
                sortMenuButton
                multiSelectButton
            }
        }
    }
    
    // MARK: - Subviews
    
    /// Search bar and filter options
    private var searchAndFilterBar: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search Notes", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(8)
            .background(Color(.textBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            .padding([.horizontal, .top], 12)
            
            Divider()
                .padding(.top, 12)
        }
    }
    
    /// Sort menu button for the toolbar
    private var sortMenuButton: some View {
        Menu {
            Picker("Sort By", selection: $sortOption) {
                Text("Date Modified").tag(SortOption.dateModified)
                Text("Date Created").tag(SortOption.dateCreated)
                Text("Title").tag(SortOption.title)
                Text("Size").tag(SortOption.size)
            }
            
            Divider()
            
            Toggle(isOn: $sortAscending) {
                Label(
                    sortAscending ? "Ascending" : "Descending",
                    systemImage: sortAscending ? "arrow.up" : "arrow.down"
                )
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
    }
    
    /// Button to toggle multi-selection mode
    private var multiSelectButton: some View {
        Button(action: { isMultiSelectActive.toggle() }) {
            Label(
                isMultiSelectActive ? "Cancel Selection" : "Select Notes",
                systemImage: isMultiSelectActive ? "xmark" : "checkmark.circle"
            )
        }
        .help(isMultiSelectActive ? "Exit selection mode" : "Select multiple notes")
    }
    
    // MARK: - Helper Methods
    
    /// Creates a row view for an individual note
    /// - Parameter note: The note to display
    /// - Returns: A view representing the note in the list
    private func noteRow(_ note: Note) -> some View {
        Button(action: {
            if !isMultiSelectActive {
                activeNoteID = note.id
            }
        }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(note.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if let updatedAt = note.updatedAt {
                        Text(dateFormatter.string(from: updatedAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if !note.content.plainText.isEmpty {
                    Text(note.content.plainText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 8) {
                    // Tags
                    if !note.tags.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "tag")
                                .font(.caption)
                            
                            Text(note.tags.prefix(3).joined(separator: ", "))
                                .lineLimit(1)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    // Attachments indicator
                    if !note.resources.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "paperclip")
                            Text("\(note.resources.count)")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
        .background(activeNoteID == note.id && !isMultiSelectActive ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }
    
    // MARK: - Support Objects
    
    /// Options for sorting the note list
    enum SortOption: String, CaseIterable, Identifiable {
        case dateModified
        case dateCreated
        case title
        case size
        
        var id: String { self.rawValue }
    }
    
    /// Date formatter for displaying dates in the note list
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }
}

// MARK: - Previews

struct NoteListView_Previews: PreviewProvider {
    struct PreviewContainer: View {
        @State private var notes: [Note] = [
            Note(id: UUID(), title: "Meeting Notes", content: NoteContent(plainText: "Discussed project timeline and resource allocation", html: ""), tags: ["work", "meeting"], resources: [], createdAt: Date(), updatedAt: Date(), contentSize: 2048),
            Note(id: UUID(), title: "Shopping List", content: NoteContent(plainText: "Apples, Bananas, Milk, Bread", html: ""), tags: ["personal"], resources: [], createdAt: Date().addingTimeInterval(-86400), updatedAt: Date().addingTimeInterval(-3600), contentSize: 1024),
            Note(id: UUID(), title: "Project Ideas", content: NoteContent(plainText: "New app concept: productivity tool for researchers", html: ""), tags: ["work", "ideas", "projects"], resources: [NoteResource(id: UUID(), filename: "concept.png", type: "image/png", data: Data())], createdAt: Date().addingTimeInterval(-172800), updatedAt: Date().addingTimeInterval(-7200), contentSize: 4096)
        ]
        @State private var selectedNotes: Set<UUID> = []
        @State private var activeNoteID: UUID? = nil
        
        var body: some View {
            NoteListView(
                notes: $notes,
                selectedNotes: $selectedNotes,
                activeNoteID: $activeNoteID
            )
            .frame(width: 350, height: 500)
        }
    }
    
    static var previews: some View {
        PreviewContainer()
    }
}

