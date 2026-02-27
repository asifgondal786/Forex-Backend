import asyncio

import pytest

from app.forex_data_service import ForexDataService


@pytest.mark.asyncio
async def test_news_cache_returns_cached_payload():
    service = ForexDataService()
    service._news_cache_ttl_seconds = 120

    first = await service.get_forex_factory_news()
    await asyncio.sleep(0.01)
    second = await service.get_forex_factory_news()

    assert first == second
    assert service._cached_news_monotonic > 0


@pytest.mark.asyncio
async def test_sentiment_cache_avoids_duplicate_analysis():
    service = ForexDataService()
    service._sentiment_cache_ttl_seconds = 120
    call_count = 0

    async def fake_analysis(rates, news):
        nonlocal call_count
        call_count += 1
        return {
            "trend": "bullish",
            "major_pairs": rates,
            "volatility": "medium",
            "risk_level": "moderate",
        }

    service.analyze_market_with_gemini = fake_analysis

    rates = {"EUR/USD": 1.1}
    news = [{"currency": "USD", "event": "NFP", "impact": "high"}]
    first = await service.get_market_sentiment(rates=rates, news=news)
    second = await service.get_market_sentiment(rates=rates, news=news)

    assert call_count == 1
    assert first == second


@pytest.mark.asyncio
async def test_pair_forecast_cache_skips_recomputation():
    service = ForexDataService()
    service._pair_forecast_cache_ttl_seconds = 120
    rates_calls = 0
    news_calls = 0
    analysis_calls = 0

    async def fake_rates():
        nonlocal rates_calls
        rates_calls += 1
        return {"EUR/USD": 1.1}

    async def fake_news():
        nonlocal news_calls
        news_calls += 1
        return [{"currency": "USD", "event": "NFP", "impact": "high"}]

    async def fake_analysis(rates, news):
        nonlocal analysis_calls
        analysis_calls += 1
        return {
            "trend": "bullish",
            "major_pairs": rates,
            "volatility": "medium",
            "risk_level": "moderate",
        }

    service.get_currency_rates = fake_rates
    service.get_forex_factory_news = fake_news
    service.analyze_market_with_gemini = fake_analysis

    first = await service.get_pair_forecast("EUR/USD", "1d")
    second = await service.get_pair_forecast("EUR/USD", "1d")

    assert first == second
    assert rates_calls == 1
    assert news_calls == 1
    assert analysis_calls == 1
