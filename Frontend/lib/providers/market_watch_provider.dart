// lib/providers/market_watch_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// Model — identical to your existing PairQuote so all UI widgets still compile
// ─────────────────────────────────────────────────────────────────────────────
class PairQuote {
  final String symbol;          // EUR/USD  (slash format — matches your UI)
  final String base;
  final String quote;
  final double bid;
  final double ask;
  final double changePercent;
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

  // Build from backend response (uses EUR_USD format — we convert to EUR/USD)
  factory PairQuote.fromBackend(
    Map<String, dynamic> json, {
    bool isFavourite = false,
    double changePercent = 0.0,
    double high24h = 0.0,
    double low24h = 0.0,
  }) {
    final instrument = json['instrument'] as String; // EUR_USD
    final parts      = instrument.split('_');
    final slashSymbol = instrument.replaceAll('_', '/'); // EUR/USD

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
      updatedAt:     DateTime.tryParse(json['timestamp'] as String? ?? '') ??
                     DateTime.now(),
    );
  }

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
        symbol:        symbol,
        base:          base,
        quote:         quote,
        bid:           bid ?? this.bid,
        ask:           ask ?? this.ask,
        changePercent: changePercent ?? this.changePercent,
        high24h:       high24h ?? this.high24h,
        low24h:        low24h ?? this.low24h,
        spread:        (ask ?? this.ask) - (bid ?? this.bid),
        isFavourite:   isFavourite ?? this.isFavourite,
        updatedAt:     updatedAt ?? this.updatedAt,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Favourites & change% are not returned by Twelve Data free tier.
// We persist them locally per session so they survive polling refreshes.
// ─────────────────────────────────────────────────────────────────────────────
const _defaultFavourites = {'EUR/USD', 'GBP/USD', 'USD/JPY'};

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────
class MarketWatchProvider extends ChangeNotifier {
  List<PairQuote> _quotes = [];
  bool _isLoading          = false;
  String? _error;
  String _filter           = 'All';
  String _searchQuery      = '';
  Timer? _ticker;
  bool _disposed           = false;

  // Session state — survives between polls
  final Map<String, bool>   _favourites     = {};
  final Map<String, double> _changePercents = {};
  final Map<String, double> _high24h        = {};
  final Map<String, double> _low24h         = {};

  // ── Public getters ────────────────────────────────────────────────────────
  List<PairQuote> get quotes   => _filtered;
  bool   get isLoading         => _isLoading;
  String? get error            => _error;
  String get filter            => _filter;
  int get bullishCount => _quotes.where((q) => q.isBullish).length;
  int get bearishCount => _quotes.where((q) => !q.isBullish).length;
  bool get hasLiveData => _quotes.isNotEmpty && _error == null;

  List<PairQuote> get _filtered {
    var list = [..._quotes];
    if (_searchQuery.isNotEmpty) {
      list = list
          .where((q) =>
              q.symbol.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    switch (_filter) {
      case 'Favourites':
        list = list.where((q) => q.isFavourite).toList();
        break;
      case 'Bullish':
        list = list.where((q) => q.isBullish).toList();
        break;
      case 'Bearish':
        list = list.where((q) => !q.isBullish).toList();
        break;
    }
    return list;
  }

  void setFilter(String f) { _filter = f;      notifyListeners(); }
  void setSearch(String q) { _searchQuery = q;  notifyListeners(); }

  void toggleFavourite(String symbol) {
    _favourites[symbol] = !(_favourites[symbol] ?? false);
    _quotes = _quotes
        .map((q) => q.symbol == symbol
            ? q.copyWith(isFavourite: _favourites[symbol])
            : q)
        .toList();
    notifyListeners();
  }

  // ── Backend URL ───────────────────────────────────────────────────────────
  static String get _baseUrl => kDebugMode
      ? 'http://localhost:8000'
      : 'https://forex-backend-production-bc44.up.railway.app';

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    _isLoading = true;
    _error     = null;
    notifyListeners();

    // Seed favourites for first run
    for (final sym in _defaultFavourites) {
      _favourites.putIfAbsent(sym, () => true);
    }

    await _fetchFromBackend();
    _startPolling();
  }

  // ── Polling ───────────────────────────────────────────────────────────────
  void _startPolling() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_disposed) _fetchFromBackend();
    });
  }

  // ── Fetch from /api/v1/market/prices ─────────────────────────────────────
  Future<void> _fetchFromBackend() async {
    if (_disposed) return;

    try {
      final uri = Uri.parse(
        '$_baseUrl/api/v1/market/prices'
        '?pairs=EUR_USD,GBP_USD,USD_JPY,AUD_USD,USD_CAD,USD_CHF,NZD_USD,EUR_GBP,EUR_JPY,GBP_JPY',
      );

      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 6));

      if (_disposed) return;

      if (response.statusCode == 200) {
        final json  = jsonDecode(response.body) as Map<String, dynamic>;
        final raw   = json['prices'] as List<dynamic>? ?? [];

        // Update 24h high/low from live mid prices
        for (final item in raw) {
          final data   = item as Map<String, dynamic>;
          final instr  = data['instrument'] as String;  // EUR_USD
          final symbol = instr.replaceAll('_', '/');    // EUR/USD
          final mid    = (data['mid'] as num).toDouble();

          // Track intraday high/low
          _high24h[symbol] = _high24h.containsKey(symbol)
              ? (_high24h[symbol]! > mid ? _high24h[symbol]! : mid)
              : mid * 1.003;
          _low24h[symbol] = _low24h.containsKey(symbol)
              ? (_low24h[symbol]! < mid ? _low24h[symbol]! : mid)
              : mid * 0.997;

          // Derive changePercent from high/low range (approximation until
          // you integrate a /quote endpoint for real 24h change data)
          final range = _high24h[symbol]! - _low24h[symbol]!;
          final fromOpen = mid - _low24h[symbol]!;
          _changePercents[symbol] =
              range > 0 ? ((fromOpen / range) * 2 - 1) * 0.5 : 0.0;
        }

        _quotes = raw.map((item) {
          final data   = item as Map<String, dynamic>;
          final instr  = data['instrument'] as String;
          final symbol = instr.replaceAll('_', '/');
          return PairQuote.fromBackend(
            data,
            isFavourite:   _favourites[symbol] ?? false,
            changePercent: _changePercents[symbol] ?? 0.0,
            high24h:       _high24h[symbol] ?? 0.0,
            low24h:        _low24h[symbol]  ?? 0.0,
          );
        }).toList();

        _error = null;
      } else if (response.statusCode == 503) {
        _error = 'Market data temporarily unavailable';
      } else {
        _error = 'Server error: ${response.statusCode}';
      }
    } on TimeoutException {
      _error = 'Request timed out — retrying...';
    } catch (e) {
      _error = 'Connection error: $e';
    } finally {
      if (!_disposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refresh() => _fetchFromBackend();

  // ── Lookup ────────────────────────────────────────────────────────────────
  PairQuote? quoteFor(String symbol) {
    try {
      return _quotes.firstWhere((q) => q.symbol == symbol);
    } catch (_) {
      return null;
    }
  }

  // ── Dispose ───────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    super.dispose();
  }
}