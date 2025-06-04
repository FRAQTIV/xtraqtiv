# xtraqtiv Application Flow Sequence Diagram

This diagram illustrates the core interaction flow within the xtraqtiv application, showing how data moves between the user, application layers, Evernote services, and local storage.

```mermaid
sequenceDiagram
    participant User
    participant xtraqtivApp as xtraqtivApp (UI Layer)
    participant xtraqtivCore as xtraqtivCore (Business Logic)
    participant EvernoteSDK
    participant EvernoteAPI as Evernote API
    participant LocalStorage

    %% App Launch
    User->>xtraqtivApp: Launch application
    xtraqtivApp->>xtraqtivCore: Initialize core components
    xtraqtivCore-->>xtraqtivApp: Initialization complete
    xtraqtivApp-->>User: Display welcome screen
    
    %% Authentication Flow
    User->>xtraqtivApp: Request Evernote login
    xtraqtivApp->>xtraqtivCore: Forward authentication request
    xtraqtivCore->>EvernoteSDK: Initiate OAuth flow
    EvernoteSDK->>EvernoteAPI: Request authentication URL
    EvernoteAPI-->>EvernoteSDK: Return authentication URL
    EvernoteSDK-->>xtraqtivCore: Forward authentication URL
    xtraqtivCore-->>xtraqtivApp: Present authentication URL
    xtraqtivApp->>User: Display login page
    User->>xtraqtivApp: Enter credentials
    xtraqtivApp->>EvernoteAPI: Submit credentials
    EvernoteAPI-->>EvernoteSDK: Return OAuth token
    EvernoteSDK-->>xtraqtivCore: Forward OAuth token
    xtraqtivCore->>LocalStorage: Store authentication token
    xtraqtivCore-->>xtraqtivApp: Authentication successful
    xtraqtivApp-->>User: Display success message
    
    %% Note Synchronization
    User->>xtraqtivApp: Request note synchronization
    xtraqtivApp->>xtraqtivCore: Forward sync request
    xtraqtivCore->>LocalStorage: Retrieve authentication token
    LocalStorage-->>xtraqtivCore: Return token
    xtraqtivCore->>EvernoteSDK: Request notebook list
    EvernoteSDK->>EvernoteAPI: Get notebooks
    EvernoteAPI-->>EvernoteSDK: Return notebook data
    EvernoteSDK-->>xtraqtivCore: Forward notebook list
    xtraqtivCore-->>xtraqtivApp: Display notebook selection
    xtraqtivApp->>User: Show notebooks for selection
    User->>xtraqtivApp: Select notebooks to sync
    xtraqtivApp->>xtraqtivCore: Forward notebook selection
    xtraqtivCore->>EvernoteSDK: Request notes from selected notebooks
    EvernoteSDK->>EvernoteAPI: Get notes with metadata
    EvernoteAPI-->>EvernoteSDK: Return note data
    EvernoteSDK-->>xtraqtivCore: Forward note data
    xtraqtivCore->>LocalStorage: Store note metadata and content
    xtraqtivCore-->>xtraqtivApp: Sync progress updates
    xtraqtivApp-->>User: Display sync progress
    xtraqtivCore-->>xtraqtivApp: Sync complete
    xtraqtivApp-->>User: Display sync completion
    
    %% Data Extraction Process
    User->>xtraqtivApp: Request data extraction
    xtraqtivApp->>xtraqtivCore: Forward extraction request
    xtraqtivCore->>LocalStorage: Retrieve stored notes
    LocalStorage-->>xtraqtivCore: Return note data
    xtraqtivCore->>xtraqtivCore: Parse ENML content
    xtraqtivCore->>xtraqtivCore: Extract structured data
    xtraqtivCore->>xtraqtivCore: Process attachments
    xtraqtivCore->>LocalStorage: Store processed data
    xtraqtivCore-->>xtraqtivApp: Extraction progress updates
    xtraqtivApp-->>User: Display extraction progress
    xtraqtivCore-->>xtraqtivApp: Extraction complete
    xtraqtivApp-->>User: Show extracted data preview
    
    %% Export Functionality
    User->>xtraqtivApp: Select export format
    xtraqtivApp-->>User: Display export options
    User->>xtraqtivApp: Configure export settings
    xtraqtivApp->>xtraqtivCore: Forward export request with settings
    xtraqtivCore->>LocalStorage: Retrieve processed data
    LocalStorage-->>xtraqtivCore: Return data for export
    xtraqtivCore->>xtraqtivCore: Format data according to export settings
    xtraqtivCore-->>xtraqtivApp: Export processing updates
    xtraqtivApp-->>User: Show export progress
    xtraqtivCore-->>xtraqtivApp: Export data ready
    xtraqtivApp->>User: Prompt for save location
    User->>xtraqtivApp: Select save location
    xtraqtivApp->>xtraqtivCore: Forward save location
    xtraqtivCore->>LocalStorage: Write export file to disk
    LocalStorage-->>xtraqtivCore: File write complete
    xtraqtivCore-->>xtraqtivApp: Export complete
    xtraqtivApp-->>User: Show export success message
```

This sequence diagram outlines the five main processes within the xtraqtiv application:

1. **App Launch**: Initial startup sequence and component initialization
2. **Authentication Flow**: OAuth-based authentication with Evernote's service
3. **Note Synchronization**: Retrieving notebooks and notes from Evernote 
4. **Data Extraction**: Parsing and structuring note content for analysis
5. **Export Functionality**: Converting extracted data to user-selected formats

The diagram shows the interactions between the UI layer (xtraqtivApp), business logic layer (xtraqtivCore), external services (Evernote SDK and API), and local storage mechanisms.

