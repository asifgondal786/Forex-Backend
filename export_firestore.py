import firebase_admin
from firebase_admin import credentials, firestore
import json
from datetime import datetime
from google.cloud.firestore_v1.base_document import DocumentSnapshot

cred = credentials.Certificate("firebase_key.json")
firebase_admin.initialize_app(cred)

db = firestore.client()

def convert_firestore_types(obj):
    if isinstance(obj, datetime):
        return obj.isoformat()
    if isinstance(obj, dict):
        return {k: convert_firestore_types(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [convert_firestore_types(i) for i in obj]
    return obj

data = {}

collections = db.collections()

for collection in collections:
    docs = collection.stream()
    data[collection.id] = []

    for doc in docs:
        doc_dict = doc.to_dict()
        doc_dict["_id"] = doc.id
        doc_dict = convert_firestore_types(doc_dict)
        data[collection.id].append(doc_dict)

with open("firestore_export.json", "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print("✅ Firestore export completed successfully.")