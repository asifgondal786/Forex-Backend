import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class RiskSimResult {
  final int simulations;
  final int numTrades;
  final double startingBalance;
  final List<List<double>> sampledCurves;
  final Map<String, double> statistics;

  RiskSimResult({
    required this.simulations,
    required this.numTrades,
    required this.startingBalance,
    required this.sampledCurves,
    required this.statistics,
  });

  factory RiskSimResult.fromJson(Map<String, dynamic> json) {
    final rawCurves = json['sampled_curves'] as List? ?? [];
    final curves = rawCurves
        .map((c) => (c as List).map((v) => (v as num).toDouble()).toList())
        .toList();
    final rawStats = json['statistics'] as Map<String, dynamic>? ?? {};
    final stats = rawStats.map((k, v) => MapEntry(k, (v as num).toDouble()));
    return RiskSimResult(
      simulations: (json['simulations'] as num?)?.toInt() ?? 1000,
      numTrades: (json['num_trades'] as num?)?.toInt() ?? 100,
      startingBalance: (json['starting_balance'] as num?)?.toDouble() ?? 10000,
      sampledCurves: curves,
      statistics: stats,
    );
  }
}

class RiskProvider extends ChangeNotifier {
  final ApiService _api;
  RiskProvider(this._api);

  // Monte Carlo inputs
  double winRate = 0.55;
  double avgWin = 50.0;
  double avgLoss = 30.0;
  int numTrades = 100;
  double startingBalance = 10000.0;

  // Drawdown inputs
  double dailyLimitPct = 3.0;
  double weeklyLimitPct = 6.0;
  int maxOpenTrades = 3;
  double riskPerTradePct = 1.0;

  // Kelly inputs
  double kellyFraction = 0.25;

  // State
  bool isLoading = false;
  bool isKellyLoading = false;
  bool isDrawdownLoading = false;
  bool isStressLoading = false;
  String? error;
  RiskSimResult? result;
  Map<String, dynamic>? kellyResult;
  Map<String, dynamic>? drawdownResult;
  Map<String, dynamic>? stressResult;

  // Monte Carlo inputs
  void updateWinRate(double v)         { winRate = v;          notifyListeners(); }
  void updateAvgWin(double v)          { avgWin = v;           notifyListeners(); }
  void updateAvgLoss(double v)         { avgLoss = v;          notifyListeners(); }
  void updateNumTrades(int v)          { numTrades = v;        notifyListeners(); }
  void updateStartingBalance(double v) { startingBalance = v;  notifyListeners(); }

  // Drawdown inputs
  void updateDailyLimit(double v)      { dailyLimitPct = v;    notifyListeners(); }
  void updateWeeklyLimit(double v)     { weeklyLimitPct = v;   notifyListeners(); }
  void updateMaxOpenTrades(int v)      { maxOpenTrades = v;    notifyListeners(); }
  void updateRiskPerTrade(double v)    { riskPerTradePct = v;  notifyListeners(); }
  void updateKellyFraction(double v)   { kellyFraction = v;    notifyListeners(); }

  Future<void> runSimulation() async {
    isLoading = true; error = null; notifyListeners();
    try {
      final data = await _api.fetchRiskSimulation(
        winRate: winRate, avgWin: avgWin, avgLoss: avgLoss,
        numTrades: numTrades, startingBalance: startingBalance,
      );
      result = RiskSimResult.fromJson(data);
    } catch (e) {
      error = e.toString();
      debugPrint('RiskProvider error: $e');
    } finally {
      isLoading = false; notifyListeners();
    }
  }

  Future<void> runKelly() async {
    isKellyLoading = true; notifyListeners();
    try {
      kellyResult = await _api.fetchKellyCriterion(
        winRate: winRate, avgWin: avgWin, avgLoss: avgLoss,
        accountBalance: startingBalance, kellyFraction: kellyFraction,
      );
    } catch (e) {
      debugPrint('Kelly error: $e');
    } finally {
      isKellyLoading = false; notifyListeners();
    }
  }

  Future<void> runDrawdown() async {
    isDrawdownLoading = true; notifyListeners();
    try {
      drawdownResult = await _api.fetchDrawdownControls(
        accountBalance: startingBalance,
        dailyLossLimitPct: dailyLimitPct / 100,
        weeklyLossLimitPct: weeklyLimitPct / 100,
        maxOpenTrades: maxOpenTrades,
        riskPerTradePct: riskPerTradePct / 100,
      );
    } catch (e) {
      debugPrint('Drawdown error: $e');
    } finally {
      isDrawdownLoading = false; notifyListeners();
    }
  }

  Future<void> runStressTest() async {
    isStressLoading = true; notifyListeners();
    try {
      stressResult = await _api.fetchStressTest(
        winRate: winRate, avgWin: avgWin, avgLoss: avgLoss,
        startingBalance: startingBalance, numTrades: numTrades,
      );
    } catch (e) {
      debugPrint('Stress test error: $e');
    } finally {
      isStressLoading = false; notifyListeners();
    }
  }
}