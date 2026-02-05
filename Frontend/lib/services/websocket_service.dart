import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';
import '../core/models/live_update.dart';
import '../core/models/task.dart' as task_model;

class WebSocketService {
  static const String wsUrl = 'ws://localhost:8080/api/ws';
  
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  
  final _updateController = StreamController<LiveUpdate>.broadcast();
  final _taskUpdateController = StreamController<task_model.Task>.broadcast();
  
  String? _userId;
  String? _taskId;
  bool _manualDisconnect = false;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectDelay = Duration(seconds: 5);

  // Getters
  Stream<LiveUpdate> get updateStream => _updateController.stream;
  Stream<task_model.Task> get taskUpdateStream => _taskUpdateController.stream;
  bool get isConnected => _isConnected;

  // Connect to WebSocket
  Future<void> connect({String? userId, String? taskId}) async {
    _userId = userId;
    _taskId = taskId;
    _manualDisconnect = false; // Reset flag on new connection attempt
    try {
      final uri = Uri.parse(
        _taskId != null
            ? '$wsUrl/$_taskId'
            : (_userId != null ? '$wsUrl?user_id=$_userId' : wsUrl),
      );
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      
      _subscription = channel.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
      
      _isConnected = true;
      _reconnectAttempts = 0;
      if (kDebugMode) {
        debugPrint('WebSocket connected');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('WebSocket connection error: $e');
      }
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  // Handle incoming messages
  void _onMessage(dynamic message) {
    try {
      final data = json.decode(message as String);
      final type = data['type'] as String?;

      if (type == 'live_update' && data['data'] is Map<String, dynamic>) {
        final update = LiveUpdate.fromJson(data['data']);
        _updateController.add(update);
      } else if (type == 'task_update' && data['data'] is Map<String, dynamic>) {
        final task = task_model.Task.fromJson(data['data']);
        _taskUpdateController.add(task);
      } else if (data.containsKey('task_id')) {
        // Backend sends updates directly without wrapping
        final update = LiveUpdate.fromJson(data);
        _updateController.add(update);
      } else {
        if (kDebugMode) {
          debugPrint('Unknown message type: $type');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error parsing WebSocket message: $e');
      }
    }
  }

  // Handle errors
  void _onError(dynamic error) {
    if (kDebugMode) {
      debugPrint('WebSocket error: $error');
    }
    _isConnected = false;
    _scheduleReconnect();
  }

  // Handle connection close
  void _onDone() {
    if (kDebugMode) {
      debugPrint('WebSocket connection closed');
    }
    _isConnected = false;
    if (!_manualDisconnect) {
      _scheduleReconnect();
    }
  }

  // Schedule reconnection
  void _scheduleReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      if (kDebugMode) {
        debugPrint('Max reconnect attempts reached');
      }
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(reconnectDelay, () {
      _reconnectAttempts++;
      if (kDebugMode) {
        debugPrint('Reconnecting... Attempt $_reconnectAttempts');
      }
      connect(userId: _userId);
    });
  }

  // Send message
  void send(Map<String, dynamic> message) {
    final channel = _channel;
    if (_isConnected && channel != null) {
      try {
        channel.sink.add(json.encode(message));
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error sending message: $e');
        }
      }
    } else {
      if (kDebugMode) {
        debugPrint('Cannot send message: WebSocket not connected');
      }
    }
  }

  // Subscribe to task updates
  void subscribeToTask(String taskId) {
    _taskId = taskId;
    if (_isConnected) {
      disconnect().then((_) => connect(userId: _userId, taskId: taskId));
    } else {
      connect(userId: _userId, taskId: taskId);
    }
  }

  // Unsubscribe from task updates
  void unsubscribeFromTask(String taskId) {
    if (_taskId == taskId) {
      _taskId = null;
      disconnect().then((_) => connect(userId: _userId));
    }
  }

  // Disconnect and cleanup
  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    _isConnected = false;
    if (kDebugMode) {
      debugPrint('WebSocket disconnected');
    }
  }

  // Dispose
  Future<void> dispose() async {
    await disconnect();
    await _updateController.close();
    await _taskUpdateController.close();
  }
}
