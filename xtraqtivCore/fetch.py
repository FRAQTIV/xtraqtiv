def list_notebooks(client):
    try:
        note_store = client.get_note_store()
        notebooks = note_store.listNotebooks()
        return [{
            'name': nb.name,
            'guid': nb.guid
        } for nb in notebooks]
    except Exception as e:
        print(f"Error fetching notebooks: {e}")
        return [] 