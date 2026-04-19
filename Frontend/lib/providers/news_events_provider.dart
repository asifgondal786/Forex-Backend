// lib/providers/news_events_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:forex_companion/services/api_service.dart';

enum NewsImpact { high, medium, low }
enum NewsSentiment { bullish, bearish, neutral }

class NewsArticle {
  final String id;
  final String headline;
  final String summary;
  final String source;
  final String affectedPairs;
  final NewsImpact impact;
  final NewsSentiment sentiment;
  final DateTime publishedAt;
  final String? url;

  const NewsArticle({
    required this.id,
    required this.headline,
    required this.summary,
    required this.source,
    required this.affectedPairs,
    required this.impact,
    required this.sentiment,
    required this.publishedAt,
    this.url,
  });

  factory NewsArticle.fromBackend(Map<String, dynamic> json, int index) {
    final impactStr = (json['impact'] as String? ?? 'medium').toLowerCase();
    final impact = impactStr == 'high'
        ? NewsImpact.high
        : impactStr == 'low'
            ? NewsImpact.low
            : NewsImpact.medium;
    final sentScore = (json['sentiment'] as num? ?? 0).toDouble();
    final sentiment = sentScore > 0.1
        ? NewsSentiment.bullish
        : sentScore < -0.1
            ? NewsSentiment.bearish
            : NewsSentiment.neutral;
    return NewsArticle(
      id: 'article_$index',
      headline: json['title'] as String? ?? 'Market Update',
      summary: json['title'] as String? ?? '',
      source: json['source'] as String? ?? 'News',
      affectedPairs: 'EUR, USD, GBP',
      impact: impact,
      sentiment: sentiment,
      publishedAt:
          DateTime.tryParse(json['published_at'] as String? ?? '') ??
              DateTime.now(),
      url: json['url'] as String?,
    );
  }
}

class EconomicEvent {
  final String id;
  final String title;
  final String country;
  final String currency;
  final NewsImpact impact;
  final DateTime scheduledAt;
  final String? forecast;
  final String? previous;
  final String? actual;
  final bool isUpcoming;

  const EconomicEvent({
    required this.id,
    required this.title,
    required this.country,
    required this.currency,
    required this.impact,
    required this.scheduledAt,
    this.forecast,
    this.previous,
    this.actual,
    required this.isUpcoming,
  });

  factory EconomicEvent.fromBackend(Map<String, dynamic> json) {
    final impactStr = (json['impact'] as String? ?? 'high').toLowerCase();
    final impact = impactStr == 'high'
        ? NewsImpact.high
        : impactStr == 'low'
            ? NewsImpact.low
            : NewsImpact.medium;
    final currency = json['currency'] as String? ?? 'USD';
    final startTime =
        DateTime.tryParse(json['start_time'] as String? ?? '') ??
            DateTime.now();
    final isUpcoming = startTime.isAfter(DateTime.now());
    final countryMap = {
      'USD': 'United States',
      'EUR': 'Eurozone',
      'GBP': 'United Kingdom',
      'JPY': 'Japan',
      'AUD': 'Australia',
      'CAD': 'Canada',
      'CHF': 'Switzerland',
      'NZD': 'New Zealand',
    };
    return EconomicEvent(
      id: json['id'] as String? ?? 'event_$startTime',
      title: json['name'] as String? ?? 'Economic Event',
      country: countryMap[currency] ?? 'Global',
      currency: currency,
      impact: impact,
      scheduledAt: startTime,
      isUpcoming: isUpcoming,
    );
  }
}

class NewsEventsProvider extends ChangeNotifier {
  final ApiService _api;
  NewsEventsProvider(this._api);

  List<NewsArticle> _articles = [];
  List<EconomicEvent> _events = [];
  bool _isLoading = false;
  String _tab = 'News';
  String _impactFilter = 'All';
  String _sentimentFilter = 'All';

  List<NewsArticle> get articles => _filteredArticles;
  List<EconomicEvent> get upcomingEvents =>
      _events.where((e) => e.isUpcoming).toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  List<EconomicEvent> get pastEvents =>
      _events.where((e) => !e.isUpcoming).toList()
        ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

  bool get isLoading => _isLoading;
  String get tab => _tab;
  String get impactFilter => _impactFilter;
  String get sentimentFilter => _sentimentFilter;

  void setTab(String t) {
    _tab = t;
    notifyListeners();
  }

  void setImpactFilter(String f) {
    _impactFilter = f;
    notifyListeners();
  }

  void setSentimentFilter(String f) {
    _sentimentFilter = f;
    notifyListeners();
  }

  List<NewsArticle> get _filteredArticles {
    var list = [..._articles];
    if (_impactFilter != 'All') {
      final imp = NewsImpact.values.firstWhere(
          (e) => e.name.toLowerCase() == _impactFilter.toLowerCase(),
          orElse: () => NewsImpact.high);
      list = list.where((a) => a.impact == imp).toList();
    }
    if (_sentimentFilter != 'All') {
      final sent = NewsSentiment.values.firstWhere(
          (e) => e.name.toLowerCase() == _sentimentFilter.toLowerCase(),
          orElse: () => NewsSentiment.neutral);
      list = list.where((a) => a.sentiment == sent).toList();
    }
    return list;
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.fetchNewsFeed(pair: 'EUR/USD'),
        _api.fetchEconomicEvents(hours: 48, highImpactOnly: false),
      ]);
      final feedData = results[0] as Map<String, dynamic>;
      final headlines = feedData['top_headlines'] as List? ?? [];
      _articles = headlines
          .asMap()
          .entries
          .map((e) =>
              NewsArticle.fromBackend(e.value as Map<String, dynamic>, e.key))
          .toList();
      final eventsRaw = results[1] as List<Map<String, dynamic>>;
      _events = eventsRaw.map((e) => EconomicEvent.fromBackend(e)).toList();
    } catch (e) {
      debugPrint('NewsEventsProvider error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async => init();
}

