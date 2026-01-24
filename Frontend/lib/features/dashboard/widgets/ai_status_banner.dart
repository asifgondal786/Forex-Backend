import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// AI Status Banner Widget - Shows AI mode, data sources, and confidence
/// Displays at the top of dashboard to make AI feel "present"
class AIStatusBanner extends StatefulWidget {
  final bool aiEnabled;
  final String aiMode; // 'Manual', 'Assisted', 'Semi-Auto', 'Full Auto'
  final int dataSourcesMonitored;
  final double confidenceScore; // 0-100
  final VoidCallback onAITapped;

  const AIStatusBanner({
    Key? key,
    required this.aiEnabled,
    required this.aiMode,
    required this.dataSourcesMonitored,
    required this.confidenceScore,
    required this.onAITapped,
  }) : super(key: key);

  @override
  State<AIStatusBanner> createState() => _AIStatusBannerState();
}

class _AIStatusBannerState extends State<AIStatusBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getConfidenceColor() {
    if (widget.confidenceScore >= 75) {
      return const Color(0xFF10B981); // Green
    } else if (widget.confidenceScore >= 50) {
      return const Color(0xFFF59E0B); // Amber
    } else {
      return const Color(0xFFEF4444); // Red
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onAITapped,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1E293B),
                  const Color(0xFF1E293B).withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.aiEnabled
                    ? const Color(0xFF3B82F6).withOpacity(
                        0.3 + (0.2 * _pulseController.value),
                      )
                    : Colors.white.withOpacity(0.1),
              ),
              boxShadow: widget.aiEnabled
                  ? [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withOpacity(
                          0.1 * _pulseController.value,
                        ),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // AI Icon + Status
                Row(
                  children: [
                    // Pulsing AI Icon
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(
                          widget.aiEnabled
                              ? 0.2 + (0.1 * _pulseController.value)
                              : 0.1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Opacity(
                          opacity: widget.aiEnabled
                              ? 0.8 + (0.2 * _pulseController.value)
                              : 0.5,
                          child: Text(
                            '🧠',
                            style: const TextStyle(
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Status Text
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'AI Mode: ',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              widget.aiMode,
                              style: TextStyle(
                                color: widget.aiEnabled
                                    ? const Color(0xFF3B82F6)
                                    : Colors.white.withOpacity(0.5),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Monitoring ',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              '${widget.dataSourcesMonitored} data sources',
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                // Confidence Score
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Confidence',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getConfidenceColor().withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _getConfidenceColor().withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        '${widget.confidenceScore.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: _getConfidenceColor(),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
