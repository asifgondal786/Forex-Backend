import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
  // Use --dart-define=API_BASE_URL=http://your.server:port for production.
  static const String _baseUrlFromDefine = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const Duration _timeout = Duration(seconds: 10);
  // Use --dart-define=DEV_USER_ID=your-user-id for development
  static const String _devUserId = String.fromEnvironment(
    'DEV_USER_ID',
    defaultValue: '',
  );
  static const bool _allowDebugUserFallback = bool.fromEnvironment(
    'ALLOW_DEBUG_USER_FALLBACK',
    defaultValue: true,
  );
  static const bool _allowInsecureHttpInRelease = bool.fromEnvironment(
    'ALLOW_INSECURE_HTTP_IN_RELEASE',
    defaultValue: false,
  );
  static const bool _requireAuthInRelease = bool.fromEnvironment(
    'REQUIRE_AUTH_IN_RELEASE',
    defaultValue: true,
  );
  static const String _devAuthSharedSecret = String.fromEnvironment(
    'DEV_AUTH_SHARED_SECRET',
    defaultValue: '',
  );

  // Default dev user ID for local development when no Firebase auth
  static const String _defaultDevUserId = 'dev_user_001';

  static String get baseUrl {
    final fromDefine = _baseUrlFromDefine.trim();
    if (fromDefine.isNotEmpty) {
      return _normalizeBaseUrl(fromDefine);
    }

    final fromEnv = (dotenv.env['API_BASE_URL'] ?? '').trim();
    if (fromEnv.isNotEmpty) {
      return _normalizeBaseUrl(fromEnv);
    }

    if (!kDebugMode) {
      throw StateError(
        'API_BASE_URL must be configured for non-debug builds.',
      );
    }

    // Flutter web local runs work best against localhost hostnames.
    final fallback = kIsWeb ? 'http://localhost:8080' : 'http://127.0.0.1:8080';
    return _normalizeBaseUrl(fallback);
  }

  final http.Client _client = http.Client();

  static String _normalizeBaseUrl(String value) {
    if (value.endsWith('/')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }

  Map<String, String> get _baseHeaders => {
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      };

  static bool get _isLocalApiTarget {
    try {
      final host = Uri.parse(baseUrl).host.toLowerCase();
      return host == 'localhost' || host == '127.0.0.1';
    } catch (_) {
      return false;
    }
  }

  static void _assertReleaseTransportSecurity() {
    if (kDebugMode || _allowInsecureHttpInRelease) {
      return;
    }
    if (baseUrl.toLowerCase().startsWith('http://')) {
      throw ApiException(
        'Insecure API URL blocked in release. Configure https:// API_BASE_URL.',
      );
    }
  }

  String? _resolveDevUserForCurrentContext() {
    final explicit = _devUserId.trim();
    if (explicit.isNotEmpty) {
      return explicit;
    }
    if (kDebugMode && _allowDebugUserFallback && _isLocalApiTarget) {
      return _defaultDevUserId;
    }
    return null;
  }

  Future<String> _resolveUserId({Map<String, String>? headers}) async {
    final candidate = headers?['x-user-id']?.trim();
    if (candidate != null && candidate.isNotEmpty) {
      return candidate;
    }
    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      final uid = user?.uid.trim();
      if (uid != null && uid.isNotEmpty) {
        return uid;
      }
    } catch (_) {}
    throw ApiException('User identity unavailable for this request.');
  }

  Future<Map<String, String>> _buildHeaders() async {
    _assertReleaseTransportSecurity();
    final headers = <String, String>{..._baseHeaders};

    final devUserId = _resolveDevUserForCurrentContext();
    if (devUserId != null && devUserId.isNotEmpty) {
      headers['x-user-id'] = devUserId;
      if (_devAuthSharedSecret.isNotEmpty) {
        headers['x-dev-auth'] = _devAuthSharedSecret;
      }
    }

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

    if (!kDebugMode &&
        _requireAuthInRelease &&
        !headers.containsKey('Authorization') &&
        !headers.containsKey('x-user-id')) {
      throw ApiException(
        'Authentication is required in release mode.',
      );
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
      final response = await _client
          .get(
            Uri.parse('$baseUrl/api/users/me'),
            headers: headers,
          )
          .timeout(_timeout);
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
      final response = await _client
          .put(
            Uri.parse('$baseUrl/api/users/me'),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(_timeout);
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
      final response = await _client
          .get(
            Uri.parse('$baseUrl/api/header'),
            headers: headers,
          )
          .timeout(_timeout);
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
      final response =
          await _client.get(uri, headers: headers).timeout(_timeout);
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
      final response = await _client
          .get(
            Uri.parse('$baseUrl/api/notifications/preferences'),
            headers: headers,
          )
          .timeout(_timeout);
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
    bool? autonomousMode,
    String? autonomousProfile,
    double? autonomousMinConfidence,
    Map<String, dynamic>? channelSettings,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (enabledChannels != null) body['enabled_channels'] = enabledChannels;
      if (disabledCategories != null) {
        body['disabled_categories'] = disabledCategories;
      }
      if (quietHoursStart != null) body['quiet_hours_start'] = quietHoursStart;
      if (quietHoursEnd != null) body['quiet_hours_end'] = quietHoursEnd;
      if (maxPerHour != null) body['max_per_hour'] = maxPerHour;
      if (digestMode != null) body['digest_mode'] = digestMode;
      if (autonomousMode != null) body['autonomous_mode'] = autonomousMode;
      if (autonomousProfile != null) {
        body['autonomous_profile'] = autonomousProfile;
      }
      if (autonomousMinConfidence != null) {
        body['autonomous_min_confidence'] = autonomousMinConfidence;
      }
      if (channelSettings != null) body['channel_settings'] = channelSettings;

      final headers = await _buildHeaders();
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/notifications/preferences'),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(_timeout);
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
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/notifications/send'),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error sending notification: $e');
      throw ApiException('Error sending notification: $e');
    }
  }

  Future<Map<String, dynamic>> sendAutonomousStudyAlert({
    required String pair,
    String? userInstruction,
    String? priority,
  }) async {
    try {
      final body = <String, dynamic>{
        'pair': pair,
      };
      if (userInstruction != null && userInstruction.trim().isNotEmpty) {
        body['user_instruction'] = userInstruction.trim();
      }
      if (priority != null && priority.trim().isNotEmpty) {
        body['priority'] = priority.trim().toLowerCase();
      }

      final headers = await _buildHeaders();
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/notifications/autonomous-study'),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error sending autonomous study alert: $e');
      throw ApiException('Error sending autonomous study alert: $e');
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
      final response =
          await _client.get(uri, headers: headers).timeout(_timeout);
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
      final response = await _client
          .get(
            Uri.parse('$baseUrl/api/tasks/'),
            headers: headers,
          )
          .timeout(_timeout);

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
      final response = await _client
          .get(
            Uri.parse('$baseUrl/api/tasks/$taskId'),
            headers: headers,
          )
          .timeout(_timeout);
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
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/tasks/create'),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(_timeout);

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
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/tasks/$taskId/stop'),
            headers: headers,
          )
          .timeout(_timeout);
      final data = _handleResponse(response);
      return Task.fromJson(data);
    } catch (e) {
      throw ApiException('Error stopping task: $e');
    }
  }

  Future<Task> pauseTask(String taskId) async {
    try {
      final headers = await _buildHeaders();
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/tasks/$taskId/pause'),
            headers: headers,
          )
          .timeout(_timeout);
      return Task.fromJson(_handleResponse(response));
    } catch (e) {
      throw ApiException('Error pausing task: $e');
    }
  }

  Future<Task> resumeTask(String taskId) async {
    try {
      final headers = await _buildHeaders();
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/tasks/$taskId/resume'),
            headers: headers,
          )
          .timeout(_timeout);
      return Task.fromJson(_handleResponse(response));
    } catch (e) {
      throw ApiException('Error resuming task: $e');
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      final headers = await _buildHeaders();
      final response = await _client
          .delete(
            Uri.parse('$baseUrl/api/tasks/$taskId'),
            headers: headers,
          )
          .timeout(_timeout);
      _handleResponse(response);
    } catch (e) {
      throw ApiException('Error deleting task: $e');
    }
  }

  // ========== ACCOUNT CONNECTION ENDPOINTS ==========

  Future<List<AccountConnection>> getAccountConnections() async {
    try {
      final headers = await _buildHeaders();
      final response = await _client
          .get(
            Uri.parse('$baseUrl/api/accounts/connections'),
            headers: headers,
          )
          .timeout(_timeout);

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

  Future<AccountConnection> connectForexAccount(
      String username, String password) async {
    try {
      final body = {
        'username': username,
        'password': password,
      };

      final headers = await _buildHeaders();
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/accounts/connect/forex'),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(_timeout);

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
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/accounts/disconnect'),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(_timeout);

      _handleResponse(response);
    } catch (e) {
      debugPrint('Error disconnecting account: $e');
      throw ApiException('Error disconnecting account: $e');
    }
  }

  Future<double> getAccountBalance(String accountId) async {
    try {
      final headers = await _buildHeaders();
      final response = await _client
          .get(
            Uri.parse('$baseUrl/api/accounts/$accountId/balance'),
            headers: headers,
          )
          .timeout(_timeout);

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

  // ========== FOREX DATA ENDPOINTS ==========

  Future<Map<String, dynamic>> getForexRates() async {
    try {
      final headers = await _buildHeaders();
      final response = await _client
          .get(
            Uri.parse('$baseUrl/api/forex/rates'),
            headers: headers,
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error fetching forex rates: $e');
      return {
        'status': 'fallback',
        'rates': {
          'EUR/USD': 1.0834,
          'GBP/USD': 1.2712,
          'USD/JPY': 154.22,
          'USD/PKR': 278.90,
          'AUD/USD': 0.6513,
          'USD/CAD': 1.3611,
        },
      };
    }
  }

  Future<Map<String, dynamic>> getForexNews() async {
    try {
      final headers = await _buildHeaders();
      final response = await _client
          .get(
            Uri.parse('$baseUrl/api/forex/news'),
            headers: headers,
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error fetching forex news: $e');
      // Graceful fallback keeps UI live when backend is offline.
      return {
        'status': 'fallback',
        'news': [
          {
            'time': DateTime.now().toIso8601String(),
            'currency': 'USD',
            'impact': 'high',
            'event': 'US labor market update',
            'actual': 'N/A',
            'forecast': 'N/A',
            'previous': 'N/A',
          },
          {
            'time': DateTime.now()
                .subtract(const Duration(minutes: 30))
                .toIso8601String(),
            'currency': 'EUR',
            'impact': 'medium',
            'event': 'Eurozone inflation watch',
            'actual': 'N/A',
            'forecast': 'N/A',
            'previous': 'N/A',
          },
        ],
      };
    }
  }

  Future<Map<String, dynamic>> getForexMarketSentiment() async {
    try {
      final headers = await _buildHeaders();
      final response = await _client
          .get(
            Uri.parse('$baseUrl/api/forex/sentiment'),
            headers: headers,
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error fetching market sentiment: $e');
      return {
        'status': 'fallback',
        'sentiment': {
          'trend': 'neutral',
          'volatility': 'medium',
          'risk_level': 'moderate',
          'timestamp': DateTime.now().toIso8601String(),
        },
      };
    }
  }

  double _fallbackPairPrice(String pair) {
    final normalized = pair.toUpperCase().replaceAll(' ', '');
    switch (normalized) {
      case 'USD/PKR':
        return 279.0;
      case 'EUR/USD':
        return 1.0834;
      case 'GBP/USD':
        return 1.2712;
      case 'USD/JPY':
        return 154.22;
      case 'AUD/USD':
        return 0.6513;
      case 'USD/CAD':
        return 1.3611;
      case 'NZD/USD':
        return 0.5989;
      default:
        return 1.0;
    }
  }

  int _pairDigits(String pair) {
    final normalized = pair.toUpperCase();
    if (normalized.contains('JPY') || normalized.contains('PKR')) {
      return 2;
    }
    return 4;
  }

  Future<Map<String, dynamic>> getForexPairForecast({
    required String pair,
    String horizon = '1d',
  }) async {
    final normalizedPair = pair.trim().toUpperCase();
    final normalizedHorizon = horizon.trim().toLowerCase();
    try {
      final headers = await _buildHeaders();
      final uri = Uri.parse('$baseUrl/api/forex/forecast').replace(
        queryParameters: <String, String>{
          'pair': normalizedPair,
          'horizon': normalizedHorizon,
        },
      );
      final response =
          await _client.get(uri, headers: headers).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error fetching forex forecast: $e');
      final price = _fallbackPairPrice(normalizedPair);
      final digits = _pairDigits(normalizedPair);
      final targetHigh = price * 1.006;
      final targetLow = price * 0.996;
      return {
        'status': 'fallback',
        'forecast': {
          'pair': normalizedPair,
          'horizon': normalizedHorizon,
          'generated_at': DateTime.now().toIso8601String(),
          'current_price': double.parse(price.toStringAsFixed(digits)),
          'trend_bias': 'neutral',
          'volatility': 'medium',
          'risk_level': 'moderate',
          'confidence_percent': 58,
          'expected_change_percent': {
            'low': -0.4,
            'mid': 0.2,
            'high': 0.8,
          },
          'target_range': {
            'low': double.parse(targetLow.toStringAsFixed(digits)),
            'high': double.parse(targetHigh.toStringAsFixed(digits)),
          },
          'timing_guidance':
              'Fallback forecast active. Use staged entries/exits and confirm direction with fresh candles.',
          'disclaimer': 'Simulation-grade forecast. Not financial advice.',
        }
      };
    }
  }

  // ========== FEATURES STATUS ENDPOINTS ==========

  Future<Map<String, dynamic>> parseNaturalLanguageCommand(
      String command) async {
    try {
      final headers = await _buildHeaders();
      final uri = Uri.parse('$baseUrl/api/advanced/nlp/parse-command').replace(
        queryParameters: {'text': command},
      );
      final response = await _client
          .post(
            uri,
            headers: headers,
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error parsing natural language command: $e');
      return {
        'success': false,
        'confidence': 0.0,
        'command_type': 'unknown',
        'ai_response': 'Command parser unavailable.',
      };
    }
  }

  Future<Map<String, dynamic>> getFeaturesStatus() async {
    try {
      final headers = await _buildHeaders();
      final userId = await _resolveUserId(headers: headers);
      final response = await _client
          .get(
            Uri.parse('$baseUrl/api/advanced/features/status?user_id=$userId'),
            headers: headers,
          )
          .timeout(_timeout);

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
            "active": true,
            "count": 0,
            "status": "active",
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
            "active": true,
            "risk_level": "moderate",
            "predictions": 0,
            "status": "active",
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

  Future<Map<String, dynamic>> getAutonomyGuardrails() async {
    try {
      final headers = await _buildHeaders();
      final userId = await _resolveUserId(headers: headers);
      final response = await _client
          .get(
            Uri.parse('$baseUrl/api/advanced/autonomy/guardrails/$userId'),
            headers: headers,
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error fetching autonomy guardrails: $e');
      throw ApiException('Error fetching autonomy guardrails: $e');
    }
  }

  Future<Map<String, dynamic>> configureAutonomyGuardrails({
    String? level,
    Map<String, dynamic>? probation,
    Map<String, dynamic>? riskBudget,
  }) async {
    try {
      final headers = await _buildHeaders();
      final userId = await _resolveUserId(headers: headers);
      final body = <String, dynamic>{
        'user_id': userId,
      };
      if (level != null && level.trim().isNotEmpty) {
        body['level'] = level.trim().toLowerCase();
      }
      if (probation != null) body['probation'] = probation;
      if (riskBudget != null) body['risk_budget'] = riskBudget;

      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/advanced/autonomy/guardrails/configure'),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error configuring autonomy guardrails: $e');
      throw ApiException('Error configuring autonomy guardrails: $e');
    }
  }

  Future<Map<String, dynamic>> explainBeforeExecute({
    required Map<String, dynamic> tradeParams,
  }) async {
    try {
      final headers = await _buildHeaders();
      final userId = await _resolveUserId(headers: headers);
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/advanced/autonomy/explain-before-execute'),
            headers: headers,
            body: json.encode({
              'user_id': userId,
              'trade_params': tradeParams,
            }),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error running explain-before-execute: $e');
      throw ApiException('Error running explain-before-execute: $e');
    }
  }

  Future<Map<String, dynamic>> executeAutonomousTrade({
    required Map<String, dynamic> tradeParams,
    String? explainToken,
  }) async {
    try {
      final headers = await _buildHeaders();
      final userId = await _resolveUserId(headers: headers);
      final uri = Uri.parse('$baseUrl/api/advanced/risk/execute-trade').replace(
        queryParameters: {
          'user_id': userId,
        },
      );
      final payload = <String, dynamic>{...tradeParams};
      if (explainToken != null && explainToken.trim().isNotEmpty) {
        payload['explain_token'] = explainToken.trim();
      }

      final response = await _client
          .post(
            uri,
            headers: headers,
            body: json.encode(payload),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error executing autonomous trade: $e');
      throw ApiException('Error executing autonomous trade: $e');
    }
  }

  Future<Map<String, dynamic>> activateKillSwitch() async {
    try {
      final headers = await _buildHeaders();
      final userId = await _resolveUserId(headers: headers);
      final uri = Uri.parse('$baseUrl/api/advanced/risk/kill-switch').replace(
        queryParameters: {
          'user_id': userId,
        },
      );
      final response = await _client
          .post(
            uri,
            headers: headers,
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error activating kill switch: $e');
      throw ApiException('Error activating kill switch: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}
