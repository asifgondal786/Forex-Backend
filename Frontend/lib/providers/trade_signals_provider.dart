// lib/providers/trade_signals_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

enum SignalType { buy, sell, hold }
enum SignalStatus { active, triggered, expired }

class TradeSignal {
  final String id;
  final String symbol;
  final SignalType type;
  final int confidence;
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
  });

  double get riskReward =>
      (takeProfit - entryPrice).abs() / (entryPrice - stopLoss).abs();
  double get pipRisk =>
      (entryPrice - stopLoss).abs() * (symbol.contains('JPY') ? 100 : 10000);
  double get pipTarget =>
      (takeProfit - entryPrice).abs() * (symbol.contains('JPY') ? 100 : 10000);

  factory TradeSignal.fromBackend(Map<String, dynamic> json) {
    final actionStr = (json['action'] as String? ?? 'hold').toLowerCase();
    final type = actionStr == 'buy'
        ? SignalType.buy
        : actionStr == 'sell'
            ? SignalType.sell
            : SignalType.hold;
    final confidence = ((json['confidence'] as num? ?? 0.5) * 100).round();
    final sentiment = json['sentiment'] as String? ?? 'neutral';
    final reasoning = json['reasoning'] as String? ?? '';
    final newsSummary = json['news_summary'] as String? ?? '';
    final explanation = reasoning.isNotEmpty && !reasoning.contains('unavailable')
        ? '$reasoning\n\n$newsSummary'
        : newsSummary.isNotEmpty
            ? newsSummary
            : 'AI signal generated from live market data and price action.';
    final sentimentLabel = sentiment.isNotEmpty
        ? sentiment[0].toUpperCase() + sentiment.substring(1)
        : 'Neutral';
    return TradeSignal(
      id: '${json['pair']}_${json['generated_at']}',
      symbol: (json['pair'] as String? ?? '').replaceAll('_', '/'),
      type: type,
      confidence: confidence,
      entryPrice: (json['entry_price'] as num? ?? 0).toDouble(),
      stopLoss: (json['stop_loss'] as num? ?? 0).toDouble(),
      takeProfit: (json['take_profit'] as num? ?? 0).toDouble(),
      explanation: explanation,
      timeframe: 'H1',
      status: SignalStatus.active,
      generatedAt:
          DateTime.tryParse(json['generated_at'] as String? ?? '') ??
              DateTime.now(),
      reasonTags: [sentimentLabel, 'Live Signal', 'Twelve Data'],
      indicatorTags: (json['indicator_tags'] as List? ?? []).cast<String>(),
      technicalBias: json['technical_bias'] as String?,
      rsi: (json['rsi'] as num?)?.toDouble(),
      macdBias: json['macd_bias'] as String?,
      explainSimple: json['explain_simple'] as String?,
      explainStandard: json['explain_standard'] as String?,
      explainAdvanced: json['explain_advanced'] as String?,
    );
  }
}

class TradeSignalsProvider extends ChangeNotifier {
  final ApiService _api;
  TradeSignalsProvider(this._api);

  List<TradeSignal> _signals = [];
  bool _isLoading = false;
  String? _error;
  String _filter = 'All';
  final Set<String> _expanded = {};

  List<TradeSignal> get signals => _filtered;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get filter => _filter;
  int get buyCount => _signals.where((s) => s.type == SignalType.buy).length;
  int get sellCount => _signals.where((s) => s.type == SignalType.sell).length;
  int get holdCount => _signals.where((s) => s.type == SignalType.hold).length;
  bool isExpanded(String id) => _expanded.contains(id);

  void toggleExpanded(String id) {
    if (_expanded.contains(id)) {
      _expanded.remove(id);
    } else {
      _expanded.add(id);
    }
    notifyListeners();
  }

  List<TradeSignal> get _filtered {
    switch (_filter) {
      case 'Buy':
        return _signals.where((s) => s.type == SignalType.buy).toList();
      case 'Sell':
        return _signals.where((s) => s.type == SignalType.sell).toList();
      case 'Hold':
        return _signals.where((s) => s.type == SignalType.hold).toList();
      case 'Active':
        return _signals
            .where((s) => s.status == SignalStatus.active)
            .toList();
      case 'Triggered':
        return _signals
            .where((s) => s.status == SignalStatus.triggered)
            .toList();
      default:
        return [..._signals];
    }
  }

  void setFilter(String f) {
    _filter = f;
    notifyListeners();
  }

  Future<void> init() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final raw = await _api.fetchLiveSignals(
        pairs: ['EUR_USD', 'GBP_USD', 'USD_JPY'],
      );
      if (raw.isNotEmpty) {
        _signals = raw.map((j) => TradeSignal.fromBackend(j)).toList();
      } else {
        _error = 'No signals returned from backend';
      }
    } catch (e) {
      _error = 'Failed to load signals: $e';
      debugPrint(_error);
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async => init();
}