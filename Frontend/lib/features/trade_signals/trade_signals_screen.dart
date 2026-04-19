// lib/features/trade_signals/trade_signals_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/trade_signals_provider.dart';

// â”€â”€ colours â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const _kBg       = Color(0xFF0A0E1A);
const _kSurface  = Color(0xFF111827);
const _kCard     = Color(0xFF161D2E);
const _kBorder   = Color(0xFF1E2A3D);
const _kGold     = Color(0xFFD4A853);
const _kGreen    = Color(0xFF00C896);
const _kGreenDim = Color(0xFF003D2E);
const _kRed      = Color(0xFFFF4560);
const _kRedDim   = Color(0xFF3D0010);
const _kAmber    = Color(0xFFF59E0B);
const _kAmberDim = Color(0xFF3D2600);
const _kBlue     = Color(0xFF3B82F6);
const _kBlueDim  = Color(0xFF0D1F4A);
const _kText     = Color(0xFFE2E8F0);
const _kSubtext  = Color(0xFF64748B);
const _kDivider  = Color(0xFF1E2A3D);

class TradeSignalsScreen extends StatefulWidget {
  const TradeSignalsScreen({super.key});
  @override
  State<TradeSignalsScreen> createState() => _TradeSignalsScreenState();
}

class _TradeSignalsScreenState extends State<TradeSignalsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TradeSignalsProvider>().init();
    });
  }

  @override
  void dispose() { _fadeCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Consumer<TradeSignalsProvider>(
      builder: (ctx, provider, _) => Scaffold(
        backgroundColor: _kBg,
        body: FadeTransition(
          opacity: CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
          child: CustomScrollView(
            slivers: [
              _buildAppBar(ctx, provider),
              SliverToBoxAdapter(child: _SignalSummaryBar(provider: provider)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: _FilterRow(provider: provider),
                ),
              ),
              if (provider.isLoading)
                const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator(color: _kGold)))
              else if (provider.error != null)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_rounded, color: _kRed, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Unable to load signals',
                            style: TextStyle(
                              color: _kText,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            provider.error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: _kSubtext, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: provider.refresh,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _kGold,
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (provider.signals.isEmpty)
                const SliverFillRemaining(child: _EmptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SignalCard(
                          signal: provider.signals[i],
                          expanded: provider.isExpanded(provider.signals[i].id),
                          onTap: () => provider.toggleExpanded(provider.signals[i].id),
                        ),
                      ),
                      childCount: provider.signals.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext ctx, TradeSignalsProvider provider) =>
      SliverAppBar(
        pinned: true,
        backgroundColor: _kBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(children: [
          Container(width: 8, height: 8,
              decoration: const BoxDecoration(color: _kGold, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          const Text('Trade Signals',
              style: TextStyle(color: _kText, fontSize: 18, fontWeight: FontWeight.w700)),
        ]),

        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _kSubtext, size: 20),
            onPressed: provider.refresh,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kDivider),
        ),
      );
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Summary bar
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _SignalSummaryBar extends StatelessWidget {
  const _SignalSummaryBar({required this.provider});
  final TradeSignalsProvider provider;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: Row(children: [
          _StatCell('BUY',  '${provider.buyCount}',  _kGreen),
          _vDivider(),
          _StatCell('SELL', '${provider.sellCount}', _kRed),
          _vDivider(),
          _StatCell('HOLD', '${provider.holdCount}', _kAmber),
          _vDivider(),
          _StatCell('TOTAL', '${provider.signals.length}', _kBlue),
        ]),
      );

  Widget _vDivider() => Container(
      width: 1, height: 28, color: _kDivider,
      margin: const EdgeInsets.symmetric(horizontal: 8));
}

class _StatCell extends StatelessWidget {
  const _StatCell(this.label, this.value, this.color);
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
              style: const TextStyle(
                  color: _kSubtext, fontSize: 9, fontWeight: FontWeight.w600,
                  letterSpacing: 0.8)),
        ]),
      );
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Filter row
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.provider});
  final TradeSignalsProvider provider;

  @override
  Widget build(BuildContext context) {
    final tabs = {
      'All': _kBlue, 'Buy': _kGreen, 'Sell': _kRed,
      'Hold': _kAmber, 'Active': _kGold, 'Triggered': _kSubtext,
    };
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: tabs.entries.map((e) {
          final active = provider.filter == e.key;
          return GestureDetector(
            onTap: () => provider.setFilter(e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: active ? e.value.withValues(alpha: 0.15) : _kCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: active ? e.value.withValues(alpha: 0.5) : _kBorder),
              ),
              child: Text(e.key,
                  style: TextStyle(
                      color: active ? e.value : _kSubtext,
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Signal Card â€” all 4 fields + expandable explanation
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _SignalCard extends StatelessWidget {
  const _SignalCard({
    required this.signal,
    required this.expanded,
    required this.onTap,
  });
  final TradeSignal signal;
  final bool expanded;
  final VoidCallback onTap;

  // type helpers
  Color get _typeColor => switch (signal.type) {
        SignalType.buy  => _kGreen,
        SignalType.sell => _kRed,
        SignalType.hold => _kAmber,
      };
  Color get _typeDim => switch (signal.type) {
        SignalType.buy  => _kGreenDim,
        SignalType.sell => _kRedDim,
        SignalType.hold => _kAmberDim,
      };
  String get _typeLabel => switch (signal.type) {
        SignalType.buy  => 'BUY',
        SignalType.sell => 'SELL',
        SignalType.hold => 'HOLD',
      };
  IconData get _typeIcon => switch (signal.type) {
        SignalType.buy  => Icons.trending_up_rounded,
        SignalType.sell => Icons.trending_down_rounded,
        SignalType.hold => Icons.pause_circle_outline_rounded,
      };

  Color get _statusColor => signal.status == SignalStatus.triggered
      ? _kBlue
      : signal.status == SignalStatus.expired
          ? _kSubtext
          : _kGreen;
  String get _statusLabel => switch (signal.status) {
        SignalStatus.active    => 'ACTIVE',
        SignalStatus.triggered => 'TRIGGERED',
        SignalStatus.expired   => 'EXPIRED',
      };

  String _timeAgo() {
    final diff = DateTime.now().difference(signal.generatedAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: expanded
                ? _typeColor.withValues(alpha: 0.35)
                : _kBorder,
            width: expanded ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // â”€â”€ Row 1: header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Row(children: [
                // Signal type badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _typeDim,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_typeIcon, color: _typeColor, size: 14),
                    const SizedBox(width: 5),
                    Text(_typeLabel,
                        style: TextStyle(
                            color: _typeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8)),
                  ]),
                ),
                const SizedBox(width: 10),
                // Symbol
                Text(signal.symbol,
                    style: const TextStyle(
                        color: _kText,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                // Timeframe
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kBlueDim,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(signal.timeframe,
                      style: const TextStyle(
                          color: _kBlue,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
                const Spacer(),
                // Status
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                        color: _statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(_statusLabel,
                      style: TextStyle(
                          color: _statusColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5)),
                ),
              ]),
            ),

            // â”€â”€ Row 2: Confidence meter â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: _ConfidenceBar(
                  confidence: signal.confidence, color: _typeColor),
            ),

            // â”€â”€ Row 3: Entry / SL / TP â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: _PriceRow(signal: signal, typeColor: _typeColor),
            ),

            // â”€â”€ Row 4: Reason tags + time â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    children: signal.reasonTags.map((t) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _typeColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: _typeColor.withValues(alpha: 0.2)),
                      ),
                      child: Text(t,
                          style: TextStyle(
                              color: _typeColor.withValues(alpha: 0.8),
                              fontSize: 9,
                              fontWeight: FontWeight.w600)),
                    )).toList(),
                  ),
                ),
                const SizedBox(width: 8),
                Text(_timeAgo(),
                    style: const TextStyle(
                        color: _kSubtext, fontSize: 10)),
              ]),
            ),

            // â”€â”€ Expand toggle â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(children: [
                Icon(Icons.psychology_outlined, color: _kGold, size: 13),
                const SizedBox(width: 5),
                Text('AI Explanation',
                    style: const TextStyle(
                        color: _kGold,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: _kSubtext,
                  size: 18,
                ),
              ]),
            ),

            // â”€â”€ Expandable explanation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Container(
                margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kGold.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _kGold.withValues(alpha: 0.15)),
                ),
                child: Text(
                  signal.explanation,
                  style: TextStyle(
                      color: _kText.withValues(alpha: 0.85),
                      fontSize: 12,
                      height: 1.6),
                ),
              ),
            ),

            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Confidence bar
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _ConfidenceBar extends StatelessWidget {
  const _ConfidenceBar({required this.confidence, required this.color});
  final int confidence;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Confidence',
                style: const TextStyle(color: _kSubtext, fontSize: 10)),
            const Spacer(),
            Text('$confidence%',
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: confidence / 100,
              backgroundColor: _kBorder,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 5,
            ),
          ),
        ],
      );
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Price row: Entry / SL / TP + R:R
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.signal, required this.typeColor});
  final TradeSignal signal;
  final Color typeColor;

  String _fmt(double p) =>
      signal.symbol.contains('JPY') ? p.toStringAsFixed(3) : p.toStringAsFixed(5);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: Row(children: [
          _PriceCell('ENTRY', _fmt(signal.entryPrice), typeColor),
          _vDivider(),
          _PriceCell('STOP LOSS', _fmt(signal.stopLoss), _kRed),
          _vDivider(),
          _PriceCell('TAKE PROFIT', _fmt(signal.takeProfit), _kGreen),
          _vDivider(),
          _PriceCell('R:R', '1:${signal.riskReward.toStringAsFixed(1)}', _kGold),
        ]),
      );

  Widget _vDivider() => Container(
      width: 1, height: 28, color: _kDivider,
      margin: const EdgeInsets.symmetric(horizontal: 8));
}

class _PriceCell extends StatelessWidget {
  const _PriceCell(this.label, this.value, this.color);
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(label,
              style: const TextStyle(
                  color: _kSubtext, fontSize: 8,
                  fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.signal_cellular_alt_rounded,
              color: _kSubtext, size: 40),
          const SizedBox(height: 12),
          const Text('No signals match this filter',
              style: TextStyle(color: _kSubtext, fontSize: 14)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Phase 4: Plain English Explainer with 3 literacy levels
// ─────────────────────────────────────────────────────────────────────────────
class _ExplainerPanel extends StatefulWidget {
  const _ExplainerPanel({required this.signal});
  final TradeSignal signal;

  @override
  State<_ExplainerPanel> createState() => _ExplainerPanelState();
}

class _ExplainerPanelState extends State<_ExplainerPanel> {
  int _level = 1; // 0=simple, 1=standard, 2=advanced

  String get _text {
    if (_level == 0) return widget.signal.explainSimple ?? widget.signal.explanation;
    if (_level == 2) return widget.signal.explainAdvanced ?? widget.signal.explanation;
    return widget.signal.explainStandard ?? widget.signal.explanation;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      decoration: BoxDecoration(
        color: _kGold.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kGold.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Level selector
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(children: [
              const Icon(Icons.school_rounded, color: _kGold, size: 12),
              const SizedBox(width: 6),
              const Text('Explanation Level',
                  style: TextStyle(color: _kGold, fontSize: 10, fontWeight: FontWeight.w600)),
              const Spacer(),
              _LevelChip(label: 'Simple',   active: _level == 0, onTap: () => setState(() => _level = 0)),
              const SizedBox(width: 4),
              _LevelChip(label: 'Standard', active: _level == 1, onTap: () => setState(() => _level = 1)),
              const SizedBox(width: 4),
              _LevelChip(label: 'Expert',   active: _level == 2, onTap: () => setState(() => _level = 2)),
            ]),
          ),
          Container(height: 1, color: _kGold.withValues(alpha: 0.1)),
          // Explanation text
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _text,
              style: TextStyle(
                  color: _kText.withValues(alpha: 0.85),
                  fontSize: 12,
                  height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? _kGold.withValues(alpha: 0.2) : _kCard,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: active ? _kGold.withValues(alpha: 0.5) : _kBorder),
      ),
      child: Text(label,
          style: TextStyle(
              color: active ? _kGold : _kSubtext,
              fontSize: 9,
              fontWeight: FontWeight.w700)),
    ),
  );
}

