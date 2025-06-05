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

class Attachment(BaseModel):
    guid: str
    noteGuid: str
    mime: str
    fileName: Optional[str] = None
    size: Optional[int] = None # Resource.data.size is not always populated directly, might need to fetch full resource
    width: Optional[int] = None # From ResourceAttributes
    height: Optional[int] = None # From ResourceAttributes

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
    attachments: List[Attachment] = [] # Changed from placeholder 

class ConversionRequest(BaseModel):
    enml_content: str
    target_format: str = "markdown" # Default to markdown, can extend later

class ConversionResponse(BaseModel):
    original_format: str = "enml"
    converted_content: str
    converted_format: str 