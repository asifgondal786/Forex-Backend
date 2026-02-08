from typing import Optional

from pydantic import BaseModel, Field, ConfigDict


class HeaderUser(BaseModel):
    id: str
    name: str
    status: str = "Available Online"
    avatar_url: Optional[str] = None
    risk_level: str = "Moderate"


class HeaderBalance(BaseModel):
    amount: float = 0.0
    currency: str = "USD"


class HeaderNotifications(BaseModel):
    unread: int = 0


class HeaderStream(BaseModel):
    enabled: bool = False
    interval: int = 10


class HeaderResponse(BaseModel):
    user: HeaderUser
    balance: HeaderBalance
    notifications: HeaderNotifications
    stream: HeaderStream


class HeaderUpdateRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    name: Optional[str] = None
    status: Optional[str] = None
    avatar_url: Optional[str] = Field(default=None, alias="avatarUrl")
    risk_level: Optional[str] = Field(default=None, alias="riskLevel")
    balance_amount: Optional[float] = Field(default=None, alias="balanceAmount")
    balance_currency: Optional[str] = Field(default=None, alias="balanceCurrency")
    notifications_unread: Optional[int] = Field(default=None, alias="notificationsUnread")


class HeaderStreamUpdateRequest(BaseModel):
    enabled: Optional[bool] = None
    interval: Optional[int] = Field(default=None, ge=1, le=3600)
