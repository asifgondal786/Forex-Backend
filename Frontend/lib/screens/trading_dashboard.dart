import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

void main() {
  runApp(const TajirTradingApp());
}

class TajirTradingApp extends StatelessWidget {
  const TajirTradingApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tajir Auto-Trading',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const TradingDashboard(),
    );
  }
}

// ===== API SERVICE =====

class TajirAPI {
  static const String baseUrl = 'http://127.0.0.1:8001';
  static const Duration timeout = Duration(seconds: 10);

  static Future<Map<String, dynamic>> getStatus() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/status'))
          .timeout(timeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  static Future<Map<String, dynamic>> getPrice(String symbol) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/price/$symbol'))
          .timeout(timeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  static Future<Map<String, dynamic>> getPrediction(String symbol) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/predict/$symbol'))
          .timeout(timeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'signal': null, 'confidence': 0};
    } catch (e) {
      return {'signal': null, 'confidence': 0};
    }
  }

  static Future<Map<String, dynamic>> autoTrade({
    required String symbol,
    required double minConfidence,
    required double lotSize,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trade/auto'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'symbol': symbol,
          'min_confidence': minConfidence,
          'lot_size': lotSize,
          'use_stop_loss': true,
          'use_take_profit': true,
          'stop_loss_pips': 30,
          'take_profit_pips': 60,
        }),
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'status': 'FAILED'};
    } catch (e) {
      return {'status': 'ERROR', 'reason': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getAccount() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/account'))
          .timeout(timeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      return {};
    }
  }
}

// ===== TRADING DASHBOARD =====

class TradingDashboard extends StatefulWidget {
  const TradingDashboard({Key? key}) : super(key: key);

  @override
  State<TradingDashboard> createState() => _TradingDashboardState();
}

class _TradingDashboardState extends State<TradingDashboard> {
  late Timer _refreshTimer;
  final List<String> symbols = ['EURUSD', 'GBPUSD', 'USDJPY', 'AUDUSD'];
  final Map<String, Map<String, dynamic>> priceData = {};
  final Map<String, Map<String, dynamic>> signalData = {};
  Map<String, dynamic> status = {};
  Map<String, dynamic> account = {};

  String selectedSymbol = 'EURUSD';
  double minConfidence = 0.65;
  double lotSize = 0.01;
  bool autoTradeActive = false;
  String lastTradeResult = '';

  @override
  void initState() {
    super.initState();
    _refreshData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) => _refreshData());
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    super.dispose();
  }

  void _refreshData() async {
    final newStatus = await TajirAPI.getStatus();
    final newAccount = await TajirAPI.getAccount();

    for (String symbol in symbols) {
      final price = await TajirAPI.getPrice(symbol);
      final signal = await TajirAPI.getPrediction(symbol);
      
      setState(() {
        priceData[symbol] = price;
        signalData[symbol] = signal;
        status = newStatus;
        account = newAccount;
      });
    }
  }

  void _executeTrade() async {
    setState(() => lastTradeResult = 'Executing...');
    
    final result = await TajirAPI.autoTrade(
      symbol: selectedSymbol,
      minConfidence: minConfidence,
      lotSize: lotSize,
    );

    setState(() {
      lastTradeResult = result['status'] ?? 'Unknown';
      if (result['status'] == 'ORDER_PLACED') {
        lastTradeResult += '\nEntry: ${result['entry_price']}\nSL: ${result['stop_loss']}\nTP: ${result['take_profit']}';
      } else if (result['status'] == 'SKIPPED') {
        lastTradeResult = 'Skipped: ${result['reason']}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚀 Tajir Auto-Trading Dashboard'),
        elevation: 2,
        backgroundColor: Colors.blue[800],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== STATUS CARD =====
            _buildStatusCard(),
            const SizedBox(height: 20),

            // ===== ACCOUNT INFO =====
            _buildAccountCard(),
            const SizedBox(height: 20),

            // ===== PRICE CARDS =====
            const Text('💱 Live Prices',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...symbols.map((symbol) => _buildPriceCard(symbol)).toList(),
            const SizedBox(height: 20),

            // ===== AUTO-TRADE PANEL =====
            _buildAutoTradePanel(),
            const SizedBox(height: 20),

            // ===== ML SIGNALS =====
            const Text('🤖 ML Predictions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...symbols.map((symbol) => _buildSignalCard(symbol)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final connected = status['connected'] ?? false;
    final priceActive = status['price_feed_active'] ?? false;
    final mlLoaded = status['ml_model_loaded'] ?? false;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📊 System Status',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _statusRow('FIX Connected', connected),
            _statusRow('Price Feed', priceActive),
            _statusRow('ML Model', mlLoaded),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(String label, bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: active ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              active ? '✅ Active' : '❌ Inactive',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard() {
    final balance = account['balance'] ?? 0.0;
    final equity = account['equity'] ?? 0.0;
    final marginLevel = account['margin_level'] ?? 0.0;

    return Card(
      elevation: 4,
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('💰 Account',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Balance:'),
                Text('\$${balance.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Equity:'),
                Text('\$${equity.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Margin Level:'),
                Text('${marginLevel.toStringAsFixed(1)}%',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceCard(String symbol) {
    final data = priceData[symbol] ?? {};
    final bid = data['bid'] ?? 0.0;
    final ask = data['ask'] ?? 0.0;
    final spread = ((ask - bid) * 10000).toStringAsFixed(2);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(symbol,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Spread: $spread pips',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${bid.toStringAsFixed(5)}/${ask.toStringAsFixed(5)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFamily: 'Courier')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalCard(String symbol) {
    final signal = signalData[symbol]?['signal'] ?? 'N/A';
    final confidence = (signalData[symbol]?['confidence'] ?? 0.0) * 100;
    final isBuy = signal == 'BUY';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: isBuy ? Colors.green[50] : Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(symbol,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text('Confidence: ${confidence.toStringAsFixed(1)}%',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isBuy ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                signal,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoTradePanel() {
    return Card(
      elevation: 4,
      color: Colors.amber[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🤖 Auto-Trading Controls',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Symbol selector
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Text('Symbol: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: DropdownButton<String>(
                      value: selectedSymbol,
                      onChanged: (newValue) =>
                          setState(() => selectedSymbol = newValue ?? 'EURUSD'),
                      items: symbols
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      isExpanded: true,
                    ),
                  ),
                ],
              ),
            ),

            // Min confidence
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Min Confidence: ${(minConfidence * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Slider(
                    value: minConfidence,
                    onChanged: (v) => setState(() => minConfidence = v),
                    min: 0.5,
                    max: 0.95,
                    divisions: 9,
                  ),
                ],
              ),
            ),

            // Lot size
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lot Size: ${lotSize.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Slider(
                    value: lotSize,
                    onChanged: (v) => setState(() => lotSize = v),
                    min: 0.01,
                    max: 1.0,
                    divisions: 99,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Trade button
            ElevatedButton.icon(
              onPressed: _executeTrade,
              icon: const Icon(Icons.bolt),
              label: const Text('Execute Auto-Trade'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),

            if (lastTradeResult.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(lastTradeResult,
                    style: const TextStyle(fontFamily: 'Courier', fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
