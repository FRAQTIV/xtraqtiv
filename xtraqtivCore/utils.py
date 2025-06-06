from bs4 import BeautifulSoup, NavigableString, Tag
from markdownify import markdownify as md
import logging
import re

logger = logging.getLogger(__name__)

def convert_enml_to_markdown(enml_content: str | None) -> str:
    """Converts ENML content to Markdown string."""
    if enml_content is None:
        logger.error("Error during ENML to Markdown conversion: ENML content is None.")
        return ""
    try:
        # Use 'xml' parser (lxml) for ENML
        soup = BeautifulSoup(enml_content, 'xml')
        # Find the <en-note> tag
        en_note_tag = soup.find('en-note')
        if not en_note_tag:
            logger.warning("No <en-note> tag found in ENML content. Returning empty string.")
            return ""

        # Extract content within <en-note> for conversion
        # We need to get the string representation of the children of en-note tag
        content_html = ''.join(str(child) for child in en_note_tag.children)

        # Convert the HTML content to Markdown
        # Added options to handle specific tags if needed, e.g. code blocks
        markdown_text = md(content_html, heading_style='atx', bullets='* ')
        return markdown_text
    except Exception as e:
        # Log the error and the content that caused it for debugging
        # logger.error(f"Error during ENML to Markdown conversion: {e}\nENML Content: {enml_content[:500]}...")
        logger.error(f"Error during ENML to Markdown conversion: {e}")
        return "" # Return empty string or handle error as appropriate

def convert_enml_to_html(enml_content: str | None) -> str:
    """Converts ENML content to a simplified HTML string (content of <en-note>)."""
    if enml_content is None:
        logger.error("Error during ENML to HTML conversion: ENML content is None.")
        return ""
    try:
        # Use 'xml' parser (lxml) for ENML
        soup = BeautifulSoup(enml_content, 'xml')
        en_note_tag = soup.find('en-note')

        if not en_note_tag:
            logger.warning("No <en-note> tag found in ENML content for HTML conversion. Returning empty string.")
            return ""

        # We want the *inner* HTML of the en-note tag.
        # Stripping the <en-note> tag itself.
        # Preserve en-media, en-crypt, en-todo tags as they are for now
        # Or define specific handling if needed.
        
        # Serialize the children of en_note_tag back to string
        inner_html = ''.join(str(child) for child in en_note_tag.children)
        
        return inner_html.strip()

    except Exception as e:
        # logger.error(f"Error during ENML to HTML conversion: {e}\nENML Content: {enml_content[:500]}...")
        logger.error(f"Error during ENML to HTML conversion: {e}")
        return "" # Return empty string or handle error as appropriate 

def sanitize_filename(name: str) -> str:
    """Sanitizes a string to be a valid filename."""
    if not isinstance(name, str):
        name = str(name) # Ensure it's a string
    # Remove characters that are definitely invalid on most OSes
    name = re.sub(r'[<>:"/\\|?*\x00-\x1f]', '', name)
    # Replace sequences of whitespace with a single underscore
    name = re.sub(r'\s+', '_', name)
    # Remove leading/trailing underscores or periods that can cause issues
    name = name.strip('_.')
    # Ensure the filename is not empty after sanitization
    if not name:
        name = "untitled"
    # Truncate to a reasonable length (e.g., 200 characters)
    # OS path limits are complex, but individual component length is also a factor.
    return name[:200] 