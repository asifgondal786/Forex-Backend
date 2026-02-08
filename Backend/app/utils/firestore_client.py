import base64
import json
import os
from typing import Optional

import firebase_admin
from firebase_admin import credentials, auth, firestore


_firebase_initialized = False


def _get_project_id() -> Optional[str]:
    return os.getenv("FIREBASE_PROJECT_ID") or os.getenv("GOOGLE_CLOUD_PROJECT")


def _get_credential_source() -> str:
    if os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON_B64"):
        return "json_b64"
    if os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON"):
        return "json"
    if os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH"):
        return "path"
    if os.getenv("GOOGLE_APPLICATION_CREDENTIALS"):
        return "adc"
    return "none"


def _get_credentials():
    b64 = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON_B64")
    json_str = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
    path = os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH")

    if b64:
        try:
            decoded = base64.b64decode(b64).decode("utf-8")
            return credentials.Certificate(json.loads(decoded))
        except Exception as exc:
            raise ValueError("Invalid FIREBASE_SERVICE_ACCOUNT_JSON_B64") from exc

    if json_str:
        try:
            return credentials.Certificate(json.loads(json_str))
        except json.JSONDecodeError as exc:
            raise ValueError("Invalid FIREBASE_SERVICE_ACCOUNT_JSON") from exc
    if path:
        return credentials.Certificate(path)

    return credentials.ApplicationDefault()


def init_firebase():
    global _firebase_initialized
    if _firebase_initialized:
        return
    if firebase_admin._apps:
        _firebase_initialized = True
        return

    cred = _get_credentials()
    project_id = _get_project_id()
    options = {"projectId": project_id} if project_id else None

    if options:
        firebase_admin.initialize_app(cred, options)
    else:
        firebase_admin.initialize_app(cred)

    _firebase_initialized = True


def get_firestore_client():
    init_firebase()
    return firestore.client()


def verify_firebase_token(token: str) -> dict:
    init_firebase()
    return auth.verify_id_token(token)


def get_firebase_config_status() -> dict:
    return {
        "credential_source": _get_credential_source(),
        "project_id": _get_project_id(),
        "initialized": bool(firebase_admin._apps),
    }