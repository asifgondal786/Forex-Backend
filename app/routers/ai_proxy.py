"""
AI Proxy Router - routes Flutter AI chat requests through the backend.
The Gemini API key never touches the client; it lives in Railway env vars.
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import logging

from ..ai.gemini_client import gemini_client

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/ai", tags=["AI Proxy"])


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


@router.post("/chat", response_model=ChatResponse)
async def proxy_chat(request: ChatRequest):
    """Proxy chat messages to Gemini server-side. Key never sent to client."""
    if not gemini_client.available:
        raise HTTPException(
            status_code=503,
            detail="AI service unavailable. GEMINI_API_KEY not configured.",
        )

    try:
        prompt = _format_messages(request.messages, request.system_prompt)
        response_text = gemini_client.generate_text(
            model_name=request.model,
            prompt=prompt,
        )
        return ChatResponse(content=response_text, model=request.model)

    except Exception as e:
        logger.error(f"AI proxy error: {e}")
        raise HTTPException(status_code=500, detail=f"AI request failed: {str(e)}")


@router.get("/health")
async def ai_health():
    """Public endpoint - check if AI service is configured."""
    return {
        "available": gemini_client.available,
        "service": "gemini",
    }


def _format_messages(messages: List[ChatMessage], system_prompt: Optional[str]) -> str:
    parts = []
    if system_prompt:
        parts.append(f"[System]: {system_prompt}\n")
    for msg in messages:
        label = "User" if msg.role == "user" else "Assistant"
        parts.append(f"{label}: {msg.content}")
    parts.append("Assistant:")
    return "\n".join(parts)
