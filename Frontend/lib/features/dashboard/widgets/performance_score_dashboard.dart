import 'package:flutter/material.dart';

/// Performance Score Dashboard - Professional gamification with 3 main metrics
/// Features:
/// - AI Win Rate: % of winning trades
/// - Capital Protection: Drawdown resistance score
/// - Risk Discipline: Adherence to rules score
/// - Real-time updates with animations
class PerformanceScoreDashboard extends StatefulWidget {
  final PerformanceMetrics metrics;

  const PerformanceScoreDashboard({
    Key? key,
    required this.metrics,
  }) : super(key: key);

  @override
  State<PerformanceScoreDashboard> createState() =>
      _PerformanceScoreDashboardState();
}

class _PerformanceScoreDashboardState extends State<PerformanceScoreDashboard>
    with TickerProviderStateMixin {
  late AnimationController _scoreController;

  @override
  void initState() {
    super.initState();
    _scoreController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _scoreController.dispose();
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
                const Text(
                  '🏅 Performance Scores',
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
                    color: _getOverallGradeColor().withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _getOverallGradeColor().withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    'Grade: ${_getOverallGrade()}',
                    style: TextStyle(
                      color: _getOverallGradeColor(),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            height: 1,
            color: Color(0xFFFFFFFF),
            opacity: 0.05,
          ),

          // Main scores
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildScoreCard(
                        title: 'Win Rate',
                        score: widget.metrics.winRateScore,
                        icon: '🎯',
                        description: '${widget.metrics.winRatePercentage.toStringAsFixed(1)}% wins',
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildScoreCard(
                        title: 'Capital Protection',
                        score: widget.metrics.capitalProtectionScore,
                        icon: '🛡️',
                        description:
                            'Max DD: ${widget.metrics.maxDrawdownPercent.toStringAsFixed(2)}%',
                        color: const Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildScoreCard(
                  title: 'Risk Discipline',
                  score: widget.metrics.riskDisciplineScore,
                  icon: '📏',
                  description: widget.metrics.rulesViolations == 0
                      ? 'Perfect adherence'
                      : '${widget.metrics.rulesViolations} violations',
                  color: const Color(0xFFF59E0B),
                  fullWidth: true,
                ),
              ],
            ),
          ),

          const Divider(
            height: 1,
            color: Color(0xFFFFFFFF),
            opacity: 0.05,
          ),

          // Detailed breakdown
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildDetailedBreakdown(),
          ),

          // Trend indicators
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildTrendIndicators(),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildScoreCard({
    required String title,
    required double score,
    required String icon,
    required String description,
    required Color color,
    bool fullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                icon,
                style: const TextStyle(fontSize: 18),
              ),
              Text(
                '${score.toStringAsFixed(0)}/100',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: AnimatedBuilder(
              animation: _scoreController,
              builder: (context, child) {
                return LinearProgressIndicator(
                  value: (score / 100) * _scoreController.value,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 4,
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detailed Analysis',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _DetailMetric(
          label: 'Total Trades',
          value: '${widget.metrics.totalTrades}',
          icon: '📊',
          secondaryValue: '${widget.metrics.winningTrades} winners',
        ),
        const SizedBox(height: 8),
        _DetailMetric(
          label: 'Avg Win',
          value: '+${widget.metrics.averageWinPercent.toStringAsFixed(2)}%',
          icon: '💹',
          isPositive: true,
        ),
        const SizedBox(height: 8),
        _DetailMetric(
          label: 'Avg Loss',
          value: '${widget.metrics.averageLossPercent.toStringAsFixed(2)}%',
          icon: '📉',
          isPositive: false,
        ),
        const SizedBox(height: 8),
        _DetailMetric(
          label: 'Risk/Reward Ratio',
          value: widget.metrics.riskRewardRatio.toStringAsFixed(2),
          icon: '⚙️',
          secondaryValue: '${widget.metrics.profitFactor.toStringAsFixed(2)}x profit factor',
        ),
        const SizedBox(height: 8),
        _DetailMetric(
          label: 'Consistency',
          value: '${widget.metrics.consistencyScore.toStringAsFixed(0)}%',
          icon: '📈',
          secondaryValue: 'Last 20 trades',
        ),
      ],
    );
  }

  Widget _buildTrendIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _TrendBadge(
          label: 'This Week',
          change: widget.metrics.weeklyTrend,
          trend: widget.metrics.weeklyTrend >= 0 ? 'up' : 'down',
        ),
        _TrendBadge(
          label: 'This Month',
          change: widget.metrics.monthlyTrend,
          trend: widget.metrics.monthlyTrend >= 0 ? 'up' : 'down',
        ),
        _TrendBadge(
          label: 'Best Day',
          change: widget.metrics.bestDayReturn,
          trend: 'neutral',
        ),
      ],
    );
  }

  String _getOverallGrade() {
    final avg = widget.metrics.overallScore;
    if (avg >= 90) return 'A+';
    if (avg >= 85) return 'A';
    if (avg >= 80) return 'A-';
    if (avg >= 75) return 'B+';
    if (avg >= 70) return 'B';
    if (avg >= 60) return 'C';
    if (avg >= 50) return 'D';
    return 'F';
  }

  Color _getOverallGradeColor() {
    final avg = widget.metrics.overallScore;
    if (avg >= 85) return const Color(0xFF10B981);
    if (avg >= 75) return const Color(0xFFF59E0B);
    if (avg >= 60) return const Color(0xFFEF4444);
    return const Color(0xFF6B7280);
  }
}

class _DetailMetric extends StatelessWidget {
  final String label;
  final String value;
  final String icon;
  final String? secondaryValue;
  final bool isPositive;

  const _DetailMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.secondaryValue,
    this.isPositive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 10,
                  ),
                ),
                if (secondaryValue != null)
                  Text(
                    secondaryValue!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 9,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: isPositive
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              if (isPositive)
                const Text(
                  '↑',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  final String label;
  final double change;
  final String trend; // 'up', 'down', 'neutral'

  const _TrendBadge({
    required this.label,
    required this.change,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    Color color = trend == 'up'
        ? const Color(0xFF10B981)
        : trend == 'down'
            ? const Color(0xFFEF4444)
            : const Color(0xFF6B7280);

    String arrow = trend == 'up'
        ? '📈'
        : trend == 'down'
            ? '📉'
            : '→';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 8,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                arrow,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 2),
              Text(
                '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Performance Metrics Data Model
class PerformanceMetrics {
  final double winRateScore; // 0-100
  final double capitalProtectionScore; // 0-100
  final double riskDisciplineScore; // 0-100

  final double winRatePercentage; // actual win rate %
  final int totalTrades;
  final int winningTrades;
  final double maxDrawdownPercent;
  final double averageWinPercent;
  final double averageLossPercent;
  final double riskRewardRatio;
  final double profitFactor;
  final double consistencyScore; // 0-100
  final int rulesViolations;

  final double weeklyTrend; // % change
  final double monthlyTrend; // % change
  final double bestDayReturn; // %

  PerformanceMetrics({
    required this.winRateScore,
    required this.capitalProtectionScore,
    required this.riskDisciplineScore,
    required this.winRatePercentage,
    required this.totalTrades,
    required this.winningTrades,
    required this.maxDrawdownPercent,
    required this.averageWinPercent,
    required this.averageLossPercent,
    required this.riskRewardRatio,
    required this.profitFactor,
    required this.consistencyScore,
    required this.rulesViolations,
    required this.weeklyTrend,
    required this.monthlyTrend,
    required this.bestDayReturn,
  });

  double get overallScore =>
      (winRateScore + capitalProtectionScore + riskDisciplineScore) / 3;

  factory PerformanceMetrics.example() {
    return PerformanceMetrics(
      winRateScore: 78.0,
      capitalProtectionScore: 82.0,
      riskDisciplineScore: 75.0,
      winRatePercentage: 68.5,
      totalTrades: 47,
      winningTrades: 32,
      maxDrawdownPercent: 2.34,
      averageWinPercent: 1.23,
      averageLossPercent: 0.89,
      riskRewardRatio: 1.38,
      profitFactor: 2.15,
      consistencyScore: 72.0,
      rulesViolations: 2,
      weeklyTrend: 5.23,
      monthlyTrend: 12.45,
      bestDayReturn: 3.67,
    );
  }
}
