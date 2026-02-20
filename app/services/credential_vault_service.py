"""
Encrypted credential vault for broker secrets.

Stores broker credentials encrypted at rest and returns only masked metadata
for UI consumption.
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
import base64
import hashlib
import json
import os
import uuid

from ..utils.firestore_client import get_firestore_client

try:
    from cryptography.fernet import Fernet, InvalidToken
except Exception:  # pragma: no cover - handled via runtime checks
    Fernet = None  # type: ignore[assignment]
    InvalidToken = Exception  # type: ignore[assignment]


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _env_bool(name: str, default: bool = False) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


class CredentialVaultService:
    def __init__(self) -> None:
        self._records_by_user: Dict[str, Dict[str, Dict[str, Any]]] = {}
        self._firestore = None
        self._firestore_disabled = False
        self._key_mode = "configured"
        self._cipher = self._build_cipher()

    @property
    def is_enabled(self) -> bool:
        return self._cipher is not None

    @property
    def key_mode(self) -> str:
        return self._key_mode

    def _build_cipher(self):
        if Fernet is None:
            self._key_mode = "unavailable"
            return None

        configured = (os.getenv("CREDENTIAL_VAULT_MASTER_KEY") or "").strip()
        if configured:
            return self._build_fernet_from_secret(configured, configured=True)

        passphrase = (
            os.getenv("CREDENTIAL_VAULT_MASTER_PASSPHRASE")
            or os.getenv("APP_SECRET")
            or os.getenv("JWT_SECRET")
            or ""
        ).strip()
        if passphrase:
            self._key_mode = "derived_from_passphrase"
            return self._build_fernet_from_secret(passphrase, configured=True)

        self._key_mode = "ephemeral"
        generated = Fernet.generate_key()
        return Fernet(generated)

    def _build_fernet_from_secret(self, secret: str, configured: bool):
        secret_bytes = secret.encode("utf-8")
        try:
            # If already a valid Fernet key, use as-is.
            return Fernet(secret_bytes)
        except Exception:
            # Otherwise derive deterministic 32-byte key from provided secret.
            digest = hashlib.sha256(secret_bytes).digest()
            derived = base64.urlsafe_b64encode(digest)
            if configured:
                self._key_mode = "configured" if self._key_mode == "configured" else self._key_mode
            return Fernet(derived)

    def _ensure_enabled(self) -> None:
        if self._cipher is not None:
            if self._key_mode == "ephemeral" and not _env_bool("DEBUG", False):
                raise RuntimeError(
                    "Credential vault master key is required in non-debug mode. "
                    "Set CREDENTIAL_VAULT_MASTER_KEY."
                )
            return
        raise RuntimeError(
            "Credential vault is disabled. Install 'cryptography' and configure "
            "CREDENTIAL_VAULT_MASTER_KEY."
        )

    def _get_firestore(self):
        if self._firestore_disabled:
            return None
        if self._firestore is not None:
            return self._firestore
        try:
            self._firestore = get_firestore_client()
            return self._firestore
        except Exception:
            self._firestore_disabled = True
            return None

    def _encrypt_payload(self, payload: Dict[str, Any]) -> str:
        self._ensure_enabled()
        serialized = json.dumps(payload, ensure_ascii=True, separators=(",", ":"))
        token = self._cipher.encrypt(serialized.encode("utf-8"))  # type: ignore[union-attr]
        return token.decode("utf-8")

    def _decrypt_payload(self, token: str) -> Dict[str, Any]:
        self._ensure_enabled()
        try:
            decrypted = self._cipher.decrypt(token.encode("utf-8"))  # type: ignore[union-attr]
        except InvalidToken as exc:
            raise ValueError("Stored credential payload is invalid or key has changed") from exc
        data = json.loads(decrypted.decode("utf-8"))
        if not isinstance(data, dict):
            raise ValueError("Credential payload format is invalid")
        return data

    def _mask_username(self, username: str) -> str:
        value = (username or "").strip()
        if len(value) <= 3:
            return "***"
        if len(value) <= 7:
            return f"{value[0]}***{value[-1]}"
        return f"{value[:3]}***{value[-3:]}"

    def _public_record(self, record: Dict[str, Any]) -> Dict[str, Any]:
        return {
            "credential_id": record["credential_id"],
            "provider": record["provider"],
            "label": record.get("label"),
            "username_hint": record.get("username_hint"),
            "mode": record.get("mode", "demo"),
            "is_active": bool(record.get("is_active", True)),
            "created_at": record.get("created_at"),
            "updated_at": record.get("updated_at"),
            "last_used_at": record.get("last_used_at"),
            "metadata": record.get("metadata") or {},
        }

    def _load_user_records(self, user_id: str) -> Dict[str, Dict[str, Any]]:
        cached = self._records_by_user.get(user_id)
        if cached is not None:
            return cached

        records: Dict[str, Dict[str, Any]] = {}
        db = self._get_firestore()
        if db is not None:
            query = db.collection("credential_vault").where("user_id", "==", user_id).stream()
            for doc in query:
                data = doc.to_dict() or {}
                credential_id = str(data.get("credential_id") or doc.id)
                provider = str(data.get("provider") or "").lower()
                if provider != "forex_com":
                    continue
                records[credential_id] = {
                    "credential_id": credential_id,
                    "user_id": user_id,
                    "provider": "forex_com",
                    "label": data.get("label"),
                    "username_hint": data.get("username_hint"),
                    "mode": str(data.get("mode") or "demo"),
                    "is_active": bool(data.get("is_active", True)),
                    "created_at": data.get("created_at"),
                    "updated_at": data.get("updated_at"),
                    "last_used_at": data.get("last_used_at"),
                    "metadata": data.get("metadata") or {},
                    "ciphertext": str(data.get("ciphertext") or ""),
                }

        self._records_by_user[user_id] = records
        return records

    def _persist_record(self, record: Dict[str, Any]) -> None:
        db = self._get_firestore()
        if db is None:
            return
        db.collection("credential_vault").document(record["credential_id"]).set(
            {
                "credential_id": record["credential_id"],
                "user_id": record["user_id"],
                "provider": record["provider"],
                "label": record.get("label"),
                "username_hint": record.get("username_hint"),
                "mode": record.get("mode", "demo"),
                "is_active": bool(record.get("is_active", True)),
                "created_at": record.get("created_at"),
                "updated_at": record.get("updated_at"),
                "last_used_at": record.get("last_used_at"),
                "metadata": record.get("metadata") or {},
                "ciphertext": record["ciphertext"],
            },
            merge=True,
        )

    def _delete_record_from_store(self, credential_id: str) -> None:
        db = self._get_firestore()
        if db is None:
            return
        db.collection("credential_vault").document(credential_id).delete()

    def store_forex_credentials(
        self,
        user_id: str,
        username: str,
        password: str,
        label: Optional[str] = None,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        username = (username or "").strip()
        password = password or ""
        if not username or not password:
            raise ValueError("Username and password are required")

        payload = {
            "username": username,
            "password": password,
        }
        ciphertext = self._encrypt_payload(payload)
        credential_id = f"cred_{uuid.uuid4().hex[:18]}"
        now = _now_iso()
        record = {
            "credential_id": credential_id,
            "user_id": user_id,
            "provider": "forex_com",
            "label": (label or "Forex.com Credentials").strip(),
            "username_hint": self._mask_username(username),
            "mode": str((metadata or {}).get("mode") or "demo"),
            "is_active": True,
            "created_at": now,
            "updated_at": now,
            "last_used_at": None,
            "metadata": metadata or {},
            "ciphertext": ciphertext,
        }

        records = self._load_user_records(user_id)
        records[credential_id] = record
        self._persist_record(record)
        return self._public_record(record)

    def list_forex_credentials(self, user_id: str) -> List[Dict[str, Any]]:
        records = self._load_user_records(user_id)
        ordered = sorted(
            records.values(),
            key=lambda row: str(row.get("updated_at") or ""),
            reverse=True,
        )
        return [self._public_record(record) for record in ordered if record.get("is_active", True)]

    def get_forex_credentials(self, user_id: str, credential_id: Optional[str] = None) -> Dict[str, Any]:
        records = self._load_user_records(user_id)
        if not records:
            raise ValueError("No stored Forex.com credentials found")

        selected: Optional[Dict[str, Any]] = None
        if credential_id:
            selected = records.get(credential_id)
            if not selected:
                raise ValueError("Credential record not found")
        else:
            active_records = [r for r in records.values() if r.get("is_active", True)]
            if not active_records:
                raise ValueError("No active credential record found")
            selected = sorted(
                active_records,
                key=lambda row: str(row.get("updated_at") or ""),
                reverse=True,
            )[0]

        if selected.get("user_id") != user_id:
            raise ValueError("Unauthorized credential access")

        decrypted = self._decrypt_payload(str(selected.get("ciphertext") or ""))
        username = str(decrypted.get("username") or "").strip()
        password = str(decrypted.get("password") or "")
        if not username or not password:
            raise ValueError("Stored credentials are incomplete")

        selected["last_used_at"] = _now_iso()
        self._persist_record(selected)
        return {
            "credential_id": selected["credential_id"],
            "provider": "forex_com",
            "mode": selected.get("mode", "demo"),
            "username": username,
            "password": password,
            "metadata": selected.get("metadata") or {},
        }

    def delete_credential(self, user_id: str, credential_id: str) -> bool:
        records = self._load_user_records(user_id)
        existing = records.get(credential_id)
        if not existing:
            return False
        if existing.get("user_id") != user_id:
            return False
        records.pop(credential_id, None)
        self._delete_record_from_store(credential_id)
        return True


credential_vault_service = CredentialVaultService()
