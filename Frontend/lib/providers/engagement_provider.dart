// lib/providers/engagement_provider.dart
//
// Manages Phase B engagement data: AI activity feed, confidence history, alerts.
// Fetches from backend engagement endpoints with graceful fallback to mock data.

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

// =============================================================================
// Models
// =============================================================================

class AIActivity {
  final String id;
  final String type; // 'scan', 'evaluate', 'monitor', 'alert', 'decision'
  final String message;
  final DateTime timestamp;
  final String emoji;
  final String? color; // hex string

  const AIActivity({
    required this.id,
    required this.type,
    required this.message,
    required this.timestamp,
    required this.emoji,
    this.color,
  });

  factory AIActivity.fromJson(Map<String, dynamic> j) => AIActivity(
        id: j['id']?.toString() ?? '',
        type: j['type']?.toString() ?? 'scan',
        message: j['message']?.toString() ?? '',
        timestamp: DateTime.tryParse(j['timestamp']?.toString() ?? '') ??
            DateTime.now(),
        emoji: j['icon']?.toString() ?? j['emoji']?.toString() ?? '📊',
        color: j['color']?.toString(),
      );

  String get relativeTime {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class ConfidenceHistory {
  final double current;
  final String trend; // 'up', 'down', 'stable'
  final double change24h;
  final String reason;
  final List<double> historical;

  const ConfidenceHistory({
    required this.current,
    required this.trend,
    required this.change24h,
    required this.reason,
    required this.historical,
  });

  factory ConfidenceHistory.fromJson(Map<String, dynamic> j) =>
      ConfidenceHistory(
        current: (j['current'] as num?)?.toDouble() ?? 75.0,
        trend: j['trend']?.toString() ?? 'stable',
        change24h: (j['change_24h'] as num?)?.toDouble() ?? 0.0,
        reason: j['reason']?.toString() ?? 'Market conditions nominal.',
        historical: (j['historical'] as List?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            [70, 72, 73, 74, 75, 75, 75],
      );

  factory ConfidenceHistory.mock() => const ConfidenceHistory(
        current: 78.0,
        trend: 'up',
        change24h: 4.0,
        reason: 'Technical signals aligning with institutional flow.',
        historical: [68, 70, 72, 74, 75, 77, 78],
      );
}

class AIAlert {
  final String id;
  final String type;
  final String emoji;
  final String title;
  final String message;
  final String severity; // 'info', 'warning', 'success'
  final DateTime timestamp;
  bool isDismissed;

  AIAlert({
    required this.id,
    required this.type,
    required this.emoji,
    required this.title,
    required this.message,
    required this.severity,
    required this.timestamp,
    this.isDismissed = false,
  });

  factory AIAlert.fromJson(Map<String, dynamic> j) => AIAlert(
        id: j['id']?.toString() ?? '',
        type: j['type']?.toString() ?? 'info',
        emoji: j['icon']?.toString() ?? j['emoji']?.toString() ?? '🛡️',
        title: j['title']?.toString() ?? '',
        message: j['message']?.toString() ?? '',
        severity: j['severity']?.toString() ?? 'info',
        timestamp: DateTime.tryParse(j['timestamp']?.toString() ?? '') ??
            DateTime.now(),
      );
}

// =============================================================================
// Provider
// =============================================================================

class EngagementProvider extends ChangeNotifier {
  final ApiService _api;

  EngagementProvider({required ApiService apiService}) : _api = apiService;

  // ── State ──────────────────────────────────────────────────────────────────

  List<AIActivity> _activities = [];
  ConfidenceHistory? _confidence;
  List<AIAlert> _alerts = [];

  bool _loadingActivities = false;
  bool _loadingConfidence = false;
  bool _loadingAlerts = false;

  String? _activitiesError;
  String? _confidenceError;
  String? _alertsError;

  Timer? _refreshTimer;
  bool _disposed = false;

  // ── Getters ────────────────────────────────────────────────────────────────

  List<AIActivity> get activities => _activities;
  ConfidenceHistory? get confidence => _confidence;
  List<AIAlert> get activeAlerts =>
      _alerts.where((a) => !a.isDismissed).toList();

  bool get isLoadingActivities => _loadingActivities;
  bool get isLoadingConfidence => _loadingConfidence;
  bool get isLoadingAlerts => _loadingAlerts;

  String? get activitiesError => _activitiesError;
  String? get confidenceError => _confidenceError;
  String? get alertsError => _alertsError;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> init() async {
    await Future.wait([
      fetchActivities(),
      fetchConfidence(),
      fetchAlerts(),
    ]);
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_disposed) {
        fetchActivities();
        fetchConfidence();
        fetchAlerts();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ── Fetch: Activity Feed ───────────────────────────────────────────────────

  Future<void> fetchActivities({int limit = 10}) async {
    if (_disposed) return;
    _loadingActivities = true;
    _activitiesError = null;
    notifyListeners();

    try {
      final data = await _api.getAIActivityFeed(limit: limit);
      if (_disposed) return;
      final list = data['activities'] as List? ?? [];
      _activities = list
          .whereType<Map<String, dynamic>>()
          .map(AIActivity.fromJson)
          .toList();
    } catch (e) {
      if (_disposed) return;
      _activitiesError = e.toString();
      // Fallback to mock data so UI always has content
      if (_activities.isEmpty) _activities = _mockActivities();
    } finally {
      if (!_disposed) {
        _loadingActivities = false;
        notifyListeners();
      }
    }
  }

  // ── Fetch: Confidence History ──────────────────────────────────────────────

  Future<void> fetchConfidence({String period = '24h'}) async {
    if (_disposed) return;
    _loadingConfidence = true;
    _confidenceError = null;
    notifyListeners();

    try {
      final data = await _api.getAIConfidenceHistory(period: period);
      if (_disposed) return;
      _confidence = ConfidenceHistory.fromJson(data);
    } catch (e) {
      if (_disposed) return;
      _confidenceError = e.toString();
      _confidence ??= ConfidenceHistory.mock();
    } finally {
      if (!_disposed) {
        _loadingConfidence = false;
        notifyListeners();
      }
    }
  }

  // ── Fetch: Alerts ──────────────────────────────────────────────────────────

  Future<void> fetchAlerts() async {
    if (_disposed) return;
    _loadingAlerts = true;
    _alertsError = null;
    notifyListeners();

    try {
      final data = await _api.getAIAlerts();
      if (_disposed) return;
      final list = data['alerts'] as List? ?? [];
      _alerts = list
          .whereType<Map<String, dynamic>>()
          .map(AIAlert.fromJson)
          .toList();
    } catch (e) {
      if (_disposed) return;
      _alertsError = e.toString();
      if (_alerts.isEmpty) _alerts = _mockAlerts();
    } finally {
      if (!_disposed) {
        _loadingAlerts = false;
        notifyListeners();
      }
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void dismissAlert(String alertId) {
    final idx = _alerts.indexWhere((a) => a.id == alertId);
    if (idx >= 0) {
      _alerts[idx].isDismissed = true;
      notifyListeners();
    }
  }

  // ── Mock data (fallback when backend unavailable) ──────────────────────────

  List<AIActivity> _mockActivities() {
    final now = DateTime.now();
    return [
      AIActivity(
        id: 'mock_1',
        type: 'scan',
        message: 'Scanning EUR/USD for breakout confirmation',
        timestamp: now.subtract(const Duration(minutes: 2)),
        emoji: '📊',
      ),
      AIActivity(
        id: 'mock_2',
        type: 'monitor',
        message: 'Monitoring US CPI news release (1h away)',
        timestamp: now.subtract(const Duration(minutes: 5)),
        emoji: '📰',
      ),
      AIActivity(
        id: 'mock_3',
        type: 'alert',
        message: 'Tightened risk exposure due to volatility spike',
        timestamp: now.subtract(const Duration(minutes: 8)),
        emoji: '🔔',
      ),
      AIActivity(
        id: 'mock_4',
        type: 'evaluate',
        message: 'Evaluating GBP/USD against historical patterns',
        timestamp: now.subtract(const Duration(minutes: 12)),
        emoji: '🧠',
      ),
      AIActivity(
        id: 'mock_5',
        type: 'decision',
        message: 'No trades executed — user safety limits maintained',
        timestamp: now.subtract(const Duration(minutes: 18)),
        emoji: '✅',
      ),
    ];
  }

  List<AIAlert> _mockAlerts() {
    return [
      AIAlert(
        id: 'mock_alert_1',
        type: 'volatility',
        emoji: '🛡️',
        title: 'Capital Protection Active',
        message: 'Volatility increased 12% — AI tightened risk exposure.',
        severity: 'info',
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
      AIAlert(
        id: 'mock_alert_2',
        type: 'news',
        emoji: '📰',
        title: 'High-Impact News Approaching',
        message: 'US CPI release in 2h — AI staying alert.',
        severity: 'warning',
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
      ),
    ];
  }
}
