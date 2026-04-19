// lib/features/dashboard/widgets/intelligent_empty_state.dart
//
// Phase A — Intelligent Empty States
// Replaces dead "0 items" with contextual, animated messaging.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum EmptyStateType {
  noActiveTasks,
  noSignals,
  noAlerts,
  noActivity,
  noTrades,
  noNews,
}

class IntelligentEmptyState extends StatelessWidget {
  final EmptyStateType type;
  final String? customTitle;
  final String? customSubtitle;
  final String? customCTA;
  final String? secondaryCTA;
  final VoidCallback? onCTA;
  final VoidCallback? onSecondaryCTA;

  const IntelligentEmptyState({
    super.key,
    required this.type,
    this.customTitle,
    this.customSubtitle,
    this.customCTA,
    this.secondaryCTA,
    this.onCTA,
    this.onSecondaryCTA,
  });

  _EmptyStateConfig get _config => switch (type) {
        EmptyStateType.noActiveTasks => const _EmptyStateConfig(
            emoji: '🧠',
            title: 'No Live AI Operations',
            subtitle:
                'AI is actively monitoring markets.\nNo safe opportunities detected yet.',
            hint: '💡 Create your first AI task or let AI continue learning.',
          ),
        EmptyStateType.noSignals => const _EmptyStateConfig(
            emoji: '📊',
            title: 'No Signals Generated',
            subtitle:
                'AI is scanning market conditions.\nWaiting for high-confidence setups.',
            hint: '💡 Signals appear when market conditions align.',
          ),
        EmptyStateType.noAlerts => const _EmptyStateConfig(
            emoji: '🛡️',
            title: 'All Clear',
            subtitle:
                'No active risk alerts.\nAI is monitoring for volatility changes.',
            hint: '💡 Alerts appear when market conditions require attention.',
          ),
        EmptyStateType.noActivity => const _EmptyStateConfig(
            emoji: '⚡',
            title: 'AI Standing By',
            subtitle:
                'No recent activity to display.\nAI is ready to act on your behalf.',
            hint: '💡 Activity appears as AI scans and evaluates opportunities.',
          ),
        EmptyStateType.noTrades => const _EmptyStateConfig(
            emoji: '📈',
            title: 'No Trades Yet',
            subtitle:
                'AI has not executed any trades.\nSafety limits are working as intended.',
            hint: '💡 Trades appear here once AI finds safe entry conditions.',
          ),
        EmptyStateType.noNews => const _EmptyStateConfig(
            emoji: '📰',
            title: 'No Headlines Yet',
            subtitle:
                'Market news is loading.\nAI monitors news for trading impact.',
            hint: '💡 News updates appear as market events unfold.',
          ),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cfg = _config;
    final title = customTitle ?? cfg.title;
    final subtitle = customSubtitle ?? cfg.subtitle;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surfaceContainerHighest,
            scheme.surfaceContainerHighest.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Floating emoji
          Text(cfg.emoji, style: const TextStyle(fontSize: 48))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(begin: 0, end: -8, duration: 3.seconds, curve: Curves.easeInOut),

          const SizedBox(height: 16),

          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 8),

          // Subtitle
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface.withValues(alpha: 0.65),
              height: 1.5,
            ),
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 16),

          // Hint box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              cfg.hint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
          ).animate().fadeIn(delay: 400.ms),

          if (onCTA != null) ...[
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onCTA,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(customCTA ?? 'Get Started'),
            ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0),
          ],

          if (onSecondaryCTA != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onSecondaryCTA,
              child: Text(
                secondaryCTA ?? 'Learn More',
                style: TextStyle(color: scheme.primary),
              ),
            ).animate().fadeIn(delay: 600.ms),
          ],
        ],
      ),
    );
  }
}

class _EmptyStateConfig {
  final String emoji;
  final String title;
  final String subtitle;
  final String hint;

  const _EmptyStateConfig({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.hint,
  });
}
