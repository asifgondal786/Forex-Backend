import 'package:flutter/foundation.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

class OpenTrade {
  final String id;
  final String pair;
  final String direction; // 'BUY' | 'SELL'
  final double entryPrice;
  final double lotSize;
  final double leverage;
  final double? stopLoss;
  final double? takeProfit;
  final DateTime openedAt;
  double pnl; // live, updated via markToMarket

  OpenTrade({
    required this.id,
    required this.pair,
    required this.direction,
    required this.entryPrice,
    required this.lotSize,
    required this.leverage,
    this.stopLoss,
    this.takeProfit,
    required this.openedAt,
    this.pnl = 0,
  });

  OpenTrade copyWith({double? pnl}) => OpenTrade(
        id: id,
        pair: pair,
        direction: direction,
        entryPrice: entryPrice,
        lotSize: lotSize,
        leverage: leverage,
        stopLoss: stopLoss,
        takeProfit: takeProfit,
        openedAt: openedAt,
        pnl: pnl ?? this.pnl,
      );
}

class ClosedTrade {
  final String id;
  final String pair;
  final String direction;
  final double entryPrice;
  final double exitPrice;
  final double lotSize;
  final double realizedPnl;
  final DateTime closedAt;

  const ClosedTrade({
    required this.id,
    required this.pair,
    required this.direction,
    required this.entryPrice,
    required this.exitPrice,
    required this.lotSize,
    required this.realizedPnl,
    required this.closedAt,
  });
}

class PortfolioStats {
  final double equity;
  final double balance;
  final double dailyPnl;
  final double winRate;
  final double avgWin;
  final double avgLoss;
  final int winStreak;
  final List<double> equityCurve;

  const PortfolioStats({
    required this.equity,
    required this.balance,
    required this.dailyPnl,
    required this.winRate,
    required this.avgWin,
    required this.avgLoss,
    required this.winStreak,
    required this.equityCurve,
  });

  factory PortfolioStats.empty() => const PortfolioStats(
        equity: 10000,
        balance: 10000,
        dailyPnl: 0,
        winRate: 0,
        avgWin: 0,
        avgLoss: 0,
        winStreak: 0,
        equityCurve: [],
      );
}

// ─── Provider ─────────────────────────────────────────────────────────────────

class PortfolioProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  PortfolioStats _stats = PortfolioStats.empty();
  List<OpenTrade> _openTrades = [];
  List<ClosedTrade> _tradeHistory = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  PortfolioStats get stats => _stats;
  List<OpenTrade> get openTrades => List.unmodifiable(_openTrades);
  List<ClosedTrade> get tradeHistory => List.unmodifiable(_tradeHistory);

  /// Loads open positions, history, and computes stats.
  /// [token] is the auth token passed from the calling screen.
  Future<void> loadAll(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // TODO: replace with real API calls using [token]
      await Future.delayed(const Duration(milliseconds: 600));

      _openTrades = _mockOpenTrades();
      _tradeHistory = _mockHistory();
      _stats = _computeStats();
    } catch (e) {
      _error = 'Failed to load portfolio: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Appends a new paper trade from TradeExecutionProvider after execution.
  void addOpenTrade(OpenTrade trade) {
    _openTrades = [trade, ..._openTrades];
    _stats = _computeStats();
    notifyListeners();
  }

  /// Updates live P&L for all open positions given current market prices.
  /// [prices] is a map of pair → current bid price.
  void markToMarket(Map<String, double> prices) {
    bool changed = false;
    _openTrades = _openTrades.map((t) {
      final price = prices[t.pair];
      if (price == null) return t;
      final pipValue = t.lotSize * t.leverage * 10;
      final priceDiff = t.direction == 'BUY'
          ? price - t.entryPrice
          : t.entryPrice - price;
      final newPnl = priceDiff * pipValue;
      changed = true;
      return t.copyWith(pnl: newPnl);
    }).toList();

    if (changed) {
      _stats = _computeStats();
      notifyListeners();
    }
  }

  /// Closes an open trade by id. Returns true on success.
  Future<bool> closeTrade(String tradeId, String token) async {
    final idx = _openTrades.indexWhere((t) => t.id == tradeId);
    if (idx == -1) return false;

    final trade = _openTrades[idx];

    try {
      // TODO: hit real close-trade endpoint with [token]
      await Future.delayed(const Duration(milliseconds: 300));

      // Simulate exit price slightly moved from entry
      final exitPrice = trade.direction == 'BUY'
          ? trade.entryPrice * 1.0008
          : trade.entryPrice * 0.9992;

      final closed = ClosedTrade(
        id: trade.id,
        pair: trade.pair,
        direction: trade.direction,
        entryPrice: trade.entryPrice,
        exitPrice: exitPrice,
        lotSize: trade.lotSize,
        realizedPnl: trade.pnl,
        closedAt: DateTime.now(),
      );

      _openTrades = List.from(_openTrades)..removeAt(idx);
      _tradeHistory = [closed, ..._tradeHistory];
      _stats = _computeStats();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── Private helpers ───────────────────────────────────────────────────────

  PortfolioStats _computeStats() {
    final openPnl = _openTrades.fold<double>(0, (sum, t) => sum + t.pnl);
    final closedPnl =
        _tradeHistory.fold<double>(0, (sum, t) => sum + t.realizedPnl);

    const startBalance = 10000.0;
    final equity = startBalance + closedPnl + openPnl;

    // Daily P&L: sum realizedPnl for trades closed today + open pnl
    final today = DateTime.now();
    final todayClosed = _tradeHistory
        .where((t) =>
            t.closedAt.year == today.year &&
            t.closedAt.month == today.month &&
            t.closedAt.day == today.day)
        .fold<double>(0, (sum, t) => sum + t.realizedPnl);
    final dailyPnl = todayClosed + openPnl;

    // Win rate & averages
    final wins = _tradeHistory.where((t) => t.realizedPnl > 0).toList();
    final losses = _tradeHistory.where((t) => t.realizedPnl <= 0).toList();
    final winRate = _tradeHistory.isEmpty
        ? 0.0
        : (wins.length / _tradeHistory.length) * 100;
    final avgWin = wins.isEmpty
        ? 0.0
        : wins.fold<double>(0, (s, t) => s + t.realizedPnl) / wins.length;
    final avgLoss = losses.isEmpty
        ? 0.0
        : losses.fold<double>(0, (s, t) => s + t.realizedPnl.abs()) /
            losses.length;

    // Win streak
    int streak = 0;
    for (final t in _tradeHistory) {
      if (t.realizedPnl > 0) {
        streak++;
      } else {
        break;
      }
    }

    // Equity curve: running balance from closed trades
    double running = startBalance;
    final curve = <double>[running];
    for (final t in _tradeHistory.reversed) {
      running += t.realizedPnl;
      curve.add(running);
    }
    curve.add(equity);

    return PortfolioStats(
      equity: equity,
      balance: startBalance + closedPnl,
      dailyPnl: dailyPnl,
      winRate: winRate,
      avgWin: avgWin,
      avgLoss: avgLoss,
      winStreak: streak,
      equityCurve: curve,
    );
  }

  // ─── Mock data (replace with API) ─────────────────────────────────────────

  List<OpenTrade> _mockOpenTrades() => [
        OpenTrade(
          id: 'ot_001',
          pair: 'EUR/USD',
          direction: 'BUY',
          entryPrice: 1.08452,
          lotSize: 0.1,
          leverage: 20,
          stopLoss: 1.0820,
          takeProfit: 1.0900,
          openedAt: DateTime.now().subtract(const Duration(hours: 2)),
          pnl: 34.20,
        ),
        OpenTrade(
          id: 'ot_002',
          pair: 'GBP/JPY',
          direction: 'SELL',
          entryPrice: 188.340,
          lotSize: 0.05,
          leverage: 15,
          openedAt: DateTime.now().subtract(const Duration(minutes: 45)),
          pnl: -12.80,
        ),
      ];

  List<ClosedTrade> _mockHistory() {
    final now = DateTime.now();
    return [
      ClosedTrade(
        id: 'ct_001',
        pair: 'USD/JPY',
        direction: 'BUY',
        entryPrice: 149.200,
        exitPrice: 149.580,
        lotSize: 0.1,
        realizedPnl: 76.00,
        closedAt: now.subtract(const Duration(hours: 5)),
      ),
      ClosedTrade(
        id: 'ct_002',
        pair: 'EUR/GBP',
        direction: 'SELL',
        entryPrice: 0.85640,
        exitPrice: 0.85920,
        lotSize: 0.05,
        realizedPnl: -22.40,
        closedAt: now.subtract(const Duration(hours: 8)),
      ),
      ClosedTrade(
        id: 'ct_003',
        pair: 'AUD/USD',
        direction: 'BUY',
        entryPrice: 0.64820,
        exitPrice: 0.65140,
        lotSize: 0.2,
        realizedPnl: 128.00,
        closedAt: now.subtract(const Duration(days: 1)),
      ),
      ClosedTrade(
        id: 'ct_004',
        pair: 'USD/CAD',
        direction: 'SELL',
        entryPrice: 1.35800,
        exitPrice: 1.35420,
        lotSize: 0.1,
        realizedPnl: 56.00,
        closedAt: now.subtract(const Duration(days: 2)),
      ),
    ];
  }
}
