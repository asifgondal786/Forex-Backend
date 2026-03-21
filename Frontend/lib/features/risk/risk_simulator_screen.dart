import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/risk_provider.dart';

class RiskSimulatorScreen extends StatefulWidget {
  const RiskSimulatorScreen({super.key});

  @override
  State<RiskSimulatorScreen> createState() => _RiskSimulatorScreenState();
}

class _RiskSimulatorScreenState extends State<RiskSimulatorScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RiskProvider>().runSimulation();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Risk Simulator'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: Consumer<RiskProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader('Parameters'),
                const SizedBox(height: 8),
                _ParametersCard(provider: provider),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: provider.isLoading ? null : provider.runSimulation,
                  icon: provider.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(provider.isLoading ? 'Running...' : 'Run Simulation'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                if (provider.error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(provider.error!),
                ],
                if (provider.result != null) ...[
                  const SizedBox(height: 24),
                  _SectionHeader('Results — ${provider.result!.simulations} Simulations'),
                  const SizedBox(height: 12),
                  _StatsGrid(stats: provider.result!.statistics),
                  const SizedBox(height: 24),
                  _SectionHeader('Equity Curves'),
                  const SizedBox(height: 8),
                  _EquityCurveChart(
                    curves: provider.result!.sampledCurves,
                    startingBalance: provider.result!.startingBalance,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Parameters Card ──────────────────────────────────────────────────────────

class _ParametersCard extends StatelessWidget {
  final RiskProvider provider;
  const _ParametersCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _SliderRow(
              label: 'Win Rate',
              value: provider.winRate,
              display: '${(provider.winRate * 100).toStringAsFixed(0)}%',
              min: 0.3,
              max: 0.8,
              divisions: 50,
              onChanged: provider.updateWinRate,
            ),
            _SliderRow(
              label: 'Avg Win',
              value: provider.avgWin,
              display: '\$${provider.avgWin.toStringAsFixed(0)}',
              min: 10,
              max: 200,
              divisions: 190,
              onChanged: provider.updateAvgWin,
            ),
            _SliderRow(
              label: 'Avg Loss',
              value: provider.avgLoss,
              display: '\$${provider.avgLoss.toStringAsFixed(0)}',
              min: 10,
              max: 200,
              divisions: 190,
              onChanged: provider.updateAvgLoss,
            ),
            _SliderRow(
              label: 'Trades',
              value: provider.numTrades.toDouble(),
              display: '${provider.numTrades}',
              min: 20,
              max: 500,
              divisions: 48,
              onChanged: (v) => provider.updateNumTrades(v.toInt()),
            ),
            _SliderRow(
              label: 'Starting Balance',
              value: provider.startingBalance,
              display: '\$${provider.startingBalance.toStringAsFixed(0)}',
              min: 1000,
              max: 100000,
              divisions: 99,
              onChanged: provider.updateStartingBalance,
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final String display;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.display,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 64,
          child: Text(
            display,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

// ─── Stats Grid ───────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final Map<String, double> stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem('Median Final', '\$${stats['median_final']?.toStringAsFixed(0) ?? '-'}',
          _profitColor(context, stats['median_final'])),
      _StatItem('Mean Final', '\$${stats['mean_final']?.toStringAsFixed(0) ?? '-'}',
          _profitColor(context, stats['mean_final'])),
      _StatItem('P10 (Worst 10%)', '\$${stats['p10_final']?.toStringAsFixed(0) ?? '-'}',
          Colors.orange),
      _StatItem('P90 (Best 10%)', '\$${stats['p90_final']?.toStringAsFixed(0) ?? '-'}',
          Colors.green),
      _StatItem('Prob. Profit',
          '${((stats['prob_profit'] ?? 0) * 100).toStringAsFixed(1)}%', Colors.green),
      _StatItem('Prob. Ruin',
          '${((stats['prob_ruin'] ?? 0) * 100).toStringAsFixed(1)}%', Colors.red),
      _StatItem('Median Max DD',
          '${((stats['median_max_drawdown'] ?? 0) * 100).toStringAsFixed(1)}%', Colors.orange),
      _StatItem('P90 Max DD',
          '${((stats['p90_max_drawdown'] ?? 0) * 100).toStringAsFixed(1)}%', Colors.red),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.4,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: items.map((item) => _StatCard(item: item)).toList(),
    );
  }

  Color _profitColor(BuildContext context, double? value) {
    if (value == null) return Colors.grey;
    return value >= 10000 ? Colors.green : Colors.red;
  }
}

class _StatItem {
  final String label;
  final String value;
  final Color color;
  const _StatItem(this.label, this.value, this.color);
}

class _StatCard extends StatelessWidget {
  final _StatItem item;
  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(item.label,
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).textTheme.bodySmall?.color)),
            const SizedBox(height: 4),
            Text(item.value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: item.color)),
          ],
        ),
      ),
    );
  }
}

// ─── Equity Curve Chart ───────────────────────────────────────────────────────

class _EquityCurveChart extends StatelessWidget {
  final List<List<double>> curves;
  final double startingBalance;

  const _EquityCurveChart({
    required this.curves,
    required this.startingBalance,
  });

  @override
  Widget build(BuildContext context) {
    if (curves.isEmpty) return const SizedBox.shrink();

    final allValues = curves.expand((c) => c).toList();
    final minY = allValues.reduce((a, b) => a < b ? a : b);
    final maxY = allValues.reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.05;

    final lineBars = curves.asMap().entries.map((entry) {
      final spots = entry.value
          .asMap()
          .entries
          .map((e) => FlSpot(e.key.toDouble(), e.value))
          .toList();

      // Color curves green if above starting balance, red if below
      final endVal = entry.value.last;
      final color = endVal >= startingBalance
          ? Colors.green.withOpacity(0.25)
          : Colors.red.withOpacity(0.2);

      return LineChartBarData(
        spots: spots,
        isCurved: false,
        color: color,
        barWidth: 1,
        dotData: const FlDotData(show: false),
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 260,
          child: LineChart(
            LineChartData(
              lineBarsData: lineBars,
              minY: (minY - padding).clamp(0, double.infinity),
              maxY: maxY + padding,
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 56,
                    getTitlesWidget: (v, _) => Text(
                      '\$${v.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 9),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) => Text(
                      '${v.toInt()}',
                      style: const TextStyle(fontSize: 9),
                    ),
                  ),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(show: false),
              // Starting balance reference line
              extraLinesData: ExtraLinesData(horizontalLines: [
                HorizontalLine(
                  y: startingBalance,
                  color: Colors.white38,
                  strokeWidth: 1,
                  dashArray: [4, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    labelResolver: (_) => 'Start',
                    style: const TextStyle(fontSize: 9, color: Colors.white54),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold));
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: const TextStyle(color: Colors.red, fontSize: 13))),
        ],
      ),
    );
  }
}