"""
Claude client via AWS Bedrock.
Uses AWS Access Key + Secret Key (from .env).

Provides both:
- Function API: ask_claude() — used by ai_router.py
- Class API: ClaudeClient — for services that need class instances
"""
import boto3
import json
import os
import logging
from tenacity import retry, stop_after_attempt, wait_exponential

from pathlib import Path
from dotenv import load_dotenv
load_dotenv(dotenv_path=Path(__file__).resolve().parents[2] / ".env", override=True)

logger = logging.getLogger(__name__)

_AWS_ACCESS_KEY = os.getenv("AWS_ACCESS_KEY_ID", "")
_AWS_SECRET_KEY = os.getenv("AWS_SECRET_ACCESS_KEY", "")
_AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
_CLAUDE_MODEL = os.getenv("CLAUDE_MODEL_ID", "anthropic.claude-3-sonnet-20240229-v1:0")

_client = None


def _get_client():
    global _client
    if _client is None:
        if not _AWS_ACCESS_KEY or not _AWS_SECRET_KEY:
            logger.warning(
                "AWS credentials not set — Claude will not work. "
                "Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in .env"
            )
        _client = boto3.client(
            "bedrock-runtime",
            aws_access_key_id=_AWS_ACCESS_KEY,
            aws_secret_access_key=_AWS_SECRET_KEY,
            region_name=_AWS_REGION,
        )
        logger.info(
            "Claude Bedrock client initialised | model=%s region=%s",
            _CLAUDE_MODEL, _AWS_REGION,
        )
    return _client


@retry(stop=stop_after_attempt(3), wait=wait_exponential(min=2, max=10), reraise=True)
async def ask_claude(
    prompt: str,
    *,
    system: str | None = None,
    max_tokens: int = 1024,
    temperature: float = 0.7,
) -> dict:
    """Send a prompt to Claude via AWS Bedrock and return parsed response."""
    client = _get_client()

    messages = [{"role": "user", "content": prompt}]
    body: dict = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": max_tokens,
        "temperature": temperature,
        "messages": messages,
    }
    if system:
        body["system"] = system

    try:
        response = client.invoke_model(
            modelId=_CLAUDE_MODEL,
            body=json.dumps(body),
        )
        result = json.loads(response["body"].read())

        return {
            "provider": "claude",
            "model": _CLAUDE_MODEL,
            "content": result["content"][0]["text"],
            "usage": result.get("usage", {}),
            "stop_reason": result.get("stop_reason", "unknown"),
        }
    except Exception as exc:
        logger.error("Claude generation failed: %s", exc)
        raise


async def claude_health() -> bool:
    """Quick health ping."""
    try:
        res = await ask_claude("Reply with only OK", max_tokens=10)
        return "ok" in res["content"].lower()
    except Exception:
        return False


# ═══════════════════════════════════════════════════════════
# CLASS API (for services that need instance-based access)
# ═══════════════════════════════════════════════════════════

class ClaudeClient:
    """Class wrapper for services that need a Claude instance."""

    def __init__(self):
        self.model = _CLAUDE_MODEL
        logger.info("ClaudeClient instance created | model=%s", self.model)

    async def chat(
        self,
        prompt: str,
        system_prompt: str | None = None,
        max_tokens: int = 1024,
        temperature: float = 0.7,
    ) -> str:
        """Send chat and return content string."""
        result = await ask_claude(
            prompt,
            system=system_prompt,
            max_tokens=max_tokens,
            temperature=temperature,
        )
        return result["content"]

    async def analyze(
        self,
        prompt: str,
        system_prompt: str | None = None,
        max_tokens: int = 1024,
        temperature: float = 0.3,
    ) -> str:
        """Analysis with lower temperature."""
        return await self.chat(
            prompt,
            system_prompt=system_prompt,
            max_tokens=max_tokens,
            temperature=temperature,
        )

    async def health_check(self) -> bool:
        return await claude_health()
