"""
Natural Language Processing Service
Converts human commands into structured trading tasks
Example: "Sell USD when it hits 289 with 1% stop-loss" → Structured order
"""
from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple
from enum import Enum
import re


class CommandType(Enum):
    """Types of commands AI can understand"""
    BUY_ORDER = "buy_order"
    SELL_ORDER = "sell_order"
    SET_ALERT = "set_alert"
    ENABLE_AUTOMATION = "enable_automation"
    DISABLE_AUTOMATION = "disable_automation"
    GET_ANALYSIS = "get_analysis"
    PAPER_TRADE = "paper_trade"
    STOP_ALL = "stop_all"
    GET_STATUS = "get_status"


@dataclass
class ParsedCommand:
    """Structured representation of a natural language command"""
    command_type: CommandType
    confidence: float  # 0-1, how confident is the parsing
    parameters: Dict  # Extracted parameters
    original_text: str
    suggestions: Optional[List[str]] = None  # Clarification suggestions if low confidence


class NaturalLanguageService:
    """
    Parse natural language commands into structured trading tasks
    Makes the app feel like a true AI copilot
    """
    
    def __init__(self):
        self.command_history: List[ParsedCommand] = []
        self.custom_phrases: Dict[str, CommandType] = {}

    async def parse_command(self, text: str) -> ParsedCommand:
        """
        Parse natural language command
        Examples:
        - "Sell USD at 289 PKR with 1% stop-loss"
        - "Buy EUR/USD when RSI drops below 30"
        - "Show me bullish predictions"
        - "Stop all trading immediately"
        """
        
        text_lower = text.lower().strip()
        
        # Keyword matching
        if any(word in text_lower for word in ["stop", "kill", "halt", "freeze"]):
            return await self._parse_stop_command(text)
        
        if any(word in text_lower for word in ["buy", "long", "bullish"]):
            return await self._parse_buy_command(text)
        
        if any(word in text_lower for word in ["sell", "short", "bearish"]):
            return await self._parse_sell_command(text)
        
        if any(word in text_lower for word in ["alert", "notify", "notify me"]):
            return await self._parse_alert_command(text)
        
        if any(word in text_lower for word in ["enable", "turn on", "activate"]):
            return await self._parse_enable_command(text)
        
        if any(word in text_lower for word in ["disable", "turn off", "deactivate"]):
            return await self._parse_disable_command(text)
        
        if any(word in text_lower for word in ["analysis", "analyze", "predict", "forecast"]):
            return await self._parse_analysis_command(text)
        
        if any(word in text_lower for word in ["status", "position", "open", "balance"]):
            return await self._parse_status_command(text)
        
        if any(word in text_lower for word in ["paper", "backtest", "simulation"]):
            return await self._parse_paper_trade_command(text)
        
        # Default: low confidence
        return ParsedCommand(
            command_type=CommandType.GET_ANALYSIS,
            confidence=0.3,
            parameters={},
            original_text=text,
            suggestions=[
                "Try: 'Sell EUR/USD at 1.1050 with 0.5% stop loss'",
                "Try: 'Buy GBP/USD when RSI < 30'",
                "Try: 'Show me predictions for USD/JPY'",
                "Try: 'Enable automation for EUR/USD'"
            ]
        )

    async def _parse_buy_command(self, text: str) -> ParsedCommand:
        """Parse buy order from natural language"""
        params = {
            "action": "BUY",
            "pair": None,
            "trigger_price": None,
            "entry_price": None,
            "stop_loss": None,
            "take_profit": None,
            "position_size": None,
        }
        
        # Extract currency pair
        pair_match = re.search(r'(EUR/USD|GBP/USD|USD/JPY|AUD/USD|USD/CHF|NZD/USD|USD/CAD|GBP/JPY|EUR/GBP)', text, re.IGNORECASE)
        if pair_match:
            params["pair"] = pair_match.group(1).upper()
        else:
            # Try to find currency pair pattern
            currency_match = re.search(r'([A-Z]{3})[/\s]?([A-Z]{3})', text)
            if currency_match:
                params["pair"] = f"{currency_match.group(1)}/{currency_match.group(2)}"
        
        # Extract prices
        price_matches = re.findall(r'(\d+\.?\d*)', text)
        if price_matches:
            prices = [float(p) for p in price_matches]
            if len(prices) >= 1:
                params["entry_price"] = prices[0]
            if len(prices) >= 2:
                params["stop_loss"] = prices[1]
            if len(prices) >= 3:
                params["take_profit"] = prices[2]
        
        # Extract stop loss percentage
        sl_percent = re.search(r'(\d+\.?\d*)\s*%\s*(?:stop|sl)', text, re.IGNORECASE)
        if sl_percent:
            params["stop_loss_percent"] = float(sl_percent.group(1))
        
        # Extract take profit percentage
        tp_percent = re.search(r'(\d+\.?\d*)\s*%\s*(?:take|profit|tp)', text, re.IGNORECASE)
        if tp_percent:
            params["take_profit_percent"] = float(tp_percent.group(1))
        
        # Extract when condition
        when_match = re.search(r'when\s+([a-zA-Z0-9\s<>=\.]+)', text, re.IGNORECASE)
        if when_match:
            params["condition"] = when_match.group(1).strip()
        
        confidence = 0.9 if params["pair"] else 0.5
        
        return ParsedCommand(
            command_type=CommandType.BUY_ORDER,
            confidence=confidence,
            parameters=params,
            original_text=text
        )

    async def _parse_sell_command(self, text: str) -> ParsedCommand:
        """Parse sell order from natural language"""
        params = await self._parse_buy_command(text)
        params.parameters["action"] = "SELL"
        params.command_type = CommandType.SELL_ORDER
        return params

    async def _parse_alert_command(self, text: str) -> ParsedCommand:
        """Parse alert setup from natural language"""
        params = {
            "pair": None,
            "trigger_price": None,
            "trigger_type": "price_level",  # or "indicator_value"
            "condition": None,
        }
        
        # Extract pair
        pair_match = re.search(r'(EUR/USD|GBP/USD|USD/JPY|AUD/USD|USD/CHF)', text, re.IGNORECASE)
        if pair_match:
            params["pair"] = pair_match.group(1).upper()
        
        # Extract price
        price_matches = re.findall(r'(\d+\.?\d*)', text)
        if price_matches:
            params["trigger_price"] = float(price_matches[0])
        
        # Extract condition
        if "above" in text.lower() or "rises" in text.lower():
            params["condition"] = "above"
        elif "below" in text.lower() or "drops" in text.lower():
            params["condition"] = "below"
        elif "reaches" in text.lower() or "hits" in text.lower():
            params["condition"] = "equals"
        
        return ParsedCommand(
            command_type=CommandType.SET_ALERT,
            confidence=0.85 if params["pair"] else 0.5,
            parameters=params,
            original_text=text
        )

    async def _parse_stop_command(self, text: str) -> ParsedCommand:
        """Parse stop/kill command"""
        return ParsedCommand(
            command_type=CommandType.STOP_ALL,
            confidence=0.95,
            parameters={"action": "kill_switch"},
            original_text=text
        )

    async def _parse_enable_command(self, text: str) -> ParsedCommand:
        """Parse enable automation command"""
        params = {"target": None, "pairs": []}
        
        if "automation" in text.lower():
            params["target"] = "automation"
        
        # Extract pairs
        pair_pattern = r'(EUR/USD|GBP/USD|USD/JPY|AUD/USD|USD/CHF|NZD/USD|USD/CAD)'
        params["pairs"] = re.findall(pair_pattern, text, re.IGNORECASE)
        
        return ParsedCommand(
            command_type=CommandType.ENABLE_AUTOMATION,
            confidence=0.9,
            parameters=params,
            original_text=text
        )

    async def _parse_disable_command(self, text: str) -> ParsedCommand:
        """Parse disable automation command"""
        params = {"target": None}
        
        if "automation" in text.lower():
            params["target"] = "automation"
        
        return ParsedCommand(
            command_type=CommandType.DISABLE_AUTOMATION,
            confidence=0.9,
            parameters=params,
            original_text=text
        )

    async def _parse_analysis_command(self, text: str) -> ParsedCommand:
        """Parse analysis/prediction request"""
        params = {
            "analysis_type": "general",  # or "technical", "sentiment", "news"
            "pairs": [],
            "timeframe": None,
        }
        
        # Determine analysis type
        if "technical" in text.lower() or "indicator" in text.lower():
            params["analysis_type"] = "technical"
        elif "sentiment" in text.lower() or "mood" in text.lower():
            params["analysis_type"] = "sentiment"
        elif "news" in text.lower() or "economic" in text.lower():
            params["analysis_type"] = "news"
        
        # Extract pairs
        pair_pattern = r'(EUR/USD|GBP/USD|USD/JPY|AUD/USD|USD/CHF|NZD/USD|USD/CAD)'
        params["pairs"] = re.findall(pair_pattern, text, re.IGNORECASE)
        
        # Extract timeframe
        timeframe_match = re.search(r'(4h|1h|15m|30m|1d|4d|1w)', text, re.IGNORECASE)
        if timeframe_match:
            params["timeframe"] = timeframe_match.group(1).lower()
        
        return ParsedCommand(
            command_type=CommandType.GET_ANALYSIS,
            confidence=0.88,
            parameters=params,
            original_text=text
        )

    async def _parse_status_command(self, text: str) -> ParsedCommand:
        """Parse status/information request"""
        params = {"query_type": "general"}
        
        if "position" in text.lower():
            params["query_type"] = "positions"
        elif "balance" in text.lower() or "equity" in text.lower():
            params["query_type"] = "balance"
        elif "open" in text.lower():
            params["query_type"] = "open_trades"
        
        return ParsedCommand(
            command_type=CommandType.GET_STATUS,
            confidence=0.92,
            parameters=params,
            original_text=text
        )

    async def _parse_paper_trade_command(self, text: str) -> ParsedCommand:
        """Parse paper trading command"""
        params = {
            "mode": "backtest",
            "pairs": [],
            "period": None,
        }
        
        pair_pattern = r'(EUR/USD|GBP/USD|USD/JPY|AUD/USD|USD/CHF)'
        params["pairs"] = re.findall(pair_pattern, text, re.IGNORECASE)
        
        period_match = re.search(r'(last\s+)?(\d+)\s*(day|week|month)', text, re.IGNORECASE)
        if period_match:
            params["period"] = f"{period_match.group(2)} {period_match.group(3)}"
        
        return ParsedCommand(
            command_type=CommandType.PAPER_TRADE,
            confidence=0.87,
            parameters=params,
            original_text=text
        )

    async def execute_parsed_command(self, parsed: ParsedCommand) -> Dict:
        """
        Execute a parsed command
        Returns what action to take
        """
        
        if parsed.confidence < 0.6:
            return {
                "success": False,
                "confidence": parsed.confidence,
                "message": "Command not clearly understood",
                "suggestions": parsed.suggestions or [
                    "Please be more specific",
                    "Try examples from the help menu"
                ]
            }
        
        # Return structured action
        return {
            "success": True,
            "confidence": parsed.confidence,
            "command_type": parsed.command_type.value,
            "parameters": parsed.parameters,
            "action": self._get_action_for_command(parsed.command_type),
            "next_steps": self._get_next_steps(parsed.command_type, parsed.parameters)
        }

    def _get_action_for_command(self, cmd_type: CommandType) -> str:
        """Get action to execute"""
        actions = {
            CommandType.BUY_ORDER: "Create buy order",
            CommandType.SELL_ORDER: "Create sell order",
            CommandType.SET_ALERT: "Set price alert",
            CommandType.ENABLE_AUTOMATION: "Enable automated trading",
            CommandType.DISABLE_AUTOMATION: "Disable automated trading",
            CommandType.GET_ANALYSIS: "Generate AI analysis",
            CommandType.PAPER_TRADE: "Run paper trading simulation",
            CommandType.STOP_ALL: "ACTIVATE KILL SWITCH",
            CommandType.GET_STATUS: "Fetch account status",
        }
        return actions.get(cmd_type, "Unknown action")

    def _get_next_steps(self, cmd_type: CommandType, params: Dict) -> List[str]:
        """Get next steps for user confirmation"""
        
        if cmd_type == CommandType.BUY_ORDER or cmd_type == CommandType.SELL_ORDER:
            steps = [
                f"1. Confirm {params.get('action')} on {params.get('pair')}",
                f"2. Entry: {params.get('entry_price')}",
                f"3. Stop Loss: {params.get('stop_loss')} or {params.get('stop_loss_percent')}%",
                f"4. Take Profit: {params.get('take_profit')} or {params.get('take_profit_percent')}%",
                "5. Verify conditions and execute"
            ]
            return steps
        
        elif cmd_type == CommandType.SET_ALERT:
            return [
                f"1. Alert on {params.get('pair')} when {params.get('condition')} {params.get('trigger_price')}",
                "2. You'll receive notifications when triggered",
                "3. Alert will remain active until dismissed"
            ]
        
        elif cmd_type == CommandType.STOP_ALL:
            return [
                "⚠️ CRITICAL ACTION - Are you sure?",
                "1. All open trades will be closed",
                "2. All pending orders will be cancelled",
                "3. Automation will be disabled",
                "4. This action cannot be undone immediately"
            ]
        
        return ["Preparing to execute..."]

    async def get_command_examples(self) -> Dict:
        """Get example commands for users"""
        return {
            "trading": [
                "Buy EUR/USD at 1.1050 with 0.5% stop loss",
                "Sell USD/JPY when RSI < 30 with 25 pips stop",
                "Buy GBP/USD at 1.2500 when London opens",
                "Take profit at 1.1150 on my EUR trade"
            ],
            "alerts": [
                "Notify me when EUR/USD rises above 1.1100",
                "Alert on USD/JPY if it drops below 105",
                "High impact news alert for USD events"
            ],
            "automation": [
                "Enable automation for EUR/USD",
                "Start paper trading EUR and GBP pairs",
                "Analyze predictions for all pairs"
            ],
            "status": [
                "Show my open positions",
                "What's my account balance?",
                "How many trades today?"
            ],
            "emergency": [
                "Stop all trading NOW",
                "Close everything",
                "Kill switch"
            ]
        }

    async def generate_nlp_response(self, parsed: ParsedCommand, execution_result: Dict) -> str:
        """
        Generate natural language response to user
        Makes interaction feel conversational
        """
        
        if not execution_result.get("success"):
            return f"I couldn't understand that command. {execution_result.get('message')}"
        
        cmd_type = parsed.command_type
        
        if cmd_type == CommandType.BUY_ORDER:
            return f"✅ Buy order ready! {parsed.parameters.get('pair')} at {parsed.parameters.get('entry_price')}. Stop at {parsed.parameters.get('stop_loss')}. Ready to execute?"
        
        elif cmd_type == CommandType.SELL_ORDER:
            return f"✅ Sell order ready! {parsed.parameters.get('pair')} at {parsed.parameters.get('entry_price')}. Stop at {parsed.parameters.get('stop_loss')}. Execute?"
        
        elif cmd_type == CommandType.SET_ALERT:
            return f"🔔 Alert set! I'll notify you when {parsed.parameters.get('pair')} {parsed.parameters.get('condition')} {parsed.parameters.get('trigger_price')}"
        
        elif cmd_type == CommandType.STOP_ALL:
            return "🛑 KILL SWITCH ACTIVATED! All trading stopped. All positions will be closed."
        
        elif cmd_type == CommandType.ENABLE_AUTOMATION:
            return f"🤖 Automation enabled for {', '.join(parsed.parameters.get('pairs', []))}. I'll handle trades while you sleep!"
        
        elif cmd_type == CommandType.GET_ANALYSIS:
            return f"📊 Analyzing {', '.join(parsed.parameters.get('pairs', ['all pairs']))}... Reports ready in a moment!"
        
        return "✅ Command processed!"
