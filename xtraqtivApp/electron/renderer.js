/**
 * Handles UI logic and API calls.
 */
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
const progressFill = document.getElementById('progressFill');
const progressText = document.getElementById('progressText');
const appInfo = document.getElementById('appInfo');

// New DOM elements for notebooks
const loadNotebooksBtn = document.getElementById('loadNotebooksBtn');
const notebooksSection = document.getElementById('notebooksSection');
const notebooksList = document.getElementById('notebooksList');
const notebooksStatus = document.getElementById('notebooksStatus');

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
        loginSection.style.display = 'none';
        loggedInSection.classList.add('visible');
        // Initially hide notebooks section until loaded
        // notebooksSection.classList.remove('visible'); 
    } else {
        loginSection.style.display = 'block';
        loggedInSection.classList.remove('visible');
        exportSection.classList.remove('visible');
        notebooksSection.classList.remove('visible'); // Hide notebooks if not authenticated
        notebooksList.innerHTML = ''; // Clear list on logout
    }
}

// API functions
async function checkAuthStatus() {
    try {
        const response = await fetch(`${API_BASE}/auth/status`);
        const data = await response.json();
        isAuthenticated = data.authenticated;
        return data;
    } catch (error) {
        console.error('Error checking auth status:', error);
        return { authenticated: false, error: error.message };
    }
}

async function startAuth() {
    try {
        showStatus('Starting authentication...', 'info');
        const response = await fetch(`${API_BASE}/auth/start`);
        const data = await response.json();
        
        if (data.auth_url) {
            showStatus('Opening browser for authentication...', 'info');
            await window.electronAPI.openExternal(data.auth_url);
            
            // Start polling for auth status
            startAuthPolling();
        } else {
            showStatus('Failed to start authentication', 'error');
        }
    } catch (error) {
        console.error('Error starting auth:', error);
        showStatus(`Error: ${error.message}`, 'error');
    }
}

async function logout() {
    try {
        showStatus('Logging out...', 'info');
        await fetch(`${API_BASE}/auth/logout`, { method: 'POST' });
        isAuthenticated = false;
        notebooksSection.classList.remove('visible'); // Hide notebooks on logout
        notebooksList.innerHTML = ''; // Clear list on logout
        notebooksStatus.textContent = ''; // Clear status on logout
        updateUI();
        showStatus('Logged out successfully', 'success');
        stopAuthPolling();
    } catch (error) {
        console.error('Error logging out:', error);
        showStatus(`Logout error: ${error.message}`, 'error');
    }
}

async function startExport() {
    exportSection.classList.add('visible');
    progressText.textContent = 'Export feature coming in Phase 2...';
    progressFill.style.width = '100%';
    
    // Placeholder for future export functionality
    setTimeout(() => {
        progressText.textContent = 'Export functionality will be available soon!';
    }, 2000);
}

// Auth polling
function startAuthPolling() {
    if (statusCheckInterval) return;
    
    statusCheckInterval = setInterval(async () => {
        const authData = await checkAuthStatus();
        if (authData.authenticated) {
            isAuthenticated = true;
            updateUI();
            showStatus('Authentication successful!', 'success');
            stopAuthPolling();
        }
    }, 2000);
}

function stopAuthPolling() {
    if (statusCheckInterval) {
        clearInterval(statusCheckInterval);
        statusCheckInterval = null;
    }
}

// New function to fetch and display notebooks
async function fetchAndDisplayNotebooks() {
    if (!isAuthenticated) {
        notebooksStatus.textContent = 'Please login first.';
        notebooksSection.classList.remove('visible');
        return;
    }

    notebooksSection.classList.add('visible');
    notebooksList.innerHTML = ''; // Clear previous list
    notebooksStatus.innerHTML = '<span class="spinner"></span> Loading notebooks...';

    try {
        const response = await fetch(`${API_BASE}/notebooks`);
        if (!response.ok) {
            const errorData = await response.json().catch(() => ({ detail: response.statusText }));
            throw new Error(`Failed to load notebooks: ${errorData.detail || response.statusText}`);
        }

        const notebooksData = await response.json();

        if (notebooksData.length === 0) {
            notebooksStatus.textContent = 'No notebooks found.';
        } else {
            notebooksData.forEach(nb => {
                const li = document.createElement('li');
                li.style.padding = '8px 0';
                li.style.borderBottom = '1px solid #eee';
                li.textContent = `${nb.name} (${nb.noteCount !== undefined ? nb.noteCount : 'N/A'} notes)`;
                if (nb.defaultNotebook) {
                    const defaultSpan = document.createElement('span');
                    defaultSpan.textContent = ' (Default)';
                    defaultSpan.style.color = '#7f8c8d';
                    defaultSpan.style.fontSize = '0.9em';
                    li.appendChild(defaultSpan);
                }
                notebooksList.appendChild(li);
            });
            notebooksStatus.textContent = `Found ${notebooksData.length} notebook(s).`;
        }
    } catch (error) {
        console.error('Error fetching notebooks:', error);
        notebooksStatus.textContent = `Error: ${error.message}`;
    }
}

// Event listeners
loginBtn.addEventListener('click', startAuth);
logoutBtn.addEventListener('click', logout);
exportBtn.addEventListener('click', startExport);
loadNotebooksBtn.addEventListener('click', fetchAndDisplayNotebooks); // New event listener

// Initialize app
async function initApp() {
    // Load app info
    try {
        const appData = await window.electronAPI.getAppInfo();
        appInfo.textContent = `v${appData.version} • Electron ${appData.electronVersion}`;
    } catch (error) {
        appInfo.textContent = 'Evernote Extractor v1.0.0';
    }
    
    // Check initial auth status
    showStatus('Checking authentication status...', 'info');
    const authData = await checkAuthStatus();
    
    if (authData.authenticated) {
        isAuthenticated = true;
        showStatus('Already authenticated', 'success');
    } else {
        hideStatus();
    }
    
    updateUI();
}

// Start the app when DOM is loaded
document.addEventListener('DOMContentLoaded', initApp);

// Handle app focus (check auth status when app regains focus)
window.addEventListener('focus', async () => {
    if (!isAuthenticated) {
        const authData = await checkAuthStatus();
        if (authData.authenticated) {
            isAuthenticated = true;
            updateUI();
            showStatus('Authentication detected!', 'success');
            stopAuthPolling();
        }
    }
});