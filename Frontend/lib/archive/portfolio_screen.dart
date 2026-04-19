import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/portfolio_provider.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // In real app, pass actual token from auth provider
      context.read<PortfolioProvider>().loadAll('demo_token');
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
      body: Consumer<PortfolioProvider>(
        builder: (context, prov, _) {
          if (prov.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: () => prov.loadAll('demo_token'),
            child: CustomScrollView(
              slivers: [
                _buildAppBar(scheme),
                SliverToBoxAdapter(child: _buildBalanceCard(prov, scheme)),
                SliverToBoxAdapter(child: _buildStatsRow(prov, scheme)),
                SliverToBoxAdapter(child: _buildEquityCurve(prov, scheme)),
                SliverToBoxAdapter(
                  child: TabBar(
                    controller: _tabs,
                    labelColor: scheme.primary,
                    unselectedLabelColor: scheme.onSurface.withOpacity(0.5),
                    indicatorColor: scheme.primary,
                    tabs: [
                      Tab(text: 'Open Trades (${prov.openTrades.length})'),
                      Tab(text: 'History (${prov.tradeHistory.length})'),
                    ],
                  ),
                ),
                SliverFillRemaining(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _OpenTradesList(trades: prov.openTrades, prov: prov),
                      _TradeHistoryList(trades: prov.tradeHistory),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  SliverAppBar _buildAppBar(ColorScheme scheme) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: scheme.surface,
      title: Text(
        'Portfolio',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: scheme.primary),
          onPressed: () =>
              context.read<PortfolioProvider>().loadAll('demo_token'),
        ),
      ],
    );
  }

  Widget _buildBalanceCard(PortfolioProvider prov, ColorScheme scheme) {
    final dailyPositive = prov.stats.dailyPnl >= 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Equity',
            style: TextStyle(
              color: scheme.onPrimary.withOpacity(0.8),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '\$${prov.stats.equity.toStringAsFixed(2)}',
            style: TextStyle(
              color: scheme.onPrimary,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                dailyPositive ? Icons.arrow_upward : Icons.arrow_downward,
                color: dailyPositive ? Colors.greenAccent : Colors.redAccent,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                '${dailyPositive ? '+' : ''}\$${prov.stats.dailyPnl.toStringAsFixed(2)} today',
                style: TextStyle(
                  color: dailyPositive ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(PortfolioProvider prov, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _StatChip(
            label: 'Win Rate',
            value: '${prov.stats.winRate.toStringAsFixed(1)}%',
            icon: Icons.emoji_events_rounded,
            positive: prov.stats.winRate >= 50,
            scheme: scheme,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Avg Win',
            value: '\$${prov.stats.avgWin.toStringAsFixed(2)}',
            icon: Icons.trending_up_rounded,
            positive: true,
            scheme: scheme,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Streak',
            value: '${prov.stats.winStreak}W',
            icon: Icons.bolt_rounded,
            positive: prov.stats.winStreak > 0,
            scheme: scheme,
          ),
        ],
      ),
    );
  }

  Widget _buildEquityCurve(PortfolioProvider prov, ColorScheme scheme) {
    if (prov.stats.equityCurve.length < 2) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Equity Curve',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: scheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: CustomPaint(
              painter: _MiniLinePainter(
                values: prov.stats.equityCurve,
                color: scheme.primary,
              ),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool positive;
  final ColorScheme scheme;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.positive,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final color = positive ? Colors.green : Colors.red;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: scheme.onSurface,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniLinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _MiniLinePainter({required this.values, required this.color});

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
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.3), color.withOpacity(0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

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

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _OpenTradesList extends StatelessWidget {
  final List<OpenTrade> trades;
  final PortfolioProvider prov;

  const _OpenTradesList({required this.trades, required this.prov});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (trades.isEmpty) {
      return _EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'No open trades',
        subtitle: 'Your active positions will appear here.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: trades.length,
      itemBuilder: (context, i) {
        final t = trades[i];
        final isProfit = t.pnl >= 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: t.direction == 'BUY'
                      ? Colors.green.withOpacity(0.15)
                      : Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  t.direction,
                  style: TextStyle(
                    color: t.direction == 'BUY' ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.pair,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    Text(
                      'Entry: ${t.entryPrice.toStringAsFixed(5)} • Lot: ${t.lotSize}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isProfit ? '+' : ''}\$${t.pnl.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: isProfit ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final ok = await prov.closeTrade(t.id, 'demo_token');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ok ? 'Trade closed' : 'Failed to close'),
                          backgroundColor: ok ? Colors.green : Colors.red,
                        ));
                      }
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TradeHistoryList extends StatelessWidget {
  final List<ClosedTrade> trades;

  const _TradeHistoryList({required this.trades});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (trades.isEmpty) {
      return _EmptyState(
        icon: Icons.history_rounded,
        title: 'No trade history',
        subtitle: 'Closed trades will appear here.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: trades.length,
      itemBuilder: (context, i) {
        final t = trades[i];
        final isProfit = t.realizedPnl >= 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${t.pair} ${t.direction}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${t.entryPrice.toStringAsFixed(5)} → ${t.exitPrice.toStringAsFixed(5)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${isProfit ? '+' : ''}\$${t.realizedPnl.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isProfit ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: scheme.onSurface.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurface.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

