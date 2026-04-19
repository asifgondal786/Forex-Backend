import 'package:flutter/foundation.dart';

// ─── Step enum ────────────────────────────────────────────────────────────────

enum TradeSetupStep { setup, review, confirm, executing, done }

// ─── Provider ─────────────────────────────────────────────────────────────────

/// Manages the full trade execution flow driven by [TradeSetupSheet]:
///
///   setup → review → confirm → executing → done
///
/// After a successful execution, call [PortfolioProvider.addOpenTrade] and
/// [AutomationProvider.appendLog] from the UI layer.
class TradeExecutionProvider extends ChangeNotifier {
  TradeSetupStep _step = TradeSetupStep.setup;

  // Setup inputs
  String? _selectedPair;
  String _direction = 'BUY';
  double _lotSize = 0.01;
  double _leverage = 10.0;
  double? _stopLoss;
  double? _takeProfit;

  // Execution state
  bool _isExecuting = false;
  String? _executionResult;
  String? _lastTradeId;

  // ─── Getters ────────────────────────────────────────────────────────────

  TradeSetupStep get step => _step;
  String? get selectedPair => _selectedPair;
  String get direction => _direction;
  double get lotSize => _lotSize;
  double get leverage => _leverage;
  double? get stopLoss => _stopLoss;
  double? get takeProfit => _takeProfit;
  bool get isExecuting => _isExecuting;
  String? get executionResult => _executionResult;
  String? get lastTradeId => _lastTradeId;

  /// Estimated max loss based on lot size and leverage (simplified).
  double get estimatedMaxLoss => _lotSize * _leverage * 10;

  /// Estimated risk/reward ratio (basic; 0 when no SL/TP set).
  double get riskRewardRatio {
    if (_stopLoss == null || _takeProfit == null) return 0;
    final risk = (_direction == 'BUY'
            ? _entryPriceHint - _stopLoss!
            : _stopLoss! - _entryPriceHint)
        .abs();
    final reward = (_direction == 'BUY'
            ? _takeProfit! - _entryPriceHint
            : _entryPriceHint - _takeProfit!)
        .abs();
    return risk == 0 ? 0 : reward / risk;
  }

  // Placeholder entry price for calculations before fill (sim only).
  double get _entryPriceHint => 1.08450;

  // ─── Flow ───────────────────────────────────────────────────────────────

  /// Initialise a new trade setup. Called before opening the bottom sheet.
  void startSetup({required String pair, required String dir}) {
    _selectedPair = pair;
    _direction = dir;
    _lotSize = 0.01;
    _leverage = 10.0;
    _stopLoss = null;
    _takeProfit = null;
    _step = TradeSetupStep.setup;
    _isExecuting = false;
    _executionResult = null;
    _lastTradeId = null;
    notifyListeners();
  }

  /// Update individual setup fields without advancing the step.
  void updateSetup({
    double? lot,
    double? lev,
    double? sl,
    double? tp,
  }) {
    if (lot != null) _lotSize = lot.clamp(0.01, 100);
    if (lev != null) _leverage = lev.clamp(1, 500);
    if (sl != null) _stopLoss = sl;
    if (tp != null) _takeProfit = tp;
    notifyListeners();
  }

  /// Clears a stop-loss or take-profit field (when user empties the text field).
  void clearStopLoss() {
    _stopLoss = null;
    notifyListeners();
  }

  void clearTakeProfit() {
    _takeProfit = null;
    notifyListeners();
  }

  /// Advance from setup → confirm (skips over the internal review sub-state).
  void proceedToConfirm() {
    if (_step == TradeSetupStep.setup || _step == TradeSetupStep.review) {
      _step = TradeSetupStep.confirm;
    } else if (_step == TradeSetupStep.confirm) {
      // "Back" from confirm → setup
      _step = TradeSetupStep.setup;
    }
    notifyListeners();
  }

  /// Validate inputs. Returns an error string if invalid, null if OK.
  String? validate() {
    if (_selectedPair == null || _selectedPair!.isEmpty) {
      return 'No pair selected.';
    }
    if (_lotSize <= 0) return 'Lot size must be greater than 0.';
    if (_leverage < 1) return 'Leverage must be at least 1.';
    if (_stopLoss != null && _takeProfit != null) {
      final isBuy = _direction == 'BUY';
      if (isBuy && _stopLoss! >= _takeProfit!) {
        return 'Stop loss must be below take profit for a BUY.';
      }
      if (!isBuy && _stopLoss! <= _takeProfit!) {
        return 'Stop loss must be above take profit for a SELL.';
      }
    }
    return null;
  }

  // ─── Execute ─────────────────────────────────────────────────────────────

  /// Consumes [token] and submits the trade to the backend.
  /// Returns true on success, false on failure.
  /// The step transitions: confirm → executing → done / stays on confirm.
  Future<bool> executeTrade(String token) async {
    final validationError = validate();
    if (validationError != null) {
      _executionResult = validationError;
      notifyListeners();
      return false;
    }

    _step = TradeSetupStep.executing;
    _isExecuting = true;
    _executionResult = null;
    notifyListeners();

    try {
      // TODO: replace with real POST /api/trades/paper
      // Body: { pair, direction, lotSize, leverage, stopLoss, takeProfit, token }
      await Future.delayed(const Duration(milliseconds: 1200));

      // Simulate token consumption + order fill
      _lastTradeId = 'trade_${DateTime.now().millisecondsSinceEpoch}';
      _executionResult =
          'Trade submitted! Order ID: ${_lastTradeId!.substring(6, 16)}';

      _step = TradeSetupStep.done;
      _isExecuting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _executionResult = 'Execution failed: $e';
      _step = TradeSetupStep.confirm; // revert so user can retry
      _isExecuting = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Helpers for building the executed trade object ───────────────────────

  /// Returns an [ExecutedTradeSnapshot] that callers (e.g., PortfolioProvider)
  /// can use to add the trade to the portfolio.
  ExecutedTradeSnapshot? buildSnapshot() {
    if (_lastTradeId == null || _selectedPair == null) return null;
    return ExecutedTradeSnapshot(
      tradeId: _lastTradeId!,
      pair: _selectedPair!,
      direction: _direction,
      lotSize: _lotSize,
      leverage: _leverage,
      stopLoss: _stopLoss,
      takeProfit: _takeProfit,
      openedAt: DateTime.now(),
    );
  }

  // ─── Reset ───────────────────────────────────────────────────────────────

  /// Fully resets provider back to the initial state.
  void reset() {
    _step = TradeSetupStep.setup;
    _selectedPair = null;
    _direction = 'BUY';
    _lotSize = 0.01;
    _leverage = 10.0;
    _stopLoss = null;
    _takeProfit = null;
    _isExecuting = false;
    _executionResult = null;
    _lastTradeId = null;
    notifyListeners();
  }
}

// ─── Snapshot model ───────────────────────────────────────────────────────────

/// Lightweight snapshot of a just-executed trade for consumption by other
/// providers (e.g., PortfolioProvider, AutomationProvider).
class ExecutedTradeSnapshot {
  final String tradeId;
  final String pair;
  final String direction;
  final double lotSize;
  final double leverage;
  final double? stopLoss;
  final double? takeProfit;
  final DateTime openedAt;

  const ExecutedTradeSnapshot({
    required this.tradeId,
    required this.pair,
    required this.direction,
    required this.lotSize,
    required this.leverage,
    this.stopLoss,
    this.takeProfit,
    required this.openedAt,
  });
}

