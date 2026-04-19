// example_trading_widget.dart
// Example Flutter widget showing how to use the TradingService
// Copy this into your app and customize as needed

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

// Simple state management provider
class TradingStateProvider extends ChangeNotifier {
  final ApiService apiService;
  
  Map<String, dynamic>? currentPrice;
  Map<String, dynamic>? latestSignal;
  Map<String, dynamic>? accountInfo;
  List<Map<String, dynamic>> orderHistory = [];
  String statusMessage = 'Initializing...';
  bool isConnected = false;

  TradingStateProvider({required this.apiService}) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Check if API is healthy
      isConnected = await ApiService.isHealthy();
      notifyListeners();

      if (isConnected) {
        // Load account info
        accountInfo = {};
        statusMessage = 'Connected to Tajir Trading';
      } else {
        statusMessage = 'Failed to connect to Tajir Trading';
      }
    } catch (e) {
      statusMessage = 'Error: $e';
    }
    notifyListeners();
  }

  void _showSignalNotification(Map<String, dynamic> signal) {
    // Could show a notification here
    debugPrint('📊 Signal: ${signal['signal']}');
  }

  Future<void> placeOrder(String symbol, String side, double volume) async {
    try {
      // Placeholder for order placement
      // In production, use a proper trading service method
      final response = {'orderId': 'ORD-123', 'status': 'COMPLETED'};
      orderHistory.add(response);
      statusMessage = 'Order placed: $symbol';
      notifyListeners();
    } catch (e) {
      statusMessage = 'Order error: $e';
      notifyListeners();
    }
  }

  Future<void> refreshPrice(String symbol) async {
    try {
      // Placeholder for price refresh
      currentPrice = {'pair': symbol, 'bid': 1.0950, 'ask': 1.0952};
      notifyListeners();
    } catch (e) {
      statusMessage = 'Price error: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}

// ===== MAIN TRADING DASHBOARD WIDGET =====

class TradingDashboard extends StatelessWidget {
  final String tradingServerUrl;

  const TradingDashboard({
    Key? key,
    this.tradingServerUrl = 'http://localhost:8001',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TradingStateProvider(
        apiService: ApiService(),
      ),
      child: const _TradingDashboardContent(),
    );
  }
}

class _TradingDashboardContent extends StatelessWidget {
  const _TradingDashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tajir Trading'),
        elevation: 0,
      ),
      body: Consumer<TradingStateProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Card
                _StatusCard(provider),
                const SizedBox(height: 16),

                // Account Info
                if (provider.accountInfo != null)
                  _AccountCard(provider.accountInfo!),
                const SizedBox(height: 16),

                // Price Card
                if (provider.currentPrice != null)
                  _PriceCard(provider.currentPrice!),
                const SizedBox(height: 16),

                // Signal Card & Action Buttons
                if (provider.latestSignal != null) ...[
                  _SignalCard(provider.latestSignal!),
                  const SizedBox(height: 16),
                  _OrderButtonsRow(provider),
                  const SizedBox(height: 16),
                ],

                // Order History
                if (provider.orderHistory.isNotEmpty) ...[
                  const Text(
                    'Recent Orders',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _OrderHistoryList(provider.orderHistory),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ===== CARD WIDGETS =====

class _StatusCard extends StatelessWidget {
  final TradingStateProvider provider;

  const _StatusCard(this.provider);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: provider.isConnected ? Colors.green[50] : Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: provider.isConnected ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  provider.isConnected ? 'Connected' : 'Disconnected',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(provider.statusMessage),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final Map<String, dynamic>? accountInfo;

  const _AccountCard(this.accountInfo, {super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Account',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (accountInfo != null)
              _InfoRow('Balance', '\$${accountInfo?['balance'] ?? 0}', color: Colors.green),
            if (accountInfo != null)
              _InfoRow('Equity', '\$${accountInfo?['equity'] ?? 0}'),
          ],
        ),
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  final Map<String, dynamic> priceData;

  const _PriceCard(this.priceData, {super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              priceData['pair'] ?? 'N/A',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bid', style: TextStyle(color: Colors.grey)),
                      Text(
                        '${priceData['bid'] ?? 0}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ask', style: TextStyle(color: Colors.grey)),
                      Text(
                        '${priceData['ask'] ?? 0}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalCard extends StatelessWidget {
  final Map<String, dynamic> signal;

  const _SignalCard(this.signal, {super.key});

  @override
  Widget build(BuildContext context) {
    final signalType = signal['signal'] ?? 'N/A';
    final isBuy = signalType == 'BUY';
    final color = isBuy ? Colors.green : Colors.red;

    return Card(
      color: color[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              signalType,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(signal['symbol'] ?? 'N/A', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            if (signal['confidence'] != null)
              _InfoRow('Confidence', '${(signal['confidence'] * 100).toStringAsFixed(0)}%'),
          ],
        ),
      ),
    );
  }
}

class _OrderButtonsRow extends StatelessWidget {
  final TradingStateProvider provider;

  const _OrderButtonsRow(this.provider, {super.key});

  @override
  Widget build(BuildContext context) {
    if (provider.latestSignal == null) return const SizedBox.shrink();

    final signal = provider.latestSignal!;
    final signalType = signal['signal'] ?? 'N/A';
    final isBuy = signalType == 'BUY';

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _placeOrder(context, provider, isBuy),
            icon: Icon(isBuy ? Icons.trending_up : Icons.trending_down),
            label: Text('${signalType} 0.1 LOT'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isBuy ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  void _placeOrder(
    BuildContext context,
    TradingStateProvider provider,
    bool isBuy,
  ) {
    final signal = provider.latestSignal!;
    provider.placeOrder(
      signal['symbol'] ?? 'EURUSD',
      isBuy ? 'BUY' : 'SELL',
      0.1,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${isBuy ? 'Buy' : 'Sell'} order placed: ${signal['symbol']}'),
        backgroundColor: isBuy ? Colors.green : Colors.red,
      ),
    );
  }
}

class _OrderHistoryList extends StatelessWidget {
  final List<Map<String, dynamic>> orders;

  const _OrderHistoryList(this.orders, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final isSuccess = order['status'] == 'COMPLETED' || order['status'] == 'SUCCESS';
        return ListTile(
          title: Text('${order['symbol']} ${order['side']}'),
          subtitle: Text(order['orderId'] ?? 'N/A'),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSuccess ? Colors.green[100] : Colors.red[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              order['status'] ?? 'UNKNOWN',
              style: TextStyle(
                color: isSuccess ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ===== HELPER WIDGETS =====

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _InfoRow(
    this.label,
    this.value, {
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ===== USAGE EXAMPLE =====

/*
// In your main.dart or where you initialize the app:

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tajir Trading',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: TradingDashboard(
        tradingServerUrl: 'http://your-server-ip:8001',
      ),
    );
  }
}
*/
