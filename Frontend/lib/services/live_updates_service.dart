import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class LiveUpdate {
  final String pair;
  final double price;
  final double change;
  final double changePercent;
  final DateTime timestamp;
  final String trend; // "UP", "DOWN", "STABLE"
  
  LiveUpdate({
    required this.pair,
    required this.price,
    required this.change,
    required this.changePercent,
    required this.timestamp,
    required this.trend,
  });
  
  factory LiveUpdate.fromJson(Map<String, dynamic> json) {
    return LiveUpdate(
      pair: json['pair'] ?? 'N/A',
      price: (json['price'] ?? 0).toDouble(),
      change: (json['change'] ?? 0).toDouble(),
      changePercent: (json['change_percent'] ?? 0).toDouble(),
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'].toString())
          : DateTime.now(),
      trend: json['trend'] ?? 'STABLE',
    );
  }
}

class LiveUpdatesService {
  static const String _wsBaseUrl = 'ws://127.0.0.1:8080';
  
  WebSocketChannel? _channel;
  final _updatesController = StreamController<LiveUpdate>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  
  Stream<LiveUpdate> get updates => _updatesController.stream;
  Stream<bool> get connectionStatus => _connectionController.stream;
  
  bool get isConnected => _channel != null;
  
  /// Connect to live updates WebSocket
  Future<void> connect(String userId) async {
    try {
      if (_channel != null) {
        await disconnect();
      }
      
      final wsUrl = '$_wsBaseUrl/api/live-updates/$userId';
      debugPrint('🔌 Connecting to: $wsUrl');
      
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _connectionController.add(true);
      debugPrint('✅ Live updates connected');
      
      // Listen for messages
      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            if (data is Map) {
              final update = LiveUpdate.fromJson(data);
              _updatesController.add(update);
            }
          } catch (e) {
            debugPrint('⚠️ Parse error: $e');
          }
        },
        onError: (error) {
          debugPrint('❌ WebSocket error: $error');
          _connectionController.add(false);
        },
        onDone: () {
          debugPrint('⚠️ WebSocket closed');
          _connectionController.add(false);
        },
      );
    } catch (e) {
      debugPrint('❌ Connection error: $e');
      _connectionController.add(false);
    }
  }
  
  /// Send subscription for specific pairs
  void subscribeToPairs(List<String> pairs) {
    if (_channel != null) {
      try {
        _channel!.sink.add(jsonEncode({
          'action': 'subscribe',
          'pairs': pairs,
        }));
        debugPrint('📡 Subscribed to: $pairs');
      } catch (e) {
        debugPrint('❌ Subscribe error: $e');
      }
    }
  }
  
  /// Unsubscribe from pairs
  void unsubscribeFromPairs(List<String> pairs) {
    if (_channel != null) {
      try {
        _channel!.sink.add(jsonEncode({
          'action': 'unsubscribe',
          'pairs': pairs,
        }));
        debugPrint('📡 Unsubscribed from: $pairs');
      } catch (e) {
        debugPrint('❌ Unsubscribe error: $e');
      }
    }
  }
  
  /// Disconnect from WebSocket
  Future<void> disconnect() async {
    try {
      if (_channel != null) {
        await _channel!.sink.close();
        _channel = null;
        _connectionController.add(false);
        debugPrint('🔌 Disconnected from live updates');
      }
    } catch (e) {
      debugPrint('❌ Disconnect error: $e');
    }
  }
  
  /// Dispose resources
  void dispose() {
    disconnect();
    _updatesController.close();
    _connectionController.close();
  }
}
