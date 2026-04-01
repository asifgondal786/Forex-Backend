"""
TAJIR BACKEND — Phase 17 Integration Guide
===========================================
Add these lines to app/main.py to register the 4 new routers.
Then update lib/services/api_service.dart with the endpoint constants below.
"""

# ─── Add to app/main.py ───────────────────────────────────────────────────────

MAIN_PY_ADDITIONS = """
# Phase 17+ — New feature routers
from app.automation_routes  import router as automation_router
from app.portfolio_routes   import router as portfolio_router
from app.trade_routes       import router as trade_router
from app.beginner_routes    import router as beginner_router
from app.notification_routes import router as notification_router_v2

# Register (add after existing router.include_router calls)
app.include_router(automation_router)
app.include_router(portfolio_router)
app.include_router(trade_router)
app.include_router(beginner_router)
app.include_router(notification_router_v2)
"""

# ─── New endpoint reference ────────────────────────────────────────────────────
"""
AUTOMATION (AutomationProvider)
  GET    /api/v1/automation/mode            → get current mode
  PATCH  /api/v1/automation/mode            → setMode()
  GET    /api/v1/automation/guardrails      → get guardrails
  PATCH  /api/v1/automation/guardrails      → setMaxDrawdown/setDailyLossCap/setMaxOpenTrades()
  PATCH  /api/v1/automation/settings        → setAutoFollow/setShowAiReasoning()
  GET    /api/v1/automation/log             → loadLog()  → List<LogEntry>
  POST   /api/v1/automation/evaluate        → evaluateAutoTrade()

PORTFOLIO (PortfolioProvider)
  GET    /api/v1/portfolio/all              → loadAll()  → stats + open + history
  GET    /api/v1/portfolio/stats            → PortfolioStats
  GET    /api/v1/portfolio/trades/open      → List<OpenTrade>
  POST   /api/v1/portfolio/trades/open/{id}/close → closeTrade()
  GET    /api/v1/portfolio/trades/history   → List<ClosedTrade>
  POST   /api/v1/portfolio/mark-to-market   → markToMarket(prices)

TRADE EXECUTION (TradeExecutionProvider)
  POST   /api/v1/trades/paper/open          → executeTrade() → creates OpenTrade
  POST   /api/v1/trades/paper/close/{id}    → closeTrade()
  GET    /api/v1/trades/paper/open          → list open trades

BEGINNER MODE (BeginnerModeProvider)
  GET    /api/v1/beginner/settings          → load() settings from server
  PATCH  /api/v1/beginner/settings          → setEnabled/setDailyLossCap/setMaxLeverage()
  POST   /api/v1/beginner/record-loss       → recordLoss(loss)
  POST   /api/v1/beginner/check-trade       → checkTrade(leverage, loss)
  POST   /api/v1/beginner/risk/kelly        → Kelly criterion calculator
  POST   /api/v1/beginner/risk/drawdown     → Drawdown calculator
  POST   /api/v1/beginner/risk/stress       → Stress test calculator

NOTIFICATIONS (NotificationProvider)
  GET    /api/v1/notifications              → load(token) → List<AppNotification>
  PATCH  /api/v1/notifications/{id}/read   → markRead(id)
  POST   /api/v1/notifications/read-all    → markAllRead()
  DELETE /api/v1/notifications/{id}        → dismiss(id)
  GET    /api/v1/notifications/unread-count → unreadCount badge
  POST   /api/v1/notifications/push-token  → grantPushPermission() / register FCM token
"""

# ─── api_service.dart — methods to add ────────────────────────────────────────
"""
Add these methods to ApiService. All use _buildHeaders() for auth.

// ── Automation ──────────────────────────────────────────────────────────────

Future<Map<String, dynamic>> getAutomationMode() async {
  final resp = await _client.get(
    Uri.parse('$_base/api/v1/automation/mode'),
    headers: _buildHeaders(),
  );
  return jsonDecode(resp.body);
}

Future<void> setAutomationMode(String mode) async {
  await _client.patch(
    Uri.parse('$_base/api/v1/automation/mode'),
    headers: _buildHeaders(),
    body: jsonEncode({'mode': mode}),
  );
}

Future<Map<String, dynamic>> getGuardrails() async {
  final resp = await _client.get(
    Uri.parse('$_base/api/v1/automation/guardrails'),
    headers: _buildHeaders(),
  );
  return jsonDecode(resp.body);
}

Future<void> updateGuardrails({
  double? maxDrawdownPct,
  double? dailyLossCapUsd,
  int? maxOpenTrades,
}) async {
  final body = <String, dynamic>{};
  if (maxDrawdownPct != null) body['max_drawdown_pct'] = maxDrawdownPct;
  if (dailyLossCapUsd != null) body['daily_loss_cap_usd'] = dailyLossCapUsd;
  if (maxOpenTrades != null) body['max_open_trades'] = maxOpenTrades;
  await _client.patch(
    Uri.parse('$_base/api/v1/automation/guardrails'),
    headers: _buildHeaders(),
    body: jsonEncode(body),
  );
}

Future<Map<String, dynamic>> getAutomationLog({int limit = 50}) async {
  final resp = await _client.get(
    Uri.parse('$_base/api/v1/automation/log?limit=$limit'),
    headers: _buildHeaders(),
  );
  return jsonDecode(resp.body);
}

// ── Portfolio ───────────────────────────────────────────────────────────────

Future<Map<String, dynamic>> loadPortfolioAll() async {
  final resp = await _client.get(
    Uri.parse('$_base/api/v1/portfolio/all'),
    headers: _buildHeaders(),
  );
  return jsonDecode(resp.body);
}

Future<bool> closeTrade(String tradeId) async {
  final resp = await _client.post(
    Uri.parse('$_base/api/v1/portfolio/trades/open/$tradeId/close'),
    headers: _buildHeaders(),
  );
  return resp.statusCode == 200;
}

Future<void> markToMarket(Map<String, double> prices) async {
  await _client.post(
    Uri.parse('$_base/api/v1/portfolio/mark-to-market'),
    headers: _buildHeaders(),
    body: jsonEncode({'prices': prices}),
  );
}

// ── Trade Execution ─────────────────────────────────────────────────────────

Future<Map<String, dynamic>> openPaperTrade({
  required String pair,
  required String direction,
  required double lotSize,
  required double leverage,
  double? stopLoss,
  double? takeProfit,
  double? entryPrice,
}) async {
  final resp = await _client.post(
    Uri.parse('$_base/api/v1/trades/paper/open'),
    headers: _buildHeaders(),
    body: jsonEncode({
      'pair':        pair,
      'direction':   direction.toLowerCase(),
      'lot_size':    lotSize,
      'leverage':    leverage,
      if (stopLoss != null)    'stop_loss':    stopLoss,
      if (takeProfit != null)  'take_profit':  takeProfit,
      if (entryPrice != null)  'entry_price':  entryPrice,
    }),
  );
  return jsonDecode(resp.body);
}

// ── Beginner Mode ───────────────────────────────────────────────────────────

Future<Map<String, dynamic>> getBeginnerSettings() async {
  final resp = await _client.get(
    Uri.parse('$_base/api/v1/beginner/settings'),
    headers: _buildHeaders(),
  );
  return jsonDecode(resp.body);
}

Future<void> updateBeginnerSettings({
  bool? isEnabled,
  double? dailyLossCap,
  double? maxLeverage,
}) async {
  final body = <String, dynamic>{};
  if (isEnabled != null)    body['is_enabled']     = isEnabled;
  if (dailyLossCap != null) body['daily_loss_cap'] = dailyLossCap;
  if (maxLeverage != null)  body['max_leverage']   = maxLeverage;
  await _client.patch(
    Uri.parse('$_base/api/v1/beginner/settings'),
    headers: _buildHeaders(),
    body: jsonEncode(body),
  );
}

Future<Map<String, dynamic>> computeKelly({
  required double winRatePct,
  required double winLossRatio,
}) async {
  final resp = await _client.post(
    Uri.parse('$_base/api/v1/beginner/risk/kelly'),
    headers: _buildHeaders(),
    body: jsonEncode({
      'win_rate_pct':   winRatePct,
      'win_loss_ratio': winLossRatio,
    }),
  );
  return jsonDecode(resp.body);
}

// ── Notifications ───────────────────────────────────────────────────────────

Future<Map<String, dynamic>> getNotifications({
  String category = 'all',
  int limit = 50,
}) async {
  final resp = await _client.get(
    Uri.parse('$_base/api/v1/notifications?category=$category&limit=$limit'),
    headers: _buildHeaders(),
  );
  return jsonDecode(resp.body);
}

Future<void> markNotificationRead(String id) async {
  await _client.patch(
    Uri.parse('$_base/api/v1/notifications/$id/read'),
    headers: _buildHeaders(),
  );
}

Future<void> markAllNotificationsRead() async {
  await _client.post(
    Uri.parse('$_base/api/v1/notifications/read-all'),
    headers: _buildHeaders(),
  );
}

Future<void> dismissNotification(String id) async {
  await _client.delete(
    Uri.parse('$_base/api/v1/notifications/$id'),
    headers: _buildHeaders(),
  );
}

Future<int> getUnreadCount() async {
  final resp = await _client.get(
    Uri.parse('$_base/api/v1/notifications/unread-count'),
    headers: _buildHeaders(),
  );
  final data = jsonDecode(resp.body);
  return data['unread_count'] as int;
}

Future<void> registerPushToken(String token, {String platform = 'web'}) async {
  await _client.post(
    Uri.parse('$_base/api/v1/notifications/push-token'),
    headers: _buildHeaders(),
    body: jsonEncode({'token': token, 'platform': platform}),
  );
}
"""
