from bs4 import BeautifulSoup
import markdownify

def convert_enml_to_markdown(enml_content: str) -> str:
    """Converts an ENML string to Markdown.

    Args:
        enml_content: The ENML content string (should include <en-note> tags).

    Returns:
        A string containing the converted Markdown.
    """
    try:
        # Parse the ENML content as XML
        # BeautifulSoup can often handle ENML well with its default HTML parser too,
        # but lxml or xml parser is more strict if needed.
        soup = BeautifulSoup(enml_content, 'html.parser') # Using html.parser for broader compatibility

        # Find the <en-note> tag, which contains the main content
        en_note_tag = soup.find('en-note')

        if not en_note_tag:
            # If <en-note> is not found, perhaps the input is already the inner content
            # or it's not valid ENML. Try to convert the whole thing.
            # This might be too permissive, consider raising an error or returning as-is.
            html_content = str(soup)
        else:
            html_content = str(en_note_tag) # Get the content of <en-note> as a string
        
        # Convert the HTML content to Markdown
        # Options for markdownify can be specified, e.g., heading_style, strip_tags, etc.
        # Default options are usually quite good.
        # Example: markdownify.markdownify(html_content, heading_style=markdownify. csakmarkdown.ATX)
        markdown_content = markdownify.markdownify(html_content)
        
        return markdown_content

    except Exception as e:
        print(f"Error during ENML to Markdown conversion: {e}")
        # Depending on desired behavior, either re-raise, return None, or return original content
        # For now, return a string indicating failure, or could return the original to see what failed.
        return f"Error converting ENML to Markdown: {str(e)}" 