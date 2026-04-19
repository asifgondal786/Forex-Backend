// lib/features/dashboard/widgets/ai_activity_feed.dart
//
// Phase B — Live AI Activity Feed
// Shows real-time AI actions: scanning, evaluating, monitoring, decisions.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../providers/engagement_provider.dart';

class AIActivityFeed extends StatelessWidget {
  const AIActivityFeed({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<EngagementProvider>(
      builder: (context, provider, _) {
        return _ActivityFeedCard(provider: provider);
      },
    );
  }
}

class _ActivityFeedCard extends StatelessWidget {
  final EngagementProvider provider;

  const _ActivityFeedCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green,
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scaleXY(begin: 1, end: 1.5, duration: 1.2.seconds),
                const SizedBox(width: 8),
                Text(
                  '🧠 AI Activity',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  'Live',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Divider(height: 1),
          ),

          // Content
          if (provider.isLoadingActivities && provider.activities.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (provider.activities.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'AI is initializing. Activity will appear shortly.',
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: provider.activities.length,
              separatorBuilder: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  height: 1,
                  color: scheme.outline.withValues(alpha: 0.08),
                ),
              ),
              itemBuilder: (context, index) {
                final activity = provider.activities[index];
                return _ActivityTile(
                  activity: activity,
                  index: index,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final AIActivity activity;
  final int index;

  const _ActivityTile({required this.activity, required this.index});

  Color _typeColor(BuildContext context, String type) {
    final scheme = Theme.of(context).colorScheme;
    return switch (type) {
      'scan' => scheme.primary,
      'evaluate' => Colors.purple,
      'monitor' => Colors.orange,
      'alert' => Colors.red,
      'decision' => Colors.green,
      _ => scheme.onSurface.withValues(alpha: 0.5),
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _typeColor(context, activity.type);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emoji + color dot
          Stack(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    activity.emoji,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scheme.surfaceContainerHighest,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 12),

          // Message
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.message,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurface.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activity.type.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Timestamp
          Text(
            activity.relativeTime,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: index * 60))
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.05, end: 0);
  }
}
