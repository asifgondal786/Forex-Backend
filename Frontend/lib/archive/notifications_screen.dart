import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().load('demo_token');
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        title: Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        actions: [
          Consumer<NotificationProvider>(
            builder: (_, prov, __) => TextButton(
              onPressed: prov.unreadCount > 0 ? prov.markAllRead : null,
              child: Text(
                'Mark all read',
                style: TextStyle(
                  color: prov.unreadCount > 0
                      ? scheme.primary
                      : scheme.onSurface.withOpacity(0.3),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, prov, _) {
          if (prov.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              if (!prov.pushPermissionGranted)
                _PushPermissionBanner(prov: prov, scheme: scheme),
              _CategoryChips(prov: prov, scheme: scheme),
              Expanded(
                child: prov.filtered.isEmpty
                    ? _EmptyNotifications(scheme: scheme)
                    : RefreshIndicator(
                        onRefresh: () => prov.load('demo_token'),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: prov.filtered.length,
                          itemBuilder: (context, i) {
                            return _NotifCard(
                              notif: prov.filtered[i],
                              prov: prov,
                              scheme: scheme,
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PushPermissionBanner extends StatelessWidget {
  final NotificationProvider prov;
  final ColorScheme scheme;

  const _PushPermissionBanner({required this.prov, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_active_rounded,
              color: scheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Enable push notifications to stay on top of signals and alerts.',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: prov.grantPushPermission,
            child: const Text('Enable', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final NotificationProvider prov;
  final ColorScheme scheme;

  const _CategoryChips({required this.prov, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final cats = NotifCategory.values;
    final labels = {
      NotifCategory.all: 'All',
      NotifCategory.trades: 'Trades',
      NotifCategory.risk: 'Risk',
      NotifCategory.market: 'Market',
      NotifCategory.ai: 'AI',
    };
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: cats.map((c) {
          final selected = prov.selectedCategory == c;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(labels[c]!),
              selected: selected,
              onSelected: (_) => prov.setCategory(c),
              selectedColor: scheme.primary,
              labelStyle: TextStyle(
                color: selected ? scheme.onPrimary : scheme.onSurface,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
              side: BorderSide(
                color: selected
                    ? scheme.primary
                    : scheme.outline.withOpacity(0.3),
              ),
              backgroundColor: scheme.surface,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final AppNotification notif;
  final NotificationProvider prov;
  final ColorScheme scheme;

  const _NotifCard(
      {required this.notif, required this.prov, required this.scheme});

  Color _catColor() {
    switch (notif.category) {
      case NotifCategory.trades:
        return Colors.blue;
      case NotifCategory.risk:
        return Colors.orange;
      case NotifCategory.market:
        return Colors.purple;
      case NotifCategory.ai:
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _catIcon() {
    switch (notif.category) {
      case NotifCategory.trades:
        return Icons.trending_up_rounded;
      case NotifCategory.risk:
        return Icons.warning_amber_rounded;
      case NotifCategory.market:
        return Icons.candlestick_chart_rounded;
      case NotifCategory.ai:
        return Icons.auto_awesome_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _catColor();
    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) => prov.dismiss(notif.id),
      child: GestureDetector(
        onTap: () => prov.markRead(notif.id),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notif.isRead
                ? scheme.surfaceContainerHighest
                : scheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: notif.isRead
                  ? Colors.transparent
                  : scheme.primary.withOpacity(0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: catColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(_catIcon(), color: catColor, size: 18),
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
                            notif.title,
                            style: TextStyle(
                              fontWeight: notif.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (!notif.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurface.withOpacity(0.65),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _timeAgo(notif.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  final ColorScheme scheme;

  const _EmptyNotifications({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 72,
            color: scheme.onSurface.withOpacity(0.15),
          ),
          const SizedBox(height: 16),
          Text(
            'All caught up!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No notifications in this category.',
            style: TextStyle(
              color: scheme.onSurface.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

