# app/routers/ai_proxy.py
"""
AI Proxy Router — routes Flutter AI chat requests through the backend.
The Gemini API key never touches the client; it stays in Railway env vars.
"""

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import List, Optional
import logging

from ..ai.gemini_client import gemini_client

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/ai", tags=["AI Proxy"])


# ── Request / Response models ──────────────────────────────────────────────

class ChatMessage(BaseModel):
    role: str          # "user" or "model"
    content: str


class ChatRequest(BaseModel):
    messages: List[ChatMessage]
    system_prompt: Optional[str] = None
    model: Optional[str] = "gemini-2.0-flash"
    max_tokens: Optional[int] = 8192


class ChatResponse(BaseModel):
    content: str
    model: str
    usage: Optional[dict] = None


# ── Endpoint ───────────────────────────────────────────────────────────────

@router.post("/chat", response_model=ChatResponse)
async def proxy_chat(request: ChatRequest):
    """
    Proxy chat messages to Gemini API server-side.
    Flutter calls this endpoint — the API key is never sent to the client.
    """
    if not gemini_client.is_available():
        raise HTTPException(
            status_code=503,
            detail="AI service is not available. GEMINI_API_KEY not configured."
        )

    try:
        # Build the prompt from message history
        # gemini_client.generate() takes a simple string prompt.
        # For multi-turn, we format the history into the prompt.
        formatted_prompt = _format_messages(request.messages, request.system_prompt)

        response_text = await gemini_client.generate(
            prompt=formatted_prompt,
            model=request.model,
        )

        return ChatResponse(
            content=response_text,
            model=request.model,
        )

    except Exception as e:
        logger.error(f"AI proxy error: {e}")
        raise HTTPException(status_code=500, detail=f"AI request failed: {str(e)}")


@router.get("/health")
async def ai_health():
    """Check if the AI service is configured and reachable."""
    return {
        "available": gemini_client.is_available(),
        "service": "gemini",
    }


# ── Helpers ────────────────────────────────────────────────────────────────

def _format_messages(messages: List[ChatMessage], system_prompt: Optional[str]) -> str:
    """
    Format a list of chat messages into a single prompt string.
    Gemini's generate() call accepts a text prompt; for multi-turn we
    inline the history so the model has context.
    """
    parts = []

    if system_prompt:
        parts.append(f"[System]: {system_prompt}\n")

    for msg in messages:
        role_label = "User" if msg.role == "user" else "Assistant"
        parts.append(f"{role_label}: {msg.content}")

    # The last message is always from the user; append the reply cue
    parts.append("Assistant:")

    return "\n".join(parts)