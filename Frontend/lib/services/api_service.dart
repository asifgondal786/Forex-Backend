import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../core/models/task.dart';
import '../core/models/user.dart';
import '../core/models/header_model.dart';
import '../core/models/app_notification.dart';
import '../core/models/account_connection.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ApiService {
  // Backend URL - matches your backend port
  // Use --dart-define=API_BASE_URL=http://your.server:port for production
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8080',
  );
  static const Duration _timeout = Duration(seconds: 10);
  // Use --dart-define=DEV_USER_ID=your-user-id for development
  static const String _devUserId = String.fromEnvironment(
    'DEV_USER_ID',
    defaultValue: '',
  );
  
  // Default dev user ID for local development when no Firebase auth
  static const String _defaultDevUserId = 'dev_user_001';
  
  final http.Client _client = http.Client();

  Map<String, String> get _baseHeaders => {
        'Content-Type': 'application/json; charset=UTF-8',
      };

  Future<Map<String, String>> _buildHeaders() async {
    final headers = <String, String>{..._baseHeaders};

    // Use dev user ID from environment or default for development
    final devUserId = _devUserId.isNotEmpty ? _devUserId : _defaultDevUserId;
    headers['x-user-id'] = devUserId;

    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        headers['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Auth header skipped: $e');
      }
    }

    return headers;
  }

  dynamic _handleResponse(http.Response response) {
    if (kDebugMode) {
      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');
    }
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return json.decode(utf8.decode(response.bodyBytes));
    } else {
      throw ApiException(
        'API Error: ${response.statusCode} - ${response.reasonPhrase}',
        response.statusCode,
      );
    }
  }

  // ========== USER ENDPOINTS ==========

  Future<User> getCurrentUser() async {
    try {
      final headers = await _buildHeaders();
      final response = await _client.get(
        Uri.parse('$baseUrl/api/users/me'),
        headers: headers,
      ).timeout(_timeout);
      final data = _handleResponse(response);
      return User.fromJson(data);
    } catch (e) {
      debugPrint('Error fetching user: $e');
      throw ApiException('Error fetching user: $e');
    }
  }

  Future<User> updateUser({String? name, String? email}) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (email != null) body['email'] = email;

      final headers = await _buildHeaders();
      final response = await _client.put(
        Uri.parse('$baseUrl/api/users/me'),
        headers: headers,
        body: json.encode(body),
      ).timeout(_timeout);
      final data = _handleResponse(response);
      return User.fromJson(data);
    } catch (e) {
      throw ApiException('Error updating user: $e');
    }
  }

  // ========== HEADER ENDPOINTS ==========

  Future<HeaderData> getHeader() async {
    try {
      final headers = await _buildHeaders();
      final response = await _client.get(
        Uri.parse('$baseUrl/api/header'),
        headers: headers,
      ).timeout(_timeout);
      final data = _handleResponse(response);
      if (data is Map<String, dynamic>) {
        return HeaderData.fromJson(data);
      }
      throw ApiException('Invalid header response');
    } catch (e) {
      debugPrint('Error fetching header: $e');
      throw ApiException('Error fetching header: $e');
    }
  }

  // ========== NOTIFICATIONS ENDPOINTS ==========

  Future<List<AppNotification>> getNotifications({
    bool unreadOnly = false,
    int limit = 20,
  }) async {
    try {
      final headers = await _buildHeaders();
      final uri = Uri.parse('$baseUrl/api/notifications').replace(
        queryParameters: {
          'unread_only': unreadOnly.toString(),
          'limit': '$limit',
        },
      );
      final response = await _client.get(uri, headers: headers).timeout(_timeout);
      final data = _handleResponse(response);

      final items = data is List
          ? data
          : (data is Map<String, dynamic> ? data['notifications'] : null);
      if (items is List) {
        return items
            .whereType<Map<String, dynamic>>()
            .map((json) => AppNotification.fromJson(json))
            .toList();
      }
      throw ApiException('Invalid notifications response');
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      throw ApiException('Error fetching notifications: $e');
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    try {
      final headers = await _buildHeaders();
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/notifications/$notificationId/read'),
            headers: headers,
          )
          .timeout(_timeout);
      _handleResponse(response);
    } catch (e) {
      debugPrint('Error marking notification read: $e');
      throw ApiException('Error marking notification read: $e');
    }
  }

  Future<Map<String, dynamic>> getNotificationPreferences() async {
    try {
      final headers = await _buildHeaders();
      final response = await _client.get(
        Uri.parse('$baseUrl/api/notifications/preferences'),
        headers: headers,
      ).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error fetching notification preferences: $e');
      throw ApiException('Error fetching notification preferences: $e');
    }
  }

  Future<Map<String, dynamic>> setNotificationPreferences({
    List<String>? enabledChannels,
    List<String>? disabledCategories,
    String? quietHoursStart,
    String? quietHoursEnd,
    int? maxPerHour,
    bool? digestMode,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (enabledChannels != null) body['enabled_channels'] = enabledChannels;
      if (disabledCategories != null) body['disabled_categories'] = disabledCategories;
      if (quietHoursStart != null) body['quiet_hours_start'] = quietHoursStart;
      if (quietHoursEnd != null) body['quiet_hours_end'] = quietHoursEnd;
      if (maxPerHour != null) body['max_per_hour'] = maxPerHour;
      if (digestMode != null) body['digest_mode'] = digestMode;

      final headers = await _buildHeaders();
      final response = await _client.post(
        Uri.parse('$baseUrl/api/notifications/preferences'),
        headers: headers,
        body: json.encode(body),
      ).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error setting notification preferences: $e');
      throw ApiException('Error setting notification preferences: $e');
    }
  }

  Future<Map<String, dynamic>> sendNotification({
    required String templateId,
    required String category,
    String priority = 'medium',
    Map<String, dynamic> variables = const {},
  }) async {
    try {
      final body = {
        'template_id': templateId,
        'category': category,
        'priority': priority,
        'variables': variables,
      };

      final headers = await _buildHeaders();
      final response = await _client.post(
        Uri.parse('$baseUrl/api/notifications/send'),
        headers: headers,
        body: json.encode(body),
      ).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error sending notification: $e');
      throw ApiException('Error sending notification: $e');
    }
  }

  Future<Map<String, dynamic>> getNotificationDigest({
    String period = 'daily',
  }) async {
    try {
      final headers = await _buildHeaders();
      final uri = Uri.parse('$baseUrl/api/notifications/digest').replace(
        queryParameters: {'period': period},
      );
      final response = await _client.get(uri, headers: headers).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error fetching notification digest: $e');
      throw ApiException('Error fetching notification digest: $e');
    }
  }

  // ========== TASK ENDPOINTS ==========

  Future<List<Task>> getTasks() async {
    try {
      final headers = await _buildHeaders();
      final response = await _client.get(
        Uri.parse('$baseUrl/api/tasks/'),
        headers: headers,
      ).timeout(_timeout);

      final data = _handleResponse(response);
      
      // Handle both formats: {tasks: [...]} or [...]
      if (data is Map && data.containsKey('tasks')) {
        final tasksList = data['tasks'] as List;
        return tasksList.map((json) => Task.fromJson(json)).toList();
      } else if (data is List) {
        return data.map((json) => Task.fromJson(json)).toList();
      }
      
      return [];
    } catch (e) {
      debugPrint('Error fetching tasks: $e');
      throw ApiException('Error fetching tasks: $e');
    }
  }

  Future<Task> getTask(String taskId) async {
    try {
      final headers = await _buildHeaders();
      final response = await _client.get(
        Uri.parse('$baseUrl/api/tasks/$taskId'),
        headers: headers,
      ).timeout(_timeout);
      final data = _handleResponse(response);
      return Task.fromJson(data);
    } catch (e) {
      throw ApiException('Error fetching task: $e');
    }
  }

  Future<Task> createTask({
    required String title,
    required String description,
    required TaskPriority priority,
  }) async {
    try {
      final body = {
        'title': title,
        'description': description,
        'priority': priority.name,
        'task_type': 'market_analysis',
        'auto_trade_enabled': false,
        'include_forecast': true,
      };

      if (kDebugMode) {
        debugPrint('Creating task: $body');
      }

      final headers = await _buildHeaders();
      final response = await _client.post(
        Uri.parse('$baseUrl/api/tasks/create'),
        headers: headers,
        body: json.encode(body),
      ).timeout(_timeout);

      final data = _handleResponse(response);
      if (kDebugMode) {
        debugPrint('Task created successfully: $data');
      }
      
      return Task.fromJson(data);
    } catch (e) {
      debugPrint('Error creating task: $e');
      throw ApiException('Error creating task: $e');
    }
  }

  Future<Task> stopTask(String taskId) async {
    try {
      final headers = await _buildHeaders();
      final response = await _client.post(
        Uri.parse('$baseUrl/api/tasks/$taskId/stop'),
        headers: headers,
      ).timeout(_timeout);
      final data = _handleResponse(response);
      return Task.fromJson(data);
    } catch (e) {
      throw ApiException('Error stopping task: $e');
    }
  }

  Future<Task> pauseTask(String taskId) async {
    try {
      final headers = await _buildHeaders();
      final response = await _client.post(
        Uri.parse('$baseUrl/api/tasks/$taskId/pause'),
        headers: headers,
      ).timeout(_timeout);
      return Task.fromJson(_handleResponse(response));
    } catch (e) {
      throw ApiException('Error pausing task: $e');
    }
  }

  Future<Task> resumeTask(String taskId) async {
    try {
      final headers = await _buildHeaders();
      final response = await _client.post(
        Uri.parse('$baseUrl/api/tasks/$taskId/resume'),
        headers: headers,
      ).timeout(_timeout);
      return Task.fromJson(_handleResponse(response));
    } catch (e) {
      throw ApiException('Error resuming task: $e');
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      final headers = await _buildHeaders();
      final response = await _client.delete(
        Uri.parse('$baseUrl/api/tasks/$taskId'),
        headers: headers,
      ).timeout(_timeout);
      _handleResponse(response);
    } catch (e) {
      throw ApiException('Error deleting task: $e');
    }
  }

  // ========== ACCOUNT CONNECTION ENDPOINTS ==========

  Future<List<AccountConnection>> getAccountConnections() async {
    try {
      final headers = await _buildHeaders();
      final response = await _client.get(
        Uri.parse('$baseUrl/api/accounts/connections'),
        headers: headers,
      ).timeout(_timeout);
      
      final data = _handleResponse(response);
      
      if (data is Map && data.containsKey('connections')) {
        return (data['connections'] as List)
            .map((json) => AccountConnection.fromJson(json))
            .toList();
      }
      
      throw ApiException('Invalid connections response');
    } catch (e) {
      debugPrint('Error fetching account connections: $e');
      throw ApiException('Error fetching account connections: $e');
    }
  }

  Future<AccountConnection> connectForexAccount(String username, String password) async {
    try {
      final body = {
        'username': username,
        'password': password,
      };

      final headers = await _buildHeaders();
      final response = await _client.post(
        Uri.parse('$baseUrl/api/accounts/connect/forex'),
        headers: headers,
        body: json.encode(body),
      ).timeout(_timeout);

      final data = _handleResponse(response);
      if (data['success'] && data.containsKey('connection')) {
        return AccountConnection.fromJson(data['connection']);
      }
      
      throw ApiException(data['message'] ?? 'Connection failed');
    } catch (e) {
      debugPrint('Error connecting Forex.com account: $e');
      throw ApiException('Error connecting Forex.com account: $e');
    }
  }

  Future<void> disconnectAccount(String accountId) async {
    try {
      final body = {'account_id': accountId};
      
      final headers = await _buildHeaders();
      final response = await _client.post(
        Uri.parse('$baseUrl/api/accounts/disconnect'),
        headers: headers,
        body: json.encode(body),
      ).timeout(_timeout);
      
      _handleResponse(response);
    } catch (e) {
      debugPrint('Error disconnecting account: $e');
      throw ApiException('Error disconnecting account: $e');
    }
  }

  Future<double> getAccountBalance(String accountId) async {
    try {
      final headers = await _buildHeaders();
      final response = await _client.get(
        Uri.parse('$baseUrl/api/accounts/$accountId/balance'),
        headers: headers,
      ).timeout(_timeout);
      
      final data = _handleResponse(response);
      
      if (data['success'] && data.containsKey('balance')) {
        return data['balance'].toDouble();
      }
      
      throw ApiException('Invalid balance response');
    } catch (e) {
      debugPrint('Error fetching account balance: $e');
      throw ApiException('Error fetching account balance: $e');
    }
  }

  // ========== FEATURES STATUS ENDPOINTS ==========

  Future<Map<String, dynamic>> getFeaturesStatus() async {
    try {
      final headers = await _buildHeaders();
      final userId = headers['x-user-id'];
      final response = await _client.get(
        Uri.parse('$baseUrl/api/advanced/features/status?user_id=$userId'),
        headers: headers,
      ).timeout(_timeout);
      
      final data = _handleResponse(response);
      return data;
    } catch (e) {
      debugPrint('Error fetching features status: $e');
      // Return fallback data if API fails
      return {
        "success": true,
        "timestamp": DateTime.now().toIso8601String(),
        "features": {
          "smart_triggers": {
            "active": false,
            "count": 0,
            "status": "inactive",
            "last_updated": DateTime.now().toIso8601String()
          },
          "realtime_charts": {
            "active": true,
            "market_data": {
              "timestamp": DateTime.now().toIso8601String(),
              "trend": "neutral",
              "volatility": "low",
              "risk_level": "low"
            },
            "status": "connected",
            "last_updated": DateTime.now().toIso8601String()
          },
          "news_aware": {
            "active": true,
            "sentiment": "neutral",
            "volatility": "low",
            "risk_level": "low",
            "last_updated": DateTime.now().toIso8601String()
          },
          "autonomous_actions": {
            "active": false,
            "risk_level": "moderate",
            "predictions": 0,
            "status": "inactive",
            "last_updated": DateTime.now().toIso8601String()
          }
        },
        "market": {
          "sentiment": "neutral",
          "volatility": "low",
          "risk_level": "low",
          "rates": {}
        },
        "risk": {}
      };
    }
  }

  void dispose() {
    _client.close();
  }
}
