import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logging/logging.dart'; // Suggested: Add `logging: ^1.1.0` to pubspec.yaml
import '../core/models/live_update.dart';

// It's good practice to use a proper logger instead of print()
final _log = Logger('LiveUpdateService');

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class LiveUpdateService {
  WebSocketChannel? _channel;
  final _updateController = StreamController<LiveUpdate>.broadcast();
  final _connectionStatusController =
      StreamController<ConnectionStatus>.broadcast();

  Timer? _reconnectTimer;
  Timer? _pingTimer;

  String? _currentTaskId;
  bool _isDisposed = false;
  bool _explicitlyDisconnected = false;
  int _reconnectAttempts = 0;

  // Configuration
  // Use --dart-define=WS_BASE_URL=ws://your.server.com for production
  static const String _baseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://127.0.0.1:8000',
  );
  final Duration _minReconnectDelay;
  final Duration _maxReconnectDelay;
  final Duration pingInterval;

  LiveUpdateService({
    Duration? minReconnectDelay,
    Duration? maxReconnectDelay,
    this.pingInterval = const Duration(seconds: 30),
  })  : _minReconnectDelay = minReconnectDelay ?? const Duration(seconds: 2),
        _maxReconnectDelay = maxReconnectDelay ?? const Duration(seconds: 30) {
    _connectionStatusController.add(ConnectionStatus.disconnected);
  }

  /// Stream of live updates
  Stream<LiveUpdate> get updates => _updateController.stream;

  /// Stream of connection status
  Stream<ConnectionStatus> get connectionStatus =>
      _connectionStatusController.stream;

  /// Connect to a task's live updates
  Future<void> connect(String taskId) async {
    if (_currentTaskId == taskId && _channel != null) {
      _log.info('Already connected or connecting to task: $taskId');
      return;
    }

    _currentTaskId = taskId;
    _explicitlyDisconnected = false;
    _reconnectAttempts = 0;

    await _connect();
  }

  Future<void> _connect() async {
    if (_explicitlyDisconnected || _isDisposed) return;

    _updateConnectionStatus(ConnectionStatus.connecting);

    // Close any existing connection before creating a new one.
    await _closeChannel();

    final wsUrl = '$_baseUrl/api/ws/$_currentTaskId';
    _log.info('Connecting to: $wsUrl');

    try {
      // Create WebSocket connection
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Listen to messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );

      // The connection is considered successful once the stream is established.
      _onConnected();
    } catch (e) {
      _handleError(e);
    }
  }

  void _onConnected() {
    _log.info('Connected to live updates for task: $_currentTaskId');
    _updateConnectionStatus(ConnectionStatus.connected);
    _reconnectAttempts = 0;
    _cancelReconnectTimer();
    _startPingTimer();
  }

  void _handleMessage(dynamic message) {
    try {
      if (message == 'pong') {
        _log.fine('Received pong');
        return;
      }

      final data = jsonDecode(message as String);
      final update = LiveUpdate.fromJson(data as Map<String, dynamic>);
      if (!_updateController.isClosed) {
        _updateController.add(update);
      }
    } catch (e, stackTrace) {
      _log.severe('Error parsing message: $e', e, stackTrace);
    }
  }

  void _handleError(dynamic error) {
    _log.warning('WebSocket error: $error');
    _updateConnectionStatus(ConnectionStatus.reconnecting);
    _scheduleReconnect();
  }

  void _handleDisconnect() {
    _log.info('WebSocket disconnected');
    _updateConnectionStatus(ConnectionStatus.reconnecting);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_explicitlyDisconnected || _isDisposed) return;

    _stopPingTimer();
    _cancelReconnectTimer();

    final delay = _minReconnectDelay * pow(2, _reconnectAttempts);
    final reconnectDelay = delay < _maxReconnectDelay ? delay : _maxReconnectDelay;

    _reconnectAttempts++;

    _log.info(
        'Attempting to reconnect in ${reconnectDelay.inSeconds} seconds (attempt $_reconnectAttempts)...');
    _reconnectTimer = Timer(reconnectDelay, _connect);
  }

  void _startPingTimer() {
    _stopPingTimer();
    _pingTimer = Timer.periodic(pingInterval, (_) {
      if (_channel?.sink != null) {
        try {
          _log.fine('Sending ping');
          _channel?.sink.add('ping');
        } catch (e) {
          _log.warning('Ping error: $e. Scheduling reconnect.');
          _handleError(e);
        }
      }
    });
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _updateConnectionStatus(ConnectionStatus status) {
    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.add(status);
    }
  }

  Future<void> _closeChannel() async {
    try {
      await _channel?.sink.close();
    } catch (e) {
      _log.warning('Error closing previous connection: $e');
    }
    _channel = null;
  }

  /// Disconnect from live updates
  Future<void> disconnect() async {
    _log.info('Disconnecting from live updates.');
    _explicitlyDisconnected = true;
    _currentTaskId = null;
    _stopPingTimer();
    _cancelReconnectTimer();
    await _closeChannel();
    _updateConnectionStatus(ConnectionStatus.disconnected);
  }

  /// Dispose resources
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    disconnect();
    _updateController.close();
    _connectionStatusController.close();
    _log.info('LiveUpdateService disposed.');
  }
}