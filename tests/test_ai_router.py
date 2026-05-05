"""
test_ai_router.py — Tests for the hybrid AI routing system.
"""

import pytest
from unittest.mock import patch, AsyncMock
from app.ai.ai_router import route, health, TASK_ROUTING


class TestAIRouterRouting:
    """Test that tasks route to the correct provider."""

    def test_claude_tasks_route_correctly(self):
        claude_tasks = [k for k, v in TASK_ROUTING.items() if v == "claude"]
        assert "sentiment" in claude_tasks
        assert "conversation" in claude_tasks
        assert "trade_explanation" in claude_tasks
        assert "news_impact" in claude_tasks

    def test_deepseek_tasks_route_correctly(self):
        deepseek_tasks = [k for k, v in TASK_ROUTING.items() if v == "deepseek"]
        assert "strategy_generation" in deepseek_tasks
        assert "technical_analysis" in deepseek_tasks
        assert "math" in deepseek_tasks
        assert "pattern_recognition" in deepseek_tasks

    @pytest.mark.asyncio
    async def test_route_to_claude(self):
        with patch("app.ai.ai_router.ask_claude", new_callable=AsyncMock) as mock_claude:
            mock_claude.return_value = {"text": "Analysis complete", "provider": "claude"}
            result = await route("Analyze EUR/USD", task="sentiment")
            assert result["routed_task"] == "sentiment"
            mock_claude.assert_called_once()

    @pytest.mark.asyncio
    async def test_route_to_deepseek(self):
        with patch("app.ai.ai_router.ask_deepseek", new_callable=AsyncMock) as mock_ds:
            mock_ds.return_value = {"text": "Strategy built", "provider": "deepseek"}
            result = await route("Build RSI strategy", task="strategy_generation")
            assert result["routed_task"] == "strategy_generation"
            mock_ds.assert_called_once()

    @pytest.mark.asyncio
    async def test_fallback_on_primary_failure(self):
        with patch("app.ai.ai_router.ask_claude", new_callable=AsyncMock) as mock_claude, \
             patch("app.ai.ai_router.ask_deepseek", new_callable=AsyncMock) as mock_ds:
            mock_claude.side_effect = Exception("Claude is down")
            mock_ds.return_value = {"text": "Fallback response", "provider": "deepseek"}

            result = await route("Test prompt", task="conversation")
            assert result.get("fallback_used") is True
            mock_ds.assert_called_once()

    @pytest.mark.asyncio
    async def test_both_providers_fail_raises(self):
        with patch("app.ai.ai_router.ask_claude", new_callable=AsyncMock) as mock_claude, \
             patch("app.ai.ai_router.ask_deepseek", new_callable=AsyncMock) as mock_ds:
            mock_claude.side_effect = Exception("Claude down")
            mock_ds.side_effect = Exception("DeepSeek down")

            with pytest.raises(RuntimeError, match="All AI providers failed"):
                await route("Test prompt", task="conversation")

    @pytest.mark.asyncio
    async def test_force_provider(self):
        with patch("app.ai.ai_router.ask_deepseek", new_callable=AsyncMock) as mock_ds:
            mock_ds.return_value = {"text": "Forced", "provider": "deepseek"}
            # Force deepseek even for a claude task
            result = await route("Sentiment check", task="sentiment", force_provider="deepseek")
            mock_ds.assert_called_once()
