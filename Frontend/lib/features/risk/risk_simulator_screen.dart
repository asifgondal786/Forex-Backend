import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/risk_provider.dart';

const _kBg      = Color(0xFF0A0E1A);
const _kCard    = Color(0xFF161D2E);
const _kBorder  = Color(0xFF1E2A3D);
const _kGold    = Color(0xFFD4A853);
const _kGreen   = Color(0xFF00C896);
const _kRed     = Color(0xFFFF4560);
const _kAmber   = Color(0xFFF59E0B);
const _kBlue    = Color(0xFF3B82F6);
const _kText    = Color(0xFFE2E8F0);
const _kSubtext = Color(0xFF64748B);
const _kDivider = Color(0xFF1E2A3D);

class RiskSimulatorScreen extends StatefulWidget {
  const RiskSimulatorScreen({super.key});
  @override
  State<RiskSimulatorScreen> createState() => _RiskSimulatorScreenState();
}

class _RiskSimulatorScreenState extends State<RiskSimulatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<RiskProvider>();
      p.runSimulation();
      p.runKelly();
      p.runDrawdown();
    });
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('Risk Guardian',
            style: TextStyle(color: _kText, fontWeight: FontWeight.w700)),
        backgroundColor: _kBg,
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          labelColor: _kGold,
          unselectedLabelColor: _kSubtext,
          indicatorColor: _kGold,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'Monte Carlo'),
            Tab(text: 'Kelly'),
            Tab(text: 'Drawdown'),
            Tab(text: 'Stress Test'),
          ],
        ),
      ),
      body: Consumer<RiskProvider>(
        builder: (context, provider, _) => TabBarView(
          controller: _tabs,
          children: [
            _MonteCarloTab(provider: provider),
            _KellyTab(provider: provider),
            _DrawdownTab(provider: provider),
            _StressTestTab(provider: provider),
          ],
        ),
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(
        color: _kText, fontSize: 14, fontWeight: FontWeight.w700)),
  );
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value, min, max;
  final String display;
  final int divisions;
  final ValueChanged<double> onChanged;
  const _SliderRow({required this.label, required this.value, required this.display,
      required this.min, required this.max, required this.divisions, required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(width: 120, child: Text(label, style: const TextStyle(color: _kSubtext, fontSize: 12))),
    Expanded(child: Slider(
      value: value.clamp(min, max), min: min, max: max, divisions: divisions,
      activeColor: _kGold, onChanged: onChanged,
    )),
    SizedBox(width: 60, child: Text(display, textAlign: TextAlign.right,
        style: const TextStyle(color: _kText, fontWeight: FontWeight.w600, fontSize: 12))),
  ]);
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final Color color;
  const _InfoRow(this.label, this.value, {this.color = _kText});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Text(label, style: const TextStyle(color: _kSubtext, fontSize: 12)),
      const Spacer(),
      Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kDivider)),
    child: child,
  );
}

// ─── Tab 1: Monte Carlo ───────────────────────────────────────────────────────

class _MonteCarloTab extends StatelessWidget {
  const _MonteCarloTab({required this.provider});
  final RiskProvider provider;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionHeader('Parameters'),
      _Card(child: Column(children: [
        _SliderRow(label: 'Win Rate', value: provider.winRate,
            display: '${(provider.winRate*100).toStringAsFixed(0)}%',
            min: 0.3, max: 0.8, divisions: 50, onChanged: provider.updateWinRate),
        _SliderRow(label: 'Avg Win', value: provider.avgWin,
            display: '\$${provider.avgWin.toStringAsFixed(0)}',
            min: 10, max: 200, divisions: 190, onChanged: provider.updateAvgWin),
        _SliderRow(label: 'Avg Loss', value: provider.avgLoss,
            display: '\$${provider.avgLoss.toStringAsFixed(0)}',
            min: 10, max: 200, divisions: 190, onChanged: provider.updateAvgLoss),
        _SliderRow(label: 'Num Trades', value: provider.numTrades.toDouble(),
            display: '${provider.numTrades}',
            min: 20, max: 500, divisions: 48, onChanged: (v) => provider.updateNumTrades(v.toInt())),
        _SliderRow(label: 'Balance', value: provider.startingBalance,
            display: '\$${provider.startingBalance.toStringAsFixed(0)}',
            min: 1000, max: 100000, divisions: 99, onChanged: provider.updateStartingBalance),
      ])),
      const SizedBox(height: 12),
      ElevatedButton.icon(
        onPressed: provider.isLoading ? null : provider.runSimulation,
        icon: provider.isLoading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.play_arrow),
        label: Text(provider.isLoading ? 'Running...' : 'Run Simulation'),
        style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            backgroundColor: _kGold, foregroundColor: Colors.black),
      ),
      if (provider.result != null) ...[
        const SizedBox(height: 20),
        const _SectionHeader('Results'),
        _StatsGrid(stats: provider.result!.statistics,
            startingBalance: provider.result!.startingBalance),
        const SizedBox(height: 20),
        const _SectionHeader('Equity Curves'),
        _EquityCurveChart(curves: provider.result!.sampledCurves,
            startingBalance: provider.result!.startingBalance),
      ],
    ]),
  );
}

class _StatsGrid extends StatelessWidget {
  final Map<String, double> stats;
  final double startingBalance;
  const _StatsGrid({required this.stats, required this.startingBalance});

  @override
  Widget build(BuildContext context) {
    final items = [
      _SI('Median Final', '\$${stats['median_final']?.toStringAsFixed(0)?? '-'}',
          (stats['median_final'] ?? 0) >= startingBalance ? _kGreen : _kRed),
      _SI('Mean Final', '\$${stats['mean_final']?.toStringAsFixed(0) ?? '-'}',
          (stats['mean_final'] ?? 0) >= startingBalance ? _kGreen : _kRed),
      _SI('P10 Worst', '\$${stats['p10_final']?.toStringAsFixed(0) ?? '-'}', _kAmber),
      _SI('P90 Best', '\$${stats['p90_final']?.toStringAsFixed(0) ?? '-'}', _kGreen),
      _SI('Prob Profit', '${((stats['prob_profit'] ?? 0)*100).toStringAsFixed(1)}%', _kGreen),
      _SI('Prob Ruin', '${((stats['prob_ruin'] ?? 0)*100).toStringAsFixed(1)}%', _kRed),
      _SI('Median DD', '${((stats['median_max_drawdown'] ?? 0)*100).toStringAsFixed(1)}%', _kAmber),
      _SI('P90 DD', '${((stats['p90_max_drawdown'] ?? 0)*100).toStringAsFixed(1)}%', _kRed),
    ];
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.4, mainAxisSpacing: 8, crossAxisSpacing: 8,
      children: items.map((i) => _Card(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(i.label, style: const TextStyle(color: _kSubtext, fontSize: 10)),
          const SizedBox(height: 4),
          Text(i.value, style: TextStyle(color: i.color, fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      ))).toList(),
    );
  }
}

class _SI { final String label, value; final Color color;
  const _SI(this.label, this.value, this.color); }

class _EquityCurveChart extends StatelessWidget {
  final List<List<double>> curves;
  final double startingBalance;
  const _EquityCurveChart({required this.curves, required this.startingBalance});

  @override
  Widget build(BuildContext context) {
    if (curves.isEmpty) return const SizedBox.shrink();
    final allValues = curves.expand((c) => c).toList();
    final minY = allValues.reduce((a, b) => a < b ? a : b);
    final maxY = allValues.reduce((a, b) => a > b ? a : b);
    final pad  = (maxY - minY) * 0.05;

    final lineBars = curves.map((c) {
      final spots = c.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
      final color = c.last >= startingBalance
          ? _kGreen.withOpacity(0.25) : _kRed.withOpacity(0.2);
      return LineChartBarData(spots: spots, isCurved: false, color: color,
          barWidth: 1, dotData: const FlDotData(show: false));
    }).toList();

    return _Card(child: SizedBox(height: 220, child: LineChart(LineChartData(
      lineBarsData: lineBars,
      minY: (minY - pad).clamp(0, double.infinity), maxY: maxY + pad,
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50,
            getTitlesWidget: (v, _) => Text('\$${v.toStringAsFixed(0)}',
                style: const TextStyle(color: _kSubtext, fontSize: 8)))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
            getTitlesWidget: (v, _) => Text('${v.toInt()}',
                style: const TextStyle(color: _kSubtext, fontSize: 8)))),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(show: true, getDrawingHorizontalLine: (_) =>
          FlLine(color: _kDivider, strokeWidth: 0.5)),
      borderData: FlBorderData(show: false),
      extraLinesData: ExtraLinesData(horizontalLines: [
        HorizontalLine(y: startingBalance, color: _kGold.withOpacity(0.4),
            strokeWidth: 1, dashArray: [4, 4]),
      ]),
    ))));
  }
}

// ─── Tab 2: Kelly Criterion ───────────────────────────────────────────────────

class _KellyTab extends StatelessWidget {
  const _KellyTab({required this.provider});
  final RiskProvider provider;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionHeader('Kelly Fraction'),
      _Card(child: _SliderRow(
          label: 'Kelly Fraction', value: provider.kellyFraction,
          display: '${(provider.kellyFraction*100).toStringAsFixed(0)}%',
          min: 0.1, max: 1.0, divisions: 9, onChanged: provider.updateKellyFraction)),
      const SizedBox(height: 8),
      const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Text('Quarter-Kelly (25%) is the recommended safe default.',
            style: TextStyle(color: _kSubtext, fontSize: 11)),
      ),
      ElevatedButton.icon(
        onPressed: provider.isKellyLoading ? null : provider.runKelly,
        icon: provider.isKellyLoading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.calculate_rounded),
        label: Text(provider.isKellyLoading ? 'Calculating...' : 'Calculate Kelly'),
        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48),
            backgroundColor: _kBlue, foregroundColor: Colors.white),
      ),
      if (provider.kellyResult != null) ...[
        const SizedBox(height: 20),
        const _SectionHeader('Position Sizing'),
        _Card(child: Column(children: [
          _InfoRow('Full Kelly %', '${provider.kellyResult!['full_kelly_pct']}%', color: _kAmber),
          _InfoRow('Safe Kelly %', '${provider.kellyResult!['safe_kelly_pct']}%', color: _kGold),
          _InfoRow('Risk Per Trade', '\$${provider.kellyResult!['risk_per_trade_usd']}', color: _kGreen),
          _InfoRow('Recommended Lots', '${provider.kellyResult!['recommended_lots']}', color: _kBlue),
          _InfoRow('R:R Ratio', '1:${provider.kellyResult!['rr_ratio']}', color: _kText),
          const Divider(color: _kDivider, height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _kGold.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kGold.withOpacity(0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.lightbulb_outline_rounded, color: _kGold, size: 14),
              const SizedBox(width: 8),
              Expanded(child: Text(
                provider.kellyResult!['interpretation'] as String? ?? '',
                style: const TextStyle(color: _kGold, fontSize: 11),
              )),
            ]),
          ),
        ])),
      ],
    ]),
  );
}

// ─── Tab 3: Drawdown Controls ─────────────────────────────────────────────────

class _DrawdownTab extends StatelessWidget {
  const _DrawdownTab({required this.provider});
  final RiskProvider provider;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionHeader('Risk Parameters'),
      _Card(child: Column(children: [
        _SliderRow(label: 'Daily Limit', value: provider.dailyLimitPct,
            display: '${provider.dailyLimitPct.toStringAsFixed(1)}%',
            min: 1.0, max: 10.0, divisions: 18, onChanged: provider.updateDailyLimit),
        _SliderRow(label: 'Weekly Limit', value: provider.weeklyLimitPct,
            display: '${provider.weeklyLimitPct.toStringAsFixed(1)}%',
            min: 2.0, max: 20.0, divisions: 18, onChanged: provider.updateWeeklyLimit),
        _SliderRow(label: 'Max Trades', value: provider.maxOpenTrades.toDouble(),
            display: '${provider.maxOpenTrades}',
            min: 1, max: 10, divisions: 9, onChanged: (v) => provider.updateMaxOpenTrades(v.toInt())),
        _SliderRow(label: 'Risk/Trade', value: provider.riskPerTradePct,
            display: '${provider.riskPerTradePct.toStringAsFixed(1)}%',
            min: 0.5, max: 5.0, divisions: 9, onChanged: provider.updateRiskPerTrade),
      ])),
      const SizedBox(height: 12),
      ElevatedButton.icon(
        onPressed: provider.isDrawdownLoading ? null : provider.runDrawdown,
        icon: provider.isDrawdownLoading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.shield_rounded),
        label: Text(provider.isDrawdownLoading ? 'Calculating...' : 'Calculate Limits'),
        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48),
            backgroundColor: _kGreen, foregroundColor: Colors.black),
      ),
      if (provider.drawdownResult != null) ...[
        const SizedBox(height: 20),
        const _SectionHeader('Trading Limits'),
        _Card(child: Column(children: [
          _InfoRow('Daily Stop Loss', '\$${provider.drawdownResult!['daily_limit_usd']}', color: _kRed),
          _InfoRow('Weekly Stop Loss', '\$${provider.drawdownResult!['weekly_limit_usd']}', color: _kAmber),
          _InfoRow('Risk Per Trade', '\$${provider.drawdownResult!['risk_per_trade_usd']}', color: _kGold),
          _InfoRow('Max Portfolio Risk', '\$${provider.drawdownResult!['max_portfolio_risk']}', color: _kBlue),
          _InfoRow('Ruin Threshold', '\$${provider.drawdownResult!['ruin_threshold_usd']}', color: _kRed),
        ])),
        const SizedBox(height: 12),
        const _SectionHeader('Rules'),
        _Card(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: ((provider.drawdownResult!['rules'] as List?) ?? [])
              .cast<String>()
              .map((rule) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.check_circle_outline_rounded, color: _kGreen, size: 14),
                  const SizedBox(width: 8),
                  Expanded(child: Text(rule, style: const TextStyle(color: _kText, fontSize: 12))),
                ]),
              )).toList(),
        )),
      ],
    ]),
  );
}

// ─── Tab 4: Stress Test ───────────────────────────────────────────────────────

class _StressTestTab extends StatelessWidget {
  const _StressTestTab({required this.provider});
  final RiskProvider provider;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text(
        'Stress test runs your strategy under 3 market regimes using current Monte Carlo parameters.',
        style: TextStyle(color: _kSubtext, fontSize: 12),
      ),
      const SizedBox(height: 12),
      ElevatedButton.icon(
        onPressed: provider.isStressLoading ? null : provider.runStressTest,
        icon: provider.isStressLoading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.bolt_rounded),
        label: Text(provider.isStressLoading ? 'Running Stress Test...' : 'Run Stress Test'),
        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48),
            backgroundColor: _kAmber, foregroundColor: Colors.black),
      ),
      if (provider.stressResult != null) ...[
        const SizedBox(height: 20),
        ...['normal_market', 'bear_market', 'crisis'].map((key) {
          final regime = provider.stressResult![key] as Map<String, dynamic>?;
          if (regime == null) return const SizedBox.shrink();
          final probProfit = (regime['prob_profit'] as num? ?? 0) * 100;
          final probRuin   = (regime['prob_ruin']   as num? ?? 0) * 100;
          final medFinal   = regime['median_final'] as num? ?? 0;
          final color = key == 'normal_market' ? _kGreen
              : key == 'bear_market' ? _kAmber : _kRed;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 4, height: 40,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 10),
                Text(regime['label'] as String? ?? key,
                    style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 10),
              _InfoRow('Median Final', '\$${medFinal.toStringAsFixed(0)}',
                  color: medFinal >= provider.startingBalance ? _kGreen : _kRed),
              _InfoRow('Prob Profit', '${probProfit.toStringAsFixed(1)}%', color: _kGreen),
              _InfoRow('Prob Ruin', '${probRuin.toStringAsFixed(1)}%', color: _kRed),
              _InfoRow('Max Drawdown',
                  '${((regime['median_max_drawdown'] as num? ?? 0)*100).toStringAsFixed(1)}%',
                  color: _kAmber),
            ])),
          );
        }),
      ],
    ]),
  );
}