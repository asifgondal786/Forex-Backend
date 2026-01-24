import 'package:flutter/material.dart';

/// Confidence-Weighted Signal Display
/// Shows trading signals with confidence percentages and reasoning
class ConfidenceWeightedSignals extends StatelessWidget {
  final List<TradeSignal> signals;
  final VoidCallback? onSignalTapped;

  const ConfidenceWeightedSignals({
    Key? key,
    required this.signals,
    this.onSignalTapped,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF1E293B).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '📊 Market Signals',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${signals.length} signals',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Signals List
          ...signals.map((signal) => _SignalCard(
                signal: signal,
                onTap: onSignalTapped,
              )),
        ],
      ),
    );
  }
}

class _SignalCard extends StatelessWidget {
  final TradeSignal signal;
  final VoidCallback? onTap;

  const _SignalCard({
    required this.signal,
    this.onTap,
  });

  Color _getSignalColor(String type) {
    switch (type.toLowerCase()) {
      case 'buy':
        return const Color(0xFF10B981);
      case 'sell':
        return const Color(0xFFEF4444);
      case 'hold':
        return const Color(0xFF6B7280);
      default:
        return Colors.grey;
    }
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 75) {
      return const Color(0xFF10B981); // Green
    } else if (confidence >= 50) {
      return const Color(0xFFF59E0B); // Amber
    } else {
      return const Color(0xFFEF4444); // Red
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _getSignalColor(signal.type).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _getSignalColor(signal.type).withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Currency + Signal + Confidence
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Currency Pair
                Text(
                  signal.pair,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                // Signal Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getSignalColor(signal.type),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    signal.type.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Confidence Meter
            _ConfidenceMeter(
              confidence: signal.confidence,
              color: _getConfidenceColor(signal.confidence),
            ),
            const SizedBox(height: 8),

            // Signal Reason
            Text(
              signal.reason,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11,
                height: 1.4,
              ),
            ),

            // Factors (if available)
            if (signal.factors.isNotEmpty) ...[
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: signal.factors
                    .map(
                      (factor) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Text(
                              '•',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                factor,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],

            // Risk & Reward
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Risk',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 9,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        signal.riskReward.split(':')[0],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reward',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 9,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        signal.riskReward.split(':')[1],
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceMeter extends StatelessWidget {
  final double confidence;
  final Color color;

  const _ConfidenceMeter({
    required this.confidence,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Confidence',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 10,
              ),
            ),
            Text(
              '${confidence.toStringAsFixed(0)}%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: confidence / 100,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}

/// Trade Signal Data Model
class TradeSignal {
  final String pair; // e.g., 'EUR/USD'
  final String type; // 'BUY' | 'SELL' | 'HOLD'
  final double confidence; // 0-100
  final String reason; // Main reason for the signal
  final List<String> factors; // Supporting factors
  final String riskReward; // e.g., "1:2.5"

  TradeSignal({
    required this.pair,
    required this.type,
    required this.confidence,
    required this.reason,
    this.factors = const [],
    this.riskReward = '1:1.5',
  });
}
