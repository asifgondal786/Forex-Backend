from typing import Dict, Any, List, Optional, Tuple

from ..utils.firestore_client import get_firestore_client


class TaskService:
    def __init__(self):
        self.db = get_firestore_client()

    def create_task(self, task_id: str, data: Dict[str, Any]) -> None:
        self.db.collection("tasks").document(task_id).set(data)

    def get_task(self, task_id: str) -> Optional[Dict[str, Any]]:
        doc = self.db.collection("tasks").document(task_id).get()
        if not doc.exists:
            return None
        return doc.to_dict() or {}

    def update_task(self, task_id: str, updates: Dict[str, Any]) -> None:
        self.db.collection("tasks").document(task_id).set(updates, merge=True)

    def delete_task(self, task_id: str) -> None:
        self.db.collection("tasks").document(task_id).delete()

    def list_tasks(self, user_id: str) -> List[Tuple[str, Dict[str, Any]]]:
        docs = (
            self.db.collection("tasks")
            .where("userId", "==", user_id)
            .stream()
        )
        return [(doc.id, doc.to_dict() or {}) for doc in docs]
