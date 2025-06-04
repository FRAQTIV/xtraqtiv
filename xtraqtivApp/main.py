#!/usr/bin/env python3
"""
DEPRECATED: Legacy CLI Interface

This CLI interface is deprecated in favor of the Electron desktop application.
Please use the Electron app in xtraqtivApp/electron/ for the full experience.

To run the Electron app:
1. Start FastAPI backend: uvicorn xtraqtivCore.api:app --reload --port 8000
2. Start Electron frontend: cd xtraqtivApp/electron && npm start
"""

from xtraqtivCore.auth import authenticate
from xtraqtivCore.fetch import list_notebooks


def main():
    print("⚠️  DEPRECATED: This CLI interface is no longer maintained.")
    print("Please use the Electron desktop application instead.")
    print("\nTo run the modern app:")
    print("1. Start backend: uvicorn xtraqtivCore.api:app --reload --port 8000")
    print("2. Start frontend: cd xtraqtivApp/electron && npm start")
    print("\nContinuing with legacy CLI...")
    print("\nWelcome to the Evernote Extractor (Python)")
    
    client = authenticate()
    if not client:
        print("Authentication failed.")
        return
    
    print("\nFetching your notebooks...")
    notebooks = list_notebooks(client)
    if notebooks:
        print("\nYour Notebooks:")
        for nb in notebooks:
            print(f"- {nb['name']} (GUID: {nb['guid']})")
    else:
        print("No notebooks found or failed to fetch.")


if __name__ == "__main__":
    main() 