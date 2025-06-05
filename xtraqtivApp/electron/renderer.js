// API base URL
const API_BASE = 'http://localhost:8000';

// DOM elements
const loginBtn = document.getElementById('loginBtn');
const logoutBtn = document.getElementById('logoutBtn');
const exportBtn = document.getElementById('exportBtn');
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

// State
let isAuthenticated = false;
let statusCheckInterval = null;
let cachedNotebooks = null;
let cachedNotesMetadata = null;
let currentNoteData = null;

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
        cachedNotebooks = null;
        cachedNotesMetadata = null;
        currentNoteData = null;
    }
}

// API functions
async function checkAuthStatus() {
    try {
        const response = await fetch(`${API_BASE}/auth/status`);
        const data = await response.json();
        isAuthenticated = data.authenticated;
        updateUI();
        
        if (isAuthenticated) {
            showStatus('Connected to Evernote', 'success');
        } else {
            hideStatus();
        }
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
        
        const response = await fetch(`${API_BASE}/auth/start`, { method: 'POST' });
        const data = await response.json();
        
        if (data.auth_url) {
            showStatus('Opening browser for authentication...', 'info');
            
            // Open the auth URL in the system browser
            if (window.electronAPI && window.electronAPI.openExternal) {
                await window.electronAPI.openExternal(data.auth_url);
            } else {
                // Fallback for development
                window.open(data.auth_url, '_blank');
            }
            
            // Start polling for authentication completion
            startStatusPolling();
        } else {
            throw new Error('No auth URL received');
        }
    } catch (error) {
        console.error('Login error:', error);
        showStatus('Login failed. Please try again.', 'error');
        loginBtn.disabled = false;
    }
}

async function logout() {
    try {
        showStatus('Logging out...', 'info');
        logoutBtn.disabled = true;
        
        const response = await fetch(`${API_BASE}/auth/logout`, { method: 'POST' });
        
        if (response.ok) {
            isAuthenticated = false;
            updateUI();
            hideStatus();
            stopStatusPolling();
        } else {
            throw new Error('Logout failed');
        }
    } catch (error) {
        console.error('Logout error:', error);
        showStatus('Logout failed. Please try again.', 'error');
    } finally {
        logoutBtn.disabled = false;
    }
}

function startStatusPolling() {
    if (statusCheckInterval) {
        clearInterval(statusCheckInterval);
    }
    
    statusCheckInterval = setInterval(async () => {
        await checkAuthStatus();
        
        if (isAuthenticated) {
            stopStatusPolling();
            loginBtn.disabled = false;
        }
    }, 2000);
}

function stopStatusPolling() {
    if (statusCheckInterval) {
        clearInterval(statusCheckInterval);
        statusCheckInterval = null;
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
            if (response.status === 401) {
                throw new Error('Authentication expired or invalid. Please login again.');
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

async function startExport() {
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
    noteMarkdownArea.classList.add('hidden');
    currentNoteData = null;

    noteAttachmentsArea.classList.remove('hidden');
    noteAttachmentsList.innerHTML = '';
    noAttachmentsMsg.classList.add('hidden');

    try {
        const response = await fetch(`${API_BASE}/notes/${noteGuid}/content`);
        if (!response.ok) {
            const errorData = await response.json().catch(() => ({ detail: 'Failed to retrieve note content.' }));
            throw new Error(errorData.detail || `Error ${response.status}`);
        }
        const note = await response.json();
        currentNoteData = note;

        noteContentLoading.classList.add('hidden');
        noteContentDisplay.textContent = note.content; 
        selectedNoteTitle.textContent = `Note Content: ${note.title}`;
        viewAsMarkdownBtn.classList.remove('hidden');

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

// Event listeners
loginBtn.addEventListener('click', startLogin);
logoutBtn.addEventListener('click', logout);
exportBtn.addEventListener('click', startExport);
refreshNotebooksBtn.addEventListener('click', () => fetchAndDisplayNotebooks(true));
viewAsMarkdownBtn.addEventListener('click', displayNoteAsMarkdown);

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    checkAuthStatus();
}); 