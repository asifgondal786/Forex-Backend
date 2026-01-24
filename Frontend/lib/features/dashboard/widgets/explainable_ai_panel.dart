import 'package:flutter/material.dart';

/// Explainable AI Panel - Shows why AI took a specific trade
/// Answers: What did AI do? Why? What factors influenced it?
class ExplainableAIPanel extends StatefulWidget {
  final TradeExplanation? explanation;
  final VoidCallback? onExpandTapped;
  final bool isExpanded;

  const ExplainableAIPanel({
    Key? key,
    this.explanation,
    this.onExpandTapped,
    this.isExpanded = false,
  }) : super(key: key);

  @override
  State<ExplainableAIPanel> createState() => _ExplainableAIPanelState();
}

class _ExplainableAIPanelState extends State<ExplainableAIPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _expandController;
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded;
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    if (_isExpanded) {
      _expandController.forward();
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded) {
      _expandController.forward();
    } else {
      _expandController.reverse();
    }
    widget.onExpandTapped?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.explanation == null) {
      return const SizedBox.shrink();
    }

    final explanation = widget.explanation!;

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
          // Header (Always visible)
          GestureDetector(
            onTap: _toggleExpanded,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        '🧠',
                        style: TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Why AI Took This Trade',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            explanation.pair,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.expand_more,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expandable Content
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: _isExpanded
                ? Column(
                    children: [
                      Divider(
                        color: Colors.white.withOpacity(0.1),
                        height: 1,
                      ),
                      _buildExplanationContent(explanation),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildExplanationContent(TradeExplanation explanation) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Decision
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF3B82F6).withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: explanation.decision.toLowerCase() == 'buy'
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        explanation.decision.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'AI Decision',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  explanation.mainReason,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Analysis Factors
          Text(
            'Analysis Factors',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          ...explanation.factors.map(
            (factor) => _FactorRow(factor: factor),
          ),
          const SizedBox(height: 16),

          // Data Sources
          Text(
            'Data Sources',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: explanation.dataSources
                .map((source) => _SourceBadge(source: source))
                .toList(),
          ),
          const SizedBox(height: 16),

          // Confidence Breakdown
          Text(
            'Confidence Breakdown',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          ...explanation.confidenceBreakdown.entries.map(
            (entry) => _ConfidenceBreakdownItem(
              label: entry.key,
              value: entry.value,
            ),
          ),
        ],
      ),
    );
  }
}

class _FactorRow extends StatelessWidget {
  final TradeExplanationFactor factor;

  const _FactorRow({required this.factor});

  Color _getImpactColor(String impact) {
    switch (impact.toLowerCase()) {
      case 'bullish':
        return const Color(0xFF10B981);
      case 'bearish':
        return const Color(0xFFEF4444);
      case 'neutral':
        return const Color(0xFF6B7280);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  factor.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  factor.description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getImpactColor(factor.impact).withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _getImpactColor(factor.impact).withOpacity(0.4),
              ),
            ),
            child: Text(
              factor.impact,
              style: TextStyle(
                color: _getImpactColor(factor.impact),
                fontWeight: FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final String source;

  const _SourceBadge({required this.source});

  IconData _getSourceIcon(String source) {
    switch (source.toLowerCase()) {
      case 'rsi':
      case 'macd':
      case 'bollinger':
        return Icons.trending_up;
      case 'news':
      case 'sentiment':
        return Icons.newspaper;
      case 'volume':
        return Icons.show_chart;
      default:
        return Icons.data_thresholding;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF3B82F6).withOpacity(0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getSourceIcon(source),
            size: 12,
            color: const Color(0xFF3B82F6),
          ),
          const SizedBox(width: 6),
          Text(
            source,
            style: const TextStyle(
              color: Color(0xFF3B82F6),
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceBreakdownItem extends StatelessWidget {
  final String label;
  final double value; // 0-100

  const _ConfidenceBreakdownItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 10,
                ),
              ),
              Text(
                '${value.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white,
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
              value: value / 100,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF3B82F6),
              ),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Trade Explanation Data Model
class TradeExplanation {
  final String pair;
  final String decision; // 'BUY' | 'SELL'
  final String mainReason;
  final List<TradeExplanationFactor> factors;
  final List<String> dataSources; // 'RSI', 'MACD', 'News', etc.
  final Map<String, double> confidenceBreakdown; // Factor → confidence %

  TradeExplanation({
    required this.pair,
    required this.decision,
    required this.mainReason,
    required this.factors,
    required this.dataSources,
    required this.confidenceBreakdown,
  });
}

class TradeExplanationFactor {
  final String name;
  final String description;
  final String impact; // 'Bullish' | 'Bearish' | 'Neutral'

  TradeExplanationFactor({
    required this.name,
    required this.description,
    required this.impact,
  });
}
