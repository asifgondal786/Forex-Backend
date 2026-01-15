import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logging/logging.dart'; // Suggested: Add `logging: ^1.1.0` to pubspec.yaml
import 'package:tajir/core/models/live_update.dart';

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
    defaultValue: 'ws://localhost:8000',
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

    final wsUrl = '$_baseUrl/api/updates/ws/$_currentTaskId';
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

// To use the logger, add this to your main.dart before runApp():
/*
void configureLogger() {
  Logger.root.level = Level.ALL; // Set the desired log level
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}');
    if (record.error != null) {
      print('ERROR: ${record.error}, ${record.stackTrace}');
    }
  });
}
*/

// Example Widget using the service
/*
class LiveUpdatesWidget extends StatefulWidget {
  final String taskId;
  
  const LiveUpdatesWidget({Key? key, required this.taskId}) : super(key: key);
  
  @override
  State<LiveUpdatesWidget> createState() => _LiveUpdatesWidgetState();
}

class _LiveUpdatesWidgetState extends State<LiveUpdatesWidget> {
  final _service = LiveUpdateService();
  final List<LiveUpdate> _updates = [];
  
  @override
  void initState() {
    super.initState();
    _connectToUpdates();
  }
  
  void _connectToUpdates() {
    _service.connect(widget.taskId);
    
    _service.updates.listen((update) {
      if (mounted) {
        setState(() {
          _updates.add(update);
        });
      }
    });
  }
  
  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Connection status
        StreamBuilder<ConnectionStatus>(
          stream: _service.connectionStatus,
          initialData: ConnectionStatus.disconnected,
          builder: (context, snapshot) {
            final status = snapshot.data ?? ConnectionStatus.disconnected;
            Color color;
            String text;
            switch (status) {
              case ConnectionStatus.connected:
                color = Colors.green;
                text = 'Connected';
                break;
              case ConnectionStatus.connecting:
              case ConnectionStatus.reconnecting:
                color = Colors.orange;
                text = 'Connecting...';
                break;
              case ConnectionStatus.disconnected:
                color = Colors.red;
                text = 'Disconnected';
                break;
            }
            return Container(
              padding: EdgeInsets.all(8),
              color: color,
              child: Text(
                text,
                style: TextStyle(color: Colors.white),
              ),
            );
          },
        ),
        
        // Updates list
        Expanded(
          child: ListView.builder(
            itemCount: _updates.length,
            itemBuilder: (context, index) {
              final update = _updates[index];
              return _buildUpdateTile(update);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildUpdateTile(LiveUpdate update) {
    Color color;
    IconData icon;
    
    switch (update.type) {
      case UpdateType.success:
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case UpdateType.error:
        color = Colors.red;
        icon = Icons.error;
        break;
      case UpdateType.warning:
        color = Colors.orange;
        icon = Icons.warning;
        break;
      case UpdateType.progress:
        color = Colors.blue;
        icon = Icons.hourglass_empty;
        break;
      default:
        color = Colors.grey;
        icon = Icons.info;
    }
    
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(update.message),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(update.timestamp.toString()),
          if (update.progress != null)
            LinearProgressIndicator(value: update.progress),
        ],
      ),
    );
  }
}
*/
      _scheduleReconnect();
    }
  }
  
  void _handleMessage(dynamic message) {
    try {
      final data = message is String ? jsonDecode(message) : message;
      
      // Handle pong response
      if (data == 'pong') {
        return;
      }
      
      // Parse update
      final update = LiveUpdate.fromJson(data as Map<String, dynamic>);
      _updateController.add(update);
      
    } catch (e) {
      print('Error parsing message: $e');
    }
  }
  
  void _handleError(dynamic error) {
    print('WebSocket error: $error');
    _isConnected = false;
    _scheduleReconnect();
  }
  
  void _handleDisconnect() {
    print('WebSocket disconnected');
    _isConnected = false;
    _stopPingTimer();
    _scheduleReconnect();
  }
  
  void _scheduleReconnect() {
    if (_currentTaskId == null) return;
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(reconnectDelay, () {
      if (_currentTaskId != null && !_isConnected) {
        print('Attempting to reconnect...');
        _connect(_currentTaskId!);
      }
    });
  }
  
  void _startPingTimer() {
    _stopPingTimer();
    _pingTimer = Timer.periodic(pingInterval, (_) {
      if (_isConnected) {
        try {
          _channel?.sink.add('ping');
        } catch (e) {
          print('Ping error: $e');
        }
      }
    });
  }
  
  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }
  
  /// Disconnect from live updates
  Future<void> disconnect() async {
    _stopPingTimer();
    _reconnectTimer?.cancel();
    _currentTaskId = null;
    _isConnected = false;
    
    try {
      await _channel?.sink.close();
    } catch (e) {
      print('Error closing connection: $e');
    }
    
    _channel = null;
  }
  
  /// Dispose resources
  void dispose() {
    disconnect();
    _updateController.close();
  }
}


// Example Widget using the service
/*
class LiveUpdatesWidget extends StatefulWidget {
  final String taskId;
  
  const LiveUpdatesWidget({Key? key, required this.taskId}) : super(key: key);
  
  @override
  State<LiveUpdatesWidget> createState() => _LiveUpdatesWidgetState();
}

class _LiveUpdatesWidgetState extends State<LiveUpdatesWidget> {
  final _service = LiveUpdateService();
  final List<LiveUpdate> _updates = [];
  
  @override
  void initState() {
    super.initState();
    _connectToUpdates();
  }
  
  void _connectToUpdates() {
    _service.connect(widget.taskId);
    
    _service.updates.listen((update) {
      setState(() {
        _updates.add(update);
      });
    });
  }
  
  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Connection status
        Container(
          padding: EdgeInsets.all(8),
          color: _service.isConnected ? Colors.green : Colors.red,
          child: Text(
            _service.isConnected ? 'Connected' : 'Disconnected',
            style: TextStyle(color: Colors.white),
          ),
        ),
        
        // Updates list
        Expanded(
          child: ListView.builder(
            itemCount: _updates.length,
            itemBuilder: (context, index) {
              final update = _updates[index];
              return _buildUpdateTile(update);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildUpdateTile(LiveUpdate update) {
    Color color;
    IconData icon;
    
    switch (update.type) {
      case UpdateType.success:
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case UpdateType.error:
        color = Colors.red;
        icon = Icons.error;
        break;
      case UpdateType.warning:
        color = Colors.orange;
        icon = Icons.warning;
        break;
      case UpdateType.progress:
        color = Colors.blue;
        icon = Icons.hourglass_empty;
        break;
      default:
        color = Colors.grey;
        icon = Icons.info;
    }
    
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(update.message),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(update.timestamp.toString()),
          if (update.progress != null)
            LinearProgressIndicator(value: update.progress),
        ],
      ),
    );
  }
}
*/