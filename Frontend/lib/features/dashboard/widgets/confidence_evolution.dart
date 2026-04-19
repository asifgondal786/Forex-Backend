// lib/features/dashboard/widgets/confidence_evolution.dart
//
// Phase B — Confidence Evolution Indicator
// Shows current AI confidence, 24h trend, sparkline, and reason.

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../../providers/engagement_provider.dart';

class ConfidenceEvolution extends StatelessWidget {
  const ConfidenceEvolution({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<EngagementProvider>(
      builder: (context, provider, _) {
        final conf = provider.confidence;
        if (provider.isLoadingConfidence && conf == null) {
          return _buildSkeleton(context);
        }
        if (conf == null) return const SizedBox.shrink();
        return _ConfidenceCard(confidence: conf);
      },
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ConfidenceCard extends StatelessWidget {
  final ConfidenceHistory confidence;

  const _ConfidenceCard({required this.confidence});

  Color _trendColor(String trend) => switch (trend) {
        'up' => Colors.green,
        'down' => Colors.red,
        _ => Colors.orange,
      };

  String _trendArrow(String trend) => switch (trend) {
        'up' => '↑',
        'down' => '↓',
        _ => '→',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trendColor = _trendColor(confidence.trend);
    final arrow = _trendArrow(confidence.trend);
    final changeStr = confidence.change24h >= 0
        ? '+${confidence.change24h.toStringAsFixed(1)}%'
        : '${confidence.change24h.toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Decision Reliability',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withValues(alpha: 0.6),
              letterSpacing: 0.3,
            ),
          ),

          const SizedBox(height: 8),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Big confidence number
              Text(
                '${confidence.current.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                  height: 1,
                ),
              ),

              const SizedBox(width: 8),

              // Trend badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: trendColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$arrow $changeStr (24h)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: trendColor,
                  ),
                ),
              ),

              const Spacer(),

              // Sparkline
              SizedBox(
                width: 80,
                height: 36,
                child: _Sparkline(
                  data: confidence.historical,
                  color: trendColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Reason
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 13,
                  color: scheme.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    confidence.reason,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurface.withValues(alpha: 0.65),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  final List<double> data;
  final Color color;

  const _Sparkline({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}
