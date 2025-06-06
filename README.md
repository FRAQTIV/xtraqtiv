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

### 🚀 **Data Viewing & Conversion** (Phase 2 Core)
- **Notebook Listing**: View all your Evernote notebooks.
- **Note Metadata**: Fetch and display titles, dates, and tags for notes in selected notebooks.
- **Note Content Viewing**: Display ENML content of individual notes.
- **Attachment Handling**: List attachments for notes and download them.
- **Format Conversion Viewing**:
    - View note content converted from ENML to Markdown.
    - View note content converted from ENML to HTML.
- **Simulated Full Export**: Trigger a simulated full export process (logs to server, no file output yet).

### 📦 **Full Data Export** *(Partially Implemented, In Progress)*
- Unlimited note and notebook export *(Backend simulation complete, file output pending)*
- Attachment preservation during export *(Backend simulation complete, file output pending)*
- Obsidian-compatible output format *(Planned for Phase 3)*
- Zotero integration support *(Planned for Phase 4)*

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
- **Evernote account** with API access (ensure your Evernote API key is configured in `.env` or environment variables)

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

1.  **Launch** both FastAPI backend and Electron frontend.
2.  **Click "Login to Evernote"** in the app.
3.  **Complete OAuth** in your system browser.
4.  Once authenticated:
    *   The app will list your Evernote notebooks.
    *   Select desired notebooks.
    *   Click "Load Notes Metadata" to see notes from selected notebooks.
    *   Click on a note title to view its ENML content and list of attachments.
    *   Click "View as Markdown" or "View as HTML" to see the note content in different formats.
    *   Download attachments by clicking on their names.
    *   Click "Full Export (Simulated)" to trigger a mock export process (details in server logs).
5.  **Actual data export to files** is targeted for Phase 3.

## 📁 Project Structure

```
xtraqtiv/
├── 📁 xtraqtivCore/          # Python Backend (FastAPI)
│   ├── api.py               # FastAPI endpoints
│   ├── auth.py              # Evernote OAuth authentication (deprecated, logic merged into api.py)
│   ├── fetch.py             # Data fetching utilities (partially used, some logic in api.py)
│   ├── models.py            # Pydantic models for API requests/responses
│   ├── utils.py             # Utility functions (e.g., ENML conversion)
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
| `/auth/start` | POST | Initiate OAuth flow (returns auth URL and request tokens) |
| `/auth/callback` | GET | Handle OAuth callback, exchange for access token |
| `/auth/status` | GET | Check if user is currently authenticated |
| `/auth/logout` | POST | Clear stored credentials and log out |
| `/notebooks` | GET | List all user notebooks |
| `/notes/fetch-metadata` | POST | Fetch metadata for notes in specified notebooks (body: `["guid1", "guid2"]`) |
| `/notes/{note_guid}/content` | GET | Fetch full content (ENML, attachments metadata) for a specific note |
| `/attachments/{attachment_guid}/data` | GET | Download binary data for a specific attachment |
| `/notes/convert` | POST | Convert ENML content to Markdown or HTML (body: `{"enml_content": "...", "target_format": "markdown|html"}`) |
| `/export/notebooks` | POST | **Simulate** full export of selected notebooks (body: `{"notebook_guids": [], "target_format": "markdown|html"}`) |

### Environment Variables

```bash
# Optional: Create .env file for custom configuration
EVERNOTE_CONSUMER_KEY=your_key_here
EVERNOTE_CONSUMER_SECRET=your_secret_here
SANDBOX=false  # Use production environment
```

## 🗺️ Roadmap

- ✅ **Phase 1**: Authentication & Architecture *(Complete)*
- ✅ **Phase 2**: Core Data Viewing & Conversion *(Largely Complete)*
    - Notebook listing & selection.
    - Note metadata and content (ENML) viewing.
    - Attachment listing and download.
    - ENML to Markdown/HTML conversion (viewing).
    - Simulated full export process.
- 🚧 **Phase 3**: Full Export Implementation & ENML Processing
    - Actual file-based export (Markdown, HTML).
    - Robust ENML parsing and cleaning.
    - Attachment file saving and linking.
    - User-configurable export options (path, formats).
- 🔗 **Phase 4**: Advanced Features & Integrations
    - Obsidian integration (vault compatibility, metadata).
    - Zotero integration (research notes).
- 🎨 **Phase 5**: UI/UX Enhancements & Batch Processing
    - Advanced UI for export management.
    - Batch selection tools, filters.
    - Export history.

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
