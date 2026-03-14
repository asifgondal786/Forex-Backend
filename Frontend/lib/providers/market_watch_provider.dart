// lib/providers/market_watch_provider.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────
class PairQuote {
  final String symbol;
  final String base;
  final String quote;
  final double bid;
  final double ask;
  final double changePercent;   // 24-h % change
  final double high24h;
  final double low24h;
  final double spread;
  final bool isFavourite;
  final DateTime updatedAt;

  const PairQuote({
    required this.symbol,
    required this.base,
    required this.quote,
    required this.bid,
    required this.ask,
    required this.changePercent,
    required this.high24h,
    required this.low24h,
    required this.spread,
    required this.isFavourite,
    required this.updatedAt,
  });

  double get mid => (bid + ask) / 2;
  bool get isBullish => changePercent >= 0;

  PairQuote copyWith({
    double? bid,
    double? ask,
    double? changePercent,
    double? high24h,
    double? low24h,
    bool? isFavourite,
    DateTime? updatedAt,
  }) =>
      PairQuote(
        symbol: symbol,
        base: base,
        quote: quote,
        bid: bid ?? this.bid,
        ask: ask ?? this.ask,
        changePercent: changePercent ?? this.changePercent,
        high24h: high24h ?? this.high24h,
        low24h: low24h ?? this.low24h,
        spread: (ask ?? this.ask) - (bid ?? this.bid),
        isFavourite: isFavourite ?? this.isFavourite,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Seed data — swap _fetchLive() for real OANDA v20 call later
// ─────────────────────────────────────────────────────────────────────────────
final _kSeedQuotes = <PairQuote>[
  PairQuote(symbol: 'EUR/USD', base: 'EUR', quote: 'USD', bid: 1.08452, ask: 1.08468, changePercent: 0.23, high24h: 1.08720, low24h: 1.08110, spread: 0.00016, isFavourite: true,  updatedAt: DateTime.now()),
  PairQuote(symbol: 'GBP/USD', base: 'GBP', quote: 'USD', bid: 1.27310, ask: 1.27334, changePercent: -0.41, high24h: 1.27890, low24h: 1.27150, spread: 0.00024, isFavourite: true,  updatedAt: DateTime.now()),
  PairQuote(symbol: 'USD/JPY', base: 'USD', quote: 'JPY', bid: 149.862, ask: 149.884, changePercent: 0.08, high24h: 150.120, low24h: 149.530, spread: 0.022,   isFavourite: true,  updatedAt: DateTime.now()),
  PairQuote(symbol: 'AUD/USD', base: 'AUD', quote: 'USD', bid: 0.65234, ask: 0.65252, changePercent: -0.17, high24h: 0.65520, low24h: 0.65100, spread: 0.00018, isFavourite: false, updatedAt: DateTime.now()),
  PairQuote(symbol: 'USD/CAD', base: 'USD', quote: 'CAD', bid: 1.36480, ask: 1.36502, changePercent: 0.31, high24h: 1.36750, low24h: 1.36200, spread: 0.00022, isFavourite: false, updatedAt: DateTime.now()),
  PairQuote(symbol: 'USD/CHF', base: 'USD', quote: 'CHF', bid: 0.90124, ask: 0.90140, changePercent: -0.09, high24h: 0.90380, low24h: 0.89980, spread: 0.00016, isFavourite: false, updatedAt: DateTime.now()),
  PairQuote(symbol: 'NZD/USD', base: 'NZD', quote: 'USD', bid: 0.60342, ask: 0.60360, changePercent: 0.54, high24h: 0.60680, low24h: 0.60100, spread: 0.00018, isFavourite: false, updatedAt: DateTime.now()),
  PairQuote(symbol: 'EUR/GBP', base: 'EUR', quote: 'GBP', bid: 0.85220, ask: 0.85238, changePercent: -0.12, high24h: 0.85450, low24h: 0.85080, spread: 0.00018, isFavourite: false, updatedAt: DateTime.now()),
  PairQuote(symbol: 'EUR/JPY', base: 'EUR', quote: 'JPY', bid: 162.480, ask: 162.510, changePercent: 0.29, high24h: 162.950, low24h: 162.100, spread: 0.030,   isFavourite: false, updatedAt: DateTime.now()),
  PairQuote(symbol: 'GBP/JPY', base: 'GBP', quote: 'JPY', bid: 190.110, ask: 190.148, changePercent: -0.33, high24h: 190.780, low24h: 189.820, spread: 0.038,   isFavourite: false, updatedAt: DateTime.now()),
];

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────
class MarketWatchProvider extends ChangeNotifier {
  List<PairQuote> _quotes = [];
  bool _isLoading = false;
  String? _error;
  String _filter = 'All';           // All | Favourites | Bullish | Bearish
  String _searchQuery = '';
  Timer? _ticker;
  final _rng = Random();

  List<PairQuote> get quotes => _filtered;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get filter => _filter;
  int get bullishCount => _quotes.where((q) => q.isBullish).length;
  int get bearishCount => _quotes.where((q) => !q.isBullish).length;

  List<PairQuote> get _filtered {
    var list = [..._quotes];
    if (_searchQuery.isNotEmpty) {
      list = list.where((q) =>
          q.symbol.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    switch (_filter) {
      case 'Favourites': list = list.where((q) => q.isFavourite).toList(); break;
      case 'Bullish':    list = list.where((q) => q.isBullish).toList();   break;
      case 'Bearish':    list = list.where((q) => !q.isBullish).toList();  break;
    }
    return list;
  }

  void setFilter(String f)      { _filter = f;       notifyListeners(); }
  void setSearch(String q)      { _searchQuery = q;  notifyListeners(); }

  void toggleFavourite(String symbol) {
    _quotes = _quotes.map((q) => q.symbol == symbol
        ? q.copyWith(isFavourite: !q.isFavourite) : q).toList();
    notifyListeners();
  }

  // ── Init & dispose ───────────────────────────────────────────────────────
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 800)); // simulate fetch
    _quotes = List.from(_kSeedQuotes);
    _isLoading = false;
    notifyListeners();
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    // Simulate price ticks every 2 s
    _ticker = Timer.periodic(const Duration(seconds: 2), (_) => _tick());
  }

  void _tick() {
    _quotes = _quotes.map((q) {
      final noise = (_rng.nextDouble() - 0.5) * 0.00030;
      final newBid = q.bid + noise;
      final newAsk = newBid + q.spread;
      final newChange = q.changePercent + (_rng.nextDouble() - 0.5) * 0.05;
      return q.copyWith(
        bid: newBid,
        ask: newAsk,
        changePercent: newChange,
        updatedAt: DateTime.now(),
      );
    }).toList();
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // ── TODO: swap this for real OANDA v20 call ──────────────────────────────
  // Future<void> _fetchLive() async {
  //   final resp = await http.get(
  //     Uri.parse('https://api-fxtrade.oanda.com/v3/accounts/$accountId/pricing'
  //               '?instruments=${pairs.join('%2C')}'),
  //     headers: {'Authorization': 'Bearer $oandaKey'},
  //   );
  //   final data = json.decode(resp.body);
  //   _quotes = (data['prices'] as List).map(PairQuote.fromOanda).toList();
  // }
}