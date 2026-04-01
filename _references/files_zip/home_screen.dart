import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(scheme, context),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _BalanceCard(scheme: scheme),
                const SizedBox(height: 16),
                _QuickActionsRow(scheme: scheme),
                const SizedBox(height: 24),
                _SectionHeader('Market Snapshot', scheme),
                const SizedBox(height: 10),
                _MarketSnapshot(scheme: scheme),
                const SizedBox(height: 24),
                _SectionHeader('Recent Signals', scheme),
                const SizedBox(height: 10),
                _RecentSignals(scheme: scheme),
                const SizedBox(height: 24),
                _SectionHeader('AI Recommendation', scheme),
                const SizedBox(height: 10),
                _AiPreviewCard(scheme: scheme),
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
          Text(
            'Tajir',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: scheme.onSurface),
          onPressed: () {},
        ),
        IconButton(
          icon: Icon(Icons.person_outline_rounded, color: scheme.onSurface),
          onPressed: () {},
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final ColorScheme scheme;

  const _BalanceCard({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primary.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.35),
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
              Text(
                'Account Balance',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.circle, size: 6, color: Colors.greenAccent),
                    SizedBox(width: 5),
                    Text(
                      'Paper Trading',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '\$10,248.32',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.arrow_upward, color: Colors.greenAccent, size: 14),
              const SizedBox(width: 4),
              const Text(
                '+\$248.32 (2.48%) today',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _BalanceStat('Open P&L', '+\$42.10', Colors.greenAccent),
              const SizedBox(width: 20),
              _BalanceStat('Win Rate', '73.2%', Colors.white),
              const SizedBox(width: 20),
              _BalanceStat('Trades', '47', Colors.white),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _BalanceStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 11,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final ColorScheme scheme;

  const _QuickActionsRow({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(
        icon: Icons.trending_up_rounded,
        label: 'Trade',
        color: Colors.green,
        onTap: () {},
      ),
      _QuickAction(
        icon: Icons.auto_awesome_rounded,
        label: 'Ask AI',
        color: Colors.purple,
        onTap: () {},
      ),
      _QuickAction(
        icon: Icons.bar_chart_rounded,
        label: 'Charts',
        color: Colors.blue,
        onTap: () {},
      ),
      _QuickAction(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Portfolio',
        color: Colors.orange,
        onTap: () {},
      ),
    ];

    return Row(
      children: actions
          .map((a) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: actions.indexOf(a) < actions.length - 1 ? 8 : 0,
                  ),
                  child: _QuickActionWidget(action: a, scheme: scheme),
                ),
              ))
          .toList(),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class _QuickActionWidget extends StatelessWidget {
  final _QuickAction action;
  final ColorScheme scheme;

  const _QuickActionWidget({required this.action, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: action.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: action.color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(action.icon, color: action.color, size: 22),
            const SizedBox(height: 6),
            Text(
              action.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: action.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final ColorScheme scheme;

  const _SectionHeader(this.title, this.scheme);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: scheme.onSurface,
          ),
        ),
        Text(
          'See all',
          style: TextStyle(
            fontSize: 13,
            color: scheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MarketSnapshot extends StatelessWidget {
  final ColorScheme scheme;

  const _MarketSnapshot({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final pairs = [
      _MarketItem('EUR/USD', '1.08432', '+0.12%', true),
      _MarketItem('GBP/JPY', '191.234', '-0.34%', false),
      _MarketItem('XAU/USD', '2341.5', '+0.87%', true),
    ];

    return Row(
      children: pairs
          .map((p) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: pairs.indexOf(p) < pairs.length - 1 ? 8 : 0,
                  ),
                  child: _MarketItemCard(item: p, scheme: scheme),
                ),
              ))
          .toList(),
    );
  }
}

class _MarketItem {
  final String pair;
  final String price;
  final String change;
  final bool positive;

  const _MarketItem(this.pair, this.price, this.change, this.positive);
}

class _MarketItemCard extends StatelessWidget {
  final _MarketItem item;
  final ColorScheme scheme;

  const _MarketItemCard({required this.item, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final color = item.positive ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.pair,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.price,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.change,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSignals extends StatelessWidget {
  final ColorScheme scheme;

  const _RecentSignals({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final signals = [
      _SignalPreview('EUR/USD', 'BUY', '78%', 'Strong bullish momentum on H4'),
      _SignalPreview('GBP/JPY', 'SELL', '65%', 'Resistance rejection at 191.80'),
      _SignalPreview('XAU/USD', 'BUY', '82%', 'Safe haven demand rising'),
    ];

    return Column(
      children: signals
          .map((s) => _SignalPreviewCard(signal: s, scheme: scheme))
          .toList(),
    );
  }
}

class _SignalPreview {
  final String pair;
  final String direction;
  final String probability;
  final String summary;

  const _SignalPreview(
      this.pair, this.direction, this.probability, this.summary);
}

class _SignalPreviewCard extends StatelessWidget {
  final _SignalPreview signal;
  final ColorScheme scheme;

  const _SignalPreviewCard({required this.signal, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final isBuy = signal.direction == 'BUY';
    final color = isBuy ? Colors.green : Colors.red;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              signal.direction,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
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
                  signal.pair,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
                Text(
                  signal.summary,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              signal.probability,
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiPreviewCard extends StatelessWidget {
  final ColorScheme scheme;

  const _AiPreviewCard({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.withOpacity(0.1),
            Colors.blue.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.15),
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
                const Text(
                  'AI Copilot',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'EUR/USD shows a high-probability bullish continuation. London session breakout above 1.0850 is the key level to watch.',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurface.withOpacity(0.8),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {},
                  child: Text(
                    'Get full analysis →',
                    style: TextStyle(
                      color: Colors.purple,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
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
