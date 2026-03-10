"""
Migration Verification Script
==============================
Compares Firestore export vs Supabase to confirm data integrity.
Checks: row counts, FK integrity, null critical fields, spot samples.
"""

from dotenv import load_dotenv
load_dotenv()

import json
import os
from datetime import datetime, timezone
from supabase import create_client, Client

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
EXPORT_FILE  = os.getenv("EXPORT_FILE", "firestore_export.json")

if not SUPABASE_KEY or not SUPABASE_URL:
    raise RuntimeError("Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY env vars.")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

PASS = "✅"
FAIL = "❌"
WARN = "⚠️ "

results = []

def check(label: str, passed: bool, detail: str = ""):
    icon = PASS if passed else FAIL
    results.append((icon, label, detail))
    print(f"  {icon}  {label}{(' — ' + detail) if detail else ''}")

def section(title: str):
    print(f"\n{'─'*50}")
    print(f"  {title}")
    print(f"{'─'*50}")

# ─────────────────────────────────────────────────────
# Load Firestore export
# ─────────────────────────────────────────────────────
with open(EXPORT_FILE, "r", encoding="utf-8") as f:
    firestore: dict = json.load(f)

print(f"\n{'═'*50}")
print(f"  MIGRATION VERIFICATION REPORT")
print(f"  {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')}")
print(f"{'═'*50}")

# ─────────────────────────────────────────────────────
# 1. ROW COUNT CHECKS
# ─────────────────────────────────────────────────────
section("1. ROW COUNTS  (Firestore export vs Supabase)")

# Expected counts — Supabase may have MORE (placeholders, pre-existing)
TABLES = {
    "users":                    len(firestore.get("users", [])),
    "user_subscriptions":       len(firestore.get("user_subscriptions", [])),
    "notification_preferences": len(firestore.get("notification_preferences", [])),
    "notifications":            len(firestore.get("notifications", [])),
    "tasks":                    len(firestore.get("tasks", [])),
    "ai_activity":              len(firestore.get("ai_activity", [])),
}

# Count task_steps from nested steps arrays
task_steps_count = sum(
    len(t.get("steps", []) or [])
    for t in firestore.get("tasks", [])
)
TABLES["task_steps"] = task_steps_count

for table, expected in TABLES.items():
    try:
        resp = supabase.table(table).select("id", count="exact").execute()
        actual = resp.count
        # Supabase can have >= expected (pre-existing + placeholders)
        ok = actual >= expected
        check(
            f"{table:<35}",
            ok,
            f"Firestore: {expected}  |  Supabase: {actual}{'  (includes pre-existing/placeholders)' if actual > expected else ''}"
        )
    except Exception as e:
        check(f"{table:<35}", False, f"query error: {e}")

# ─────────────────────────────────────────────────────
# 2. FK INTEGRITY CHECKS
# ─────────────────────────────────────────────────────
section("2. FOREIGN KEY INTEGRITY")

FK_CHECKS = [
    ("user_preferences",         "user_id", "users",  "id"),
    ("user_subscriptions",       "user_id", "users",  "id"),
    ("notification_preferences", "user_id", "users",  "id"),
    ("notifications",            "user_id", "users",  "id"),
    ("tasks",                    "user_id", "users",  "id"),
    ("ai_activity",              "user_id", "users",  "id"),
    ("task_steps",               "task_id", "tasks",  "id"),
]

for child_table, fk_col, parent_table, pk_col in FK_CHECKS:
    try:
        # Fetch all child FK values
        child_resp  = supabase.table(child_table).select(fk_col).execute()
        child_ids   = {r[fk_col] for r in (child_resp.data or []) if r.get(fk_col)}

        # Fetch all parent PK values
        parent_resp = supabase.table(parent_table).select(pk_col).execute()
        parent_ids  = {r[pk_col] for r in (parent_resp.data or []) if r.get(pk_col)}

        orphans = child_ids - parent_ids
        ok = len(orphans) == 0
        check(
            f"{child_table}.{fk_col} → {parent_table}.{pk_col}",
            ok,
            f"{len(orphans)} orphaned refs" if orphans else "all refs valid"
        )
    except Exception as e:
        check(f"{child_table}.{fk_col}", False, f"query error: {e}")

# ─────────────────────────────────────────────────────
# 3. CRITICAL NULL CHECKS
# ─────────────────────────────────────────────────────
section("3. CRITICAL NULL FIELDS")

NULL_CHECKS = [
    ("users",         "email"),
    ("users",         "id"),
    ("notifications", "user_id"),
    ("notifications", "id"),
    ("tasks",         "user_id"),
    ("ai_activity",   "user_id"),
]

for table, col in NULL_CHECKS:
    try:
        resp = supabase.table(table).select("id").is_(col, "null").execute()
        null_count = len(resp.data or [])
        ok = null_count == 0
        check(
            f"{table}.{col} has no NULLs",
            ok,
            f"{null_count} nulls found" if null_count else "clean"
        )
    except Exception as e:
        check(f"{table}.{col}", False, f"query error: {e}")

# ─────────────────────────────────────────────────────
# 4. SPOT SAMPLE — show 3 users from Supabase
# ─────────────────────────────────────────────────────
section("4. SPOT SAMPLE — 3 users from Supabase")

try:
    resp = supabase.table("users").select("id,email,name,plan,created_at").limit(3).execute()
    for row in (resp.data or []):
        print(f"  • {row.get('email','?'):<35}  plan={row.get('plan','?')}  name={row.get('name','?')}")
except Exception as e:
    print(f"  query error: {e}")

# ─────────────────────────────────────────────────────
# 5. SPOT SAMPLE — 3 notifications
# ─────────────────────────────────────────────────────
section("5. SPOT SAMPLE — 3 notifications from Supabase")

try:
    resp = supabase.table("notifications").select("id,user_id,title,category,is_read").limit(3).execute()
    for row in (resp.data or []):
        print(f"  • [{row.get('category','?')}] {row.get('title','?')[:50]}  read={row.get('is_read')}")
except Exception as e:
    print(f"  query error: {e}")

# ─────────────────────────────────────────────────────
# 6. PLACEHOLDER USER CHECK
# ─────────────────────────────────────────────────────
section("6. PLACEHOLDER USERS (safe to clean up later)")

try:
    resp = supabase.table("users").select("id,email").like("email", "%@migrated.invalid").execute()
    placeholders = resp.data or []
    if placeholders:
        print(f"  {WARN} {len(placeholders)} placeholder user(s) found — real data but no real email:")
        for p in placeholders:
            print(f"    • {p['id']}  {p['email']}")
    else:
        print(f"  {PASS}  No placeholder users found.")
except Exception as e:
    print(f"  query error: {e}")

# ─────────────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────────────
passed = sum(1 for r in results if r[0] == PASS)
failed = sum(1 for r in results if r[0] == FAIL)

print(f"\n{'═'*50}")
print(f"  SUMMARY")
print(f"{'═'*50}")
print(f"  {PASS} Passed : {passed}")
print(f"  {FAIL} Failed : {failed}")
if failed == 0:
    print(f"\n  🎉 Migration looks clean! Data is consistent.")
else:
    print(f"\n  ⚠️  {failed} check(s) failed — review above for details.")
print()