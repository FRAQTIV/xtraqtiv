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

## 🏗️ Architecture

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
