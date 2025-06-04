from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
import keyring
import os
from dotenv import load_dotenv
from .auth import get_request_token, get_access_token, create_evernote_client

# Load environment variables
load_dotenv()

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
CONSUMER_KEY = os.getenv("EVERNOTE_CONSUMER_KEY", "extraqtive-1974")
CONSUMER_SECRET = os.getenv("EVERNOTE_CONSUMER_SECRET", "5a0d3a222a8c18e60dbf381a9d90b6e1745b24287f323d6da3eabe47")
SANDBOX = os.getenv("SANDBOX", "false").lower() == "true"

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
        # Retrieve stored request token
        request_token = keyring.get_password("evernote_extractor", "request_token")
        request_token_secret = keyring.get_password("evernote_extractor", "request_token_secret")
        
        if not request_token or not request_token_secret:
            raise HTTPException(status_code=400, detail="Request token not found")
        
        # Exchange for access token
        access_token, access_token_secret = get_access_token(
            CONSUMER_KEY, CONSUMER_SECRET, request_token, request_token_secret, 
            oauth_verifier, sandbox=SANDBOX
        )
        
        # Store access token securely
        keyring.set_password("evernote_extractor", "access_token", access_token)
        keyring.set_password("evernote_extractor", "access_token_secret", access_token_secret)
        
        # Clean up request tokens
        keyring.delete_password("evernote_extractor", "request_token")
        keyring.delete_password("evernote_extractor", "request_token_secret")
        
        return {"status": "authenticated", "message": "Authentication successful"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/auth/status")
async def auth_status():
    """Check authentication status"""
    try:
        access_token = keyring.get_password("evernote_extractor", "access_token")
        access_token_secret = keyring.get_password("evernote_extractor", "access_token_secret")
        
        if access_token and access_token_secret:
            return {"authenticated": True, "status": "ready"}
        else:
            return {"authenticated": False, "status": "not_authenticated"}
    except Exception as e:
        return {"authenticated": False, "status": "error", "error": str(e)}

@app.post("/auth/logout")
async def logout():
    """Clear stored credentials"""
    try:
        # Clear all stored tokens
        for key in ["access_token", "access_token_secret", "request_token", "request_token_secret"]:
            try:
                keyring.delete_password("evernote_extractor", key)
            except keyring.errors.PasswordDeleteError:
                pass  # Token doesn't exist, which is fine
        
        return {"status": "logged_out", "message": "Credentials cleared"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))