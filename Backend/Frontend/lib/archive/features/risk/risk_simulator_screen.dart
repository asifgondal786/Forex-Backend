import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ═════════════════════════════════════════════════════════════════════════════
// RiskProvider
// Self-contained — no external API. All computation is local.
// Handles: Monte Carlo simulation, Kelly criterion, drawdown limits, stress test.
// ═════════════════════════════════════════════════════════════════════════════

class RiskProvider extends ChangeNotifier {
  // ── Shared parameters ──────────────────────────────────────────────────────
  double _winRate = 0.55;          // 0.0–1.0
  double _avgWin = 80.0;           // USD
  double _avgLoss = 50.0;          // USD
  int _numTrades = 100;
  double _startingBalance = 10000.0;

  // ── Kelly parameters ───────────────────────────────────────────────────────
  double _kellyFraction = 0.25;    // fraction of full Kelly to use

  // ── Drawdown parameters ────────────────────────────────────────────────────
  double _dailyLimitPct = 3.0;
  double _weeklyLimitPct = 8.0;
  int _maxOpenTrades = 5;
  double _riskPerTradePct = 1.0;

  // ── Stress / local params (mirrored for Kelly & Stress tabs) ───────────────
  double _winLossRatio = 2.0;      // used for local Kelly gauge
  double _localWinRate = 60.0;     // percent, used in local Kelly gauge
  double _consecutiveLosses = 5;
  double _localRiskPerTrade = 2.0; // percent, used in local stress/drawdown
  double _maxDrawdownTarget = 20.0;
  double _accountSize = 10000.0;

  // ── Loading flags ──────────────────────────────────────────────────────────
  bool _isLoading = false;
  bool _isKellyLoading = false;
  bool _isDrawdownLoading = false;
  bool _isStressLoading = false;

  // ── Results ────────────────────────────────────────────────────────────────
  MonteCarloResult? _result;
  Map<String, dynamic>? _kellyResult;
  Map<String, dynamic>? _drawdownResult;
  Map<String, dynamic>? _stressResult;

  // ── Getters ────────────────────────────────────────────────────────────────
  double get winRate => _winRate;
  double get avgWin => _avgWin;
  double get avgLoss => _avgLoss;
  int get numTrades => _numTrades;
  double get startingBalance => _startingBalance;
  double get kellyFraction => _kellyFraction;
  double get dailyLimitPct => _dailyLimitPct;
  double get weeklyLimitPct => _weeklyLimitPct;
  int get maxOpenTrades => _maxOpenTrades;
  double get riskPerTradePct => _riskPerTradePct;
  double get winLossRatio => _winLossRatio;
  double get localWinRate => _localWinRate;
  double get consecutiveLosses => _consecutiveLosses;
  double get localRiskPerTrade => _localRiskPerTrade;
  double get maxDrawdownTarget => _maxDrawdownTarget;
  double get accountSize => _accountSize;
  bool get isLoading => _isLoading;
  bool get isKellyLoading => _isKellyLoading;
  bool get isDrawdownLoading => _isDrawdownLoading;
  bool get isStressLoading => _isStressLoading;
  MonteCarloResult? get result => _result;
  Map<String, dynamic>? get kellyResult => _kellyResult;
  Map<String, dynamic>? get drawdownResult => _drawdownResult;
  Map<String, dynamic>? get stressResult => _stressResult;

  // ── Shared parameter updaters ──────────────────────────────────────────────
  void updateWinRate(double v) { _winRate = v; notifyListeners(); }
  void updateAvgWin(double v) { _avgWin = v; notifyListeners(); }
  void updateAvgLoss(double v) { _avgLoss = v; notifyListeners(); }
  void updateNumTrades(int v) { _numTrades = v; notifyListeners(); }
  void updateStartingBalance(double v) { _startingBalance = v; notifyListeners(); }
  void updateKellyFraction(double v) { _kellyFraction = v; notifyListeners(); }
  void updateDailyLimit(double v) { _dailyLimitPct = v; notifyListeners(); }
  void updateWeeklyLimit(double v) { _weeklyLimitPct = v; notifyListeners(); }
  void updateMaxOpenTrades(int v) { _maxOpenTrades = v; notifyListeners(); }
  void updateRiskPerTrade(double v) { _riskPerTradePct = v; notifyListeners(); }
  void updateWinLossRatio(double v) { _winLossRatio = v; notifyListeners(); }
  void updateLocalWinRate(double v) { _localWinRate = v; notifyListeners(); }
  void updateConsecutiveLosses(double v) { _consecutiveLosses = v; notifyListeners(); }
  void updateLocalRiskPerTrade(double v) { _localRiskPerTrade = v; notifyListeners(); }
  void updateMaxDrawdownTarget(double v) { _maxDrawdownTarget = v; notifyListeners(); }
  void updateAccountSize(double v) { _accountSize = v; notifyListeners(); }

  // ── Local computed getters (no async needed) ───────────────────────────────

  /// Full Kelly % from local inputs (for Kelly gauge widget).
  double get localKellyCriterion {
    final w = _localWinRate / 100;
    final r = _winLossRatio;
    if (r <= 0) return 0;
    return (w - (1 - w) / r) * 100;
  }

  double get localSafeKelly => localKellyCriterion / 2;

  /// Max consecutive losses before hitting drawdown target.
  double get maxConsecutiveLosses {
    final riskDecimal = _localRiskPerTrade / 100;
    if (riskDecimal <= 0) return 0;
    return _maxDrawdownTarget / 100 / riskDecimal;
  }

  /// Dollar loss after N consecutive losses (compounding).
  double get stressLoss {
    double balance = _accountSize;
    for (int i = 0; i < _consecutiveLosses.toInt(); i++) {
      balance *= (1 - _localRiskPerTrade / 100);
    }
    return _accountSize - balance;
  }

  /// Simulated equity curve (seeded random, 30 trades) for drawdown preview.
  List<double> get simulatedEquityCurve {
    final points = <double>[];
    double balance = _accountSize;
    final rand = Random(42);
    for (int i = 0; i < 30; i++) {
      final isWin = rand.nextDouble() < _localWinRate / 100;
      balance = isWin
          ? balance + balance * (_localRiskPerTrade / 100) * _winLossRatio
          : balance - balance * (_localRiskPerTrade / 100);
      points.add(balance);
    }
    return points;
  }

  // ── Monte Carlo ────────────────────────────────────────────────────────────

  Future<void> runSimulation() async {
    _isLoading = true;
    notifyListeners();

    // Run on a separate isolate in production; here we just yield to UI.
    await Future.delayed(const Duration(milliseconds: 30));

    const int runs = 200;
    final rand = Random();
    final List<double> finalBalances = [];
    final List<double> maxDrawdowns = [];
    final List<List<double>> sampledCurves = [];

    for (int run = 0; run < runs; run++) {
      double balance = _startingBalance;
      double peak = _startingBalance;
      double maxDd = 0;
      final curve = <double>[balance];

      for (int t = 0; t < _numTrades; t++) {
        final isWin = rand.nextDouble() < _winRate;
        balance = isWin ? balance + _avgWin : balance - _avgLoss;
        balance = balance.clamp(0.0, double.infinity).toDouble();
        if (balance > peak) peak = balance;
        final double dd = peak > 0 ? (peak - balance) / peak : 0.0;
        if (dd > maxDd) maxDd = dd;
        curve.add(balance);
      }

      finalBalances.add(balance);
      maxDrawdowns.add(maxDd);
      if (sampledCurves.length < 40) sampledCurves.add(curve);
    }

    finalBalances.sort();
    maxDrawdowns.sort();

    final probProfit = finalBalances.where((b) => b > _startingBalance).length / runs;
    final probRuin = finalBalances.where((b) => b <= 0).length / runs;
    final median = finalBalances[runs ~/ 2];
    final mean = finalBalances.fold(0.0, (s, b) => s + b) / runs;
    final p10 = finalBalances[(runs * 0.10).toInt()];
    final p90 = finalBalances[(runs * 0.90).toInt()];
    final medDd = maxDrawdowns[runs ~/ 2];
    final p90Dd = maxDrawdowns[(runs * 0.90).toInt()];

    _result = MonteCarloResult(
      startingBalance: _startingBalance,
      sampledCurves: sampledCurves,
      statistics: {
        'median_final': median,
        'mean_final': mean,
        'p10_final': p10,
        'p90_final': p90,
        'prob_profit': probProfit,
        'prob_ruin': probRuin,
        'median_max_drawdown': medDd,
        'p90_max_drawdown': p90Dd,
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  // ── Kelly ──────────────────────────────────────────────────────────────────

  Future<void> runKelly() async {
    _isKellyLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 20));

    final w = _winRate;
    final b = _avgWin / (_avgLoss > 0 ? _avgLoss : 1);
    final fullKelly = (w - (1 - w) / b);
    final safeKelly = fullKelly * _kellyFraction;
    final riskUsd = _startingBalance * safeKelly;
    final rrRatio = (_avgWin / (_avgLoss > 0 ? _avgLoss : 1));

    // Rough lot estimate: 1 standard lot = ~$10/pip; assume 20pip SL
    final lots = (riskUsd / 200).clamp(0.01, 100);

    String interpretation;
    if (fullKelly <= 0) {
      interpretation =
          'Negative expected value — this setup is not worth trading at current parameters.';
    } else if (safeKelly < 0.005) {
      interpretation = 'Very small edge. Use micro lots and focus on improving win rate or R:R.';
    } else if (safeKelly < 0.02) {
      interpretation =
          'Modest edge. Risk \$${riskUsd.toStringAsFixed(0)}/trade with discipline.';
    } else {
      interpretation =
          'Strong edge detected. Safe Kelly suggests \$${riskUsd.toStringAsFixed(0)} per trade.';
    }

    _kellyResult = {
      'full_kelly_pct': (fullKelly * 100).toStringAsFixed(2),
      'safe_kelly_pct': (safeKelly * 100).toStringAsFixed(2),
      'risk_per_trade_usd': riskUsd.toStringAsFixed(2),
      'recommended_lots': lots.toStringAsFixed(2),
      'rr_ratio': rrRatio.toStringAsFixed(2),
      'interpretation': interpretation,
    };

    _isKellyLoading = false;
    notifyListeners();
  }

  // ── Drawdown limits ────────────────────────────────────────────────────────

  Future<void> runDrawdown() async {
    _isDrawdownLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 20));

    final dailyUsd = _startingBalance * _dailyLimitPct / 100;
    final weeklyUsd = _startingBalance * _weeklyLimitPct / 100;
    final riskUsd = _startingBalance * _riskPerTradePct / 100;
    final maxPortfolio = riskUsd * _maxOpenTrades;
    final ruinThreshold = _startingBalance * 0.5;

    final rules = [
      'Stop trading for the day if you lose \$${dailyUsd.toStringAsFixed(0)}.',
      'Stop trading for the week if you lose \$${weeklyUsd.toStringAsFixed(0)}.',
      'Never risk more than \$${riskUsd.toStringAsFixed(0)} on any single trade.',
      'Keep no more than $_maxOpenTrades positions open simultaneously.',
      'Max portfolio risk at any moment: \$${maxPortfolio.toStringAsFixed(0)}.',
      'Halve position sizing if balance drops below \$${ruinThreshold.toStringAsFixed(0)}.',
    ];

    _drawdownResult = {
      'daily_limit_usd': dailyUsd.toStringAsFixed(2),
      'weekly_limit_usd': weeklyUsd.toStringAsFixed(2),
      'risk_per_trade_usd': riskUsd.toStringAsFixed(2),
      'max_portfolio_risk': maxPortfolio.toStringAsFixed(2),
      'ruin_threshold_usd': ruinThreshold.toStringAsFixed(2),
      'rules': rules,
    };

    _isDrawdownLoading = false;
    notifyListeners();
  }

  // ── Stress test ────────────────────────────────────────────────────────────

  Future<void> runStressTest() async {
    _isStressLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 50));

    _stressResult = {
      'normal_market': _runRegime(
        label: '🟢 Normal Market',
        winRateAdj: 0.0,
        avgWinAdj: 0.0,
        avgLossAdj: 0.0,
      ),
      'bear_market': _runRegime(
        label: '🟡 Bear Market',
        winRateAdj: -0.08,
        avgWinAdj: -10,
        avgLossAdj: 15,
      ),
      'crisis': _runRegime(
        label: '🔴 Market Crisis',
        winRateAdj: -0.18,
        avgWinAdj: -25,
        avgLossAdj: 40,
      ),
    };

    _isStressLoading = false;
    notifyListeners();
  }

  Map<String, dynamic> _runRegime({
    required String label,
    required double winRateAdj,
    required double avgWinAdj,
    required double avgLossAdj,
  }) {
    const runs = 150;
    final rand = Random();
    final effectiveWr = (_winRate + winRateAdj).clamp(0.05, 0.95);
    final effectiveWin = (_avgWin + avgWinAdj).clamp(1.0, 10000.0);
    final effectiveLoss = (_avgLoss + avgLossAdj).clamp(1.0, 10000.0);

    final finals = <double>[];
    final dds = <double>[];

    for (int run = 0; run < runs; run++) {
      double balance = _startingBalance;
      double peak = _startingBalance;
      double maxDd = 0;

      for (int t = 0; t < _numTrades; t++) {
        final isWin = rand.nextDouble() < effectiveWr;
        balance = isWin ? balance + effectiveWin : balance - effectiveLoss;
        balance = balance.clamp(0, double.infinity);
        if (balance > peak) peak = balance;
        final dd = peak > 0 ? (peak - balance) / peak : 0.0;
        if (dd > maxDd) maxDd = dd;
      }

      finals.add(balance);
      dds.add(maxDd);
    }

    finals.sort();
    dds.sort();

    return {
      'label': label,
      'median_final': finals[runs ~/ 2],
      'prob_profit': finals.where((b) => b > _startingBalance).length / runs,
      'prob_ruin': finals.where((b) => b <= 0).length / runs,
      'median_max_drawdown': dds[runs ~/ 2],
    };
  }
}

// ─── Monte Carlo result model ─────────────────────────────────────────────────

class MonteCarloResult {
  final double startingBalance;
  final List<List<double>> sampledCurves;
  final Map<String, double> statistics;

  const MonteCarloResult({
    required this.startingBalance,
    required this.sampledCurves,
    required this.statistics,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// RiskSimulatorScreen
// 4 tabs: Monte Carlo · Kelly · Drawdown · Stress Test
// Design: Tajir ColorScheme (no hardcoded dark colours).
// ═════════════════════════════════════════════════════════════════════════════

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
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        title: Text(
          'Risk Simulator',
          style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurface.withOpacity(0.5),
          indicatorColor: scheme.primary,
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
            _MonteCarloTab(p: provider, scheme: scheme),
            _KellyTab(p: provider, scheme: scheme),
            _DrawdownTab(p: provider, scheme: scheme),
            _StressTestTab(p: provider, scheme: scheme),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Tab 1 — Monte Carlo
// ═════════════════════════════════════════════════════════════════════════════

class _MonteCarloTab extends StatelessWidget {
  final RiskProvider p;
  final ColorScheme scheme;
  const _MonteCarloTab({required this.p, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('Parameters', scheme),
          const SizedBox(height: 10),
          _Card(scheme: scheme, child: Column(children: [
            _SliderInput(
              label: 'Win Rate',
              value: p.winRate,
              min: 0.3, max: 0.8,
              display: '${(p.winRate * 100).toStringAsFixed(0)}%',
              onChanged: p.updateWinRate,
              scheme: scheme,
            ),
            _SliderInput(
              label: 'Avg Win',
              value: p.avgWin,
              min: 10, max: 200,
              display: '\$${p.avgWin.toStringAsFixed(0)}',
              onChanged: p.updateAvgWin,
              scheme: scheme,
            ),
            _SliderInput(
              label: 'Avg Loss',
              value: p.avgLoss,
              min: 10, max: 200,
              display: '\$${p.avgLoss.toStringAsFixed(0)}',
              onChanged: p.updateAvgLoss,
              scheme: scheme,
            ),
            _SliderInput(
              label: 'Trades',
              value: p.numTrades.toDouble(),
              min: 20, max: 500,
              display: '${p.numTrades}',
              onChanged: (v) => p.updateNumTrades(v.toInt()),
              scheme: scheme,
            ),
            _SliderInput(
              label: 'Balance',
              value: p.startingBalance,
              min: 1000, max: 100000,
              display: '\$${p.startingBalance.toStringAsFixed(0)}',
              onChanged: p.updateStartingBalance,
              scheme: scheme,
            ),
          ])),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: p.isLoading ? null : p.runSimulation,
              icon: p.isLoading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(p.isLoading ? 'Running…' : 'Run Simulation'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (p.result != null) ...[
            const SizedBox(height: 24),
            _SectionLabel('Results', scheme),
            const SizedBox(height: 10),
            _MonteCarloStatsGrid(result: p.result!, scheme: scheme),
            const SizedBox(height: 20),
            _SectionLabel('Equity Curves (${p.result!.sampledCurves.length} runs)', scheme),
            const SizedBox(height: 10),
            _MonteCarloChart(result: p.result!, scheme: scheme),
          ],
        ],
      ),
    );
  }
}

class _MonteCarloStatsGrid extends StatelessWidget {
  final MonteCarloResult result;
  final ColorScheme scheme;
  const _MonteCarloStatsGrid({required this.result, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final s = result.statistics;
    final start = result.startingBalance;

    final items = [
      _StatItem('Median Final',
          '\$${s['median_final']!.toStringAsFixed(0)}',
          (s['median_final']! >= start) ? Colors.green : Colors.red),
      _StatItem('Mean Final',
          '\$${s['mean_final']!.toStringAsFixed(0)}',
          (s['mean_final']! >= start) ? Colors.green : Colors.red),
      _StatItem('P10 Worst', '\$${s['p10_final']!.toStringAsFixed(0)}', Colors.orange),
      _StatItem('P90 Best', '\$${s['p90_final']!.toStringAsFixed(0)}', Colors.green),
      _StatItem('Prob Profit',
          '${(s['prob_profit']! * 100).toStringAsFixed(1)}%', Colors.green),
      _StatItem('Prob Ruin',
          '${(s['prob_ruin']! * 100).toStringAsFixed(1)}%', Colors.red),
      _StatItem('Median DD',
          '${(s['median_max_drawdown']! * 100).toStringAsFixed(1)}%', Colors.orange),
      _StatItem('P90 DD',
          '${(s['p90_max_drawdown']! * 100).toStringAsFixed(1)}%', Colors.red),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: items.map((item) => _Card(
        scheme: scheme,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(item.label,
                style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurface.withOpacity(0.5))),
            const SizedBox(height: 4),
            Text(item.value,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: item.color)),
          ],
        ),
      )).toList(),
    );
  }
}

class _StatItem {
  final String label, value;
  final Color color;
  const _StatItem(this.label, this.value, this.color);
}

class _MonteCarloChart extends StatelessWidget {
  final MonteCarloResult result;
  final ColorScheme scheme;
  const _MonteCarloChart({required this.result, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final curves = result.sampledCurves;
    if (curves.isEmpty) return const SizedBox.shrink();

    return _Card(
      scheme: scheme,
      child: SizedBox(
        height: 200,
        child: CustomPaint(
          painter: _MultiLinePainter(
            curves: curves,
            startingBalance: result.startingBalance,
            scheme: scheme,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// Draws all MC equity curves using CustomPainter — no fl_chart dependency.
class _MultiLinePainter extends CustomPainter {
  final List<List<double>> curves;
  final double startingBalance;
  final ColorScheme scheme;

  _MultiLinePainter({
    required this.curves,
    required this.startingBalance,
    required this.scheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (curves.isEmpty) return;

    final allValues = curves.expand((c) => c).toList();
    final minY = allValues.reduce((a, b) => a < b ? a : b);
    final maxY = allValues.reduce((a, b) => a > b ? a : b);
    final rangeY = (maxY - minY) == 0 ? 1.0 : (maxY - minY);
    final maxX = curves.map((c) => c.length - 1).reduce((a, b) => a > b ? a : b);

    double toX(int i) => (i / maxX) * size.width;
    double toY(double v) =>
        size.height - ((v - minY) / rangeY) * size.height * 0.9 - size.height * 0.05;

    for (final curve in curves) {
      final isProfit = curve.last >= startingBalance;
      final paint = Paint()
        ..color = (isProfit ? Colors.green : Colors.red).withOpacity(0.18)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;

      final path = Path();
      for (int i = 0; i < curve.length; i++) {
        final x = toX(i);
        final y = toY(curve[i]);
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }

    // Baseline (starting balance)
    final baseY = toY(startingBalance);
    canvas.drawLine(
      Offset(0, baseY),
      Offset(size.width, baseY),
      Paint()
        ..color = scheme.primary.withOpacity(0.5)
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..shader = null,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ═════════════════════════════════════════════════════════════════════════════
// Tab 2 — Kelly Criterion
// ═════════════════════════════════════════════════════════════════════════════

class _KellyTab extends StatelessWidget {
  final RiskProvider p;
  final ColorScheme scheme;
  const _KellyTab({required this.p, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final kellyColor = p.localKellyCriterion < 0
        ? Colors.red
        : p.localKellyCriterion < 5
            ? Colors.orange
            : Colors.green;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // ── Live local result card ──────────────────────────────────────
          _ResultCard(
            label: 'Kelly Criterion',
            value: '${p.localKellyCriterion.toStringAsFixed(1)}%',
            subLabel: 'Safe Kelly (½)',
            subValue: '${p.localSafeKelly.toStringAsFixed(1)}%',
            color: kellyColor,
            scheme: scheme,
            description: p.localKellyCriterion < 0
                ? 'Negative Kelly — this setup has a negative expected value. Do not trade.'
                : 'Risk ${p.localSafeKelly.toStringAsFixed(1)}% of your account per trade for optimal growth.',
          ),
          const SizedBox(height: 20),

          // ── Gauge ──────────────────────────────────────────────────────
          _GaugeChart(
            value: p.localKellyCriterion.clamp(0, 30),
            max: 30,
            color: kellyColor,
            scheme: scheme,
            label: 'Optimal Risk %',
          ),
          const SizedBox(height: 20),

          // ── Local inputs ───────────────────────────────────────────────
          _SliderInput(
            label: 'Win Rate',
            value: p.localWinRate,
            min: 1, max: 99,
            display: '${p.localWinRate.toStringAsFixed(0)}%',
            onChanged: p.updateLocalWinRate,
            scheme: scheme,
          ),
          const SizedBox(height: 8),
          _SliderInput(
            label: 'Win/Loss Ratio',
            value: p.winLossRatio,
            min: 0.1, max: 5,
            display: '${p.winLossRatio.toStringAsFixed(1)}:1',
            onChanged: p.updateWinLossRatio,
            scheme: scheme,
          ),
          const SizedBox(height: 16),

          // ── Kelly fraction selector ────────────────────────────────────
          _Card(scheme: scheme, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SliderInput(
                label: 'Kelly Fraction',
                value: p.kellyFraction,
                min: 0.1, max: 1.0,
                display: '${(p.kellyFraction * 100).toStringAsFixed(0)}%',
                onChanged: p.updateKellyFraction,
                scheme: scheme,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  'Quarter-Kelly (25%) is the recommended safe default.',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurface.withOpacity(0.45),
                  ),
                ),
              ),
            ],
          )),
          const SizedBox(height: 16),

          // ── Calculate button ───────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: p.isKellyLoading ? null : p.runKelly,
              icon: p.isKellyLoading
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.calculate_rounded),
              label: Text(p.isKellyLoading ? 'Calculating…' : 'Calculate Position Size'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // ── Rich result from provider ──────────────────────────────────
          if (p.kellyResult != null) ...[
            const SizedBox(height: 20),
            _Card(scheme: scheme, child: Column(
              children: [
                _InfoRow('Full Kelly %', '${p.kellyResult!['full_kelly_pct']}%',
                    color: Colors.orange, scheme: scheme),
                _InfoRow('Safe Kelly %', '${p.kellyResult!['safe_kelly_pct']}%',
                    color: scheme.primary, scheme: scheme),
                _InfoRow('Risk Per Trade', '\$${p.kellyResult!['risk_per_trade_usd']}',
                    color: Colors.green, scheme: scheme),
                _InfoRow('Recommended Lots', '${p.kellyResult!['recommended_lots']}',
                    color: Colors.blue, scheme: scheme),
                _InfoRow('R:R Ratio', '1:${p.kellyResult!['rr_ratio']}',
                    scheme: scheme),
                Divider(height: 20, color: scheme.outline.withOpacity(0.15)),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.primary.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: scheme.primary.withOpacity(0.15)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline_rounded,
                          color: scheme.primary, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          p.kellyResult!['interpretation'] as String,
                          style: TextStyle(
                              color: scheme.primary,
                              fontSize: 12,
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )),
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Tab 3 — Drawdown
// ═════════════════════════════════════════════════════════════════════════════

class _DrawdownTab extends StatelessWidget {
  final RiskProvider p;
  final ColorScheme scheme;
  const _DrawdownTab({required this.p, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Local consecutive-loss card ────────────────────────────────
          _ResultCard(
            label: 'Max Consecutive Losses',
            value: p.maxConsecutiveLosses.toStringAsFixed(0),
            subLabel: 'Before hitting drawdown target',
            subValue: '${p.maxDrawdownTarget.toStringAsFixed(0)}%',
            color: p.maxConsecutiveLosses < 5 ? Colors.red : Colors.green,
            scheme: scheme,
            description:
                'At ${p.localRiskPerTrade.toStringAsFixed(1)}% risk/trade you can absorb '
                '${p.maxConsecutiveLosses.toStringAsFixed(0)} consecutive losses before '
                'hitting your ${p.maxDrawdownTarget.toStringAsFixed(0)}% drawdown limit.',
          ),
          const SizedBox(height: 20),

          // ── Simulated equity curve ─────────────────────────────────────
          _SimulatedEquityChart(
            values: p.simulatedEquityCurve,
            accountSize: p.accountSize,
            scheme: scheme,
          ),
          const SizedBox(height: 20),

          // ── Local sliders ──────────────────────────────────────────────
          _SliderInput(
            label: 'Risk Per Trade',
            value: p.localRiskPerTrade,
            min: 0.1, max: 20,
            display: '${p.localRiskPerTrade.toStringAsFixed(1)}%',
            onChanged: p.updateLocalRiskPerTrade,
            scheme: scheme,
          ),
          const SizedBox(height: 8),
          _SliderInput(
            label: 'Max Drawdown Target',
            value: p.maxDrawdownTarget,
            min: 5, max: 80,
            display: '${p.maxDrawdownTarget.toStringAsFixed(0)}%',
            onChanged: p.updateMaxDrawdownTarget,
            scheme: scheme,
          ),
          const SizedBox(height: 16),

          // ── Risk limit sliders (server-side params) ────────────────────
          _SectionLabel('Trading Limit Parameters', scheme),
          const SizedBox(height: 10),
          _Card(scheme: scheme, child: Column(children: [
            _SliderInput(
              label: 'Daily Limit',
              value: p.dailyLimitPct,
              min: 1.0, max: 10.0,
              display: '${p.dailyLimitPct.toStringAsFixed(1)}%',
              onChanged: p.updateDailyLimit,
              scheme: scheme,
            ),
            _SliderInput(
              label: 'Weekly Limit',
              value: p.weeklyLimitPct,
              min: 2.0, max: 20.0,
              display: '${p.weeklyLimitPct.toStringAsFixed(1)}%',
              onChanged: p.updateWeeklyLimit,
              scheme: scheme,
            ),
            _SliderInput(
              label: 'Max Trades',
              value: p.maxOpenTrades.toDouble(),
              min: 1, max: 10,
              display: '${p.maxOpenTrades}',
              onChanged: (v) => p.updateMaxOpenTrades(v.toInt()),
              scheme: scheme,
            ),
            _SliderInput(
              label: 'Risk/Trade',
              value: p.riskPerTradePct,
              min: 0.5, max: 5.0,
              display: '${p.riskPerTradePct.toStringAsFixed(1)}%',
              onChanged: p.updateRiskPerTrade,
              scheme: scheme,
            ),
          ])),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: p.isDrawdownLoading ? null : p.runDrawdown,
              icon: p.isDrawdownLoading
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.shield_rounded),
              label: Text(p.isDrawdownLoading ? 'Calculating…' : 'Calculate Limits'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          if (p.drawdownResult != null) ...[
            const SizedBox(height: 20),
            _SectionLabel('Trading Limits', scheme),
            const SizedBox(height: 10),
            _Card(scheme: scheme, child: Column(children: [
              _InfoRow('Daily Stop Loss',
                  '\$${p.drawdownResult!['daily_limit_usd']}',
                  color: Colors.red, scheme: scheme),
              _InfoRow('Weekly Stop Loss',
                  '\$${p.drawdownResult!['weekly_limit_usd']}',
                  color: Colors.orange, scheme: scheme),
              _InfoRow('Risk Per Trade',
                  '\$${p.drawdownResult!['risk_per_trade_usd']}',
                  color: scheme.primary, scheme: scheme),
              _InfoRow('Max Portfolio Risk',
                  '\$${p.drawdownResult!['max_portfolio_risk']}',
                  color: Colors.blue, scheme: scheme),
              _InfoRow('Ruin Threshold',
                  '\$${p.drawdownResult!['ruin_threshold_usd']}',
                  color: Colors.red, scheme: scheme),
            ])),
            const SizedBox(height: 12),
            _SectionLabel('Rules', scheme),
            const SizedBox(height: 10),
            _Card(scheme: scheme, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: ((p.drawdownResult!['rules'] as List).cast<String>())
                  .map((rule) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                color: Colors.green, size: 14),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(rule,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurface,
                                      height: 1.4)),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            )),
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Tab 4 — Stress Test
// ═════════════════════════════════════════════════════════════════════════════

class _StressTestTab extends StatelessWidget {
  final RiskProvider p;
  final ColorScheme scheme;
  const _StressTestTab({required this.p, required this.scheme});

  // ── Local simple scenario (no async) ────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lossPercent = (p.stressLoss / p.accountSize) * 100;
    final localColor = lossPercent > 30
        ? Colors.red
        : lossPercent > 15
            ? Colors.orange
            : Colors.green;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Local consecutive-loss result card ─────────────────────────
          _ResultCard(
            label: 'Total Loss (Scenario)',
            value: '\$${p.stressLoss.toStringAsFixed(2)}',
            subLabel: 'Account drawdown',
            subValue: '${lossPercent.toStringAsFixed(1)}%',
            color: localColor,
            scheme: scheme,
            description:
                'After ${p.consecutiveLosses.toInt()} consecutive losses at '
                '${p.localRiskPerTrade.toStringAsFixed(1)}% risk, your '
                '\$${p.accountSize.toStringAsFixed(0)} account would be down '
                '\$${p.stressLoss.toStringAsFixed(2)}.',
          ),
          const SizedBox(height: 20),

          // ── Bar chart ─────────────────────────────────────────────────
          _StressBarChart(
            accountSize: p.accountSize,
            stressLoss: p.stressLoss,
            scheme: scheme,
            color: localColor,
          ),
          const SizedBox(height: 20),

          // ── Local sliders ─────────────────────────────────────────────
          _SliderInput(
            label: 'Consecutive Losses',
            value: p.consecutiveLosses,
            min: 1, max: 20,
            display: '${p.consecutiveLosses.toInt()} trades',
            onChanged: p.updateConsecutiveLosses,
            scheme: scheme,
          ),
          const SizedBox(height: 8),
          _SliderInput(
            label: 'Risk Per Trade',
            value: p.localRiskPerTrade,
            min: 0.1, max: 20,
            display: '${p.localRiskPerTrade.toStringAsFixed(1)}%',
            onChanged: p.updateLocalRiskPerTrade,
            scheme: scheme,
          ),
          const SizedBox(height: 8),
          _SliderInput(
            label: 'Account Size',
            value: p.accountSize,
            min: 100, max: 100000,
            display: '\$${p.accountSize.toStringAsFixed(0)}',
            onChanged: p.updateAccountSize,
            scheme: scheme,
          ),
          const SizedBox(height: 20),

          // ── MC stress test (3 regimes) ────────────────────────────────
          Text(
            'The Market Regime Stress Test runs your current Monte Carlo parameters '
            'across 3 market conditions.',
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurface.withOpacity(0.5),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: p.isStressLoading ? null : p.runStressTest,
              icon: p.isStressLoading
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.bolt_rounded),
              label: Text(p.isStressLoading ? 'Running Stress Test…' : 'Run Market Regime Test'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          if (p.stressResult != null) ...[
            const SizedBox(height: 20),
            ..._buildRegimeCards(p.stressResult!, p.startingBalance),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildRegimeCards(
      Map<String, dynamic> result, double startingBalance) {
    final regimes = ['normal_market', 'bear_market', 'crisis'];
    final regimeColors = [Colors.green, Colors.orange, Colors.red];
    final widgets = <Widget>[];

    for (int i = 0; i < regimes.length; i++) {
      final key = regimes[i];
      final regime = result[key] as Map<String, dynamic>?;
      if (regime == null) continue;

      final probProfit = (regime['prob_profit'] as num? ?? 0) * 100;
      final probRuin = (regime['prob_ruin'] as num? ?? 0) * 100;
      final medFinal = (regime['median_final'] as num? ?? 0).toDouble();
      final medDd = (regime['median_max_drawdown'] as num? ?? 0) * 100;
      final color = regimeColors[i];

      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _Card(
          scheme: scheme,
          accentColor: color,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 4, height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  regime['label'] as String? ?? key,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              _InfoRow('Median Final',
                  '\$${medFinal.toStringAsFixed(0)}',
                  color: medFinal >= startingBalance ? Colors.green : Colors.red,
                  scheme: scheme),
              _InfoRow('Prob Profit',
                  '${probProfit.toStringAsFixed(1)}%',
                  color: Colors.green, scheme: scheme),
              _InfoRow('Prob Ruin',
                  '${probRuin.toStringAsFixed(1)}%',
                  color: Colors.red, scheme: scheme),
              _InfoRow('Median Max DD',
                  '${medDd.toStringAsFixed(1)}%',
                  color: Colors.orange, scheme: scheme),
            ],
          ),
        ),
      ));
    }
    return widgets;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Shared primitives — all use ColorScheme, never hardcoded colours
// ═════════════════════════════════════════════════════════════════════════════

/// Section label matching Tajir's settings/portfolio style.
class _SectionLabel extends StatelessWidget {
  final String text;
  final ColorScheme scheme;
  const _SectionLabel(this.text, this.scheme);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
          color: scheme.onSurface.withOpacity(0.4),
        ),
      );
}

/// Card container — matches Tajir surfaceContainerHighest cards.
class _Card extends StatelessWidget {
  final Widget child;
  final ColorScheme scheme;
  final Color? accentColor;

  const _Card({required this.child, required this.scheme, this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: accentColor != null
            ? Border.all(color: accentColor!.withOpacity(0.25))
            : Border.all(color: scheme.outline.withOpacity(0.1)),
      ),
      child: child,
    );
  }
}

/// Slider row used across all tabs.
class _SliderInput extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;
  final ColorScheme scheme;

  const _SliderInput({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: scheme.onSurface)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(display,
                  style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          activeColor: scheme.primary,
          inactiveColor: scheme.primary.withOpacity(0.2),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Key/value info row used in result cards.
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final ColorScheme scheme;

  const _InfoRow(this.label, this.value,
      {this.color, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: scheme.onSurface.withOpacity(0.55))),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color ?? scheme.onSurface)),
        ],
      ),
    );
  }
}

/// Large result hero card (from File 3 design).
class _ResultCard extends StatelessWidget {
  final String label;
  final String value;
  final String subLabel;
  final String subValue;
  final Color color;
  final ColorScheme scheme;
  final String description;

  const _ResultCard({
    required this.label,
    required this.value,
    required this.subLabel,
    required this.subValue,
    required this.color,
    required this.scheme,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: color,
                      letterSpacing: -1)),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(subValue,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface)),
                  Text(subLabel,
                      style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurface.withOpacity(0.5))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(description,
              style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurface.withOpacity(0.65),
                  height: 1.5)),
        ],
      ),
    );
  }
}

/// Semi-circle gauge (from File 3).
class _GaugeChart extends StatelessWidget {
  final double value;
  final double max;
  final Color color;
  final ColorScheme scheme;
  final String label;

  const _GaugeChart({
    required this.value,
    required this.max,
    required this.color,
    required this.scheme,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      scheme: scheme,
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withOpacity(0.5))),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _GaugePainter(
                  value: value, max: max, color: color, scheme: scheme),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final double max;
  final Color color;
  final ColorScheme scheme;

  _GaugePainter({
    required this.value,
    required this.max,
    required this.color,
    required this.scheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 20;
    const startAngle = pi;
    const sweepAngle = pi;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepAngle, false,
      Paint()
        ..color = scheme.onSurface.withOpacity(0.1)
        ..strokeWidth = 16
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    final fraction = (value / max).clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepAngle * fraction, false,
      Paint()
        ..color = color
        ..strokeWidth = 16
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: '${value.toStringAsFixed(1)}%',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2,
          center.dy - textPainter.height - 12),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Simulated equity line chart (single curve, from File 3).
class _SimulatedEquityChart extends StatelessWidget {
  final List<double> values;
  final double accountSize;
  final ColorScheme scheme;

  const _SimulatedEquityChart({
    required this.values,
    required this.accountSize,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final isProfit = values.last > accountSize;

    return _Card(
      scheme: scheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Simulated Equity (30 trades)',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface.withOpacity(0.5))),
              Text(
                '${isProfit ? '+' : ''}\$${(values.last - accountSize).toStringAsFixed(0)}',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isProfit ? Colors.green : Colors.red,
                    fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: CustomPaint(
              painter: _LinePainter(
                values: values,
                baseline: accountSize,
                color: isProfit ? Colors.green : Colors.red,
              ),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('\$${minV.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontSize: 10, color: scheme.onSurface.withOpacity(0.4))),
              Text('\$${maxV.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontSize: 10, color: scheme.onSurface.withOpacity(0.4))),
            ],
          ),
        ],
      ),
    );
  }
}

/// Stress-test account bar chart (from File 3).
class _StressBarChart extends StatelessWidget {
  final double accountSize;
  final double stressLoss;
  final ColorScheme scheme;
  final Color color;

  const _StressBarChart({
    required this.accountSize,
    required this.stressLoss,
    required this.scheme,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = accountSize - stressLoss;
    return _Card(
      scheme: scheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Account After Stress Scenario',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withOpacity(0.5))),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 40,
              child: Stack(
                children: [
                  Container(color: color.withOpacity(0.2)),
                  FractionallySizedBox(
                    widthFactor: (remaining / accountSize).clamp(0, 1),
                    child: Container(color: Colors.green),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _LegendDot(
                  color: Colors.green,
                  label: 'Remaining: \$${remaining.toStringAsFixed(0)}',
                  scheme: scheme),
              const SizedBox(width: 16),
              _LegendDot(
                  color: color,
                  label: 'Lost: \$${stressLoss.toStringAsFixed(0)}',
                  scheme: scheme),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final ColorScheme scheme;

  const _LegendDot({
    required this.color,
    required this.label,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: scheme.onSurface.withOpacity(0.8))),
      ],
    );
  }
}

/// Single equity line painter (from File 3, used in drawdown tab).
class _LinePainter extends CustomPainter {
  final List<double> values;
  final double baseline;
  final Color color;

  const _LinePainter({
    required this.values,
    required this.baseline,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = maxV - minV == 0 ? 1.0 : maxV - minV;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y = size.height - ((values[i] - minV) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.3), color.withOpacity(0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

