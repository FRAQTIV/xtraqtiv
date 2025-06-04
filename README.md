# 🗂️ Evernote Extractor

> **Cross-platform desktop application for unlimited Evernote data export with Obsidian integration**

A modern Python + Electron application that overcomes Evernote's 100-item export limit, providing unlimited data extraction with conversion to Markdown format for seamless integration with Obsidian, Zotero, and other note-taking systems.

## ✨ Features

### 🔐 **Authentication**
- Secure OAuth 1.0a flow with Evernote API
- Cross-platform credential storage (Windows Credential Manager, macOS Keychain, Linux Secret Service)
- Production Evernote API integration

### 📱 **Desktop Application**
- Modern Electron-based UI with beautiful gradients and animations
- Cross-platform support (Windows, macOS, Linux)
- Secure communication between frontend and backend
- System browser integration for OAuth flow

### 🚀 **Data Export** *(Phase 2 - Coming Soon)*
- Unlimited note and notebook export
- ENML → Markdown conversion
- Attachment preservation and download
- Obsidian-compatible output format
- Zotero integration support

<<<<<<< HEAD
## 🏗️ Architecture
=======
- macOS 13.0 or later (with SwiftUI support)
- Internet connection (for initial Evernote authentication only)
- Evernote account (Free, Premium, or Business)
- Approximately 200MB of disk space for the application

## Installation

1. Download the latest release from the [Releases page](https://github.com/FRAQTIV/xtraqtiv/releases)
2. Open the downloaded DMG file
3. Drag xtraqtiv to your Applications folder
4. Launch xtraqtiv from your Applications folder or Launchpad
5. Authenticate with your Evernote account when prompted

## Development Setup

xtraqtiv is built using a modular architecture:

### Project Structure

- **xtraqtivApp**: The main macOS application built with SwiftUI
- **xtraqtivCore**: Core library providing Evernote API integration and data processing functionality

### Building the Project

1. Clone the repository:
   ```bash
   git clone https://github.com/FRAQTIV/xtraqtiv.git
   cd xtraqtiv
   ```

2. Open the Xcode project:
   ```bash
   open xtraqtiv.xcodeproj
   ```

3. Select the appropriate scheme (xtraqtivApp) and run target (My Mac)

4. Build and run the project using Cmd+R or the play button

### Development Guidelines

- Use SwiftUI for all new UI components
- Follow MVVM architecture pattern
- Write unit tests for all core functionality
- Ensure backward compatibility with macOS 13.0+
## Basic Usage

### Initial Setup

1. Launch xtraqtiv
2. Click "Connect to Evernote" and complete the authentication process
3. Wait for your notebooks to sync (initial sync time depends on your library size)

### Exporting Notes

1. Select notebooks or notes to export from the left sidebar
2. Choose your preferred export format (ENEX, HTML, PDF, etc.)
3. Specify destination folder and export options
4. Click "Export" to begin the process
5. View export progress and any warnings/errors

### Managing Local Data

1. Use the "Local Library" tab to view exported content
2. Apply tags, filters, or custom organization to your local archive
3. Perform batch operations (rename, reorganize, tag) as needed
4. Use the search functionality to locate specific content quickly

## Privacy & Security

xtraqtiv is designed with your data privacy and security as a top priority:

- **Local Processing**: All data processing happens locally on your device
- **No External Servers**: Your notes and credentials are never transmitted to any external servers
- **Evernote API Compliance**: We strictly adhere to Evernote's developer guidelines
- **Authentication Security**: Secure OAuth authentication with no password storage
- **Control Your Data**: You maintain complete control over what is exported and where it's stored

## Support the Project

If xtraqtiv is helpful, consider supporting its development through Buy Me a Coffee. Your support helps maintain and improve the project!

[![Buy Me A Coffee](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/fraqtiv)

## Support

For issues, feature requests, or general feedback:

- Submit an issue on our [GitHub repository](https://github.com/FRAQTIV/xtraqtiv/issues)
- Contact our support team at support@fraqtiv.com
- Consider supporting the project through [Buy Me a Coffee](https://www.buymeacoffee.com/fraqtiv)
## License
[License information to be added]
>>>>>>> origin/main

```
┌─────────────────┐    HTTP/REST    ┌──────────────────┐
│                 │ ←─────────────→ │                  │
│  Electron App   │                 │  FastAPI Backend │
│  (Frontend UI)  │                 │  (Python Server) │
│                 │                 │                  │
└─────────────────┘                 └──────────────────┘
                                              │
                                              │ OAuth 1.0a
                                              ▼
                                    ┌──────────────────┐
                                    │   Evernote API   │
                                    │  (Production)    │
                                    └──────────────────┘
```

## 🚀 Quick Start

### Prerequisites
- **Python 3.8+** with pip
- **Node.js 16+** with npm
- **Evernote account** with API access

### 1. Backend Setup (FastAPI)

```bash
# Create and activate virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install Python dependencies
pip install -r requirements.txt

# Start the FastAPI server
uvicorn xtraqtivCore.api:app --reload --port 8000
```

### 2. Frontend Setup (Electron)

```bash
# Navigate to Electron app
cd xtraqtivApp/electron

# Install Node.js dependencies
npm install

# Start the Electron app
npm start
```

### 3. Usage

1. **Launch** both FastAPI backend and Electron frontend
2. **Click "Login to Evernote"** in the app
3. **Complete OAuth** in your system browser
4. **Export your data** (Phase 2 - Coming Soon)

## 📁 Project Structure

```
xtraqtiv/
├── 📁 xtraqtivCore/          # Python Backend (FastAPI)
│   ├── api.py               # FastAPI endpoints
│   ├── auth.py              # Evernote OAuth authentication
│   ├── fetch.py             # Data fetching utilities
│   └── __init__.py
├── 📁 xtraqtivApp/           # Frontend Applications
│   ├── 📁 electron/         # Electron Desktop App
│   │   ├── main.js          # Electron main process
│   │   ├── renderer.js      # UI logic
│   │   ├── preload.js       # Secure bridge script
│   │   ├── index.html       # Main UI
│   │   └── package.json     # Node.js dependencies
│   └── main.py              # Legacy CLI (deprecated)
├── 📁 tasks/                # Project Documentation
│   ├── PRD.md              # Product Requirements
│   └── task-breakdown.md   # Development Tasks
├── requirements.txt         # Python dependencies
├── .gitignore              # Git ignore rules
└── README.md               # This file
```

## 🛠️ Development

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/auth/start` | GET | Initiate OAuth flow |
| `/auth/callback` | GET | Handle OAuth callback |
| `/auth/status` | GET | Check authentication status |
| `/auth/logout` | POST | Clear stored credentials |

### Environment Variables

```bash
# Optional: Create .env file for custom configuration
EVERNOTE_CONSUMER_KEY=your_key_here
EVERNOTE_CONSUMER_SECRET=your_secret_here
SANDBOX=false  # Use production environment
```

## 🗺️ Roadmap

- ✅ **Phase 1**: Authentication & Architecture *(Complete)*
- 🚧 **Phase 2**: Note Fetching & Export *(In Progress)*
- 📋 **Phase 3**: ENML → Markdown Conversion
- 🔗 **Phase 4**: Obsidian/Zotero Integration
- 🎨 **Phase 5**: Advanced UI & Batch Processing

## 🤝 Contributing

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔧 Troubleshooting

### Authentication Issues
- Ensure FastAPI backend is running on port 8000
- Check that your system browser can access `localhost:8000`
- Verify Evernote API credentials are configured

### Cross-Platform Notes
- **Linux**: Requires `python3-keyring` for credential storage
- **Windows**: Uses Windows Credential Manager automatically
- **macOS**: Uses Keychain access automatically

### Development Setup
```bash
# Install development dependencies
pip install -r requirements.txt
cd xtraqtivApp/electron && npm install

# Run in development mode
# Terminal 1:
uvicorn xtraqtivCore.api:app --reload --port 8000

# Terminal 2:
cd xtraqtivApp/electron && npm run dev
```

## 🌟 What's New in v1.0

### 🚀 **Complete Architecture Migration**
- **BREAKING CHANGE**: Migrated from Swift/macOS to Python + Electron
- **Cross-platform**: Now supports Windows, macOS, and Linux
- **Modern UI**: Beautiful Electron interface with gradient design
- **Unlimited Export**: Architecture prepared for unlimited data extraction

### 🔐 **Enhanced Security**
- OAuth 1.0a compliance with Evernote production API
- Secure credential storage using system keychains
- Context isolation in Electron for maximum security

### 📊 **Professional Development**
- Comprehensive documentation and PRD
- Clean project structure and development workflow
- Professional .gitignore and dependency management

---

*Built with ❤️ for seamless note migration and unlimited data freedom*
