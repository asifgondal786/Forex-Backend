import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/market_watch_provider.dart';
import '../../providers/trade_signals_provider.dart';
import '../../providers/news_events_provider.dart';
import '../../providers/paper_trading_provider.dart';
import '../../providers/app_shell_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MarketWatchProvider>().init();
      context.read<TradeSignalsProvider>().init();
      context.read<NewsEventsProvider>().init();
      context.read<PaperTradingProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(scheme, context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const _NewsMarquee(),
                const SizedBox(height: 16),
                const _LiveBalanceCard(),
                const SizedBox(height: 16),
                const _QuickActionsRow(),
                const SizedBox(height: 24),
                _SectionHeader('Market Snapshot', scheme,
                    onSeeAll: () => context.read<AppShellProvider>().setTab(1)),
                const SizedBox(height: 10),
                const _LiveMarketSnapshot(),
                const SizedBox(height: 24),
                _SectionHeader('Recent Signals', scheme,
                    onSeeAll: () => context.read<AppShellProvider>().setTab(2)),
                const SizedBox(height: 10),
                const _LiveRecentSignals(),
                const SizedBox(height: 24),
                _SectionHeader('AI Recommendation', scheme),
                const SizedBox(height: 10),
                const _LiveAiPreviewCard(),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(ColorScheme scheme, BuildContext context) {
    return SliverAppBar(
      floating: true,
      backgroundColor: scheme.surface,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.primaryContainer],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.currency_exchange, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text('Tajir',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: scheme.onSurface)),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: scheme.onSurface),
          onPressed: () => context.read<AppShellProvider>().setTab(4),
        ),
        IconButton(
          icon: Icon(Icons.person_outline_rounded, color: scheme.onSurface),
          onPressed: () => Navigator.pushNamed(context, '/profile'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// News Marquee Ticker — uses NewsEventsProvider.articles
// ─────────────────────────────────────────────────────────────────────────────

class _NewsMarquee extends StatefulWidget {
  const _NewsMarquee();

  @override
  State<_NewsMarquee> createState() => _NewsMarqueeState();
}

class _NewsMarqueeState extends State<_NewsMarquee> {
  final ScrollController _ctrl = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    _timer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (!_ctrl.hasClients) return;
      final max = _ctrl.position.maxScrollExtent;
      if (max <= 0) return;
      if (_ctrl.offset >= max) {
        _ctrl.jumpTo(0);
      } else {
        _ctrl.jumpTo(_ctrl.offset + 1.5);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final news = context.watch<NewsEventsProvider>();

    final List<String> items = news.articles.isNotEmpty
        ? news.articles
            .take(10)
            .map((a) => '${a.source} • ${a.headline}')
            .toList()
        : [
            'EUR/USD • Bullish momentum on H4 continues',
            'GBP/USD • BoE policy meeting in focus this week',
            'USD/JPY • BOJ intervention risk elevated near 155',
            'XAU/USD • Safe haven demand rising amid uncertainty',
            'NFP data due Friday — expect high volatility',
          ];

    // Double the list for seamless looping
    final text = '${items.join('     ◆     ')}     ◆     ${items.join('     ◆     ')}';

    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                bottomLeft: Radius.circular(7),
              ),
            ),
            child: const Center(
              child: Text('LIVE',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
            ),
          ),
          Expanded(
            child: ListView(
              controller: _ctrl,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: Text(text,
                        style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Balance Card — PaperTradingProvider.stats + openTrades
// ─────────────────────────────────────────────────────────────────────────────

class _LiveBalanceCard extends StatelessWidget {
  const _LiveBalanceCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final paper = context.watch<PaperTradingProvider>();
    final stats = paper.stats;

    // Equity = starting 10k + total realized P&L
    final equity = 10000.0 + stats.totalPnl;
    final isPos = stats.totalPnl >= 0;
    final pnlPct = stats.totalPnl / 10000 * 100;
    final openPnl = paper.totalUnrealizedPnl;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primary.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Account Balance',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(children: [
                  Icon(Icons.circle, size: 6, color: Colors.greenAccent),
                  SizedBox(width: 5),
                  Text('Paper Trading',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('\$${equity.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1)),
          const SizedBox(height: 6),
          Row(children: [
            Icon(
              isPos ? Icons.arrow_upward : Icons.arrow_downward,
              color: isPos ? Colors.greenAccent : Colors.redAccent,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              '${isPos ? '+' : ''}\$${stats.totalPnl.toStringAsFixed(2)} (${pnlPct.toStringAsFixed(2)}%)',
              style: TextStyle(
                  color: isPos ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            _Stat('Open P&L',
                '${openPnl >= 0 ? '+' : ''}\$${openPnl.toStringAsFixed(2)}',
                openPnl >= 0 ? Colors.greenAccent : Colors.redAccent),
            const SizedBox(width: 20),
            _Stat('Win Rate',
                '${(stats.winRate * 100).toStringAsFixed(1)}%', Colors.white),
            const SizedBox(width: 20),
            _Stat('Trades', '${stats.totalTrades}', Colors.white),
          ]),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Actions — all wired to real navigation
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    final shell = context.read<AppShellProvider>();
    final actions = [
      (Icons.trending_up_rounded, 'Trade', Colors.green,
          () => shell.setTab(2)),
      (Icons.auto_awesome_rounded, 'Ask AI', Colors.purple,
          () => Navigator.pushNamed(context, '/ai-chat')),
      (Icons.bar_chart_rounded, 'Charts', Colors.blue,
          () => Navigator.pushNamed(context, '/charts')),
      (Icons.account_balance_wallet_rounded, 'Portfolio', Colors.orange,
          () => shell.setTab(3)),
    ];

    return Row(
      children: List.generate(actions.length, (i) {
        final (icon, label, color, onTap) = actions[i];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < actions.length - 1 ? 8 : 0),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Column(children: [
                    Icon(icon, color: color, size: 22),
                    const SizedBox(height: 6),
                    Text(label,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color)),
                  ]),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Market Snapshot — MarketWatchProvider.quotes (PairQuote.symbol/.mid/.changePercent)
// ─────────────────────────────────────────────────────────────────────────────

class _LiveMarketSnapshot extends StatelessWidget {
  const _LiveMarketSnapshot();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mw = context.watch<MarketWatchProvider>();

    if (mw.isLoading && mw.quotes.isEmpty) {
      return SizedBox(
        height: 72,
        child: Center(
            child: CircularProgressIndicator(
                strokeWidth: 2, color: scheme.primary)),
      );
    }

    // quotes getter already applies filters — read all by using quoteFor or
    // just take from the underlying list via the public getter (no filter set)
    final top = mw.quotes.take(3).toList();

    if (top.isEmpty) {
      return _fallback(scheme);
    }

    return Row(
      children: List.generate(top.length, (i) {
        final q = top[i];
        final isPos = q.changePercent >= 0;
        final color = isPos ? Colors.green : Colors.red;
        final digits = q.symbol.contains('JPY') ? 3 : 5;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < top.length - 1 ? 8 : 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(q.symbol,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface.withValues(alpha: 0.6))),
                  const SizedBox(height: 4),
                  Text(q.mid.toStringAsFixed(digits),
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: scheme.onSurface)),
                  const SizedBox(height: 2),
                  Text(
                    '${isPos ? '+' : ''}${q.changePercent.toStringAsFixed(2)}%',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _fallback(ColorScheme scheme) {
    final items = [
      ('EUR/USD', '1.08432', '+0.12%', true),
      ('GBP/JPY', '191.234', '-0.34%', false),
      ('XAU/USD', '2341.5', '+0.87%', true),
    ];
    return Row(
      children: List.generate(items.length, (i) {
        final (pair, price, change, isPos) = items[i];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < items.length - 1 ? 8 : 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pair,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface.withValues(alpha: 0.6))),
                  const SizedBox(height: 4),
                  Text(price,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: scheme.onSurface)),
                  const SizedBox(height: 2),
                  Text(change,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isPos ? Colors.green : Colors.red)),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Recent Signals — TradeSignalsProvider.signals (List<TradeSignal>)
// ─────────────────────────────────────────────────────────────────────────────

class _LiveRecentSignals extends StatelessWidget {
  const _LiveRecentSignals();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<TradeSignalsProvider>();

    if (provider.isLoading && !provider.hasSignals) {
      return SizedBox(
        height: 80,
        child: Center(
            child: CircularProgressIndicator(
                strokeWidth: 2, color: scheme.primary)),
      );
    }

    final signals = provider.signals.take(3).toList();

    if (signals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text('No signals yet — refreshing...',
              style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.4),
                  fontSize: 13)),
        ),
      );
    }

    return Column(
      children: signals.map((s) {
        final label = switch (s.type) {
          SignalType.buy  => 'BUY',
          SignalType.sell => 'SELL',
          SignalType.hold => 'HOLD',
        };
        final color = switch (s.type) {
          SignalType.buy  => Colors.green,
          SignalType.sell => Colors.red,
          SignalType.hold => Colors.orange,
        };

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(label,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 12)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.symbol,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(
                    s.explanation,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${s.confidence}%',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              ),
            ),
          ]),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live AI Preview — highest-confidence TradeSignal
// ─────────────────────────────────────────────────────────────────────────────

class _LiveAiPreviewCard extends StatelessWidget {
  const _LiveAiPreviewCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<TradeSignalsProvider>();

    TradeSignal? top;
    if (provider.hasSignals) {
      top = provider.signals
          .reduce((a, b) => a.confidence >= b.confidence ? a : b);
    }

    final pair = top?.symbol ?? 'EUR/USD';
    final label = top == null
        ? 'BUY'
        : switch (top.type) {
            SignalType.buy  => 'BUY',
            SignalType.sell => 'SELL',
            SignalType.hold => 'HOLD',
          };
    final reason = top?.explanation ??
        'EUR/USD shows a high-probability bullish continuation. '
            'London session breakout above 1.0850 is the key level to watch.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.purple.withValues(alpha: 0.1),
          Colors.blue.withValues(alpha: 0.1),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.purple, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('AI Copilot',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Colors.purple)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('$pair • $label',
                        style: const TextStyle(
                            fontSize: 10,
                            color: Colors.purple,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(reason,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurface.withValues(alpha: 0.8),
                        height: 1.5)),
                const SizedBox(height: 10),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/ai-chat'),
                    child: const Text('Get full analysis →',
                        style: TextStyle(
                            color: Colors.purple,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final ColorScheme scheme;
  final VoidCallback? onSeeAll;

  const _SectionHeader(this.title, this.scheme, {this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: scheme.onSurface)),
        if (onSeeAll != null)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onSeeAll,
              child: Text('See all',
                  style: TextStyle(
                      fontSize: 13,
                      color: scheme.primary,
                      fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }
}