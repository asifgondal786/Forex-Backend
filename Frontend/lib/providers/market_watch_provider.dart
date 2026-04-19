// lib/providers/market_watch_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

// =============================================================================
// Model
// =============================================================================

/// A single pair quote as returned by /api/v1/market/prices (normalised).
/// All UI widgets that previously consumed PairQuote continue to compile
/// unchanged — field names and types are identical to the old version.
class PairQuote {
  final String symbol;        // slash format: EUR/USD
  final String base;          // EUR
  final String quote;         // USD
  final double bid;
  final double ask;
  final double changePercent; // approximate — derived from intraday range
  final double high24h;
  final double low24h;
  final double spread;        // in pips (pre-computed by backend)
  final bool isFavourite;
  final bool isFallback;      // true when data is synthetic (backend offline)
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
    required this.isFallback,
    required this.updatedAt,
  });

  double get mid        => (bid + ask) / 2;
  bool   get isBullish  => changePercent >= 0;
  bool   get isTradeable => !isFallback;

  /// Construct from a backend price item.
  /// Backend shape: { "instrument": "EUR_USD", "bid": 1.158, "ask": 1.159,
  ///                  "mid": 1.158, "spread": 1.0, "tradeable": true,
  ///                  "timestamp": "...", "source"?: "fallback" }
  factory PairQuote.fromBackend(
    Map<String, dynamic> json, {
    bool isFavourite      = false,
    double changePercent  = 0.0,
    double high24h        = 0.0,
    double low24h         = 0.0,
  }) {
    final instrument  = json['instrument'] as String;    // EUR_USD
    final parts       = instrument.split('_');
    final slashSymbol = instrument.replaceAll('_', '/'); // EUR/USD
    final fallback    = json['source'] == 'fallback' || json['tradeable'] == false;

    return PairQuote(
      symbol:        slashSymbol,
      base:          parts.isNotEmpty ? parts[0] : '',
      quote:         parts.length > 1 ? parts[1] : '',
      bid:           (json['bid']    as num).toDouble(),
      ask:           (json['ask']    as num).toDouble(),
      changePercent: changePercent,
      high24h:       high24h,
      low24h:        low24h,
      spread:        (json['spread'] as num).toDouble(),
      isFavourite:   isFavourite,
      isFallback:    fallback,
      updatedAt:     DateTime.tryParse(json['timestamp'] as String? ?? '') ??
                     DateTime.now(),
    );
  }

  PairQuote copyWith({
    double?   bid,
    double?   ask,
    double?   changePercent,
    double?   high24h,
    double?   low24h,
    bool?     isFavourite,
    bool?     isFallback,
    DateTime? updatedAt,
  }) =>
      PairQuote(
        symbol:        symbol,
        base:          base,
        quote:         quote,
        bid:           bid           ?? this.bid,
        ask:           ask           ?? this.ask,
        changePercent: changePercent ?? this.changePercent,
        high24h:       high24h       ?? this.high24h,
        low24h:        low24h        ?? this.low24h,
        spread:        ((ask ?? this.ask) - (bid ?? this.bid)).abs(),
        isFavourite:   isFavourite   ?? this.isFavourite,
        isFallback:    isFallback    ?? this.isFallback,
        updatedAt:     updatedAt     ?? this.updatedAt,
      );
}

// =============================================================================
// Provider
// =============================================================================

// Default pairs to pre-mark as favourites on first run.
const _defaultFavourites = {'EUR/USD', 'GBP/USD', 'USD/JPY'};

// Backend pairs to request (underscore notation).
// These 10 are confirmed supported by the backend / Twelve Data free tier.
// Expand only after verifying with:
//   Invoke-RestMethod ".../api/v1/market/prices?pairs=EUR_USD,AUD_USD,..."
const _defaultWatchedPairs = [
  'EUR_USD', 'GBP_USD', 'USD_JPY',
  'AUD_USD', 'USD_CAD', 'USD_CHF',
  'NZD_USD', 'EUR_GBP', 'EUR_JPY', 'GBP_JPY',
];

// 15 s keeps daily usage well within Twelve Data's 800 req/day free tier.
// (10 pairs × 86400 s/day ÷ 15 s/poll ≈ 576 requests/day — safe with headroom.)
const _pollInterval = Duration(seconds: 15);

class MarketWatchProvider extends ChangeNotifier {
  final ApiService _apiService;

  MarketWatchProvider({required ApiService apiService})
      : _apiService = apiService;

  // ── State ───────────────────────────────────────────────────────────────────

  List<PairQuote> _quotes   = [];
  bool            _loading  = false;
  String?         _error;
  String          _filter   = 'All';
  String          _search   = '';
  Timer?          _ticker;
  bool            _disposed = false;

  // Session-persistent state — survives between polls.
  final Map<String, bool>   _favourites     = {};
  final Map<String, double> _changePercents = {};
  final Map<String, double> _high24h        = {};
  final Map<String, double> _low24h         = {};

  // ── Public getters ──────────────────────────────────────────────────────────

  List<PairQuote> get quotes      => _applyFilters();
  bool            get isLoading   => _loading;
  String?         get error       => _error;
  String          get filter      => _filter;
  bool            get hasLiveData => _quotes.isNotEmpty && _error == null;
  bool            get isFallback  => _quotes.isNotEmpty && _quotes.first.isFallback;

  int get bullishCount => _quotes.where((q) => q.isBullish).length;
  int get bearishCount => _quotes.where((q) => !q.isBullish).length;

  // ── Filter / search ─────────────────────────────────────────────────────────

  void setFilter(String f) { _filter = f; notifyListeners(); }
  void setSearch(String q) { _search = q; notifyListeners(); }

  List<PairQuote> _applyFilters() {
    var list = [..._quotes];
    if (_search.isNotEmpty) {
      list = list.where(
        (q) => q.symbol.toLowerCase().contains(_search.toLowerCase()),
      ).toList();
    }
    return switch (_filter) {
      'Favourites' => list.where((q) => q.isFavourite).toList(),
      'Bullish'    => list.where((q) => q.isBullish).toList(),
      'Bearish'    => list.where((q) => !q.isBullish).toList(),
      _            => list,
    };
  }

  // ── Favourites ──────────────────────────────────────────────────────────────

  void toggleFavourite(String symbol) {
    _favourites[symbol] = !(_favourites[symbol] ?? false);
    _quotes = _quotes.map((q) =>
        q.symbol == symbol ? q.copyWith(isFavourite: _favourites[symbol]) : q
    ).toList();
    notifyListeners();
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  /// Call from initState / didChangeDependencies. Safe to call multiple times.
  Future<void> init() async {
    if (_ticker != null) return; // already initialised

    for (final sym in _defaultFavourites) {
      _favourites.putIfAbsent(sym, () => true);
    }

    _loading = true;
    notifyListeners();

    await _fetch();
    _startPolling();
  }

  Future<void> refresh() => _fetch();

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    super.dispose();
  }

  // ── Polling ──────────────────────────────────────────────────────────────────

  void _startPolling() {
    _ticker?.cancel();
    _ticker = Timer.periodic(_pollInterval, (_) {
      if (!_disposed) _fetch();
    });
  }

  // ── Fetch ────────────────────────────────────────────────────────────────────

  Future<void> _fetch() async {
    if (_disposed) return;

    try {
      final raw = await _apiService.fetchMarketPrices(pairs: _defaultWatchedPairs);
      if (_disposed) return;

      // Track intraday high/low from the live mid price.
      for (final item in raw) {
        final symbol = (item['instrument'] as String).replaceAll('_', '/');
        final mid    = (item['mid'] as num).toDouble();

        _high24h[symbol] = _high24h.containsKey(symbol)
            ? (_high24h[symbol]! > mid ? _high24h[symbol]! : mid)
            : mid * 1.003;
        _low24h[symbol] = _low24h.containsKey(symbol)
            ? (_low24h[symbol]! < mid ? _low24h[symbol]! : mid)
            : mid * 0.997;

        // Approximate changePercent from intraday range.
        // Replace with real 24h change once a /quote endpoint is available.
        final range    = _high24h[symbol]! - _low24h[symbol]!;
        final fromOpen = mid - _low24h[symbol]!;
        _changePercents[symbol] = range > 0 ? ((fromOpen / range) * 2 - 1) * 0.5 : 0.0;
      }

      _quotes = raw.map((item) {
        final symbol = (item['instrument'] as String).replaceAll('_', '/');
        return PairQuote.fromBackend(
          item,
          isFavourite:   _favourites[symbol] ?? false,
          changePercent: _changePercents[symbol] ?? 0.0,
          high24h:       _high24h[symbol] ?? 0.0,
          low24h:        _low24h[symbol]  ?? 0.0,
        );
      }).toList();

      _error = null;
    } catch (e) {
      if (!_disposed) _error = e.toString();
    } finally {
      if (!_disposed) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  // ── Lookup ───────────────────────────────────────────────────────────────────

  PairQuote? quoteFor(String symbol) {
    try {
      return _quotes.firstWhere((q) => q.symbol == symbol);
    } catch (_) {
      return null;
    }
  }
}

