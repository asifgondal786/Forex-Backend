// trading_service.dart
// Flutter service for communicating with Tajir Trading API (Pepperstone backend)

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class PriceData {
  final String symbol;
  final double bid;
  final double ask;
  final String timestamp;
  final double spread;

  PriceData({
    required this.symbol,
    required this.bid,
    required this.ask,
    required this.timestamp,
    required this.spread,
  });

  factory PriceData.fromJson(Map<String, dynamic> json) {
    return PriceData(
      symbol: json['symbol'],
      bid: (json['bid'] as num).toDouble(),
      ask: (json['ask'] as num).toDouble(),
      timestamp: json['timestamp'],
      spread: (json['spread'] as num).toDouble(),
    );
  }

  @override
  String toString() => '$symbol Bid:${bid.toStringAsFixed(5)} Ask:${ask.toStringAsFixed(5)}';
}

class MLSignal {
  final String symbol;
  final String signal; // "BUY", "SELL", "HOLD"
  final double confidence;
  final String reason;
  final String timestamp;

  MLSignal({
    required this.symbol,
    required this.signal,
    required this.confidence,
    required this.reason,
    required this.timestamp,
  });

  factory MLSignal.fromJson(Map<String, dynamic> json) {
    return MLSignal(
      symbol: json['symbol'],
      signal: json['signal'],
      confidence: (json['confidence'] as num).toDouble(),
      reason: json['reason'],
      timestamp: json['timestamp'],
    );
  }

  @override
  String toString() => '$symbol: $signal (${(confidence * 100).toStringAsFixed(0)}%)';
}

class OrderRequest {
  final String symbol;
  final String side; // "BUY" or "SELL"
  final double volume; // in lots
  final String orderType; // "MARKET" or "LIMIT"
  final double? price; // Required for LIMIT orders

  OrderRequest({
    required this.symbol,
    required this.side,
    required this.volume,
    this.orderType = "MARKET",
    this.price,
  });

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'side': side,
    'volume': volume,
    'order_type': orderType,
    if (price != null) 'price': price,
  };
}

class OrderResponse {
  final String status;
  final String orderId;
  final String symbol;
  final String side;
  final double volume;
  final String timestamp;
  final String message;

  OrderResponse({
    required this.status,
    required this.orderId,
    required this.symbol,
    required this.side,
    required this.volume,
    required this.timestamp,
    required this.message,
  });

  factory OrderResponse.fromJson(Map<String, dynamic> json) {
    return OrderResponse(
      status: json['status'],
      orderId: json['order_id'],
      symbol: json['symbol'],
      side: json['side'],
      volume: (json['volume'] as num).toDouble(),
      timestamp: json['timestamp'],
      message: json['message'],
    );
  }

  bool get isSuccess => status == 'PENDING' || status == 'FILLED';

  @override
  String toString() => '$orderId: $status - $message';
}

class AccountInfo {
  final String accountId;
  final double balance;
  final double equity;
  final double marginUsed;
  final double marginFree;
  final double marginLevel;

  AccountInfo({
    required this.accountId,
    required this.balance,
    required this.equity,
    required this.marginUsed,
    required this.marginFree,
    required this.marginLevel,
  });

  factory AccountInfo.fromJson(Map<String, dynamic> json) {
    return AccountInfo(
      accountId: json['account_id'],
      balance: (json['balance'] as num).toDouble(),
      equity: (json['equity'] as num).toDouble(),
      marginUsed: (json['margin_used'] as num).toDouble(),
      marginFree: (json['margin_free'] as num).toDouble(),
      marginLevel: (json['margin_level'] as num).toDouble(),
    );
  }

  @override
  String toString() => 'Account $accountId: Balance \$${balance.toStringAsFixed(2)}, Equity \$${equity.toStringAsFixed(2)}';
}

/// Main Trading Service
/// Handles all communication with Tajir Trading API
class TradingService {
  static const String _defaultBaseUrl = 'http://localhost:8001';
  
  final String baseUrl;
  final http.Client httpClient;
  
  late WebSocketChannel _priceChannel;
  late WebSocketChannel _signalChannel;
  
  final StreamController<PriceData> _priceStream = StreamController<PriceData>.broadcast();
  final StreamController<MLSignal> _signalStream = StreamController<MLSignal>.broadcast();
  final StreamController<String> _statusStream = StreamController<String>.broadcast();

  TradingService({
    String? baseUrl,
    http.Client? httpClient,
  })  : baseUrl = baseUrl ?? _defaultBaseUrl,
        httpClient = httpClient ?? http.Client();

  /// Get stream of live price updates
  Stream<PriceData> get priceUpdates => _priceStream.stream;

  /// Get stream of ML trading signals
  Stream<MLSignal> get signalUpdates => _signalStream.stream;

  /// Get stream of connection status
  Stream<String> get statusUpdates => _statusStream.stream;

  // ===== CONNECTION MANAGEMENT =====

  /// Check API health
  Future<bool> healthCheck() async {
    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _statusStream.add('Connected: ${data['status']}');
        return data['status'] == 'healthy';
      }
      return false;
    } catch (e) {
      _statusStream.add('Connection error: $e');
      return false;
    }
  }

  /// Get trading system status
  Future<Map<String, dynamic>?> getStatus() async {
    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/status'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Status error: $e');
      return null;
    }
  }

  // ===== PRICE FEEDS =====

  /// Get latest price for a symbol
  Future<PriceData?> getPrice(String symbol) async {
    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/price/${symbol.toUpperCase()}'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return PriceData.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('Price fetch error: $e');
      return null;
    }
  }

  /// Get all cached prices
  Future<List<PriceData>?> getAllPrices() async {
    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/prices'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data.values
            .map((v) => PriceData.fromJson(v as Map<String, dynamic>))
            .toList();
      }
      return null;
    } catch (e) {
      print('All prices error: $e');
      return null;
    }
  }

  /// Connect to real-time price WebSocket
  Future<void> connectPriceStream() async {
    try {
      final wsUrl = baseUrl.replaceFirst('http', 'ws');
      _priceChannel = WebSocketChannel.connect(
        Uri.parse('$wsUrl/ws/prices'),
      );

      _priceChannel.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data);
            if (json['type'] != 'heartbeat') {
              final price = PriceData.fromJson(json);
              _priceStream.add(price);
            }
          } catch (e) {
            print('Price parsing error: $e');
          }
        },
        onError: (error) {
          _statusStream.add('Price stream error: $error');
        },
        onDone: () {
          _statusStream.add('Price stream closed');
        },
      );

      _statusStream.add('Price stream connected');
    } catch (e) {
      _statusStream.add('Price connection error: $e');
    }
  }

  /// Connect to real-time ML signal WebSocket
  Future<void> connectSignalStream() async {
    try {
      final wsUrl = baseUrl.replaceFirst('http', 'ws');
      _signalChannel = WebSocketChannel.connect(
        Uri.parse('$wsUrl/ws/signals'),
      );

      _signalChannel.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data);
            if (json['type'] != 'heartbeat') {
              final signal = MLSignal.fromJson(json);
              _signalStream.add(signal);
            }
          } catch (e) {
            print('Signal parsing error: $e');
          }
        },
        onError: (error) {
          _statusStream.add('Signal stream error: $error');
        },
        onDone: () {
          _statusStream.add('Signal stream closed');
        },
      );

      _statusStream.add('Signal stream connected');
    } catch (e) {
      _statusStream.add('Signal connection error: $e');
    }
  }

  // ===== ML PREDICTIONS =====

  /// Get ML prediction for a symbol
  Future<MLSignal?> getPrediction({String symbol = 'EURUSD'}) async {
    try {
      final response = await httpClient.post(
        Uri.parse('$baseUrl/predict').replace(
          queryParameters: {'symbol': symbol},
        ),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return MLSignal.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('Prediction error: $e');
      return null;
    }
  }

  // ===== ORDER EXECUTION =====

  /// Place a market or limit order
  Future<OrderResponse?> placeOrder(OrderRequest order) async {
    try {
      final response = await httpClient.post(
        Uri.parse('$baseUrl/order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(order.toJson()),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final result = OrderResponse.fromJson(jsonDecode(response.body));
        _statusStream.add('Order placed: ${result.orderId}');
        return result;
      } else {
        _statusStream.add('Order failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _statusStream.add('Order error: $e');
      return null;
    }
  }

  /// Place a market order (convenience method)
  Future<OrderResponse?> placeMarketOrder(
    String symbol,
    String side,
    double volume,
  ) async {
    return placeOrder(
      OrderRequest(
        symbol: symbol,
        side: side,
        volume: volume,
        orderType: 'MARKET',
      ),
    );
  }

  /// Place a limit order (convenience method)
  Future<OrderResponse?> placeLimitOrder(
    String symbol,
    String side,
    double volume,
    double price,
  ) async {
    return placeOrder(
      OrderRequest(
        symbol: symbol,
        side: side,
        volume: volume,
        orderType: 'LIMIT',
        price: price,
      ),
    );
  }

  // ===== ACCOUNT MANAGEMENT =====

  /// Get account information
  Future<AccountInfo?> getAccountInfo() async {
    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/account'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return AccountInfo.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('Account info error: $e');
      return null;
    }
  }

  /// Get price history for technical analysis
  Future<List<Map<String, dynamic>>?> getPriceHistory(
    String symbol, {
    int limit = 100,
  }) async {
    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/history/$symbol').replace(
          queryParameters: {'limit': limit.toString()},
        ),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('History error: $e');
      return null;
    }
  }

  // ===== CLEANUP =====

  /// Disconnect from WebSocket streams
  Future<void> disconnect() async {
    try {
      await _priceChannel.sink.close();
    } catch (_) {}
    try {
      await _signalChannel.sink.close();
    } catch (_) {}
    _statusStream.add('Disconnected');
  }

  /// Dispose all resources
  void dispose() {
    disconnect();
    _priceStream.close();
    _signalStream.close();
    _statusStream.close();
    httpClient.close();
  }
}

// ===== EXAMPLE USAGE WIDGET =====

/*
import 'package:flutter/material.dart';

class TradingDashboard extends StatefulWidget {
  @override
  State<TradingDashboard> createState() => _TradingDashboardState();
}

class _TradingDashboardState extends State<TradingDashboard> {
  late TradingService tradingService;
  PriceData? currentPrice;
  MLSignal? latestSignal;
  AccountInfo? accountInfo;

  @override
  void initState() {
    super.initState();
    tradingService = TradingService();
    _initializeTrading();
  }

  Future<void> _initializeTrading() async {
    // Check connection
    bool connected = await tradingService.healthCheck();
    if (connected) {
      // Load account info
      accountInfo = await tradingService.getAccountInfo();
      setState(() {});

      // Start streaming prices and signals
      await tradingService.connectPriceStream();
      await tradingService.connectSignalStream();

      tradingService.priceUpdates.listen((price) {
        setState(() {
          currentPrice = price;
        });
      });

      tradingService.signalUpdates.listen((signal) {
        setState(() {
          latestSignal = signal;
        });
        _showSignalAlert(signal);
      });
    }
  }

  void _showSignalAlert(MLSignal signal) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Signal: ${signal.signal} ${signal.symbol} (${(signal.confidence * 100).toStringAsFixed(0)}%)'),
        backgroundColor: signal.signal == 'BUY' ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _placeOrder() async {
    if (latestSignal != null) {
      final response = await tradingService.placeMarketOrder(
        latestSignal!.symbol,
        latestSignal!.signal,
        0.1, // 0.1 lot
      );
      
      if (response != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tajir Trading')),
      body: Column(
        children: [
          if (currentPrice != null)
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('${currentPrice!.symbol}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    Text('Bid: ${currentPrice!.bid.toStringAsFixed(5)} | Ask: ${currentPrice!.ask.toStringAsFixed(5)}'),
                  ],
                ),
              ),
            ),
          if (latestSignal != null)
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('ML Signal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(latestSignal!.signal, style: TextStyle(fontSize: 20, color: latestSignal!.signal == 'BUY' ? Colors.green : Colors.red)),
                    Text('Confidence: ${(latestSignal!.confidence * 100).toStringAsFixed(0)}%'),
                  ],
                ),
              ),
            ),
          if (accountInfo != null)
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Balance: \$${accountInfo!.balance.toStringAsFixed(2)}'),
              ),
            ),
          ElevatedButton(
            onPressed: _placeOrder,
            child: Text('PLACE ORDER'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    tradingService.dispose();
    super.dispose();
  }
}
*/
