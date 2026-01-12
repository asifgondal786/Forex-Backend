import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';
import '../core/models/live_update.dart';
import '../core/models/task.dart' as task_model;

class WebSocketService {
  // TODO: Replace with your actual WebSocket URL
  static const String wsUrl = 'ws://localhost:8000/ws';
  
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  
  final _updateController = StreamController<LiveUpdate>.broadcast();
  final _taskUpdateController = StreamController<task_model.Task>.broadcast();
  
  String? _userId;
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
  Future<void> connect({String? userId}) async {
    _userId = userId;
    _manualDisconnect = false; // Reset flag on new connection attempt
    try {
      final uri = Uri.parse(_userId != null ? '$wsUrl?user_id=$_userId' : wsUrl);
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
      debugPrint('WebSocket connected');
    } catch (e) {
      debugPrint('WebSocket connection error: $e');
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  // Handle incoming messages
  void _onMessage(dynamic message) {
    try {
      final data = json.decode(message as String);
      final type = data['type'] as String?;

      switch (type) {
        case 'live_update':
          final update = LiveUpdate.fromJson(data['data']);
          _updateController.add(update);
          break;
        
        case 'task_update':
          final task = task_model.Task.fromJson(data['data']);
          _taskUpdateController.add(task);
          break;
        
        default:
          debugPrint('Unknown message type: $type');
      }
    } catch (e) {
      debugPrint('Error parsing WebSocket message: $e');
    }
  }

  // Handle errors
  void _onError(dynamic error) {
    debugPrint('WebSocket error: $error');
    _isConnected = false;
    _scheduleReconnect();
  }

  // Handle connection close
  void _onDone() {
    debugPrint('WebSocket connection closed');
    _isConnected = false;
    if (!_manualDisconnect) {
      _scheduleReconnect();
    }
  }

  // Schedule reconnection
  void _scheduleReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      debugPrint('Max reconnect attempts reached');
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(reconnectDelay, () {
      _reconnectAttempts++;
      debugPrint('Reconnecting... Attempt $_reconnectAttempts');
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
        debugPrint('Error sending message: $e');
      }
    } else {
      debugPrint('Cannot send message: WebSocket not connected');
    }
  }

  // Subscribe to task updates
  void subscribeToTask(String taskId) {
    send({
      'type': 'subscribe',
      'task_id': taskId,
    });
  }

  // Unsubscribe from task updates
  void unsubscribeFromTask(String taskId) {
    send({
      'type': 'unsubscribe',
      'task_id': taskId,
    });
  }

  // Disconnect and cleanup
  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    _isConnected = false;
    debugPrint('WebSocket disconnected');
  }

  // Dispose
  Future<void> dispose() async {
    await disconnect();
    await _updateController.close();
    await _taskUpdateController.close();
  }
}