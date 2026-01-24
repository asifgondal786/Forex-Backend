import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Learning Indicator - Shows AI's learning progress and personalization level
/// Features:
/// - "AI has learned your behavior for X days"
/// - Progress toward mastery
/// - Emotional attachment building
/// - Customization level indicator
class LearningIndicator extends StatefulWidget {
  final LearningProgress progress;

  const LearningIndicator({
    Key? key,
    required this.progress,
  }) : super(key: key);

  @override
  State<LearningIndicator> createState() => _LearningIndicatorState();
}

class _LearningIndicatorState extends State<LearningIndicator>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..forward();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1F2937),
            const Color(0xFF111827).withOpacity(0.9),
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
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildLevelBadge(),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🧠 AI Learning',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Personalizing for your style',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                _buildDaysCount(),
              ],
            ),
          ),
          const Divider(
            height: 1,
            color: Color(0xFFFFFFFF),
            opacity: 0.05,
          ),
          const SizedBox(height: 16),

          // Main progress display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Overall mastery score
                _buildMasteryScore(),
                const SizedBox(height: 16),

                // Learning areas
                _buildLearningAreas(),
                const SizedBox(height: 16),

                // Milestones
                _buildMilestones(),
                const SizedBox(height: 16),

                // Next milestone info
                _buildNextMilestone(),
              ],
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLevelBadge() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (math.sin(_pulseController.value * 2 * math.pi) * 0.05),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getLevelColor(),
                  _getLevelColor().withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _getLevelColor().withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                _getLevelEmoji(),
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDaysCount() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          'Learning Duration',
          style: TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: const Color(0xFF3B82F6).withOpacity(0.5),
            ),
          ),
          child: Text(
            '${widget.progress.daysSinceLearningStart} days',
            style: const TextStyle(
              color: Color(0xFF3B82F6),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMasteryScore() {
    return Container(
      padding: const EdgeInsets.all(16),
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
            'Overall Mastery',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: widget.progress.masteryScore / 100,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(_getLevelColor()),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getMasteryDescription(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  Text(
                    '${widget.progress.masteryScore.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: _getLevelColor(),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    'Mastery',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLearningAreas() {
    final areas = [
      _LearningArea(
        name: 'Risk Preference',
        progress: widget.progress.riskPreferenceScore,
        icon: '⚖️',
      ),
      _LearningArea(
        name: 'Time Preference',
        progress: widget.progress.timePreferenceScore,
        icon: '⏱️',
      ),
      _LearningArea(
        name: 'Strategy Style',
        progress: widget.progress.strategyStyleScore,
        icon: '📊',
      ),
      _LearningArea(
        name: 'Market Conditions',
        progress: widget.progress.marketConditionScore,
        icon: '🌍',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Learning Areas',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(
          areas.length,
          (index) => Padding(
            padding: EdgeInsets.only(bottom: index < areas.length - 1 ? 10 : 0),
            child: _buildLearningAreaRow(areas[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildLearningAreaRow(_LearningArea area) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          child: Text(
            area.icon,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    area.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${area.progress.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: _getProgressColor(area.progress),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: area.progress / 100,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getProgressColor(area.progress),
                  ),
                  minHeight: 3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMilestones() {
    final milestones = [
      _Milestone(
        level: 1,
        name: 'First Trade',
        description: 'AI executes first trade',
        achieved: widget.progress.masteryScore >= 5,
      ),
      _Milestone(
        level: 2,
        name: 'Pattern Recognition',
        description: 'AI identifies your style',
        achieved: widget.progress.masteryScore >= 25,
      ),
      _Milestone(
        level: 3,
        name: 'Predictive',
        description: 'AI predicts your moves',
        achieved: widget.progress.masteryScore >= 50,
      ),
      _Milestone(
        level: 4,
        name: 'Mastery',
        description: 'Full personalization',
        achieved: widget.progress.masteryScore >= 75,
      ),
      _Milestone(
        level: 5,
        name: 'Expert',
        description: 'Ultimate personalization',
        achieved: widget.progress.masteryScore >= 95,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Milestones',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 60,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: milestones.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) => _buildMilestoneCard(milestones[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildMilestoneCard(_Milestone milestone) {
    return Container(
      width: 90,
      decoration: BoxDecoration(
        color: milestone.achieved
            ? const Color(0xFF10B981).withOpacity(0.15)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: milestone.achieved
              ? const Color(0xFF10B981).withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            milestone.achieved ? '✅' : '🔒',
            style: TextStyle(
              fontSize: milestone.achieved ? 16 : 14,
              opacity: milestone.achieved ? 1 : 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            milestone.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: milestone.achieved
                  ? Colors.white
                  : Colors.white.withOpacity(0.5),
              fontWeight: FontWeight.bold,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextMilestone() {
    final nextMilestone = _getNextMilestone();
    if (nextMilestone == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF10B981).withOpacity(0.15),
              const Color(0xFF059669).withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF10B981).withOpacity(0.3),
          ),
        ),
        child: const Row(
          children: [
            Text(
              '🏆',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'You\'ve achieved Expert mastery! AI is fully personalized to your style.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final progress = widget.progress.masteryScore - _getMilestoneThreshold(nextMilestone.level - 1);
    final targetProgress = _getMilestoneThreshold(nextMilestone.level) - _getMilestoneThreshold(nextMilestone.level - 1);
    final percentToNext = (progress / targetProgress * 100).clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFF59E0B).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '🎯',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next: ${nextMilestone.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      nextMilestone.description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: percentToNext / 100,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${percentToNext.toStringAsFixed(0)}% to next milestone',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  String _getLevelEmoji() {
    if (widget.progress.masteryScore >= 95) return '🏆';
    if (widget.progress.masteryScore >= 75) return '⭐';
    if (widget.progress.masteryScore >= 50) return '🌟';
    if (widget.progress.masteryScore >= 25) return '✨';
    return '🌱';
  }

  Color _getLevelColor() {
    if (widget.progress.masteryScore >= 95) return const Color(0xFFEC4899);
    if (widget.progress.masteryScore >= 75) return const Color(0xFFF59E0B);
    if (widget.progress.masteryScore >= 50) return const Color(0xFF06B6D4);
    if (widget.progress.masteryScore >= 25) return const Color(0xFF3B82F6);
    return const Color(0xFF6B7280);
  }

  Color _getProgressColor(double score) {
    if (score >= 75) return const Color(0xFF10B981);
    if (score >= 50) return const Color(0xFFF59E0B);
    if (score >= 25) return const Color(0xFF3B82F6);
    return const Color(0xFF6B7280);
  }

  String _getMasteryDescription() {
    if (widget.progress.masteryScore >= 95) {
      return 'Expert: AI perfectly adapts to your trading style';
    } else if (widget.progress.masteryScore >= 75) {
      return 'Advanced: AI strongly understands your preferences';
    } else if (widget.progress.masteryScore >= 50) {
      return 'Intermediate: AI learning your patterns';
    } else if (widget.progress.masteryScore >= 25) {
      return 'Beginner: AI starting to recognize your style';
    } else {
      return 'Novice: AI beginning to learn';
    }
  }

  _Milestone? _getNextMilestone() {
    if (widget.progress.masteryScore >= 95) return null;
    if (widget.progress.masteryScore >= 75)
      return _Milestone(
        level: 5,
        name: 'Expert',
        description: 'Ultimate personalization',
        achieved: false,
      );
    if (widget.progress.masteryScore >= 50)
      return _Milestone(
        level: 4,
        name: 'Mastery',
        description: 'Full personalization',
        achieved: false,
      );
    if (widget.progress.masteryScore >= 25)
      return _Milestone(
        level: 3,
        name: 'Predictive',
        description: 'AI predicts your moves',
        achieved: false,
      );
    return _Milestone(
      level: 2,
      name: 'Pattern Recognition',
      description: 'AI identifies your style',
      achieved: false,
    );
  }

  double _getMilestoneThreshold(int level) {
    switch (level) {
      case 0:
        return 0;
      case 1:
        return 5;
      case 2:
        return 25;
      case 3:
        return 50;
      case 4:
        return 75;
      default:
        return 95;
    }
  }
}

class _LearningArea {
  final String name;
  final double progress;
  final String icon;

  _LearningArea({
    required this.name,
    required this.progress,
    required this.icon,
  });
}

class _Milestone {
  final int level;
  final String name;
  final String description;
  final bool achieved;

  _Milestone({
    required this.level,
    required this.name,
    required this.description,
    required this.achieved,
  });
}

/// Learning Progress Data Model
class LearningProgress {
  final int daysSinceLearningStart;
  final double masteryScore; // 0-100
  final double riskPreferenceScore; // 0-100
  final double timePreferenceScore; // 0-100
  final double strategyStyleScore; // 0-100
  final double marketConditionScore; // 0-100

  LearningProgress({
    required this.daysSinceLearningStart,
    required this.masteryScore,
    required this.riskPreferenceScore,
    required this.timePreferenceScore,
    required this.strategyStyleScore,
    required this.marketConditionScore,
  });

  factory LearningProgress.example() {
    return LearningProgress(
      daysSinceLearningStart: 23,
      masteryScore: 62.5,
      riskPreferenceScore: 68.0,
      timePreferenceScore: 55.0,
      strategyStyleScore: 72.0,
      marketConditionScore: 54.0,
    );
  }
}
