import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../core/models/task.dart';
import '../core/models/user.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ApiService {
  // Backend URL - matches your backend port
  static const String baseUrl = 'http://127.0.0.1:8080';
  
  final http.Client _client = http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=UTF-8',
      };

  dynamic _handleResponse(http.Response response) {
    debugPrint('Response status: ${response.statusCode}');
    debugPrint('Response body: ${response.body}');
    
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
      final response = await _client.get(
        Uri.parse('$baseUrl/api/users/me'),
        headers: _headers,
      );
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

      final response = await _client.put(
        Uri.parse('$baseUrl/api/users/me'),
        headers: _headers,
        body: json.encode(body),
      );
      final data = _handleResponse(response);
      return User.fromJson(data);
    } catch (e) {
      throw ApiException('Error updating user: $e');
    }
  }

  // ========== TASK ENDPOINTS ==========

  Future<List<Task>> getTasks() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/tasks/'),
        headers: _headers,
      );

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
      final response = await _client.get(
        Uri.parse('$baseUrl/api/tasks/$taskId'),
        headers: _headers,
      );
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

      debugPrint('Creating task: $body');

      final response = await _client.post(
        Uri.parse('$baseUrl/api/tasks/create'),
        headers: _headers,
        body: json.encode(body),
      );

      final data = _handleResponse(response);
      debugPrint('Task created successfully: $data');
      
      return Task.fromJson(data);
    } catch (e) {
      debugPrint('Error creating task: $e');
      throw ApiException('Error creating task: $e');
    }
  }

  Future<Task> stopTask(String taskId) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/tasks/$taskId/stop'),
        headers: _headers,
      );
      final data = _handleResponse(response);
      return Task.fromJson(data);
    } catch (e) {
      throw ApiException('Error stopping task: $e');
    }
  }

  Future<Task> pauseTask(String taskId) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/tasks/$taskId/pause'),
        headers: _headers,
      );
      return Task.fromJson(_handleResponse(response));
    } catch (e) {
      throw ApiException('Error pausing task: $e');
    }
  }

  Future<Task> resumeTask(String taskId) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/tasks/$taskId/resume'),
        headers: _headers,
      );
      return Task.fromJson(_handleResponse(response));
    } catch (e) {
      throw ApiException('Error resuming task: $e');
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      await _client.delete(
        Uri.parse('$baseUrl/api/tasks/$taskId'),
        headers: _headers,
      );
    } catch (e) {
      throw ApiException('Error deleting task: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}