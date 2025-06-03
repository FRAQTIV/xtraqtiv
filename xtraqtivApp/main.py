from xtraqtivCore.auth import authenticate
from xtraqtivCore.fetch import list_notebooks


def main():
    print("Welcome to the Evernote Extractor (Python)")
    client = authenticate()
    if not client:
        print("Authentication failed.")
        return
    print("\nFetching your notebooks...")
    notebooks = list_notebooks(client)
    if notebooks:
        print("\nYour Notebooks:")
        for nb in notebooks:
            print(f"- {nb['name']} (GUID: {nb['guid']})")
    else:
        print("No notebooks found or failed to fetch.")

if __name__ == "__main__":
    main() 