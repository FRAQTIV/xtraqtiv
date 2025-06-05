from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import RedirectResponse, JSONResponse
import os
import keyring
from evernote.api.client import EvernoteClient
from evernote.edam.notestore import NoteStore
from dotenv import load_dotenv
from typing import List

from .models import Notebook # Added import for Notebook model

load_dotenv()

# Set keyring backend to SecretService to avoid KWallet errors
import keyring.backends.SecretService
keyring.set_keyring(keyring.backends.SecretService.Keyring())

app = FastAPI()

CONSUMER_KEY = os.environ.get('EVERNOTE_CONSUMER_KEY', 'YOUR_CONSUMER_KEY')
CONSUMER_SECRET = os.environ.get('EVERNOTE_CONSUMER_SECRET', 'YOUR_CONSUMER_SECRET')
SANDBOX = True  # Set to False for production
CALLBACK_URL = os.environ.get('EVERNOTE_CALLBACK_URL', 'http://localhost:8000/auth/callback')
SERVICE_NAME = 'xtraqtiv-evernote'
USER_ID = 'default-user'  # For now, single-user; can be extended for multi-user

def get_auth_token():
    return keyring.get_password(SERVICE_NAME, USER_ID)

def set_auth_token(token):
    keyring.set_password(SERVICE_NAME, USER_ID, token)

def delete_auth_token():
    keyring.delete_password(SERVICE_NAME, USER_ID)

@app.post('/auth/start')
def auth_start():
    client = EvernoteClient(
        consumer_key=CONSUMER_KEY,
        consumer_secret=CONSUMER_SECRET,
        sandbox=SANDBOX
    )
    request_token = client.get_request_token(CALLBACK_URL)
    auth_url = client.get_authorize_url(request_token)
    # Store request token in memory/session (for demo, return in response)
    return JSONResponse({
        'auth_url': auth_url,
        'oauth_token': request_token['oauth_token'],
        'oauth_token_secret': request_token['oauth_token_secret']
    })

@app.get('/auth/callback')
def auth_callback(request: Request):
    # In production, retrieve request_token from session or secure store
    oauth_token = request.query_params.get('oauth_token')
    oauth_verifier = request.query_params.get('oauth_verifier')
    oauth_token_secret = request.query_params.get('oauth_token_secret')
    if not (oauth_token and oauth_verifier and oauth_token_secret):
        raise HTTPException(status_code=400, detail='Missing OAuth parameters')
    client = EvernoteClient(
        consumer_key=CONSUMER_KEY,
        consumer_secret=CONSUMER_SECRET,
        sandbox=SANDBOX
    )
    auth_token = client.get_access_token(
        oauth_token,
        oauth_token_secret,
        oauth_verifier
    )
    set_auth_token(auth_token)
    return JSONResponse({'status': 'authenticated'})

@app.get('/auth/status')
def auth_status():
    token = get_auth_token()
    return {'authenticated': bool(token)}

@app.post('/auth/logout')
def auth_logout():
    delete_auth_token()
    return {'status': 'logged out'}

@app.get("/notebooks", response_model=List[Notebook])
def list_notebooks():
    auth_token = get_auth_token()
    if not auth_token:
        raise HTTPException(status_code=401, detail="Not authenticated")

    try:
        client = EvernoteClient(token=auth_token, sandbox=SANDBOX)
        note_store = client.get_note_store()
        raw_notebooks = note_store.listNotebooks()

        notebooks = [
            Notebook(
                guid=nb.guid,
                name=nb.name,
                defaultNotebook=nb.defaultNotebook if nb.defaultNotebook is not None else False,
                stack=nb.stack if nb.stack else None
            )
            for nb in raw_notebooks
        ]
        return notebooks
    except Exception as e:
        # Log the exception e for debugging
        print(f"Error fetching notebooks: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch notebooks from Evernote") 