import 'package:flutter/material.dart';

/// Market Replay - Educational backtesting simulator
/// Features:
/// - "Rewind: What if AI traded differently yesterday?"
/// - Compare actual trades vs alternative scenarios
/// - Learn what happens with different strategies
/// - Professional gamification (not childish)
class MarketReplay extends StatefulWidget {
  final ReplaySession session;
  final VoidCallback onScenarioChanged;

  const MarketReplay({
    Key? key,
    required this.session,
    required this.onScenarioChanged,
  }) : super(key: key);

  @override
  State<MarketReplay> createState() => _MarketReplayState();
}

class _MarketReplayState extends State<MarketReplay>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _slideController;
  int _currentScenarioIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _changeScenario(int index) {
    _slideController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() => _currentScenarioIndex = index);
        widget.onScenarioChanged();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scenario = widget.session.scenarios[_currentScenarioIndex];

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
                const Row(
                  children: [
                    Text(
                      '⏮️ Market Replay',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'What if?',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF3B82F6).withOpacity(0.5),
                    ),
                  ),
                  child: const Text(
                    'Simulation',
                    style: TextStyle(
                      color: Color(0xFF3B82F6),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
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

          // Scenario display
          FadeTransition(
            opacity: Tween<double>(begin: 0.5, end: 1.0).animate(
              CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _ScenarioDisplay(
                scenario: scenario,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Scenario selector tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(
                  widget.session.scenarios.length,
                  (index) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _ScenarioTab(
                      label: widget.session.scenarios[index].name,
                      isSelected: index == _currentScenarioIndex,
                      onTap: () => _changeScenario(index),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Comparison metrics
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ComparisonMetrics(
              actualScenario: widget.session.scenarios[0],
              selectedScenario: scenario,
            ),
          ),

          const SizedBox(height: 16),

          // Learning insight
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _LearningInsight(scenario: scenario),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ScenarioDisplay extends StatelessWidget {
  final ReplayScenario scenario;

  const _ScenarioDisplay({required this.scenario});

  @override
  Widget build(BuildContext context) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scenario.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    scenario.description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 10,
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
                  color: scenario.pnl >= 0
                      ? const Color(0xFF10B981).withOpacity(0.2)
                      : const Color(0xFFEF4444).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: scenario.pnl >= 0
                        ? const Color(0xFF10B981).withOpacity(0.5)
                        : const Color(0xFFEF4444).withOpacity(0.5),
                  ),
                ),
                child: Text(
                  '${scenario.pnl >= 0 ? '+' : ''}${scenario.pnl.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: scenario.pnl >= 0
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatRow(
            label: 'Trades Made',
            value: '${scenario.tradeCount}',
            icon: '📊',
          ),
          const SizedBox(height: 6),
          _StatRow(
            label: 'Win Rate',
            value: '${scenario.winRate.toStringAsFixed(1)}%',
            icon: '🎯',
          ),
          const SizedBox(height: 6),
          _StatRow(
            label: 'Max Drawdown',
            value: '${scenario.maxDrawdown.toStringAsFixed(2)}%',
            icon: '⬇️',
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final String icon;

  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          icon,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 10,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _ScenarioTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ScenarioTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF3B82F6)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3B82F6)
                : Colors.white.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}

class _ComparisonMetrics extends StatelessWidget {
  final ReplayScenario actualScenario;
  final ReplayScenario selectedScenario;

  const _ComparisonMetrics({
    required this.actualScenario,
    required this.selectedScenario,
  });

  @override
  Widget build(BuildContext context) {
    final pnlDifference = selectedScenario.pnl - actualScenario.pnl;
    final isBetter = pnlDifference >= 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isBetter
            ? const Color(0xFF10B981).withOpacity(0.1)
            : const Color(0xFFEF4444).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isBetter
              ? const Color(0xFF10B981).withOpacity(0.3)
              : const Color(0xFFEF4444).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'vs. Actual Trades',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Difference',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${isBetter ? '+' : ''}${pnlDifference.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: isBetter
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isBetter ? 'Better' : 'Worse'}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isBetter ? '📈 Gained' : '📉 Lost',
                    style: TextStyle(
                      color: isBetter
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
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
}

class _LearningInsight extends StatelessWidget {
  final ReplayScenario scenario;

  const _LearningInsight({required this.scenario});

  @override
  Widget build(BuildContext context) {
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
          const Row(
            children: [
              Text(
                '💡',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(width: 8),
              Text(
                'What You Learned',
                style: TextStyle(
                  color: Color(0xFFF59E0B),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            scenario.learningInsight,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Data Models
class ReplaySession {
  final String date;
  final String pair;
  final List<ReplayScenario> scenarios;

  ReplaySession({
    required this.date,
    required this.pair,
    required this.scenarios,
  });

  factory ReplaySession.example() {
    return ReplaySession(
      date: '2024-01-15',
      pair: 'EUR/USD',
      scenarios: [
        ReplayScenario(
          name: 'Actual',
          description: 'AI\'s real trades from yesterday',
          pnl: 2.34,
          tradeCount: 5,
          winRate: 80.0,
          maxDrawdown: 0.5,
          learningInsight:
              'The AI entered too early on the news spike. Waiting 15 minutes would have avoided the false breakout.',
        ),
        ReplayScenario(
          name: 'Wait Longer',
          description: 'If AI waited 15 min after news',
          pnl: 3.45,
          tradeCount: 4,
          winRate: 85.0,
          maxDrawdown: 0.3,
          learningInsight:
              'Patience pays: Waiting for confirmation reduced false signals and improved profitability by 1.11%.',
        ),
        ReplayScenario(
          name: 'Smaller Risk',
          description: 'If AI used 0.5% instead of 2%',
          pnl: 1.12,
          tradeCount: 5,
          winRate: 80.0,
          maxDrawdown: 0.2,
          learningInsight:
              'Conservative sizing protects capital but limits gains. The trade-off: safety vs. growth.',
        ),
        ReplayScenario(
          name: 'Aggressive',
          description: 'If AI used 3% risk per trade',
          pnl: 4.56,
          tradeCount: 5,
          winRate: 80.0,
          maxDrawdown: 1.2,
          learningInsight:
              'Aggressive sizing amplifies wins but increases drawdown risk. Not suitable for sleep times.',
        ),
      ],
    );
  }
}

class ReplayScenario {
  final String name;
  final String description;
  final double pnl; // as percentage
  final int tradeCount;
  final double winRate; // 0-100
  final double maxDrawdown; // as percentage
  final String learningInsight;

  ReplayScenario({
    required this.name,
    required this.description,
    required this.pnl,
    required this.tradeCount,
    required this.winRate,
    required this.maxDrawdown,
    required this.learningInsight,
  });
}
