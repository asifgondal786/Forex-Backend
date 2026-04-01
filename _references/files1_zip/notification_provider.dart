import 'package:flutter/foundation.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

enum NotifCategory { all, trades, risk, market, ai }

class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotifCategory category;
  final DateTime timestamp;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.timestamp,
    this.isRead = false,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        body: body,
        category: category,
        timestamp: timestamp,
        isRead: isRead ?? this.isRead,
      );
}

// ─── Provider ─────────────────────────────────────────────────────────────────

class NotificationProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _pushPermissionGranted = false;
  NotifCategory _selectedCategory = NotifCategory.all;
  List<AppNotification> _notifications = [];

  bool get isLoading => _isLoading;
  bool get pushPermissionGranted => _pushPermissionGranted;
  NotifCategory get selectedCategory => _selectedCategory;
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  /// Unread count across all categories (shown as badge in bottom nav).
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Notifications filtered by [_selectedCategory].
  List<AppNotification> get filtered {
    if (_selectedCategory == NotifCategory.all) return _notifications;
    return _notifications
        .where((n) => n.category == _selectedCategory)
        .toList();
  }

  /// Load notifications from backend. [token] is the auth token.
  Future<void> load(String token) async {
    _isLoading = true;
    notifyListeners();

    try {
      // TODO: replace with real API call using [token]
      await Future.delayed(const Duration(milliseconds: 500));
      _notifications = _mockNotifications();
    } catch (_) {
      // Silently fail — notifications are non-critical
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Called when an FCM push payload arrives.
  /// Adds the notification to the top of the list and bumps unread count.
  void onFcmMessage({
    required String id,
    required String title,
    required String body,
    required String categoryKey, // 'trades' | 'risk' | 'market' | 'ai'
  }) {
    final cat = _categoryFromKey(categoryKey);
    final notif = AppNotification(
      id: id,
      title: title,
      body: body,
      category: cat,
      timestamp: DateTime.now(),
    );
    _notifications = [notif, ..._notifications];
    notifyListeners();
  }

  /// Change the active filter chip.
  void setCategory(NotifCategory cat) {
    if (_selectedCategory == cat) return;
    _selectedCategory = cat;
    notifyListeners();
  }

  /// Mark a single notification as read.
  void markRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx == -1 || _notifications[idx].isRead) return;
    final updated = List<AppNotification>.from(_notifications);
    updated[idx] = updated[idx].copyWith(isRead: true);
    _notifications = updated;
    notifyListeners();
  }

  /// Mark all notifications as read.
  void markAllRead() {
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
  }

  /// Swipe-to-dismiss: remove a notification by id.
  void dismiss(String id) {
    _notifications = _notifications.where((n) => n.id != id).toList();
    notifyListeners();
  }

  /// Simulate granting push notification permission (iOS/Android flow).
  /// In production: call `firebase_messaging` requestPermission here.
  Future<void> grantPushPermission() async {
    // TODO: await FirebaseMessaging.instance.requestPermission();
    await Future.delayed(const Duration(milliseconds: 200));
    _pushPermissionGranted = true;
    notifyListeners();
  }

  // ─── Private helpers ───────────────────────────────────────────────────────

  NotifCategory _categoryFromKey(String key) {
    switch (key) {
      case 'trades':
        return NotifCategory.trades;
      case 'risk':
        return NotifCategory.risk;
      case 'market':
        return NotifCategory.market;
      case 'ai':
        return NotifCategory.ai;
      default:
        return NotifCategory.all;
    }
  }

  // ─── Mock data (replace with API) ─────────────────────────────────────────

  List<AppNotification> _mockNotifications() {
    final now = DateTime.now();
    return [
      AppNotification(
        id: 'n_001',
        title: 'EUR/USD Signal Detected',
        body: 'AI detected a BUY opportunity on EUR/USD with 82% confidence. RSI divergence at key support.',
        category: NotifCategory.ai,
        timestamp: now.subtract(const Duration(minutes: 3)),
      ),
      AppNotification(
        id: 'n_002',
        title: 'Trade Closed — +\$76.00',
        body: 'Your USD/JPY BUY was closed at 149.580. Realized P&L: +\$76.00.',
        category: NotifCategory.trades,
        timestamp: now.subtract(const Duration(hours: 1)),
        isRead: true,
      ),
      AppNotification(
        id: 'n_003',
        title: '⚠️ Daily Loss Cap Warning',
        body: 'You have reached 80% of your daily loss cap (\$80 of \$100). Consider pausing trading.',
        category: NotifCategory.risk,
        timestamp: now.subtract(const Duration(hours: 2)),
      ),
      AppNotification(
        id: 'n_004',
        title: 'NFP Report Released',
        body: 'Non-Farm Payrolls came in at 256K vs 200K expected. USD pairs showing high volatility.',
        category: NotifCategory.market,
        timestamp: now.subtract(const Duration(hours: 3)),
        isRead: true,
      ),
      AppNotification(
        id: 'n_005',
        title: 'Auto-Trade Executed',
        body: 'Semi-Auto mode placed a SELL on GBP/USD (0.05 lots) based on your guardrails.',
        category: NotifCategory.trades,
        timestamp: now.subtract(const Duration(hours: 5)),
        isRead: true,
      ),
      AppNotification(
        id: 'n_006',
        title: 'AI Portfolio Review',
        body: 'Your win rate dropped to 48% this week. AI suggests reducing lot sizes until trend improves.',
        category: NotifCategory.ai,
        timestamp: now.subtract(const Duration(days: 1)),
        isRead: true,
      ),
      AppNotification(
        id: 'n_007',
        title: 'High Leverage Alert',
        body: 'One of your open trades is using 1:75 leverage. Consider reducing to manage risk.',
        category: NotifCategory.risk,
        timestamp: now.subtract(const Duration(days: 1, hours: 3)),
        isRead: true,
      ),
    ];
  }
}
