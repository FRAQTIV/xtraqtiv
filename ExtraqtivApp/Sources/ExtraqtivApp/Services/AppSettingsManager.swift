//
//  AppSettingsManager.swift
//  ExtraqtivApp
//
//  Created by FRAQTIV
//

import Foundation
import Combine

/// Defines keys for all application settings to ensure type safety and consistency
public enum SettingsKey: String, CaseIterable {
    // Export settings
    case defaultExportFormat
    case preserveFormatting
    case includeMetadata
    case includeAttachments
    case exportLocation
    
    // UI settings
    case sidebarWidth
    case noteListWidth
    case defaultSortOrder
    case showPreviewPane
    
    // Authentication settings
    case lastAuthenticatedUsername
    case authTokenExpiration
    
    // Application settings
    case lastOpenedNotebook
    case lastExportDate
    case autoCheckForUpdates
    case useDarkMode
}

/// Enum representing available export formats
public enum ExportFormat: String, Codable, CaseIterable {
    case enex = "ENEX"
    case html = "HTML"
    case markdown = "Markdown"
    case pdf = "PDF"
    case plainText = "Plain Text"
    
    var fileExtension: String {
        switch self {
        case .enex: return "enex"
        case .html: return "html"
        case .markdown: return "md"
        case .pdf: return "pdf"
        case .plainText: return "txt"
        }
    }
}

/// Enum representing available note sort orders
public enum NoteSortOrder: String, Codable, CaseIterable {
    case titleAscending = "Title (A-Z)"
    case titleDescending = "Title (Z-A)"
    case dateCreatedNewest = "Date Created (Newest)"
    case dateCreatedOldest = "Date Created (Oldest)"
    case dateUpdatedNewest = "Date Updated (Newest)"
    case dateUpdatedOldest = "Date Updated (Oldest)"
}

/**
 * AppSettingsManager
 *
 * A service responsible for managing application settings with the following features:
 * - Persistent storage using UserDefaults
 * - Type-safe access to settings via strongly typed keys
 * - Default values for all settings
 * - Observable settings changes via Combine
 *
 * Usage:
 * ```
 * // Access settings directly
 * let exportFormat = AppSettingsManager.shared.getValue(for: .defaultExportFormat, defaultValue: ExportFormat.enex)
 *
 * // Use with property wrapper
 * @Setting(.defaultExportFormat, defaultValue: ExportFormat.enex) var exportFormat: ExportFormat
 * ```
 */
public class AppSettingsManager: ObservableObject {
    /// Shared singleton instance
    public static let shared = AppSettingsManager()
    
    /// Publisher that emits when any setting changes
    private let settingsChangeSubject = PassthroughSubject<SettingsKey, Never>()
    
    /// UserDefaults suite used for storing settings
    private let defaults: UserDefaults
    
    /// Dictionary of default values for all settings
    private let defaultValues: [SettingsKey: Any] = [
        // Export defaults
        .defaultExportFormat: ExportFormat.enex.rawValue,
        .preserveFormatting: true,
        .includeMetadata: true,
        .includeAttachments: true,
        .exportLocation: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? "",
        
        // UI defaults
        .sidebarWidth: 250,
        .noteListWidth: 300,
        .defaultSortOrder: NoteSortOrder.dateUpdatedNewest.rawValue,
        .showPreviewPane: true,
        
        // App defaults
        .lastOpenedNotebook: "",
        .lastExportDate: Date.distantPast,
        .autoCheckForUpdates: true,
        .useDarkMode: true,
        
        // Auth defaults - empty since these are populated during runtime
        .lastAuthenticatedUsername: "",
        .authTokenExpiration: Date.distantPast
    ]
    
    /// Publisher for observing settings changes
    public var settingsChangePublisher: AnyPublisher<SettingsKey, Never> {
        settingsChangeSubject.eraseToAnyPublisher()
    }
    
    /**
     * Initialize the settings manager with a specific UserDefaults suite.
     *
     * - Parameter defaults: UserDefaults suite to use for storage. Defaults to standard UserDefaults.
     */
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaultValues()
    }
    
    /**
     * Registers default values with UserDefaults.
     */
    private func registerDefaultValues() {
        var defaultsDictionary: [String: Any] = [:]
        
        for (key, value) in defaultValues {
            defaultsDictionary[key.rawValue] = value
        }
        
        defaults.register(defaults: defaultsDictionary)
    }
    
    /**
     * Resets all settings to their default values.
     */
    public func resetToDefaults() {
        for key in SettingsKey.allCases {
            if let defaultValue = defaultValues[key] {
                defaults.set(defaultValue, forKey: key.rawValue)
                settingsChangeSubject.send(key)
            }
        }
    }
    
    /**
     * Gets a strongly typed value for a settings key.
     *
     * - Parameters:
     *   - key: The settings key to retrieve
     *   - defaultValue: The default value to return if the setting is not found
     * - Returns: The stored value, or the default if not found
     */
    public func getValue<T>(for key: SettingsKey, defaultValue: T) -> T {
        let result = defaults.object(forKey: key.rawValue)
        
        // Handle Codable types (like enums)
        if let codableDefaultValue = defaultValue as? Codable,
           let storedData = defaults.data(forKey: key.rawValue) {
            let decoder = JSONDecoder()
            return (try? decoder.decode(T.self, from: storedData)) ?? defaultValue
        }
        
        return (result as? T) ?? defaultValue
    }
    
    /**
     * Sets a strongly typed value for a settings key.
     *
     * - Parameters:
     *   - value: The value to store
     *   - key: The settings key to update
     */
    public func setValue<T>(_ value: T, for key: SettingsKey) {
        // Handle Codable types (like enums)
        if let codableValue = value as? Codable {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(codableValue) {
                defaults.set(encoded, forKey: key.rawValue)
                settingsChangeSubject.send(key)
                return
            }
        }
        
        defaults.set(value, forKey: key.rawValue)
        settingsChangeSubject.send(key)
    }
    
    /**
     * Removes a value for a settings key, reverting to the default.
     *
     * - Parameter key: The settings key to remove
     */
    public func removeValue(for key: SettingsKey) {
        defaults.removeObject(forKey: key.rawValue)
        settingsChangeSubject.send(key)
    }
}

/**
 * Property wrapper for accessing settings with automatic observation.
 *
 * Usage:
 * ```
 * @Setting(.defaultExportFormat, defaultValue: ExportFormat.enex) 
 * var exportFormat: ExportFormat
 * ```
 */
@propertyWrapper
public struct Setting<T>: DynamicProperty {
    @ObservedObject private var settingsManager: AppSettingsManager
    private let key: SettingsKey
    private let defaultValue: T
    private var cancellables = Set<AnyCancellable>()
    
    public init(_ key: SettingsKey, defaultValue: T, settingsManager: AppSettingsManager = .shared) {
        self.key = key
        self.defaultValue = defaultValue
        self.settingsManager = settingsManager
    }
    
    public var wrappedValue: T {
        get {
            return settingsManager.getValue(for: key, defaultValue: defaultValue)
        }
        set {
            settingsManager.setValue(newValue, for: key)
        }
    }
    
    /// Projected value provides access to the publisher for this setting
    public var projectedValue: Setting<T> {
        return self
    }
    
    /// Publisher that emits when this specific setting changes
    public var publisher: AnyPublisher<T, Never> {
        settingsManager.settingsChangePublisher
            .filter { $0 == key }
            .map { _ in self.wrappedValue }
            .eraseToAnyPublisher()
    }
}

/**
 * Extension to implement export-related functionality.
 */
public extension AppSettingsManager {
    /// Returns the user's preferred export format
    var preferredExportFormat: ExportFormat {
        get { getValue(for: .defaultExportFormat, defaultValue: .enex) }
        set { setValue(newValue, for: .defaultExportFormat) }
    }
    
    /// Returns the user's preferred export location
    var exportLocation: URL? {
        get {
            let path = getValue(for: .exportLocation, defaultValue: "")
            return path.isEmpty ? nil : URL(fileURLWithPath: path)
        }
        set {
            setValue(newValue?.path ?? "", for: .exportLocation)
        }
    }
    
    /// Returns whether attachments should be included in exports
    var shouldIncludeAttachments: Bool {
        get { getValue(for: .includeAttachments, defaultValue: true) }
        set { setValue(newValue, for: .includeAttachments) }
    }
    
    /// Returns whether metadata should be included in exports
    var shouldIncludeMetadata: Bool {
        get { getValue(for: .includeMetadata, defaultValue: true) }
        set { setValue(newValue, for: .includeMetadata) }
    }
}

/**
 * Extension to implement UI-related functionality.
 */
public extension AppSettingsManager {
    /// Returns the preferred sort order for notes
    var noteSortOrder: NoteSortOrder {
        get { getValue(for: .defaultSortOrder, defaultValue: .dateUpdatedNewest) }
        set { setValue(newValue, for: .defaultSortOrder) }
    }
    
    /// Returns whether the preview pane should be shown
    var showPreviewPane: Bool {
        get { getValue(for: .showPreviewPane, defaultValue: true) }
        set { setValue(newValue, for: .showPreviewPane) }
    }
    
    /// Returns whether dark mode should be used
    var useDarkMode: Bool {
        get { getValue(for: .useDarkMode, defaultValue: true) }
        set { setValue(newValue, for: .useDarkMode) }
    }
}

