// API base URL
const API_BASE = 'http://localhost:8000';

let cachedNotebooks = null;
let cachedNotesMetadata = null;
let pendingOAuthDetails = null; // Used to hold details between auth steps

// Test connection immediately on load
window.addEventListener('DOMContentLoaded', () => {
    // Initial connection test
    fetch(`${API_BASE}/`).then(res => res.json())
        .then(data => console.log('✅ Backend connection successful:', data))
        .catch(error => console.error('❌ Backend connection failed:', error));

    // Attach event listeners
    document.getElementById('loginButton').addEventListener('click', startAuth);
    document.getElementById('logoutButton').addEventListener('click', logout);
    document.getElementById('loadNotesButton').addEventListener('click', () => {
        console.log('Load Notes Metadata button clicked!');
        startExport();
    });
    document.getElementById('startExportButton').addEventListener('click', startFullExport);
    document.getElementById('refreshNotebooksButton').addEventListener('click', () => {
        console.log('Clearing notebook cache and re-fetching.');
        cachedNotebooks = null; // Invalidate cache
        fetchNotebooks(); // Re-fetch notebooks
    });

    // Initial check of auth status
    checkAuthStatus();
});

async function startAuth() {
    try {
        showStatus('Starting authentication...', 'info');
        console.log('Attempting to connect to:', `${API_BASE}/auth/start`);
        
        const response = await fetch(`${API_BASE}/auth/start`);
        console.log('Response status:', response.status);
        console.log('Response ok:', response.ok);
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const data = await response.json();
        console.log('Response data:', data);
        
        if (data.auth_url && data.oauth_token && data.oauth_token_secret) {
            // Store the OAuth details for later token exchange
            pendingOAuthDetails = {
                oauth_token: data.oauth_token,
                oauth_token_secret: data.oauth_token_secret
            };
            
            showStatus('Opening browser for authentication...', 'info');
            await window.electronAPI.openExternal(data.auth_url);
            
            // Start polling for auth status
            startAuthPolling();
        } else {
            showStatus('Failed to start authentication', 'error');
        }
    } catch (error) {
        console.error('Detailed error starting auth:', error);
        console.error('Error name:', error.name);
        console.error('Error message:', error.message);
        showStatus(`Error: ${error.message || 'Failed to fetch'}`, 'error');
    }
} 

// --- UI Element Getters ---
const getFetchedNotesList = () => document.getElementById('fetchedNotesList');
const getNotesListStatus = () => document.getElementById('notesListStatus');

// --- Main Application Logic ---

async function startExport() {
    console.log("Starting metadata export...");
    const selectedNotebooks = getSelectedNotebooks();
    console.log("Selected notebook GUIDs:", selectedNotebooks);
    console.log("Number of selected notebooks:", selectedNotebooks.length);
    if (selectedNotebooks.length === 0) {
        showProgress("Please select at least one notebook.", "error");
        return;
    }

    showProgress("Loading notes metadata...", "info");
    const notesArea = document.getElementById('fetchedNotesArea');
    const notesList = getFetchedNotesList();
    const notesListStatus = getNotesListStatus();
    
    // Clear previous results
    notesList.innerHTML = '';
    
    try {
        const response = await fetchWithAuth(`${API_BASE}/notes/fetch-metadata`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(selectedNotebooks)
        });

        if (!response.ok) {
            const errorData = await response.json().catch(() => ({ detail: 'Could not parse error response.' }));
            throw new Error(errorData.detail || `HTTP error! status: ${response.status}`);
        }

        const notes = await response.json();
        cachedNotesMetadata = notes; // Cache the metadata

        if (notes.length > 0) {
            notes.forEach(note => {
                const li = document.createElement('li');
                li.textContent = note.title;
                li.dataset.guid = note.guid; // Store guid for later use
                notesList.appendChild(li);
            });
            notesArea.style.display = 'block';
            notesListStatus.textContent = `Found ${notes.length} notes. Click 'Full Export' to begin exporting all notes.`;
            showProgress(`Successfully loaded ${notes.length} note headers.`, 'success');
        } else {
            notesArea.style.display = 'block';
            notesListStatus.textContent = 'No notes found in the selected notebook(s).';
            showProgress("No notes found.", "warning");
        }
    } catch (error) {
        console.error("Error loading notes metadata:", error);
        showProgress(`Error: ${error.message}`, "error");
        notesArea.style.display = 'block';
        notesListStatus.textContent = `Error loading notes: ${error.message}`;
    }
}

async function startFullExport() {
    console.log("Starting full export process...");
    showProgress("Starting full export...", "info");

    const selectedNotebooks = getSelectedNotebooks();
    if (selectedNotebooks.length === 0) {
        showProgress("Cannot start export: No notebooks selected.", "error");
        return;
    }

    try {
        const response = await fetchWithAuth(`${API_BASE}/export/notebooks`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                notebook_guids: selectedNotebooks,
                target_format: "markdown" // Or make this configurable later
            })
        });

        const result = await response.json();

        if (!response.ok) {
            throw new Error(result.detail || `HTTP Error: ${response.status}`);
        }

        console.log("Export response:", result);
        showProgress(result.message, "success");

    } catch (error) {
        console.error("Error during full export:", error);
        showProgress(`Export failed: ${error.message}`, "error");
    }
}

// --- Authentication and Utility Functions ---

async function checkAuthStatus() {
    try {
        const response = await fetch(`${API_BASE}/auth/status`);
        const data = await response.json();
        
        if (data.authenticated) {
            showStatus('Successfully connected to Evernote!', 'success');
            document.getElementById('loginButton').style.display = 'none';
            document.getElementById('logoutButton').style.display = 'inline-block';
            document.getElementById('notebookSelectionArea').style.display = 'block';
            document.getElementById('loadNotesButton').style.display = 'inline-block';
            document.getElementById('startExportButton').style.display = 'inline-block';
            
            // Auto-load notebooks if not cached
            if (!cachedNotebooks) {
                await fetchNotebooks();
            }
        } else {
            showStatus('Not authenticated. Please login to Evernote.', 'info');
            document.getElementById('loginButton').style.display = 'inline-block';
            document.getElementById('logoutButton').style.display = 'none';
            updateUI();
        }
    } catch (error) {
        console.error('Error checking auth status:', error);
        showStatus('Error checking authentication status', 'error');
        document.getElementById('loginButton').style.display = 'inline-block';
        document.getElementById('logoutButton').style.display = 'none';
        updateUI();
    }
}

async function startAuthPolling() {
    const maxAttempts = 30;
    let attempts = 0;
    
    const pollInterval = setInterval(async () => {
        attempts++;
        
        if (pendingOAuthDetails) {
            console.log(`Auth polling attempt ${attempts}: Trying token exchange...`);
            try {
                await attemptTokenExchange();
                clearInterval(pollInterval);
                return;
            } catch (error) {
                console.log('Token exchange not ready yet, continuing to poll...');
            }
        }
        
        if (attempts >= maxAttempts) {
            clearInterval(pollInterval);
            showStatus('Authentication timeout. Please try again.', 'error');
            console.log('Auth polling stopped after max attempts');
        }
    }, 2000);
}

async function attemptTokenExchange() {
    if (!pendingOAuthDetails) {
        throw new Error('No pending OAuth details');
    }
    
    try {
        const response = await fetch(`${API_BASE}/auth/exchange-token`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(pendingOAuthDetails)
        });
        
        if (response.ok) {
            console.log('Token exchange successful!');
            pendingOAuthDetails = null;
            await checkAuthStatus();
        } else {
            throw new Error(`Token exchange failed: ${response.status}`);
        }
    } catch (error) {
        console.error('Token exchange error:', error);
        throw error;
    }
}

async function logout() {
    try {
        await fetch(`${API_BASE}/auth/logout`, { method: 'POST' });
        showStatus('Logged out successfully', 'info');
        updateUI();
    } catch (error) {
        console.error('Error during logout:', error);
        showStatus('Error during logout', 'error');
    }
}

async function fetchNotebooks() {
    if (cachedNotebooks) {
        displayNotebooks(cachedNotebooks);
        return;
    }
    
    try {
        const response = await fetchWithAuth(`${API_BASE}/notebooks`);
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const notebooks = await response.json();
        cachedNotebooks = notebooks;
        displayNotebooks(notebooks);
    } catch (error) {
        console.error('Error fetching notebooks:', error);
        showStatus(`Error fetching notebooks: ${error.message}`, 'error');
    }
}

function displayNotebooks(notebooks) {
    const notebookList = document.getElementById('notebookList');
    notebookList.innerHTML = '';
    
    notebooks.forEach(notebook => {
        const div = document.createElement('div');
        div.className = 'notebook-item';
        
        const checkbox = document.createElement('input');
        checkbox.type = 'checkbox';
        checkbox.id = `notebook-${notebook.guid}`;
        checkbox.value = notebook.guid;
        
        const label = document.createElement('label');
        label.htmlFor = `notebook-${notebook.guid}`;
        label.textContent = notebook.name;
        if (notebook.defaultNotebook) {
            label.textContent += ' (Default)';
            checkbox.checked = true;
        }
        
        div.appendChild(checkbox);
        div.appendChild(label);
        notebookList.appendChild(div);
    });
}

function getSelectedNotebooks() {
    const checkboxes = document.querySelectorAll('#notebookList input[type="checkbox"]:checked');
    return Array.from(checkboxes).map(cb => cb.value);
}

function updateUI() {
    // Clear caches
    cachedNotebooks = null;
    cachedNotesMetadata = null;
    pendingOAuthDetails = null;
    
    // Hide UI elements
    document.getElementById('notebookSelectionArea').style.display = 'none';
    document.getElementById('loadNotesButton').style.display = 'none';
    document.getElementById('startExportButton').style.display = 'none';
    document.getElementById('fetchedNotesArea').style.display = 'none';
    
    // Clear content
    document.getElementById('notebookList').innerHTML = '';
    document.getElementById('fetchedNotesList').innerHTML = '';
    document.getElementById('progressInfo').innerHTML = '';
}

async function fetchWithAuth(url, options = {}) {
    // For now, the backend handles authentication via keyring
    // In a production app, we might pass tokens in headers
    return fetch(url, options);
}

function showStatus(message, type) {
    const authStatus = document.getElementById('authStatus');
    authStatus.textContent = message;
    authStatus.className = `status-${type}`;
}

function showProgress(message, type) {
    const progressInfo = document.getElementById('progressInfo');
    progressInfo.textContent = message;
    progressInfo.className = `progress-${type}`;
}



