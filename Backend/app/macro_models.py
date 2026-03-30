"""
Tajir Macro Event Shield â€” Models
Phase 18
"""

from pydantic import BaseModel, Field
from typing import Optional, Literal
from datetime import datetime
from enum import Enum


# â”€â”€â”€ Enums â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class EventImpact(str, Enum):
    HIGH   = "high"
    MEDIUM = "medium"
    LOW    = "low"


class AlertChannel(str, Enum):
    WHATSAPP = "whatsapp"
    SMS      = "sms"
    PUSH     = "push"


class AlertStatus(str, Enum):
    PENDING   = "pending"
    SENT      = "sent"
    FAILED    = "failed"


# â”€â”€â”€ Economic Event â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class MacroEvent(BaseModel):
    id:           Optional[str] = None          # Supabase UUID after insert
    title:        str                           # e.g. "Non-Farm Payrolls"
    currency:     str                           # "USD" | "EUR" | "GBP" | "JPY"
    impact:       EventImpact
    event_time:   datetime                      # UTC
    forecast:     Optional[str] = None
    previous:     Optional[str] = None
    actual:       Optional[str] = None          # populated after release
    source:       str = "forexfactory"
    fetched_at:   Optional[datetime] = None


# â”€â”€â”€ Window Check Result â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class NewsWindowResult(BaseModel):
    is_blocked:       bool
    symbol:           str
    affected_currency: Optional[str] = None    # which leg triggered the block
    event:            Optional[MacroEvent] = None
    minutes_to_event: Optional[float] = None   # negative = event already started
    window_ends_at:   Optional[datetime] = None
    reason:           str                       # plain English


# â”€â”€â”€ Alert Payload â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class EventAlert(BaseModel):
    user_id:   str
    event:     MacroEvent
    channel:   AlertChannel
    message:   str
    status:    AlertStatus = AlertStatus.PENDING
    sent_at:   Optional[datetime] = None
    error:     Optional[str] = None


# â”€â”€â”€ API Response Models â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class UpcomingEventsResponse(BaseModel):
    events:       list[MacroEvent]
    fetched_at:   datetime
    next_refresh: datetime


class ShieldStatusResponse(BaseModel):
    symbol:        str
    window_result: NewsWindowResult
    upcoming:      list[MacroEvent]   # next 3 events for affected currencies