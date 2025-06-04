// API base URL
const API_BASE = 'http://localhost:8000';

// Test connection immediately on load
window.addEventListener('DOMContentLoaded', () => {
    console.log('🔧 Testing connection to backend...');
    fetch(`${API_BASE}/`)
        .then(response => {
            console.log('✅ Connection test successful:', response.status);
            return response.json();
        })
        .then(data => {
            console.log('✅ Backend response:', data);
        })
        .catch(error => {
            console.error('❌ Connection test failed:', error);
        });
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
        
        if (data.auth_url) {
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