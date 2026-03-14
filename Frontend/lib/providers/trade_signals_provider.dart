// lib/providers/trade_signals_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums & Model
// ─────────────────────────────────────────────────────────────────────────────
enum SignalType { buy, sell, hold }

enum SignalStatus { active, triggered, expired }

class TradeSignal {
  final String id;
  final String symbol;
  final SignalType type;
  final int confidence;          // 0–100
  final double entryPrice;
  final double stopLoss;
  final double takeProfit;
  final String explanation;      // plain-English AI reasoning
  final String timeframe;
  final SignalStatus status;
  final DateTime generatedAt;
  final List<String> reasonTags; // e.g. ['ECB Hawkish', 'RSI Oversold']

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
  });

  double get riskReward =>
      (takeProfit - entryPrice).abs() / (entryPrice - stopLoss).abs();

  double get pipRisk =>
      (entryPrice - stopLoss).abs() * (symbol.contains('JPY') ? 100 : 10000);

  double get pipTarget =>
      (takeProfit - entryPrice).abs() * (symbol.contains('JPY') ? 100 : 10000);
}

// ─────────────────────────────────────────────────────────────────────────────
// Mock signals — replace _fetchSignals() with backend /signals endpoint
// ─────────────────────────────────────────────────────────────────────────────
final _kMockSignals = <TradeSignal>[
  TradeSignal(
    id: 's1',
    symbol: 'EUR/USD',
    type: SignalType.buy,
    confidence: 78,
    entryPrice: 1.08460,
    stopLoss: 1.08120,
    takeProfit: 1.09140,
    timeframe: 'H4',
    status: SignalStatus.active,
    generatedAt: DateTime.now().subtract(const Duration(minutes: 12)),
    reasonTags: ['ECB Hawkish', 'RSI Oversold', 'EMA Cross'],
    explanation:
        'ECB held rates at 4.5% while market expected a cut — EUR bullish. '
        'US CPI printed below forecast at 2.8%, weakening USD. '
        'Price broke above the 20-EMA on H4 with volume confirmation. '
        'Risk/reward of 2.0 with 61% modelled win probability.',
  ),
  TradeSignal(
    id: 's2',
    symbol: 'GBP/USD',
    type: SignalType.sell,
    confidence: 65,
    entryPrice: 1.27310,
    stopLoss: 1.27620,
    takeProfit: 1.26520,
    timeframe: 'H1',
    status: SignalStatus.active,
    generatedAt: DateTime.now().subtract(const Duration(minutes: 31)),
    reasonTags: ['UK PMI Miss', 'MACD Bearish', 'Resistance Rejected'],
    explanation:
        'UK Services PMI came in at 48.6, below the 50 contraction line. '
        'Price tested the 1.2760 resistance zone three times and failed. '
        'MACD histogram turning negative on H1. '
        'Sentiment skews 62% bearish on GBP across news feeds this hour.',
  ),
  TradeSignal(
    id: 's3',
    symbol: 'USD/JPY',
    type: SignalType.buy,
    confidence: 82,
    entryPrice: 149.880,
    stopLoss: 149.420,
    takeProfit: 150.940,
    timeframe: 'H4',
    status: SignalStatus.active,
    generatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
    reasonTags: ['BoJ Dovish', 'US Yields Rising', 'Trend Continuation'],
    explanation:
        'Bank of Japan held policy unchanged, reinforcing its dovish stance. '
        'US 10-year yields rose 4 bps, widening the rate differential. '
        'Price structure shows higher lows since 148.50 — uptrend intact. '
        'Institutional COT data shows net long USD positioning at 3-month high.',
  ),
  TradeSignal(
    id: 's4',
    symbol: 'AUD/USD',
    type: SignalType.hold,
    confidence: 41,
    entryPrice: 0.65240,
    stopLoss: 0.64900,
    takeProfit: 0.65800,
    timeframe: 'D1',
    status: SignalStatus.active,
    generatedAt: DateTime.now().subtract(const Duration(hours: 2)),
    reasonTags: ['RBA Decision Pending', 'Mixed Indicators', 'Low Conviction'],
    explanation:
        'RBA rate decision due in 4 hours — conflicting signals present. '
        'Technical indicators split: RSI neutral at 52, MACD flat. '
        'News sentiment is balanced (51% bullish, 49% bearish on AUD). '
        'Recommended to wait for post-RBA clarity before entering.',
  ),
  TradeSignal(
    id: 's5',
    symbol: 'EUR/GBP',
    type: SignalType.sell,
    confidence: 71,
    entryPrice: 0.85225,
    stopLoss: 0.85480,
    takeProfit: 0.84680,
    timeframe: 'H1',
    status: SignalStatus.triggered,
    generatedAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 15)),
    reasonTags: ['EUR Weakness', 'GBP Rebound', 'Double Top'],
    explanation:
        'EUR/GBP formed a clear double top at 0.8548 on the H1 chart. '
        'EUR is showing relative weakness after GDP revision came in soft. '
        'GBP bounced on better-than-expected retail sales data (+0.4%). '
        'Signal triggered — monitoring position at entry.',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────
class TradeSignalsProvider extends ChangeNotifier {
  List<TradeSignal> _signals = [];
  bool _isLoading = false;
  String? _error;
  String _filter = 'All';     // All | Buy | Sell | Hold | Active | Triggered
  Set<String> _expanded = {};

  List<TradeSignal> get signals => _filtered;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get filter => _filter;
  int get buyCount  => _signals.where((s) => s.type == SignalType.buy).length;
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
      case 'Buy':       return _signals.where((s) => s.type == SignalType.buy).toList();
      case 'Sell':      return _signals.where((s) => s.type == SignalType.sell).toList();
      case 'Hold':      return _signals.where((s) => s.type == SignalType.hold).toList();
      case 'Active':    return _signals.where((s) => s.status == SignalStatus.active).toList();
      case 'Triggered': return _signals.where((s) => s.status == SignalStatus.triggered).toList();
      default:          return [..._signals];
    }
  }

  void setFilter(String f) { _filter = f; notifyListeners(); }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 900));
    _signals = List.from(_kMockSignals);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    await init();
  }

  // ── TODO: replace with real backend call ─────────────────────────────────
  // Future<void> _fetchSignals() async {
  //   final resp = await apiService.get('/signals/latest');
  //   _signals = (resp['signals'] as List).map(TradeSignal.fromJson).toList();
  // }
}