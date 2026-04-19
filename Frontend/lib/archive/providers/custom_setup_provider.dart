import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Keys
// ─────────────────────────────────────────────────────────────────────────────
const _kPairsKey = 'custom_setup_pairs';
const _kIndicatorsKey = 'custom_setup_indicators';
const _kTimeframeKey = 'custom_setup_timeframe';
const _kLayoutKey = 'custom_setup_layout';
const _kRiskKey = 'custom_setup_risk_level';
const _kAutoSignalsKey = 'custom_setup_auto_signals';
const _kShowExplanationsKey = 'custom_setup_show_explanations';
const _kDarkModeChartsKey = 'custom_setup_dark_charts';

// ─────────────────────────────────────────────────────────────────────────────
// Static data — all supported options
// ─────────────────────────────────────────────────────────────────────────────
class CurrencyPair {
  final String symbol;
  final String base;
  final String quote;
  final String region;
  const CurrencyPair(this.symbol, this.base, this.quote, this.region);
}

const List<CurrencyPair> kAllPairs = [
  // Majors
  CurrencyPair('EUR/USD', 'EUR', 'USD', 'Major'),
  CurrencyPair('GBP/USD', 'GBP', 'USD', 'Major'),
  CurrencyPair('USD/JPY', 'USD', 'JPY', 'Major'),
  CurrencyPair('USD/CHF', 'USD', 'CHF', 'Major'),
  CurrencyPair('AUD/USD', 'AUD', 'USD', 'Major'),
  CurrencyPair('USD/CAD', 'USD', 'CAD', 'Major'),
  CurrencyPair('NZD/USD', 'NZD', 'USD', 'Major'),
  // Minors
  CurrencyPair('EUR/GBP', 'EUR', 'GBP', 'Minor'),
  CurrencyPair('EUR/JPY', 'EUR', 'JPY', 'Minor'),
  CurrencyPair('GBP/JPY', 'GBP', 'JPY', 'Minor'),
  CurrencyPair('EUR/AUD', 'EUR', 'AUD', 'Minor'),
  CurrencyPair('GBP/AUD', 'GBP', 'AUD', 'Minor'),
  // Exotics
  CurrencyPair('USD/TRY', 'USD', 'TRY', 'Exotic'),
  CurrencyPair('USD/ZAR', 'USD', 'ZAR', 'Exotic'),
  CurrencyPair('USD/MXN', 'USD', 'MXN', 'Exotic'),
];

const List<String> kAllIndicators = [
  'RSI',
  'MACD',
  'Bollinger Bands',
  'EMA 20',
  'EMA 50',
  'EMA 200',
  'SMA 50',
  'ATR',
  'Stochastic',
  'CCI',
  'Williams %R',
  'ADX',
  'Ichimoku',
  'VWAP',
  'Fibonacci',
];

const List<String> kTimeframes = [
  'M1', 'M5', 'M15', 'M30',
  'H1', 'H4', 'D1', 'W1',
];

enum LayoutStyle { cards, list, compact }

enum RiskLevel { conservative, moderate, aggressive }

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────
class CustomSetupProvider extends ChangeNotifier {
  // State
  Set<String> _selectedPairs = {'EUR/USD', 'GBP/USD', 'USD/JPY'};
  Set<String> _selectedIndicators = {'RSI', 'MACD', 'EMA 20', 'EMA 50'};
  String _preferredTimeframe = 'H1';
  LayoutStyle _layoutStyle = LayoutStyle.cards;
  RiskLevel _riskLevel = RiskLevel.moderate;
  bool _autoSignals = false;
  bool _showExplanations = true;
  bool _darkCharts = true;
  bool _isLoading = false;
  bool _isSaving = false;

  // Getters
  Set<String> get selectedPairs => Set.unmodifiable(_selectedPairs);
  Set<String> get selectedIndicators => Set.unmodifiable(_selectedIndicators);
  String get preferredTimeframe => _preferredTimeframe;
  LayoutStyle get layoutStyle => _layoutStyle;
  RiskLevel get riskLevel => _riskLevel;
  bool get autoSignals => _autoSignals;
  bool get showExplanations => _showExplanations;
  bool get darkCharts => _darkCharts;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get hasMinimumSetup => _selectedPairs.isNotEmpty;

  // ── Pair toggles ────────────────────────────────────────────────────────
  void togglePair(String symbol) {
    if (_selectedPairs.contains(symbol)) {
      // keep at least 1
      if (_selectedPairs.length > 1) _selectedPairs.remove(symbol);
    } else {
      _selectedPairs.add(symbol);
    }
    notifyListeners();
  }

  // ── Indicator toggles ───────────────────────────────────────────────────
  void toggleIndicator(String name) {
    if (_selectedIndicators.contains(name)) {
      _selectedIndicators.remove(name);
    } else {
      _selectedIndicators.add(name);
    }
    notifyListeners();
  }

  // ── Simple setters ───────────────────────────────────────────────────────
  void setTimeframe(String tf) {
    _preferredTimeframe = tf;
    notifyListeners();
  }

  void setLayout(LayoutStyle style) {
    _layoutStyle = style;
    notifyListeners();
  }

  void setRiskLevel(RiskLevel level) {
    _riskLevel = level;
    notifyListeners();
  }

  void setAutoSignals(bool val) {
    _autoSignals = val;
    notifyListeners();
  }

  void setShowExplanations(bool val) {
    _showExplanations = val;
    notifyListeners();
  }

  void setDarkCharts(bool val) {
    _darkCharts = val;
    notifyListeners();
  }

  // ── Persistence ──────────────────────────────────────────────────────────
  Future<void> loadFromPrefs() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final pairsRaw = prefs.getStringList(_kPairsKey);
      if (pairsRaw != null && pairsRaw.isNotEmpty) {
        _selectedPairs = pairsRaw.toSet();
      }
      final indicatorsRaw = prefs.getStringList(_kIndicatorsKey);
      if (indicatorsRaw != null) {
        _selectedIndicators = indicatorsRaw.toSet();
      }
      _preferredTimeframe =
          prefs.getString(_kTimeframeKey) ?? 'H1';
      _layoutStyle = LayoutStyle.values[
          prefs.getInt(_kLayoutKey) ?? LayoutStyle.cards.index];
      _riskLevel = RiskLevel.values[
          prefs.getInt(_kRiskKey) ?? RiskLevel.moderate.index];
      _autoSignals = prefs.getBool(_kAutoSignalsKey) ?? false;
      _showExplanations = prefs.getBool(_kShowExplanationsKey) ?? true;
      _darkCharts = prefs.getBool(_kDarkModeChartsKey) ?? true;
    } catch (_) {
      // use defaults
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveToPrefs() async {
    _isSaving = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kPairsKey, _selectedPairs.toList());
      await prefs.setStringList(
          _kIndicatorsKey, _selectedIndicators.toList());
      await prefs.setString(_kTimeframeKey, _preferredTimeframe);
      await prefs.setInt(_kLayoutKey, _layoutStyle.index);
      await prefs.setInt(_kRiskKey, _riskLevel.index);
      await prefs.setBool(_kAutoSignalsKey, _autoSignals);
      await prefs.setBool(_kShowExplanationsKey, _showExplanations);
      await prefs.setBool(_kDarkModeChartsKey, _darkCharts);
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}

