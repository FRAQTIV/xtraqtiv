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
    } else {
        loginSection.style.display = 'block';
        loggedInSection.classList.remove('visible');
        exportSection.classList.remove('visible');
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

// Event listeners
loginBtn.addEventListener('click', startAuth);
logoutBtn.addEventListener('click', logout);
exportBtn.addEventListener('click', startExport);

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