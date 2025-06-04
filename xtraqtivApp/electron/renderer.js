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
    } else {
        loginSection.classList.remove('hidden');
        loggedInSection.classList.add('hidden');
        exportSection.classList.add('hidden');
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
    }, 2000); // Check every 2 seconds
}

function stopStatusPolling() {
    if (statusCheckInterval) {
        clearInterval(statusCheckInterval);
        statusCheckInterval = null;
    }
}

async function startExport() {
    try {
        showStatus('Starting export...', 'info');
        exportBtn.disabled = true;
        exportSection.classList.remove('hidden');
        progressInfo.textContent = 'Preparing export...';
        
        // TODO: Implement actual export functionality
        // This will be implemented in Phase 2
        showStatus('Export functionality coming in Phase 2!', 'info');
        
    } catch (error) {
        console.error('Export error:', error);
        showStatus('Export failed. Please try again.', 'error');
    } finally {
        exportBtn.disabled = false;
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