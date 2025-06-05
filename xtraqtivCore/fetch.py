"""Functions for fetching notebooks and notes from Evernote."""

from .auth import create_evernote_client, get_stored_credentials
import os

def list_notebooks(client=None):
    """Fetch and list user notebooks"""
    if not client:
        access_token = get_stored_credentials()
        if not access_token:
            print("ERROR: [list_notebooks] No stored access token found.")
            return None
        
        consumer_key = os.getenv("EVERNOTE_CONSUMER_KEY")
        consumer_secret = os.getenv("EVERNOTE_CONSUMER_SECRET")
        sandbox = os.getenv("SANDBOX", "false").lower() == "true"

        if not consumer_key or not consumer_secret:
            print("ERROR: [list_notebooks] EVERNOTE_CONSUMER_KEY or EVERNOTE_CONSUMER_SECRET not set.")
            return None
        
        client = create_evernote_client(consumer_key, consumer_secret, access_token, sandbox)
    
    try:
        note_store = client.get_note_store()
        notebooks = note_store.listNotebooks()
        return [{
            'name': nb.name,
            'guid': nb.guid,
            'noteCount': getattr(nb, 'noteCount', 0),
            'defaultNotebook': getattr(nb, 'defaultNotebook', False)
        } for nb in notebooks]
    except Exception as e:
        print(f"Error fetching notebooks: {e}")
        return None

def list_notes(notebook_guid=None, client=None):
    """Fetch notes from a specific notebook or all notebooks"""
    if not client:
        access_token = get_stored_credentials()
        if not access_token:
            print("ERROR: [list_notes] No stored access token found.")
            return []
        
        consumer_key = os.getenv("EVERNOTE_CONSUMER_KEY")
        consumer_secret = os.getenv("EVERNOTE_CONSUMER_SECRET")
        sandbox = os.getenv("SANDBOX", "false").lower() == "true"

        if not consumer_key or not consumer_secret:
            print("ERROR: [list_notes] EVERNOTE_CONSUMER_KEY or EVERNOTE_CONSUMER_SECRET not set.")
            return []
        
        client = create_evernote_client(consumer_key, consumer_secret, access_token, sandbox)
    
    try:
        note_store = client.get_note_store()
        
        # Create note filter
        from evernote.edam.notestore.ttypes import NoteFilter
        filter = NoteFilter()
        if notebook_guid:
            filter.notebookGuid = notebook_guid
            
        # Get notes (limited to 100 for now, can be expanded)
        notes = note_store.findNotes(filter, 0, 100)
        
        return [{
            'title': note.title,
            'guid': note.guid,
            'created': note.created,
            'updated': note.updated,
            'notebookGuid': note.notebookGuid
        } for note in notes.notes]
    except Exception as e:
        print(f"Error fetching notes: {e}")
        return []