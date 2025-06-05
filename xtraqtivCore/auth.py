"""OAuth helper utilities for interacting with Evernote."""

import requests
import urllib.parse
from evernote.api.client import EvernoteClient
import keyring


def get_request_token(consumer_key, consumer_secret, sandbox=False):
    """Get OAuth request token from Evernote"""
    client = EvernoteClient(
        consumer_key=consumer_key, consumer_secret=consumer_secret, sandbox=sandbox
    )

    callback_url = "http://localhost:8000/auth/callback"
    request_token = client.get_request_token(callback_url)

    # Generate authorization URL
    auth_url = client.get_authorize_url(request_token)

    return (request_token["oauth_token"], request_token["oauth_token_secret"], auth_url)


def get_access_token(
    consumer_key,
    consumer_secret,
    request_token,
    request_token_secret,
    oauth_verifier,
    sandbox=False,
):
    """Exchange request token for access token"""
    client = EvernoteClient(
        consumer_key=consumer_key, consumer_secret=consumer_secret, sandbox=sandbox
    )

    access_token = client.get_access_token(
        request_token, request_token_secret, oauth_verifier
    )

    return access_token, ""  # Evernote returns token directly


def create_evernote_client(consumer_key, consumer_secret, access_token, sandbox=False):
    """Create authenticated Evernote client"""
    return EvernoteClient(
        consumer_key=consumer_key,
        consumer_secret=consumer_secret,
        token=access_token,
        sandbox=sandbox,
    )


def get_stored_credentials():
    """Retrieve stored credentials from keyring"""
    access_token = keyring.get_password("evernote_extractor", "access_token")
    return access_token if access_token else None
