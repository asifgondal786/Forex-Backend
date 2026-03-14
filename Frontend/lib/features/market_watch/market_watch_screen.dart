// lib/features/market_watch/market_watch_screen.dart
import '../../core/widgets/quick_actions_overlay.dart';
import '../../providers/mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/market_watch_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Theme constants (same palette as rest of app)
// ─────────────────────────────────────────────────────────────────────────────
const _kBg       = Color(0xFF0A0E1A);
// const _kSurface  = Color(0xFF111827);
const _kCard     = Color(0xFF161D2E);
const _kBorder   = Color(0xFF1E2A3D);
const _kGold     = Color(0xFFD4A853);
const _kGreen    = Color(0xFF00C896);
const _kGreenDim = Color(0xFF003D2E);
const _kRed      = Color(0xFFFF4560);
const _kRedDim   = Color(0xFF3D0010);
const _kBlue     = Color(0xFF3B82F6);
const _kText     = Color(0xFFE2E8F0);
const _kSubtext  = Color(0xFF64748B);
const _kDivider  = Color(0xFF1E2A3D);

class MarketWatchScreen extends StatefulWidget {
  const MarketWatchScreen({super.key});
  @override
  State<MarketWatchScreen> createState() => _MarketWatchScreenState();
}

class _MarketWatchScreenState extends State<MarketWatchScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MarketWatchProvider>().init();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketWatchProvider>(
      builder: (ctx, provider, _) => Scaffold(
        backgroundColor: _kBg,
        body: FadeTransition(
          opacity: CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
          child: CustomScrollView(
            slivers: [
              _AppBar(provider: provider),
              SliverToBoxAdapter(child: _StatsBar(provider: provider)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _SearchBar(
                    controller: _searchCtrl,
                    onChanged: provider.setSearch,
                  ),
                ),
              ),

              // STEP 2: Inside build(), in the SliverList, add as FIRST item before
//         the _StatsBar SliverToBoxAdapter:
SliverToBoxAdapter(
  child: QuickActionsOverlay(
    modeKey: 'marketWatch',
    accentColor: const Color(0xFF00C896),  // green
    title: 'QUICK ACTIONS',
    onAction: (action) {
      switch (action.routeOrAction) {
        case 'filter_favourites':
          provider.setFilter('Favourites');
          break;
        case 'filter_movers':
          provider.setFilter('Bullish');
          break;
        case 'switch_signals':
          context.read<ModeProvider>().setMode(AppMode.tradeSignals);
          Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (_) => false);
          break;
        default:
          if (action.isRoute) Navigator.pushNamed(context, action.routeOrAction);
      }
    },
  ),
),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: _FilterRow(provider: provider),
                ),
              ),
              if (provider.isLoading)
                const SliverFillRemaining(
                    child: Center(
                        child: CircularProgressIndicator(color: _kGold)))
              else if (provider.quotes.isEmpty)
                const SliverFillRemaining(child: _EmptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PairCard(
                          quote: provider.quotes[i],
                          onFavTap: () => provider
                              .toggleFavourite(provider.quotes[i].symbol),
                        ),
                      ),
                      childCount: provider.quotes.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App bar
// ─────────────────────────────────────────────────────────────────────────────
class _AppBar extends StatelessWidget {
  const _AppBar({required this.provider});
  final MarketWatchProvider provider;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: _kBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(children: [
        Container(width: 8, height: 8,
            decoration: const BoxDecoration(color: _kGreen, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        const Text('Market Watch',
            style: TextStyle(color: _kText, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        // Live pulse dot
        _LiveDot(),
      ]),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Text('LIVE',
              style: TextStyle(color: _kGreen.withValues(alpha: 0.7),
                  fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _kDivider),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats bar
// ─────────────────────────────────────────────────────────────────────────────
class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.provider});
  final MarketWatchProvider provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        _StatCell(
            label: 'Pairs',
            value: '${provider.quotes.length}',
            color: _kGold),
        _divider(),
        _StatCell(
            label: 'Bullish',
            value: '${provider.bullishCount}',
            color: _kGreen),
        _divider(),
        _StatCell(
            label: 'Bearish',
            value: '${provider.bearishCount}',
            color: _kRed),
        _divider(),
        _StatCell(label: 'Updated', value: 'Live', color: _kBlue),
      ]),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 28, color: _kDivider, margin: const EdgeInsets.symmetric(horizontal: 8));
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: _kSubtext, fontSize: 10)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Search
// ─────────────────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: _kText, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search pairs…',
          hintStyle: const TextStyle(color: _kSubtext, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: _kSubtext, size: 18),
          filled: true,
          fillColor: _kCard,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _kGold.withValues(alpha: 0.5))),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter row
// ─────────────────────────────────────────────────────────────────────────────
class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.provider});
  final MarketWatchProvider provider;

  @override
  Widget build(BuildContext context) {
    const tabs = ['All', 'Favourites', 'Bullish', 'Bearish'];
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final active = provider.filter == tabs[i];
          final color = tabs[i] == 'Bullish' ? _kGreen
              : tabs[i] == 'Bearish' ? _kRed
              : tabs[i] == 'Favourites' ? _kGold
              : _kBlue;
          return GestureDetector(
            onTap: () => provider.setFilter(tabs[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: active ? color.withValues(alpha: 0.15) : _kCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: active ? color.withValues(alpha: 0.5) : _kBorder),
              ),
              child: Text(tabs[i],
                  style: TextStyle(
                      color: active ? color : _kSubtext,
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pair card
// ─────────────────────────────────────────────────────────────────────────────
class _PairCard extends StatelessWidget {
  const _PairCard({required this.quote, required this.onFavTap});
  final PairQuote quote;
  final VoidCallback onFavTap;

  @override
  Widget build(BuildContext context) {
    final up = quote.isBullish;
    final color = up ? _kGreen : _kRed;
    final dimColor = up ? _kGreenDim : _kRedDim;
    final priceStr = _formatPrice(quote.mid, quote.symbol);
    final changeStr =
        '${up ? '+' : ''}${quote.changePercent.toStringAsFixed(2)}%';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        // ── Flag badges ─────────────────────────────────────────────
        _FlagPair(base: quote.base, quote: quote.quote),
        const SizedBox(width: 12),
        // ── Symbol + spread ─────────────────────────────────────────
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(quote.symbol,
                style: const TextStyle(
                    color: _kText, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Row(children: [
              Text('Spread: ',
                  style: const TextStyle(color: _kSubtext, fontSize: 10)),
              Text(_formatSpread(quote.spread, quote.symbol),
                  style: const TextStyle(
                      color: _kSubtext, fontSize: 10, fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
        // ── Price + change ──────────────────────────────────────────
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(priceStr,
              style: const TextStyle(
                  color: _kText, fontSize: 16, fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: dimColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: color, size: 10),
              const SizedBox(width: 3),
              Text(changeStr,
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
        const SizedBox(width: 8),
        // ── H/L + favourite ─────────────────────────────────────────
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _HLRow(label: 'H', value: _formatPrice(quote.high24h, quote.symbol), color: _kGreen),
          const SizedBox(height: 4),
          _HLRow(label: 'L', value: _formatPrice(quote.low24h, quote.symbol), color: _kRed),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onFavTap,
            child: Icon(
              quote.isFavourite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: quote.isFavourite ? _kGold : _kSubtext,
              size: 18,
            ),
          ),
        ]),
      ]),
    );
  }

  String _formatPrice(double price, String symbol) {
    if (symbol.contains('JPY')) return price.toStringAsFixed(3);
    return price.toStringAsFixed(5);
  }

  String _formatSpread(double spread, String symbol) {
    if (symbol.contains('JPY')) return (spread * 100).toStringAsFixed(1) + ' p';
    return (spread * 10000).toStringAsFixed(1) + ' p';
  }
}

class _HLRow extends StatelessWidget {
  const _HLRow({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
          const SizedBox(width: 3),
          Text(value, style: const TextStyle(color: _kSubtext, fontSize: 9)),
        ],
      );
}

class _FlagPair extends StatelessWidget {
  const _FlagPair({required this.base, required this.quote});
  final String base, quote;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 38,
        height: 38,
        child: Stack(children: [
          Positioned(
            top: 0, left: 0,
            child: _CurrencyBadge(code: base, size: 26),
          ),
          Positioned(
            bottom: 0, right: 0,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: _kCard, width: 1.5),
                shape: BoxShape.circle,
              ),
              child: _CurrencyBadge(code: quote, size: 22),
            ),
          ),
        ]),
      );
}

class _CurrencyBadge extends StatelessWidget {
  const _CurrencyBadge({required this.code, required this.size});
  final String code;
  final double size;

  static const _colors = {
    'EUR': Color(0xFF0052A5), 'GBP': Color(0xFF012169),
    'USD': Color(0xFF3C3B6E), 'JPY': Color(0xFFBC002D),
    'AUD': Color(0xFF003087), 'CAD': Color(0xFFD52B1E),
    'CHF': Color(0xFFFF0000), 'NZD': Color(0xFF00247D),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: _colors[code] ?? _kSubtext,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(code.substring(0, 1),
            style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.38,
                fontWeight: FontWeight.w800)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Misc
// ─────────────────────────────────────────────────────────────────────────────
class _LiveDot extends StatefulWidget {
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _ctrl,
        child: Container(
          width: 7, height: 7,
          decoration: const BoxDecoration(
              color: _kGreen, shape: BoxShape.circle),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off_rounded, color: _kSubtext, size: 40),
          const SizedBox(height: 12),
          const Text('No pairs match your filter',
              style: TextStyle(color: _kSubtext, fontSize: 14)),
        ]),
      );
}
