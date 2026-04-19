import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const _kPrefEnabled = 'beginner_mode_enabled';
const _kPrefDailyLossCap = 'beginner_daily_loss_cap';
const _kPrefMaxLeverage = 'beginner_max_leverage';
const _kPrefDailyLossUsed = 'beginner_daily_loss_used';
const _kPrefLastResetDate = 'beginner_last_reset_date';

// ─── Provider ─────────────────────────────────────────────────────────────────

/// Manages beginner-mode settings with full SharedPreferences persistence.
///
/// Guards:
///   • Daily loss cap — blocks new trades when accumulated loss hits the cap.
///   • Leverage guard  — warns / blocks trades above [maxLeverage].
///
/// Call [load()] once at app start (wired in main.dart via `..load()`).
class BeginnerModeProvider extends ChangeNotifier {
  bool _isEnabled = false;
  double _dailyLossCap = 100.0; // USD
  double _maxLeverage = 10.0;
  double _dailyLossUsed = 0.0; // accumulated loss for today
  DateTime? _lastResetDate;

  // Transient state (not persisted)
  double _currentLeverage = 1.0; // updated by TradeSetupSheet

  // ─── Getters ────────────────────────────────────────────────────────────

  bool get isEnabled => _isEnabled;
  double get dailyLossCap => _dailyLossCap;
  double get maxLeverage => _maxLeverage;
  double get dailyLossUsed => _dailyLossUsed;
  double get dailyLossRemaining =>
      (_dailyLossCap - _dailyLossUsed).clamp(0, _dailyLossCap);

  /// True when today's losses have hit or exceeded the daily cap.
  bool get isDailyLossCapReached =>
      _isEnabled && _dailyLossUsed >= _dailyLossCap;

  /// True when the currently-configured leverage exceeds [maxLeverage].
  bool get isHighLeverage =>
      _isEnabled && _currentLeverage > _maxLeverage;

  /// Percentage of the daily cap consumed (0.0 – 1.0).
  double get dailyCapProgress =>
      _dailyLossCap == 0 ? 0 : (_dailyLossUsed / _dailyLossCap).clamp(0, 1);

  // ─── Persistence ────────────────────────────────────────────────────────

  /// Load all settings from SharedPreferences. Call once at startup.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    _isEnabled = prefs.getBool(_kPrefEnabled) ?? false;
    _dailyLossCap = prefs.getDouble(_kPrefDailyLossCap) ?? 100.0;
    _maxLeverage = prefs.getDouble(_kPrefMaxLeverage) ?? 10.0;
    _dailyLossUsed = prefs.getDouble(_kPrefDailyLossUsed) ?? 0.0;

    final lastResetStr = prefs.getString(_kPrefLastResetDate);
    _lastResetDate =
        lastResetStr != null ? DateTime.tryParse(lastResetStr) : null;

    _maybeResetDailyLoss();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefEnabled, _isEnabled);
    await prefs.setDouble(_kPrefDailyLossCap, _dailyLossCap);
    await prefs.setDouble(_kPrefMaxLeverage, _maxLeverage);
    await prefs.setDouble(_kPrefDailyLossUsed, _dailyLossUsed);
    await prefs.setString(
        _kPrefLastResetDate, DateTime.now().toIso8601String());
  }

  /// Resets the daily loss counter when a new calendar day starts.
  void _maybeResetDailyLoss() {
    final now = DateTime.now();
    if (_lastResetDate == null ||
        _lastResetDate!.year != now.year ||
        _lastResetDate!.month != now.month ||
        _lastResetDate!.day != now.day) {
      _dailyLossUsed = 0;
      _lastResetDate = now;
    }
  }

  // ─── Setters ────────────────────────────────────────────────────────────

  Future<void> setEnabled(bool value) async {
    if (_isEnabled == value) return;
    _isEnabled = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setDailyLossCap(double value) async {
    if (_dailyLossCap == value) return;
    _dailyLossCap = value.clamp(10, 10000);
    notifyListeners();
    await _persist();
  }

  Future<void> setMaxLeverage(double value) async {
    if (_maxLeverage == value) return;
    _maxLeverage = value.clamp(1, 100);
    notifyListeners();
    await _persist();
  }

  // ─── Runtime guards ──────────────────────────────────────────────────────

  /// Called by trade setup to check current leverage. Updates [isHighLeverage].
  void updateCurrentLeverage(double leverage) {
    if (_currentLeverage == leverage) return;
    _currentLeverage = leverage;
    notifyListeners();
  }

  /// Called by TradeExecutionProvider after a trade closes with a loss.
  /// [loss] should be a positive number representing dollars lost.
  Future<void> recordLoss(double loss) async {
    if (!_isEnabled || loss <= 0) return;
    _maybeResetDailyLoss();
    _dailyLossUsed += loss;
    notifyListeners();
    await _persist();
  }

  /// Returns false and blocks the trade if the daily cap has been reached
  /// or if leverage exceeds the max. Use in TradeExecutionProvider.
  TradeGuardResult checkTrade({required double leverage, required double loss}) {
    if (!_isEnabled) return TradeGuardResult.allowed;

    _maybeResetDailyLoss();

    if (_dailyLossUsed + loss > _dailyLossCap) {
      return TradeGuardResult.blockedDailyCap;
    }
    if (leverage > _maxLeverage) {
      return TradeGuardResult.warnHighLeverage;
    }
    return TradeGuardResult.allowed;
  }

  /// Resets the daily loss counter manually (e.g., for testing).
  Future<void> resetDailyLoss() async {
    _dailyLossUsed = 0;
    _lastResetDate = DateTime.now();
    notifyListeners();
    await _persist();
  }
}

// ─── Guard result enum ────────────────────────────────────────────────────────

enum TradeGuardResult {
  allowed,
  warnHighLeverage,
  blockedDailyCap,
}

