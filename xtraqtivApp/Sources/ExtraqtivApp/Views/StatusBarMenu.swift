import SwiftUI
import ExtraqtivCore

/**
 * StatusBarMenu
 *
 * A SwiftUI component that implements a macOS status bar menu for the Extraqtiv application.
 *
 * Features:
 * - Evernote connection status indicator 
 * - Quick export actions for recently accessed notebooks
 * - Recent notebooks access for quick navigation
 * - Settings and help options
 *
 * Usage:
 * ```swift
 * StatusBarMenu(
 *     isConnected: $isConnected,
 *     recentNotebooks: recentNotebooks,
 *     onExportAction: handleExport,
 *     onOpenNotebook: handleOpenNotebook
 * )
 * ```
 */
struct StatusBarMenu: View {
    // MARK: - Properties
    
    /// Current Evernote connection status
    @Binding var isConnected: Bool
    
    /// Recently accessed notebooks
    let recentNotebooks: [Notebook]
    
    /// Current app settings
    @EnvironmentObject private var appSettings: AppSettingsManager
    
    /// Authentication service from ExtraqtivCore
    @EnvironmentObject private var authService: EvernoteAuthService
    
    /// Export manager from ExtraqtivCore
    @EnvironmentObject private var exportManager: ExportManager
    
    // MARK: - Callbacks
    
    /// Callback when user selects an export action
    var onExportAction: (ExportFormat, Notebook?) -> Void
    
    /// Callback when user selects to open a notebook
    var onOpenNotebook: (Notebook) -> Void
    
    /// Callback when user selects to open settings
    var onOpenSettings: () -> Void
    
    /// Callback when user selects to open help
    var onOpenHelp: () -> Void
    
    // MARK: - Initialization
    
    /**
     * Initializes a new StatusBarMenu
     *
     * - Parameters:
     *   - isConnected: Binding to the current Evernote connection status
     *   - recentNotebooks: Array of recently accessed notebooks
     *   - onExportAction: Callback for handling export actions
     *   - onOpenNotebook: Callback for handling notebook opening
     *   - onOpenSettings: Callback for opening the settings view
     *   - onOpenHelp: Callback for opening the help view
     */
    init(
        isConnected: Binding<Bool>,
        recentNotebooks: [Notebook],
        onExportAction: @escaping (ExportFormat, Notebook?) -> Void,
        onOpenNotebook: @escaping (Notebook) -> Void,
        onOpenSettings: @escaping () -> Void = {},
        onOpenHelp: @escaping () -> Void = {}
    ) {
        self._isConnected = isConnected
        self.recentNotebooks = recentNotebooks
        self.onExportAction = onExportAction
        self.onOpenNotebook = onOpenNotebook
        self.onOpenSettings = onOpenSettings
        self.onOpenHelp = onOpenHelp
    }
    
    // MARK: - Body
    
    var body: some View {
        // Main menu
        Menu {
            connectionStatusSection
            
            Divider()
            
            exportActionsSection
            
            Divider()
            
            recentNotebooksSection
            
            Divider()
            
            settingsAndHelpSection
        } label: {
            statusBarIcon
        }
    }
    
    // MARK: - Menu Sections
    
    /// Connection status section
    private var connectionStatusSection: some View {
        Section {
            HStack {
                Image(systemName: isConnected ? "circle.fill" : "circle")
                    .foregroundColor(isConnected ? .green : .red)
                Text(isConnected ? "Connected to Evernote" : "Disconnected")
            }
            
            if !isConnected {
                Button("Connect to Evernote") {
                    Task {
                        try? await authService.authenticate()
                    }
                }
            } else {
                Button("Disconnect") {
                    Task {
                        await authService.signOut()
                    }
                }
            }
        }
    }
    
    /// Export actions section
    private var exportActionsSection: some View {
        Section("Export Actions") {
            Button("Export All Notebooks") {
                onExportAction(.enex, nil)
            }
            .disabled(!isConnected)
            
            Menu("Export Format") {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    Button(format.description) {
                        appSettings.setDefaultExportFormat(format)
                    }
                    .disabled(!isConnected)
                }
            }
            .disabled(!isConnected)
        }
    }
    
    /// Recent notebooks section
    private var recentNotebooksSection: some View {
        Section("Recent Notebooks") {
            if recentNotebooks.isEmpty {
                Text("No recent notebooks")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                ForEach(recentNotebooks.prefix(5)) { notebook in
                    notebookMenuItem(for: notebook)
                }
                
                if recentNotebooks.count > 5 {
                    Button("Show All Recent Notebooks...") {
                        // Open main app window focused on notebooks
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
            }
        }
    }
    
    /// Settings and help section
    private var settingsAndHelpSection: some View {
        Section {
            Button("Settings...") {
                onOpenSettings()
            }
            
            Button("Help...") {
                onOpenHelp()
            }
            
            Divider()
            
            Button("Quit Extraqtiv") {
                NSApp.terminate(nil)
            }
        }
    }
    
    // MARK: - Helper Views
    
    /// Status bar icon
    private var statusBarIcon: some View {
        Image(systemName: "doc.text.magnifyingglass")
            .symbolVariant(isConnected ? .fill : .none)
            .foregroundColor(isConnected ? .accentColor : .secondary)
    }
    
    /// Menu item for a notebook
    private func notebookMenuItem(for notebook: Notebook) -> some View {
        Menu(notebook.name) {
            Button("Open Notebook") {
                onOpenNotebook(notebook)
            }
            
            Menu("Export Notebook") {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    Button(format.description) {
                        onExportAction(format, notebook)
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    StatusBarMenu(
        isConnected: .constant(true),
        recentNotebooks: [
            Notebook(id: "1", name: "Work Notes", stack: "Work"),
            Notebook(id: "2", name: "Personal Notes", stack: "Personal"),
            Notebook(id: "3", name: "Research", stack: "Work")
        ],
        onExportAction: { _, _ in },
        onOpenNotebook: { _ in }
    )
    .environmentObject(AppSettingsManager())
}

/**
 * Extension to provide string descriptions for export formats
 */
extension ExportFormat {
    var description: String {
        switch self {
        case .enex:
            return "Evernote Export (.enex)"
        case .html:
            return "HTML (.html)"
        case .markdown:
            return "Markdown (.md)"
        case .pdf:
            return "PDF Document (.pdf)"
        case .text:
            return "Plain Text (.txt)"
        }
    }
}

/**
 * StatusBarController
 *
 * A controller class that manages the macOS status bar item and menu.
 * This class handles the lifecycle of the status bar item and connects
 * it to the SwiftUI StatusBarMenu view.
 */
class StatusBarController {
    // MARK: - Properties
    
    /// The status bar item
    private var statusItem: NSStatusItem?
    
    /// The SwiftUI hosting view
    private var hostingView: NSHostingView<StatusBarMenu>?
    
    /// Evernote connection status
    @Binding private var isConnected: Bool
    
    /// Recently accessed notebooks
    @Binding private var recentNotebooks: [Notebook]
    
    /// Callbacks for menu actions
    private let onExportAction: (ExportFormat, Notebook?) -> Void
    private let onOpenNotebook: (Notebook) -> Void
    private let onOpenSettings: () -> Void
    private let onOpenHelp: () -> Void
    
    /**
     * Initializes a new StatusBarController
     *
     * - Parameters:
     *   - isConnected: Binding to the current Evernote connection status
     *   - recentNotebooks: Binding to recently accessed notebooks
     *   - onExportAction: Callback for handling export actions
     *   - onOpenNotebook: Callback for handling notebook opening
     *   - onOpenSettings: Callback for opening settings
     *   - onOpenHelp: Callback for opening help documentation
     */
    init(
        isConnected: Binding<Bool>,
        recentNotebooks: Binding<[Notebook]>,
        onExportAction: @escaping (ExportFormat, Notebook?) -> Void,
        onOpenNotebook: @escaping (Notebook) -> Void,
        onOpenSettings: @escaping () -> Void,
        onOpenHelp: @escaping () -> Void
    ) {
        self._isConnected = isConnected
        self._recentNotebooks = recentNotebooks
        self.onExportAction = onExportAction
        self.onOpenNotebook = onOpenNotebook
        self.onOpenSettings = onOpenSettings
        self.onOpenHelp = onOpenHelp
    }
    
    /**
     * Sets up the status bar item and menu
     *
     * - Parameter appSettings: The application settings manager
     * - Parameter authService: The authentication service
     * - Parameter exportManager: The export manager
     */
    func setupStatusBarItem(
        appSettings: AppSettingsManager,
        authService: EvernoteAuthService,
        exportManager: ExportManager
    ) {
        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Create the SwiftUI menu
        let statusBarMenu = StatusBarMenu(
            isConnected: _isConnected,
            recentNotebooks: recentNotebooks,
            onExportAction: onExportAction,
            onOpenNotebook: onOpenNotebook,
            onOpenSettings: onOpenSettings,
            onOpenHelp: onOpenHelp
        )
        .environmentObject(appSettings)
        .environmentObject(authService)
        .environmentObject(exportManager)
        
        // Create the hosting view
        hostingView = NSHostingView(rootView: statusBarMenu)
        
        // Set up the menu
        if let hostingView = hostingView, let statusItem = statusItem {
            hostingView.frame = NSRect(x: 0, y: 0, width: 250, height: 250)
            
            let menu = NSMenu()
            let menuItem = NSMenuItem()
            menuItem.view = hostingView
            menu.addItem(menuItem)
            
            statusItem.menu = menu
            statusItem.button?.image = NSImage(systemSymbolName: "doc.text.magnifyingglass", accessibilityDescription: "Extraqtiv")
        }
    }
    
    /**
     * Removes the status bar item
     */
    func removeStatusBarItem() {
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
            self.hostingView = nil
        }
    }
}

