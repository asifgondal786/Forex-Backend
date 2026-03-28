import firebase_admin
from firebase_admin import credentials, firestore
import os, json
from datetime import timezone
from dotenv import load_dotenv

load_dotenv()
DRY_RUN = False
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SECRET_KEY")

if not firebase_admin._apps:
    cred = credentials.Certificate("firebase_key.json")
    firebase_admin.initialize_app(cred)
db = firestore.client()

from supabase import create_client
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

def to_iso(val):
    if val is None: return None
    if hasattr(val, 'isoformat'):
        if hasattr(val, 'tzinfo') and val.tzinfo is None:
            val = val.replace(tzinfo=timezone.utc)
        return val.isoformat()
    if isinstance(val, str): return val
    return None

def sanitize(obj):
    if obj is None: return None
    if hasattr(obj, 'isoformat'): return to_iso(obj)
    if isinstance(obj, dict): return {k: sanitize(v) for k, v in obj.items()}
    if isinstance(obj, list): return [sanitize(i) for i in obj]
    return obj

def log(msg): print(f"  {msg}")
def section(t): print(f"\n{'='*50}\n  {t}\n{'='*50}")

# Load valid Firebase UIDs
print("\nLoading valid user IDs...")
valid_user_ids = {doc.id for doc in db.collection("users").stream()}
print(f"  Found {len(valid_user_ids)} real users")

stats = {c: {"read":0,"ok":0,"skip":0,"err":0} for c in
    ["users","tasks","notifications","ai_activity",
     "notification_preferences","user_subscriptions"]}

# ── 1. USERS ──────────────────────────────────────────
section("1 / 6  —  users")
docs = list(db.collection("users").stream())
stats["users"]["read"] = len(docs)
for doc in docs:
    d = doc.to_dict()
    row = {
        "id":          d.get("id") or doc.id,
        "email":       d.get("email"),
        "name":        d.get("name"),
        "avatar_url":  d.get("avatar_url"),
        "plan":        d.get("plan", "free"),
        "preferences": json.dumps(sanitize(d.get("preferences") or {})),
        "created_at":  to_iso(d.get("created_at")),
    }
    try:
        supabase.table("users").upsert(row, on_conflict="id").execute()
        log(f"ok  user: {row['id']}  {row['email']}")
        stats["users"]["ok"] += 1
    except Exception as e:
        log(f"ERR user: {row['id']}  {e}")
        stats["users"]["err"] += 1

# ── 2. TASKS ──────────────────────────────────────────
section("2 / 6  —  tasks")
docs = list(db.collection("tasks").stream())
stats["tasks"]["read"] = len(docs)
for doc in docs:
    d = doc.to_dict()
    uid = d.get("userId")
    if uid not in valid_user_ids:
        log(f"SKIP task: {doc.id}  (userId '{uid}' not in users)")
        stats["tasks"]["skip"] += 1
        continue
    row = {
        "id": d.get("id") or doc.id, "user_id": uid,
        "title": d.get("title"), "description": d.get("description"),
        "task_type": d.get("taskType"), "status": d.get("status"),
        "priority": d.get("priority"), "current_step": d.get("currentStep", 0),
        "total_steps": d.get("totalSteps", 0),
        "steps": json.dumps(sanitize(d.get("steps") or [])),
        "result_file_url": d.get("resultFileUrl"),
        "result_file_name": d.get("resultFileName"),
        "result_file_size": d.get("resultFileSize"),
        "start_time": to_iso(d.get("startTime")),
        "end_time": to_iso(d.get("endTime")),
        "created_at": to_iso(d.get("createdAt")),
    }
    try:
        supabase.table("tasks").upsert(row, on_conflict="id").execute()
        log(f"ok  task: {row['id']}")
        stats["tasks"]["ok"] += 1
    except Exception as e:
        log(f"ERR task: {doc.id}  {e}")
        stats["tasks"]["err"] += 1

# ── 3. NOTIFICATIONS ──────────────────────────────────
section("3 / 6  —  notifications")
docs = list(db.collection("notifications").stream())
stats["notifications"]["read"] = len(docs)
for doc in docs:
    d = doc.to_dict()
    uid = d.get("userId")
    if uid not in valid_user_ids:
        log(f"SKIP notif: {doc.id}  (userId '{uid}' not in users)")
        stats["notifications"]["skip"] += 1
        continue
    row = {
        "id": d.get("notificationId") or doc.id, "user_id": uid,
        "title": d.get("title"), "message": d.get("message"),
        "short_message": d.get("shortMessage"), "category": d.get("category"),
        "priority": d.get("priority"), "is_read": d.get("read", False),
        "read_at": to_iso(d.get("readAt")), "action_url": d.get("actionUrl"),
        "timestamp": to_iso(d.get("timestamp")),
        "created_at": to_iso(d.get("createdAt")),
    }
    try:
        supabase.table("notifications").upsert(row, on_conflict="id").execute()
        log(f"ok  notif: {row['id']}")
        stats["notifications"]["ok"] += 1
    except Exception as e:
        log(f"ERR notif: {doc.id}  {e}")
        stats["notifications"]["err"] += 1

# ── 4. AI ACTIVITY ────────────────────────────────────
section("4 / 6  —  ai_activity")
docs = list(db.collection("ai_activity").stream())
stats["ai_activity"]["read"] = len(docs)
for doc in docs:
    d = doc.to_dict()
    uid = d.get("userId")
    if uid not in valid_user_ids:
        log(f"SKIP ai_activity: {doc.id}  (userId '{uid}' not in users)")
        stats["ai_activity"]["skip"] += 1
        continue
    row = {
        "id": doc.id, "user_id": uid,
        "type": d.get("type"), "message": d.get("message"),
        "emoji": d.get("emoji"), "color": d.get("color"),
        "timestamp": to_iso(d.get("timestamp")),
    }
    try:
        supabase.table("ai_activity").upsert(row, on_conflict="id").execute()
        log(f"ok  ai_activity: {row['id']}")
        stats["ai_activity"]["ok"] += 1
    except Exception as e:
        log(f"ERR ai_activity: {doc.id}  {e}")
        stats["ai_activity"]["err"] += 1

# ── 5. NOTIFICATION PREFERENCES ───────────────────────
section("5 / 6  —  notification_preferences")
docs = list(db.collection("notification_preferences").stream())
stats["notification_preferences"]["read"] = len(docs)
for doc in docs:
    d = doc.to_dict()
    uid = d.get("user_id") or doc.id
    if uid not in valid_user_ids:
        log(f"SKIP notif_prefs: {uid}  (not in users)")
        stats["notification_preferences"]["skip"] += 1
        continue
    row = {
        "user_id": uid,
        "enabled_channels": d.get("enabled_channels") or [],
        "disabled_categories": d.get("disabled_categories") or [],
        "channel_settings": json.dumps(sanitize(d.get("channel_settings") or {})),
        "digest_mode": d.get("digest_mode", False),
        "digest_frequency": d.get("digest_frequency", "daily"),
        "quiet_hours_start": d.get("quiet_hours_start", "22:00"),
        "quiet_hours_end": d.get("quiet_hours_end", "08:00"),
        "max_notifications_per_hour": d.get("max_notifications_per_hour", 10),
        "autonomous_mode": d.get("autonomous_mode", False),
        "autonomous_profile": d.get("autonomous_profile"),
        "autonomous_min_confidence": d.get("autonomous_min_confidence", 0.7),
        "autonomous_stage_alerts": d.get("autonomous_stage_alerts", False),
        "autonomous_stage_interval_seconds": d.get("autonomous_stage_interval_seconds", 300),
        "updated_at": to_iso(d.get("updated_at")),
    }
    try:
        supabase.table("notification_preferences").upsert(row, on_conflict="user_id").execute()
        log(f"ok  notif_prefs: {uid}")
        stats["notification_preferences"]["ok"] += 1
    except Exception as e:
        log(f"ERR notif_prefs: {uid}  {e}")
        stats["notification_preferences"]["err"] += 1

# ── 6. USER SUBSCRIPTIONS ─────────────────────────────
section("6 / 6  —  user_subscriptions")
docs = list(db.collection("user_subscriptions").stream())
stats["user_subscriptions"]["read"] = len(docs)
for doc in docs:
    d = doc.to_dict()
    uid = d.get("user_id") or doc.id
    if uid not in valid_user_ids:
        log(f"SKIP subscription: {uid}  (not in users)")
        stats["user_subscriptions"]["skip"] += 1
        continue
    row = {
        "user_id": uid, "plan": d.get("plan","free"),
        "status": d.get("status","active"), "source": d.get("source"),
        "subscribed_at": to_iso(d.get("subscribed_at")),
        "updated_at": to_iso(d.get("updated_at")),
        "renews_on": to_iso(d.get("renews_on")),
        "expires_on": to_iso(d.get("expires_on")),
    }
    try:
        supabase.table("user_subscriptions").upsert(row, on_conflict="user_id").execute()
        log(f"ok  subscription: {uid}")
        stats["user_subscriptions"]["ok"] += 1
    except Exception as e:
        log(f"ERR subscription: {uid}  {e}")
        stats["user_subscriptions"]["err"] += 1

# ── SUMMARY ───────────────────────────────────────────
print(f"\n{'='*50}\n  SUMMARY  [LIVE]\n{'='*50}")
for c, s in stats.items():
    status = "OK" if s["err"] == 0 else "ERRORS"
    print(f"  {c:<30} read={s['read']}  ok={s['ok']}  skip={s['skip']}  err={s['err']}  [{status}]")
print("\n  Migration complete. Verify counts in Supabase Table Editor.")
