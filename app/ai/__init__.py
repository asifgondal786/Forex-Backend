"""AI clients package - Claude (Bedrock) + DeepSeek + Smart Router."""
from app.ai.claude_client import ask_claude, claude_health, ClaudeClient
from app.ai.deepseek_client import (
    ask_deepseek,
    deepseek_health,
    DeepSeekClient,
    chat_completion,
    chat_completion_json,
    health_check,
)
from app.ai.ai_router import route as ai_route, health as ai_health

__all__ = [
    "ask_claude", "claude_health", "ClaudeClient",
    "ask_deepseek", "deepseek_health", "DeepSeekClient",
    "chat_completion", "chat_completion_json", "health_check",
    "ai_route", "ai_health",
]
