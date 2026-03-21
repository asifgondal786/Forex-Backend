import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class CandleData {
  final int time;
  final double open;
  final double high;
  final double low;
  final double close;
  CandleData({required this.time, required this.open, required this.high, required this.low, required this.close});
}

class ChartProvider extends ChangeNotifier {
  final ApiService _api;
  ChartProvider(this._api);

  List<CandleData> _candles = [];
  String _selectedPair = 'EUR/USD';
  bool _isLoading = false;
  String? _error;

  List<CandleData> get candles => _candles;
  String get selectedPair => _selectedPair;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void selectPair(String pair) {
    _selectedPair = pair;
    fetchCandles();
  }

  Future<void> fetchCandles() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _api.fetchOHLCData(pair: _selectedPair);
      final values = data['values'] as List? ?? [];
      _candles = values.map((v) {
        final dt = DateTime.parse(v['datetime'] as String);
        return CandleData(
          time: dt.millisecondsSinceEpoch ~/ 1000,
          open: double.tryParse(v['open'].toString()) ?? 0,
          high: double.tryParse(v['high'].toString()) ?? 0,
          low: double.tryParse(v['low'].toString()) ?? 0,
          close: double.tryParse(v['close'].toString()) ?? 0,
        );
      }).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
