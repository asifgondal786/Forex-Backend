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
        for k, v in data.items():
            print(f"    {k}: {type(v).__name__}")
        print()
    if not found:
        print("  (empty or no docs)")

for col in ["ai_activity", "notification_preferences", "user_subscriptions"]:
    audit_collection(col)