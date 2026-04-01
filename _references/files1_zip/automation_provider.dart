import 'package:flutter/foundation.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

enum AutoMode {
  manual,    // user controls everything
  assisted,  // AI suggests, user approves
  semiAuto,  // executes within guardrail limits
  fullyAuto, // AI trades autonomously
}

class LogEntry {
  final String id;
  final String pair;
  final String action; // e.g. 'BUY 0.1 lots'
  final String result; // e.g. '+$42.00' | 'Blocked: daily cap' | '-$18.00'
  final AutoMode triggeredBy;
  final DateTime timestamp;

  const LogEntry({
    required this.id,
    required this.pair,
    required this.action,
    required this.result,
    required this.triggeredBy,
    required this.timestamp,
  });
}

// ─── Provider ─────────────────────────────────────────────────────────────────

/// Manages automation mode, risk guardrails, auto-follow settings, and
/// a live execution log. There is intentionally no kill switch — mode
/// changes require deliberate user selection from [setMode].
class AutomationProvider extends ChangeNotifier {
  bool _isLoading = false;

  // Mode
  AutoMode _mode = AutoMode.manual;

  // Guardrails
  double _maxDrawdown = 20.0;   // percent
  double _dailyLossCap = 200.0; // USD
  int _maxOpenTrades = 5;

  // Auto-follow settings
  bool _autoFollowEnabled = false;
  bool _showAiReasoning = true;

  // Execution log
  List<LogEntry> _log = [];

  // ─── Getters ────────────────────────────────────────────────────────────

  bool get isLoading => _isLoading;
  AutoMode get mode => _mode;
  double get maxDrawdown => _maxDrawdown;
  double get dailyLossCap => _dailyLossCap;
  int get maxOpenTrades => _maxOpenTrades;
  bool get autoFollowEnabled => _autoFollowEnabled;
  bool get showAiReasoning => _showAiReasoning;
  List<LogEntry> get log => List.unmodifiable(_log);

  /// Whether any form of automation is currently active.
  bool get isAutomationActive =>
      _mode == AutoMode.semiAuto || _mode == AutoMode.fullyAuto;

  /// Human-readable label for the current mode.
  String get modeLabel {
    switch (_mode) {
      case AutoMode.manual:
        return 'Manual';
      case AutoMode.assisted:
        return 'Assisted';
      case AutoMode.semiAuto:
        return 'Semi-Auto';
      case AutoMode.fullyAuto:
        return 'Fully Auto';
    }
  }

  // ─── Init ───────────────────────────────────────────────────────────────

  /// Load execution log from backend. [token] is the auth bearer token.
  Future<void> loadLog(String token) async {
    _isLoading = true;
    notifyListeners();

    try {
      // TODO: replace with real API call using [token]
      await Future.delayed(const Duration(milliseconds: 500));
      _log = _mockLog();
    } catch (_) {
      // Log is non-critical; fail silently
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Mode ───────────────────────────────────────────────────────────────

  /// Switch automation mode. [token] is used to persist the change server-side.
  Future<void> setMode(AutoMode newMode, String token) async {
    if (_mode == newMode) return;
    _mode = newMode;
    notifyListeners();

    // TODO: PATCH /api/automation/mode with { mode: newMode.name, token }
    await Future.delayed(const Duration(milliseconds: 100));
  }

  // ─── Guardrails ──────────────────────────────────────────────────────────

  void setMaxDrawdown(double value) {
    _maxDrawdown = value.clamp(1, 50);
    notifyListeners();
    _syncGuardrails();
  }

  void setDailyLossCap(double value) {
    _dailyLossCap = value.clamp(10, 10000);
    notifyListeners();
    _syncGuardrails();
  }

  void setMaxOpenTrades(int value) {
    _maxOpenTrades = value.clamp(1, 20);
    notifyListeners();
    _syncGuardrails();
  }

  Future<void> _syncGuardrails() async {
    // TODO: PATCH /api/automation/guardrails with current values
    await Future.delayed(const Duration(milliseconds: 50));
  }

  // ─── Auto-follow ─────────────────────────────────────────────────────────

  void setAutoFollow(bool value) {
    if (_autoFollowEnabled == value) return;
    _autoFollowEnabled = value;
    notifyListeners();
  }

  void setShowAiReasoning(bool value) {
    if (_showAiReasoning == value) return;
    _showAiReasoning = value;
    notifyListeners();
  }

  // ─── Execution log ───────────────────────────────────────────────────────

  /// Append a new log entry. Called by TradeExecutionProvider after execution.
  void appendLog(LogEntry entry) {
    _log = [entry, ..._log];
    notifyListeners();
  }

  /// Checks whether an incoming auto-trade should be allowed or blocked
  /// based on current guardrails and open trade count.
  AutoTradeDecision evaluateAutoTrade({
    required int currentOpenCount,
    required double estimatedLoss,
    required double currentDrawdownPct,
  }) {
    if (!isAutomationActive) {
      return AutoTradeDecision(
          allowed: false, reason: 'Automation is not active');
    }
    if (currentOpenCount >= _maxOpenTrades) {
      return AutoTradeDecision(
          allowed: false,
          reason: 'Max open trades limit reached ($_maxOpenTrades)');
    }
    if (estimatedLoss > _dailyLossCap) {
      return AutoTradeDecision(
          allowed: false,
          reason: 'Exceeds daily loss cap (\$$_dailyLossCap)');
    }
    if (currentDrawdownPct > _maxDrawdown) {
      return AutoTradeDecision(
          allowed: false,
          reason: 'Drawdown limit exceeded ($_maxDrawdown%)');
    }
    return AutoTradeDecision(allowed: true);
  }

  // ─── Mock data (replace with API) ─────────────────────────────────────────

  List<LogEntry> _mockLog() {
    final now = DateTime.now();
    return [
      LogEntry(
        id: 'l_001',
        pair: 'EUR/USD',
        action: 'BUY 0.1 lots @ 1.0845',
        result: '+\$34.20',
        triggeredBy: AutoMode.semiAuto,
        timestamp: now.subtract(const Duration(minutes: 18)),
      ),
      LogEntry(
        id: 'l_002',
        pair: 'GBP/USD',
        action: 'SELL 0.05 lots @ 1.2630',
        result: 'Blocked: max open trades',
        triggeredBy: AutoMode.fullyAuto,
        timestamp: now.subtract(const Duration(hours: 1, minutes: 12)),
      ),
      LogEntry(
        id: 'l_003',
        pair: 'USD/JPY',
        action: 'BUY 0.2 lots @ 149.20',
        result: '+\$76.00',
        triggeredBy: AutoMode.semiAuto,
        timestamp: now.subtract(const Duration(hours: 3)),
      ),
      LogEntry(
        id: 'l_004',
        pair: 'AUD/USD',
        action: 'SELL 0.1 lots @ 0.6510',
        result: '-\$22.40',
        triggeredBy: AutoMode.assisted,
        timestamp: now.subtract(const Duration(hours: 6)),
      ),
      LogEntry(
        id: 'l_005',
        pair: 'EUR/GBP',
        action: 'BUY 0.05 lots @ 0.8560',
        result: 'Blocked: drawdown limit',
        triggeredBy: AutoMode.fullyAuto,
        timestamp: now.subtract(const Duration(days: 1)),
      ),
    ];
  }
}

// ─── Decision model ───────────────────────────────────────────────────────────

class AutoTradeDecision {
  final bool allowed;
  final String? reason;

  const AutoTradeDecision({required this.allowed, this.reason});
}
