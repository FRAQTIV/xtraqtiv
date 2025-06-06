import os
from evernote.api.client import EvernoteClient
from dotenv import load_dotenv

# Load environment variables from .env if present
load_dotenv()

def mask(s, show=4):
    if not s or len(s) <= show * 2:
        return '*' * len(s)
    return s[:show] + '*' * (len(s) - show * 2) + s[-show:]

# You need to register your app at https://dev.evernote.com/doc/ to get these
CONSUMER_KEY = os.environ.get('EVERNOTE_CONSUMER_KEY', 'YOUR_CONSUMER_KEY')
CONSUMER_SECRET = os.environ.get('EVERNOTE_CONSUMER_SECRET', 'YOUR_CONSUMER_SECRET')
# Read SANDBOX setting from environment variable, default to True for safety
SANDBOX = os.environ.get('SANDBOX', 'true').lower() != 'false'
# Read callback URL from environment or use default
CALLBACK_URL = os.environ.get('EVERNOTE_CALLBACK_URL', 'http://localhost:5000')

TOKEN_FILE = os.path.expanduser('~/.evernote_token')

def authenticate():
    print(f"Using Evernote key: {mask(CONSUMER_KEY)}")
    print(f"Using Evernote secret: {mask(CONSUMER_SECRET)}")
    # Try to load token from file
    if os.path.exists(TOKEN_FILE):
        with open(TOKEN_FILE, 'r') as f:
            auth_token = f.read().strip()
        print("Loaded existing Evernote auth token.")
        return EvernoteClient(token=auth_token, sandbox=SANDBOX)

    client = EvernoteClient(
        consumer_key=CONSUMER_KEY,
        consumer_secret=CONSUMER_SECRET,
        sandbox=SANDBOX
    )
    request_token = client.get_request_token(CALLBACK_URL)
    auth_url = client.get_authorize_url(request_token)
    print(f"Go to the following URL in your browser to authorize:\n{auth_url}")
    print("After authorization, paste the provided verification code here.")
    oauth_verifier = input("Verification code: ").strip()
    auth_token = client.get_access_token(
        request_token['oauth_token'],
        request_token['oauth_token_secret'],
        oauth_verifier
    )
    # Save token for future use
    with open(TOKEN_FILE, 'w') as f:
        f.write(auth_token)
    print("Authentication successful. Token saved.")
    return EvernoteClient(token=auth_token, sandbox=SANDBOX) 