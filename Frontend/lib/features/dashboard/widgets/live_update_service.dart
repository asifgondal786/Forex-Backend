import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/models/live_update.dart';

enum ConnectionStatus {
  connected,
  connecting,
  reconnecting,
  disconnected,
}

class LiveUpdateService {
  final _updatesController = StreamController<LiveUpdate>.broadcast();
  final _connectionStatusController =
      StreamController<ConnectionStatus>.broadcast();

  String? _currentTaskId;
  Timer? _simulationTimer;
  ConnectionStatus _status = ConnectionStatus.disconnected;

  Stream<LiveUpdate> get updates => _updatesController.stream;
  Stream<ConnectionStatus> get connectionStatus =>
      _connectionStatusController.stream;

  // Connect to a specific task's updates
  void connect(String taskId) {
    if (_currentTaskId == taskId && _status == ConnectionStatus.connected) {
      return; // Already connected to this task
    }

    // Disconnect from previous task
    if (_currentTaskId != null && _currentTaskId != taskId) {
      _disconnect();
    }

    _currentTaskId = taskId;
    _updateStatus(ConnectionStatus.connecting);

    // Simulate connection delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_currentTaskId == taskId) {
        _updateStatus(ConnectionStatus.connected);
        _startSimulation();
      }
    });
  }

  void _updateStatus(ConnectionStatus status) {
    _status = status;
    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.add(status);
    }
  }

  void _disconnect() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _updateStatus(ConnectionStatus.disconnected);
  }

  // Simulate live updates for development/testing
  void _startSimulation() {
    _simulationTimer?.cancel();

    int updateCount = 0;
    final messages = [
      'Initializing AI model...',
      'Fetching market data from API...',
      'Analyzing forex trends...',
      'Processing historical data...',
      'Generating predictions...',
      'Calculating risk metrics...',
      'Applying machine learning algorithms...',
      'Validating results...',
      'Preparing summary report...',
      'Finalizing analysis...',
    ];

    final types = [
      UpdateType.info,
      UpdateType.progress,
      UpdateType.progress,
      UpdateType.info,
      UpdateType.progress,
      UpdateType.warning,
      UpdateType.progress,
      UpdateType.info,
      UpdateType.success,
      UpdateType.success,
    ];

    _simulationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_currentTaskId == null || _connectionStatusController.isClosed) {
        timer.cancel();
        return;
      }

      final index = updateCount % messages.length;
      final update = LiveUpdate(
        id: 'update_${DateTime.now().millisecondsSinceEpoch}',
        taskId: _currentTaskId!,
        message: messages[index],
        type: types[index],
        timestamp: DateTime.now(),
        progress: index < 5 ? (index + 1) * 0.2 : null,
      );

      if (!_updatesController.isClosed) {
        _updatesController.add(update);
      }

      updateCount++;

      // Simulate completion after 10 updates
      if (updateCount >= messages.length) {
        timer.cancel();
        Future.delayed(const Duration(seconds: 2), () {
          if (!_updatesController.isClosed && _currentTaskId != null) {
            _updatesController.add(LiveUpdate(
              id: 'final_${DateTime.now().millisecondsSinceEpoch}',
              taskId: _currentTaskId!,
              message: 'Task completed successfully!',
              type: UpdateType.success,
              timestamp: DateTime.now(),
              progress: 1.0,
            ));
          }
        });
      }
    });
  }

  void dispose() {
    _disconnect();
    _updatesController.close();
    _connectionStatusController.close();
  }
}