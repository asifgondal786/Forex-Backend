// lib/features/news/news_events_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/news_events_provider.dart';
import '../../providers/mode_provider.dart';
import '../../core/widgets/quick_actions_overlay.dart';

// ── palette ──────────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// The original used NestedScrollView which makes it impossible to insert a
// plain widget (overlay) between header slivers and body.
// We switch to a simple Column so overlay sits between tab bar and content.
// ─────────────────────────────────────────────────────────────────────────────
class NewsEventsScreen extends StatefulWidget {
  const NewsEventsScreen({super.key});

  @override
  State<NewsEventsScreen> createState() => _NewsEventsScreenState();
}

class _NewsEventsScreenState extends State<NewsEventsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NewsEventsProvider>().init();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NewsEventsProvider>(
      builder: (ctx, provider, _) {
        return Scaffold(
          backgroundColor: _kBg,
          body: FadeTransition(
            opacity:
                CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Pinned app bar ───────────────────────────────────
                  _AppBar(provider: provider),

                  // ── News / Calendar tab switcher ─────────────────────
                  _TabBar(provider: provider),

                  // ── Quick actions overlay (dismissable) ──────────────
                  QuickActionsOverlay(
                    modeKey: 'newsEvents',
                    accentColor: _kBlue,
                    title: 'QUICK ACTIONS',
                    onAction: (action) {
                      switch (action.routeOrAction) {
                        case 'tab_calendar':
                          provider.setTab('Calendar');
                          break;
                        case 'filter_high':
                          provider.setImpactFilter('High');
                          break;
                        case 'filter_bullish':
                          provider.setSentimentFilter('Bullish');
                          break;
                        case 'switch_chat':
                          ctx.read<ModeProvider>().setMode(AppMode.aiChat);
                          Navigator.pushNamedAndRemoveUntil(
                              context, '/dashboard', (_) => false);
                          break;
                        default:
                          if (action.isRoute) {
                            Navigator.pushNamed(
                                context, action.routeOrAction);
                          }
                      }
                    },
                  ),

                  // ── Body ─────────────────────────────────────────────
                  Expanded(
                    child: provider.isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: _kGold))
                        : provider.tab == 'News'
                            ? _NewsTab(provider: provider)
                            : _CalendarTab(provider: provider),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App bar (plain Container — no Sliver needed in Column layout)
// ─────────────────────────────────────────────────────────────────────────────
class _AppBar extends StatelessWidget {
  const _AppBar({required this.provider});
  final NewsEventsProvider provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kDivider)),
      ),
      child: Row(children: [
        Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                color: _kBlue, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        const Text('News & Events',
            style: TextStyle(
                color: _kText,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.refresh_rounded,
              color: _kSubtext, size: 20),
          onPressed: provider.refresh,
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab bar
// ─────────────────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  const _TabBar({required this.provider});
  final NewsEventsProvider provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBg,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: ['News', 'Calendar'].map((t) {
          final active = provider.tab == t;
          return Expanded(
            child: GestureDetector(
              onTap: () => provider.setTab(t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(right: t == 'News' ? 6 : 0),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active
                      ? _kBlue.withValues(alpha: 0.15)
                      : _kCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: active
                        ? _kBlue.withValues(alpha: 0.4)
                        : _kBorder,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      t == 'News'
                          ? Icons.newspaper_rounded
                          : Icons.calendar_today_rounded,
                      color: active ? _kBlue : _kSubtext,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(t,
                        style: TextStyle(
                            color: active ? _kBlue : _kSubtext,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// News tab
// ─────────────────────────────────────────────────────────────────────────────
class _NewsTab extends StatelessWidget {
  const _NewsTab({required this.provider});
  final NewsEventsProvider provider;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: _FilterRow(provider: provider),
          ),
        ),
        if (provider.articles.isEmpty)
          const SliverFillRemaining(
              child: _EmptyState('No news articles'))
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _NewsCard(article: provider.articles[i]),
                ),
                childCount: provider.articles.length,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter row — impact + sentiment chips
// ─────────────────────────────────────────────────────────────────────────────
class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.provider});
  final NewsEventsProvider provider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 30,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _chip('All', provider.impactFilter == 'All', _kBlue,
                  () => provider.setImpactFilter('All')),
              _chip('High', provider.impactFilter == 'High', _kRed,
                  () => provider.setImpactFilter('High')),
              _chip('Medium', provider.impactFilter == 'Medium', _kAmber,
                  () => provider.setImpactFilter('Medium')),
              _chip('Low', provider.impactFilter == 'Low', _kGreen,
                  () => provider.setImpactFilter('Low')),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 30,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _chip('All', provider.sentimentFilter == 'All', _kBlue,
                  () => provider.setSentimentFilter('All')),
              _chip('Bullish', provider.sentimentFilter == 'Bullish',
                  _kGreen, () => provider.setSentimentFilter('Bullish')),
              _chip('Bearish', provider.sentimentFilter == 'Bearish',
                  _kRed, () => provider.setSentimentFilter('Bearish')),
              _chip('Neutral', provider.sentimentFilter == 'Neutral',
                  _kSubtext,
                  () => provider.setSentimentFilter('Neutral')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(
          String label, bool active, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(right: 8),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.15) : _kCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: active
                    ? color.withValues(alpha: 0.4)
                    : _kBorder),
          ),
          child: Text(label,
              style: TextStyle(
                  color: active ? color : _kSubtext,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// News card (expandable)
// ─────────────────────────────────────────────────────────────────────────────
class _NewsCard extends StatefulWidget {
  const _NewsCard({required this.article});
  final NewsArticle article;

  @override
  State<_NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<_NewsCard> {
  bool _expanded = false;

  Color get _impactColor => switch (widget.article.impact) {
        NewsImpact.high   => _kRed,
        NewsImpact.medium => _kAmber,
        NewsImpact.low    => _kGreen,
      };
  Color get _impactDim => switch (widget.article.impact) {
        NewsImpact.high   => _kRedDim,
        NewsImpact.medium => _kAmberDim,
        NewsImpact.low    => _kGreenDim,
      };
  String get _impactLabel => switch (widget.article.impact) {
        NewsImpact.high   => 'HIGH',
        NewsImpact.medium => 'MED',
        NewsImpact.low    => 'LOW',
      };
  Color get _sentColor => switch (widget.article.sentiment) {
        NewsSentiment.bullish => _kGreen,
        NewsSentiment.bearish => _kRed,
        NewsSentiment.neutral => _kSubtext,
      };
  IconData get _sentIcon => switch (widget.article.sentiment) {
        NewsSentiment.bullish => Icons.arrow_upward_rounded,
        NewsSentiment.bearish => Icons.arrow_downward_rounded,
        NewsSentiment.neutral => Icons.remove_rounded,
      };
  String get _sentLabel => switch (widget.article.sentiment) {
        NewsSentiment.bullish => 'BULLISH',
        NewsSentiment.bearish => 'BEARISH',
        NewsSentiment.neutral => 'NEUTRAL',
      };

  String _timeAgo() {
    final diff = DateTime.now().difference(widget.article.publishedAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _expanded
                ? _impactColor.withValues(alpha: 0.3)
                : _kBorder,
            width: _expanded ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _Badge(_impactLabel, _impactColor, _impactDim),
                    const SizedBox(width: 6),
                    _Badge(_sentLabel, _sentColor,
                        _sentColor.withValues(alpha: 0.1),
                        icon: _sentIcon),
                    const Spacer(),
                    Text(widget.article.source,
                        style: const TextStyle(
                            color: _kSubtext,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    Text(_timeAgo(),
                        style: const TextStyle(
                            color: _kSubtext, fontSize: 10)),
                  ]),
                  const SizedBox(height: 10),
                  Text(widget.article.headline,
                      style: const TextStyle(
                          color: _kText,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.4)),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.currency_exchange_rounded,
                        color: _kSubtext, size: 11),
                    const SizedBox(width: 4),
                    Text(
                        'Affects: ${widget.article.affectedPairs}',
                        style: const TextStyle(
                            color: _kSubtext, fontSize: 10)),
                  ]),
                ],
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBorder),
                ),
                child: Text(widget.article.summary,
                    style: TextStyle(
                        color: _kText.withValues(alpha: 0.8),
                        fontSize: 12,
                        height: 1.6)),
              ),
            ),
            if (!_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Row(children: const [
                  Icon(Icons.expand_more_rounded,
                      color: _kSubtext, size: 14),
                  SizedBox(width: 4),
                  Text('Read more',
                      style: TextStyle(color: _kSubtext, fontSize: 10)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color, this.bg, {this.icon});
  final String label;
  final Color color, bg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 9),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Calendar tab
// ─────────────────────────────────────────────────────────────────────────────
class _CalendarTab extends StatelessWidget {
  const _CalendarTab({required this.provider});
  final NewsEventsProvider provider;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          if (provider.upcomingEvents.isNotEmpty) ...[
            _CalSection(
                title: 'Upcoming Events',
                icon: Icons.schedule_rounded,
                color: _kGold,
                events: provider.upcomingEvents),
            const SizedBox(height: 20),
          ],
          if (provider.pastEvents.isNotEmpty)
            _CalSection(
                title: 'Released Today',
                icon: Icons.check_circle_outline_rounded,
                color: _kSubtext,
                events: provider.pastEvents),
        ],
      );
}

class _CalSection extends StatelessWidget {
  const _CalSection(
      {required this.title,
      required this.icon,
      required this.color,
      required this.events});
  final String title;
  final IconData icon;
  final Color color;
  final List<EconomicEvent> events;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 7),
            Text(title,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          ...events.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _EventCard(event: e),
              )),
        ],
      );
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});
  final EconomicEvent event;

  Color get _impactColor => switch (event.impact) {
        NewsImpact.high   => _kRed,
        NewsImpact.medium => _kAmber,
        NewsImpact.low    => _kGreen,
      };

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _timeUntil(DateTime dt) {
    final diff = dt.difference(DateTime.now());
    if (diff.isNegative) return 'Released';
    if (diff.inMinutes < 60) return 'in ${diff.inMinutes}m';
    return 'in ${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
  }

  @override
  Widget build(BuildContext context) {
    final isUpcoming = event.isUpcoming;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isUpcoming
                ? _impactColor.withValues(alpha: 0.25)
                : _kBorder),
      ),
      child: Row(children: [
        Container(
            width: 3,
            height: 44,
            decoration: BoxDecoration(
                color: _impactColor,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.title,
                  style: const TextStyle(
                      color: _kText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Row(children: [
                _currencyBadge(event.currency),
                const SizedBox(width: 6),
                Text(event.country,
                    style: const TextStyle(
                        color: _kSubtext, fontSize: 10)),
              ]),
            ],
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_fmtTime(event.scheduledAt),
              style: const TextStyle(
                  color: _kText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(
            isUpcoming ? _timeUntil(event.scheduledAt) : 'Released',
            style: TextStyle(
                color: isUpcoming ? _kGold : _kSubtext,
                fontSize: 10,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (event.forecast != null) ...[
              _DataTag('F', event.forecast!, _kBlue),
              const SizedBox(width: 4),
            ],
            if (event.actual != null)
              _DataTag('A', event.actual!, _kGreen)
            else if (event.previous != null)
              _DataTag('P', event.previous!, _kSubtext),
          ]),
        ]),
      ]),
    );
  }

  Widget _currencyBadge(String code) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: _kBlueDim,
            borderRadius: BorderRadius.circular(4)),
        child: Text(code,
            style: const TextStyle(
                color: _kBlue,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5)),
      );
}

class _DataTag extends StatelessWidget {
  const _DataTag(this.prefix, this.value, this.color);
  final String prefix, value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$prefix:',
              style: const TextStyle(color: _kSubtext, fontSize: 9)),
          const SizedBox(width: 2),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w700)),
        ],
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.article_outlined,
              color: _kSubtext, size: 40),
          const SizedBox(height: 12),
          Text(message,
              style:
                  const TextStyle(color: _kSubtext, fontSize: 14)),
        ]),
      );
}