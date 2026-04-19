// lib/features/dashboard/widgets/trust_reinforcement_footer.dart
//
// Phase A — Trust Reinforcement Footer
// Rotating trust statements that build user confidence passively.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TrustReinforcementFooter extends StatefulWidget {
  final bool isAIActive;
  final String? userEmail;

  const TrustReinforcementFooter({
    super.key,
    this.isAIActive = false,
    this.userEmail,
  });

  @override
  State<TrustReinforcementFooter> createState() =>
      _TrustReinforcementFooterState();
}

class _TrustReinforcementFooterState extends State<TrustReinforcementFooter> {
  static const _statements = [
    ('🔐', 'AI never exceeds your limits.'),
    ('📋', 'Every action is logged.'),
    ('🚫', 'No withdrawal authority granted.'),
    ('⚖️', 'You control all trading parameters.'),
    ('✨', 'Inaction is intelligent.'),
    ('🧠', 'AI learns from your feedback.'),
  ];

  int _currentIndex = 0;
  bool _visible = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startRotation();
  }

  void _startRotation() {
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      setState(() => _visible = false);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() {
          _currentIndex = (_currentIndex + 1) % _statements.length;
          _visible = true;
        });
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (emoji, text) = _statements[_currentIndex];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Statement row
          AnimatedOpacity(
            opacity: _visible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurface.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // Live/Standby indicator
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.isAIActive
                        ? Colors.green.withValues(alpha: 0.15)
                        : scheme.outline.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.isAIActive
                              ? Colors.green
                              : scheme.outline,
                        ),
                      )
                          .animate(
                            onPlay: widget.isAIActive
                                ? (c) => c.repeat(reverse: true)
                                : null,
                          )
                          .scaleXY(
                            begin: 1,
                            end: 1.4,
                            duration: 1.seconds,
                          ),
                      const SizedBox(width: 4),
                      Text(
                        widget.isAIActive ? 'Live' : 'Standby',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: widget.isAIActive
                              ? Colors.green
                              : scheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Progress dots + email
          Row(
            children: [
              // Dots
              Row(
                children: List.generate(_statements.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(right: 4),
                    width: i == _currentIndex ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _currentIndex
                          ? scheme.primary
                          : scheme.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
              const Spacer(),
              if (widget.userEmail != null)
                Text(
                  widget.userEmail!,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurface.withValues(alpha: 0.4),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
