# Changelog

All notable changes to the Evernote Extractor project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-14

### 🎉 Phase 1 Complete - Major Architecture Migration

**BREAKING CHANGES**: Complete migration from Swift/macOS to Python + Electron

### Added
- **FastAPI Backend**: OAuth authentication with Evernote API
- **Electron Frontend**: Modern desktop application with secure communication
- **Cross-platform Support**: Windows, macOS, Linux compatibility
- **Secure Authentication**: OAuth 1.0a flow with production Evernote API
- **Credential Management**: Cross-platform secure storage using keyring
- **Modern UI**: Clean, responsive interface for desktop
- **API Endpoints**: `/auth/start`, `/auth/callback`, `/auth/status`, `/auth/logout`
- **Comprehensive Documentation**: Professional README with architecture diagrams
- **Development Workflow**: PRD, task breakdown, and contribution guidelines

### Changed
- **Architecture**: Migrated from Swift/macOS monolithic app to Python + Electron
- **Authentication**: Replaced custom auth with secure OAuth 1.0a implementation
- **Platform Support**: Extended from macOS-only to cross-platform
- **UI Framework**: Modernized from macOS native to Electron web technologies
- **Project Structure**: Reorganized for clear separation of backend/frontend

### Removed
- **Swift/macOS Code**: All legacy Swift files and macOS-specific implementations
- **Platform Restrictions**: No longer limited to macOS ecosystem
- **Export Limitations**: Prepared architecture for unlimited export (vs 100-item limit)

### Technical Details
- **Backend**: FastAPI with uvicorn, python-keyring, evernote3 SDK
- **Frontend**: Electron with secure preload scripts and CORS support
- **Development**: Clean project structure with proper .gitignore and documentation
- **Security**: Context isolation, secure credential storage, OAuth best practices

### Migration Notes
- Legacy CLI interface deprecated but maintained for compatibility
- All existing Swift/Objective-C code removed
- New architecture supports future features: ENML→Markdown, Obsidian integration

---

## [0.x.x] - Legacy Versions

### Historical Context
Previous versions (0.1.0 - 0.x.x) were built with Swift for macOS. All legacy 
code has been migrated to the new Python + Electron architecture in v1.0.0.

For historical reference, the legacy Swift implementation included:
- macOS-native authentication
- Basic note fetching capabilities  
- Limited export functionality
- Platform-specific UI components

These features have been reimplemented and enhanced in the new architecture.

