"""
AI Proxy Router - routes Flutter AI chat requests through the backend.
The Gemini API key never touches the client; it lives in Railway env vars.
"""
import logging
import os
import time
from collections import defaultdict, deque
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel

from ..ai.gemini_client import gemini_client
from ..security import get_current_user_id

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/ai", tags=["AI Proxy"])

# ---------------------------------------------------------------------------
# Per-user rate limit for Gemini calls.
#
# Keyed on Firebase UID (not IP) so authenticated users each get their own
# bucket. This protects against billing abuse even when multiple users share
# the same IP (mobile NAT, office networks, etc.).
#
# Defaults: 20 requests per 60 seconds per user.
# Override via env vars: AI_CHAT_RATE_LIMIT_MAX / AI_CHAT_RATE_LIMIT_WINDOW_SECONDS
# ---------------------------------------------------------------------------
_ai_chat_rate_limit_max: int = int(os.getenv("AI_CHAT_RATE_LIMIT_MAX", "20"))
_ai_chat_rate_limit_window: int = int(os.getenv("AI_CHAT_RATE_LIMIT_WINDOW_SECONDS", "60"))
_ai_chat_rate_limit_store: dict = defaultdict(deque)


def _ai_chat_rate_limit_ok(user_id: str) -> bool:
    now = time.time()
    window_start = now - _ai_chat_rate_limit_window
    bucket = _ai_chat_rate_limit_store[user_id]
    while bucket and bucket[0] <= window_start:
        bucket.popleft()
    if len(bucket) >= _ai_chat_rate_limit_max:
        return False
    bucket.append(now)
    return True


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------

class ChatMessage(BaseModel):
    role: str        # "user" or "model"
    content: str


class ChatRequest(BaseModel):
    messages: List[ChatMessage]
    system_prompt: Optional[str] = None
    model: Optional[str] = "gemini-2.0-flash"


class ChatResponse(BaseModel):
    content: str
    model: str


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@router.post("/chat", response_model=ChatResponse)
async def proxy_chat(
    request: Request,
    chat_request: ChatRequest,
    user_id: str = Depends(get_current_user_id),
):
    """
    Proxy chat messages to Gemini server-side. Key never sent to client.
    Rate limited per authenticated user (default 20 req / 60 s).
    """
    if not gemini_client.available:
        raise HTTPException(
            status_code=503,
            detail="AI service unavailable. GEMINI_API_KEY not configured.",
        )

    if not _ai_chat_rate_limit_ok(user_id):
        logger.warning(
            "ai_chat_rate_limit_exceeded user_id=%s limit=%d window=%ds",
            user_id,
            _ai_chat_rate_limit_max,
            _ai_chat_rate_limit_window,
        )
        raise HTTPException(
            status_code=429,
            detail="AI chat rate limit exceeded. Please wait before sending more messages.",
            headers={"Retry-After": str(_ai_chat_rate_limit_window)},
        )

    try:
        prompt = _format_messages(chat_request.messages, chat_request.system_prompt)
        response_text = gemini_client.generate_text(
            model_name=chat_request.model,
            prompt=prompt,
        )
        return ChatResponse(content=response_text, model=chat_request.model)
    except Exception as e:
        logger.error("AI proxy error user_id=%s: %s", user_id, e)
        raise HTTPException(status_code=500, detail=f"AI request failed: {str(e)}")


@router.get("/health")
async def ai_health():
    """Public endpoint - check if AI service is configured."""
    return {
        "available": gemini_client.available,
        "service": "gemini",
    }


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _format_messages(messages: List[ChatMessage], system_prompt: Optional[str]) -> str:
    parts = []
    if system_prompt:
        parts.append(f"[System]: {system_prompt}\n")
    for msg in messages:
        label = "User" if msg.role == "user" else "Assistant"
        parts.append(f"{label}: {msg.content}")
    parts.append("Assistant:")
    return "\n".join(parts)