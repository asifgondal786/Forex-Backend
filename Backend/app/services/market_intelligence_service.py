"""
Market intelligence service used to build deep-study context for notifications.

The goal is to ground notifications in multi-source evidence:
- chart/sentiment context
- Forex Factory latest calendar events
- external market/news sources (RSS or Google News RSS where possible)
"""

from __future__ import annotations

import asyncio
from dataclasses import dataclass
from datetime import datetime, timedelta
from email.utils import parsedate_to_datetime
from typing import Any, Dict, List, Optional, Tuple
from urllib.parse import quote_plus
from xml.etree import ElementTree

import aiohttp

from ..forex_data_service import forex_service


@dataclass(frozen=True)
class SourceDefinition:
    key: str
    label: str
    method: str
    query: Optional[str] = None
    url: Optional[str] = None


class MarketIntelligenceService:
    """
    Collects and synthesizes market intelligence from multiple sources.
    """

    _DEFAULT_PAIR = "EUR/USD"
    _CACHE_TTL_SECONDS = 90
    _RATES_ENDPOINT = "https://api.exchangerate-api.com/v4/latest/USD"

    # Source list aligned with user requirement.
    _SOURCE_DEFINITIONS: List[SourceDefinition] = [
        SourceDefinition(key="charts", label="Charts", method="chart"),
        SourceDefinition(
            key="forex_factory_latest",
            label="Forex Factory News (latest)",
            method="forex_factory_latest",
        ),
        SourceDefinition(key="forex_com", label="Forex.com", method="google_news", query="Forex.com forex"),
        SourceDefinition(key="bloomberg", label="Bloomberg", method="google_news", query="Bloomberg forex"),
        SourceDefinition(key="reuters", label="Reuters", method="google_news", query="Reuters forex"),
        SourceDefinition(key="cnbc", label="CNBC", method="google_news", query="CNBC forex"),
        SourceDefinition(
            key="financial_times",
            label="Financial Times",
            method="google_news",
            query="Financial Times forex",
        ),
        SourceDefinition(
            key="investing_com",
            label="Investing.com",
            method="google_news",
            query="Investing.com forex",
        ),
        SourceDefinition(
            key="forex_factory",
            label="Forex Factory",
            method="google_news",
            query="Forex Factory economic calendar",
        ),
        SourceDefinition(key="dailyfx", label="DailyFX", method="google_news", query="DailyFX forex"),
        SourceDefinition(key="fxstreet", label="FXStreet", method="google_news", query="FXStreet forex"),
        SourceDefinition(key="myfxbook", label="Myfxbook", method="google_news", query="Myfxbook forex"),
        SourceDefinition(key="google_news", label="Google News", method="google_news", query="forex market"),
        SourceDefinition(key="feedly", label="Feedly", method="google_news", query="Feedly forex"),
        SourceDefinition(key="apple_news", label="Apple News", method="google_news", query="Apple News forex"),
        SourceDefinition(key="x", label="X (Twitter)", method="google_news", query="site:x.com forex"),
        SourceDefinition(
            key="reddit",
            label="Reddit",
            method="rss",
            url="https://www.reddit.com/r/Forex/new.rss",
        ),
        SourceDefinition(key="telegram", label="Telegram", method="google_news", query="Telegram forex channel"),
        SourceDefinition(key="discord", label="Discord", method="google_news", query="Discord forex server"),
        SourceDefinition(key="trading_view", label="Trading View", method="google_news", query="TradingView forex"),
    ]

    _SOURCE_WEIGHT: Dict[str, float] = {
        "Bloomberg": 1.0,
        "Reuters": 1.0,
        "Financial Times": 0.95,
        "CNBC": 0.9,
        "Forex Factory News (latest)": 0.9,
        "Forex Factory": 0.85,
        "DailyFX": 0.85,
        "FXStreet": 0.85,
        "Investing.com": 0.8,
        "Trading View": 0.8,
        "Google News": 0.75,
        "Myfxbook": 0.7,
        "Forex.com": 0.75,
        "Reddit": 0.55,
    }

    _POSITIVE_KEYWORDS = {
        "rally",
        "surge",
        "gain",
        "gains",
        "bullish",
        "beat",
        "upside",
        "strength",
        "rebound",
        "optimism",
    }
    _NEGATIVE_KEYWORDS = {
        "selloff",
        "drop",
        "falls",
        "fall",
        "bearish",
        "miss",
        "downside",
        "weakness",
        "decline",
        "recession",
    }
    _HIGH_IMPACT_KEYWORDS = {
        "cpi",
        "inflation",
        "fomc",
        "nfp",
        "interest rate",
        "ecb",
        "boe",
        "boj",
        "jobs",
        "gdp",
        "powell",
        "lagarde",
    }

    def __init__(self) -> None:
        self._cached_key: Optional[Tuple[str, int]] = None
        self._cached_report: Optional[Dict[str, Any]] = None
        self._cached_at: Optional[datetime] = None
        self._last_rates: Dict[str, float] = {}

    async def build_deep_study(
        self,
        pair: str = _DEFAULT_PAIR,
        max_headlines_per_source: int = 3,
    ) -> Dict[str, Any]:
        normalized_pair = (pair or self._DEFAULT_PAIR).strip().upper()
        cache_key = (normalized_pair, max_headlines_per_source)
        if self._is_cache_valid(cache_key):
            cached = dict(self._cached_report or {})
            cached["cached"] = True
            return cached

        chart_analysis_task = asyncio.create_task(
            self._collect_chart_analysis(normalized_pair)
        )
        forex_factory_task = asyncio.create_task(
            self._collect_forex_factory_latest(max_headlines_per_source)
        )
        external_sources_task = asyncio.create_task(
            self._collect_external_sources(max_headlines_per_source)
        )

        chart_analysis, forex_factory_latest, external_sources = await asyncio.gather(
            chart_analysis_task,
            forex_factory_task,
            external_sources_task,
        )

        source_records: List[Dict[str, Any]] = [
            {
                "source": "Charts",
                "status": "derived",
                "headline_count": 0,
                "detail": f"Trend={chart_analysis.get('trend', 'neutral')}, volatility={chart_analysis.get('volatility', 'unknown')}",
                "headlines": [],
            },
            {
                "source": "Forex Factory News (latest)",
                "status": "collected" if forex_factory_latest else "unavailable",
                "headline_count": len(forex_factory_latest),
                "detail": "Latest economic calendar events",
                "headlines": forex_factory_latest,
            },
        ]
        source_records.extend(external_sources)

        all_headlines: List[Dict[str, Any]] = []
        for source in source_records:
            all_headlines.extend(source.get("headlines", []))

        sentiment_score = self._aggregate_sentiment(all_headlines)
        consensus_score = self._compute_consensus_score(
            chart_analysis=chart_analysis,
            sentiment_score=sentiment_score,
            headlines=all_headlines,
        )
        confidence_band = self._confidence_band(consensus_score)
        recommendation = self._recommendation(consensus_score)

        report = {
            "generated_at": datetime.utcnow().isoformat(),
            "pair": normalized_pair,
            "chart_analysis": chart_analysis,
            "source_coverage": self._build_source_coverage(source_records),
            "sentiment_score": round(sentiment_score, 4),
            "consensus_score": round(consensus_score, 4),
            "confidence_band": confidence_band,
            "recommendation": recommendation,
            "evidence_summary": self._build_evidence_summary(
                chart_analysis=chart_analysis,
                source_records=source_records,
                consensus_score=consensus_score,
            ),
            "top_headlines": self._select_top_headlines(all_headlines, limit=8),
            "sources": source_records,
            "cached": False,
        }

        self._cached_key = cache_key
        self._cached_report = report
        self._cached_at = datetime.utcnow()
        return report

    def _is_cache_valid(self, cache_key: Tuple[str, int]) -> bool:
        if self._cached_key != cache_key:
            return False
        if not self._cached_at or not self._cached_report:
            return False
        return (datetime.utcnow() - self._cached_at) <= timedelta(
            seconds=self._CACHE_TTL_SECONDS
        )

    async def _collect_chart_analysis(self, pair: str) -> Dict[str, Any]:
        rates: Dict[str, float] = {}
        try:
            rates = await self._fetch_currency_rates()
        except Exception as exc:
            return {
                "pair": pair,
                "trend": "neutral",
                "volatility": "unknown",
                "risk_level": "unknown",
                "pair_price": None,
                "major_pairs_sample": {},
                "error": f"chart_analysis_failed: {exc}",
            }

        current_price = rates.get(pair)
        previous_price = self._last_rates.get(pair)

        trend = "neutral"
        volatility = "low"
        if current_price and previous_price:
            pct_move = (current_price - previous_price) / previous_price
            if pct_move > 0.0004:
                trend = "bullish"
            elif pct_move < -0.0004:
                trend = "bearish"

            abs_move = abs(pct_move)
            if abs_move >= 0.002:
                volatility = "high"
            elif abs_move >= 0.0008:
                volatility = "medium"
            else:
                volatility = "low"
        elif current_price:
            volatility = "medium"

        self._last_rates.update(rates)

        return {
            "pair": pair,
            "trend": trend,
            "volatility": volatility,
            "risk_level": self._risk_level_from_volatility(volatility),
            "pair_price": current_price,
            "major_pairs_sample": dict(list(rates.items())[:5]),
        }

    async def _fetch_currency_rates(self) -> Dict[str, float]:
        timeout = aiohttp.ClientTimeout(total=6)
        headers = {"User-Agent": "ForexCompanionBot/1.0"}
        async with aiohttp.ClientSession(timeout=timeout, headers=headers) as session:
            async with session.get(self._RATES_ENDPOINT) as response:
                if response.status != 200:
                    return {}
                payload = await response.json()

        rates = payload.get("rates", {}) if isinstance(payload, dict) else {}
        if not isinstance(rates, dict):
            return {}

        def _safe_inverse(code: str) -> Optional[float]:
            raw = rates.get(code)
            if not raw:
                return None
            try:
                return 1 / float(raw)
            except Exception:
                return None

        def _safe_direct(code: str) -> Optional[float]:
            raw = rates.get(code)
            if raw is None:
                return None
            try:
                return float(raw)
            except Exception:
                return None

        normalized = {
            "EUR/USD": _safe_inverse("EUR"),
            "GBP/USD": _safe_inverse("GBP"),
            "USD/JPY": _safe_direct("JPY"),
            "USD/CHF": _safe_direct("CHF"),
            "AUD/USD": _safe_inverse("AUD"),
            "USD/CAD": _safe_direct("CAD"),
            "NZD/USD": _safe_inverse("NZD"),
        }
        return {pair: price for pair, price in normalized.items() if price is not None}

    def _risk_level_from_volatility(self, volatility: str) -> str:
        if volatility == "high":
            return "high"
        if volatility == "medium":
            return "moderate"
        if volatility == "low":
            return "low"
        return "unknown"

    async def _collect_forex_factory_latest(
        self,
        max_headlines: int,
    ) -> List[Dict[str, Any]]:
        try:
            events = await forex_service.get_forex_factory_news()
        except Exception:
            return []

        if not isinstance(events, list):
            return []

        normalized: List[Dict[str, Any]] = []
        for event in events[:max_headlines]:
            currency = str(event.get("currency", "")).strip()
            headline = str(event.get("event", "")).strip()
            impact = str(event.get("impact", "medium")).strip().lower()
            timestamp = self._normalize_timestamp(event.get("time"))
            title = f"{currency} {headline}".strip()
            text_for_scoring = f"{title} {impact}"
            normalized.append(
                {
                    "source": "Forex Factory News (latest)",
                    "title": title or "Economic calendar event",
                    "url": "",
                    "published_at": timestamp,
                    "impact": impact if impact in {"high", "medium", "low"} else "medium",
                    "sentiment": self._headline_sentiment(text_for_scoring),
                }
            )
        return normalized

    async def _collect_external_sources(
        self,
        max_headlines: int,
    ) -> List[Dict[str, Any]]:
        timeout = aiohttp.ClientTimeout(total=6)
        headers = {"User-Agent": "ForexCompanionBot/1.0"}

        async with aiohttp.ClientSession(timeout=timeout, headers=headers) as session:
            tasks = [
                self._collect_single_source(session, source, max_headlines)
                for source in self._SOURCE_DEFINITIONS
                if source.method not in {"chart", "forex_factory_latest"}
            ]
            results = await asyncio.gather(*tasks, return_exceptions=True)

        records: List[Dict[str, Any]] = []
        for result in results:
            if isinstance(result, Exception):
                records.append(
                    {
                        "source": "Unknown",
                        "status": "unavailable",
                        "headline_count": 0,
                        "detail": f"source_collection_failed: {result}",
                        "headlines": [],
                    }
                )
                continue
            records.append(result)
        return records

    async def _collect_single_source(
        self,
        session: aiohttp.ClientSession,
        source: SourceDefinition,
        max_headlines: int,
    ) -> Dict[str, Any]:
        if source.method == "unsupported":
            return {
                "source": source.label,
                "status": "unsupported",
                "headline_count": 0,
                "detail": "No official/public API feed configured for this platform.",
                "headlines": [],
            }

        try:
            if source.method == "rss":
                headlines = await self._fetch_rss(session, source.url or "", source.label, max_headlines)
            elif source.method == "google_news":
                headlines = await self._fetch_google_news(session, source.query or source.label, source.label, max_headlines)
            else:
                headlines = []
        except Exception as exc:
            return {
                "source": source.label,
                "status": "unavailable",
                "headline_count": 0,
                "detail": f"fetch_failed: {exc}",
                "headlines": [],
            }

        return {
            "source": source.label,
            "status": "collected" if headlines else "unavailable",
            "headline_count": len(headlines),
            "detail": "RSS collection complete" if headlines else "No recent items returned",
            "headlines": headlines,
        }

    async def _fetch_google_news(
        self,
        session: aiohttp.ClientSession,
        query: str,
        source_label: str,
        max_headlines: int,
    ) -> List[Dict[str, Any]]:
        encoded = quote_plus(f"{query} when:1d")
        url = (
            "https://news.google.com/rss/search"
            f"?q={encoded}&hl=en-US&gl=US&ceid=US:en"
        )
        return await self._fetch_rss(session, url, source_label, max_headlines)

    async def _fetch_rss(
        self,
        session: aiohttp.ClientSession,
        url: str,
        source_label: str,
        max_headlines: int,
    ) -> List[Dict[str, Any]]:
        if not url:
            return []

        async with session.get(url) as response:
            if response.status != 200:
                return []
            raw_xml = await response.text()

        return self._parse_rss_items(raw_xml, source_label, max_headlines)

    def _parse_rss_items(
        self,
        raw_xml: str,
        source_label: str,
        max_headlines: int,
    ) -> List[Dict[str, Any]]:
        try:
            root = ElementTree.fromstring(raw_xml)
        except ElementTree.ParseError:
            return []

        items: List[ElementTree.Element] = root.findall(".//item")
        # Basic Atom fallback.
        if not items:
            atom_ns = "{http://www.w3.org/2005/Atom}"
            items = root.findall(f".//{atom_ns}entry")

        parsed: List[Dict[str, Any]] = []
        for item in items[:max_headlines]:
            title = self._element_text(item, {"title"}) or "Market update"
            link = self._element_text(item, {"link"})
            if not link:
                link = item.attrib.get("href", "")
            published = (
                self._element_text(item, {"pubDate", "published", "updated"})
                or datetime.utcnow().isoformat()
            )
            normalized_time = self._normalize_timestamp(published)
            sentiment = self._headline_sentiment(title)
            impact = self._headline_impact(title)
            parsed.append(
                {
                    "source": source_label,
                    "title": title.strip(),
                    "url": link.strip(),
                    "published_at": normalized_time,
                    "impact": impact,
                    "sentiment": sentiment,
                }
            )
        return parsed

    def _element_text(
        self,
        node: ElementTree.Element,
        candidate_names: set[str],
    ) -> str:
        for child in list(node):
            local_name = child.tag.split("}")[-1]
            if local_name in candidate_names and child.text:
                return child.text.strip()
        # Some feeds place URL in <link href="..."/>.
        if "link" in candidate_names:
            for child in list(node):
                local_name = child.tag.split("}")[-1]
                if local_name == "link":
                    href = child.attrib.get("href")
                    if href:
                        return href.strip()
        return ""

    def _normalize_timestamp(self, raw_value: Any) -> str:
        if isinstance(raw_value, datetime):
            return raw_value.isoformat()
        if isinstance(raw_value, str):
            stripped = raw_value.strip()
            if not stripped:
                return datetime.utcnow().isoformat()
            try:
                return datetime.fromisoformat(stripped.replace("Z", "+00:00")).isoformat()
            except ValueError:
                pass
            try:
                return parsedate_to_datetime(stripped).isoformat()
            except Exception:
                return datetime.utcnow().isoformat()
        return datetime.utcnow().isoformat()

    def _headline_sentiment(self, text: str) -> float:
        lowered = (text or "").lower()
        positive_hits = sum(1 for token in self._POSITIVE_KEYWORDS if token in lowered)
        negative_hits = sum(1 for token in self._NEGATIVE_KEYWORDS if token in lowered)
        raw = positive_hits - negative_hits
        if raw == 0:
            return 0.0
        return max(-1.0, min(1.0, raw / 3.0))

    def _headline_impact(self, text: str) -> str:
        lowered = (text or "").lower()
        if any(token in lowered for token in self._HIGH_IMPACT_KEYWORDS):
            return "high"
        if "forex" in lowered or "currency" in lowered:
            return "medium"
        return "low"

    def _aggregate_sentiment(self, headlines: List[Dict[str, Any]]) -> float:
        weighted_sum = 0.0
        total_weight = 0.0
        for item in headlines:
            source = str(item.get("source", "")).strip()
            sentiment = float(item.get("sentiment", 0.0) or 0.0)
            weight = self._SOURCE_WEIGHT.get(source, 0.65)
            weighted_sum += sentiment * weight
            total_weight += weight
        if total_weight <= 0:
            return 0.0
        return weighted_sum / total_weight

    def _compute_consensus_score(
        self,
        chart_analysis: Dict[str, Any],
        sentiment_score: float,
        headlines: List[Dict[str, Any]],
    ) -> float:
        trend = str(chart_analysis.get("trend", "neutral")).lower()
        trend_component = {
            "bullish": 0.18,
            "bearish": -0.18,
            "neutral": 0.0,
        }.get(trend, 0.0)

        volatility = str(chart_analysis.get("volatility", "unknown")).lower()
        volatility_penalty = 0.08 if volatility == "high" else 0.0

        high_impact_count = sum(1 for h in headlines if h.get("impact") == "high")
        high_impact_component = min(high_impact_count, 5) * 0.03

        raw_score = 0.5 + trend_component + (sentiment_score * 0.42) + high_impact_component
        raw_score -= volatility_penalty
        return max(0.0, min(1.0, raw_score))

    def _confidence_band(self, consensus_score: float) -> str:
        if consensus_score >= 0.72:
            return "high"
        if consensus_score >= 0.5:
            return "medium"
        return "low"

    def _recommendation(self, consensus_score: float) -> str:
        if consensus_score >= 0.72:
            return "strong_signal"
        if consensus_score >= 0.5:
            return "watch_and_prepare"
        return "wait_for_confirmation"

    def _build_source_coverage(self, source_records: List[Dict[str, Any]]) -> Dict[str, Any]:
        requested = len(source_records)
        analyzed = len(
            [
                source
                for source in source_records
                if source.get("status") in {"collected", "derived"}
            ]
        )
        unsupported = [
            source.get("source")
            for source in source_records
            if source.get("status") == "unsupported"
        ]
        unavailable = [
            source.get("source")
            for source in source_records
            if source.get("status") == "unavailable"
        ]
        return {
            "requested": requested,
            "analyzed": analyzed,
            "coverage_ratio": round((analyzed / requested), 4) if requested else 0.0,
            "unsupported_sources": unsupported,
            "unavailable_sources": unavailable,
        }

    def _build_evidence_summary(
        self,
        chart_analysis: Dict[str, Any],
        source_records: List[Dict[str, Any]],
        consensus_score: float,
    ) -> str:
        coverage = self._build_source_coverage(source_records)
        trend = chart_analysis.get("trend", "neutral")
        volatility = chart_analysis.get("volatility", "unknown")
        return (
            f"Deep study checked {coverage['analyzed']}/{coverage['requested']} requested sources, "
            f"chart trend is {trend}, volatility is {volatility}, "
            f"consensus score is {consensus_score:.2f}."
        )

    def _select_top_headlines(
        self,
        headlines: List[Dict[str, Any]],
        limit: int = 8,
    ) -> List[Dict[str, Any]]:
        impact_rank = {"high": 3, "medium": 2, "low": 1}
        sorted_items = sorted(
            headlines,
            key=lambda item: (
                impact_rank.get(str(item.get("impact", "low")).lower(), 1),
                str(item.get("published_at", "")),
            ),
            reverse=True,
        )
        return sorted_items[:limit]
