// lib/providers/news_events_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────
enum NewsImpact { high, medium, low }
enum NewsSentiment { bullish, bearish, neutral }

class NewsArticle {
  final String id;
  final String headline;
  final String summary;
  final String source;
  final String affectedPairs;     // e.g. 'EUR, USD'
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Mock data — replace with NewsAPI + Forex Factory feeds
// ─────────────────────────────────────────────────────────────────────────────
final _now = DateTime.now();

final _kArticles = <NewsArticle>[
  NewsArticle(
    id: 'n1',
    headline: 'ECB Holds Rates at 4.5% — Signals Patience Before Any Cut',
    summary: 'The European Central Bank kept its key rate unchanged for the second consecutive meeting. '
        'President Lagarde emphasised the need for more evidence that inflation is durably '
        'returning to the 2% target before any easing. EUR strengthened on the decision.',
    source: 'Reuters',
    affectedPairs: 'EUR, USD, GBP',
    impact: NewsImpact.high,
    sentiment: NewsSentiment.bullish,
    publishedAt: _now.subtract(const Duration(minutes: 18)),
  ),
  NewsArticle(
    id: 'n2',
    headline: 'US CPI Prints Below Forecast — Dollar Slides on Rate-Cut Hopes',
    summary: 'US Consumer Price Index for February came in at 2.8% year-on-year, '
        'below the 3.1% consensus estimate. Core CPI also surprised to the downside at 3.1%. '
        'Markets now price 3 Fed cuts in 2025, up from 2 cuts prior to the print.',
    source: 'Bloomberg',
    affectedPairs: 'USD, EUR, JPY',
    impact: NewsImpact.high,
    sentiment: NewsSentiment.bearish,
    publishedAt: _now.subtract(const Duration(hours: 1, minutes: 45)),
  ),
  NewsArticle(
    id: 'n3',
    headline: 'Bank of Japan Holds Steady — JPY Weakens as Rate Differential Widens',
    summary: 'The BoJ maintained ultra-loose monetary policy citing fragile economic recovery. '
        'USD/JPY climbed past the 150 handle as the rate differential between the US and Japan '
        'reached its widest point since November. Intervention risk remains elevated.',
    source: 'Nikkei',
    affectedPairs: 'JPY, USD',
    impact: NewsImpact.high,
    sentiment: NewsSentiment.bearish,
    publishedAt: _now.subtract(const Duration(hours: 3)),
  ),
  NewsArticle(
    id: 'n4',
    headline: 'UK Services PMI Contracts — Sterling Under Pressure',
    summary: 'The UK Services PMI fell to 48.6 in February, entering contraction territory '
        'for the first time in four months. Weak consumer demand and rising wage costs '
        'were cited as primary headwinds. GBP/USD dropped 40 pips on the release.',
    source: 'FT',
    affectedPairs: 'GBP, EUR',
    impact: NewsImpact.medium,
    sentiment: NewsSentiment.bearish,
    publishedAt: _now.subtract(const Duration(hours: 4, minutes: 30)),
  ),
  NewsArticle(
    id: 'n5',
    headline: 'RBA Rate Decision Due Tomorrow — Markets Split on Outcome',
    summary: 'The Reserve Bank of Australia is set to announce its rate decision. '
        'A narrow majority of economists polled expect a hold at 4.35%, but '
        'a significant minority see a 25bp cut following softer inflation data. '
        'AUD/USD is range-bound ahead of the event.',
    source: 'AFR',
    affectedPairs: 'AUD, NZD',
    impact: NewsImpact.high,
    sentiment: NewsSentiment.neutral,
    publishedAt: _now.subtract(const Duration(hours: 6)),
  ),
  NewsArticle(
    id: 'n6',
    headline: 'Oil Prices Drop 2% on Rising US Inventories — CAD Weakens',
    summary: 'WTI crude fell 2.1% after the EIA reported a larger-than-expected '
        'build in US crude stockpiles of 5.2 million barrels. '
        'As a commodity-linked currency, the Canadian dollar tracked crude lower. '
        'USD/CAD testing resistance at 1.3680.',
    source: 'Reuters',
    affectedPairs: 'CAD, USD',
    impact: NewsImpact.medium,
    sentiment: NewsSentiment.bearish,
    publishedAt: _now.subtract(const Duration(hours: 7, minutes: 15)),
  ),
];

final _kEvents = <EconomicEvent>[
  EconomicEvent(
    id: 'e1',
    title: 'US Non-Farm Payrolls',
    country: 'United States',
    currency: 'USD',
    impact: NewsImpact.high,
    scheduledAt: _now.add(const Duration(hours: 2, minutes: 30)),
    forecast: '185K',
    previous: '199K',
    isUpcoming: true,
  ),
  EconomicEvent(
    id: 'e2',
    title: 'US Unemployment Rate',
    country: 'United States',
    currency: 'USD',
    impact: NewsImpact.high,
    scheduledAt: _now.add(const Duration(hours: 2, minutes: 30)),
    forecast: '3.7%',
    previous: '3.7%',
    isUpcoming: true,
  ),
  EconomicEvent(
    id: 'e3',
    title: 'RBA Interest Rate Decision',
    country: 'Australia',
    currency: 'AUD',
    impact: NewsImpact.high,
    scheduledAt: _now.add(const Duration(hours: 18)),
    forecast: '4.35%',
    previous: '4.35%',
    isUpcoming: true,
  ),
  EconomicEvent(
    id: 'e4',
    title: 'UK GDP (MoM)',
    country: 'United Kingdom',
    currency: 'GBP',
    impact: NewsImpact.medium,
    scheduledAt: _now.subtract(const Duration(hours: 2)),
    forecast: '0.1%',
    previous: '0.0%',
    actual: '0.0%',
    isUpcoming: false,
  ),
  EconomicEvent(
    id: 'e5',
    title: 'Eurozone CPI (Final)',
    country: 'Eurozone',
    currency: 'EUR',
    impact: NewsImpact.medium,
    scheduledAt: _now.subtract(const Duration(hours: 5)),
    forecast: '2.6%',
    previous: '2.8%',
    actual: '2.6%',
    isUpcoming: false,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────
class NewsEventsProvider extends ChangeNotifier {
  List<NewsArticle> _articles = [];
  List<EconomicEvent> _events = [];
  bool _isLoading = false;
  String _tab = 'News';           // News | Calendar
  String _impactFilter = 'All';  // All | High | Medium | Low
  String _sentimentFilter = 'All'; // All | Bullish | Bearish | Neutral

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

  void setTab(String t) { _tab = t; notifyListeners(); }
  void setImpactFilter(String f) { _impactFilter = f; notifyListeners(); }
  void setSentimentFilter(String f) { _sentimentFilter = f; notifyListeners(); }

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
    await Future.delayed(const Duration(milliseconds: 700));
    _articles = List.from(_kArticles);
    _events = List.from(_kEvents);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async { await init(); }

  // ── TODO: replace with real feeds ────────────────────────────────────────
  // Future<void> _fetchNews() async {
  //   final resp = await http.get(Uri.parse(
  //       'https://newsapi.org/v2/everything?q=forex+EUR+USD&apiKey=$newsApiKey'));
  //   _articles = NewsArticle.fromNewsApiList(json.decode(resp.body)['articles']);
  // }
  // Future<void> _fetchCalendar() async {
  //   // Forex Factory calendar RSS or scraped JSON
  // }
}