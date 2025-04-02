import SwiftUI
import ExtraqtivCore

/// `ExportView` provides a comprehensive interface for configuring and executing note exports.
///
/// This view enables users to select export formats (ENEX, HTML, PDF), configure export options,
/// track export progress, and receive feedback about the export process including errors.
///
/// # Features
/// - Multiple export format selection
/// - Customizable export options per format
/// - Real-time progress tracking
/// - Error handling and user feedback
///
struct ExportView: View {
    // MARK: - Environment & State Properties
    
    /// The environment object that coordinates exports
    @EnvironmentObject private var coordinator: ExtraqtivCore.Coordinator
    
    /// Selected notebooks for export
    @Binding var selectedNotebooks: [Notebook]
    
    /// Selected notes for export when in single note selection mode
    @Binding var selectedNotes: [Note]
    
    /// Tracks whether the export operation is in progress
    @State private var isExporting = false
    
    /// Tracks the progress of the current export operation (0.0 to 1.0)
    @State private var exportProgress: Double = 0.0
    
    /// Export format options
    @State private var exportFormat: ExportFormat = .enex
    
    /// Path for export destination
    @State private var exportPath: String = ""
    
    /// Flag to show path selection dialog
    @State private var showingPathPicker = false
    
    /// Error message if export fails
    @State private var exportError: String? = nil
    
    /// Flag to show error alert
    @State private var showingErrorAlert = false
    
    /// Export status message
    @State private var statusMessage = "Ready to export"
    
    // MARK: - Export Format Options
    
    /// ENEX export options
    @State private var enexOptions = ENEXExportOptions()
    
    /// HTML export options
    @State private var htmlOptions = HTMLExportOptions()
    
    /// PDF export options
    @State private var pdfOptions = PDFExportOptions()
    
    // MARK: - Main View Body
    
    var body: some View {
        VStack(spacing: 20) {
            exportHeaderView
            
            exportSelectionSummaryView
            
            Divider()
            
            formatSelectionView
                .padding()
            
            exportOptionsView
                .padding()
            
            Divider()
            
            exportPathView
            
            if isExporting {
                exportProgressView
            }
            
            Spacer()
            
            actionButtonsView
        }
        .padding()
        .frame(minWidth: 500, minHeight: 600)
        .alert("Export Error", isPresented: $showingErrorAlert) {
            Button("OK") {
                exportError = nil
            }
        } message: {
            Text(exportError ?? "An unknown error occurred")
        }
        .onDisappear {
            // Cancel any in-progress export when view disappears
            if isExporting {
                cancelExport()
            }
        }
    }
    
    // MARK: - Component Views
    
    /// Header view displaying the export title and status
    private var exportHeaderView: some View {
        VStack {
            Text("Export Notes")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(statusMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    /// View summarizing the current selection for export
    private var exportSelectionSummaryView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Export Selection:")
                .font(.headline)
            
            if !selectedNotebooks.isEmpty {
                Text("• \(selectedNotebooks.count) notebooks selected")
                    .foregroundColor(.secondary)
            }
            
            if !selectedNotes.isEmpty {
                Text("• \(selectedNotes.count) individual notes selected")
                    .foregroundColor(.secondary)
            }
            
            if selectedNotebooks.isEmpty && selectedNotes.isEmpty {
                Text("No content selected for export")
                    .foregroundColor(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
    
    /// View for selecting export format
    private var formatSelectionView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Export Format")
                .font(.headline)
            
            Picker("", selection: $exportFormat) {
                Text("ENEX (Evernote Export)").tag(ExportFormat.enex)
                Text("HTML").tag(ExportFormat.html)
                Text("PDF").tag(ExportFormat.pdf)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.bottom, 5)
            
            Text(formatDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    /// View that shows format-specific options
    private var exportOptionsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Export Options")
                .font(.headline)
            
            switch exportFormat {
            case .enex:
                enexOptionsView
            case .html:
                htmlOptionsView
            case .pdf:
                pdfOptionsView
            }
        }
    }
    
    /// ENEX format specific options
    private var enexOptionsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Include note history", isOn: $enexOptions.includeHistory)
            Toggle("Include tags", isOn: $enexOptions.includeTags)
            Toggle("Include resources (attachments)", isOn: $enexOptions.includeResources)
            Toggle("Include note creation date", isOn: $enexOptions.includeCreated)
            Toggle("Include note update date", isOn: $enexOptions.includeUpdated)
        }
    }
    
    /// HTML format specific options
    private var htmlOptionsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Generate single HTML file per notebook", isOn: $htmlOptions.singleFilePerNotebook)
            Toggle("Include embedded resources", isOn: $htmlOptions.embedResources)
            Toggle("Include CSS styling", isOn: $htmlOptions.includeStyling)
            Toggle("Add table of contents", isOn: $htmlOptions.includeTableOfContents)
            Toggle("Include metadata header", isOn: $htmlOptions.includeMetadata)
        }
    }
    
    /// PDF format specific options
    private var pdfOptionsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Generate single PDF per notebook", isOn: $pdfOptions.singleFilePerNotebook)
            Toggle("Include table of contents", isOn: $pdfOptions.includeTableOfContents)
            Toggle("Include note metadata", isOn: $pdfOptions.includeMetadata)
            
            HStack {
                Text("Page Size:")
                Picker("", selection: $pdfOptions.pageSize) {
                    Text("Letter").tag(PDFPageSize.letter)
                    Text("A4").tag(PDFPageSize.a4)
                    Text("Legal").tag(PDFPageSize.legal)
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 120)
            }
            
            HStack {
                Text("Quality:")
                Picker("", selection: $pdfOptions.quality) {
                    Text("Draft").tag(PDFQuality.draft)
                    Text("Standard").tag(PDFQuality.standard)
                    Text("High").tag(PDFQuality.high)
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 120)
            }
        }
    }
    
    /// View for selecting and displaying export path
    private var exportPathView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Export Destination")
                .font(.headline)
            
            HStack {
                TextField("Select destination folder...", text: $exportPath)
                    .disabled(true)
                
                Button("Browse...") {
                    showingPathPicker = true
                }
                .disabled(isExporting)
            }
            .fileImporter(
                isPresented: $showingPathPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let selectedURL = urls.first else { return }
                    exportPath = selectedURL.path
                case .failure(let error):
                    exportError = "Failed to select folder: \(error.localizedDescription)"
                    showingErrorAlert = true
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
    
    /// View displaying export progress
    private var exportProgressView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Export Progress")
                .font(.headline)
            
            ProgressView(value: exportProgress)
                .progressViewStyle(LinearProgressViewStyle())
            
            Text(progressDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
    
    /// View containing action buttons (Export, Cancel)
    private var actionButtonsView: some View {
        HStack {
            Button(action: cancelExport) {
                Text("Cancel")
            }
            .buttonStyle(.bordered)
            .disabled(!isExporting)
            
            Spacer()
            
            Button(action: startExport) {
                Text(isExporting ? "Exporting..." : "Export")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isExporting || selectedNotebooks.isEmpty && selectedNotes.isEmpty || exportPath.isEmpty)
        }
    }
    
    // MARK: - Computed Properties
    
    /// Returns a description of the currently selected export format
    private var formatDescription: String {
        switch exportFormat {
        case .enex:
            return "ENEX format is compatible with Evernote and can be reimported. Best for backups and transfers between Evernote accounts."
        case .html:
            return "HTML format creates web pages that can be viewed in any browser. Good for sharing and archiving notes."
        case .pdf:
            return "PDF format creates fixed-layout documents. Best for printing and long-term archiving."
        }
    }
    
    /// Returns a description of the current progress
    private var progressDescription: String {
        let percentage = Int(exportProgress * 100)
        return "Exporting notes... \(percentage)% complete"
    }
    
    // MARK: - Methods
    
    /// Starts the export process based on current settings
    private func startExport() {
        guard !isExporting else { return }
        guard !selectedNotebooks.isEmpty || !selectedNotes.isEmpty else { return }
        guard !exportPath.isEmpty else { return }
        
        // Reset state
        exportProgress = 0.0
        exportError = nil
        isExporting = true
        statusMessage = "Exporting..."
        
        // Create export configuration based on selected format and options
        let config = createExportConfiguration()
        
        // Start export using the coordinator
        Task {
            do {
                try await coordinator.exportNotes(
                    notebooks: selectedNotebooks,
                    notes: selectedNotes,
                    configuration: config,
                    destination: URL(fileURLWithPath: exportPath),
                    progressHandler: { progress in
                        // Update progress on the main thread
                        DispatchQueue.main.async {
                            self.exportProgress = progress
                        }
                    }
                )
                
                // Update UI on completion
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.statusMessage = "Export completed successfully"
                }
            } catch {
                // Handle export error
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.exportError = error.localizedDescription
                    self.showingErrorAlert = true
                    self.statusMessage = "Export failed"
                }
            }
        }
    }
    
    /// Cancels the current export operation
    private func cancelExport() {
        guard isExporting else { return }
        
        // Cancel the export operation
        coordinator.cancelExport()
        
        // Update UI state
        isExporting = false
        statusMessage = "Export cancelled"
    }
    
    /// Creates an export configuration based on the selected format and options
    private func createExportConfiguration() -> ExportConfiguration {
        switch exportFormat {
        case .enex:
            return ENEXExportConfiguration(options: enexOptions)
        case .html:
            return HTMLExportConfiguration(options: htmlOptions)
        case .pdf:
            return PDFExportConfiguration(options: pdfOptions)
        }
    }
}

// MARK: - Supporting Types

/// Represents the available export formats
enum ExportFormat {
    case enex
    case html
    case pdf
}

/// Options for ENEX export format
struct ENEXExportOptions {
    var includeHistory: Bool = true
    var includeTags: Bool = true
    var includeResources: Bool = true
    var includeCreated: Bool = true
    var includeUpdated: Bool = true
}

/// Options for HTML export format
struct HTMLExportOptions {
    var singleFilePerNotebook: Bool = false
    var embedResources: Bool = true
    var includeStyling: Bool = true
    var includeTableOfContents: Bool = true
    var includeMetadata: Bool = true
}

/// Options for PDF export format
struct PDFExportOptions {
    var singleFilePerNotebook: Bool = false
    var includeTableOfContents: Bool = true
    var includeMetadata: Bool = true
    var pageSize: PDFPageSize = .letter
    var quality: PDFQuality = .standard
}

/// Represents PDF page size options
enum PDFPageSize {
    case letter
    case a4
    case legal
}

/// Represents PDF quality levels
enum PDFQuality {
    case draft
    case standard
    case high
}

/// Base protocol for export configurations
protocol ExportConfiguration {
    var format: ExportFormat { get }
}

/// ENEX export configuration
struct ENEXExportConfiguration: ExportConfiguration {
    let format: ExportFormat = .enex
    let options: ENEXExportOptions
}

/// HTML export configuration
struct HTMLExportConfiguration: ExportConfiguration {
    let format: ExportFormat = .html
    let options: HTMLExportOptions
}

/// PDF export configuration
struct PDFExportConfiguration: ExportConfiguration {
    let format: ExportFormat = .pdf
    let options: PDFExportOptions
}

// MARK: - Preview

struct ExportView_Previews: PreviewProvider {
    static var previews: some View {
        ExportView(
            selectedNotebooks: .constant([]),
            selectedNotes: .constant([])
        )
        .environmentObject(ExtraqtivCore.Coordinator())
    }
}

