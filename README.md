# 🗂️ Evernote Extractor

> **Cross-platform desktop application for unlimited Evernote data export with Obsidian integration**

A modern Python + Electron application that overcomes Evernote's 100-item export limit, providing unlimited data extraction with conversion to Markdown format for seamless integration with Obsidian, Zotero, and other note-taking systems.

## ✨ Features

### 🔐 **Authentication**
- Secure OAuth 1.0a flow with Evernote API
- Cross-platform credential storage (Windows Credential Manager, macOS Keychain, Linux Secret Service)
- Production Evernote API integration

### 📱 **Desktop Application**
- Modern Electron-based UI
- Cross-platform support (Windows, macOS, Linux)
- Secure communication between frontend and backend
- System browser integration for OAuth flow

### 🚀 **Data Export** *(Coming Soon)*
- Unlimited note and notebook export
- ENML → Markdown conversion
- Attachment preservation
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
- Verify Evernote API credentials

### Cross-Platform Notes
- **Linux**: Requires `python3-keyring` for credential storage
- **Windows**: Uses Windows Credential Manager automatically
- **macOS**: Uses Keychain access automatically

---

*Built with ❤️ for seamless note migration and unlimited data freedom*
