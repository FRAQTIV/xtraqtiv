const { contextBridge, ipcRenderer } = require('electron');

// In newer Electron versions, it's recommended to use IPC for shell operations
// instead of directly accessing shell from the preload script
contextBridge.exposeInMainWorld('electronAPI', {
  openExternal: async (url) => {
    try {
      console.log('[Preload DEBUG] Sending openExternal request to main process with URL:', url);
      // Use ipcRenderer to communicate with the main process
      await ipcRenderer.invoke('open-external', url);
      console.log('[Preload DEBUG] Successfully called open-external for:', url);
      return true; // Indicate success
    } catch (error) {
      console.error('[Preload DEBUG] Error during open-external IPC call:', error);
      throw new Error(`Failed to open external URL: ${error.message}`);
    }
  }
});
