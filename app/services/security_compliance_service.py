"""
Security & Compliance Models
Handles API security, audit logs, and legal compliance
"""
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from enum import Enum
import hashlib
import json


class APIKeyScope(Enum):
    """API key permission scopes"""
    READ_ONLY = "read_only"
    TRADE_ONLY = "trade_only"  # Cannot withdraw funds
    FULL_ACCESS = "full_access"


class AuditActionType(Enum):
    """Types of auditable actions"""
    TRADE_EXECUTED = "trade_executed"
    TRADE_CANCELLED = "trade_cancelled"
    KILL_SWITCH_ACTIVATED = "kill_switch_activated"
    RISK_LIMIT_CHANGED = "risk_limit_changed"
    API_KEY_CREATED = "api_key_created"
    API_KEY_REVOKED = "api_key_revoked"
    CREDENTIALS_ACCESSED = "credentials_accessed"
    AUTOMATION_ENABLED = "automation_enabled"
    AUTOMATION_DISABLED = "automation_disabled"
    PAPER_MODE_TOGGLED = "paper_mode_toggled"


class ComplianceStatus(Enum):
    """Compliance status"""
    COMPLIANT = "compliant"
    WARNING = "warning"
    VIOLATION = "violation"


@dataclass
class APIKeyCredential:
    """Secure API key management"""
    key_id: str
    user_id: str
    broker: str  # "forex.com", "oanda", etc.
    created_at: datetime
    last_used: Optional[datetime] = None
    expires_at: Optional[datetime] = None
    scope: APIKeyScope = APIKeyScope.TRADE_ONLY
    is_active: bool = True
    
    # Encrypted storage (never store raw keys)
    key_hash: str = ""  # SHA256 hash of encrypted key
    
    # Usage statistics
    total_trades_executed: int = 0
    api_calls_made: int = 0


@dataclass
class AuditLogEntry:
    """Audit log for compliance"""
    log_id: str
    user_id: str
    action: AuditActionType
    timestamp: datetime
    
    # Action details
    pair: Optional[str] = None
    trade_id: Optional[str] = None
    quantity: Optional[float] = None
    price: Optional[float] = None
    
    # Actor information
    api_key_id: Optional[str] = None
    ip_address: Optional[str] = None
    session_id: Optional[str] = None
    
    # Status
    success: bool = True
    error_message: Optional[str] = None
    
    # Additional context
    metadata: Dict = field(default_factory=dict)


@dataclass
class UserLegalAcknowledgement:
    """Legal compliance acknowledgement"""
    acknowledgement_id: str
    user_id: str
    timestamp: datetime
    
    # Acknowledged items
    risk_disclaimer_accepted: bool = False
    trading_losses_understood: bool = False
    autonomous_trading_authorized: bool = False
    api_key_usage_acknowledged: bool = False
    data_privacy_accepted: bool = False
    terms_of_service_accepted: bool = False
    
    # Signature (digital)
    signature_hash: Optional[str] = None
    ip_address: Optional[str] = None
    
    # Version tracking
    agreement_version: str = "1.0"
    expiry_date: Optional[datetime] = None


@dataclass
class ComplianceReport:
    """Generate compliance status"""
    user_id: str
    report_date: datetime
    status: ComplianceStatus
    
    # Metrics
    daily_trade_count: int
    daily_volume: float
    unusual_activity: bool
    
    # Risk assessment
    current_drawdown: float
    leverage_usage: float
    account_equity: float
    
    # Optional fields (with defaults)
    violations_detected: List[str] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)


class SecurityComplianceService:
    """
    Comprehensive security and compliance management
    """
    
    def __init__(self):
        self.api_keys: Dict[str, APIKeyCredential] = {}
        self.audit_logs: List[AuditLogEntry] = []
        self.legal_acknowledgements: Dict[str, UserLegalAcknowledgement] = {}
        self.compliance_alerts: Dict[str, List[str]] = {}

    # ========================================================================
    # API KEY MANAGEMENT
    # ========================================================================

    async def create_api_key(
        self,
        user_id: str,
        broker: str,
        scope: str = "trade_only",
        expires_in_days: Optional[int] = 365
    ) -> Dict:
        """
        Create a new API key credential
        NEVER stores raw credentials - only encrypted hashes
        """
        
        key_id = f"key_{user_id}_{datetime.now().timestamp()}"
        
        # In production: encrypt the API key before storing
        # For now: store hash
        dummy_key = f"{broker}_{user_id}_{key_id}"
        key_hash = hashlib.sha256(dummy_key.encode()).hexdigest()
        
        expires_at = None
        if expires_in_days:
            expires_at = datetime.now() + timedelta(days=expires_in_days)
        
        api_key = APIKeyCredential(
            key_id=key_id,
            user_id=user_id,
            broker=broker,
            scope=APIKeyScope[scope.upper()],
            created_at=datetime.now(),
            expires_at=expires_at,
            key_hash=key_hash
        )
        
        self.api_keys[key_id] = api_key
        
        # Log the action
        await self._log_audit(
            user_id=user_id,
            action=AuditActionType.API_KEY_CREATED,
            success=True,
            metadata={
                "broker": broker,
                "scope": scope,
                "key_id": key_id[:20] + "..."  # Masked
            }
        )
        
        return {
            "success": True,
            "key_id": key_id,
            "broker": broker,
            "scope": scope,
            "expires_at": expires_at.isoformat() if expires_at else None,
            "message": "API key created successfully. Store the key securely - it won't be shown again.",
            "warning": "NEVER share this key or commit to version control"
        }

    async def revoke_api_key(self, key_id: str, user_id: str) -> Dict:
        """Revoke an API key"""
        if key_id not in self.api_keys:
            return {"error": "API key not found"}
        
        api_key = self.api_keys[key_id]
        if api_key.user_id != user_id:
            return {"error": "Unauthorized"}
        
        api_key.is_active = False
        
        await self._log_audit(
            user_id=user_id,
            action=AuditActionType.API_KEY_REVOKED,
            success=True,
            metadata={"key_id": key_id[:20] + "..."}
        )
        
        return {
            "success": True,
            "message": f"API key {key_id} revoked",
            "timestamp": datetime.now().isoformat()
        }

    async def get_user_api_keys(self, user_id: str) -> List[Dict]:
        """Get all API keys for a user (censored)"""
        user_keys = [k for k in self.api_keys.values() if k.user_id == user_id]
        
        return [
            {
                "key_id": k.key_id[:20] + "...",
                "broker": k.broker,
                "scope": k.scope.value,
                "created_at": k.created_at.isoformat(),
                "expires_at": k.expires_at.isoformat() if k.expires_at else "Never",
                "is_active": k.is_active,
                "last_used": k.last_used.isoformat() if k.last_used else "Never",
                "api_calls": k.api_calls_made,
            }
            for k in user_keys
        ]

    # ========================================================================
    # AUDIT LOGGING
    # ========================================================================

    async def _log_audit(
        self,
        user_id: str,
        action: AuditActionType,
        success: bool = True,
        error_message: Optional[str] = None,
        pair: Optional[str] = None,
        trade_id: Optional[str] = None,
        metadata: Optional[Dict] = None
    ) -> str:
        """Log an auditable action"""
        log_id = f"audit_{user_id}_{datetime.now().timestamp()}"
        
        entry = AuditLogEntry(
            log_id=log_id,
            user_id=user_id,
            action=action,
            timestamp=datetime.now(),
            pair=pair,
            trade_id=trade_id,
            success=success,
            error_message=error_message,
            metadata=metadata or {}
        )
        
        self.audit_logs.append(entry)
        
        # Alert on critical actions
        if action in [
            AuditActionType.KILL_SWITCH_ACTIVATED,
            AuditActionType.API_KEY_REVOKED,
            AuditActionType.CREDENTIALS_ACCESSED
        ]:
            if user_id not in self.compliance_alerts:
                self.compliance_alerts[user_id] = []
            self.compliance_alerts[user_id].append(f"[SECURITY] {action.value} at {datetime.now().isoformat()}")
        
        return log_id

    async def log_trade_execution(
        self,
        user_id: str,
        trade_id: str,
        pair: str,
        action: str,
        quantity: float,
        price: float
    ) -> str:
        """Log a trade execution"""
        return await self._log_audit(
            user_id=user_id,
            action=AuditActionType.TRADE_EXECUTED,
            pair=pair,
            trade_id=trade_id,
            success=True,
            metadata={
                "action": action,
                "quantity": quantity,
                "price": price
            }
        )

    async def get_audit_log(self, user_id: str, limit: int = 50, days: int = 30) -> List[Dict]:
        """Get audit log for a user"""
        cutoff_date = datetime.now() - timedelta(days=days)
        
        logs = [
            l for l in self.audit_logs
            if l.user_id == user_id and l.timestamp > cutoff_date
        ]
        
        logs = sorted(logs, key=lambda x: x.timestamp, reverse=True)[:limit]
        
        return [
            {
                "log_id": l.log_id,
                "action": l.action.value,
                "timestamp": l.timestamp.isoformat(),
                "success": l.success,
                "pair": l.pair,
                "trade_id": l.trade_id[:20] + "..." if l.trade_id else None,
                "error_message": l.error_message,
            }
            for l in logs
        ]

    # ========================================================================
    # LEGAL COMPLIANCE
    # ========================================================================

    async def create_legal_acknowledgement(
        self,
        user_id: str,
        ip_address: str,
        risk_disclaimer: bool = True,
        losses_understood: bool = True,
        autonomous_trading: bool = True,
        api_usage: bool = True,
        privacy: bool = True,
        terms: bool = True
    ) -> Dict:
        """
        Create legal acknowledgement for compliance
        User must explicitly accept all risks and terms
        """
        
        if not all([risk_disclaimer, losses_understood, autonomous_trading, api_usage, privacy, terms]):
            return {
                "success": False,
                "error": "All acknowledgements must be accepted to proceed"
            }
        
        ack_id = f"ack_{user_id}_{datetime.now().timestamp()}"
        
        acknowledgement = UserLegalAcknowledgement(
            acknowledgement_id=ack_id,
            user_id=user_id,
            timestamp=datetime.now(),
            risk_disclaimer_accepted=risk_disclaimer,
            trading_losses_understood=losses_understood,
            autonomous_trading_authorized=autonomous_trading,
            api_key_usage_acknowledged=api_usage,
            data_privacy_accepted=privacy,
            terms_of_service_accepted=terms,
            ip_address=ip_address,
            expiry_date=datetime.now() + timedelta(days=365)
        )
        
        self.legal_acknowledgements[user_id] = acknowledgement
        
        # Log the action
        await self._log_audit(
            user_id=user_id,
            action=AuditActionType.AUTOMATION_ENABLED,
            metadata={"acknowledgement_id": ack_id}
        )
        
        return {
            "success": True,
            "acknowledgement_id": ack_id,
            "message": "Legal acknowledgements accepted. Autonomous trading enabled.",
            "timestamp": datetime.now().isoformat(),
            "valid_until": acknowledgement.expiry_date.isoformat()
        }

    async def get_legal_status(self, user_id: str) -> Dict:
        """Get legal compliance status"""
        ack = self.legal_acknowledgements.get(user_id)
        
        if not ack:
            return {
                "compliant": False,
                "message": "Legal acknowledgements not completed",
                "action_required": "Complete legal agreement before enabling automation"
            }
        
        is_valid = ack.expiry_date > datetime.now() if ack.expiry_date else True
        
        return {
            "compliant": is_valid,
            "acknowledged_at": ack.timestamp.isoformat(),
            "valid_until": ack.expiry_date.isoformat() if ack.expiry_date else None,
            "items_accepted": {
                "risk_disclaimer": ack.risk_disclaimer_accepted,
                "losses_understood": ack.trading_losses_understood,
                "autonomous_trading": ack.autonomous_trading_authorized,
                "api_usage": ack.api_key_usage_acknowledged,
                "privacy": ack.data_privacy_accepted,
                "terms": ack.terms_of_service_accepted,
            }
        }

    # ========================================================================
    # COMPLIANCE REPORTING
    # ========================================================================

    async def generate_compliance_report(self, user_id: str) -> Dict:
        """Generate comprehensive compliance report"""
        logs = [l for l in self.audit_logs if l.user_id == user_id]
        violations = []
        warnings = []
        
        # Check for suspicious patterns
        trades_today = len([l for l in logs if l.action == AuditActionType.TRADE_EXECUTED and
                           (datetime.now() - l.timestamp).days == 0])
        
        if trades_today > 20:
            warnings.append(f"High trade frequency today: {trades_today} trades")
        
        # Check for multiple kill switch activations
        kill_switches = len([l for l in logs if l.action == AuditActionType.KILL_SWITCH_ACTIVATED and
                            (datetime.now() - l.timestamp).days <= 7])
        
        if kill_switches > 2:
            violations.append("Multiple kill switch activations detected")
        
        # Check legal status
        legal_status = await self.get_legal_status(user_id)
        
        report = ComplianceReport(
            user_id=user_id,
            report_date=datetime.now(),
            status=ComplianceStatus.COMPLIANT if legal_status["compliant"] else ComplianceStatus.WARNING,
            daily_trade_count=trades_today,
            daily_volume=0,  # Would calculate from trade logs
            unusual_activity=len(warnings) > 0,
            violations_detected=violations,
            warnings=warnings,
            current_drawdown=0,
            leverage_usage=0,
            account_equity=0
        )
        
        return {
            "status": report.status.value,
            "report_date": report.report_date.isoformat(),
            "summary": {
                "daily_trades": report.daily_trade_count,
                "unusual_activity": report.unusual_activity,
                "violations": len(report.violations_detected),
                "warnings": len(report.warnings),
            },
            "details": {
                "violations": report.violations_detected,
                "warnings": report.warnings,
                "legal_compliant": legal_status["compliant"],
            },
            "audit_trail_size": len([l for l in logs if l.user_id == user_id]),
        }

    async def get_security_dashboard(self, user_id: str) -> Dict:
        """Get security & compliance dashboard"""
        api_keys = await self.get_user_api_keys(user_id)
        legal_status = await self.get_legal_status(user_id)
        alerts = self.compliance_alerts.get(user_id, [])
        
        return {
            "security_status": {
                "api_keys_active": len([k for k in api_keys if k["is_active"]]),
                "legal_compliant": legal_status["compliant"],
                "security_alerts": len(alerts),
            },
            "api_keys": api_keys,
            "legal_status": legal_status,
            "recent_alerts": alerts[-5:],  # Last 5 alerts
            "audit_log_link": "/api/compliance/audit-log"
        }
