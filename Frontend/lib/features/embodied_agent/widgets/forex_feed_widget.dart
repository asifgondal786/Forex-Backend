import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/live_updates_service.dart';

class ForexFeedWidget extends StatefulWidget {
  const ForexFeedWidget({super.key});

  @override
  State<ForexFeedWidget> createState() => _ForexFeedWidgetState();
}

class _ForexFeedWidgetState extends State<ForexFeedWidget> {
  static const List<String> _watchedPairs = <String>[
    'EUR/USD',
    'GBP/USD',
    'USD/JPY',
    'USD/PKR',
    'AUD/USD',
    'USD/CAD',
  ];

  static const Map<String, double> _fallbackPrices = <String, double>{
    'EUR/USD': 1.0933,
    'GBP/USD': 1.2781,
    'USD/JPY': 147.82,
    'USD/PKR': 289.00,
    'AUD/USD': 0.7350,
    'USD/CAD': 1.3450,
  };

  final Map<String, LiveUpdate> _latestByPair = <String, LiveUpdate>{};
  StreamSubscription<LiveUpdate>? _updatesSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  LiveUpdatesService? _liveService;

  bool _isConnected = false;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_initializeFeed());
    });
  }

  @override
  void dispose() {
    _updatesSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeFeed() async {
    _liveService = context.read<LiveUpdatesService>();

    _updatesSubscription = _liveService!.updates.listen((LiveUpdate update) {
      if (!mounted || !_watchedPairs.contains(update.pair)) {
        return;
      }
      setState(() {
        _latestByPair[update.pair] = update;
      });
    });

    _connectionSubscription =
        _liveService!.connectionStatus.listen((connected) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isConnected = connected;
      });
    });

    await _connectIfNeeded();
    _liveService?.subscribeToPairs(_watchedPairs);
  }

  Future<void> _connectIfNeeded() async {
    if (_liveService == null || _isConnecting) {
      return;
    }
    if (_liveService!.isConnected) {
      setState(() {
        _isConnected = true;
      });
      return;
    }

    _isConnecting = true;
    try {
      await _liveService!.connect();
    } finally {
      _isConnecting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor =
        _isConnected ? AppColors.statusRunning : AppColors.errorRed;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 240;
        final headerFontSize = isCompact ? 14.0 : 16.0;
        final edgePadding = isCompact ? 12.0 : 18.0;

        return Container(
          padding: EdgeInsets.all(edgePadding),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Live Forex Feed',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: headerFontSize,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      _isConnected
                          ? 'Live'
                          : (_isConnecting ? 'Connecting' : 'Offline'),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._watchedPairs.asMap().entries.map((entry) {
                final index = entry.key;
                final pair = entry.value;
                final update = _latestByPair[pair];
                final price = update?.price ?? _fallbackPrices[pair] ?? 0.0;
                final change = update?.changePercent ?? 0.0;
                final color = change > 0
                    ? AppColors.statusRunning
                    : change < 0
                        ? AppColors.errorRed
                        : Colors.grey;

                return Column(
                  children: [
                    _buildRow(
                      pair: pair,
                      price: _formatPrice(pair, price),
                      changePercent: change,
                      color: color,
                      timestamp: update?.timestamp,
                    ),
                    if (index != _watchedPairs.length - 1)
                      const SizedBox(height: 10),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRow({
    required String pair,
    required String price,
    required double changePercent,
    required Color color,
    DateTime? timestamp,
  }) {
    final isPositive = changePercent >= 0;
    final sign = isPositive ? '+' : '';
    final change = '$sign${changePercent.toStringAsFixed(2)}%';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 220;

        final leftSection = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              pair,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );

        final priceSection = Column(
          crossAxisAlignment:
              compact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Text(
              price,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatUpdated(timestamp),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 9,
              ),
            ),
          ],
        );

        final changeChip = Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 7 : 8,
            vertical: compact ? 3 : 4,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: color,
              ),
              const SizedBox(width: 2),
              Text(
                change,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leftSection,
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  priceSection,
                  changeChip,
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: leftSection),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                priceSection,
                const SizedBox(width: 10),
                changeChip,
              ],
            ),
          ],
        );
      },
    );
  }

  String _formatPrice(String pair, double price) {
    if (pair.contains('JPY') || pair.contains('PKR')) {
      return price.toStringAsFixed(2);
    }
    return price.toStringAsFixed(4);
  }

  String _formatUpdated(DateTime? timestamp) {
    if (timestamp == null) {
      return _isConnected ? 'Awaiting tick...' : 'No live tick';
    }
    final now = DateTime.now();
    final seconds = now.difference(timestamp).inSeconds;
    if (seconds < 2) {
      return 'Updated now';
    }
    if (seconds < 60) {
      return '$seconds s ago';
    }
    final minutes = seconds ~/ 60;
    return '$minutes m ago';
  }
}
