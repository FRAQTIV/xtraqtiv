# Product Requirements Document: Evernote Extractor

## 1. Overview

**Product Name:** Evernote Extractor  
**Version:** 1.0 (Migration Release)  
**Goal:** Cross-platform desktop application for unlimited Evernote data export with Obsidian integration

## 2. Background & Problem Statement

The original Swift/macOS implementation had critical limitations:
- **Platform restriction** to macOS only
- **Export limitations** (100-item restriction)
- **No modern integrations** with popular note-taking systems
- **Maintenance challenges** with native macOS dependencies

## 3. Solution

**New Architecture: Python + Electron**
- **Backend:** FastAPI with OAuth 1.0a authentication
- **Frontend:** Cross-platform Electron desktop application
- **Security:** Secure credential storage using system keychains
- **Scalability:** Architecture prepared for unlimited data export

## 4. Target Users

- **Evernote users** seeking to migrate to modern note-taking systems
- **Obsidian users** wanting to import Evernote data
- **Researchers and writers** needing bulk data export capabilities
- **Cross-platform users** (Windows, macOS, Linux)

## 5. Core Features

### Phase 1: Authentication & Architecture ✅ COMPLETE
- OAuth 1.0a authentication with Evernote API
- Secure cross-platform credential storage
- Modern Electron desktop interface
- FastAPI backend with RESTful endpoints

### Phase 2: Data Extraction (Next)
- Unlimited notebook and note fetching
- Attachment preservation and download
- Progress tracking and error handling
- Batch processing capabilities

### Phase 3: Format Conversion
- ENML → Markdown conversion
- Metadata preservation (tags, dates, locations)
- File organization and naming strategies
- Custom export templates

### Phase 4: Integration
- Obsidian vault-ready output format
- Zotero integration for research notes
- Custom export configurations
- Automated folder structures

## 6. Technical Requirements

### Performance
- Handle 10,000+ notes efficiently
- Progress indicators for long operations
- Background processing capabilities
- Memory-efficient streaming

### Security
- OAuth 1.0a compliance
- Secure credential storage (Windows Credential Manager, macOS Keychain, Linux Secret Service)
- No credential logging or transmission
- Production API environment

### Compatibility
- **Windows:** 10+ (64-bit)
- **macOS:** 10.14+ (Mojave and later)
- **Linux:** Ubuntu 18.04+, other major distributions
- **Python:** 3.8+ backend requirements
- **Node.js:** 16+ for Electron frontend

## 7. User Experience

### Installation
1. Download platform-specific installer
2. One-click installation process
3. Automatic dependency handling

### Authentication
1. Click "Login to Evernote" button
2. System browser opens for OAuth
3. Automatic detection of successful authentication
4. Secure token storage for future sessions

### Export Process
1. Select notebooks/notes for export
2. Choose output format and destination
3. Monitor real-time progress
4. Review export summary and any errors

## 8. Success Metrics

- **Adoption:** 1000+ successful installations in first quarter
- **Reliability:** 99%+ successful authentication rate
- **Performance:** Export 1000 notes in under 5 minutes
- **User Satisfaction:** 4.5+ star rating on user feedback

## 9. Development Phases

### Phase 1: Foundation ✅ COMPLETE
- Authentication system
- Basic UI framework
- Cross-platform architecture
- Documentation and setup

### Phase 2: Core Functionality (Next)
- Note fetching implementation
- Progress tracking
- Error handling
- Basic export capabilities

### Phase 3: Advanced Features
- Format conversion (ENML → Markdown)
- Attachment handling
- Metadata preservation
- Export customization

### Phase 4: Integrations
- Obsidian compatibility
- Zotero integration
- Advanced export options
- User preferences

## 10. Risk Mitigation

### Technical Risks
- **Evernote API changes:** Use stable production API, implement version checking
- **Rate limiting:** Implement respectful request throttling
- **Large data handling:** Stream processing, memory management

### User Experience Risks
- **Authentication complexity:** Streamlined OAuth flow with clear instructions
- **Cross-platform issues:** Extensive testing on all target platforms
- **Data integrity:** Validation checks and backup mechanisms

## 11. Future Considerations

- **Multi-account support** for users with multiple Evernote accounts
- **Selective sync** for ongoing synchronization
- **Plugin system** for custom export formats
- **Cloud storage integration** for direct export to services