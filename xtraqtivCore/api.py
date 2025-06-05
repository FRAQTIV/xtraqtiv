from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import RedirectResponse, JSONResponse
import os
import keyring
from evernote.api.client import EvernoteClient
from evernote.edam.notestore import NoteStore
from evernote.edam.notestore.ttypes import NotesMetadataResultSpec, NoteFilter
from evernote.edam.type.ttypes import NoteSortOrder
from dotenv import load_dotenv
from typing import List
import datetime

from .models import Notebook, NoteMetadata, Note, Attachment

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

@app.post("/notes/fetch-metadata", response_model=List[NoteMetadata])
def fetch_notes_metadata(notebook_guids: List[str]):
    auth_token = get_auth_token()
    if not auth_token:
        raise HTTPException(status_code=401, detail="Not authenticated")

    all_notes_metadata = []
    try:
        client = EvernoteClient(token=auth_token, sandbox=SANDBOX)
        note_store = client.get_note_store()

        # Define what metadata to fetch
        # For available fields, see Edam.Limits.EDAM_NOTES_METADATA_RESULT_SPEC_...
        result_spec = NotesMetadataResultSpec(
            includeTitle=True,
            includeCreated=True,
            includeUpdated=True,
            includeTagGuids=True,
            # includeAttributes=True, # For things like author, sourceURL, etc.
            # includeNotebookGuid=True # Not strictly needed as we filter by it
        )

        for notebook_guid in notebook_guids:
            note_filter = NoteFilter(
                notebookGuid=notebook_guid,
                order=NoteSortOrder.UPDATED, # Or CREATED, TITLE etc.
                ascending=False
            )
            
            offset = 0
            max_notes_per_call = 250 # Evernote API limit for findNotesMetadata
            while True:
                notes_metadata_list = note_store.findNotesMetadata(
                    note_filter,
                    offset,
                    max_notes_per_call,
                    result_spec
                )
                
                if not notes_metadata_list.notes:
                    break # No more notes in this notebook

                for en_note_meta in notes_metadata_list.notes:
                    # Resolve tag GUIDs to names (optional, can be done on client or here)
                    # For now, just pass GUIDs and an empty list for names
                    tag_names = [] # Placeholder
                    # if en_note_meta.tagGuids:
                    #    try:
                    #        tag_names = note_store.getNoteTagNames(en_note_meta.guid)
                    #    except Exception as e:
                    #        print(f"Error fetching tag names for note {en_note_meta.guid}: {e}")
                    
                    note_meta = NoteMetadata(
                        guid=en_note_meta.guid,
                        title=en_note_meta.title,
                        created=datetime.datetime.fromtimestamp(en_note_meta.created / 1000.0),
                        updated=datetime.datetime.fromtimestamp(en_note_meta.updated / 1000.0),
                        notebookGuid=notebook_guid, # Assign the current notebook_guid
                        tagGuids=en_note_meta.tagGuids if en_note_meta.tagGuids else [],
                        tagNames=tag_names
                    )
                    all_notes_metadata.append(note_meta)
                
                if notes_metadata_list.startIndex + len(notes_metadata_list.notes) >= notes_metadata_list.totalNotes:
                    break # Reached the end for this notebook
                offset += len(notes_metadata_list.notes)

        return all_notes_metadata

    except Exception as e:
        print(f"Error fetching notes metadata: {e}") # Log the exception
        # Consider more specific error handling for Evernote API errors (e.g., EDAMUserException)
        raise HTTPException(status_code=500, detail=f"Failed to fetch notes metadata: {str(e)}")

@app.get("/notes/{note_guid}/content", response_model=Note)
def fetch_note_content(note_guid: str):
    auth_token = get_auth_token()
    if not auth_token:
        raise HTTPException(status_code=401, detail="Not authenticated")

    try:
        client = EvernoteClient(token=auth_token, sandbox=SANDBOX)
        note_store = client.get_note_store()

        # Fetch the note with content AND resource information (but not resource data)
        # getNote(guid, withContent, withResourcesData, withResourcesRecognition, withResourcesAlternateData)
        en_note = note_store.getNote(note_guid, True, False, False, False) # withResourcesData is False

        # Resolve tag GUIDs to tag names if available
        tag_names = []
        if en_note.tags:
            tag_names = [tag.name for tag in en_note.tags if tag.name]

        # Populate attachments
        attachments_list = []
        if en_note.resources:
            for res in en_note.resources:
                attachment = Attachment(
                    guid=res.guid,
                    noteGuid=res.noteGuid,
                    mime=res.mime,
                    fileName=res.attributes.fileName if res.attributes else None,
                    size=res.size, # This is the size of the data body from the Resource object itself
                    width=res.attributes.width if res.attributes and res.attributes.width else None,
                    height=res.attributes.height if res.attributes and res.attributes.height else None
                )
                attachments_list.append(attachment)
            
        note_data = Note(
            guid=en_note.guid,
            title=en_note.title,
            created=datetime.datetime.fromtimestamp(en_note.created / 1000.0),
            updated=datetime.datetime.fromtimestamp(en_note.updated / 1000.0),
            notebookGuid=en_note.notebookGuid,
            tagGuids=en_note.tagGuids if en_note.tagGuids else [],
            tagNames=tag_names,
            content=en_note.content,
            attachments=attachments_list # Add the populated list
        )
        return note_data

    except Exception as e:
        print(f"Error fetching note content for {note_guid}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch note content: {str(e)}") 