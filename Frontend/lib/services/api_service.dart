import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/models/task.dart';
import '../core/models/user.dart';

class ApiService {
  // The base URL for your FastAPI backend.
  // For local development, this is typically http://localhost:8000.
  // If using an Android emulator, use http://10.0.2.2:8000 to connect to your host machine's localhost.
  final String _baseUrl = 'http://localhost:8000';

  // You might need to handle authentication tokens (e.g., JWT).
  // For simplicity, this example assumes no auth. In a real app, you'd
  // get a token from a login response and store it securely.
  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=UTF-8',
        // 'Authorization': 'Bearer YOUR_JWT_TOKEN',
      };

  // Helper to handle HTTP responses and errors
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // If the response body is empty, return null, otherwise decode JSON.
      if (response.body.isEmpty) return null;
      return json.decode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception(
          'API Error: ${response.statusCode} - ${response.reasonPhrase}\nBody: ${response.body}');
    }
  }

  // --- User Methods ---
  Future<User> getCurrentUser() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/users/me'),
      headers: _headers,
    );
    final data = _handleResponse(response);
    return User.fromJson(data);
  }

  Future<User> updateUser({String? name, String? email}) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/api/users/me'),
      headers: _headers,
      body: json.encode({'name': name, 'email': email}),
    );
    final data = _handleResponse(response);
    return User.fromJson(data);
  }

  // --- Task Methods ---
  Future<List<Task>> getTasks() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/tasks/'),
      headers: _headers,
    );
    final List<dynamic> data = _handleResponse(response);
    return data.map((json) => Task.fromJson(json)).toList();
  }

  Future<Task> getTask(String taskId) async {
    final response = await http.get(
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
    final response = await http.post(
      Uri.parse('$_baseUrl/api/tasks/'),
      headers: _headers,
      body: json.encode({
        'title': title,
        'description': description,
        'priority': priority.name, // e.g., 'medium'
      }),
    );
    final data = _handleResponse(response);
    return Task.fromJson(data);
  }

  Future<Task> stopTask(String taskId) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/api/tasks/$taskId/stop'),
      headers: _headers,
    );
    final data = _handleResponse(response);
    return Task.fromJson(data);
  }

  Future<Task> pauseTask(String taskId) async {
    // Assuming a similar endpoint exists in your FastAPI backend
    final response = await http.put(Uri.parse('$_baseUrl/api/tasks/$taskId/pause'), headers: _headers);
    return Task.fromJson(_handleResponse(response));
  }

  Future<Task> resumeTask(String taskId) async {
    // Assuming a similar endpoint exists in your FastAPI backend
    final response = await http.put(Uri.parse('$_baseUrl/api/tasks/$taskId/resume'), headers: _headers);
    return Task.fromJson(_handleResponse(response));
  }

  Future<void> deleteTask(String taskId) async {
    await http.delete(Uri.parse('$_baseUrl/api/tasks/$taskId'), headers: _headers);
  }
}