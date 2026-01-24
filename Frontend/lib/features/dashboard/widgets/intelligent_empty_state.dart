import 'package:flutter/material.dart';

/// Intelligent Empty State - Replaces dead zeros with engaging, contextual guidance
/// Shows: Status, educational messaging, CTAs instead of empty task lists
enum EmptyStateType {
  noActiveTasks,
  noCompletedTasks,
  noAlerts,
  noActivities,
}

class IntelligentEmptyState extends StatefulWidget {
  final EmptyStateType type;
  final String? customStatus;
  final String customCTA;
  final VoidCallback onCTA;
  final String? secondaryCTA;
  final VoidCallback? onSecondaryCTA;

  const IntelligentEmptyState({
    Key? key,
    required this.type,
    this.customStatus,
    required this.customCTA,
    required this.onCTA,
    this.secondaryCTA,
    this.onSecondaryCTA,
  }) : super(key: key);

  @override
  State<IntelligentEmptyState> createState() => _IntelligentEmptyStateState();
}

class _IntelligentEmptyStateState extends State<IntelligentEmptyState>
    with TickerProviderStateMixin {
  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (emoji, title, status, advice) = _getContent();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1F2937).withOpacity(0.8),
            const Color(0xFF111827).withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          // Floating emoji
          AnimatedBuilder(
            animation: _floatController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, 8 * _floatController.value),
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 56),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),

          // Status text
          Text(
            widget.customStatus ?? status,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          // Advice
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFF3B82F6).withOpacity(0.3),
              ),
            ),
            child: Text(
              advice,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Primary CTA
          GestureDetector(
            onTap: widget.onCTA,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF3B82F6),
                    const Color(0xFF2563EB),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Text(
                widget.customCTA,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),

          // Secondary CTA (optional)
          if (widget.secondaryCTA != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: widget.onSecondaryCTA,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  widget.secondaryCTA!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  (String emoji, String title, String status, String advice) _getContent() {
    switch (widget.type) {
      case EmptyStateType.noActiveTasks:
        return (
          '🧠',
          'No Live AI Operations',
          'AI is actively monitoring markets. No safe opportunities have been detected yet.',
          'Create your first AI task, or let AI continue learning your preferences.',
        );
      case EmptyStateType.noCompletedTasks:
        return (
          '🚀',
          'Ready to Start',
          'Your first AI-executed trade will appear here. AI is preparing.',
          'Complete trades will be logged for your review and learning.',
        );
      case EmptyStateType.noAlerts:
        return (
          '🛡️',
          'All Clear',
          'No active alerts. AI is operating within your safety parameters.',
          'You\'ll be notified immediately if risk levels or opportunities change.',
        );
      case EmptyStateType.noActivities:
        return (
          '📊',
          'Waiting for Activity',
          'AI activity will stream here as market opportunities emerge.',
          'Even "no action" moments are intelligent—patience builds better trades.',
        );
    }
  }
}
