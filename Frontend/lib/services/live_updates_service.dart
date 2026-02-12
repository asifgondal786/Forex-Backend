import 'dart:async';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

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
}

class NotificationUpdate {
  final String notificationId;
  final String userId;
  final String title;
  final String message;
  final String? shortMessage;
  final String category;
  final String priority;
  final DateTime timestamp;
  final bool read;
  final String? actionUrl;
  final Map<String, dynamic> richData;

  NotificationUpdate({
    required this.notificationId,
    required this.userId,
    required this.title,
    required this.message,
    this.shortMessage,
    required this.category,
    required this.priority,
    required this.timestamp,
    required this.read,
    this.actionUrl,
    required this.richData,
  });

  factory NotificationUpdate.fromJson(Map<String, dynamic> json) {
    return NotificationUpdate(
      notificationId: json['notification_id'] ?? '',
      userId: json['user_id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      shortMessage: json['short_message'],
      category: json['category'] ?? '',
      priority: json['priority'] ?? 'medium',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      read: json['read'] ?? false,
      actionUrl: json['action_url'],
      richData: Map<String, dynamic>.from(json['rich_data'] ?? {}),
    );
  }
}

class LiveUpdatesService {
  static const String _wsBaseUrl = 'ws://127.0.0.1:8080';
  static const String _devUserId = String.fromEnvironment(
    'DEV_USER_ID',
    defaultValue: '',
  );

  WebSocketChannel? _channel;
  final _updatesController = StreamController<LiveUpdate>.broadcast();
  final _notificationsController = StreamController<NotificationUpdate>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final Map<String, double> _lastRates = {};

  Stream<LiveUpdate> get updates => _updatesController.stream;
  Stream<NotificationUpdate> get notifications => _notificationsController.stream;
  Stream<bool> get connectionStatus => _connectionController.stream;

  bool get isConnected => _channel != null;

  /// Connect to live updates WebSocket (global stream).
  Future<void> connect() async {
    try {
      if (_channel != null) {
        await disconnect();
      }

      String? token;
      try {
        final user = firebase_auth.FirebaseAuth.instance.currentUser;
        if (user != null) {
          token = await user.getIdToken();
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Live updates token fetch failed: $e');
        }
      }

      final params = <String, String>{};
      if (_devUserId.isNotEmpty) {
        params['user_id'] = _devUserId;
      }
      if (token != null && token.isNotEmpty) {
        params['token'] = token;
      }
      if (params.isEmpty) {
        debugPrint('Live updates auth token missing. Connect aborted.');
        _connectionController.add(false);
        return;
      }

      final wsUrl = Uri.parse('$_wsBaseUrl/api/ws').replace(queryParameters: params).toString();
      debugPrint('Connecting to: $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _connectionController.add(true);
      debugPrint('Live updates connected');

      // Listen for messages
      _channel!.stream.listen(
        (message) {
          try {
            if (message == 'pong') {
              return;
            }
            final decoded = jsonDecode(message);
            if (decoded is Map<String, dynamic>) {
              final updateType = decoded['type'];
              
              // Handle notification updates
              if (updateType == 'notification') {
                final data = decoded['data'];
                if (data is Map<String, dynamic>) {
                  final notification = NotificationUpdate.fromJson(data);
                  if (!_notificationsController.isClosed) {
                    _notificationsController.add(notification);
                  }
                  debugPrint('Notification received: ${notification.title}');
                }
              } 
              // Handle forex rate updates
              else {
                final data = decoded['data'];
                if (data is Map<String, dynamic>) {
                  final rates = data['rates'];
                  if (rates is Map<String, dynamic>) {
                    _emitRateUpdates(rates);
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('Parse error: $e');
          }
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _connectionController.add(false);
        },
        onDone: () {
          debugPrint('WebSocket closed');
          _connectionController.add(false);
        },
      );
    } catch (e) {
      debugPrint('Connection error: $e');
      _connectionController.add(false);
    }
  }

  /// Send subscription for specific pairs (client-side filter).
  void subscribeToPairs(List<String> pairs) {
    debugPrint('Subscribed to: $pairs');
  }

  /// Unsubscribe from pairs (client-side filter).
  void unsubscribeFromPairs(List<String> pairs) {
    debugPrint('Unsubscribed from: $pairs');
  }

  void _emitRateUpdates(Map<String, dynamic> rates) {
    rates.forEach((pair, value) {
      final price = (value as num?)?.toDouble() ?? 0.0;
      final last = _lastRates[pair];
      final change = last != null ? price - last : 0.0;
      final changePercent = last != null && last != 0.0
          ? (change / last) * 100
          : 0.0;
      final trend = change > 0
          ? 'UP'
          : change < 0
              ? 'DOWN'
              : 'STABLE';

      _lastRates[pair] = price;

      final update = LiveUpdate(
        pair: pair,
        price: price,
        change: change,
        changePercent: changePercent,
        timestamp: DateTime.now(),
        trend: trend,
      );

      if (!_updatesController.isClosed) {
        _updatesController.add(update);
      }
    });
  }

  /// Disconnect from WebSocket
  Future<void> disconnect() async {
    try {
      if (_channel != null) {
        await _channel!.sink.close();
        _channel = null;
        _connectionController.add(false);
        debugPrint('Disconnected from live updates');
      }
    } catch (e) {
      debugPrint('Disconnect error: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _updatesController.close();
    _notificationsController.close();
    _connectionController.close();
  }
}
