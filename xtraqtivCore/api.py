"""FastAPI endpoints exposing Evernote authentication and data APIs."""

import inspect # New import
import sys # New import

# Monkey patch inspect.getargspec for compatibility with older libraries (e.g., evernote3) on Python 3.11+
if sys.version_info >= (3, 0) and not hasattr(inspect, 'getargspec'):
    inspect.getargspec = inspect.getfullargspec

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
import keyring
import os
from dotenv import load_dotenv
from .auth import get_request_token, get_access_token, create_evernote_client, get_stored_credentials
from .fetch import list_notebooks

# Load environment variables
load_dotenv()

# Log the active keyring backend
try:
    print(f"[KEYRING_DEBUG] Active keyring backend: {keyring.get_keyring().name}")
except Exception as e:
    print(f"[KEYRING_DEBUG] Error getting keyring backend: {e}")

app = FastAPI(title="Evernote Extractor API", version="1.0.0")

# Add CORS middleware for Electron app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your Electron app's origin
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuration
CONSUMER_KEY = os.getenv("EVERNOTE_CONSUMER_KEY")
CONSUMER_SECRET = os.getenv("EVERNOTE_CONSUMER_SECRET")
SANDBOX = os.getenv("SANDBOX", "false").lower() == "true"

if not CONSUMER_KEY or not CONSUMER_SECRET:
    print("ERROR: EVERNOTE_CONSUMER_KEY and EVERNOTE_CONSUMER_SECRET must be set in environment variables.")
    # You might want to raise an exception here to prevent the app from starting
    # For now, just printing, but Uvicorn might fail to start or requests will fail later
    # raise RuntimeError("Evernote API keys not configured in environment.")

@app.get("/")
async def root():
    return {"message": "Evernote Extractor API", "version": "1.0.0"}

@app.get("/auth/start")
async def start_auth():
    """Initiate OAuth authentication flow"""
    try:
        request_token, request_token_secret, auth_url = get_request_token(
            CONSUMER_KEY, CONSUMER_SECRET, sandbox=SANDBOX
        )
        
        # Store request token temporarily
        keyring.set_password("evernote_extractor", "request_token", request_token)
        keyring.set_password("evernote_extractor", "request_token_secret", request_token_secret)
        
        return {"auth_url": auth_url, "status": "success"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/auth/callback")
async def auth_callback(oauth_token: str, oauth_verifier: str):
    """Handle OAuth callback and exchange for access token"""
    try:
        print("[KEYRING_DEBUG] /auth/callback: Entered")
        # Retrieve stored request token
        request_token = keyring.get_password("evernote_extractor", "request_token")
        request_token_secret = keyring.get_password("evernote_extractor", "request_token_secret")
        print(f"[KEYRING_DEBUG] /auth/callback: Retrieved request_token: {'SET' if request_token else 'NOT_SET'}")
        
        if not request_token or not request_token_secret:
            print("[KEYRING_DEBUG] /auth/callback: Request token or secret not found")
            raise HTTPException(status_code=400, detail="Request token not found")
        
        # Exchange for access token
        access_token, access_token_secret_from_evernote = get_access_token(
            CONSUMER_KEY, CONSUMER_SECRET, request_token, request_token_secret, 
            oauth_verifier, sandbox=SANDBOX
        )
        print(f"[KEYRING_DEBUG] /auth/callback: Got access_token: {'SET' if access_token else 'NOT_SET'}")
        print(f"[KEYRING_DEBUG] /auth/callback: Got access_token_secret_from_evernote: type={type(access_token_secret_from_evernote)}, value_is_truthy={bool(access_token_secret_from_evernote)}")

        # Store access token securely
        print(f"[KEYRING_DEBUG] /auth/callback: Attempting to store access_token...")
        keyring.set_password("evernote_extractor", "access_token", access_token)
        # No longer storing access_token_secret as it's empty and not needed for API calls with the main token
        print("[KEYRING_DEBUG] /auth/callback: access_token supposedly stored.")
        
        # Verify immediately if it was stored
        retrieved_access_token_after_set = keyring.get_password("evernote_extractor", "access_token")
        print(f"[KEYRING_DEBUG] /auth/callback: Verified access_token after setting: {'SET' if retrieved_access_token_after_set else 'NOT_SET'}")

        # Clean up request tokens
        keyring.delete_password("evernote_extractor", "request_token")
        keyring.delete_password("evernote_extractor", "request_token_secret")
        print("[KEYRING_DEBUG] /auth/callback: Request tokens cleaned up.")
        
        return {"status": "authenticated", "message": "Authentication successful"}
    except Exception as e:
        print(f"[KEYRING_DEBUG] /auth/callback: Exception: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/auth/status")
async def auth_status():
    """Check authentication status"""
    try:
        print("[KEYRING_DEBUG] /auth/status: Entered")
        access_token = keyring.get_password("evernote_extractor", "access_token")
        
        print(f"[KEYRING_DEBUG] /auth/status: Retrieved access_token: {'SET' if access_token else 'NOT_SET'}")
        
        if access_token:
            return {"authenticated": True, "status": "ready"}
        else:
            return {"authenticated": False, "status": "not_authenticated"}
    except Exception as e:
        print(f"[KEYRING_DEBUG] /auth/status: Exception: {str(e)}")
        return {"authenticated": False, "status": "error", "error": str(e)}

@app.post("/auth/logout")
async def logout():
    """Clear stored credentials"""
    try:
        print("[KEYRING_DEBUG] /logout: Entered")
        # Clear all stored tokens
        # No longer attempting to delete access_token_secret as it wasn't being reliably stored/retrieved if empty
        for key in ["access_token", "request_token", "request_token_secret"]:
            try:
                keyring.delete_password("evernote_extractor", key)
                print(f"[KEYRING_DEBUG] /logout: Deleted '{key}' from keyring.")
            except keyring.errors.PasswordDeleteError:
                print(f"[KEYRING_DEBUG] /logout: '{key}' not found in keyring, or error deleting.")
                pass  # Token doesn't exist or couldn't be deleted, which is fine
        
        return {"status": "logged_out", "message": "Credentials cleared"}
    except Exception as e:
        print(f"[KEYRING_DEBUG] /logout: Exception: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/notebooks")
async def get_user_notebooks():
    """Fetch and return the list of user's Evernote notebooks."""
    print("[API_LOG] /notebooks: Endpoint called")
    try:
        # Check if user is authenticated by retrieving the access token
        access_token = get_stored_credentials()
        if not access_token:
            print("[API_LOG] /notebooks: User not authenticated (no access token)")
            raise HTTPException(status_code=401, detail="User not authenticated. Please login first.")

        print("[API_LOG] /notebooks: User authenticated, attempting to fetch notebooks.")
        # The list_notebooks function from fetch.py will handle client creation with the stored token
        notebooks_data = list_notebooks()
        
        if notebooks_data is None: # list_notebooks might return None on error
            print("[API_LOG] /notebooks: Failed to fetch notebooks (list_notebooks returned None).")
            raise HTTPException(status_code=500, detail="Failed to fetch notebooks from Evernote.")

        print(f"[API_LOG] /notebooks: Successfully fetched {len(notebooks_data)} notebooks.")
        return notebooks_data
    except HTTPException as http_exc: # Re-raise HTTPExceptions directly
        raise http_exc
    except Exception as e:
        print(f"[API_LOG] /notebooks: Unexpected error: {str(e)}")
        # Log the full traceback for unexpected errors for better debugging
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred: {str(e)}")