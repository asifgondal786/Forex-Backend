"""
AI Router — routes requests to Claude or DeepSeek based on task,
with automatic fallback if the primary provider fails.
"""
import os
import logging
from app.ai.claude_client import ask_claude, claude_health
from app.ai.deepseek_client import ask_deepseek, deepseek_health

logger = logging.getLogger(__name__)

_DEFAULT = os.getenv("DEFAULT_AI_PROVIDER", "claude")
_FALLBACK = os.getenv("FALLBACK_AI_PROVIDER", "deepseek")

# Which provider is best for each task type
TASK_ROUTING: dict[str, str] = {
    # Claude strengths — nuance, analysis, safety
    "sentiment":        "claude",
    "classification":   "claude",
    "summarization":    "claude",
    "translation":      "claude",
    "ner":              "claude",
    "intent":           "claude",
    "qa":               "claude",
    "signal_analysis":  "claude",
    "risk_analysis":    "claude",
    "market_analysis":  "claude",
    "news_impact":      "claude",
    "trade_explanation": "claude",
    "conversation":     "claude",
    # DeepSeek strengths — code, math, cost efficiency
    "code_generation":  "deepseek",
    "code_review":      "deepseek",
    "math":             "deepseek",
    "nlp_command":      "deepseek",       # parsing trade commands
    "quick_analysis":   "deepseek",       # simple fast tasks
}

_PROVIDERS = {
    "claude": ask_claude,
    "deepseek": ask_deepseek,
}


async def route(
    prompt: str,
    *,
    task: str = "conversation",
    system: str | None = None,
    max_tokens: int = 1024,
    temperature: float = 0.7,
    force_provider: str | None = None,
) -> dict:
    """Route to the best provider with automatic fallback."""
    primary = force_provider if force_provider in _PROVIDERS else TASK_ROUTING.get(task, _DEFAULT)
    fallback = "deepseek" if primary == "claude" else "claude"

    logger.info("AI Router | task=%s primary=%s fallback=%s", task, primary, fallback)

    # Try primary
    try:
        result = await _PROVIDERS[primary](
            prompt, system=system, max_tokens=max_tokens, temperature=temperature,
        )
        result["routed_task"] = task
        return result
    except Exception as exc:
        logger.warning("Primary '%s' failed: %s — trying fallback '%s'", primary, exc, fallback)

    # Try fallback
    try:
        result = await _PROVIDERS[fallback](
            prompt, system=system, max_tokens=max_tokens, temperature=temperature,
        )
        result["routed_task"] = task
        result["fallback_used"] = True
        return result
    except Exception as exc:
        logger.error("Both providers failed for task '%s': %s", task, exc)
        raise RuntimeError(f"All AI providers failed for task '{task}'") from exc


async def health() -> dict:
    """Health check all providers."""
    return {
        "claude": await claude_health(),
        "deepseek": await deepseek_health(),
    }
