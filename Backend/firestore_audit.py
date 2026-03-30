import firebase_admin
from firebase_admin import credentials, firestore

cred = credentials.Certificate("firebase_key.json")
firebase_admin.initialize_app(cred)

db = firestore.client()

def audit_collection(name, limit=3):
    print(f"\n{'='*40}")
    print(f"Collection: {name}")
    docs = db.collection(name).limit(limit).stream()
    found = False
    for doc in docs:
        found = True
        data = doc.to_dict()
        print(f"  doc_id: {doc.id}")
        print(f"  fields: {list(data.keys())}")
        for k, v in data.items():
            print(f"    {k}: {type(v).__name__}")
        print()
    if not found:
        print("  (empty or no docs)")

for col in ["users", "tasks", "signals", "notifications", 
            "trades", "profiles", "orders", "alerts"]:
    try:
        audit_collection(col)
    except Exception as e:
        print(f"\n{col}: not found or error â€” {e}")

print("\n" + "="*40)
print("All top-level collections in Firestore:")
for col in db.collections():
    count = len(list(col.stream()))
    print(f"  - {col.id} ({count} docs)")
