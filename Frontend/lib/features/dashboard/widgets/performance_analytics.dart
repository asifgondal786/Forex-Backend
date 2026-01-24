import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PerformanceAnalytics extends StatefulWidget {
  const PerformanceAnalytics({super.key});

  @override
  State<PerformanceAnalytics> createState() => _PerformanceAnalyticsState();
}

class _PerformanceAnalyticsState extends State<PerformanceAnalytics> {
  int _selectedPeriod = 0;
  final List<String> _periods = ['1D', '1W', '1M', '3M', '1Y'];

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
                    '📊 Performance Analytics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Trading performance metrics & statistics',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Period Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(
                _periods.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPeriod = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedPeriod == index
                            ? const Color(0xFF3B82F6)
                            : Colors.white.withOpacity(0.05),
                        border: Border.all(
                          color: _selectedPeriod == index
                              ? const Color(0xFF3B82F6)
                              : Colors.white.withOpacity(0.1),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _periods[index],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _selectedPeriod == index
                              ? Colors.white
                              : Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Key Metrics
          if (!isMobile)
            GridView.count(
              crossAxisCount: 4,
              childAspectRatio: 1.1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildMetricCard(
                  'Total Return',
                  '+12.45%',
                  const Color(0xFF10B981),
                  Icons.trending_up,
                  0,
                ),
                _buildMetricCard(
                  'Win Rate',
                  '68.5%',
                  const Color(0xFF3B82F6),
                  Icons.adjust,
                  1,
                ),
                _buildMetricCard(
                  'Profit Factor',
                  '2.34x',
                  const Color(0xFF8B5CF6),
                  Icons.functions,
                  2,
                ),
                _buildMetricCard(
                  'Max Drawdown',
                  '-8.2%',
                  const Color(0xFFF59E0B),
                  Icons.trending_down,
                  3,
                ),
              ],
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'Total Return',
                        '+12.45%',
                        const Color(0xFF10B981),
                        Icons.trending_up,
                        0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        'Win Rate',
                        '68.5%',
                        const Color(0xFF3B82F6),
                        Icons.adjust,
                        1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'Profit Factor',
                        '2.34x',
                        const Color(0xFF8B5CF6),
                        Icons.functions,
                        2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        'Max Drawdown',
                        '-8.2%',
                        const Color(0xFFF59E0B),
                        Icons.trending_down,
                        3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 24),

          // Win/Loss Breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Win/Loss Distribution',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 68,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.3),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color:
                                    const Color(0xFF10B981).withOpacity(0.2),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: LinearProgressIndicator(
                                value: 0.685,
                                backgroundColor: Colors.transparent,
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Wins: 68.5%',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 32,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withOpacity(0.3),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color:
                                    const Color(0xFFEF4444).withOpacity(0.2),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: LinearProgressIndicator(
                                value: 0.315,
                                backgroundColor: Colors.transparent,
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Losses: 31.5%',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.w600,
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
          const SizedBox(height: 24),

          // Trade Statistics Table
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trade Statistics',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatRow('Total Trades', '43', Colors.white),
                _buildStatRow('Avg Win', '+156 pips', const Color(0xFF10B981)),
                _buildStatRow('Avg Loss', '-92 pips', const Color(0xFFEF4444)),
                _buildStatRow('Best Trade', '+428 pips', const Color(0xFF10B981)),
                _buildStatRow(
                    'Worst Trade', '-245 pips', const Color(0xFFEF4444)),
                _buildStatRow('Profit/Loss', '+\$3,450', const Color(0xFF10B981)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    Color color,
    IconData icon,
    int delay,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[400],
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: const Duration(milliseconds: 600))
        .slideY(
          begin: 0.2,
          delay: Duration(milliseconds: delay * 100),
        );
  }

  Widget _buildStatRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
