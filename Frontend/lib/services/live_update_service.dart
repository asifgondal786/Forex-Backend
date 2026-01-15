import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'live_updates.dart';

class LiveUpdateService {
  WebSocketChannel? _channel;
  final _updateController = StreamController<LiveUpdate>.broadcast();
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _isConnected = false;
  String? _currentTaskId;
  
  // Configuration
  final String baseUrl;
  final Duration reconnectDelay;
  final Duration pingInterval;
  
  LiveUpdateService({
    this.baseUrl = 'ws://localhost:8000',
    this.reconnectDelay = const Duration(seconds: 3),
    this.pingInterval = const Duration(seconds: 30),
  });
  
  /// Stream of live updates
  Stream<LiveUpdate> get updates => _updateController.stream;
  
  /// Check if connected
  bool get isConnected => _isConnected;
  
  /// Connect to a task's live updates
  Future<void> connect(String taskId) async {
    _currentTaskId = taskId;
    await _connect(taskId);
  }
  
  Future<void> _connect(String taskId) async {
    try {
      // Close existing connection
      await disconnect();
      
      // Create WebSocket connection
      final wsUrl = '$baseUrl/api/updates/ws/$taskId';
      print('Connecting to: $wsUrl');
      
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;
      
      // Listen to messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );
      
      // Start ping timer to keep connection alive
      _startPingTimer();
      
      print('Connected to live updates for task: $taskId');
      
    } catch (e) {
      print('Connection error: $e');
      _isConnected = false;
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