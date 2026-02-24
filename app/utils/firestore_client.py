import base64
import json
import os
from typing import Optional
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import Request as UrlRequest, urlopen

import firebase_admin
from firebase_admin import auth, credentials, firestore
from google.auth.transport.requests import Request as GoogleAuthRequest


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


def get_firebase_auth_project_config(timeout_seconds: int = 10) -> dict:
    init_firebase()
    project_id = _get_project_id()
    if not project_id:
        raise RuntimeError("FIREBASE_PROJECT_ID is not configured.")

    app = firebase_admin.get_app()
    google_cred = app.credential.get_credential()
    google_cred.refresh(GoogleAuthRequest())

    url = f"https://identitytoolkit.googleapis.com/admin/v2/projects/{project_id}/config"
    req = UrlRequest(
        url=url,
        headers={
            "Authorization": f"Bearer {google_cred.token}",
            "Content-Type": "application/json",
        },
        method="GET",
    )

    try:
        with urlopen(req, timeout=timeout_seconds) as response:
            payload = response.read().decode("utf-8")
            return json.loads(payload)
    except HTTPError as exc:
        body = ""
        try:
            body = exc.read().decode("utf-8")
        except Exception:
            body = str(exc)
        raise RuntimeError(
            f"Firebase Auth config fetch failed ({exc.code}): {body[:300]}"
        ) from exc
    except URLError as exc:
        raise RuntimeError(f"Firebase Auth config fetch failed: {exc}") from exc


def get_firebase_authorized_domains(timeout_seconds: int = 10) -> list[str]:
    config = get_firebase_auth_project_config(timeout_seconds=timeout_seconds)
    raw_domains = config.get("authorizedDomains") or []
    domains: list[str] = []
    for item in raw_domains:
        value = str(item or "").strip().lower()
        if value and value not in domains:
            domains.append(value)
    return domains


def check_firebase_authorized_domain(domain: str, timeout_seconds: int = 10) -> dict:
    candidate = str(domain or "").strip().lower()
    if not candidate:
        raise ValueError("Domain is required for Firebase authorized-domain check.")

    if "://" in candidate:
        candidate = (urlparse(candidate).hostname or "").strip().lower()
    if not candidate:
        raise ValueError("Invalid domain for Firebase authorized-domain check.")

    authorized_domains = get_firebase_authorized_domains(timeout_seconds=timeout_seconds)
    return {
        "project_id": _get_project_id(),
        "domain": candidate,
        "authorized": candidate in authorized_domains,
        "authorized_domains": authorized_domains,
    }
