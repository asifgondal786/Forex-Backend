import pathlib, textwrap

path = pathlib.Path(r"D:\Tajir\Backend\app\services\nlp_command_service.py")

code = textwrap.dedent('''\
    """
    NLP Command Service - parses natural language trade commands.
    Uses AI Router (Claude + DeepSeek with fallback).
    """
    import re
    import json
    import logging
    from typing import Any, Optional

    from app.ai.ai_router import route as ai_route

    logger = logging.getLogger(__name__)

    _PAIRS = [
        "EUR/USD", "GBP/USD", "USD/JPY", "USD/CHF", "AUD/USD",
        "NZD/USD", "USD/CAD", "EUR/GBP", "EUR/JPY", "GBP/JPY",
        "EUR/AUD", "EUR/CHF", "AUD/JPY", "CHF/JPY", "CAD/JPY",
        "NZD/JPY", "GBP/CHF", "GBP/AUD", "AUD/NZD", "XAU/USD",
    ]

    _pair_alts = "|".join(p.replace("/", "[/\\\\\\\\s]?") for p in _PAIRS)
    _PAIR_PATTERN = re.compile(r"\\b(" + _pair_alts + r")\\b", re.IGNORECASE)


    def _extract_pair(text: str) -> Optional[str]:
        cleaned = text.upper().replace("\\\", "/").replace(" ", "")
        m = _PAIR_PATTERN.search(cleaned)
        if m:
            raw = m.group(1).replace(" ", "").upper()
            if "/" not in raw and len(raw) == 6:
                raw = raw[:3] + "/" + raw[3:]
            return raw
        return None
''')

path.write_text(code, encoding="utf-8")
print("Done")
