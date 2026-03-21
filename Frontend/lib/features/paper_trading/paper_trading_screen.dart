import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/paper_trading_provider.dart';

const _kBg      = Color(0xFF0A0E1A);
const _kCard    = Color(0xFF161D2E);
const _kBorder  = Color(0xFF1E2A3D);
const _kGold    = Color(0xFFD4A853);
const _kGreen   = Color(0xFF00C896);
const _kGreenDim= Color(0xFF003D2E);
const _kRed     = Color(0xFFFF4560);
const _kRedDim  = Color(0xFF3D0010);
const _kBlue    = Color(0xFF3B82F6);
const _kText    = Color(0xFFE2E8F0);
const _kSubtext = Color(0xFF64748B);
const _kDivider = Color(0xFF1E2A3D);

class PaperTradingScreen extends StatefulWidget {
  const PaperTradingScreen({super.key});
  @override
  State<PaperTradingScreen> createState() => _PaperTradingScreenState();
}

class _PaperTradingScreenState extends State<PaperTradingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fade;
  String _tab = 'Open';

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaperTradingProvider>().init();
    });
  }

  @override
  void dispose() { _fade.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Consumer<PaperTradingProvider>(
      builder: (ctx, provider, _) {
        if (provider.successMessage != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(provider.successMessage!),
              backgroundColor: _kGreen,
              duration: const Duration(seconds: 3),
            ));
            provider.clearMessages();
          });
        }
        if (provider.error != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(provider.error!),
              backgroundColor: _kRed,
              duration: const Duration(seconds: 3),
            ));
            provider.clearMessages();
          });
        }
        return Scaffold(
          backgroundColor: _kBg,
          body: FadeTransition(
            opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
            child: SafeArea(
              child: Column(children: [
                _AppBar(provider: provider),
                _StatsBar(provider: provider),
                _TabRow(tab: _tab, onTab: (t) => setState(() => _tab = t)),
                Expanded(
                  child: provider.isLoading
                      ? const Center(child: CircularProgressIndicator(color: _kGold))
                      : _tab == 'Open'
                          ? _OpenTradesTab(provider: provider)
                          : _HistoryTab(provider: provider),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar({required this.provider});
  final PaperTradingProvider provider;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _kDivider))),
    child: Row(children: [
      Container(width: 8, height: 8, decoration: const BoxDecoration(color: _kGreen, shape: BoxShape.circle)),
      const SizedBox(width: 10),
      const Text('Paper Trading', style: TextStyle(color: _kText, fontSize: 18, fontWeight: FontWeight.w700)),
      const Spacer(),
      IconButton(icon: const Icon(Icons.refresh_rounded, color: _kSubtext, size: 20), onPressed: provider.refresh),
    ]),
  );
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.provider});
  final PaperTradingProvider provider;
  @override
  Widget build(BuildContext context) {
    final s = provider.stats;
    final pnlColor = s.totalPnl >= 0 ? _kGreen : _kRed;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: _kBorder)),
      child: Row(children: [
        _StatCell('TOTAL P&L', '\$${s.totalPnl.toStringAsFixed(2)}', pnlColor),
        _vDiv(),
        _StatCell('WIN RATE', '${(s.winRate * 100).toStringAsFixed(0)}%', _kGold),
        _vDiv(),
        _StatCell('TRADES', '${s.totalTrades}', _kBlue),
        _vDiv(),
        _StatCell('OPEN', '${provider.openTrades.length}', _kGreen),
      ]),
    );
  }
  Widget _vDiv() => Container(width: 1, height: 28, color: _kDivider, margin: const EdgeInsets.symmetric(horizontal: 8));
}

class _StatCell extends StatelessWidget {
  const _StatCell(this.label, this.value, this.color);
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: _kSubtext, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
    ]),
  );
}

class _TabRow extends StatelessWidget {
  const _TabRow({required this.tab, required this.onTab});
  final String tab;
  final ValueChanged<String> onTab;
  @override
  Widget build(BuildContext context) => Container(
    color: _kBg,
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
    child: Row(
      children: ['Open', 'History'].map((t) {
        final active = tab == t;
        return Expanded(
          child: GestureDetector(
            onTap: () => onTab(t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: t == 'Open' ? 6 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: active ? _kGreen.withOpacity(0.12) : _kCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: active ? _kGreen.withOpacity(0.4) : _kBorder),
              ),
              child: Text(t, textAlign: TextAlign.center,
                  style: TextStyle(color: active ? _kGreen : _kSubtext, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

class _OpenTradesTab extends StatelessWidget {
  const _OpenTradesTab({required this.provider});
  final PaperTradingProvider provider;
  @override
  Widget build(BuildContext context) {
    if (provider.openTrades.isEmpty) {
      return const _EmptyState(icon: Icons.show_chart_rounded, message: 'No open trades', sub: 'Open a trade from the Signals screen');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: provider.openTrades.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _OpenTradeCard(trade: provider.openTrades[i], provider: provider),
      ),
    );
  }
}

class _OpenTradeCard extends StatelessWidget {
  const _OpenTradeCard({required this.trade, required this.provider});
  final PaperTrade trade;
  final PaperTradingProvider provider;
  @override
  Widget build(BuildContext context) {
    final isBuy = trade.direction == TradeDirection.buy;
    final dirColor = isBuy ? _kGreen : _kRed;
    final dirDim   = isBuy ? _kGreenDim : _kRedDim;
    final pnlColor = trade.unrealizedPnl >= 0 ? _kGreen : _kRed;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: _kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: dirDim, borderRadius: BorderRadius.circular(7)),
            child: Text(isBuy ? 'BUY' : 'SELL', style: TextStyle(color: dirColor, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Text(trade.pair.replaceAll('_', '/'), style: const TextStyle(color: _kText, fontSize: 16, fontWeight: FontWeight.w800)),
          const Spacer(),
          Text('\$${trade.unrealizedPnl.toStringAsFixed(2)}', style: TextStyle(color: pnlColor, fontSize: 15, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _PCell('ENTRY', trade.entryPrice.toStringAsFixed(5), _kText),
          _PCell('SL', trade.stopLoss.toStringAsFixed(5), _kRed),
          _PCell('TP', trade.takeProfit.toStringAsFixed(5), _kGreen),
          _PCell('R:R', '1:${trade.riskReward.toStringAsFixed(1)}', _kGold),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showCloseDialog(context),
            icon: const Icon(Icons.close_rounded, size: 14),
            label: const Text('Close Trade'),
            style: OutlinedButton.styleFrom(foregroundColor: _kRed, side: BorderSide(color: _kRed.withOpacity(0.4)), padding: const EdgeInsets.symmetric(vertical: 8)),
          ),
        ),
      ]),
    );
  }

  void _showCloseDialog(BuildContext context) {
    final controller = TextEditingController(text: trade.entryPrice.toStringAsFixed(5));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kCard,
        title: const Text('Close Trade', style: TextStyle(color: _kText)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Enter close price:', style: TextStyle(color: _kSubtext)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: _kText),
            decoration: InputDecoration(filled: true, fillColor: _kBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: _kSubtext))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kRed),
            onPressed: () async {
              final price = double.tryParse(controller.text);
              if (price == null) return;
              Navigator.pop(context);
              await context.read<PaperTradingProvider>().closeTrade(trade, price);
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _PCell extends StatelessWidget {
  const _PCell(this.label, this.value, this.color);
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text(label, style: const TextStyle(color: _kSubtext, fontSize: 8, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      const SizedBox(height: 3),
      Text(value, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.provider});
  final PaperTradingProvider provider;
  @override
  Widget build(BuildContext context) {
    if (provider.history.isEmpty) {
      return const _EmptyState(icon: Icons.history_rounded, message: 'No trade history', sub: 'Closed trades will appear here');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: provider.history.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _HistoryCard(trade: provider.history[i]),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.trade});
  final PaperTrade trade;
  @override
  Widget build(BuildContext context) {
    final isBuy = trade.direction == TradeDirection.buy;
    final pnl   = trade.realizedPnl ?? 0;
    final pnlPos = pnl >= 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: _kBorder)),
      child: Row(children: [
        Container(width: 3, height: 40, decoration: BoxDecoration(color: pnlPos ? _kGreen : _kRed, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(trade.pair.replaceAll('_', '/'), style: const TextStyle(color: _kText, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              Text(isBuy ? 'BUY' : 'SELL', style: TextStyle(color: isBuy ? _kGreen : _kRed, fontSize: 10, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 3),
            Text('Entry: ${trade.entryPrice.toStringAsFixed(5)}', style: const TextStyle(color: _kSubtext, fontSize: 10)),
          ]),
        ),
        Text('${pnlPos ? '+' : ''}\$${pnl.toStringAsFixed(2)}',
            style: TextStyle(color: pnlPos ? _kGreen : _kRed, fontSize: 15, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message, required this.sub});
  final IconData icon;
  final String message, sub;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: _kSubtext, size: 44),
      const SizedBox(height: 12),
      Text(message, style: const TextStyle(color: _kText, fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(sub, style: const TextStyle(color: _kSubtext, fontSize: 12)),
    ]),
  );
}