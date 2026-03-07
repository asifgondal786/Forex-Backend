import json
import os
from supabase import create_client

SUPABASE_URL = "https://vlmenitpmbibbqdlsick.supabase.co"
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

if not SUPABASE_KEY:
    raise RuntimeError(
        "Missing SUPABASE_SERVICE_ROLE_KEY environment variable."
    )

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

# Load Firestore export
with open("firestore_export.json", "r", encoding="utf-8") as f:
    data = json.load(f)

collections = [
    "users",
    "user_subscriptions",
    "notification_preferences",
    "notifications",
    "tasks",
    "ai_activity"
]

for collection in collections:

    if collection not in data:
        print(f"{collection} not found in export, skipping...")
        continue

    print(f"\nMigrating {collection}...")

    records = data[collection]

    success = 0
    skipped = 0

    for record in records:

        # Remove Firestore internal id
        record.pop("_id", None)

        # Remove null fields
        clean_record = {k: v for k, v in record.items() if v is not None}

        try:
            supabase.table(collection).upsert(clean_record).execute()
            success += 1
        except Exception as e:
            skipped += 1
            print(f"Skipped record in {collection}: {e}")

    print(f"{collection} migration complete")
    print(f"Inserted/Updated: {success}")
    print(f"Skipped: {skipped}")

print("\nMigration finished.")
