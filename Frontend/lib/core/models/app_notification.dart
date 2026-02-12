class AppNotification {
  final String id;
  final String title;
  final String message;
  final String category;
  final String priority;
  final DateTime? timestamp;
  final bool read;
  final bool clicked;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.priority,
    required this.timestamp,
    required this.read,
    required this.clicked,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawRead = json['read'] ?? json['is_read'] ?? json['isRead'];
    final rawClicked = json['clicked'] ?? json['is_clicked'] ?? json['isClicked'];
    final timestamp = _parseTimestamp(json['timestamp']);

    return AppNotification(
      id: (json['notification_id'] ??
              json['notificationId'] ??
              json['id'] ??
              '')
          .toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      priority: (json['priority'] ?? '').toString(),
      timestamp: timestamp,
      read: rawRead == true,
      clicked: rawClicked == true,
    );
  }

  AppNotification copyWith({bool? read, bool? clicked}) {
    return AppNotification(
      id: id,
      title: title,
      message: message,
      category: category,
      priority: priority,
      timestamp: timestamp,
      read: read ?? this.read,
      clicked: clicked ?? this.clicked,
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    if (value is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
