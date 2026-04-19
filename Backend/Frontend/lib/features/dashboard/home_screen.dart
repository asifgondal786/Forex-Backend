import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/account_connection.dart';
import '../../providers/account_connection_provider.dart';
import '../../providers/market_watch_provider.dart';
import '../../providers/news_events_provider.dart';

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
      context.read<AccountConnectionProvider>().loadConnections();
      context.read<MarketWatchProvider>().init();
      context.read<NewsEventsProvider>().init();
    });
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    await Future.wait<void>([
      context.read<AccountConnectionProvider>().loadConnections(),
      context.read<MarketWatchProvider>().refresh(),
      context.read<NewsEventsProvider>().refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: const [
            _ConnectionStatusCard(),
            SizedBox(height: 16),
            _LivePricesSection(),
            SizedBox(height: 16),
            _NewsSection(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Open AI Chat'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionStatusCard extends StatelessWidget {
  const _ConnectionStatusCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<AccountConnectionProvider>();
    final account = provider.selectedAccount;
    final connected = account?.status == AccountConnectionStatus.connected;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                connected ? Icons.check_circle_rounded : Icons.error_outline,
                color: connected ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  connected
                      ? '${account?.broker ?? 'Broker'} connected'
                      : 'Broker not connected',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            account == null
                ? 'Add your trading account to unlock live automation.'
                : 'Balance: ${account.currency} ${account.balance.toStringAsFixed(2)}',
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.72),
              fontSize: 14,
            ),
          ),
          if (provider.lastError != null) ...[
            const SizedBox(height: 10),
            Text(
              provider.lastError!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LivePricesSection extends StatelessWidget {
  const _LivePricesSection();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MarketWatchProvider>();
    final quotes = provider.quotes.take(5).toList();

    return _Section(
      title: 'Live Prices',
      child: provider.isLoading && quotes.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              children: quotes.isEmpty
                  ? const [
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No live prices available yet.'),
                      ),
                    ]
                  : quotes.map((quote) {
                      return ListTile(
                        title: Text(quote.symbol),
                        subtitle: Text(
                          'Spread ${quote.spread.toStringAsFixed(1)}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              quote.mid.toStringAsFixed(
                                quote.symbol.contains('JPY') ? 3 : 5,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${quote.changePercent >= 0 ? '+' : ''}${quote.changePercent.toStringAsFixed(2)}%',
                              style: TextStyle(
                                color: quote.changePercent >= 0
                                    ? Colors.green
                                    : Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
            ),
    );
  }
}

class _NewsSection extends StatelessWidget {
  const _NewsSection();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NewsEventsProvider>();
    final articles = provider.articles.take(3).toList();

    return _Section(
      title: 'Latest News',
      child: provider.isLoading && articles.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              children: articles.isEmpty
                  ? const [
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No headlines available yet.'),
                      ),
                    ]
                  : articles.map((article) {
                      return ListTile(
                        title: Text(
                          article.headline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(article.source),
                      );
                    }).toList(),
            ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}


