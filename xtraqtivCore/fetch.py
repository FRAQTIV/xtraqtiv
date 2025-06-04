from .auth import create_evernote_client, get_stored_credentials
import os

def list_notebooks(client=None):
    """Fetch and list user notebooks"""
    if not client:
        access_token = get_stored_credentials()
        if not access_token:
            return []
        
        consumer_key = os.getenv("EVERNOTE_CONSUMER_KEY", "extraqtive-1974")
        consumer_secret = os.getenv("EVERNOTE_CONSUMER_SECRET", "5a0d3a222a8c18e60dbf381a9d90b6e1745b24287f323d6da3eabe47")
        sandbox = os.getenv("SANDBOX", "false").lower() == "true"
        
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
        return []

def list_notes(notebook_guid=None, client=None):
    """Fetch notes from a specific notebook or all notebooks"""
    if not client:
        access_token = get_stored_credentials()
        if not access_token:
            return []
        
        consumer_key = os.getenv("EVERNOTE_CONSUMER_KEY", "extraqtive-1974")
        consumer_secret = os.getenv("EVERNOTE_CONSUMER_SECRET", "5a0d3a222a8c18e60dbf381a9d90b6e1745b24287f323d6da3eabe47")
        sandbox = os.getenv("SANDBOX", "false").lower() == "true"
        
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