/// Reusable dropdown for switching mode — used in SettingsScreen.
/// Drop this widget anywhere in the settings UI.
///
/// Usage:
///   const ModeSwitcherWidget()
///
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/mode_provider.dart';

class ModeSwitcherWidget extends StatelessWidget {
  const ModeSwitcherWidget({super.key});

  static const List<(AppMode, String, IconData, Color)> _options = [
    (AppMode.marketWatch,  'Market Watch',   Icons.candlestick_chart_rounded, Color(0xFF00C896)),
    (AppMode.aiChat,       'AI Chat',        Icons.chat_bubble_rounded,       Color(0xFF6C63FF)),
    (AppMode.aiCopilot,    'AI Copilot',     Icons.auto_awesome_rounded,      Color(0xFF3DB9FF)),
    (AppMode.tradeSignals, 'Trade Signals',  Icons.trending_up_rounded,       Color(0xFFFF8C42)),
    (AppMode.newsEvents,   'News & Events',  Icons.newspaper_rounded,         Color(0xFFFF4F7B)),
    (AppMode.customSetup,  'Custom Setup',   Icons.tune_rounded,              Color(0xFFB8860B)),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ModeProvider>();
    final current = provider.mode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard Mode',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<AppMode>(
              value: current,
              isExpanded: true,
              borderRadius: BorderRadius.circular(12),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: _options.map((opt) {
                final (mode, label, icon, color) = opt;
                return DropdownMenuItem<AppMode>(
                  value: mode,
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: color, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (AppMode? selected) {
                if (selected != null) {
                  provider.setMode(selected);
                  // Pop back to dashboard so ModeRouter re-renders immediately
                  Navigator.of(context).popUntil(
                    (route) => route.settings.name == '/dashboard',
                  );
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Changes your home screen layout instantly.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}

