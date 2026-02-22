class AppNotification {
  final String id;
  final String title;
  final String message;
  final String category;
  final String priority;
  final DateTime? timestamp;
  final bool read;
  final bool clicked;
  final Map<String, dynamic> richData;
  final List<String> channelsToSend;
  final Map<String, String> deliveryStatus;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.priority,
    required this.timestamp,
    required this.read,
    required this.clicked,
    required this.richData,
    required this.channelsToSend,
    required this.deliveryStatus,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawRead = json['read'] ?? json['is_read'] ?? json['isRead'];
    final rawClicked = json['clicked'] ?? json['is_clicked'] ?? json['isClicked'];
    final timestamp = _parseTimestamp(json['timestamp']);
    final richData = _parseMap(json['rich_data'] ?? json['richData']);
    final channelsToSend =
        _parseStringList(json['channels_to_send'] ?? json['channelsToSend']);
    final deliveryStatus = _parseStringMap(
      json['delivery_status'] ?? json['deliveryStatus'],
    );

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
      richData: richData,
      channelsToSend: channelsToSend,
      deliveryStatus: deliveryStatus,
    );
  }

  AppNotification copyWith({
    bool? read,
    bool? clicked,
    Map<String, dynamic>? richData,
    List<String>? channelsToSend,
    Map<String, String>? deliveryStatus,
  }) {
    return AppNotification(
      id: id,
      title: title,
      message: message,
      category: category,
      priority: priority,
      timestamp: timestamp,
      read: read ?? this.read,
      clicked: clicked ?? this.clicked,
      richData: richData ?? this.richData,
      channelsToSend: channelsToSend ?? this.channelsToSend,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
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

  static Map<String, dynamic> _parseMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      final result = <String, dynamic>{};
      value.forEach((key, val) {
        result[key.toString()] = val;
      });
      return result;
    }
    return <String, dynamic>{};
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value.map((entry) => entry.toString()).toList();
    }
    return <String>[];
  }

  static Map<String, String> _parseStringMap(dynamic value) {
    if (value is Map) {
      final result = <String, String>{};
      value.forEach((key, val) {
        result[key.toString()] = val?.toString() ?? '';
      });
      return result;
    }
    return <String, String>{};
  }
}
