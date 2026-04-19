import 'package:flutter/foundation.dart';

import 'trade_execution.dart';

class OpenTrade {
  final String id;
  final String pair;
  final String direction;
  final double entryPrice;
  final double lotSize;
  final double pnl;
  final DateTime openedAt;

  const OpenTrade({
    required this.id,
    required this.pair,
    required this.direction,
    required this.entryPrice,
    required this.lotSize,
    required this.pnl,
    required this.openedAt,
  });
}

class ClosedTrade {
  final String id;
  final String pair;
  final String direction;
  final double entryPrice;
  final double exitPrice;
  final double realizedPnl;
  final DateTime openedAt;
  final DateTime closedAt;

  const ClosedTrade({
    required this.id,
    required this.pair,
    required this.direction,
    required this.entryPrice,
    required this.exitPrice,
    required this.realizedPnl,
    required this.openedAt,
    required this.closedAt,
  });
}

class PortfolioStats {
  final double equity;
  final double dailyPnl;
  final double winRate;
  final double avgWin;
  final int winStreak;
  final List<double> equityCurve;

  const PortfolioStats({
    this.equity = 10000,
    this.dailyPnl = 0,
    this.winRate = 0,
    this.avgWin = 0,
    this.winStreak = 0,
    this.equityCurve = const [10000],
  });
}

class PortfolioProvider extends ChangeNotifier {
  static const double _startingBalance = 10000;

  bool _isLoading = false;
  List<OpenTrade> _openTrades = const [];
  List<ClosedTrade> _tradeHistory = const [];
  PortfolioStats _stats = const PortfolioStats();

  bool get isLoading => _isLoading;
  List<OpenTrade> get openTrades => List.unmodifiable(_openTrades);
  List<ClosedTrade> get tradeHistory => List.unmodifiable(_tradeHistory);
  PortfolioStats get stats => _stats;

  Future<void> loadAll(String token) async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      _openTrades = _buildMockOpenTrades();
      _tradeHistory = _buildMockTradeHistory();
      _recomputeStats();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void addOpenTrade(ExecutedTradeSnapshot snapshot) {
    _openTrades = [
      OpenTrade(
        id: snapshot.tradeId,
        pair: snapshot.pair,
        direction: snapshot.direction,
        entryPrice: 1.08450,
        lotSize: snapshot.lotSize,
        pnl: 0,
        openedAt: snapshot.openedAt,
      ),
      ..._openTrades,
    ];
    _recomputeStats();
    notifyListeners();
  }

  Future<bool> closeTrade(String tradeId, String token) async {
    final tradeIndex = _openTrades.indexWhere((trade) => trade.id == tradeId);
    if (tradeIndex == -1) return false;

    final trade = _openTrades[tradeIndex];
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final exitPrice = _exitPriceFor(trade);
    final closedTrade = ClosedTrade(
      id: trade.id,
      pair: trade.pair,
      direction: trade.direction,
      entryPrice: trade.entryPrice,
      exitPrice: exitPrice,
      realizedPnl: trade.pnl,
      openedAt: trade.openedAt,
      closedAt: DateTime.now(),
    );

    final updatedOpenTrades = List<OpenTrade>.from(_openTrades)
      ..removeAt(tradeIndex);
    _openTrades = updatedOpenTrades;
    _tradeHistory = [closedTrade, ..._tradeHistory];
    _recomputeStats();
    notifyListeners();
    return true;
  }

  void _recomputeStats() {
    final realizedPnl = _tradeHistory.fold<double>(
      0,
      (sum, trade) => sum + trade.realizedPnl,
    );
    final unrealizedPnl = _openTrades.fold<double>(
      0,
      (sum, trade) => sum + trade.pnl,
    );

    final wins = _tradeHistory.where((trade) => trade.realizedPnl > 0).length;
    final avgWinValues = _tradeHistory
        .where((trade) => trade.realizedPnl > 0)
        .map((trade) => trade.realizedPnl)
        .toList();
    final avgWin = avgWinValues.isEmpty
        ? 0.0
        : avgWinValues.reduce((a, b) => a + b) / avgWinValues.length;

    final today = DateTime.now();
    final dailyRealized = _tradeHistory
        .where((trade) => _isSameDay(trade.closedAt, today))
        .fold<double>(0, (sum, trade) => sum + trade.realizedPnl);

    _stats = PortfolioStats(
      equity: _startingBalance + realizedPnl + unrealizedPnl,
      dailyPnl: dailyRealized + unrealizedPnl,
      winRate: _tradeHistory.isEmpty ? 0 : (wins / _tradeHistory.length) * 100,
      avgWin: avgWin,
      winStreak: _computeWinStreak(),
      equityCurve: _buildEquityCurve(),
    );
  }

  int _computeWinStreak() {
    var streak = 0;
    for (final trade in _tradeHistory) {
      if (trade.realizedPnl > 0) {
        streak += 1;
      } else {
        break;
      }
    }
    return streak;
  }

  List<double> _buildEquityCurve() {
    final orderedHistory = _tradeHistory.reversed.toList();
    final curve = <double>[_startingBalance];
    var running = _startingBalance;

    for (final trade in orderedHistory) {
      running += trade.realizedPnl;
      curve.add(running);
    }

    if (_openTrades.isNotEmpty) {
      final currentUnrealized =
          _openTrades.fold<double>(0, (sum, trade) => sum + trade.pnl);
      curve.add(running + currentUnrealized);
    }

    return curve;
  }

  double _exitPriceFor(OpenTrade trade) {
    final pipMove = trade.pnl.abs() >= 25 ? 0.0018 : 0.0009;
    final isBuy = trade.direction.toUpperCase() == 'BUY';
    final isProfit = trade.pnl >= 0;

    if (isBuy) {
      return isProfit ? trade.entryPrice + pipMove : trade.entryPrice - pipMove;
    }
    return isProfit ? trade.entryPrice - pipMove : trade.entryPrice + pipMove;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<OpenTrade> _buildMockOpenTrades() {
    final now = DateTime.now();
    return [
      OpenTrade(
        id: 'ot_001',
        pair: 'EUR/USD',
        direction: 'BUY',
        entryPrice: 1.08240,
        lotSize: 0.10,
        pnl: 42.80,
        openedAt: now.subtract(const Duration(hours: 3)),
      ),
      OpenTrade(
        id: 'ot_002',
        pair: 'GBP/USD',
        direction: 'SELL',
        entryPrice: 1.27310,
        lotSize: 0.05,
        pnl: -18.40,
        openedAt: now.subtract(const Duration(hours: 1, minutes: 20)),
      ),
    ];
  }

  List<ClosedTrade> _buildMockTradeHistory() {
    final now = DateTime.now();
    return [
      ClosedTrade(
        id: 'ct_001',
        pair: 'USD/JPY',
        direction: 'BUY',
        entryPrice: 149.12000,
        exitPrice: 149.58000,
        realizedPnl: 76.00,
        openedAt: now.subtract(const Duration(hours: 8)),
        closedAt: now.subtract(const Duration(hours: 1)),
      ),
      ClosedTrade(
        id: 'ct_002',
        pair: 'AUD/USD',
        direction: 'SELL',
        entryPrice: 0.65240,
        exitPrice: 0.64990,
        realizedPnl: 58.50,
        openedAt: now.subtract(const Duration(days: 1, hours: 4)),
        closedAt: now.subtract(const Duration(days: 1, hours: 2)),
      ),
      ClosedTrade(
        id: 'ct_003',
        pair: 'EUR/USD',
        direction: 'BUY',
        entryPrice: 1.07920,
        exitPrice: 1.07810,
        realizedPnl: -24.75,
        openedAt: now.subtract(const Duration(days: 2, hours: 6)),
        closedAt: now.subtract(const Duration(days: 2, hours: 5)),
      ),
      ClosedTrade(
        id: 'ct_004',
        pair: 'USD/CAD',
        direction: 'SELL',
        entryPrice: 1.36640,
        exitPrice: 1.36220,
        realizedPnl: 63.10,
        openedAt: now.subtract(const Duration(days: 3, hours: 2)),
        closedAt: now.subtract(const Duration(days: 3)),
      ),
    ];
  }
}

