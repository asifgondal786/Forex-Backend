// lib/providers/automation_provider.dart
//
// Manages agent mode state, kill-switch, and today's trading stats.
// Calls ApiService for all backend interactions.

import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class AutomationProvider with ChangeNotifier {
  // ── Mode state ──────────────────────────────────────────────────────────
  bool _semiEnabled  = false;
  bool _fullyEnabled = false;

  // ── Loading flags ───────────────────────────────────────────────────────
  bool _isSemiLoading  = false;
  bool _isFullyLoading = false;
  bool _isKillLoading  = false;

  // ── Today's stats (from backend) ────────────────────────────────────────
  int    _tradesToday    = 0;
  int    _signalsToday   = 0;
  int    _blockedToday   = 0;
  int    _openPositions  = 0;
  double _pnlToday       = 0.0;

  // ── Error ───────────────────────────────────────────────────────────────
  String? _lastError;

  // ── Getters ─────────────────────────────────────────────────────────────
  bool    get semiEnabled    => _semiEnabled;
  bool    get fullyEnabled   => _fullyEnabled;
  bool    get isSemiLoading  => _isSemiLoading;
  bool    get isFullyLoading => _isFullyLoading;
  bool    get isKillLoading  => _isKillLoading;
  int     get tradesToday    => _tradesToday;
  int     get signalsToday   => _signalsToday;
  int     get blockedToday   => _blockedToday;
  int     get openPositions  => _openPositions;
  double  get pnlToday       => _pnlToday;
  String? get lastError      => _lastError;

  // ── Internal ApiService reference ───────────────────────────────────────
  // Resolved lazily from Provider tree — caller passes it in for actions.
  // For simplicity, we accept an optional ApiService on the methods that
  // need it; the screen passes context.read<ApiService>() each time.

  // ── Status refresh ───────────────────────────────────────────────────────
  Future<void> refreshStatus([ApiService? api]) async {
    try {
      if (api == null) return; // no-op when called without service (boot)
      final data = await api.getFeaturesStatus();
      final autonomous = data['features']?['autonomous_actions'];
      if (autonomous is Map) {
        _semiEnabled  = autonomous['semi_active']  as bool? ?? _semiEnabled;
        _fullyEnabled = autonomous['fully_active'] as bool? ?? _fullyEnabled;
      }
      final stats = data['agent_stats'];
      if (stats is Map) {
        _tradesToday   = (stats['trades_today']   as num?)?.toInt()    ?? 0;
        _signalsToday  = (stats['signals_today']  as num?)?.toInt()    ?? 0;
        _blockedToday  = (stats['blocked_today']  as num?)?.toInt()    ?? 0;
        _openPositions = (stats['open_positions'] as num?)?.toInt()    ?? 0;
        _pnlToday      = (stats['pnl_today']      as num?)?.toDouble() ?? 0.0;
      }
      _lastError = null;
    } catch (e) {
      if (kDebugMode) debugPrint('AutomationProvider.refreshStatus: $e');
      // Non-fatal — keep last known state, don't surface error to UI
    }
    notifyListeners();
  }

  // ── Semi-Autonomous ──────────────────────────────────────────────────────
  Future<void> enableSemiAutonomous([ApiService? api]) async {
    if (_isSemiLoading) return;
    _isSemiLoading = true;
    _lastError     = null;
    notifyListeners();

    try {
      if (api != null) {
        await api.setNotificationPreferences(autonomousMode: true);
      }
      _semiEnabled  = true;
      _fullyEnabled = false; // mutually exclusive
    } catch (e) {
      _lastError = _friendlyError(e);
      if (kDebugMode) debugPrint('enableSemiAutonomous: $e');
    } finally {
      _isSemiLoading = false;
      notifyListeners();
    }
  }

  Future<void> disableSemiAutonomous([ApiService? api]) async {
    if (_isSemiLoading) return;
    _isSemiLoading = true;
    _lastError     = null;
    notifyListeners();

    try {
      if (api != null) {
        await api.setNotificationPreferences(autonomousMode: false);
      }
      _semiEnabled = false;
    } catch (e) {
      _lastError = _friendlyError(e);
    } finally {
      _isSemiLoading = false;
      notifyListeners();
    }
  }

  // ── Fully Autonomous ─────────────────────────────────────────────────────
  Future<void> enableFullyAutonomous([ApiService? api]) async {
    if (_isFullyLoading) return;
    _isFullyLoading = true;
    _lastError      = null;
    notifyListeners();

    try {
      if (api != null) {
        // POST /agent/start via configureAutonomyGuardrails
        await api.configureAutonomyGuardrails(
          level:   'full',
          profile: 'conservative',
        );
      }
      _fullyEnabled = true;
      _semiEnabled  = false; // mutually exclusive
    } catch (e) {
      _lastError = _friendlyError(e);
      if (kDebugMode) debugPrint('enableFullyAutonomous: $e');
    } finally {
      _isFullyLoading = false;
      notifyListeners();
    }
  }

  Future<void> disableFullyAutonomous([ApiService? api]) async {
    if (_isFullyLoading) return;
    _isFullyLoading = true;
    _lastError      = null;
    notifyListeners();

    try {
      if (api != null) {
        await api.configureAutonomyGuardrails(level: 'off');
      }
      _fullyEnabled = false;
    } catch (e) {
      _lastError = _friendlyError(e);
    } finally {
      _isFullyLoading = false;
      notifyListeners();
    }
  }

  // ── Kill-switch ──────────────────────────────────────────────────────────
  Future<void> activateKillSwitch([ApiService? api]) async {
    if (_isKillLoading) return;
    _isKillLoading = true;
    _lastError     = null;
    notifyListeners();

    try {
      if (api != null) {
        await api.activateKillSwitch();
      }
      _semiEnabled  = false;
      _fullyEnabled = false;
    } catch (e) {
      _lastError = _friendlyError(e);
      if (kDebugMode) debugPrint('activateKillSwitch: $e');
      // Still disable locally even if backend call fails — safety first
      _semiEnabled  = false;
      _fullyEnabled = false;
    } finally {
      _isKillLoading = false;
      notifyListeners();
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('Authentication') || msg.contains('401')) {
      return 'Session expired — please log in again.';
    }
    if (msg.contains('broker') || msg.contains('connection')) {
      return 'Broker connection required. Connect in Settings.';
    }
    if (msg.contains('timeout') || msg.contains('Timeout')) {
      return 'Request timed out. Check your connection and try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}