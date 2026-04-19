// lib/providers/trade_signals_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

enum SignalType { buy, sell, hold }
enum SignalStatus { active, triggered, expired }

// ── Model ─────────────────────────────────────────────────────────────────────

class TradeSignal {
  final String id;
  final String symbol;         // slash format: EUR/USD
  final SignalType type;
  final int confidence;        // 0–100
  final double entryPrice;
  final double stopLoss;
  final double takeProfit;
  final String explanation;
  final String timeframe;
  final SignalStatus status;
  final DateTime generatedAt;
  final List<String> reasonTags;
  // Phase 4 fields
  final List<String> indicatorTags;
  final String? technicalBias;
  final double? rsi;
  final String? macdBias;
  final String? explainSimple;
  final String? explainStandard;
  final String? explainAdvanced;
  // Whether this signal came from live Gemini AI or the fallback engine
  final bool isAiFallback;

  const TradeSignal({
    required this.id,
    required this.symbol,
    required this.type,
    required this.confidence,
    required this.entryPrice,
    required this.stopLoss,
    required this.takeProfit,
    required this.explanation,
    required this.timeframe,
    required this.status,
    required this.generatedAt,
    required this.reasonTags,
    this.indicatorTags = const [],
    this.technicalBias,
    this.rsi,
    this.macdBias,
    this.explainSimple,
    this.explainStandard,
    this.explainAdvanced,
    this.isAiFallback = false,
  });

  // ── Computed getters ────────────────────────────────────────────────────────

  double get riskReward =>
      (takeProfit - entryPrice).abs() /
      ((entryPrice - stopLoss).abs().clamp(0.00001, double.infinity));

  double get pipRisk =>
      (entryPrice - stopLoss).abs() * (symbol.contains('JPY') ? 100 : 10000);

  double get pipTarget =>
      (takeProfit - entryPrice).abs() * (symbol.contains('JPY') ? 100 : 10000);

  // ── Factory ─────────────────────────────────────────────────────────────────

  factory TradeSignal.fromBackend(Map<String, dynamic> json) {
    final actionStr = (json['action'] as String? ?? 'hold').toLowerCase();
    final type = actionStr == 'buy'
        ? SignalType.buy
        : actionStr == 'sell'
            ? SignalType.sell
            : SignalType.hold;

    final confidence = ((json['confidence'] as num? ?? 0.5) * 100).round();
    final sentiment  = json['sentiment'] as String? ?? 'neutral';
    final reasoning  = json['reasoning'] as String? ?? '';
    final newsSummary = json['news_summary'] as String? ?? '';

    // Detect fallback signals from the backend
    final isFallback = reasoning.toLowerCase().contains('unavailable') ||
        reasoning.toLowerCase().contains('default hold') ||
        (json['model'] as String? ?? '').isEmpty;

    final explanation = !isFallback && reasoning.isNotEmpty
        ? (newsSummary.isNotEmpty ? '$reasoning\n\n$newsSummary' : reasoning)
        : newsSummary.isNotEmpty && !newsSummary.contains('No news')
            ? newsSummary
            : 'Technical signal from live market data. Upgrade Gemini API key for full AI analysis.';

    final sentimentLabel = sentiment.isNotEmpty
        ? sentiment[0].toUpperCase() + sentiment.substring(1)
        : 'Neutral';

    final tags = <String>[sentimentLabel, 'Live Signal', 'Twelve Data'];
    if (isFallback) tags.add('Fallback');

    return TradeSignal(
      id:           '${json['pair']}_${json['generated_at']}',
      symbol:       (json['pair'] as String? ?? '').replaceAll('_', '/'),
      type:         type,
      confidence:   confidence,
      entryPrice:   (json['entry_price'] as num? ?? 0).toDouble(),
      stopLoss:     (json['stop_loss']   as num? ?? 0).toDouble(),
      takeProfit:   (json['take_profit'] as num? ?? 0).toDouble(),
      explanation:  explanation,
      timeframe:    'H1',
      status:       SignalStatus.active,
      generatedAt:  DateTime.tryParse(json['generated_at'] as String? ?? '') ??
                    DateTime.now(),
      reasonTags:   tags,
      indicatorTags: (json['indicator_tags'] as List? ?? []).cast<String>(),
      technicalBias: json['technical_bias'] as String?,
      rsi:           (json['rsi'] as num?)?.toDouble(),
      macdBias:      json['macd_bias'] as String?,
      explainSimple:   json['explain_simple']   as String?,
      explainStandard: json['explain_standard'] as String?,
      explainAdvanced: json['explain_advanced'] as String?,
      isAiFallback:  isFallback,
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

// Signals are refreshed every 5 minutes.
// Twelve Data free tier: 800 req/day — signals endpoint calls prices internally,
// so 5 min interval = ~288 signal calls/day, well within budget.
const _signalPollInterval = Duration(minutes: 5);

const _defaultPairs = ['EUR_USD', 'GBP_USD', 'USD_JPY'];

class TradeSignalsProvider extends ChangeNotifier {
  final ApiService _api;
  TradeSignalsProvider(this._api);

  // ── State ───────────────────────────────────────────────────────────────────

  List<TradeSignal> _signals   = [];
  bool              _isLoading = false;
  String?           _error;
  String            _filter    = 'All';
  DateTime?         _lastFetch;
  Timer?            _ticker;
  bool              _disposed  = false;
  final Set<String> _expanded  = {};

  // ── Public getters ──────────────────────────────────────────────────────────

  List<TradeSignal> get signals    => _filtered;
  bool              get isLoading  => _isLoading;
  String?           get error      => _error;
  String            get filter     => _filter;
  DateTime?         get lastFetch  => _lastFetch;

  int get buyCount  => _signals.where((s) => s.type == SignalType.buy).length;
  int get sellCount => _signals.where((s) => s.type == SignalType.sell).length;
  int get holdCount => _signals.where((s) => s.type == SignalType.hold).length;

  /// True when Gemini AI is unavailable and signals are from the fallback engine.
  bool get isAiFallback =>
      _signals.isNotEmpty && _signals.every((s) => s.isAiFallback);

  bool get hasSignals => _signals.isNotEmpty;

  bool isExpanded(String id) => _expanded.contains(id);

  void toggleExpanded(String id) {
    _expanded.contains(id) ? _expanded.remove(id) : _expanded.add(id);
    notifyListeners();
  }

  // ── Filters ─────────────────────────────────────────────────────────────────

  void setFilter(String f) {
    _filter = f;
    notifyListeners();
  }

  List<TradeSignal> get _filtered => switch (_filter) {
        'Buy'       => _signals.where((s) => s.type == SignalType.buy).toList(),
        'Sell'      => _signals.where((s) => s.type == SignalType.sell).toList(),
        'Hold'      => _signals.where((s) => s.type == SignalType.hold).toList(),
        'Active'    => _signals.where((s) => s.status == SignalStatus.active).toList(),
        'Triggered' => _signals.where((s) => s.status == SignalStatus.triggered).toList(),
        _           => [..._signals],
      };

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  /// Called from main.dart MultiProvider create. Safe to call multiple times.
  Future<void> init() async {
    if (_ticker != null) return; // already initialised
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
    _ticker = Timer.periodic(_signalPollInterval, (_) {
      if (!_disposed) _fetch();
    });
  }

  // ── Fetch ────────────────────────────────────────────────────────────────────

  Future<void> _fetch() async {
    if (_disposed) return;
    _isLoading = true;
    _error     = null;
    notifyListeners();

    try {
      final raw = await _api.fetchLiveSignals(pairs: _defaultPairs);

      if (_disposed) return;

      if (raw.isNotEmpty) {
        _signals    = raw.map((j) => TradeSignal.fromBackend(j)).toList();
        _lastFetch  = DateTime.now();
        _error      = null;
      } else {
        // Keep stale signals visible rather than showing empty state
        if (_signals.isEmpty) {
          _error = 'No signals returned — retrying in ${_signalPollInterval.inMinutes} min';
        }
        if (kDebugMode) debugPrint('TradeSignalsProvider: empty response');
      }
    } catch (e) {
      if (!_disposed) {
        _error = e.toString();
        if (kDebugMode) debugPrint('TradeSignalsProvider API error: $e');
      }
    } finally {
      if (!_disposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Returns the signal for a specific pair (slash format e.g. "EUR/USD"), or null.
  TradeSignal? signalFor(String symbol) {
    try {
      return _signals.firstWhere((s) => s.symbol == symbol);
    } catch (_) {
      return null;
    }
  }
}

