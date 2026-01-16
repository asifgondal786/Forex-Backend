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
  final Map<String, dynamic>? data;

  LiveUpdate({
    required this.id,
    required this.taskId,
    required this.message,
    required this.type,
    required this.timestamp,
    this.progress,
    this.data,
  });

  factory LiveUpdate.fromJson(Map<String, dynamic> json) {
    UpdateType parseType(String? typeStr) {
      if (typeStr == null) return UpdateType.info;
      return UpdateType.values.firstWhere(
        (e) => e.name == typeStr,
        orElse: () => UpdateType.info,
      );
    }

    return LiveUpdate(
      id: json['id'] as String? ?? '',
      taskId: json['task_id'] as String? ?? '',
      message: json['message'] as String? ?? 'No message',
      type: parseType(json['type'] as String?),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      progress: json['progress'] as double?,
      data: json['data'] as Map<String, dynamic>?,
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
      'data': data,
    };
  }
}
