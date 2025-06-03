# Evernote Extractor (Python)

A cross-platform tool to authenticate with Evernote, extract user notebooks and notes, and export data for large-scale analysis or migration.

## Features
- OAuth authentication with Evernote
- Fetch and list user notebooks
- Fetch notes and attachments
- Export data as JSON

## Setup

1. Clone the repository
2. Create a virtual environment:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

## Usage

1. Run the main script:
   ```bash
   python xtraqtivApp/main.py
   ```
2. Follow the instructions to authenticate with Evernote and fetch your data.

## Project Structure

- `xtraqtivCore/` — Core modules (auth, fetch, export)
- `xtraqtivApp/` — Entry point (CLI or UI)
- `requirements.txt` — Python dependencies

## Notes
- This tool is in early development. Contributions and feedback are welcome!
