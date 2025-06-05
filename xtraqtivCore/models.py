from pydantic import BaseModel
from typing import Optional, List
import datetime # Added for datetime fields

class Notebook(BaseModel):
    guid: str
    name: str
    defaultNotebook: bool = False
    stack: Optional[str] = None

class Tag(BaseModel):
    guid: str
    name: str

class NoteMetadata(BaseModel):
    guid: str
    title: str
    created: datetime.datetime
    updated: datetime.datetime
    notebookGuid: str
    tagGuids: Optional[List[str]] = [] # Storing tag GUIDs initially
    tagNames: Optional[List[str]] = [] # Storing tag names for convenience

class Note(NoteMetadata):
    content: Optional[str] = None # ENML content
    # attachments: List[Attachment] = [] # To be added later 