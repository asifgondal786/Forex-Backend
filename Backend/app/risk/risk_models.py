"""
Tajir AI Risk Guardian — Pydantic Models
Phase 17
"""

from pydantic import BaseModel, Field, validator
from typing import Optional, Literal
from enum import Enum


# ─── Enums ────────────────────────────────────────────────────────────────────

class RiskDecision(str, Enum):
    APPROVE  = "approve"   # score 0–39
    WARN     = "warn"      # score 40–69
    BLOCK    = "block"     # score 70–100


class TrustLevel(str, Enum):
    OBSERVE        = "observe"
    ASSIST         = "assist"
    SEMI_AUTO      = "semi_auto"
    FULL_AUTO      = "full_auto"


class TradeDirection(str, Enum):
    BUY  = "buy"
    SELL = "sell"


# ─── Incoming Trade Request ────────────────────────────────────────────────────

class TradeRequest(BaseModel):
    user_id:        str
    symbol:         str                         # e.g. "EURUSD"
    direction:      TradeDirection
    lot_size:       float = Field(gt=0)
    leverage:       int   = Field(ge=1, le=500)
    stop_loss_pips: Optional[float] = None
    take_profit_pips: Optional[float] = None
    trust_level:    TrustLevel = TrustLevel.ASSIST
    source:         Literal["manual", "nlp", "signal", "autonomous"] = "manual"

    @validator("lot_size")
    def lot_size_precision(cls, v):
        return round(v, 2)


# ─── Account Snapshot (fetched from DB for scoring) ───────────────────────────

class AccountSnapshot(BaseModel):
    balance:            float
    equity:             float
    current_drawdown_pct: float = Field(ge=0, le=100)
    daily_loss_pct:     float = Field(ge=0, le=100)
    open_positions:     int   = Field(ge=0)
    win_rate_7d:        float = Field(ge=0, le=100)   # last 7 days win %
    consecutive_losses: int   = Field(ge=0)


# ─── Market Snapshot (from price feed) ────────────────────────────────────────

class MarketSnapshot(BaseModel):
    symbol:             str
    current_spread_pips: float
    atr_14:             float          # Average True Range
    is_news_window:     bool = False   # True = within ±30 min of high-impact news
    session:            Literal["sydney", "tokyo", "london", "new_york", "overlap", "dead"]
    volatility_index:   float = Field(ge=0, le=100)  # normalised 0–100


# ─── Sub-scores ───────────────────────────────────────────────────────────────

class PositionScore(BaseModel):
    score:         float   # 0–100
    flags:         list[str]
    lot_risk_pct:  float   # % of balance this lot risks
    margin_used:   float   # estimated margin in account currency


class AccountScore(BaseModel):
    score:  float
    flags:  list[str]


class MarketScore(BaseModel):
    score:  float
    flags:  list[str]


# ─── Guardian Decision ────────────────────────────────────────────────────────

class RiskGuardianResult(BaseModel):
    composite_score:    float = Field(ge=0, le=100)
    decision:           RiskDecision
    position_score:     PositionScore
    account_score:      AccountScore
    market_score:       MarketScore
    explanation:        str            # plain English, shown to user
    suggested_lot_size: Optional[float] = None   # if WARN, suggest safer size
    hard_limits_hit:    list[str]      # any absolute rule violations
    approved:           bool

    @property
    def color(self) -> str:
        if self.decision == RiskDecision.APPROVE:
            return "green"
        elif self.decision == RiskDecision.WARN:
            return "amber"
        return "red"