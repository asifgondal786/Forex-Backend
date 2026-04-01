import 'dart:math';
import 'package:flutter/material.dart';

class RiskSimulatorScreen extends StatefulWidget {
  const RiskSimulatorScreen({super.key});

  @override
  State<RiskSimulatorScreen> createState() => _RiskSimulatorScreenState();
}

class _RiskSimulatorScreenState extends State<RiskSimulatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  // Kelly inputs
  double _winRate = 60;
  double _winLossRatio = 2.0;

  // Drawdown inputs
  double _riskPerTrade = 2.0;
  double _maxDrawdownTarget = 20.0;

  // Stress test inputs
  double _consecutiveLosses = 5;
  double _accountSize = 10000;

  // Computed results
  double get _kellyCriterion {
    final w = _winRate / 100;
    final r = _winLossRatio;
    return (w - (1 - w) / r) * 100;
  }

  double get _safKelly => _kellyCriterion / 2;

  double get _maxConsecutiveLosses {
    final riskDecimal = _riskPerTrade / 100;
    return (_maxDrawdownTarget / 100 / riskDecimal);
  }

  double get _stressLoss {
    double balance = _accountSize;
    for (int i = 0; i < _consecutiveLosses.toInt(); i++) {
      balance *= (1 - _riskPerTrade / 100);
    }
    return _accountSize - balance;
  }

  List<double> get _drawdownCurve {
    final points = <double>[];
    double balance = _accountSize;
    final rand = Random(42);
    for (int i = 0; i < 30; i++) {
      final isWin = rand.nextDouble() < _winRate / 100;
      if (isWin) {
        balance += balance * (_riskPerTrade / 100) * _winLossRatio;
      } else {
        balance -= balance * (_riskPerTrade / 100);
      }
      points.add(balance);
    }
    return points;
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
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
          tabs: const [
            Tab(text: 'Kelly'),
            Tab(text: 'Drawdown'),
            Tab(text: 'Stress Test'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _KellyTab(
            winRate: _winRate,
            winLossRatio: _winLossRatio,
            kellyCriterion: _kellyCriterion,
            safeKelly: _safKelly,
            onWinRateChanged: (v) => setState(() => _winRate = v),
            onWinLossRatioChanged: (v) => setState(() => _winLossRatio = v),
            scheme: scheme,
          ),
          _DrawdownTab(
            riskPerTrade: _riskPerTrade,
            maxDrawdownTarget: _maxDrawdownTarget,
            maxConsecutiveLosses: _maxConsecutiveLosses,
            equityCurve: _drawdownCurve,
            accountSize: _accountSize,
            onRiskChanged: (v) => setState(() => _riskPerTrade = v),
            onDrawdownChanged: (v) => setState(() => _maxDrawdownTarget = v),
            scheme: scheme,
          ),
          _StressTestTab(
            consecutiveLosses: _consecutiveLosses,
            riskPerTrade: _riskPerTrade,
            accountSize: _accountSize,
            stressLoss: _stressLoss,
            onLossesChanged: (v) => setState(() => _consecutiveLosses = v),
            onRiskChanged: (v) => setState(() => _riskPerTrade = v),
            onAccountChanged: (v) => setState(() => _accountSize = v),
            scheme: scheme,
          ),
        ],
      ),
    );
  }
}

class _KellyTab extends StatelessWidget {
  final double winRate;
  final double winLossRatio;
  final double kellyCriterion;
  final double safeKelly;
  final ValueChanged<double> onWinRateChanged;
  final ValueChanged<double> onWinLossRatioChanged;
  final ColorScheme scheme;

  const _KellyTab({
    required this.winRate,
    required this.winLossRatio,
    required this.kellyCriterion,
    required this.safeKelly,
    required this.onWinRateChanged,
    required this.onWinLossRatioChanged,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final kellyColor = kellyCriterion < 0
        ? Colors.red
        : kellyCriterion < 5
            ? Colors.orange
            : Colors.green;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _ResultCard(
            label: 'Kelly Criterion',
            value: '${kellyCriterion.toStringAsFixed(1)}%',
            subLabel: 'Safe Kelly (½)',
            subValue: '${safeKelly.toStringAsFixed(1)}%',
            color: kellyColor,
            scheme: scheme,
            description: kellyCriterion < 0
                ? 'Negative Kelly — this setup has a negative expected value. Do not trade.'
                : 'Risk ${safeKelly.toStringAsFixed(1)}% of your account per trade for optimal growth.',
          ),
          const SizedBox(height: 24),
          _GaugeChart(
            value: kellyCriterion.clamp(0, 30),
            max: 30,
            color: kellyColor,
            scheme: scheme,
            label: 'Optimal Risk %',
          ),
          const SizedBox(height: 24),
          _SliderInput(
            label: 'Win Rate',
            value: winRate,
            min: 1,
            max: 99,
            suffix: '%',
            onChanged: onWinRateChanged,
            scheme: scheme,
          ),
          const SizedBox(height: 16),
          _SliderInput(
            label: 'Win/Loss Ratio',
            value: winLossRatio,
            min: 0.1,
            max: 5,
            suffix: ':1',
            onChanged: onWinLossRatioChanged,
            scheme: scheme,
          ),
        ],
      ),
    );
  }
}

class _DrawdownTab extends StatelessWidget {
  final double riskPerTrade;
  final double maxDrawdownTarget;
  final double maxConsecutiveLosses;
  final List<double> equityCurve;
  final double accountSize;
  final ValueChanged<double> onRiskChanged;
  final ValueChanged<double> onDrawdownChanged;
  final ColorScheme scheme;

  const _DrawdownTab({
    required this.riskPerTrade,
    required this.maxDrawdownTarget,
    required this.maxConsecutiveLosses,
    required this.equityCurve,
    required this.accountSize,
    required this.onRiskChanged,
    required this.onDrawdownChanged,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _ResultCard(
            label: 'Max Consecutive Losses',
            value: maxConsecutiveLosses.toStringAsFixed(0),
            subLabel: 'Before hitting drawdown target',
            subValue: '${maxDrawdownTarget.toStringAsFixed(0)}%',
            color: maxConsecutiveLosses < 5 ? Colors.red : Colors.green,
            scheme: scheme,
            description:
                'At ${riskPerTrade.toStringAsFixed(1)}% risk/trade, you can absorb ${maxConsecutiveLosses.toStringAsFixed(0)} consecutive losses before hitting your ${maxDrawdownTarget.toStringAsFixed(0)}% drawdown limit.',
          ),
          const SizedBox(height: 24),
          _SimulatedEquityChart(
            values: equityCurve,
            accountSize: accountSize,
            scheme: scheme,
          ),
          const SizedBox(height: 24),
          _SliderInput(
            label: 'Risk Per Trade',
            value: riskPerTrade,
            min: 0.1,
            max: 20,
            suffix: '%',
            onChanged: onRiskChanged,
            scheme: scheme,
          ),
          const SizedBox(height: 16),
          _SliderInput(
            label: 'Max Drawdown Target',
            value: maxDrawdownTarget,
            min: 5,
            max: 80,
            suffix: '%',
            onChanged: onDrawdownChanged,
            scheme: scheme,
          ),
        ],
      ),
    );
  }
}

class _StressTestTab extends StatelessWidget {
  final double consecutiveLosses;
  final double riskPerTrade;
  final double accountSize;
  final double stressLoss;
  final ValueChanged<double> onLossesChanged;
  final ValueChanged<double> onRiskChanged;
  final ValueChanged<double> onAccountChanged;
  final ColorScheme scheme;

  const _StressTestTab({
    required this.consecutiveLosses,
    required this.riskPerTrade,
    required this.accountSize,
    required this.stressLoss,
    required this.onLossesChanged,
    required this.onRiskChanged,
    required this.onAccountChanged,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final lossPercent = (stressLoss / accountSize) * 100;
    final color = lossPercent > 30
        ? Colors.red
        : lossPercent > 15
            ? Colors.orange
            : Colors.green;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _ResultCard(
            label: 'Total Loss (Scenario)',
            value: '\$${stressLoss.toStringAsFixed(2)}',
            subLabel: 'Account drawdown',
            subValue: '${lossPercent.toStringAsFixed(1)}%',
            color: color,
            scheme: scheme,
            description:
                'After ${consecutiveLosses.toInt()} consecutive losses at ${riskPerTrade.toStringAsFixed(1)}% risk, your \$${accountSize.toStringAsFixed(0)} account would be down \$${stressLoss.toStringAsFixed(2)}.',
          ),
          const SizedBox(height: 24),
          _StressBarChart(
            accountSize: accountSize,
            stressLoss: stressLoss,
            scheme: scheme,
            color: color,
          ),
          const SizedBox(height: 24),
          _SliderInput(
            label: 'Consecutive Losses',
            value: consecutiveLosses,
            min: 1,
            max: 20,
            suffix: ' trades',
            onChanged: onLossesChanged,
            scheme: scheme,
          ),
          const SizedBox(height: 16),
          _SliderInput(
            label: 'Risk Per Trade',
            value: riskPerTrade,
            min: 0.1,
            max: 20,
            suffix: '%',
            onChanged: onRiskChanged,
            scheme: scheme,
          ),
          const SizedBox(height: 16),
          _SliderInput(
            label: 'Account Size',
            value: accountSize,
            min: 100,
            max: 100000,
            prefix: '\$',
            onChanged: onAccountChanged,
            scheme: scheme,
          ),
        ],
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

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
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: -1,
                ),
              ),
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
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface.withOpacity(0.65),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderInput extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String suffix;
  final String? prefix;
  final ValueChanged<double> onChanged;
  final ColorScheme scheme;

  const _SliderInput({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    this.prefix,
    required this.onChanged,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final display = prefix != null
        ? '$prefix${value.toStringAsFixed(value < 10 ? 1 : 0)}'
        : '${value.toStringAsFixed(value < 10 ? 1 : 0)}$suffix';
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: scheme.onSurface)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                display,
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
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

  _GaugePainter(
      {required this.value,
      required this.max,
      required this.color,
      required this.scheme});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 20;
    const startAngle = pi;
    const sweepAngle = pi;

    // Background arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = scheme.onSurface.withOpacity(0.1)
        ..strokeWidth = 16
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Value arc
    final fraction = (value / max).clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * fraction,
      false,
      Paint()
        ..color = color
        ..strokeWidth = 16
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Center text
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${value.toStringAsFixed(1)}%',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
        canvas,
        Offset(center.dx - textPainter.width / 2,
            center.dy - textPainter.height - 12));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

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
    final max = values.reduce((a, b) => a > b ? a : b);
    final min = values.reduce((a, b) => a < b ? a : b);
    final isProfit = values.last > accountSize;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Simulated Equity (30 trades)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withOpacity(0.5),
                ),
              ),
              Text(
                '${isProfit ? '+' : ''}\$${(values.last - accountSize).toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isProfit ? Colors.green : Colors.red,
                  fontSize: 13,
                ),
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
              Text('\$${min.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontSize: 10, color: scheme.onSurface.withOpacity(0.4))),
              Text('\$${max.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontSize: 10, color: scheme.onSurface.withOpacity(0.4))),
            ],
          ),
        ],
      ),
    );
  }
}

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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account After Stress Test',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withOpacity(0.5),
            ),
          ),
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
              _LegendDot(color: Colors.green, label: 'Remaining: \$${remaining.toStringAsFixed(0)}'),
              const SizedBox(width: 16),
              _LegendDot(color: color, label: 'Lost: \$${stressLoss.toStringAsFixed(0)}'),
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
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> values;
  final double baseline;
  final Color color;

  _LinePainter(
      {required this.values, required this.baseline, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = max - min == 0 ? 1.0 : max - min;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y = size.height - ((values[i] - min) / range) * size.height;
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
