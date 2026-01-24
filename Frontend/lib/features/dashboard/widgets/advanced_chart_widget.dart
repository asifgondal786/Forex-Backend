import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AdvancedChartWidget extends StatefulWidget {
  const AdvancedChartWidget({super.key});

  @override
  State<AdvancedChartWidget> createState() => _AdvancedChartWidgetState();
}

class _AdvancedChartWidgetState extends State<AdvancedChartWidget> {
  int _selectedChartType = 0;
  final List<String> _chartTypes = ['Equity Curve', 'Daily Returns', 'Drawdown'];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.02),
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
                  const Text(
                    '📈 Advanced Analytics Charts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Visual analysis of trading performance',
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

          // Chart Type Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(
                _chartTypes.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedChartType = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedChartType == index
                            ? const Color(0xFF3B82F6)
                            : Colors.white.withValues(alpha: 0.05),
                        border: Border.all(
                          color: _selectedChartType == index
                              ? const Color(0xFF3B82F6)
                              : Colors.white.withValues(alpha: 0.1),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _chartTypes[index],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _selectedChartType == index
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

          // Chart Display
          if (_selectedChartType == 0)
            _buildEquityCurveChart(isMobile)
          else if (_selectedChartType == 1)
            _buildDailyReturnsChart(isMobile)
          else
            _buildDrawdownChart(isMobile),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: const Duration(milliseconds: 600))
        .slideY(begin: 0.2);
  }

  Widget _buildEquityCurveChart(bool isMobile) {
    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 500,
            verticalInterval: 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.white.withValues(alpha: 0.1),
                strokeWidth: 1,
              );
            },
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: Colors.white.withValues(alpha: 0.1),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  return Text(
                    'Day ${value.toInt()}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '\$${value.toInt()}k',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                    ),
                  );
                },
                reservedSize: 50,
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                const FlSpot(1, 10000),
                const FlSpot(2, 10500),
                const FlSpot(3, 10800),
                const FlSpot(4, 11200),
                const FlSpot(5, 11000),
                const FlSpot(6, 11500),
                const FlSpot(7, 12300),
                const FlSpot(8, 12100),
                const FlSpot(9, 12800),
                const FlSpot(10, 13450),
              ],
              isCurved: true,
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF3B82F6)],
              ),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF10B981).withValues(alpha: 0.1),
                    const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  ],
                ),
              ),
            ),
          ],
          minX: 0,
          maxX: 11,
          minY: 9000,
          maxY: 14000,
        ),
      ),
    );
  }

  Widget _buildDailyReturnsChart(bool isMobile) {
    return SizedBox(
      height: 300,
      child: BarChart(
        BarChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 0.5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.white.withValues(alpha: 0.1),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      days[value.toInt() % 5],
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}%',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                    ),
                  );
                },
                reservedSize: 40,
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            makeGroupData(0, 1.5, const Color(0xFF10B981)),
            makeGroupData(1, -0.8, const Color(0xFFEF4444)),
            makeGroupData(2, 2.3, const Color(0xFF10B981)),
            makeGroupData(3, 0.5, const Color(0xFF10B981)),
            makeGroupData(4, -1.2, const Color(0xFFEF4444)),
          ],
          minY: -3,
          maxY: 3,
        ),
      ),
    );
  }

  Widget _buildDrawdownChart(bool isMobile) {
    return SizedBox(
      height: 300,
      child: AreaChart(
        AreaChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.white.withValues(alpha: 0.1),
                strokeWidth: 1,
              );
            },
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: Colors.white.withValues(alpha: 0.1),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    'Day ${value.toInt()}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                    ),
                  );
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}%',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                    ),
                  );
                },
                reservedSize: 40,
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          areaData: AreaChartData(
            spots: [
              const FlSpot(1, 0),
              const FlSpot(2, -1.2),
              const FlSpot(3, -2.5),
              const FlSpot(4, -1.8),
              const FlSpot(5, 0),
              const FlSpot(6, -0.5),
              const FlSpot(7, -3.2),
              const FlSpot(8, -2.1),
              const FlSpot(9, -1.5),
              const FlSpot(10, 0),
            ],
            areaTooltipOnBarTouchData: AreaTooltipOnBarTouchData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((touchedSpot) {
                  return LineTooltipItem(
                    '${touchedSpot.y.toStringAsFixed(2)}%',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
              },
            ),
            gradientFrom: const Offset(0, 0),
            gradientTo: const Offset(0, 1),
            color: const Color(0xFFEF4444).withValues(alpha: 0.3),
            borderLine: BorderLine(
              color: const Color(0xFFEF4444),
              width: 2,
              isRounded: true,
            ),
          ),
          minY: -4,
          maxY: 1,
        ),
      ),
    );
  }

  BarChartGroupData makeGroupData(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 15,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}
