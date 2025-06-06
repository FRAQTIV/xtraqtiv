import inspect
if not hasattr(inspect, 'getargspec'):
    inspect.getargspec = inspect.getfullargspec

from fastapi import FastAPI, Request, HTTPException, Depends
from fastapi.responses import RedirectResponse, JSONResponse, StreamingResponse, HTMLResponse
import os
import keyring
from evernote.api.client import EvernoteClient
from evernote.edam.notestore import NoteStore
from evernote.edam.notestore.ttypes import NotesMetadataResultSpec, NoteFilter
from evernote.edam.type.ttypes import NoteSortOrder
from evernote.edam.error.ttypes import EDAMUserException, EDAMSystemException, EDAMNotFoundException, EDAMErrorCode
from dotenv import load_dotenv
from typing import List
import datetime
from io import BytesIO
import logging # For more structured logging
from pathlib import Path # Added for path operations
from pydantic import BaseModel

from .models import Notebook, NoteMetadata, Note, Attachment, ConversionRequest, ConversionResponse, ExportRequest, ExportResponse
from .utils import convert_enml_to_markdown, convert_enml_to_html, sanitize_filename # Added sanitize_filename

load_dotenv()

# Set keyring backend to SecretService to avoid KWallet errors
# import keyring.backends.SecretService # This might cause issues if SecretService is not available
# keyring.set_keyring(keyring.backends.SecretService.Keyring()) # Consider making this conditional or configurable

app = FastAPI()

# Get CONSUMER_KEY, CONSUMER_SECRET, SANDBOX, CALLBACK_URL from .env or use defaults
CONSUMER_KEY = os.environ.get('EVERNOTE_CONSUMER_KEY', 'YOUR_CONSUMER_KEY')
CONSUMER_SECRET = os.environ.get('EVERNOTE_CONSUMER_SECRET', 'YOUR_CONSUMER_SECRET')
SANDBOX_STR = os.environ.get('SANDBOX', 'True').lower()
SANDBOX = SANDBOX_STR == 'true' # Convert string to boolean

CALLBACK_URL = os.environ.get('EVERNOTE_CALLBACK_URL', 'http://localhost:8000/auth/callback')

SERVICE_NAME = 'xtraqtiv-evernote'
USER_ID = 'default-user'  # For now, single-user; can be extended for multi-user

# Define a base directory for exports
EXPORT_BASE_DIR = Path("xtraqtiv_exports")

# Configure basic logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__) # Use a specific logger for this module

# Global temporary storage for OAuth verifiers
# In a production multi-user or multi-instance app, use a proper session store or database.
temp_oauth_storage = {}

def get_evernote_client(token: str | None = None) -> EvernoteClient:
    """Helper to get an EvernoteClient instance."""
    if token:
        return EvernoteClient(token=token, sandbox=SANDBOX)
    else:
        return EvernoteClient(
            consumer_key=CONSUMER_KEY,
            consumer_secret=CONSUMER_SECRET,
            sandbox=SANDBOX
        )

# OAuth related functions (get_auth_token, set_auth_token, delete_auth_token)
# These need to handle potential errors from keyring, e.g., NoKeyringError
def get_auth_token_from_keyring():
    try:
        return keyring.get_password(SERVICE_NAME, USER_ID)
    except Exception as e: # Catch generic keyring errors
        logger.error(f"Keyring error when getting password: {e}")
        return None

def set_auth_token_in_keyring(token: str):
    try:
        keyring.set_password(SERVICE_NAME, USER_ID, token)
    except Exception as e:
        logger.error(f"Keyring error when setting password: {e}")
        # Decide if this should raise an HTTP exception or just log

def delete_auth_token_from_keyring():
    try:
        keyring.delete_password(SERVICE_NAME, USER_ID)
    except Exception as e: # Catch generic keyring errors
        logger.error(f"Keyring error when deleting password: {e}")

# Updated to use the helper function for token retrieval
@app.post('/auth/start')
def auth_start():
    client = get_evernote_client() 
    try:
        request_token_dict = client.get_request_token(CALLBACK_URL)
        auth_url = client.get_authorize_url(request_token_dict)
        return JSONResponse({
            'auth_url': auth_url,
            'oauth_token': request_token_dict['oauth_token'],
            'oauth_token_secret': request_token_dict['oauth_token_secret']
        })
    except Exception as e:
        logger.error(f"Error during /auth/start: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to initiate Evernote authentication.")

from fastapi.responses import HTMLResponse

@app.get('/auth/callback')
def auth_callback_phase1(request: Request): # Renamed to avoid confusion if old one is called by mistake
    oauth_token = request.query_params.get('oauth_token')
    oauth_verifier = request.query_params.get('oauth_verifier')

    if not (oauth_token and oauth_verifier):
        logger.error(f"/auth/callback_phase1 missing oauth_token or oauth_verifier. Token: {oauth_token}, Verifier: {oauth_verifier}")
        # Return a more user-friendly error page if possible
        return HTMLResponse(
            content="<html><body><h1>Authentication Error</h1><p>Missing required parameters from Evernote. Please try logging in again. If the problem persists, check application logs. You can close this window.</p></body></html>", 
            status_code=400
        )
    
    # Store verifier temporarily
    temp_oauth_storage[oauth_token] = {
        'oauth_verifier': oauth_verifier,
        'timestamp': datetime.datetime.utcnow()
    }
    logger.info(f"Stored verifier for oauth_token (ends with): ...{oauth_token[-6:]}")
    
    # Simple HTML response for the browser window
    html_content = """
    <html>
        <head><title>Authentication Successful</title></head>
        <body>
            <h1>Authentication with Evernote successful!</h1>
            <p>Please return to the Xtraqtiv application. You can now close this browser window.</p>
            <script>
                // Optional: try to close the window automatically, might be blocked by browser
                // setTimeout(() => { window.close(); }, 2000);
            </script>
        </body>
    </html>
    """
    return HTMLResponse(content=html_content)

from pydantic import BaseModel
class ExchangeTokenRequest(BaseModel):
    oauth_token: str
    oauth_token_secret: str

@app.post('/auth/exchange-token')
def auth_exchange_token(payload: ExchangeTokenRequest):
    logger.info(f"Attempting to exchange token for oauth_token (ends with): ...{payload.oauth_token[-6:]}")
    stored_data = temp_oauth_storage.get(payload.oauth_token)

    if not stored_data:
        logger.warning(f"No verifier found in temp storage for oauth_token: ...{payload.oauth_token[-6:]}. Might be too early or token mismatch.")
        raise HTTPException(status_code=404, detail="OAuth verifier not found or expired. Please try login again.")

    oauth_verifier = stored_data['oauth_verifier']
    client = get_evernote_client()
    try:
        access_token = client.get_access_token(
            payload.oauth_token,
            payload.oauth_token_secret,
            oauth_verifier
        )
        set_auth_token_in_keyring(access_token)
        logger.info(f"Successfully obtained and stored access token for oauth_token: ...{payload.oauth_token[-6:]}")
        
        # Clean up temporary storage
        if payload.oauth_token in temp_oauth_storage:
            del temp_oauth_storage[payload.oauth_token]
            logger.info(f"Cleaned temp storage for oauth_token: ...{payload.oauth_token[-6:]}")
            
        return {"status": "authenticated"}
    except Exception as e:
        logger.error(f"Error exchanging token for ...{payload.oauth_token[-6:]}: {e}", exc_info=True)
        # Clean up temporary storage even on error to prevent retries with stale data
        if payload.oauth_token in temp_oauth_storage:
            del temp_oauth_storage[payload.oauth_token]
        raise HTTPException(status_code=500, detail="Failed to get final access token from Evernote.")

@app.get('/auth/status')
def auth_status():
    token = get_auth_token_from_keyring()
    return {'authenticated': bool(token)}

@app.post('/auth/logout')
def auth_logout():
    delete_auth_token_from_keyring()
    return {'status': 'logged out'}

# Dependency to get current active token
def get_current_active_token(request: Request):
    # This is a placeholder. In a real app, you might extract the token from
    # Authorization header (Bearer token) or a secure cookie.
    # For now, we rely on the server-side keyring storage.
    token = get_auth_token_from_keyring()
    if not token:
        logger.warning("Attempted an authenticated action without a token.")
        raise HTTPException(status_code=401, detail="Not authenticated or token expired.")
    return token

# --- Main Application Endpoints ---

@app.get("/notebooks", response_model=List[Notebook])
def list_notebooks(token: str = Depends(get_current_active_token)):
    try:
        client = get_evernote_client(token)
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
    except EDAMUserException as e:
        logger.error(f"Evernote API User Exception (list_notebooks): Code {e.errorCode}, Param {e.parameter}")
        detail = f"Evernote user error: {EDAMErrorCode._VALUES_TO_NAMES.get(e.errorCode, 'Unknown Error')}"
        if e.errorCode in [EDAMErrorCode.AUTH_EXPIRED, EDAMErrorCode.INVALID_AUTH]:
            detail = "Evernote authentication expired or invalid. Please re-authenticate."
        raise HTTPException(status_code=401 if e.errorCode in [EDAMErrorCode.AUTH_EXPIRED, EDAMErrorCode.INVALID_AUTH] else 400, detail=detail)
    except EDAMSystemException as e:
        logger.error(f"Evernote API System Exception (list_notebooks): Code {e.errorCode}, Message {e.message}")
        detail = f"Evernote system error: {EDAMErrorCode._VALUES_TO_NAMES.get(e.errorCode, 'Unknown Error')}"
        if e.errorCode == EDAMErrorCode.RATE_LIMIT_REACHED:
            detail = "Evernote API rate limit reached. Please try again later."
        raise HTTPException(status_code=503, detail=detail)
    except Exception as e:
        logger.error(f"Error fetching notebooks: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="An unexpected error occurred while fetching notebooks.")

@app.post("/notes/fetch-metadata", response_model=List[NoteMetadata])
def fetch_notes_metadata(notebook_guids: List[str], token: str = Depends(get_current_active_token)):
    all_notes_metadata = []
    try:
        client = get_evernote_client(token)
        note_store = client.get_note_store()
        result_spec = NotesMetadataResultSpec(
            includeTitle=True, includeCreated=True, includeUpdated=True,
            includeTagGuids=True, includeNotebookGuid=True # Ensure notebookGuid is included
        )

        for notebook_guid in notebook_guids:
            note_filter = NoteFilter(notebookGuid=notebook_guid, order=NoteSortOrder.UPDATED, ascending=False)
            offset = 0
            max_notes_per_call = 250
            while True:
                notes_meta_list = note_store.findNotesMetadata(note_filter, offset, max_notes_per_call, result_spec)
                if not notes_meta_list.notes:
                    break
                for en_note_meta in notes_meta_list.notes:
                    all_notes_metadata.append(NoteMetadata(
                        guid=en_note_meta.guid,
                        title=en_note_meta.title or "Untitled Note",
                        created=datetime.datetime.fromtimestamp(en_note_meta.created / 1000.0) if en_note_meta.created else None,
                        updated=datetime.datetime.fromtimestamp(en_note_meta.updated / 1000.0) if en_note_meta.updated else None,
                        notebookGuid=en_note_meta.notebookGuid or notebook_guid, # Fallback to outer loop guid
                        tagGuids=en_note_meta.tagGuids if en_note_meta.tagGuids else [],
                        tagNames=[] # Placeholder for simplicity; resolving names can be slow here
                    ))
                if notes_meta_list.startIndex + len(notes_meta_list.notes) >= notes_meta_list.totalNotes:
                    break
                offset += len(notes_meta_list.notes)
        return all_notes_metadata
    except EDAMUserException as e:
        logger.error(f"Evernote API User Exception (fetch_notes_metadata): {e.errorCode}")
        detail = f"Evernote user error: {EDAMErrorCode._VALUES_TO_NAMES.get(e.errorCode)}"
        if e.errorCode in [EDAMErrorCode.AUTH_EXPIRED, EDAMErrorCode.INVALID_AUTH]:
            detail = "Evernote authentication expired or invalid. Please re-authenticate."
        raise HTTPException(status_code=401 if e.errorCode in [EDAMErrorCode.AUTH_EXPIRED, EDAMErrorCode.INVALID_AUTH] else 400, detail=detail)
    except EDAMSystemException as e:
        logger.error(f"Evernote API System Exception (fetch_notes_metadata): {e.errorCode}")
        detail = f"Evernote system error: {EDAMErrorCode._VALUES_TO_NAMES.get(e.errorCode)}"
        if e.errorCode == EDAMErrorCode.RATE_LIMIT_REACHED:
            detail = "Evernote API rate limit reached."
        raise HTTPException(status_code=503, detail=detail)
    except Exception as e:
        logger.error(f"Error fetching notes metadata: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred: {str(e)}")

@app.get("/notes/{note_guid}/content", response_model=Note)
def fetch_note_content(note_guid: str, token: str = Depends(get_current_active_token)):
    try:
        client = get_evernote_client(token)
        note_store = client.get_note_store()
        
        # Fetch the note content (ENML) and basic metadata
        # getNote(guid, withContent, withResourcesData, withResourcesRecognition, 
        #         withResourcesAlternateData, withSharedNotes)
        en_note = note_store.getNote(token, note_guid, True, True, False, False) # Fetch resources metadata too

        our_note = Note(
            guid=en_note.guid,
            title=en_note.title,
            content=en_note.content, # This is ENML
            created=datetime.datetime.fromtimestamp(en_note.created / 1000) if en_note.created else None,
            updated=datetime.datetime.fromtimestamp(en_note.updated / 1000) if en_note.updated else None,
            notebookGuid=en_note.notebookGuid,
            attachments=[] # Initialize attachments list
        )

        # Process Attachments if they exist
        if en_note.resources:
            for res in en_note.resources:
                attachment = Attachment(
                    guid=res.guid,
                    note_guid=res.noteGuid,
                    mime=res.mime,
                    width=res.width,
                    height=res.height,
                    size=res.data.size if res.data else (res.size if hasattr(res, 'size') else None),
                    fileName=res.attributes.fileName if res.attributes else None
                )
                our_note.attachments.append(attachment)
        
        # Process Tags if they exist
        if hasattr(en_note, 'tagGuids') and en_note.tagGuids:
            our_note.tags = [Tag(guid=tag_guid) for tag_guid in en_note.tagGuids]
        else:
            our_note.tags = [] # Ensure it's an empty list if no tags
            
        return our_note

    except EDAMUserException as e:
        logger.error(f"EDAMUserException fetching note content for {note_guid}: {e}")
        if e.errorCode == EDAMErrorCode.PERMISSION_DENIED:
            if e.parameter == "authenticationToken":
                raise HTTPException(status_code=401, detail="Authentication token is invalid or expired.")
            raise HTTPException(status_code=403, detail=f"Permission denied: {e.parameter}")
        elif e.errorCode == EDAMErrorCode.NOT_FOUND:
            raise HTTPException(status_code=404, detail=f"Note or related resource not found: {e.parameter}")
        raise HTTPException(status_code=500, detail=f"Evernote user error: {EDAMErrorCode._VALUES_TO_NAMES.get(e.errorCode, str(e.errorCode))} - {e.parameter}")
    except EDAMSystemException as e:
        logger.error(f"EDAMSystemException fetching note content for {note_guid}: {e}")
        raise HTTPException(status_code=503, detail=f"Evernote system error: {EDAMErrorCode._VALUES_TO_NAMES.get(e.errorCode, str(e.errorCode))} - {e.message}")
    except Exception as e:
        logger.error(f"Error fetching note content for {note_guid}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred while fetching note content.")

@app.get("/attachments/{attachment_guid}/data")
async def fetch_attachment_data(attachment_guid: str, token: str = Depends(get_current_active_token)):
    try:
        client = get_evernote_client(token)
        note_store = client.get_note_store()
        resource = note_store.getResource(attachment_guid, True, False, True, False) # data=True, attributes=True

        if not resource or not resource.data or not resource.data.body:
            raise HTTPException(status_code=404, detail="Attachment data not found or empty.")

        file_data = BytesIO(resource.data.body)
        media_type = resource.mime
        filename = sanitize_filename(resource.attributes.fileName if resource.attributes and resource.attributes.fileName else "attachment")
        
        headers = {'Content-Disposition': f'attachment; filename="{filename}"'}
        return StreamingResponse(file_data, media_type=media_type, headers=headers)

    except EDAMNotFoundException:
        logger.warning(f"Attachment {attachment_guid} not found.")
        raise HTTPException(status_code=404, detail=f"Attachment with GUID {attachment_guid} not found.")
    except EDAMUserException as e:
        logger.error(f"Evernote API User Exception (attachment {attachment_guid}): {e.errorCode}")
        detail = f"Evernote user error (attachment {attachment_guid}): {EDAMErrorCode._VALUES_TO_NAMES.get(e.errorCode)}"
        if e.errorCode in [EDAMErrorCode.AUTH_EXPIRED, EDAMErrorCode.INVALID_AUTH]:
            detail = "Evernote authentication expired."
        elif e.errorCode == EDAMErrorCode.PERMISSION_DENIED:
            detail = f"Permission denied for attachment {attachment_guid}."
        raise HTTPException(status_code=401 if e.errorCode in [EDAMErrorCode.AUTH_EXPIRED, EDAMErrorCode.INVALID_AUTH] else 400, detail=detail)
    # ... (other exception handling similar to above) ...
    except Exception as e:
        logger.error(f"Error fetching attachment data for {attachment_guid}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"An unexpected error for attachment {attachment_guid}: {str(e)}")

@app.post("/notes/convert", response_model=ConversionResponse)
async def convert_note_content(request_data: ConversionRequest, token: str = Depends(get_current_active_token)):
    # Token dependency ensures user is authenticated
    target_format = request_data.target_format.lower()
    converted_content_str = ""
    try:
        if target_format == "markdown":
            converted_content_str = convert_enml_to_markdown(request_data.enml_content)
        elif target_format == "html":
            converted_content_str = convert_enml_to_html(request_data.enml_content)
        else:
            raise HTTPException(status_code=400, detail=f"Unsupported target format: {request_data.target_format}.")

        # The utility functions now return empty on error, so specific error string checks are less reliable.
        # They log errors internally. If an empty string is a valid conversion result for some inputs,
        # distinguishing that from an error might need more context or different error signaling from utils.
        # For now, assume if utils return non-empty, it's a success.
        return ConversionResponse(converted_content=converted_content_str, converted_format=target_format)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error in /notes/convert for format {target_format}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Conversion error: {str(e)}")

@app.post("/export/notebooks", response_model=ExportResponse)
async def perform_actual_export(request_data: ExportRequest, token: str = Depends(get_current_active_token)):
    logger.info(f"Received export request for notebooks: {request_data.notebook_guids}, format: {request_data.target_format}")
    
    notes_exported_count = 0
    export_format = request_data.target_format.lower()
    file_extension = ""
    if export_format == "markdown":
        file_extension = ".md"
    elif export_format == "html":
        file_extension = ".html"
    else:
        raise HTTPException(status_code=400, detail=f"Unsupported export format: {export_format}. Supported: markdown, html")

    try:
        client = get_evernote_client(token)
        note_store = client.get_note_store()

        # Create base export directory if it doesn't exist
        EXPORT_BASE_DIR.mkdir(parents=True, exist_ok=True)
        logger.info(f"Exporting to base directory: {EXPORT_BASE_DIR.resolve()}")

        all_evernote_notebooks = note_store.listNotebooks()
        notebook_guid_to_name_map = {nb.guid: nb.name for nb in all_evernote_notebooks}

        for notebook_guid in request_data.notebook_guids:
            notebook_name_original = notebook_guid_to_name_map.get(notebook_guid, f"notebook_{notebook_guid}")
            sanitized_notebook_name = sanitize_filename(notebook_name_original)
            notebook_export_path = EXPORT_BASE_DIR / sanitized_notebook_name
            notebook_export_path.mkdir(parents=True, exist_ok=True)
            
            logger.info(f"Processing notebook: {notebook_name_original} (GUID: {notebook_guid}) -> {notebook_export_path}")

            note_filter = NoteFilter(notebookGuid=notebook_guid, order=NoteSortOrder.UPDATED, ascending=False)
            # We only need GUID and Title for filename, but result_spec in full export needs to be minimal
            # However, getNote will be called anyway. So just includeTitle is fine here.
            result_spec = NotesMetadataResultSpec(includeTitle=True) 
            
            offset = 0
            # Max notes per findNotesMetadata call, Evernote API limit usually 250
            # Using a smaller number for testing can be okay, but production should use near max.
            max_notes_per_call = 50 

            while True:
                try:
                    notes_metadata_list = note_store.findNotesMetadata(note_filter, offset, max_notes_per_call, result_spec)
                except Exception as find_meta_err:
                    logger.error(f"Error finding notes metadata for notebook {notebook_guid} at offset {offset}: {find_meta_err}", exc_info=True)
                    break # Stop processing this notebook if metadata fetch fails

                if not notes_metadata_list.notes:
                    break

                for en_note_meta in notes_metadata_list.notes:
                    note_title_original = en_note_meta.title if en_note_meta.title else "untitled_note"
                    sanitized_note_title = sanitize_filename(note_title_original)
                    
                    try:
                        # Fetch full note content
                        # getNote(guid, withContent, withResourcesData, withResourcesRecognition, withResourcesAlternateData)
                        note_data = note_store.getNote(en_note_meta.guid, True, False, False, False)
                        
                        if not note_data.content:
                            logger.warning(f"Note {en_note_meta.guid} ('{note_title_original}') has no content. Skipping.")
                            continue

                        converted_content = ""
                        if export_format == "markdown":
                            converted_content = convert_enml_to_markdown(note_data.content)
                        elif export_format == "html":
                            converted_content = convert_enml_to_html(note_data.content)
                        
                        # Note: convert functions return "" on error and log it.
                        # If "" is a valid result vs error, this might need adjustment.
                        # For now, if content is empty after conversion, we might skip or save empty. Let's save.

                        file_path = notebook_export_path / (sanitized_note_title + file_extension)
                        
                        # Handle potential filename collisions by appending a number
                        counter = 1
                        original_file_path = file_path
                        while file_path.exists():
                            file_path = notebook_export_path / (f"{original_file_path.stem}_{counter}{file_extension}")
                            counter += 1
                            if counter > 100: # Safety break to avoid infinite loop on extreme collision
                                logger.error(f"Too many filename collisions for {original_file_path.stem}. Skipping.")
                                break
                        if file_path.exists() and counter > 100: continue

                        with open(file_path, "w", encoding="utf-8") as f:
                            f.write(converted_content)
                        notes_exported_count += 1
                        logger.info(f"  Successfully saved note: {note_title_original} (GUID: {en_note_meta.guid}) to {file_path}")

                    except EDAMNotFoundException:
                        logger.error(f"  Note {en_note_meta.guid} ('{note_title_original}') not found during full content fetch. Skipping.")
                    except Exception as note_proc_err:
                        logger.error(f"  Error processing note {en_note_meta.guid} ('{note_title_original}'): {note_proc_err}. Skipping.", exc_info=True)
                
                if notes_metadata_list.startIndex + len(notes_metadata_list.notes) >= notes_metadata_list.totalNotes:
                    break # Reached the end for this notebook
                offset += len(notes_metadata_list.notes)
            
            logger.info(f"Finished processing notebook {notebook_name_original}. Notes saved from this notebook: (count for this notebook would require another counter)")

        logger.info(f"Export process completed. Total notes saved: {notes_exported_count}")
        return ExportResponse(
            status="Export completed", 
            message=f"Successfully exported {notes_exported_count} notes to {EXPORT_BASE_DIR.resolve()}",
            export_path=str(EXPORT_BASE_DIR.resolve()),
            notes_processed=notes_exported_count # Placeholder, more complex counting if needed
        )

    except EDAMUserException as e:
        logger.error(f"Evernote API User Exception during export: Code {e.errorCode}, Param {e.parameter}", exc_info=True)
        detail = f"Evernote user error during export: {EDAMErrorCode._VALUES_TO_NAMES.get(e.errorCode, 'Unknown Error')}"
        raise HTTPException(status_code=401 if e.errorCode in [EDAMErrorCode.AUTH_EXPIRED, EDAMErrorCode.INVALID_AUTH] else 400, detail=detail)
    except EDAMSystemException as e:
        logger.error(f"Evernote API System Exception during export: Code {e.errorCode}, Message {e.message}", exc_info=True)
        detail = f"Evernote system error during export: {EDAMErrorCode._VALUES_TO_NAMES.get(e.errorCode, 'Unknown Error')}"
        raise HTTPException(status_code=503, detail=detail)
    except HTTPException: # Re-raise HTTPExceptions from format check etc.
        raise
    except Exception as e:
        logger.error(f"Unexpected error during export process: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"An unexpected server error occurred during the export process: {str(e)}")

# To run this app: uvicorn xtraqtivCore.api:app --reload --port 8000
# Remember to set EVERNOTE_CONSUMER_KEY, EVERNOTE_CONSUMER_SECRET, SANDBOX, EVERNOTE_CALLBACK_URL in your .env file or environment

# To run this app: uvicorn xtraqtivCore.api:app --reload --port 8000
# Remember to set EVERNOTE_CONSUMER_KEY, EVERNOTE_CONSUMER_SECRET, SANDBOX, EVERNOTE_CALLBACK_URL in your .env file or environment 