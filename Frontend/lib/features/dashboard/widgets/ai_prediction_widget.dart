import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AIPredictionCard extends StatelessWidget {
  final String pair;
  final String sentiment;
  final double confidence;
  final String recommendation;
  final String reason;
  final List<String> signals;
  final Color sentimentColor;

  const AIPredictionCard({
    super.key,
    required this.pair,
    required this.sentiment,
    required this.confidence,
    required this.recommendation,
    required this.reason,
    required this.signals,
    required this.sentimentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            sentimentColor.withOpacity(0.12),
            sentimentColor.withOpacity(0.04),
          ],
        ),
        border: Border.all(
          color: sentimentColor.withOpacity(0.3),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: sentimentColor.withOpacity(0.1),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pair,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: sentimentColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      sentiment,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: sentimentColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              // Confidence Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      sentimentColor.withOpacity(0.2),
                      sentimentColor.withOpacity(0.1),
                    ],
                  ),
                  border: Border.all(
                    color: sentimentColor.withOpacity(0.4),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      '${confidence.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: sentimentColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Confidence',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Confidence Progress Bar
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: Colors.white.withOpacity(0.05),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: confidence / 100,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(sentimentColor),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Recommendation Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: sentimentColor.withOpacity(0.08),
              border: Border.all(
                color: sentimentColor.withOpacity(0.2),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  recommendation == 'BUY'
                      ? Icons.trending_up
                      : recommendation == 'SELL'
                          ? Icons.trending_down
                          : Icons.pause_circle,
                  color: sentimentColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recommendation: $recommendation',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reason,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[400],
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Signals Tags
          if (signals.isNotEmpty) ...[
            Text(
              'Key Signals',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[400],
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: signals
                  .map(
                    (signal) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: sentimentColor.withOpacity(0.15),
                        border: Border.all(
                          color: sentimentColor.withOpacity(0.2),
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        signal,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: sentimentColor,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        sentimentColor.withOpacity(0.3),
                        sentimentColor.withOpacity(0.1),
                      ],
                    ),
                    border: Border.all(
                      color: sentimentColor.withOpacity(0.4),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(8),
                      child: Center(
                        child: Text(
                          'Trade',
                          style: TextStyle(
                            color: sentimentColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(8),
                      child: const Center(
                        child: Text(
                          'Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AIPredictionWidget extends StatefulWidget {
  const AIPredictionWidget({super.key});

  @override
  State<AIPredictionWidget> createState() => _AIPredictionWidgetState();
}

class _AIPredictionWidgetState extends State<AIPredictionWidget> {
  final List<Map<String, dynamic>> predictions = [
    {
      'pair': 'EUR/USD',
      'sentiment': 'BULLISH 📈',
      'confidence': 87.5,
      'recommendation': 'BUY',
      'reason': 'Technical levels support bullish momentum with strong volume',
      'signals': ['RSI Oversold', 'MA Cross', 'Support Hold', 'Volume ↑'],
      'color': const Color(0xFF10B981),
    },
    {
      'pair': 'GBP/USD',
      'sentiment': 'BEARISH 📉',
      'confidence': 72.3,
      'recommendation': 'SELL',
      'reason': 'Resistance rejection with declining momentum indicators',
      'signals': ['MACD Bearish', 'Volume Divergence', 'Trend Break'],
      'color': const Color(0xFFEF4444),
    },
    {
      'pair': 'USD/JPY',
      'sentiment': 'NEUTRAL ➡️',
      'confidence': 64.2,
      'recommendation': 'HOLD',
      'reason': 'Consolidation pattern forming with mixed signals',
      'signals': ['Range Bound', 'Mixed MACD', 'Support Near'],
      'color': const Color(0xFFF59E0B),
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.05),
            Colors.white.withOpacity(0.02),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🤖 AI Predictions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ML-powered trading insights',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.15),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Updating...',
                  style: TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Predictions Grid
          if (isMobile)
            Column(
              children: predictions
                  .asMap()
                  .entries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: AIPredictionCard(
                        pair: entry.value['pair'],
                        sentiment: entry.value['sentiment'],
                        confidence: entry.value['confidence'],
                        recommendation: entry.value['recommendation'],
                        reason: entry.value['reason'],
                        signals: entry.value['signals'],
                        sentimentColor: entry.value['color'],
                      )
                          .animate()
                          .fadeIn(
                            duration: const Duration(milliseconds: 600),
                          )
                          .slideY(
                            begin: 0.2,
                            delay: Duration(
                              milliseconds: entry.key * 100,
                            ),
                          ),
                    ),
                  )
                  .toList(),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.95,
              ),
              itemCount: predictions.length,
              itemBuilder: (context, index) {
                final pred = predictions[index];
                return AIPredictionCard(
                  pair: pred['pair'],
                  sentiment: pred['sentiment'],
                  confidence: pred['confidence'],
                  recommendation: pred['recommendation'],
                  reason: pred['reason'],
                  signals: pred['signals'],
                  sentimentColor: pred['color'],
                )
                    .animate()
                    .fadeIn(
                      duration: const Duration(milliseconds: 600),
                    )
                    .slideY(
                      begin: 0.2,
                      delay: Duration(milliseconds: index * 100),
                    );
              },
            ),
        ],
      ),
    );
  }
}
