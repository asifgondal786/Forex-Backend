import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../core/models/task.dart';
import '../core/models/user.dart';

class ApiService {
  static const String _devApiUrl = 'http://localhost:8080';
  static const String _prodApiUrl = 'https://your-prod-api.com';

  String get _baseUrl => kReleaseMode ? _prodApiUrl : _devApiUrl;
  
  final http.Client _client = http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=UTF-8',
      };

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return json.decode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception(
          'API Error: ${response.statusCode} - ${response.reasonPhrase}\nBody: ${response.body}');
    }
  }

  Future<User> getCurrentUser() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/users/me'),
      headers: _headers,
    );
    final data = _handleResponse(response);
    return User.fromJson(data);
  }

  Future<User> updateUser({String? name, String? email}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (email != null) body['email'] = email;

    final response = await _client.put(
      Uri.parse('$_baseUrl/api/users/me'),
      headers: _headers,
      body: json.encode(body),
    );
    final data = _handleResponse(response);
    return User.fromJson(data);
  }

  Future<List<Task>> getTasks() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/tasks/'),
      headers: _headers,
    );
    final List<dynamic> data = _handleResponse(response);
    return data.map((json) => Task.fromJson(json)).toList();
  }

  Future<Task> getTask(String taskId) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/tasks/$taskId'),
      headers: _headers,
    );
    final data = _handleResponse(response);
    return Task.fromJson(data);
  }

  Future<Task> createTask({
    required String title,
    required String description,
    required TaskPriority priority,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/tasks/'),
      headers: _headers,
      body: json.encode({
        'title': title,
        'description': description,
        'priority': priority.name,
      }),
    );
    final data = _handleResponse(response);
    return Task.fromJson(data);
  }

  Future<Task> stopTask(String taskId) async {
    final response = await _client.put(
      Uri.parse('$_baseUrl/api/tasks/$taskId/stop'),
      headers: _headers,
    );
    final data = _handleResponse(response);
    return Task.fromJson(data);
  }

  Future<Task> pauseTask(String taskId) async {
    final response = await _client.put(
      Uri.parse('$_baseUrl/api/tasks/$taskId/pause'),
      headers: _headers,
    );
    return Task.fromJson(_handleResponse(response));
  }

  Future<Task> resumeTask(String taskId) async {
    final response = await _client.put(
      Uri.parse('$_baseUrl/api/tasks/$taskId/resume'),
      headers: _headers,
    );
    return Task.fromJson(_handleResponse(response));
  }

  Future<void> deleteTask(String taskId) async {
    await _client.delete(
      Uri.parse('$_baseUrl/api/tasks/$taskId'),
      headers: _headers,
    );
  }

  void dispose() {
    _client.close();
  }
}
