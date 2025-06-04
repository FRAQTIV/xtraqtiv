# Product Requirements Document: Evernote Extractor Initial Functionality

## 1. Overview

**Product Name:** Evernote Extractor  
**Version:** 1.0 (Initial Release)  
**Goal:** Enable unlimited extraction and export of Evernote data with cross-platform compatibility and integration with Obsidian/Zotero.

## 2. Background & Problem Statement

The current Swift/macOS implementation has limitations:
- Platform restriction to macOS only
- Limited data extraction capabilities (100-item limit)
- No integration with modern note-taking systems
- Maintenance challenges with Swift/macOS dependencies

## 3. Solution

Migrate to Python + Electron architecture providing:
- Cross-platform compatibility (Windows, macOS, Linux)
- Unlimited data export capabilities
- ENML → Markdown conversion
- Direct integration with Obsidian and Zotero
- Modern, maintainable codebase

## 4. Core Requirements

### 4.1 Authentication
- OAuth integration with Evernote API
- Secure token storage using system keychain
- Production environment support
- Session management

### 4.2 Data Fetching
- Unlimited export capability (beyond 100-item limit)
- Support for all note types and attachments
- Batch processing for large datasets
- Progress tracking and error handling

### 4.3 Conversion & Export
- ENML to Markdown conversion
- Obsidian-compatible format
- Zotero integration support
- File organization and naming

### 4.4 User Interface
- Electron-based cross-platform UI
- Simple authentication flow
- Progress monitoring
- Export configuration options

### 4.5 Security & Privacy
- Local credential storage
- Secure API communication
- Data privacy compliance
- No cloud storage of user data

## 5. Technical Architecture

### Backend (Python/FastAPI)
- FastAPI for API endpoints
- Evernote SDK integration
- Keyring for credential management
- ENML processing libraries

### Frontend (Electron)
- Cross-platform desktop application
- API communication with backend
- Progress monitoring interface
- Export configuration UI

## 6. Success Metrics

- Successful authentication with Evernote
- Export of >100 items without limitations
- Cross-platform deployment working
- Obsidian-compatible output generated
- Secure credential storage implemented

## 7. Timeline

**Phase 1: Foundation (Current)**
- Backend API with authentication ✓
- Basic Electron frontend ✓
- OAuth flow implementation ✓
- Secure token storage ✓

**Phase 2: Core Functionality**
- Data fetching implementation
- ENML to Markdown conversion
- Batch processing capabilities
- Progress tracking

**Phase 3: Enhancement**
- Obsidian integration
- Zotero support
- Advanced export options
- UI/UX improvements

## 8. Dependencies

- Evernote API v3
- Python 3.8+
- Electron framework
- FastAPI
- System keychain services 