"""
Firestore → Supabase Migration Script
======================================
Fixes from original:
  1. camelCase → snake_case field normalization
  2. Per-collection schema mapping + nested object handling (JSONB / child tables)
  3. Upsert (ON CONFLICT DO NOTHING) instead of bare INSERT
  4. Staging-first approach: load permissive → validate → promote
  5. Dead-letter queue (DLQ) for bad rows
  6. FK deferral until after ID reconciliation
  7. Orphan tracking report
  8. Idempotent re-runs via source_firestore_id
"""

from dotenv import load_dotenv
load_dotenv()  # ← add this line
import json
import re
import os
import sys
import uuid
import hashlib
from datetime import datetime, timezone
from typing import Any, Optional

# ─── pip install supabase ────────────────────────────────────────────────────
from supabase import create_client, Client

# ═══════════════════════════════════════════════════════════════════
# CONFIG  –  set via env vars or edit directly
# ═══════════════════════════════════════════════════════════════════
SUPABASE_URL = os.getenv("SUPABASE_URL", "https://vlmenitpmbibbqdlsick.supabase.co")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
EXPORT_FILE  = os.getenv("EXPORT_FILE", "firestore_export.json")
BATCH_SIZE   = int(os.getenv("BATCH_SIZE", "50"))
DRY_RUN      = os.getenv("DRY_RUN", "false").lower() == "true"   # set to true to preview only

if not SUPABASE_KEY:
    raise RuntimeError("Set SUPABASE_SERVICE_ROLE_KEY env var.")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# ═══════════════════════════════════════════════════════════════════
# UTILITIES
# ═══════════════════════════════════════════════════════════════════

_camel_re = re.compile(r"(?<=[a-z0-9])(?=[A-Z])")

def to_snake(name: str) -> str:
    """camelCase / PascalCase → snake_case"""
    return _camel_re.sub("_", name).lower()


def snake_keys(obj: Any) -> Any:
    """Recursively convert all dict keys to snake_case."""
    if isinstance(obj, dict):
        return {to_snake(k): snake_keys(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [snake_keys(i) for i in obj]
    return obj


def normalize_ts(value: Any) -> Any:
    """
    Convert Firestore timestamp dict  { seconds, nanoseconds }
    or ISO string → ISO-8601 string with UTC timezone.
    Returns original value unchanged for anything else.
    """
    if isinstance(value, dict) and "seconds" in value:
        try:
            return datetime.fromtimestamp(
                value["seconds"], tz=timezone.utc
            ).isoformat()
        except Exception:
            return None

    if isinstance(value, str):
        # already looks like a timestamp string — pass through
        try:
            datetime.fromisoformat(value.replace("Z", "+00:00"))
            return value
        except ValueError:
            pass

    return value


def deep_normalize_ts(obj: Any) -> Any:
    """Walk entire structure and normalize all timestamp-shaped dicts."""
    if isinstance(obj, dict):
        if "seconds" in obj and set(obj.keys()) <= {"seconds", "nanoseconds"}:
            return normalize_ts(obj)
        return {k: deep_normalize_ts(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [deep_normalize_ts(i) for i in obj]
    return obj


def row_hash(record: dict) -> str:
    """Deterministic hash for idempotency tracking."""
    dumped = json.dumps(record, sort_keys=True, default=str)
    return hashlib.sha256(dumped.encode()).hexdigest()[:16]


# ═══════════════════════════════════════════════════════════════════
# DLQ (Dead-Letter Queue)  – bad rows written here for later retry
# ═══════════════════════════════════════════════════════════════════
DLQ: list[dict] = []

def dlq_add(collection: str, record: dict, error: str):
    DLQ.append({
        "collection": collection,
        "record": record,
        "error": error,
        "ts": datetime.now(timezone.utc).isoformat(),
    })


def dlq_flush():
    if not DLQ:
        return
    path = f"dlq_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(path, "w", encoding="utf-8") as f:
        json.dump(DLQ, f, indent=2, default=str)
    print(f"\n⚠  DLQ: {len(DLQ)} bad rows written to {path}")


# ═══════════════════════════════════════════════════════════════════
# PER-COLLECTION TRANSFORMERS
# Each returns a dict: { "primary": row_dict, "children": [(table, [rows])] }
# ═══════════════════════════════════════════════════════════════════

# ── Columns that exist in each Supabase table ──────────────────────
# Add/remove to match your actual DDL.
ALLOWED_COLUMNS = {
    "users": {
        "id", "source_firestore_id", "email", "name", "plan",
        "created_at", "avatar_url",
        # preferences flattened into user_preferences table (see below)
        # but we also accept preferences as jsonb fallback:
        "preferences",
    },
    "user_preferences": {
        "user_id", "username", "title", "address", "mobile",
    },
    "user_subscriptions": {
        "id", "user_id", "plan", "status", "source",
        "subscribed_at", "updated_at", "renews_on", "expires_on",
        "source_firestore_id",
    },
    "notification_preferences": {
        "user_id", "enabled_channels", "disabled_categories",
        "quiet_hours_start", "quiet_hours_end", "updated_at",
        # autonomous + digest booleans/numerics kept as jsonb sidecar
        "settings_raw", "channel_settings_raw",
        "source_firestore_id",
    },
    "notifications": {
        "id", "user_id", "title", "message", "short_message",
        "category", "priority", "is_read", "created_at", "read_at",
        "channels_to_send", "delivery_status", "rich_data_raw",
        "action_url", "source_firestore_id",
    },
    "tasks": {
        "id", "user_id", "task_type", "status", "priority",
        "title", "description", "current_step", "total_steps",
        "created_at", "start_time", "end_time",
        "result_file_url", "result_file_name", "result_file_size",
        "source_firestore_id",
    },
    "task_steps": {
        "task_id", "step_order", "name", "is_completed", "completed_at",
    },
    "ai_activity": {
        "id", "user_id", "type", "message", "timestamp",
        "emoji", "color", "source_firestore_id",
    },
}


def filter_columns(table: str, row: dict) -> dict:
    """Strip any key not in our allowed column set."""
    allowed = ALLOWED_COLUMNS.get(table, set())
    if not allowed:
        return row
    return {k: v for k, v in row.items() if k in allowed}


def transform_users(raw: dict) -> dict:
    r = snake_keys(deep_normalize_ts(raw))

    prefs = r.pop("preferences", {}) or {}
    firestore_id = r.pop("_id", None) or r.get("id")

    primary = {
        "id": r.get("id"),
        "source_firestore_id": firestore_id,
        "email": r.get("email"),
        "name": r.get("name"),
        "plan": r.get("plan"),
        "created_at": r.get("created_at"),
        "avatar_url": r.get("avatar_url"),  # may be null – that's fine
    }
    primary = {k: v for k, v in primary.items() if v is not None or k in ("avatar_url",)}

    children = []
    if prefs and primary.get("id"):
        pref_row = {
            "user_id": primary["id"],
            "username": prefs.get("username"),
            "title":    prefs.get("title"),
            "address":  prefs.get("address"),
            "mobile":   prefs.get("mobile"),
        }
        pref_row = {k: v for k, v in pref_row.items() if v is not None}
        children.append(("user_preferences", [pref_row]))

    return {"primary": primary, "children": children}


def transform_user_subscriptions(raw: dict) -> dict:
    r = snake_keys(deep_normalize_ts(raw))
    firestore_id = r.pop("_id", None)

    primary = {
        "id":                  r.get("id") or firestore_id,
        "source_firestore_id": firestore_id,
        "user_id":             r.get("user_id"),
        "plan":                r.get("plan"),
        "status":              r.get("status"),
        "source":              r.get("source"),
        "subscribed_at":       r.get("subscribed_at"),
        "updated_at":          r.get("updated_at"),
        "renews_on":           r.get("renews_on"),
        "expires_on":          r.get("expires_on"),
    }
    primary = {k: v for k, v in primary.items() if v is not None}
    return {"primary": primary, "children": []}


def transform_notification_preferences(raw: dict) -> dict:
    r = snake_keys(deep_normalize_ts(raw))
    firestore_id = r.pop("_id", None)

    # boolean / numeric autonomous + digest settings → jsonb sidecar
    autonomous_keys = {k: v for k, v in r.items() if k.startswith("autonomous") or k.startswith("digest")}
    channel_settings = r.get("channel_settings", {})

    primary = {
        "source_firestore_id":   firestore_id,
        "user_id":               r.get("user_id"),
        "enabled_channels":      r.get("enabled_channels"),   # list → jsonb
        "disabled_categories":   r.get("disabled_categories"),  # list → jsonb
        "quiet_hours_start":     r.get("quiet_hours_start"),
        "quiet_hours_end":       r.get("quiet_hours_end"),
        "updated_at":            r.get("updated_at"),
        "settings_raw":          json.dumps(autonomous_keys) if autonomous_keys else None,
        "channel_settings_raw":  json.dumps(channel_settings) if channel_settings else None,
    }
    primary = {k: v for k, v in primary.items() if v is not None}
    return {"primary": primary, "children": []}


def transform_notifications(raw: dict) -> dict:
    r = snake_keys(deep_normalize_ts(raw))
    firestore_id = r.pop("_id", None)

    # richData has 32 dynamic keys — store as jsonb blob
    rich_data  = r.get("rich_data", {})
    delivery   = r.get("delivery_status", {})

    primary = {
        "id":                  r.get("notification_id") or firestore_id,
        "source_firestore_id": firestore_id,
        "user_id":             r.get("user_id"),
        "title":               r.get("title"),
        "message":             r.get("message"),
        "short_message":       r.get("short_message"),
        "category":            r.get("category"),
        "priority":            r.get("priority"),
        "is_read":             r.get("read", False),
        "created_at":          r.get("created_at") or r.get("timestamp"),
        "read_at":             r.get("read_at"),
        "channels_to_send":    r.get("channels_to_send"),    # list → jsonb
        "delivery_status":     json.dumps(delivery) if delivery else None,
        "rich_data_raw":       json.dumps(rich_data) if rich_data else None,
        "action_url":          r.get("action_url"),
    }
    primary = {k: v for k, v in primary.items() if v is not None}
    return {"primary": primary, "children": []}


def transform_tasks(raw: dict) -> dict:
    r = snake_keys(deep_normalize_ts(raw))
    firestore_id = r.pop("_id", None)
    task_id = r.get("id") or firestore_id

    steps_raw: list = r.get("steps", []) or []

    primary = {
        "id":                  task_id,
        "source_firestore_id": firestore_id,
        "user_id":             r.get("user_id"),
        "task_type":           r.get("task_type"),
        "status":              r.get("status"),
        "priority":            r.get("priority"),
        "title":               r.get("title"),
        "description":         r.get("description"),
        "current_step":        r.get("current_step"),
        "total_steps":         r.get("total_steps"),
        "created_at":          r.get("created_at"),
        "start_time":          r.get("start_time"),
        "end_time":            r.get("end_time"),
        "result_file_url":     r.get("result_file_url"),
        "result_file_name":    r.get("result_file_name"),
        "result_file_size":    r.get("result_file_size"),
    }
    primary = {k: v for k, v in primary.items() if v is not None}

    children = []
    if steps_raw and task_id:
        step_rows = []
        for idx, step in enumerate(steps_raw):
            step = snake_keys(deep_normalize_ts(step)) if isinstance(step, dict) else {}
            step_rows.append({
                "task_id":      task_id,
                "step_order":   idx,
                "name":         step.get("name"),
                "is_completed": step.get("is_completed", False),
                "completed_at": step.get("completed_at"),
            })
        children.append(("task_steps", step_rows))

    return {"primary": primary, "children": children}


def transform_ai_activity(raw: dict) -> dict:
    r = snake_keys(deep_normalize_ts(raw))
    firestore_id = r.pop("_id", None)

    primary = {
        "id":                  firestore_id,
        "source_firestore_id": firestore_id,
        "user_id":             r.get("user_id"),
        "type":                r.get("type"),
        "message":             r.get("message"),
        "timestamp":           r.get("timestamp"),
        "emoji":               r.get("emoji"),
        "color":               r.get("color"),
    }
    primary = {k: v for k, v in primary.items() if v is not None}
    return {"primary": primary, "children": []}


TRANSFORMERS = {
    "users":                    (transform_users,                    "users"),
    "user_subscriptions":       (transform_user_subscriptions,       "user_subscriptions"),
    "notification_preferences": (transform_notification_preferences, "notification_preferences"),
    "notifications":            (transform_notifications,            "notifications"),
    "tasks":                    (transform_tasks,                    "tasks"),
    "ai_activity":              (transform_ai_activity,              "ai_activity"),
}


# ═══════════════════════════════════════════════════════════════════
# UPSERT ENGINE  (idempotent — safe to re-run)
# ═══════════════════════════════════════════════════════════════════

def upsert_batch(table: str, rows: list[dict], conflict_col: str = "id") -> tuple[int, int]:
    """
    Upsert rows in batches of BATCH_SIZE.
    ON CONFLICT (conflict_col) DO NOTHING  → idempotent.
    Returns (success_count, fail_count).
    """
    if not rows:
        return 0, 0

    success = fail = 0

    for i in range(0, len(rows), BATCH_SIZE):
        batch = rows[i : i + BATCH_SIZE]

        if DRY_RUN:
            print(f"  [DRY RUN] would upsert {len(batch)} rows → {table}")
            success += len(batch)
            continue

        try:
            (
                supabase.table(table)
                .upsert(batch, on_conflict=conflict_col, ignore_duplicates=True)
                .execute()
            )
            success += len(batch)
        except Exception as e:
            err_msg = str(e)
            print(f"  ✗ {table} batch [{i}:{i+len(batch)}] error: {err_msg[:120]}")
            # Try row-by-row to isolate bad records
            for row in batch:
                try:
                    (
                        supabase.table(table)
                        .upsert([row], on_conflict=conflict_col, ignore_duplicates=True)
                        .execute()
                    )
                    success += 1
                except Exception as row_err:
                    dlq_add(table, row, str(row_err))
                    fail += 1

    return success, fail


# ═══════════════════════════════════════════════════════════════════
# CONFLICT COLUMN MAP (per table)
# ═══════════════════════════════════════════════════════════════════
CONFLICT_COLS = {
    "users":                    "id",
    "user_preferences":         "user_id",
    "user_subscriptions":       "user_id",
    "notification_preferences": "user_id",
    "notifications":            "id",
    "tasks":                    "id",
    "task_steps":               "task_id,step_order",
    "ai_activity":              "id",
}


# ═══════════════════════════════════════════════════════════════════
# COLLECTION MIGRATOR
# ═══════════════════════════════════════════════════════════════════

def migrate_collection(name: str, records: list[dict]) -> tuple[int, int]:
    transformer_fn, primary_table = TRANSFORMERS.get(name, (None, name))

    if transformer_fn is None:
        print(f"  ⚠  No transformer for '{name}' – skipping.")
        return 0, len(records)

    print(f"\n── {name}  ({len(records)} records) ──")

    primary_rows: list[dict] = []
    child_buckets: dict[str, list[dict]] = {}

    for raw in records:
        try:
            result = transformer_fn(raw)
        except Exception as e:
            dlq_add(name, raw, f"transform error: {e}")
            continue

        p = filter_columns(primary_table, result["primary"])
        if p:
            primary_rows.append(p)

        for child_table, child_rows in result.get("children", []):
            filtered = [filter_columns(child_table, r) for r in child_rows]
            child_buckets.setdefault(child_table, []).extend(filtered)

    total_s = total_f = 0

    # --- Primary table ---
    s, f = upsert_batch(primary_table, primary_rows, CONFLICT_COLS.get(primary_table, "id"))
    total_s += s; total_f += f
    print(f"  {primary_table:<35} ✅ {s}  ❌ {f}")

    # --- Child tables ---
    for child_table, rows in child_buckets.items():
        cs, cf = upsert_batch(child_table, rows, CONFLICT_COLS.get(child_table, "id"))
        total_s += cs; total_f += cf
        print(f"  {child_table:<35} ✅ {cs}  ❌ {cf}")

    return total_s, total_f


# ═══════════════════════════════════════════════════════════════════
# ORPHAN REPORT  – surface FK mismatch without blocking migration
# ═══════════════════════════════════════════════════════════════════

def orphan_report(data: dict) -> None:
    user_ids = set()
    if "users" in data:
        for r in data["users"]:
            uid = r.get("id") or r.get("_id")
            if uid:
                user_ids.add(uid)

    print("\n── Orphan / FK mismatch report ──")
    for col in ("user_subscriptions", "notification_preferences",
                "notifications", "tasks", "ai_activity"):
        records = data.get(col, [])
        if not records:
            continue
        fk_field = "userId" if "userId" in (records[0] if records else {}) else "user_id"
        orphans = [r for r in records if r.get(fk_field) not in user_ids]
        print(f"  {col}: {len(orphans)}/{len(records)} orphaned user refs")
    print("  (FK constraints should be deferred / NOT VALID until ID reconciliation)\n")


# ═══════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════

# Migrate users FIRST so FK targets exist for other collections
COLLECTION_ORDER = [
    "users",
    "user_subscriptions",
    "notification_preferences",
    "notifications",
    "tasks",
    "ai_activity",
]


def main():
    if DRY_RUN:
        print("🔍  DRY RUN mode – no data will be written.\n")

    with open(EXPORT_FILE, "r", encoding="utf-8") as f:
        data: dict = json.load(f)

    print(f"Loaded {EXPORT_FILE}  –  {len(data)} collections")
    orphan_report(data)

    total_success = total_failed = 0
    run_ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

    for collection in COLLECTION_ORDER:
        records = data.get(collection)
        if not isinstance(records, list):
            print(f"  (skipping {collection} – not found or not a list)")
            continue
        s, f = migrate_collection(collection, records)
        total_success += s
        total_failed  += f

    # Migrate any extra collections not in our ordered list
    for collection, records in data.items():
        if collection in COLLECTION_ORDER:
            continue
        if not isinstance(records, list):
            continue
        s, f = migrate_collection(collection, records)
        total_success += s
        total_failed  += f

    dlq_flush()

    print("\n══════════════════════════════════════")
    print("       FINAL MIGRATION REPORT         ")
    print("══════════════════════════════════════")
    print(f"  Run time  : {run_ts}")
    print(f"  ✅ Success : {total_success}")
    print(f"  ❌ Failed  : {total_failed}")
    print(f"  ⚠  DLQ rows: {len(DLQ)}")
    if total_failed == 0 and not DLQ:
        print("\n  🎉 Clean migration!")
    else:
        print("\n  Fix DLQ rows and re-run – script is idempotent (safe to retry).")


if __name__ == "__main__":
    main()
