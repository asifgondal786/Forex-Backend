import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../core/models/app_notification.dart';
import '../../../providers/header_provider.dart';
import '../../../services/api_service.dart';
import '../../../services/live_updates_service.dart';
import '../../../shared/widgets/glassmorphism_card.dart';

class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet({super.key});

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  bool _loading = true;
  bool _markingAll = false;
  String? _error;
  List<AppNotification> _items = [];
  bool _initialized = false;
  late ApiService _apiService;
  late LiveUpdatesService _liveUpdatesService;
  StreamSubscription? _notificationSubscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _apiService = context.read<ApiService>();
    _liveUpdatesService = context.read<LiveUpdatesService>();
    _initialized = true;
    _loadNotifications();
    _listenForNotifications();
  }

  void _listenForNotifications() {
    _notificationSubscription = _liveUpdatesService.notifications.listen(
      (NotificationUpdate notificationUpdate) {
        if (!mounted) return;
        
        // Convert NotificationUpdate to AppNotification
        final newNotification = AppNotification(
          id: notificationUpdate.notificationId,
          title: notificationUpdate.title,
          message: notificationUpdate.message,
          category: notificationUpdate.category,
          priority: notificationUpdate.priority,
          timestamp: notificationUpdate.timestamp,
          read: notificationUpdate.read,
          clicked: false,
        );

        setState(() {
          // Add new notification to the beginning of the list
          _items.insert(0, newNotification);
          // Keep only latest 20 notifications
          if (_items.length > 20) {
            _items = _items.sublist(0, 20);
          }
        });

        // Refresh header to update notification count
        _refreshHeader();
      },
      onError: (error) {
        debugPrint('Notification stream error: $error');
      },
    );
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _apiService.getNotifications(limit: 20);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markRead(AppNotification notification) async {
    if (notification.read) return;
    setState(() {
      _items = _items
          .map((item) => item.id == notification.id
              ? item.copyWith(read: true)
              : item)
          .toList();
    });

    try {
      await _apiService.markNotificationRead(notification.id);
      _refreshHeader();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = _items
            .map((item) => item.id == notification.id
                ? item.copyWith(read: false)
                : item)
            .toList();
      });
      _showSnack('Unable to mark notification as read.');
    }
  }

  Future<void> _markAllRead() async {
    final unread = _items.where((item) => !item.read).toList();
    if (unread.isEmpty) return;

    setState(() {
      _markingAll = true;
      _items = _items.map((item) => item.copyWith(read: true)).toList();
    });

    try {
      await Future.wait(
        unread.map((item) => _apiService.markNotificationRead(item.id)),
      );
      _refreshHeader();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = _items
            .map((item) => unread.any((u) => u.id == item.id)
                ? item.copyWith(read: false)
                : item)
            .toList();
      });
      _showSnack('Unable to mark all notifications as read.');
    } finally {
      if (!mounted) return;
      setState(() {
        _markingAll = false;
      });
    }
  }

  void _refreshHeader() {
    if (!mounted) return;
    context.read<HeaderProvider>().fetchHeader();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorRed,
      ),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return const Color(0xFFEF4444);
      case 'high':
        return const Color(0xFFF59E0B);
      case 'medium':
        return const Color(0xFF3B82F6);
      case 'low':
        return const Color(0xFF10B981);
      default:
        return AppTheme.accentCyan;
    }
  }

  IconData _priorityIcon(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return Icons.warning_amber_rounded;
      case 'high':
        return Icons.notifications_active;
      case 'medium':
        return Icons.notifications;
      case 'low':
        return Icons.notifications_none;
      default:
        return Icons.notifications;
    }
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return '';
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Widget _buildTag(String label, Color color) {
    if (label.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildNotificationItem(AppNotification item) {
    final isUnread = !item.read;
    final accent = _priorityColor(item.priority);
    final timestamp = _formatTimestamp(item.timestamp);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _markRead(item),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isUnread ? 0.08 : 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accent.withValues(alpha: isUnread ? 0.35 : 0.2),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _priorityIcon(item.priority),
                  color: accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title.isNotEmpty
                                ? item.title
                                : 'Notification',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight:
                                  isUnread ? FontWeight.w700 : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (timestamp.isNotEmpty)
                          Text(
                            timestamp,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                    if (item.message.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.message,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildTag(item.category, accent),
                        _buildTag(
                          item.priority.isNotEmpty
                              ? item.priority
                              : 'info',
                          accent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isUnread)
                Container(
                  margin: const EdgeInsets.only(left: 8, top: 2),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFF59E0B),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white70, size: 36),
            const SizedBox(height: 12),
            Text(
              'Unable to load notifications.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadNotifications,
              style: AppTheme.glassTextButtonStyle(
                tintColor: AppTheme.accentCyan,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_none, color: Colors.white70, size: 42),
            const SizedBox(height: 12),
            Text(
              'No notifications yet.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'New alerts will appear here.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _buildNotificationItem(_items[index]);
      },
    );
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _items.where((item) => !item.read).length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: GlassmorphismCard(
          padding: const EdgeInsets.all(20),
          borderRadius: 18,
          blur: 16,
          opacity: 0.12,
          borderColor: AppTheme.accentCyan,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;

              final headerBadge = unreadCount > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : null;

              final headerActions = Row(
                mainAxisAlignment:
                    isNarrow ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  TextButton(
                    onPressed: _markingAll || unreadCount == 0
                        ? null
                        : _markAllRead,
                    style: AppTheme.glassTextButtonStyle(
                      tintColor: AppTheme.accentCyan,
                    ),
                    child: _markingAll
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Mark all read'),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: Colors.white70,
                  ),
                ],
              );

              return Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.notifications_active,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (headerBadge != null) ...[
                        const SizedBox(width: 8),
                        headerBadge,
                      ],
                      if (!isNarrow) ...[
                        const Spacer(),
                        headerActions,
                      ],
                    ],
                  ),
                  if (isNarrow) ...[
                    const SizedBox(height: 8),
                    headerActions,
                  ],
                  const SizedBox(height: 12),
                  Expanded(child: _buildBody()),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
