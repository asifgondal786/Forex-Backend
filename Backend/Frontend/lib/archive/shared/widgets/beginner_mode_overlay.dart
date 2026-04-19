import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/beginner_mode_provider.dart';

/// Wrap any screen child with this to apply beginner protections.
class BeginnerModeOverlay extends StatelessWidget {
  final Widget child;

  const BeginnerModeOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<BeginnerModeProvider>();
    if (!prov.isEnabled) return child;

    return Stack(
      children: [
        child,
        if (prov.isDailyLossCapReached) _DailyCapBanner(prov: prov),
        if (prov.isHighLeverage) _LeverageWarningBanner(),
      ],
    );
  }
}

class _DailyCapBanner extends StatelessWidget {
  final BeginnerModeProvider prov;

  const _DailyCapBanner({required this.prov});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.red.shade700,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.block_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Daily loss cap reached (\$${prov.dailyLossCap.toStringAsFixed(0)}). New trades are blocked for today.',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LeverageWarningBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 80,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.orange.shade700,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '⚠️ Beginner Mode: Leverage above 1:10 is risky. Consider reducing it.',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows an extra confirmation dialog before trade actions in beginner mode.
Future<bool> beginnerConfirmTrade(BuildContext context, String pair) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Confirm Trade'),
      content: Text(
        'You are about to place a trade on $pair. In Beginner Mode, please double-check your setup before confirming.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

