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

// State
let isAuthenticated = false;
let statusCheckInterval = null;

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
        fetchAndDisplayNotebooks(); // Fetch notebooks when authenticated
    } else {
        loginSection.classList.remove('hidden');
        loggedInSection.classList.add('hidden');
        exportSection.classList.add('hidden');
        notebookSelectionArea.classList.add('hidden'); // Hide notebook section on logout
        notebookListContainer.innerHTML = ''; // Clear notebooks on logout
    }
}

// API functions
async function checkAuthStatus() {
    try {
        const response = await fetch(`${API_BASE}/auth/status`);
        const data = await response.json();
        isAuthenticated = data.authenticated;
        updateUI(); // This will call fetchAndDisplayNotebooks if authenticated
        
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
            updateUI(); // This will hide notebook section and clear list
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
    }, 2000); // Check every 2 seconds
}

function stopStatusPolling() {
    if (statusCheckInterval) {
        clearInterval(statusCheckInterval);
        statusCheckInterval = null;
    }
}

// New function to fetch and display notebooks
async function fetchAndDisplayNotebooks() {
    notebookSelectionArea.classList.remove('hidden');
    notebookListLoading.classList.remove('hidden');
    notebookListError.classList.add('hidden');
    notebookListContainer.innerHTML = ''; // Clear previous list

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

        notebookListLoading.classList.add('hidden');

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
            if (notebook.defaultNotebook) {
                checkbox.checked = true; // Pre-select default notebook
            }

            const label = document.createElement('label');
            label.htmlFor = `nb-${notebook.guid}`;
            label.textContent = notebook.name;
            if (notebook.stack) {
                label.textContent += ` (Stack: ${notebook.stack})`;
            }

            div.appendChild(checkbox);
            div.appendChild(label);
            notebookListContainer.appendChild(div);
        });

    } catch (error) {
        console.error('Error fetching notebooks:', error);
        notebookListLoading.classList.add('hidden');
        notebookListError.textContent = `Error fetching notebooks: ${error.message}`;
        notebookListError.classList.remove('hidden');
    }
}

async function startExport() {
    const selectedNotebooks = Array.from(document.querySelectorAll('input[name="notebook"]:checked'))
                                .map(cb => cb.value);

    if (selectedNotebooks.length === 0) {
        showStatus('Please select at least one notebook to export.', 'error');
        return;
    }

    try {
        showStatus(`Starting export for ${selectedNotebooks.length} notebook(s)...`, 'info');
        exportBtn.disabled = true;
        exportSection.classList.remove('hidden');
        progressInfo.textContent = `Selected notebooks: ${selectedNotebooks.join(', ')}. Preparing export...`;
        
        // TODO: Implement actual export functionality using selectedNotebooks
        console.log('Selected notebook GUIDs for export:', selectedNotebooks);
        showStatus('Export functionality with selected notebooks coming soon!', 'info');
        
    } catch (error) {
        console.error('Export error:', error);
        showStatus('Export failed. Please try again.', 'error');
    } finally {
        // Keep exportBtn disabled for now, or re-enable if it's a one-off attempt
        // exportBtn.disabled = false; 
    }
}

// Event listeners
loginBtn.addEventListener('click', startLogin);
logoutBtn.addEventListener('click', logout);
exportBtn.addEventListener('click', startExport);

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    checkAuthStatus();
}); 