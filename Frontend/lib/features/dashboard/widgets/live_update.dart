enum UpdateType {
  info,
  success,
  warning,
  error,
  progress,
}

class LiveUpdate {
  final String id;
  final String taskId;
  final String message;
  final UpdateType type;
  final DateTime timestamp;
  final double? progress;

  LiveUpdate({
    required this.id,
    required this.taskId,
    required this.message,
    required this.type,
    required this.timestamp,
    this.progress,
  });

  factory LiveUpdate.fromJson(Map<String, dynamic> json) {
    return LiveUpdate(
      id: json['id'] as String,
      taskId: json['task_id'] as String,
      message: json['message'] as String,
      type: _parseUpdateType(json['type'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      progress: (json['progress'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_id': taskId,
      'message': message,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'progress': progress,
    };
  }

  static UpdateType _parseUpdateType(String type) {
    switch (type.toLowerCase()) {
      case 'info':
        return UpdateType.info;
      case 'success':
        return UpdateType.success;
      case 'warning':
        return UpdateType.warning;
      case 'error':
        return UpdateType.error;
      case 'progress':
        return UpdateType.progress;
      default:
        return UpdateType.info;
    }
  }
}