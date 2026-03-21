import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../services/api_service.dart';
import '../providers/trade_signals_provider.dart';

// ── Models ────────────────────────────────────────────────────────────────────

enum TradeDirection { buy, sell }
enum PaperTradeStatus { open, closed }

class PaperTrade {
  final String id;
  final String pair;
  final TradeDirection direction;
  final double entryPrice;
  final double stopLoss;
  final double takeProfit;
  final double lotSize;
  final DateTime openedAt;
  final PaperTradeStatus status;
  final double unrealizedPnl;
  final double? realizedPnl;
  final DateTime? closedAt;
  final String? closeReason;
  final String? reasoning;

  const PaperTrade({
    required this.id,
    required this.pair,
    required this.direction,
    required this.entryPrice,
    required this.stopLoss,
    required this.takeProfit,
    required this.lotSize,
    required this.openedAt,
    required this.status,
    this.unrealizedPnl = 0,
    this.realizedPnl,
    this.closedAt,
    this.closeReason,
    this.reasoning,
  });

  double get riskReward =>
      (takeProfit - entryPrice).abs() /
      ((entryPrice - stopLoss).abs().clamp(0.00001, double.infinity));

  factory PaperTrade.fromJson(Map<String, dynamic> json) {
    final dirStr = (json['direction'] as String? ?? 'BUY').toUpperCase();
    return PaperTrade(
      id:           json['id']?.toString() ?? '',
      pair:         json['pair'] as String? ?? '',
      direction:    dirStr == 'BUY' ? TradeDirection.buy : TradeDirection.sell,
      entryPrice:   (json['entry_price'] as num? ?? 0).toDouble(),
      stopLoss:     (json['stop_loss'] as num? ?? 0).toDouble(),
      takeProfit:   (json['take_profit'] as num? ?? 0).toDouble(),
      lotSize:      (json['lot_size'] as num? ?? 1000).toDouble(),
      openedAt:     DateTime.tryParse(json['opened_at'] as String? ?? '') ?? DateTime.now(),
      status:       (json['status'] as String?) == 'closed'
                      ? PaperTradeStatus.closed
                      : PaperTradeStatus.open,
      unrealizedPnl: (json['unrealized_pnl'] as num? ?? 0).toDouble(),
      realizedPnl:  (json['realized_pnl'] as num?)?.toDouble(),
      closedAt:     DateTime.tryParse(json['closed_at'] as String? ?? ''),
      closeReason:  json['close_reason'] as String?,
      reasoning:    json['reasoning'] as String?,
    );
  }
}

class PerformanceStats {
  final int totalTrades;
  final int wins;
  final int losses;
  final double winRate;
  final double totalPnl;
  final double avgPnlPerTrade;
  final double bestTrade;
  final double worstTrade;

  const PerformanceStats({
    this.totalTrades = 0,
    this.wins = 0,
    this.losses = 0,
    this.winRate = 0,
    this.totalPnl = 0,
    this.avgPnlPerTrade = 0,
    this.bestTrade = 0,
    this.worstTrade = 0,
  });

  factory PerformanceStats.fromJson(Map<String, dynamic> json) => PerformanceStats(
    totalTrades:    (json['total_trades'] as num? ?? 0).toInt(),
    wins:           (json['wins'] as num? ?? 0).toInt(),
    losses:         (json['losses'] as num? ?? 0).toInt(),
    winRate:        (json['win_rate'] as num? ?? 0).toDouble(),
    totalPnl:       (json['total_pnl'] as num? ?? 0).toDouble(),
    avgPnlPerTrade: (json['avg_pnl_per_trade'] as num? ?? 0).toDouble(),
    bestTrade:      (json['best_trade'] as num? ?? 0).toDouble(),
    worstTrade:     (json['worst_trade'] as num? ?? 0).toDouble(),
  );
}

// ── Provider ──────────────────────────────────────────────────────────────────

class PaperTradingProvider extends ChangeNotifier {
  final ApiService _api;
  PaperTradingProvider(this._api);

  List<PaperTrade> _openTrades = [];
  List<PaperTrade> _history = [];
  PerformanceStats _stats = const PerformanceStats();
  bool _isLoading = false;
  bool _isOpening = false;
  String? _error;
  String? _successMessage;

  List<PaperTrade> get openTrades => _openTrades;
  List<PaperTrade> get history => _history;
  PerformanceStats get stats => _stats;
  bool get isLoading => _isLoading;
  bool get isOpening => _isOpening;
  String? get error => _error;
  String? get successMessage => _successMessage;
  double get totalUnrealizedPnl =>
      _openTrades.fold(0, (sum, t) => sum + t.unrealizedPnl);

  String get _userId {
    try {
      return firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? 'demo_user';
    } catch (_) {
      return 'demo_user';
    }
  }

  Future<void> init() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    await Future.wait([
      _loadOpenTrades(),
      _loadHistory(),
      _loadStats(),
    ]);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadOpenTrades() async {
    try {
      final data = await _api.fetchOpenPaperTrades(userId: _userId);
      _openTrades = (data['trades'] as List? ?? [])
          .map((j) => PaperTrade.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Load open trades error: $e');
    }
  }

  Future<void> _loadHistory() async {
    try {
      final data = await _api.fetchPaperTradeHistory(userId: _userId);
      _history = (data['trades'] as List? ?? [])
          .map((j) => PaperTrade.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Load history error: $e');
    }
  }

  Future<void> _loadStats() async {
    try {
      final data = await _api.fetchPaperPerformance(userId: _userId);
      _stats = PerformanceStats.fromJson(data);
    } catch (e) {
      debugPrint('Load stats error: $e');
    }
  }

  /// Open a paper trade from a signal card
  Future<bool> openFromSignal(TradeSignal signal) async {
    _isOpening = true;
    _error = null;
    _successMessage = null;
    notifyListeners();

    try {
      final direction = signal.type == SignalType.buy ? 'BUY' : 'SELL';
      final result = await _api.openPaperTrade(
        userId: _userId,
        pair: signal.symbol.replaceAll('/', '_'),
        direction: direction,
        entryPrice: signal.entryPrice,
        stopLoss: signal.stopLoss,
        takeProfit: signal.takeProfit,
        reasoning: signal.explanation,
        signalId: signal.id,
      );

      if (result['success'] == true) {
        final trade = PaperTrade.fromJson(
            result['trade'] as Map<String, dynamic>);
        _openTrades.insert(0, trade);
        _successMessage = 'Paper trade opened: ${direction} ${signal.symbol}';
        notifyListeners();
        return true;
      }
      _error = 'Failed to open trade';
      return false;
    } catch (e) {
      _error = 'Error: $e';
      debugPrint('openFromSignal error: $e');
      return false;
    } finally {
      _isOpening = false;
      notifyListeners();
    }
  }

  /// Close a trade at given price
  Future<bool> closeTrade(PaperTrade trade, double closePrice) async {
    _error = null;
    _successMessage = null;
    notifyListeners();

    try {
      final result = await _api.closePaperTrade(
        tradeId: trade.id,
        closePrice: closePrice,
      );

      if (result['success'] == true) {
        _openTrades.removeWhere((t) => t.id == trade.id);
        final closed = PaperTrade.fromJson(
            result['trade'] as Map<String, dynamic>);
        _history.insert(0, closed);
        await _loadStats();
        _successMessage =
            'Trade closed. P&L: \$${result['realized_pnl']?.toStringAsFixed(2)}';
        notifyListeners();
        return true;
      }
      _error = result['error'] ?? 'Failed to close trade';
      return false;
    } catch (e) {
      _error = 'Error: $e';
      return false;
    } finally {
      notifyListeners();
    }
  }

  void clearMessages() {
    _error = null;
    _successMessage = null;
    notifyListeners();
  }

  Future<void> refresh() async => init();
}