from pydantic import BaseModel
from typing import Optional

class Notebook(BaseModel):
    guid: str
    name: str
    defaultNotebook: bool = False
    stack: Optional[str] = None 