#!/usr/bin/env python3
"""
DEPRECATED: Legacy CLI Interface

This CLI interface is deprecated in favor of the Electron desktop application.
Please use the Electron app in xtraqtivApp/electron/ for the full experience.

To run the Electron app:
1. Start FastAPI backend: uvicorn xtraqtivCore.api:app --reload --port 8000
2. Start Electron frontend: cd xtraqtivApp/electron && npm start
"""

from xtraqtivCore.auth import get_stored_credentials, create_evernote_client
from xtraqtivCore.fetch import list_notebooks
import os


def main():
    print("⚠️  DEPRECATED: This CLI interface is no longer maintained.")
    print("Please use the Electron desktop application instead.")
    print("\nTo run the modern app:")
    print("1. Start backend: uvicorn xtraqtivCore.api:app --reload --port 8000")
    print("2. Start frontend: cd xtraqtivApp/electron && npm start")
    print("\nContinuing with legacy CLI...")
    print("\nWelcome to the Evernote Extractor (Python)")
    
    # Try to get stored credentials
    access_token = get_stored_credentials()
    
    if not access_token:
        print("No stored credentials found. Please authenticate using the Electron app first.")
        return
    
    try:
        # Create client with stored credentials
        consumer_key = os.getenv("EVERNOTE_CONSUMER_KEY", "extraqtive-1974")
        consumer_secret = os.getenv("EVERNOTE_CONSUMER_SECRET", "5a0d3a222a8c18e60dbf381a9d90b6e1745b24287f323d6da3eabe47")
        sandbox = os.getenv("SANDBOX", "false").lower() == "true"
        
        client = create_evernote_client(consumer_key, consumer_secret, access_token, sandbox)
        
        print("\nFetching your notebooks...")
        notebooks = list_notebooks(client)
        
        if notebooks:
            print("\nYour Notebooks:")
            for nb in notebooks:
                note_count = nb.get('noteCount', 'Unknown')
                default_marker = " (Default)" if nb.get('defaultNotebook', False) else ""
                print(f"- {nb['name']} ({note_count} notes){default_marker}")
                print(f"  GUID: {nb['guid']}")
        else:
            print("No notebooks found or failed to fetch.")
            
    except Exception as e:
        print(f"Error: {e}")
        print("Please re-authenticate using the Electron app.")


if __name__ == "__main__":
    main()