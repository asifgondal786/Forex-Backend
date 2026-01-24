import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Sentiment Radar - Circular visualization of market sentiment from multiple sources
/// Shows: News sentiment, Retail sentiment, Institutional bias, Technical bias
class SentimentRadar extends StatefulWidget {
  final SentimentData sentiment;
  final VoidCallback? onTapped;

  const SentimentRadar({
    Key? key,
    required this.sentiment,
    this.onTapped,
  }) : super(key: key);

  @override
  State<SentimentRadar> createState() => _SentimentRadarState();
}

class _SentimentRadarState extends State<SentimentRadar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTapped,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.all(16),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '🎯 Market Sentiment Radar',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getOverallColor().withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _getOverallColor().withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    _getOverallSentiment(),
                    style: TextStyle(
                      color: _getOverallColor(),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Radar Chart
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return _SentimentRadarChart(
                  sentiment: widget.sentiment,
                  animationValue: _animationController.value,
                );
              },
            ),
            const SizedBox(height: 16),

            // Legend
            _buildLegend(),
            const SizedBox(height: 12),

            // Sentiment Breakdown
            _buildSentimentBreakdown(),
          ],
        ),
      ),
    );
  }

  Color _getOverallColor() {
    final avg = widget.sentiment.getAverageSentiment();
    if (avg > 60) {
      return const Color(0xFF10B981); // Green - Bullish
    } else if (avg > 40) {
      return const Color(0xFF6B7280); // Gray - Neutral
    } else {
      return const Color(0xFFEF4444); // Red - Bearish
    }
  }

  String _getOverallSentiment() {
    final avg = widget.sentiment.getAverageSentiment();
    if (avg > 60) {
      return 'Very Bullish';
    } else if (avg > 55) {
      return 'Bullish';
    } else if (avg > 45) {
      return 'Neutral';
    } else if (avg > 40) {
      return 'Bearish';
    } else {
      return 'Very Bearish';
    }
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _LegendItem(
          color: const Color(0xFF3B82F6),
          label: 'News',
          value: '${widget.sentiment.newsSentiment.toStringAsFixed(0)}%',
        ),
        _LegendItem(
          color: const Color(0xFF10B981),
          label: 'Retail',
          value: '${widget.sentiment.retailSentiment.toStringAsFixed(0)}%',
        ),
        _LegendItem(
          color: const Color(0xFFF59E0B),
          label: 'Institutional',
          value: '${widget.sentiment.institutionalBias.toStringAsFixed(0)}%',
        ),
        _LegendItem(
          color: const Color(0xFFEC4899),
          label: 'Technical',
          value: '${widget.sentiment.technicalBias.toStringAsFixed(0)}%',
        ),
      ],
    );
  }

  Widget _buildSentimentBreakdown() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sentiment Score',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _SentimentMeterRow(
            label: 'News',
            value: widget.sentiment.newsSentiment,
            color: const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 6),
          _SentimentMeterRow(
            label: 'Retail',
            value: widget.sentiment.retailSentiment,
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 6),
          _SentimentMeterRow(
            label: 'Institutional',
            value: widget.sentiment.institutionalBias,
            color: const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 6),
          _SentimentMeterRow(
            label: 'Technical',
            value: widget.sentiment.technicalBias,
            color: const Color(0xFFEC4899),
          ),
        ],
      ),
    );
  }
}

class _SentimentRadarChart extends StatelessWidget {
  final SentimentData sentiment;
  final double animationValue;

  const _SentimentRadarChart({
    required this.sentiment,
    required this.animationValue,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: CustomPaint(
        painter: RadarChartPainter(
          sentiment: sentiment,
          animationValue: animationValue,
        ),
      ),
    );
  }
}

class RadarChartPainter extends CustomPainter {
  final SentimentData sentiment;
  final double animationValue;

  RadarChartPainter({
    required this.sentiment,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    // Draw background circles
    _drawBackgroundCircles(canvas, center, radius);

    // Draw axes
    _drawAxes(canvas, center, radius);

    // Draw data points
    _drawDataPoints(canvas, center, radius);

    // Draw labels
    _drawLabels(canvas, center, radius);
  }

  void _drawBackgroundCircles(Canvas canvas, Offset center, double radius) {
    for (int i = 5; i >= 1; i--) {
      final r = (radius / 5) * i;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = Colors.white.withOpacity(0.05)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  void _drawAxes(Canvas canvas, Offset center, double radius) {
    const axes = 4; // 4 sentiment sources
    for (int i = 0; i < axes; i++) {
      final angle = (i * 2 * math.pi / axes) - (math.pi / 2);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      canvas.drawLine(
        center,
        Offset(x, y),
        Paint()
          ..color = Colors.white.withOpacity(0.1)
          ..strokeWidth = 1,
      );
    }
  }

  void _drawDataPoints(Canvas canvas, Offset center, double radius) {
    final sentiments = [
      sentiment.newsSentiment / 100,
      sentiment.retailSentiment / 100,
      sentiment.institutionalBias / 100,
      sentiment.technicalBias / 100,
    ];

    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
    ];

    final points = <Offset>[];
    for (int i = 0; i < sentiments.length; i++) {
      final angle = (i * 2 * math.pi / sentiments.length) - (math.pi / 2);
      final distance = radius * sentiments[i] * animationValue;
      final x = center.dx + distance * math.cos(angle);
      final y = center.dy + distance * math.sin(angle);
      points.add(Offset(x, y));
    }

    // Draw filled polygon
    canvas.drawPath(
      _createPath(points),
      Paint()
        ..color = const Color(0xFF3B82F6).withOpacity(0.2)
        ..style = PaintingStyle.fill,
    );

    // Draw border
    canvas.drawPath(
      _createPath(points),
      Paint()
        ..color = const Color(0xFF3B82F6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Draw points
    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(
        points[i],
        4,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _drawLabels(Canvas canvas, Offset center, double radius) {
    final labels = ['📰 News', '👥 Retail', '🏛️ Institutional', '📊 Technical'];
    const axes = 4;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < axes; i++) {
      final angle = (i * 2 * math.pi / axes) - (math.pi / 2);
      final x = center.dx + (radius + 30) * math.cos(angle);
      final y = center.dy + (radius + 30) * math.sin(angle);

      textPainter.text = TextSpan(
        text: labels[i],
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }
  }

  Path _createPath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;

    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(RadarChartPainter oldDelegate) => true;
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 9,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _SentimentMeterRow extends StatelessWidget {
  final String label;
  final double value; // 0-100
  final Color color;

  const _SentimentMeterRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 10,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: value / 100,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 3,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            '${value.toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }
}

/// Sentiment Data Model
class SentimentData {
  final String pair; // e.g., 'EUR/USD'
  final double newsSentiment; // 0-100 (50 = neutral)
  final double retailSentiment; // 0-100
  final double institutionalBias; // 0-100
  final double technicalBias; // 0-100

  SentimentData({
    required this.pair,
    required this.newsSentiment,
    required this.retailSentiment,
    required this.institutionalBias,
    required this.technicalBias,
  });

  double getAverageSentiment() {
    return (newsSentiment + retailSentiment + institutionalBias + technicalBias) /
        4;
  }

  factory SentimentData.example() {
    return SentimentData(
      pair: 'EUR/USD',
      newsSentiment: 65.0,
      retailSentiment: 72.0,
      institutionalBias: 58.0,
      technicalBias: 70.0,
    );
  }
}
