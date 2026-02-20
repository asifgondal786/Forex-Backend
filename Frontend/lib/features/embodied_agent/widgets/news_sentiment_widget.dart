import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/api_service.dart';

class NewsSentimentWidget extends StatefulWidget {
  const NewsSentimentWidget({super.key});

  @override
  State<NewsSentimentWidget> createState() => _NewsSentimentWidgetState();
}

class _NewsSentimentWidgetState extends State<NewsSentimentWidget> {
  static const Duration _refreshInterval = Duration(seconds: 45);
  static const Duration _marqueeTick = Duration(milliseconds: 16);
  static const double _marqueeStepDesktop = 0.62;
  static const double _marqueeStepMobile = 0.45;

  final ApiService _apiService = ApiService();
  final ScrollController _marqueeController = ScrollController();

  Timer? _refreshTimer;
  Timer? _marqueeTimer;

  bool _isLoading = true;
  bool _isOfflineFallback = false;
  bool _pauseMarquee = false;
  double _marqueeStep = _marqueeStepDesktop;

  String? _error;
  DateTime? _updatedAt;
  String _trend = 'neutral';
  String _volatility = 'medium';
  String _riskLevel = 'moderate';
  double _sentimentScore = 0.5;
  List<_NewsItem> _newsItems = const <_NewsItem>[];
  int _selectedCategory = 0;

  static const List<String> _categories = <String>[
    'All',
    'High Impact',
    'Medium Impact',
    'Low Impact',
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_loadData());
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      unawaited(_loadData(silent: true));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startMarquee();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _marqueeTimer?.cancel();
    _marqueeController.dispose();
    _apiService.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _apiService.getForexNews(),
        _apiService.getForexMarketSentiment(),
      ]);

      final newsPayload = (results[0] as Map<String, dynamic>);
      final sentimentPayload = (results[1] as Map<String, dynamic>);
      final newsItems = _parseNews(newsPayload);
      final sentiment = _parseSentiment(sentimentPayload);

      if (!mounted) {
        return;
      }

      setState(() {
        _newsItems = newsItems;
        _trend = sentiment.trend;
        _volatility = sentiment.volatility;
        _riskLevel = sentiment.riskLevel;
        _sentimentScore = sentiment.score;
        _updatedAt = sentiment.timestamp ?? _latestNewsTimestamp(newsItems);
        _isOfflineFallback = _isFallbackPayload(newsPayload) ||
            _isFallbackPayload(sentimentPayload);
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = 'Unable to load news and sentiment right now.';
      });
    }
  }

  bool _isFallbackPayload(Map<String, dynamic> payload) {
    return (payload['status']?.toString().toLowerCase() ?? '') == 'fallback';
  }

  DateTime? _latestNewsTimestamp(List<_NewsItem> items) {
    if (items.isEmpty) {
      return null;
    }
    return items.map((item) => item.timestamp).reduce(
          (current, next) => current.isAfter(next) ? current : next,
        );
  }

  List<_NewsItem> _parseNews(Map<String, dynamic> payload) {
    final rawList = _extractNewsList(payload);
    final parsed = rawList
        .whereType<Map<String, dynamic>>()
        .map(_mapNewsItem)
        .whereType<_NewsItem>()
        .toList();

    if (parsed.isEmpty) {
      final now = DateTime.now();
      return <_NewsItem>[
        _NewsItem(
          title: 'No live news items yet',
          source: 'System',
          timestamp: now,
          impact: 'MEDIUM',
          category: 'Market',
          summary: 'Waiting for backend news stream.',
          sentimentLabel: 'Neutral',
          sentimentColor: const Color(0xFF3B82F6),
          relatedPairs: const <String>['EUR/USD'],
          isLatest: true,
        ),
      ];
    }

    parsed.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final newestTimestamp = parsed.first.timestamp;
    return parsed
        .map((item) =>
            item.copyWith(isLatest: item.timestamp == newestTimestamp))
        .toList();
  }

  List<dynamic> _extractNewsList(Map<String, dynamic> payload) {
    final directNews = payload['news'];
    if (directNews is List) {
      return directNews;
    }
    final headlines = payload['headlines'];
    if (headlines is List) {
      return headlines;
    }
    final data = payload['data'];
    if (data is List) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      final nestedNews = data['news'];
      if (nestedNews is List) {
        return nestedNews;
      }
      final nestedHeadlines = data['headlines'];
      if (nestedHeadlines is List) {
        return nestedHeadlines;
      }
    }
    return const <dynamic>[];
  }

  _NewsItem? _mapNewsItem(Map<String, dynamic> value) {
    final title = _firstText(<dynamic>[
      value['title'],
      value['event'],
      value['headline'],
    ]);
    if (title == null) {
      return null;
    }

    final timestamp = _parseDate(<dynamic>[
          value['published_at'],
          value['time'],
          value['timestamp'],
        ]) ??
        DateTime.now();
    final impact = _normalizeImpact(value['impact']?.toString());
    final category = _firstText(<dynamic>[value['category']]) ??
        (value.containsKey('event') ? 'Economic' : 'Market');
    final summary = _buildSummary(value);
    final sentimentLabel = _normalizeSentiment(value['sentiment']);
    final source = _firstText(<dynamic>[
          value['source'],
          value['currency'] != null ? '${value['currency']} Calendar' : null,
        ]) ??
        'Market Feed';

    return _NewsItem(
      title: title,
      source: source,
      timestamp: timestamp,
      impact: impact,
      category: category,
      summary: summary,
      sentimentLabel: sentimentLabel,
      sentimentColor: _sentimentColor(sentimentLabel),
      relatedPairs: _derivePairs(value),
      isLatest: false,
    );
  }

  String _buildSummary(Map<String, dynamic> value) {
    final excerpt = _firstText(<dynamic>[value['excerpt'], value['detail']]);
    if (excerpt != null) {
      return excerpt;
    }

    final actual = _firstText(<dynamic>[value['actual']]);
    final forecast = _firstText(<dynamic>[value['forecast']]);
    final previous = _firstText(<dynamic>[value['previous']]);

    final segments = <String>[];
    if (actual != null) {
      segments.add('Actual $actual');
    }
    if (forecast != null) {
      segments.add('Forecast $forecast');
    }
    if (previous != null) {
      segments.add('Previous $previous');
    }
    if (segments.isNotEmpty) {
      return segments.join(' | ');
    }
    return 'No extra details provided.';
  }

  List<String> _derivePairs(Map<String, dynamic> value) {
    final relatedPairs = value['relatedPairs'];
    if (relatedPairs is List) {
      final parsed = relatedPairs
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }

    final pair = _firstText(<dynamic>[value['pair']]);
    if (pair != null) {
      return <String>[pair];
    }

    final currency = _firstText(<dynamic>[value['currency']]);
    if (currency != null) {
      switch (currency.toUpperCase()) {
        case 'USD':
          return const <String>['EUR/USD', 'GBP/USD', 'USD/JPY'];
        case 'EUR':
          return const <String>['EUR/USD', 'EUR/GBP'];
        case 'GBP':
          return const <String>['GBP/USD', 'EUR/GBP'];
        case 'JPY':
          return const <String>['USD/JPY', 'EUR/JPY'];
      }
    }

    return const <String>['EUR/USD'];
  }

  _SentimentSnapshot _parseSentiment(Map<String, dynamic> payload) {
    final source = payload['sentiment'] is Map<String, dynamic>
        ? payload['sentiment']
        : payload;
    final map = source is Map<String, dynamic> ? source : <String, dynamic>{};

    final trend =
        _normalizeTrend(_firstText(<dynamic>[map['trend'], map['bias']]));
    final volatility =
        _normalizeLevel(_firstText(<dynamic>[map['volatility']]));
    final riskLevel =
        _normalizeLevel(_firstText(<dynamic>[map['risk_level'], map['risk']]));

    final numericScore = _asDouble(<dynamic>[
      map['score'],
      map['sentiment_score'],
      map['confidence'],
    ]);

    final score = numericScore == null
        ? _trendToScore(trend)
        : (numericScore > 1 ? numericScore / 100 : numericScore)
            .clamp(0.0, 1.0);

    final timestamp = _parseDate(<dynamic>[
      map['timestamp'],
      map['updated_at'],
    ]);

    return _SentimentSnapshot(
      trend: trend,
      volatility: volatility,
      riskLevel: riskLevel,
      score: score,
      timestamp: timestamp,
    );
  }

  String _normalizeTrend(String? value) {
    if (value == null) {
      return 'neutral';
    }
    final normalized = value.trim().toLowerCase();
    if (normalized.contains('bull')) {
      return 'bullish';
    }
    if (normalized.contains('bear')) {
      return 'bearish';
    }
    return 'neutral';
  }

  String _normalizeLevel(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'medium';
    }
    return value.trim().toLowerCase();
  }

  String _normalizeImpact(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'MEDIUM';
    }
    final normalized = raw.trim().toUpperCase();
    if (normalized.contains('CRITICAL')) {
      return 'CRITICAL';
    }
    if (normalized.contains('HIGH')) {
      return 'HIGH';
    }
    if (normalized.contains('LOW')) {
      return 'LOW';
    }
    return 'MEDIUM';
  }

  String _normalizeSentiment(dynamic value) {
    if (value == null) {
      return 'Neutral';
    }
    if (value is num) {
      if (value > 0.15) {
        return 'Bullish';
      }
      if (value < -0.15) {
        return 'Bearish';
      }
      return 'Neutral';
    }
    final normalized = value.toString().trim().toLowerCase();
    if (normalized.contains('bull')) {
      return 'Bullish';
    }
    if (normalized.contains('bear')) {
      return 'Bearish';
    }
    return 'Neutral';
  }

  DateTime? _parseDate(List<dynamic> candidates) {
    for (final candidate in candidates) {
      if (candidate == null) {
        continue;
      }
      final parsed = DateTime.tryParse(candidate.toString());
      if (parsed != null) {
        return parsed.toLocal();
      }
    }
    return null;
  }

  String? _firstText(List<dynamic> candidates) {
    for (final candidate in candidates) {
      if (candidate == null) {
        continue;
      }
      final text = candidate.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'n/a') {
        return text;
      }
    }
    return null;
  }

  double? _asDouble(List<dynamic> candidates) {
    for (final candidate in candidates) {
      if (candidate == null) {
        continue;
      }
      if (candidate is num) {
        return candidate.toDouble();
      }
      final parsed = double.tryParse(candidate.toString());
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  double _trendToScore(String trend) {
    switch (trend) {
      case 'bullish':
        return 0.68;
      case 'bearish':
        return 0.32;
      default:
        return 0.5;
    }
  }

  Color _impactColor(String impact) {
    switch (impact) {
      case 'CRITICAL':
        return AppColors.errorRed;
      case 'HIGH':
        return const Color(0xFFF59E0B);
      case 'LOW':
        return Colors.white70;
      default:
        return const Color(0xFF3B82F6);
    }
  }

  Color _sentimentColor(String sentiment) {
    switch (sentiment.toLowerCase()) {
      case 'bullish':
        return AppColors.statusRunning;
      case 'bearish':
        return AppColors.errorRed;
      default:
        return const Color(0xFF3B82F6);
    }
  }

  void _startMarquee() {
    _marqueeTimer?.cancel();
    _marqueeTimer = Timer.periodic(_marqueeTick, (_) {
      if (_pauseMarquee || !_marqueeController.hasClients) {
        return;
      }
      final maxOffset = _marqueeController.position.maxScrollExtent;
      if (maxOffset <= 0) {
        return;
      }
      final next = _marqueeController.offset + _marqueeStep;
      if (next >= maxOffset) {
        _marqueeController.jumpTo(0);
      } else {
        _marqueeController.jumpTo(next);
      }
    });
  }

  List<_NewsItem> get _filteredNews {
    if (_selectedCategory == 0) {
      return _newsItems;
    }
    final label = _categories[_selectedCategory].toUpperCase();
    if (label.contains('HIGH')) {
      return _newsItems
          .where((item) => item.impact == 'HIGH' || item.impact == 'CRITICAL')
          .toList();
    }
    if (label.contains('MEDIUM')) {
      return _newsItems.where((item) => item.impact == 'MEDIUM').toList();
    }
    return _newsItems.where((item) => item.impact == 'LOW').toList();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 820;
    final isTiny = MediaQuery.of(context).size.width < 260;
    _marqueeStep = isMobile ? _marqueeStepMobile : _marqueeStepDesktop;

    final news = _filteredNews.isEmpty ? _newsItems : _filteredNews;
    final loopedNews = news.length <= 1 ? news : <_NewsItem>[...news, ...news];
    final trendColor = _sentimentColor(_trend);
    final statusText = _isOfflineFallback ? 'Fallback' : 'Live';
    final statusColor =
        _isOfflineFallback ? const Color(0xFFF59E0B) : AppColors.statusRunning;

    return Container(
      padding: EdgeInsets.all(isTiny ? 12 : 18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LayoutBuilder(
            builder: (context, constraints) {
              final compactHeader = constraints.maxWidth < 220;
              final title = Text(
                'News and Sentiment',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: compactHeader ? 14 : 16,
                ),
              );

              final statusChip = Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compactHeader ? 8 : 10,
                  vertical: compactHeader ? 5 : 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: compactHeader ? 9 : 10,
                  ),
                ),
              );

              final refreshButton = IconButton(
                visualDensity: compactHeader
                    ? VisualDensity.compact
                    : VisualDensity.standard,
                constraints: compactHeader
                    ? const BoxConstraints(minWidth: 28, minHeight: 28)
                    : null,
                padding: compactHeader ? EdgeInsets.zero : null,
                tooltip: 'Refresh news',
                onPressed: _isLoading ? null : () => unawaited(_loadData()),
                icon: Icon(
                  Icons.refresh,
                  color: Colors.white70,
                  size: compactHeader ? 16 : 18,
                ),
              );

              if (compactHeader) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    title,
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[statusChip, refreshButton],
                    ),
                  ],
                );
              }

              return Row(
                children: <Widget>[
                  Expanded(child: title),
                  statusChip,
                  const SizedBox(width: 8),
                  refreshButton,
                ],
              );
            },
          ),
          if (_updatedAt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Updated ${_formatUpdateAge(_updatedAt!)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 10,
                ),
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List<Widget>.generate(_categories.length, (index) {
                final selected = _selectedCategory == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      setState(() {
                        _selectedCategory = index;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF3B82F6)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF3B82F6)
                              : Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Text(
                        _categories[index],
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoading && _newsItems.isEmpty)
            const SizedBox(
              height: 136,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            _buildMarquee(loopedNews, isMobile),
          const SizedBox(height: 12),
          _buildSentimentPanel(trendColor),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFFCA5A5),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMarquee(List<_NewsItem> news, bool isMobile) {
    if (news.isEmpty) {
      return Container(
        height: 132,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Text(
          'No news available yet.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 12,
          ),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => _pauseMarquee = true,
      onExit: (_) => _pauseMarquee = false,
      child: Container(
        height: 154,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SingleChildScrollView(
            controller: _marqueeController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              children: news.asMap().entries.map((entry) {
                final item = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                    left: entry.key == 0 ? 10 : 0,
                    right: 10,
                    top: 10,
                    bottom: 10,
                  ),
                  child: _buildNewsCard(item, isMobile),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewsCard(_NewsItem item, bool isMobile) {
    final impactColor = _impactColor(item.impact);
    return Container(
      width: isMobile ? 288 : 348,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (item.isLatest) _buildFlag('LATEST', AppColors.errorRed),
              if (item.isLatest) const SizedBox(width: 6),
              if (item.impact == 'HIGH' || item.impact == 'CRITICAL')
                _buildFlag('HOT', const Color(0xFFF59E0B)),
              const Spacer(),
              _buildBadge(item.sentimentLabel, item.sentimentColor),
              const SizedBox(width: 6),
              _buildBadge(item.impact, impactColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: item.relatedPairs.take(3).map((pair) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  pair,
                  style: const TextStyle(
                    color: Color(0xFF93C5FD),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }).toList(),
          ),
          const Spacer(),
          Row(
            children: <Widget>[
              Text(
                item.source,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                _formatUpdateAge(item.timestamp),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.52),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSentimentPanel(Color trendColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Market Sentiment Snapshot',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _sentimentScore,
              minHeight: 9,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(trendColor),
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 260;
              final trendLabel = Text(
                _trend.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: trendColor,
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w700,
                ),
              );
              final scoreLabel = Text(
                '${(_sentimentScore * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: compact ? 10 : 11,
                ),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Flexible(child: trendLabel),
                        const SizedBox(width: 8),
                        scoreLabel,
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        _buildMetricChip('Vol', _volatility),
                        _buildMetricChip('Risk', _riskLevel),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: <Widget>[
                  Flexible(child: trendLabel),
                  const SizedBox(width: 8),
                  scoreLabel,
                  const Spacer(),
                  _buildMetricChip('Volatility', _volatility),
                  const SizedBox(width: 6),
                  _buildMetricChip('Risk', _riskLevel),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFlag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 8,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 8,
        ),
      ),
    );
  }

  Widget _buildMetricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        '$label ${value.toUpperCase()}',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.75),
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatUpdateAge(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inSeconds < 10) {
      return 'just now';
    }
    if (diff.inMinutes < 1) {
      return '${diff.inSeconds}s ago';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    }
    return '${diff.inDays}d ago';
  }
}

class _NewsItem {
  final String title;
  final String source;
  final DateTime timestamp;
  final String impact;
  final String category;
  final String summary;
  final String sentimentLabel;
  final Color sentimentColor;
  final List<String> relatedPairs;
  final bool isLatest;

  const _NewsItem({
    required this.title,
    required this.source,
    required this.timestamp,
    required this.impact,
    required this.category,
    required this.summary,
    required this.sentimentLabel,
    required this.sentimentColor,
    required this.relatedPairs,
    required this.isLatest,
  });

  _NewsItem copyWith({
    String? title,
    String? source,
    DateTime? timestamp,
    String? impact,
    String? category,
    String? summary,
    String? sentimentLabel,
    Color? sentimentColor,
    List<String>? relatedPairs,
    bool? isLatest,
  }) {
    return _NewsItem(
      title: title ?? this.title,
      source: source ?? this.source,
      timestamp: timestamp ?? this.timestamp,
      impact: impact ?? this.impact,
      category: category ?? this.category,
      summary: summary ?? this.summary,
      sentimentLabel: sentimentLabel ?? this.sentimentLabel,
      sentimentColor: sentimentColor ?? this.sentimentColor,
      relatedPairs: relatedPairs ?? this.relatedPairs,
      isLatest: isLatest ?? this.isLatest,
    );
  }
}

class _SentimentSnapshot {
  final String trend;
  final String volatility;
  final String riskLevel;
  final double score;
  final DateTime? timestamp;

  const _SentimentSnapshot({
    required this.trend,
    required this.volatility,
    required this.riskLevel,
    required this.score,
    required this.timestamp,
  });
}
