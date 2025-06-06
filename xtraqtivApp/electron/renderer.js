// API base URL
const API_BASE = 'http://localhost:8000';

// DOM elements
const loginBtn = document.getElementById('loginBtn');
const logoutBtn = document.getElementById('logoutBtn');
const exportBtn = document.getElementById('exportBtn');
const fullExportBtn = document.getElementById('fullExportBtn');
const statusDiv = document.getElementById('status');
const loginSection = document.getElementById('loginSection');
const loggedInSection = document.getElementById('loggedInSection');
const exportSection = document.getElementById('exportSection');
const progressInfo = document.getElementById('progressInfo');

// New DOM elements for notebook selection
const notebookSelectionArea = document.getElementById('notebookSelectionArea');
const notebookListLoading = document.getElementById('notebookListLoading');
const notebookListError = document.getElementById('notebookListError');
const notebookListContainer = document.getElementById('notebookListContainer');
const refreshNotebooksBtn = document.getElementById('refreshNotebooksBtn');

// New DOM elements for notes display
const notesArea = document.getElementById('notesArea');
const notesListLoading = document.getElementById('notesListLoading');
const notesListError = document.getElementById('notesListError');
const notesListContainer = document.getElementById('notesListContainer');
const noteContentArea = document.getElementById('noteContentArea');
const selectedNoteTitle = document.getElementById('selectedNoteTitle');
const noteContentLoading = document.getElementById('noteContentLoading');
const noteContentError = document.getElementById('noteContentError');
const noteContentDisplay = document.getElementById('noteContentDisplay');

// New DOM elements for attachments
const noteAttachmentsArea = document.getElementById('noteAttachmentsArea');
const noteAttachmentsList = document.getElementById('noteAttachmentsList');
const noAttachmentsMsg = document.getElementById('noAttachmentsMsg');

// New DOM elements for Markdown display
const noteMarkdownArea = document.getElementById('noteMarkdownArea');
const selectedNoteMarkdownTitle = document.getElementById('selectedNoteMarkdownTitle');
const noteMarkdownLoading = document.getElementById('noteMarkdownLoading');
const noteMarkdownError = document.getElementById('noteMarkdownError');
const noteMarkdownDisplay = document.getElementById('noteMarkdownDisplay');
const viewAsMarkdownBtn = document.getElementById('viewAsMarkdownBtn');

// New DOM elements for HTML display
const noteHtmlArea = document.getElementById('noteHtmlArea');
const selectedNoteHtmlTitle = document.getElementById('selectedNoteHtmlTitle');
const noteHtmlLoading = document.getElementById('noteHtmlLoading');
const noteHtmlError = document.getElementById('noteHtmlError');
const noteHtmlDisplay = document.getElementById('noteHtmlDisplay');
const viewAsHtmlBtn = document.getElementById('viewAsHtmlBtn');

// State
let isAuthenticated = false;
let statusCheckInterval = null;
let cachedNotebooks = null;
let cachedNotesMetadata = null;
let currentNoteData = null;
let pendingOAuthDetails = null; // To store { token, secret } from /auth/start
let exchangeTokenAttempts = 0;
const MAX_EXCHANGE_ATTEMPTS = 15; // Approx 30 seconds if poll interval is 2s

// Utility functions
function showStatus(message, type = 'info') {
    statusDiv.textContent = message;
    statusDiv.className = `status ${type}`;
    statusDiv.classList.remove('hidden');
}

function hideStatus() {
    statusDiv.classList.add('hidden');
}

function updateUI() {
    if (isAuthenticated) {
        loginSection.classList.add('hidden');
        loggedInSection.classList.remove('hidden');
        fetchAndDisplayNotebooks();
    } else {
        loginSection.classList.remove('hidden');
        loggedInSection.classList.add('hidden');
        exportSection.classList.add('hidden');
        notebookSelectionArea.classList.add('hidden'); 
        if (notebookListContainer) notebookListContainer.innerHTML = ''; 
        notesArea.classList.add('hidden');
        noteContentArea.classList.add('hidden');
        if (noteAttachmentsArea) noteAttachmentsArea.classList.add('hidden');
        if (noteMarkdownArea) noteMarkdownArea.classList.add('hidden');
        if (noteHtmlArea) noteHtmlArea.classList.add('hidden');
        cachedNotebooks = null;
        cachedNotesMetadata = null;
        currentNoteData = null;
    }
}

// API functions
async function checkAuthStatus(calledFromPolling = false) {
    try {
        const response = await fetch(`${API_BASE}/auth/status`);
        const data = await response.json();
        const previouslyAuthenticated = isAuthenticated;
        isAuthenticated = data.authenticated;

        if (isAuthenticated && !previouslyAuthenticated) {
            showStatus('Connected to Evernote', 'success');
            pendingOAuthDetails = null; 
            exchangeTokenAttempts = 0;
            if (statusCheckInterval) stopStatusPolling(); // Stop if auth succeeded
            loginBtn.disabled = false;
        } else if (!isAuthenticated && previouslyAuthenticated) {
            // Was authenticated, but now is not (e.g. token expired, logout from elsewhere)
            hideStatus();
        } else if (!isAuthenticated && !pendingOAuthDetails && !calledFromPolling) {
            // Not authenticated, no pending login, and not in a polling loop that will retry exchange
            hideStatus();
        }
        // Always update UI based on the latest isAuthenticated state
        updateUI(); 

    } catch (error) {
        console.error('Error checking auth status:', error);
        showStatus('Error connecting to backend. Make sure the Python server is running.', 'error');
        isAuthenticated = false;
        updateUI();
    }
}

async function startLogin() {
    try {
        showStatus('Starting authentication...', 'info');
        loginBtn.disabled = true;
        pendingOAuthDetails = null; 
        exchangeTokenAttempts = 0;
        
        const response = await fetch(`${API_BASE}/auth/start`, { method: 'POST' });
        if (!response.ok) {
            const errorData = await response.json().catch(() => ({ detail: 'Failed to initiate authentication.'}));
            throw new Error(errorData.detail || `Error ${response.status}`);
        }
        const serverData = await response.json(); 
        console.log('[DEBUG] /auth/start response data:', serverData);
        
        if (serverData.auth_url && serverData.oauth_token && serverData.oauth_token_secret) {
            pendingOAuthDetails = { token: serverData.oauth_token, secret: serverData.oauth_token_secret };
            showStatus('Opening browser for Evernote authorization...', 'info');
            
            const originalAuthUrl = serverData.auth_url; 
            console.log('[DEBUG] URL to open (original from Evernote):', originalAuthUrl);

            if (window.electronAPI && window.electronAPI.openExternal) {
                await window.electronAPI.openExternal(originalAuthUrl);
            } else {
                console.warn('[DEBUG] electronAPI.openExternal not found, using window.open as fallback.');
                window.open(originalAuthUrl, '_blank'); 
            }
            
            startStatusPolling();
        } else {
            console.error('[DEBUG] /auth/start response missing required data:', serverData);
            throw new Error('No auth URL or necessary tokens received from /auth/start');
        }
    } catch (error) {
        console.error('[DEBUG] Login error in startLogin catch block:', error.message);
        showStatus(`Login failed: ${error.message}. Please try again.`, 'error');
        loginBtn.disabled = false;
        pendingOAuthDetails = null; 
    }
}

async function attemptTokenExchange() {
    if (!pendingOAuthDetails) {
        console.warn('[DEBUG] attemptTokenExchange called without pendingOAuthDetails.');
        return false; 
    }

    exchangeTokenAttempts++;
    console.log(`[DEBUG] Attempting token exchange (${exchangeTokenAttempts}/${MAX_EXCHANGE_ATTEMPTS})...`);
    showStatus(`Attempting to finalize Evernote connection (attempt ${exchangeTokenAttempts}/${MAX_EXCHANGE_ATTEMPTS})...`, 'info');

    try {
        const response = await fetch(`${API_BASE}/auth/exchange-token`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                oauth_token: pendingOAuthDetails.token,
                oauth_token_secret: pendingOAuthDetails.secret,
            }),
        });

        if (response.ok) {
            const exchangeData = await response.json();
            if (exchangeData.status === 'authenticated') {
                console.log('[DEBUG] Token exchange successful!');
                // `isAuthenticated` will be set true by the subsequent checkAuthStatus call
                // `pendingOAuthDetails` will be cleared by `checkAuthStatus` when it finds `isAuthenticated` is true
                // `exchangeTokenAttempts` will be reset by `checkAuthStatus` for the same reason
                await checkAuthStatus(); // This should confirm isAuthenticated and update UI
                // stopStatusPolling() will be called by checkAuthStatus if isAuthenticated is true
                return true; 
            }
        } else {
            const errorData = await response.json().catch(() => ({ detail: 'Token exchange attempt failed with status: ' + response.status }));
            console.warn('[DEBUG] Token exchange attempt failed (HTTP error):', errorData.detail);
            if (response.status === 404) { 
                showStatus(`Waiting for Evernote authorization in browser... (attempt ${exchangeTokenAttempts}/${MAX_EXCHANGE_ATTEMPTS})`, 'info');
            } else {
                 showStatus(`Failed to finalize connection (attempt ${exchangeTokenAttempts}/${MAX_EXCHANGE_ATTEMPTS}): ${errorData.detail}. Will retry.`, 'error');
            }
        }
    } catch (error) {
        console.error('[DEBUG] Network error during token exchange attempt:', error);
        showStatus(`Network error during connection finalization (attempt ${exchangeTokenAttempts}/${MAX_EXCHANGE_ATTEMPTS}). Will retry.`, 'error');
    }
    return false; 
}

function startStatusPolling() {
    if (statusCheckInterval) {
        clearInterval(statusCheckInterval);
        statusCheckInterval = null;
    }
    console.log('[DEBUG] Starting status polling / token exchange attempts.');
    
    if (pendingOAuthDetails) {
        // Initial message when login process starts
        showStatus('Waiting for Evernote authorization in browser... Once authorized, return to this app.', 'info');
    }
    // For subsequent calls or startup check, status will be handled by checkAuthStatus or attemptTokenExchange

    statusCheckInterval = setInterval(async () => {
        if (isAuthenticated) { 
            // This should have been caught by checkAuthStatus which would stop the poll
            // But as a safeguard:
            console.log('[DEBUG] Polling: Already authenticated. Stopping poll explicitly.');
            stopStatusPolling();
            loginBtn.disabled = false; 
            return;
        }

        if (pendingOAuthDetails) {
            if (exchangeTokenAttempts < MAX_EXCHANGE_ATTEMPTS) {
                const exchangeSuccess = await attemptTokenExchange();
                if (exchangeSuccess) {
                    // attemptTokenExchange calls checkAuthStatus, which will stop polling if auth is confirmed
                    return; 
                }
            } else {
                console.error('[DEBUG] Max token exchange attempts reached. Clearing pending auth.');
                showStatus('Failed to finalize Evernote connection after multiple attempts. Please try logging in again.', 'error');
                pendingOAuthDetails = null;
                exchangeTokenAttempts = 0;
                stopStatusPolling();
                loginBtn.disabled = false;
                await checkAuthStatus(); // Final UI update
                return;
            }
        } else {
            // No pending OAuth operation, just check status (e.g., for an existing session on startup)
            console.log('[DEBUG] Polling: No pending OAuth, just checking status regularly.');
            await checkAuthStatus(true);
            // If checkAuthStatus finds isAuthenticated is true, it will stop the polling itself.
        }
    }, 2000); 
}

function stopStatusPolling() {
    if (statusCheckInterval) {
        console.log('[DEBUG] Stopping status polling.');
        clearInterval(statusCheckInterval);
        statusCheckInterval = null;
    }
}

async function logout() {
    try {
        showStatus('Logging out...', 'info');
        logoutBtn.disabled = true;
        stopStatusPolling(); 
        pendingOAuthDetails = null; 
        exchangeTokenAttempts = 0;
        
        await fetch(`${API_BASE}/auth/logout`, { method: 'POST' });
        // No need to check response.ok, outcome will be reflected by /auth/status
    } catch (error) {
        console.error('Logout error (ignoring, will rely on auth status):', error);
    } finally {
        isAuthenticated = false; // Optimistically set local state
        updateUI(); // Reflect local state immediately
        hideStatus();
        logoutBtn.disabled = false;
        loginBtn.disabled = false; 
        await checkAuthStatus(); // Verify with backend and update UI finally
    }
}

// New function to render notebooks from data (cache or fetch)
function renderNotebooks(notebooks) {
    notebookListContainer.innerHTML = '';
    if (notebooks.length === 0) {
        notebookListContainer.innerHTML = '<p>No notebooks found.</p>';
        return;
    }
    notebooks.forEach(notebook => {
        const div = document.createElement('div');
        div.classList.add('notebook-item');
        const checkbox = document.createElement('input');
        checkbox.type = 'checkbox';
        checkbox.id = `nb-${notebook.guid}`;
        checkbox.value = notebook.guid;
        checkbox.name = 'notebook';
        if (notebook.defaultNotebook) checkbox.checked = true;
        const label = document.createElement('label');
        label.htmlFor = `nb-${notebook.guid}`;
        label.textContent = notebook.name;
        if (notebook.stack) label.textContent += ` (Stack: ${notebook.stack})`;
        div.appendChild(checkbox);
        div.appendChild(label);
        notebookListContainer.appendChild(div);
    });
}

async function fetchAndDisplayNotebooks(forceRefresh = false) {
    notesArea.classList.add('hidden');
    noteContentArea.classList.add('hidden');
    if (noteAttachmentsArea) noteAttachmentsArea.classList.add('hidden');
    cachedNotesMetadata = null;
    if (notesListContainer) notesListContainer.innerHTML = '';
    if (noteContentDisplay) noteContentDisplay.textContent = '';
    if (noteAttachmentsList) noteAttachmentsList.innerHTML = '';
    if (noteMarkdownArea) noteMarkdownArea.classList.add('hidden');
    if (noteHtmlArea) noteHtmlArea.classList.add('hidden');
    currentNoteData = null;

    notebookSelectionArea.classList.remove('hidden');
    notebookListError.classList.add('hidden');

    if (!forceRefresh && cachedNotebooks) {
        console.log("Using cached notebooks");
        renderNotebooks(cachedNotebooks);
        notebookListLoading.classList.add('hidden');
        return;
    }

    console.log(forceRefresh ? "Forcing refresh of notebooks" : "Fetching notebooks");
    notebookListLoading.classList.remove('hidden');
    
    try {
        const response = await fetch(`${API_BASE}/notebooks`);
        if (!response.ok) {
            if (response.status === 401) { // Unauthorized
                showStatus('Authentication required. Please login again.', 'error');
                isAuthenticated = false; // Update local auth state
                updateUI();
                stopStatusPolling(); // Stop any polling
                pendingOAuthDetails = null; // Clear any pending auth attempt
                return; // Stop further processing
            }
            const errorData = await response.json().catch(() => ({ detail: 'Failed to retrieve notebooks.' }));
            throw new Error(errorData.detail || `Error ${response.status}`);
        }
        const notebooks = await response.json();
        cachedNotebooks = notebooks;
        notebookListLoading.classList.add('hidden');
        renderNotebooks(notebooks);
    } catch (error) {
        console.error('Error fetching notebooks:', error);
        notebookListLoading.classList.add('hidden');
        let displayMessage = error.message;
        if (error.name === 'TypeError' && error.message.toLowerCase().includes('failed to fetch')) {
            displayMessage = "Cannot connect to the application server to fetch notebooks. Please ensure it is running and check your network connection.";
        }
        notebookListError.textContent = `Error: ${displayMessage}`;
        notebookListError.classList.remove('hidden');
        cachedNotebooks = null;
    }
}

async function startExport() { // This is "Load Notes Metadata"
    const selectedNotebookGuids = Array.from(document.querySelectorAll('input[name="notebook"]:checked'))
                                .map(cb => cb.value);

    if (selectedNotebookGuids.length === 0) {
        showStatus('Please select at least one notebook.', 'error');
        return;
    }

    showStatus(`Fetching notes for ${selectedNotebookGuids.length} notebook(s)...`, 'info');
    exportSection.classList.remove('hidden');
    progressInfo.textContent = 'Requesting note metadata from server... Please wait.';
    
    exportBtn.disabled = true;
    notesArea.classList.remove('hidden');
    notesListLoading.classList.remove('hidden');
    notesListError.classList.add('hidden');
    notesListContainer.innerHTML = '';
    noteContentArea.classList.add('hidden'); 
    if (noteAttachmentsArea) noteAttachmentsArea.classList.add('hidden'); 
    if (noteMarkdownArea) noteMarkdownArea.classList.add('hidden');
    if (noteHtmlArea) noteHtmlArea.classList.add('hidden');
    currentNoteData = null;
    cachedNotesMetadata = null;

    try {
        const response = await fetch(`${API_BASE}/notes/fetch-metadata`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(selectedNotebookGuids),
        });

        if (!response.ok) {
             if (response.status === 401) { // Unauthorized
                showStatus('Authentication required. Please login again.', 'error');
                isAuthenticated = false; updateUI(); stopStatusPolling(); pendingOAuthDetails = null;
                exportBtn.disabled = false; notesListLoading.classList.add('hidden');
                return;
            }
            const errorData = await response.json().catch(() => ({ detail: 'Failed to retrieve notes metadata.' }));
            throw new Error(errorData.detail || `Error ${response.status}`);
        }
        progressInfo.textContent = 'Processing received note metadata...';
        const notesMetadata = await response.json();
        
        notesListLoading.classList.add('hidden');
        exportBtn.disabled = false;

        if (notesMetadata.length === 0) {
            notesListContainer.innerHTML = '<p>No notes found in selected notebook(s).</p>';
            showStatus('No notes found.', 'info');
            progressInfo.textContent = 'No notes found in the selected notebook(s).';
        } else {
            notesMetadata.forEach(noteMeta => {
                const noteDiv = document.createElement('div');
                noteDiv.textContent = noteMeta.title;
                noteDiv.style.padding = '5px';
                noteDiv.style.cursor = 'pointer';
                noteDiv.style.borderBottom = '1px solid #eee';
                noteDiv.addEventListener('mouseover', () => noteDiv.style.backgroundColor = '#f0f0f0');
                noteDiv.addEventListener('mouseout', () => noteDiv.style.backgroundColor = 'transparent');
                noteDiv.addEventListener('click', () => fetchAndDisplayNoteContent(noteMeta.guid, noteMeta.title));
                notesListContainer.appendChild(noteDiv);
            });
            showStatus(`Found ${notesMetadata.length} notes. Click a title to view content.`, 'success');
            progressInfo.textContent = `Successfully loaded ${notesMetadata.length} note headers.`;
            cachedNotesMetadata = notesMetadata;
        }

    } catch (error) {
        console.error('Error fetching notes metadata:', error);
        notesListLoading.classList.add('hidden');
        let displayMessage = error.message;
        if (error.name === 'TypeError' && error.message.toLowerCase().includes('failed to fetch')) {
            displayMessage = "Cannot connect to the application server to fetch notes. Please ensure it is running and check your network connection.";
        }
        
        notesListError.textContent = `Error: ${displayMessage}`;
        notesListError.classList.remove('hidden');
        exportBtn.disabled = false;
        showStatus('Error fetching notes.', 'error');
        progressInfo.textContent = `Error fetching notes: ${displayMessage}`;
        cachedNotesMetadata = null;
    }
}

async function fetchAndDisplayNoteContent(noteGuid, noteTitle) {
    noteContentArea.classList.remove('hidden');
    selectedNoteTitle.textContent = `Note Content: ${noteTitle}`;
    noteContentLoading.classList.remove('hidden');
    noteContentError.classList.add('hidden');
    noteContentDisplay.textContent = '';
    viewAsMarkdownBtn.classList.add('hidden');
    viewAsHtmlBtn.classList.add('hidden');
    noteMarkdownArea.classList.add('hidden');
    noteHtmlArea.classList.add('hidden');
    currentNoteData = null;

    noteAttachmentsArea.classList.remove('hidden');
    noteAttachmentsList.innerHTML = '';
    noAttachmentsMsg.classList.add('hidden');

    try {
        const response = await fetch(`${API_BASE}/notes/${noteGuid}/content`);
        if (!response.ok) {
            if (response.status === 401) { // Unauthorized
                showStatus('Authentication required. Please login again.', 'error');
                isAuthenticated = false; updateUI(); stopStatusPolling(); pendingOAuthDetails = null;
                noteContentLoading.classList.add('hidden');
                return;
            }
            const errorData = await response.json().catch(() => ({ detail: 'Failed to retrieve note content.' }));
            throw new Error(errorData.detail || `Error ${response.status}`);
        }
        const note = await response.json();
        currentNoteData = note;

        noteContentLoading.classList.add('hidden');
        noteContentDisplay.textContent = note.content; 
        selectedNoteTitle.textContent = `Note Content: ${note.title}`;
        viewAsMarkdownBtn.classList.remove('hidden');
        viewAsHtmlBtn.classList.remove('hidden');

        if (note.attachments && note.attachments.length > 0) {
            note.attachments.forEach(att => {
                const li = document.createElement('li');
                
                const a = document.createElement('a');
                a.href = `${API_BASE}/attachments/${att.guid}/data`;
                a.download = att.fileName || 'attachment'; 

                let displayText = att.fileName || 'Untitled Attachment';
                displayText += ` (${att.mime}, ${att.size ? (att.size / 1024).toFixed(2) + ' KB' : 'size N/A'})`;
                if (att.width && att.height) {
                    displayText += ` [${att.width}x${att.height}]`;
                }
                a.textContent = displayText;
                
                li.appendChild(a);
                li.style.padding = '3px 0';
                noteAttachmentsList.appendChild(li);
            });
        } else {
            noAttachmentsMsg.classList.remove('hidden');
        }

    } catch (error) {
        console.error(`Error fetching content for note ${noteGuid}:`, error);
        noteContentLoading.classList.add('hidden');
        let displayMessage = error.message;
        if (error.name === 'TypeError' && error.message.toLowerCase().includes('failed to fetch')) {
            displayMessage = `Cannot connect to the server to fetch content for note \"${noteTitle}\". Please ensure it is running and check your network connection.`;
        }

        noteContentError.textContent = `Error: ${displayMessage}`;
        noteContentError.classList.remove('hidden');
        noteAttachmentsArea.classList.add('hidden'); 
        viewAsMarkdownBtn.classList.add('hidden');
        viewAsHtmlBtn.classList.add('hidden');
        currentNoteData = null;
    }
}

async function displayNoteAsMarkdown() {
    if (!currentNoteData || !currentNoteData.content) {
        showStatus("No note content available to convert.", "error");
        return;
    }

    noteMarkdownArea.classList.remove('hidden');
    selectedNoteMarkdownTitle.textContent = `Note Content (Markdown): ${currentNoteData.title}`;
    noteMarkdownLoading.classList.remove('hidden');
    noteMarkdownError.classList.add('hidden');
    noteMarkdownDisplay.textContent = '';

    try {
        const response = await fetch(`${API_BASE}/notes/convert`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ 
                enml_content: currentNoteData.content,
                target_format: 'markdown' 
            }),
        });

        if (!response.ok) {
            if (response.status === 401) { // Unauthorized
                showStatus('Authentication required. Please login again.', 'error');
                isAuthenticated = false; updateUI(); stopStatusPolling(); pendingOAuthDetails = null;
                noteMarkdownLoading.classList.add('hidden');
                return;
            }
            const errorData = await response.json().catch(() => ({ detail: 'Failed to convert note to Markdown.' }));
            throw new Error(errorData.detail || `Error ${response.status}`);
        }

        const conversionResult = await response.json();
        noteMarkdownLoading.classList.add('hidden');
        noteMarkdownDisplay.textContent = conversionResult.converted_content;

    } catch (error) {
        console.error('Error converting note to Markdown:', error);
        noteMarkdownLoading.classList.add('hidden');
        let displayMessage = error.message;
        if (error.name === 'TypeError' && error.message.toLowerCase().includes('failed to fetch')) {
            displayMessage = "Cannot connect to the server to convert note. Please ensure it is running.";
        }
        noteMarkdownError.textContent = `Error: ${displayMessage}`;
        noteMarkdownError.classList.remove('hidden');
    }
}

async function displayNoteAsHtml() {
    if (!currentNoteData || !currentNoteData.content) {
        showStatus("No note content available to convert.", "error");
        return;
    }

    noteHtmlArea.classList.remove('hidden');
    selectedNoteHtmlTitle.textContent = `Note Content (HTML): ${currentNoteData.title}`;
    noteHtmlLoading.classList.remove('hidden');
    noteHtmlError.classList.add('hidden');
    noteHtmlDisplay.textContent = '';

    try {
        const response = await fetch(`${API_BASE}/notes/convert`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ 
                enml_content: currentNoteData.content,
                target_format: 'html' 
            }),
        });

        if (!response.ok) {
             if (response.status === 401) { // Unauthorized
                showStatus('Authentication required. Please login again.', 'error');
                isAuthenticated = false; updateUI(); stopStatusPolling(); pendingOAuthDetails = null;
                noteHtmlLoading.classList.add('hidden');
                return;
            }
            const errorData = await response.json().catch(() => ({ detail: 'Failed to convert note to HTML.' }));
            throw new Error(errorData.detail || `Error ${response.status}`);
        }

        const conversionResult = await response.json();
        noteHtmlLoading.classList.add('hidden');
        noteHtmlDisplay.textContent = conversionResult.converted_content;

    } catch (error) {
        console.error('Error converting note to HTML:', error);
        noteHtmlLoading.classList.add('hidden');
        let displayMessage = error.message;
        if (error.name === 'TypeError' && error.message.toLowerCase().includes('failed to fetch')) {
            displayMessage = "Cannot connect to the server to convert note to HTML. Please ensure it is running.";
        }
        noteHtmlError.textContent = `Error: ${displayMessage}`;
        noteHtmlError.classList.remove('hidden');
    }
}

async function startFullExportSimulated() {
    const selectedNotebookGuids = Array.from(document.querySelectorAll('input[name="notebook"]:checked'))
                                .map(cb => cb.value);

    if (selectedNotebookGuids.length === 0) {
        showStatus('Please select at least one notebook for the full export.', 'error');
        return;
    }

    const targetFormat = 'markdown'; 

    showStatus(`Starting full export for ${selectedNotebookGuids.length} notebook(s) to ${targetFormat}...`, 'info');
    if(progressInfo) progressInfo.textContent = "Initiating export process... This may take a while. Check server logs for detailed progress.";
    if(exportSection) exportSection.classList.remove('hidden'); 
    
    fullExportBtn.disabled = true;
    exportBtn.disabled = true; 

    try {
        const response = await fetch(`${API_BASE}/export/notebooks`, { // Endpoint was renamed to perform_actual_export; assuming /export/notebooks is current
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                notebook_guids: selectedNotebookGuids,
                target_format: targetFormat,
            }),
        });

        const result = await response.json();

        if (!response.ok) {
            if (response.status === 401) { // Unauthorized
                showStatus('Authentication required. Please login again.', 'error');
                isAuthenticated = false; updateUI(); stopStatusPolling(); pendingOAuthDetails = null;
                fullExportBtn.disabled = false; exportBtn.disabled = false;
                return;
            }
            throw new Error(result.detail || `Export failed with status ${response.status}`);
        }

        showStatus(result.message || 'Export process finished.', 'success');
        if(progressInfo) progressInfo.textContent = result.message || "Export finished. Check server logs for output location.";

    } catch (error) {
        console.error('Full export error:', error);
        let displayMessage = error.message;
        if (error.name === 'TypeError' && error.message.toLowerCase().includes('failed to fetch')) {
            displayMessage = "Cannot connect to the application server to start export. Please ensure it is running.";
        }
        showStatus(`Export failed: ${displayMessage}`, 'error');
        if(progressInfo) progressInfo.textContent = `Export error: ${displayMessage}`;
    } finally {
        fullExportBtn.disabled = false;
        exportBtn.disabled = false;
    }
}

// Event listeners
loginBtn.addEventListener('click', startLogin);
logoutBtn.addEventListener('click', logout);
exportBtn.addEventListener('click', startExport); // "Load Notes Metadata"
fullExportBtn.addEventListener('click', startFullExportSimulated); // "Full Export (Simulated)" -> now "Full Export"
refreshNotebooksBtn.addEventListener('click', () => fetchAndDisplayNotebooks(true));
viewAsMarkdownBtn.addEventListener('click', displayNoteAsMarkdown);
viewAsHtmlBtn.addEventListener('click', displayNoteAsHtml);

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    checkAuthStatus(); // Check auth on load
});
