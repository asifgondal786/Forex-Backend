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
    final stats = rawStats.map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    );

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

  // Inputs
  double winRate = 0.55;
  double avgWin = 50.0;
  double avgLoss = 30.0;
  int numTrades = 100;
  double startingBalance = 10000.0;

  // State
  bool isLoading = false;
  String? error;
  RiskSimResult? result;

  void updateWinRate(double v)        { winRate = v;         notifyListeners(); }
  void updateAvgWin(double v)         { avgWin = v;          notifyListeners(); }
  void updateAvgLoss(double v)        { avgLoss = v;         notifyListeners(); }
  void updateNumTrades(int v)         { numTrades = v;       notifyListeners(); }
  void updateStartingBalance(double v){ startingBalance = v; notifyListeners(); }

  Future<void> runSimulation() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final data = await _api.fetchRiskSimulation(
        winRate: winRate,
        avgWin: avgWin,
        avgLoss: avgLoss,
        numTrades: numTrades,
        startingBalance: startingBalance,
      );
      result = RiskSimResult.fromJson(data);
    } catch (e) {
      error = e.toString();
      debugPrint('RiskProvider error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}