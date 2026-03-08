import json
import os
from supabase import create_client
from datetime import datetime

# =============================
# CONFIG
# =============================

SUPABASE_URL = "https://vlmenitpmbibbqdlsick.supabase.co"
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

if not SUPABASE_KEY:
    raise RuntimeError(
        "Missing SUPABASE_SERVICE_ROLE_KEY environment variable."
    )

EXPORT_FILE = "firestore_export.json"
BATCH_SIZE = 50

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)


# =============================
# Timestamp Conversion
# =============================

def normalize_timestamp(value):
    """Convert Firestore timestamps to ISO format"""
    if isinstance(value, dict):
        if "seconds" in value:
            return datetime.utcfromtimestamp(value["seconds"]).isoformat()

    return value


# =============================
# Schema Detection
# =============================

def get_table_columns(table_name):
    try:
        response = supabase.table(table_name).select("*").limit(1).execute()

        if response.data:
            return list(response.data[0].keys())

    except Exception as e:
        print(f"Schema detection failed for {table_name}: {e}")

    return []


# =============================
# Record Cleaning
# =============================

def clean_record(record, valid_columns):

    # Remove Firestore metadata
    record.pop("_id", None)

    cleaned = {}

    for k, v in record.items():

        if v is None:
            continue

        # Normalize timestamps
        v = normalize_timestamp(v)

        # Only allow valid columns
        if not valid_columns or k in valid_columns:
            cleaned[k] = v

    return cleaned


# =============================
# Batch Insert
# =============================

def batch_insert(table_name, records):

    if not records:
        return 0, 0

    success = 0
    failed = 0

    for i in range(0, len(records), BATCH_SIZE):

        batch = records[i:i + BATCH_SIZE]

        try:
            supabase.table(table_name).insert(batch).execute()
            success += len(batch)

        except Exception as e:
            print(f"{table_name} batch error:", e)
            failed += len(batch)

    return success, failed


# =============================
# Migration Engine
# =============================

def migrate_collection(name, records):

    print(f"\nMigrating {name}...")

    valid_columns = get_table_columns(name)

    cleaned_records = [
        clean_record(r, valid_columns)
        for r in records
    ]

    success, failed = batch_insert(name, cleaned_records)

    print(f"{name} → ✅ {success} | ❌ {failed}")

    return success, failed


# =============================
# MAIN
# =============================

def main():

    with open(EXPORT_FILE, "r", encoding="utf-8") as f:
        data = json.load(f)

    total_success = 0
    total_failed = 0

    for collection, records in data.items():

        if not isinstance(records, list):
            continue

        s, f = migrate_collection(collection, records)

        total_success += s
        total_failed += f

    print("\n======================")
    print("FINAL MIGRATION REPORT")
    print("======================")
    print("Total Success:", total_success)
    print("Total Failed:", total_failed)


if __name__ == "__main__":
    main()
