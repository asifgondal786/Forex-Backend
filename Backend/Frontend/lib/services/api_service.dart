import 'dart:async';
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
  // /api/v1 — public market data, signals, risk, paper trading
  static const String apiV1  = '/api/v1';
  // /v1/api — authenticated endpoints (tasks, accounts, forex, advanced)
  static const String apiV1b = '/v1/api';

  // added new cosntant here
  static const String apiV1c = '/v1';


  static const String _baseUrlFromDefine = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const Duration _timeout     = Duration(seconds: 10);
  static const Duration _authTimeout = Duration(seconds: 45);

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

  static const String _defaultDevUserId = 'dev_user_001';

  static final RegExp _invisibleChars = RegExp(
    r'[\u0000-\u001F\u007F\u00A0\u1680\u180E\u2000-\u200F\u2028-\u202F\u205F-\u206F\u3000\uFEFF]',
  );

  // â”€â”€ Base URL â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  static String get baseUrl {
    final fromDefine = _baseUrlFromDefine.trim();
    if (fromDefine.isNotEmpty) return _normalizeBaseUrl(fromDefine);

    if (!kDebugMode) {
      throw StateError('API_BASE_URL must be configured for non-debug builds.');
    }

    // Always use 127.0.0.1:8001 for API — never use the web dev server origin (e.g., :60051)
    final fallback = kIsWeb ? 'http://127.0.0.1:8001' : 'http://127.0.0.1:8001';
    return _normalizeBaseUrl(fallback);
  }

  final http.Client _client = http.Client();

  // â”€â”€ Static helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  static String _normalizeBaseUrl(String v) =>
      v.endsWith('/') ? v.substring(0, v.length - 1) : v;

  static Map<String, String> _buildBaseHeaders() => const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  static String _normalizeEmail(String raw) => raw
      .replaceAll(_invisibleChars, '')
      .replaceAll(RegExp(r'\s+'), '')
      .trim()
      .toLowerCase();

  static List<String> _normalizePairs(List<String>? pairs) {
    if (pairs == null) return const [];
    return pairs.map((p) => p.trim().toUpperCase()).where((p) => p.isNotEmpty).toList();
  }

  static Map<String, T> _filterRatesForPairs<T>(
    Map<String, T> rates,
    List<String> pairs,
  ) {
    if (pairs.isEmpty) return rates;
    final out = <String, T>{};
    for (final pair in pairs) {
      if (rates.containsKey(pair)) { out[pair] = rates[pair]!; continue; }
      final compact = pair.replaceAll('/', '');
      if (rates.containsKey(compact)) out[compact] = rates[compact]!;
    }
    return out.isNotEmpty ? out : rates;
  }

  static bool get _isLocalApiTarget {
    try {
      final host = Uri.parse(baseUrl).host.toLowerCase();
      return host == 'localhost' || host == '127.0.0.1';
    } catch (_) {
      return false;
    }
  }

  /// Returns true if the Railway backend responds to /health within 5 seconds.
static Future<bool> isHealthy() async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/health'),
    ).timeout(const Duration(seconds: 5));
    return response.statusCode == 200;
  } catch (_) {
    return false;
  }
}

  static void _assertReleaseTransportSecurity() {
    if (kDebugMode || _allowInsecureHttpInRelease || _isLocalApiTarget) return;
    if (baseUrl.toLowerCase().startsWith('http://')) {
      throw ApiException('Insecure API URL blocked in release. Use https://.');
    }
  }

  String? _resolveDevUserForCurrentContext() {
    final explicit = _devUserId.trim();
    if (explicit.isNotEmpty) return explicit;
    if (kDebugMode && _allowDebugUserFallback && _isLocalApiTarget) {
      return _defaultDevUserId;
    }
    return null;
  }

  Future<String> _resolveUserId({Map<String, String>? headers}) async {
    final candidate = headers?['x-user-id']?.trim();
    if (candidate != null && candidate.isNotEmpty) return candidate;
    try {
      final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid.trim();
      if (uid != null && uid.isNotEmpty) return uid;
    } catch (_) {}
    throw ApiException('User identity unavailable for this request.');
  }

  Future<Map<String, String>> _buildHeaders() async {
    _assertReleaseTransportSecurity();
    final headers = <String, String>{..._buildBaseHeaders()};

    final devUserId = _resolveDevUserForCurrentContext();
    if (devUserId != null) {
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
      if (kDebugMode) debugPrint('Auth header skipped: $e');
    }

    if (!kDebugMode &&
        _requireAuthInRelease &&
        !headers.containsKey('Authorization') &&
        !headers.containsKey('x-user-id')) {
      throw ApiException('Authentication is required in release mode.');
    }

    return headers;
  }

  /// Cast all nested Maps to Map<String, dynamic>
  /// Recursively processes the entire structure including nested maps and lists.
  dynamic _deepCastMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(
        value.map((k, v) => MapEntry(k.toString(), _deepCastMap(v))),
      );
    } else if (value is List) {
      return value.map(_deepCastMap).toList();
    }
    return value;
  }

  dynamic _handleResponse(http.Response response) {
    if (kDebugMode) {
      debugPrint('Response ${response.statusCode}: ${response.body}');
    }

    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        var raw = json.decode(utf8.decode(response.bodyBytes));
        decoded = _deepCastMap(raw);
      } catch (_) {
        decoded = null;
      }
    }

    bool isEnvelope(Map<String, dynamic> p) =>
        p.containsKey('status') && p.containsKey('message') && p.containsKey('data');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded == null) return {};
      if (decoded is Map<String, dynamic> && isEnvelope(decoded)) {
        final status  = (decoded['status'] ?? '').toString().toLowerCase();
        final message = (decoded['message'] ?? '').toString().trim();
        if (status == 'error') {
          throw ApiException(message.isNotEmpty ? message : 'Request failed', response.statusCode);
        }
        final data = decoded['data'];
        if (data is Map<String, dynamic>) {
          if (message.isNotEmpty && !data.containsKey('message')) data['message'] = message;
          return data;
        }
        if (data is List) return data;
        if (data == null) return {if (message.isNotEmpty) 'message': message};
        return {'value': data, if (message.isNotEmpty) 'message': message};
      }
      return decoded;
    }

    var message = 'API Error: ${response.statusCode} - ${response.reasonPhrase}';
    if (decoded is Map<String, dynamic>) {
      if (isEnvelope(decoded)) {
        final m = (decoded['message'] ?? '').toString().trim();
        if (m.isNotEmpty) message = m;
      }
      final detail = decoded['detail'] ?? decoded['message'] ?? decoded['error'];
      if (detail is String && detail.trim().isNotEmpty) {
        message = detail.trim();
      } else if (detail != null) {
        message = detail.toString();
      }
    } else if (response.body.isNotEmpty) {
      final plain = utf8.decode(response.bodyBytes).trim();
      if (plain.isNotEmpty) message = plain;
    }
    throw ApiException(message, response.statusCode);
  }

  // â”€â”€ Fallback data â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Map<String, double> _fallbackForexRates() => {
        'EUR/USD': 1.0834, 'GBP/USD': 1.2712, 'USD/JPY': 154.22,
        'USD/PKR': 278.90, 'AUD/USD': 0.6513, 'USD/CAD': 1.3611,
        'NZD/USD': 0.5989, 'USD/CHF': 0.7895,
      };

  double _fallbackPairPrice(String pair) {
    const prices = {
      'USD/PKR': 279.0, 'EUR/USD': 1.0834, 'GBP/USD': 1.2712,
      'USD/JPY': 154.22, 'AUD/USD': 0.6513, 'USD/CAD': 1.3611,
      'NZD/USD': 0.5989,
    };
    return prices[pair.toUpperCase().replaceAll(' ', '')] ?? 1.0;
  }

  int _pairDigits(String pair) {
    final p = pair.toUpperCase();
    return (p.contains('JPY') || p.contains('PKR')) ? 2 : 4;
  }

  double _formatPrice(String pair, double value) =>
      double.parse(value.toStringAsFixed(_pairDigits(pair)));

  int _stableHash(String value) {
    var hash = 0;
    for (final c in value.codeUnits) hash = (hash * 31 + c) & 0x7fffffff;
    return hash;
  }

  List<Map<String, dynamic>> _buildFallbackSignals(List<String> pairs) {
    final now   = DateTime.now();
    final rates = _fallbackForexRates();
    const timeframes = ['M30', 'H1', 'H4'];
    return pairs.map((pair) {
      final hash = _stableHash(pair);
      final type = switch (hash % 4) {
        0 => 'buy', 1 => 'sell', 2 => 'hold', _ => 'wait',
      };
      final baseConf  = 0.55 + (hash % 30) / 100;
      final confidence = (type == 'hold' || type == 'wait'
          ? (baseConf - 0.12).clamp(0.4, 0.7)
          : baseConf.clamp(0.55, 0.9)).toDouble();
      final entry = rates[pair] ?? _fallbackPairPrice(pair);
      final swing = entry * (0.0025 + (hash % 8) / 10000);
      final tp = type == 'buy'  ? entry + swing * 1.6
               : type == 'sell' ? entry - swing * 1.6 : null;
      final sl = type == 'buy'  ? entry - swing
               : type == 'sell' ? entry + swing       : null;
      final reason = switch (type) {
        'buy'  => 'Momentum aligned with higher-timeframe support; risk skew favors upside.',
        'sell' => 'Price rejected near resistance; short-term risk bias leans lower.',
        'hold' => 'Signals are mixed; waiting for confirmation before committing.',
        _      => 'Low volatility regime. Awaiting breakout and volume confirmation.',
      };
      return <String, dynamic>{
        'pair': pair, 'signal': type, 'confidence': confidence, 'reason': reason,
        'entry_price': (type == 'buy' || type == 'sell') ? _formatPrice(pair, entry) : null,
        'take_profit': tp != null ? _formatPrice(pair, tp) : null,
        'stop_loss':   sl != null ? _formatPrice(pair, sl) : null,
        'timeframe':   timeframes[hash % timeframes.length],
        'generated_at': now.subtract(Duration(minutes: hash % 45)).toIso8601String(),
        'tags': ['Fallback', type == 'hold' || type == 'wait' ? 'Neutral' : 'Momentum'],
      };
    }).toList();
  }

  // =========================================================================
  // USER ENDPOINTS
  // =========================================================================

  Future<Map<String, dynamic>> requestPasswordReset({required String email}) async {
    final normalized = _normalizeEmail(email);
    if (normalized.isEmpty) throw ApiException('Email is required for password reset.');
    try {
      final response = await _client
          .post(Uri.parse('$baseUrl/auth/password-reset'),
              headers: await _buildHeaders(), body: json.encode({'email': normalized}))
          .timeout(_authTimeout);
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      return {
        'success': true,
        'message': 'If an account exists for this email, password reset instructions have been sent.',
        'debug': {'result': 'client_timeout_optimistic'},
      };
    } catch (e) {
      debugPrint('Error requesting password reset: $e');
      throw ApiException('Error requesting password reset: $e');
    }
  }

  Future<Map<String, dynamic>> requestEmailVerification({required String email}) async {
    final normalized = _normalizeEmail(email);
    if (normalized.isEmpty) throw ApiException('Email is required for verification.');
    try {
      final response = await _client
          .post(Uri.parse('$baseUrl/auth/email-verification'),
              headers: await _buildHeaders(), body: json.encode({'email': normalized}))
          .timeout(_authTimeout);
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('Error requesting verification email: $e');
      throw ApiException('Error requesting verification email: $e');
    }
  }

  Future<User> getCurrentUser() async {
    try {
      final headers  = await _buildHeaders();
      final response = await _client
          .get(Uri.parse('$baseUrl$apiV1c/users/me'), headers: headers)
          .timeout(_timeout);
      return User.fromJson(_handleResponse(response));
    } catch (e) {
      debugPrint('Error fetching user: $e');
      throw ApiException('Error fetching user: $e');
    }
  }

  Future<User> updateUser({String? name, String? email}) async {
    try {
      final body    = <String, dynamic>{};
      if (name  != null) body['name']  = name;
      if (email != null) body['email'] = email;
      final headers  = await _buildHeaders();
      final response = await _client
          .put(Uri.parse('$baseUrl$apiV1c/users/me'),
              headers: headers, body: json.encode(body))
          .timeout(_timeout);
      return User.fromJson(_handleResponse(response));
    } catch (e) {
      throw ApiException('Error updating user: $e');
    }
  }

  // =========================================================================
  // HEADER ENDPOINTS
  // =========================================================================

  Future<HeaderData> getHeader() async {
    try {
      final headers  = await _buildHeaders();
      final response = await _client
          .get(Uri.parse('$baseUrl$apiV1c/header/'), headers: headers)
          .timeout(_timeout);
      final data = _handleResponse(response);
      if (data is Map<String, dynamic>) return HeaderData.fromJson(data);
      throw ApiException('Invalid header response');
    } catch (e) {
      debugPrint('Error fetching header: $e');
      throw ApiException('Error fetching header: $e');
    }
  }

  // =========================================================================
  // NOTIFICATION ENDPOINTS
  // =========================================================================

  Future<List<AppNotification>> getNotifications({
    bool unreadOnly = false,
    int limit = 20,
  }) async {
    try {
      final headers = await _buildHeaders();
      final uri     = Uri.parse('$baseUrl$apiV1b/notifications').replace(
        queryParameters: {'unread_only': '$unreadOnly', 'limit': '$limit'},
      );
      final response = await _client.get(uri, headers: headers).timeout(_timeout);
      final data = _handleResponse(response);
      final items = data is List ? data : (data is Map ? data['notifications'] : null);
      if (items is List) {
        return items.whereType<Map<String, dynamic>>()
            .map((j) => AppNotification.fromJson(j)).toList();
      }
      throw ApiException('Invalid notifications response');
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      throw ApiException('Error fetching notifications: $e');
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    try {
      final headers  = await _buildHeaders();
      final response = await _client
          .post(Uri.parse('$baseUrl$apiV1b/notifications/$notificationId/read'),
              headers: headers)
          .timeout(_timeout);
      _handleResponse(response);
    } catch (e) {
      debugPrint('Error marking notification read: $e');
      throw ApiException('Error marking notification read: $e');
    }
  }

  Future<Map<String, dynamic>> getNotificationPreferences() async {
    try {
      final headers  = await _buildHeaders();
      final response = await _client
          .get(Uri.parse('$baseUrl$apiV1b/notifications/preferences'), headers: headers)
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
    bool? autonomousStageAlerts,
    int? autonomousStageIntervalSeconds,
    Map<String, dynamic>? channelSettings,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (enabledChannels              != null) body['enabled_channels']               = enabledChannels;
      if (disabledCategories           != null) body['disabled_categories']            = disabledCategories;
      if (quietHoursStart              != null) body['quiet_hours_start']              = quietHoursStart;
      if (quietHoursEnd                != null) body['quiet_hours_end']                = quietHoursEnd;
      if (maxPerHour                   != null) body['max_per_hour']                   = maxPerHour;
      if (digestMode                   != null) body['digest_mode']                    = digestMode;
      if (autonomousMode               != null) body['autonomous_mode']                = autonomousMode;
      if (autonomousProfile            != null) body['autonomous_profile']             = autonomousProfile;
      if (autonomousMinConfidence      != null) body['autonomous_min_confidence']      = autonomousMinConfidence;
      if (autonomousStageAlerts        != null) body['autonomous_stage_alerts']        = autonomousStageAlerts;
      if (autonomousStageIntervalSeconds != null) body['autonomous_stage_interval_seconds'] = autonomousStageIntervalSeconds;
      if (channelSettings              != null) body['channel_settings']               = channelSettings;

      final headers  = await _buildHeaders();
      final response = await _client
          .post(Uri.parse('$baseUrl$apiV1b/notifications/preferences'),
              headers: headers, body: json.encode(body))
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
      final headers  = await _buildHeaders();
      final response = await _client
          .post(Uri.parse('$baseUrl$apiV1b/notifications/send'),
              headers: headers,
              body: json.encode({
                'template_id': templateId, 'category': category,
                'priority': priority, 'variables': variables,
              }))
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
      final body = <String, dynamic>{'pair': pair};
      if (userInstruction?.trim().isNotEmpty == true) body['user_instruction'] = userInstruction!.trim();
      if (priority?.trim().isNotEmpty        == true) body['priority']         = priority!.trim().toLowerCase();
      final headers  = await _buildHeaders();
      final response = await _client
          .post(Uri.parse('$baseUrl$apiV1b/notifications/autonomous-study'),
              headers: headers, body: json.encode(body))
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error sending autonomous study alert: $e');
      throw ApiException('Error sending autonomous study alert: $e');
    }
  }

  Future<Map<String, dynamic>> sendAutonomousAwarenessAlert({
    required String stage,
    String pair = 'EUR/USD',
    String? userInstruction,
    String? priority,
    String? stageContext,
    bool force = false,
  }) async {
    try {
      final body = <String, dynamic>{
        'stage': stage.trim().toLowerCase(),
        'pair':  pair.trim().toUpperCase(),
        'force': force,
      };
      if (userInstruction?.trim().isNotEmpty == true) body['user_instruction'] = userInstruction!.trim();
      if (priority?.trim().isNotEmpty        == true) body['priority']         = priority!.trim().toLowerCase();
      if (stageContext?.trim().isNotEmpty     == true) body['stage_context']    = stageContext!.trim();
      final headers  = await _buildHeaders();
      final response = await _client
          .post(Uri.parse('$baseUrl$apiV1b/notifications/autonomous-awareness'),
              headers: headers, body: json.encode(body))
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error sending autonomous awareness alert: $e');
      throw ApiException('Error sending autonomous awareness alert: $e');
    }
  }

  Future<Map<String, dynamic>> getDeepMarketStudy({
    String pair = 'EUR/USD',
    int maxHeadlinesPerSource = 3,
  }) async {
    try {
      final headers = await _buildHeaders();
      final uri     = Uri.parse('$baseUrl$apiV1b/notifications/deep-study').replace(
        queryParameters: {
          'pair': pair.trim().toUpperCase(),
          'max_headlines_per_source': '$maxHeadlinesPerSource',
        },
      );
      final response = await _client.get(uri, headers: headers).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error fetching deep market study: $e');
      return {
        'pair': pair.trim().toUpperCase(),
        'confidence_band': 'low',
        'recommendation': 'wait_for_confirmation',
        'source_coverage': {'requested': 0, 'analyzed': 0, 'coverage_ratio': 0.0},
      };
    }
  }

  Future<Map<String, dynamic>> getNotificationDigest({String period = 'daily'}) async {
    try {
      final headers  = await _buildHeaders();
      final uri      = Uri.parse('$baseUrl$apiV1b/notifications/digest')
          .replace(queryParameters: {'period': period});
      final response = await _client.get(uri, headers: headers).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error fetching notification digest: $e');
      throw ApiException('Error fetching notification digest: $e');
    }
  }

  // =========================================================================
  // TASK ENDPOINTS
  // =========================================================================

  Future<List<Task>> getTasks() async {
    try {
      final headers  = await _buildHeaders();
      final response = await _client
          .get(Uri.parse('$baseUrl$apiV1c/tasks/...'), headers: headers)
          .timeout(_timeout);
      final data = _handleResponse(response);
      if (data is Map && data.containsKey('tasks')) {
        return (data['tasks'] as List).map((j) => Task.fromJson(j)).toList();
      } else if (data is List) {
        return data.map((j) => Task.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching tasks: $e');
      throw ApiException('Error fetching tasks: $e');
    }
  }

  Future<Task> getTask(String taskId) async {
    try {
      final headers  = await _buildHeaders();
      final response = await _client
          .get(Uri.parse('$baseUrl$apiV1c/tasks/$taskId'), headers: headers)
          .timeout(_timeout);
      return Task.fromJson(_handleResponse(response));
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
        'title': title, 'description': description, 'priority': priority.name,
        'task_type': 'market_analysis', 'auto_trade_enabled': false, 'include_forecast': true,
      };
      if (kDebugMode) debugPrint('Creating task: $body');
      final headers  = await _buildHeaders();
      final response = await _client
          .post(Uri.parse('$baseUrl$apiV1c/tasks/create'),
              headers: headers, body: json.encode(body))
          .timeout(_timeout);
      final data = _handleResponse(response);
      if (kDebugMode) debugPrint('Task created: $data');
      return Task.fromJson(data);
    } catch (e) {
      debugPrint('Error creating task: $e');
      throw ApiException('Error creating task: $e');
    }
  }

  Future<Task> stopTask(String taskId) async {
    try {
      final headers  = await _buildHeaders();
      final response = await _client
          .post(Uri.parse('$baseUrl$apiV1c/tasks/$taskId/stop'), headers: headers)
          .timeout(_timeout);
      return Task.fromJson(_handleResponse(response));
    } catch (e) {
      throw ApiException('Error stopping task: $e');
    }
  }

  Future<Task> pauseTask(String taskId) async {
    try {
      final headers  = await _buildHeaders();
      final response = await _client
          .post(Uri.parse('$baseUrl$apiV1c/tasks/$taskId/pause'), headers: headers)
          .timeout(_timeout);
      return Task.fromJson(_handleResponse(response));
    } catch (e) {
      throw ApiException('Error pausing task: $e');
    }
  }

  Future<Task> resumeTask(String taskId) async {
    try {
      final headers  = await _buildHeaders();
      final response = await _client
          .post(Uri.parse('$baseUrl$apiV1c/tasks/$taskId/resume'), headers: headers)
          .timeout(_timeout);
      return Task.fromJson(_handleResponse(response));
    } catch (e) {
      throw ApiException('Error resuming task: $e');
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      final headers  = await _buildHeaders();
      final response = await _client
          .delete(Uri.parse('$baseUrl$apiV1c/tasks/$taskId'), headers: headers)
          .timeout(_timeout);
      _handleResponse(response);
    } catch (e) {
      throw ApiException('Error deleting task: $e');
    }
  }

  // =========================================================================
  // ACCOUNT CONNECTION ENDPOINTS
  // =========================================================================

  Future<List<AccountConnection>> getAccountConnections() async {
    try {
      final headers  = await _buildHeaders();
      final response = await _client
          .get(Uri.parse('$baseUrl$apiV1b/accounts/connections'), headers: headers)
          .timeout(_timeout);
      final data = _handleResponse(response);
      // Fixed: API returns 'accounts' not 'connections'
      if (data is Map && data.containsKey('accounts')) {
        return (data['accounts'] as List)
            .map((j) => AccountConnection.fromJson(j)).toList();
      }
      throw ApiException('Invalid connections response');
    } catch (e) {
      debugPrint('Error fetching account connections: $e');
      throw ApiException('Error fetching account connections: $e');
    }
  }

  Future<AccountConnection> connectForexAccount(String username, String password) async {
    try {
      final headers  = await _buildHeaders();
      final response = await _client
          .post(Uri.parse('$baseUrl$apiV1b/accounts/connect/forex'),
              headers: headers,
              body: json.encode({'username': username, 'password': password}))
          .timeout(_timeout);
      final data = _handleResponse(response);
      if (data['success'] == true && data.containsKey('connection')) {
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
      final headers  = await _buildHeaders();
      final response = await _client
          .post(Uri.parse('$baseUrl$apiV1b/accounts/disconnect'),
              headers: headers, body: json.encode({'account_id': accountId}))
          .timeout(_timeout);
      _handleResponse(response);
    } catch (e) {
      debugPrint('Error disconnecting account: $e');
      throw ApiException('Error disconnecting account: $e');
    }
  }

  Future<double> getAccountBalance(String accountId) async {
    try {
      final headers  = await _buildHeaders();
      final response = await _client
          .get(Uri.parse('$baseUrl$apiV1b/accounts/$accountId/balance'), headers: headers)
          .timeout(_timeout);
      final data = _handleResponse(response);
      if (data['success'] == true && data.containsKey('balance')) {
        return (data['balance'] as num).toDouble();
      }
      throw ApiException('Invalid balance response');
    } catch (e) {
      debugPrint('Error fetching account balance: $e');
      throw ApiException('Error fetching account balance: $e');
    }
  }

  // =========================================================================
  // MARKET DATA ENDPOINTS  (/api/v1  â€” no auth required)
  // =========================================================================

  /// Fetches live bid/ask/mid prices from /api/v1/market/prices.
  ///
  /// Backend response shape (Twelve Data via Railway):
  ///   {
  ///     "prices": [
  ///       { "instrument": "EUR_USD", "bid": 1.158, "ask": 1.159,
  ///         "mid": 1.1580, "spread": 1.0, "tradeable": true,
  ///         "timestamp": "2026-03-25T14:44:07.86+00:00" },
  ///       ...
  ///     ],
  ///     "cached": false,
  ///     "fetched_at": "...",
  ///     "source": "twelve_data"
  ///   }
  ///
  /// Returns the raw list so callers (MarketWatchProvider) can use
  /// PairQuote.fromBackend() directly. On any failure returns a synthetic
  /// list in the same shape so the UI always has data to display.
  Future<List<Map<String, dynamic>>> fetchMarketPrices({
    List<String> pairs = const ['EUR_USD', 'GBP_USD', 'USD_JPY'],
  }) async {
    // Backend expects underscore notation (EUR_USD).
    // Normalise slash input just in case callers pass EUR/USD.
    final backendPairs = pairs.map((p) => p.toUpperCase().replaceAll('/', '_')).toList();

    try {
      final uri = Uri.parse('$baseUrl$apiV1/market/prices').replace(
        queryParameters: {'pairs': backendPairs.join(',')},
      );
      // Public endpoint â€” no auth header (matches fetchOHLCData pattern).
      final response = await _client.get(uri).timeout(_timeout);
      final data     = _handleResponse(response);

      if (data is Map<String, dynamic> && data['prices'] is List) {
        return (data['prices'] as List).cast<Map<String, dynamic>>();
      }
      debugPrint('fetchMarketPrices: unexpected shape â€” ${data.runtimeType}');
      return _fallbackMarketPrices(backendPairs);
    } catch (e) {
      debugPrint('fetchMarketPrices error: $e');
      return _fallbackMarketPrices(backendPairs);
    }
  }

  /// Builds a synthetic price list matching the real backend shape so the
  /// UI renders correctly when the backend is offline or TWELVE_DATA_API_KEY
  /// is exhausted.
  List<Map<String, dynamic>> _fallbackMarketPrices(List<String> backendPairs) {
    final rates = _fallbackForexRates();
    final now   = DateTime.now().toUtc().toIso8601String();
    return backendPairs.map((instr) {
      final slashPair = instr.replaceAll('_', '/');
      final mid       = rates[slashPair] ?? _fallbackPairPrice(slashPair);
      final spread    = instr.contains('JPY') ? 0.012 : 0.0002;
      return <String, dynamic>{
        'instrument': instr,
        'bid':        _formatPrice(slashPair, mid - spread / 2),
        'ask':        _formatPrice(slashPair, mid + spread / 2),
        'mid':        _formatPrice(slashPair, mid),
        'spread':     instr.contains('JPY') ? 1.2 : 1.0,
        'tradeable':  false,  // false signals fallback to UI
        'timestamp':  now,
        'source':     'fallback',
      };
    }).toList();
  }

  Future<Map<String, dynamic>> fetchOHLCData({
    String pair = 'EUR/USD',
    String interval = '1h',
    int outputsize = 100,
  }) async {
    try {
      final uri      = Uri.parse(
          '$baseUrl$apiV1/market/ohlc?pair=${Uri.encodeComponent(pair)}&interval=$interval&outputsize=$outputsize');
      final response = await _client.get(uri).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error fetching OHLC data: $e');
      return {'values': []};
    }
  }

  // =========================================================================
  // SIGNALS & NEWS ENDPOINTS
  // =========================================================================

  Future<List<Map<String, dynamic>>> fetchLiveSignals({
    List<String> pairs = const ['EUR_USD', 'GBP_USD', 'USD_JPY'],
  }) async {
    try {
      final uri      = Uri.parse('$baseUrl$apiV1/signals/generate?pairs=${pairs.join(',')}');
      final headers  = await _buildHeaders();
      final response = await _client.post(uri, headers: headers).timeout(_timeout);
      final data     = _handleResponse(response);
      return (data['signals'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error fetching live signals: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> fetchNewsFeed({String pair = 'EUR/USD'}) async {
    try {
      final uri      = Uri.parse('$baseUrl$apiV1/news/feed?pair=${Uri.encodeComponent(pair)}');
      final response = await _client.get(uri).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error fetching news feed: $e');
      return {'top_headlines': [], 'status': 'error'};
    }
  }

  Future<List<Map<String, dynamic>>> fetchEconomicEvents({
    int hours = 48,
    bool highImpactOnly = false,
  }) async {
    try {
      final uri      = Uri.parse(
          '$baseUrl$apiV1/news/events?hours=$hours&high_impact_only=$highImpactOnly');
      final response = await _client.get(uri).timeout(_timeout);
      final data     = _handleResponse(response);
      return (data['events'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error fetching economic events: $e');
      return [];
    }
  }

  // =========================================================================
  // FOREX DATA ENDPOINTS  (/v1/api â€” authenticated)
  // =========================================================================

  Future<Map<String, dynamic>> getForexRates({List<String>? pairs}) async {
    final normalized = _normalizePairs(pairs);
    try {
      final headers = await _buildHeaders();
      final uri     = Uri.parse('$baseUrl$apiV1b/forex/rates').replace(
        queryParameters: normalized.isEmpty ? null : {'pairs': normalized.join(',')},
      );
      final response = await _client.get(uri, headers: headers).timeout(_timeout);
      final data     = _handleResponse(response);
      if (normalized.isNotEmpty && data is Map<String, dynamic>) {
        final rates = data['rates'];
        if (rates is Map<String, dynamic>) {
          data['rates'] = _filterRatesForPairs(rates, normalized);
        }
      }
      return data;
    } catch (e) {
      debugPrint('Error fetching forex rates: $e');
      return {
        'status': 'fallback',
        'rates': _filterRatesForPairs(_fallbackForexRates(), normalized),
      };
    }
  }

  Future<Map<String, dynamic>> getForexNews() async {
    try {
      final headers  = await _buildHeaders();
      final response = await _client
          .get(Uri.parse('$baseUrl$apiV1b/forex/news'), headers: headers)
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error fetching forex news: $e');
      return {
        'status': 'fallback',
        'news': [
          {
            'time': DateTime.now().toIso8601String(), 'currency': 'USD',
            'impact': 'high', 'event': 'US labor market update',
            'actual': 'N/A', 'forecast': 'N/A', 'previous': 'N/A',
          },
          {
            'time': DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String(),
            'currency': 'EUR', 'impact': 'medium', 'event': 'Eurozone inflation watch',
            'actual': 'N/A', 'forecast': 'N/A', 'previous': 'N/A',
          },
        ],
      };
    }
  }

  Future<Map<String, dynamic>> getForexMarketSentiment() async {
    try {
      final headers  = await _buildHeaders();
      final response = await _client
          .get(Uri.parse('$baseUrl$apiV1b/forex/sentiment'), headers: headers)
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error fetching market sentiment: $e');
      return {
        'status': 'fallback',
        'sentiment': {
          'trend': 'neutral', 'volatility': 'medium', 'risk_level': 'moderate',
          'timestamp': DateTime.now().toIso8601String(),
        },
      };
    }
  }

  Future<Map<String, dynamic>> getTradeSignals({List<String>? pairs}) async {
    final normalized  = _normalizePairs(pairs);
    final targetPairs = normalized.isEmpty
        ? const <String>['EUR/USD', 'GBP/USD', 'USD/JPY']
        : normalized;
    try {
      final headers = await _buildHeaders();
      final uri     = Uri.parse('$baseUrl$apiV1b/forex/signals').replace(
        queryParameters: targetPairs.isEmpty ? null : {'pairs': targetPairs.join(',')},
      );
      final response = await _client.get(uri, headers: headers).timeout(_timeout);
      final data     = _handleResponse(response);
      return data is Map<String, dynamic> ? data : {'signals': data};
    } catch (e) {
      debugPrint('Error fetching trade signals: $e');
      return {'status': 'fallback', 'signals': _buildFallbackSignals(targetPairs)};
    }
  }

  Future<Map<String, dynamic>> getForexPairForecast({
    required String pair,
    String horizon = '1d',
  }) async {
    final normPair    = pair.trim().toUpperCase();
    final normHorizon = horizon.trim().toLowerCase();
    try {
      final headers = await _buildHeaders();
      final uri     = Uri.parse('$baseUrl$apiV1b/forex/forecast').replace(
        queryParameters: {'pair': normPair, 'horizon': normHorizon},
      );
      final response = await _client.get(uri, headers: headers).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error fetching forex forecast: $e');
      final price  = _fallbackPairPrice(normPair);
      final digits = _pairDigits(normPair);
      return {
        'status': 'fallback',
        'forecast': {
          'pair': normPair, 'horizon': normHorizon,
          'generated_at': DateTime.now().toIso8601String(),
          'current_price': double.parse(price.toStringAsFixed(digits)),
          'trend_bias': 'neutral', 'volatility': 'medium', 'risk_level': 'moderate',
          'confidence_percent': 58,
          'expected_change_percent': {'low': -0.4, 'mid': 0.2, 'high': 0.8},
          'target_range': {
            'low':  double.parse((price * 0.996).toStringAsFixed(digits)),
            'high': double.parse((price * 1.006).toStringAsFixed(digits)),
          },
          'timing_guidance':
              'Fallback forecast active. Use staged entries/exits and confirm direction with fresh candles.',
          'disclaimer': 'Simulation-grade forecast. Not financial advice.',
        },
      };
    }
  }

  // =========================================================================
  // FEATURES / ADVANCED ENDPOINTS
  // =========================================================================

  Future<Map<String, dynamic>> parseNaturalLanguageCommand(String command) async {
    try {
      final headers  = await _buildHeaders();
      final uri      = Uri.parse('$baseUrl$apiV1b/advanced/nlp/parse-command')
          .replace(queryParameters: {'text': command});
      final response = await _client.post(uri, headers: headers).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error parsing NL command: $e');
      return {
        'success': false, 'confidence': 0.0,
        'command_type': 'unknown', 'ai_response': 'Command parser unavailable.',
      };
    }
  }

  Future<Map<String, dynamic>> getFeaturesStatus() async {
    try {
      final headers  = await _buildHeaders();
      final userId   = await _resolveUserId(headers: headers);
      final response = await _client
          .get(Uri.parse('$baseUrl$apiV1b/advanced/features/status?user_id=$userId'),
              headers: headers)
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error fetching features status: $e');
      final now = DateTime.now().toIso8601String();
      return {
        'success': true, 'timestamp': now,
        'features': {
          'smart_triggers':    {'active': true, 'count': 0, 'status': 'active', 'last_updated': now},
          'realtime_charts':   {'active': true, 'status': 'connected', 'last_updated': now,
                                'market_data': {'timestamp': now, 'trend': 'neutral', 'volatility': 'low', 'risk_level': 'low'}},
          'news_aware':        {'active': true, 'sentiment': 'neutral', 'volatility': 'low', 'risk_level': 'low', 'last_updated': now},
          'autonomous_actions':{'active': true, 'risk_level': 'moderate', 'predictions': 0, 'status': 'active', 'last_updated': now},
        },
        'market': {'sentiment': 'neutral', 'volatility': 'low', 'risk_level': 'low', 'rates': {}},
        'risk': {},
      };
    }
  }

  // =========================================================================
  // SECURITY & COMPLIANCE
  // =========================================================================

  Future<Map<String, dynamic>> getSecurityDashboard() async {
    try {
      final headers  = await _buildHeaders();
      final userId   = await _resolveUserId(headers: headers);
      final response = await _client
          .get(Uri.parse('$baseUrl$apiV1b/advanced/security/dashboard/$userId'),
              headers: headers)
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error fetching security dashboard: $e');
      throw ApiException('Error fetching security dashboard: $e');
    }
  }

  Future<Map<String, dynamic>> getAutonomyGuardrails() async {
    try {
      final headers  = await _buildHeaders();
      final userId   = await _resolveUserId(headers: headers);
      final response = await _client
          .get(Uri.parse('$baseUrl$apiV1b/advanced/autonomy/guardrails/$userId'),
              headers: headers)
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
    String? profile,
  }) async {
    try {
      final headers = await _buildHeaders();
      final userId  = await _resolveUserId(headers: headers);
      final body    = <String, dynamic>{'user_id': userId};
      if (level?.trim().isNotEmpty   == true) body['level']   = level!.trim().toLowerCase();
      if (profile?.trim().isNotEmpty == true) body['profile'] = profile!.trim().toLowerCase();
      if (probation  != null) body['probation']   = probation;
      if (riskBudget != null) body['risk_budget'] = riskBudget;
      final response = await _client
          .post(Uri.parse('$baseUrl$apiV1b/advanced/autonomy/guardrails/configure'),
              headers: headers, body: json.encode(body))
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
      final headers  = await _buildHeaders();
      final userId   = await _resolveUserId(headers: headers);
      final response = await _client
          .post(Uri.parse('$baseUrl$apiV1b/advanced/autonomy/explain-before-execute'),
              headers: headers,
              body: json.encode({'user_id': userId, 'trade_params': tradeParams}))
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
      final userId  = await _resolveUserId(headers: headers);
      final uri     = Uri.parse('$baseUrl$apiV1b/advanced/risk/execute-trade')
          .replace(queryParameters: {'user_id': userId});
      final payload = <String, dynamic>{...tradeParams};
      if (explainToken?.trim().isNotEmpty == true) payload['explain_token'] = explainToken!.trim();
      final response = await _client
          .post(uri, headers: headers, body: json.encode(payload))
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error executing autonomous trade: $e');
      throw ApiException('Error executing autonomous trade: $e');
    }
  }

  Future<Map<String, dynamic>> activateKillSwitch() async {
    try {
      final headers  = await _buildHeaders();
      final userId   = await _resolveUserId(headers: headers);
      final uri      = Uri.parse('$baseUrl$apiV1b/advanced/risk/kill-switch')
          .replace(queryParameters: {'user_id': userId});
      final response = await _client.post(uri, headers: headers).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error activating kill switch: $e');
      throw ApiException('Error activating kill switch: $e');
    }
  }

  // =========================================================================
  // RISK GUARDIAN ENDPOINTS (Phase 6)
  // =========================================================================

  Future<Map<String, dynamic>> fetchKellyCriterion({
    required double winRate,
    required double avgWin,
    required double avgLoss,
    required double accountBalance,
    double kellyFraction = 0.25,
  }) async {
    try {
      final response = await _client
          .post(Uri.parse('$baseUrl$apiV1/risk/kelly'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'win_rate': winRate, 'avg_win': avgWin, 'avg_loss': avgLoss,
                'account_balance': accountBalance, 'kelly_fraction': kellyFraction,
              }))
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Kelly error: $e');
    }
  }

  Future<Map<String, dynamic>> fetchDrawdownControls({
    required double accountBalance,
    double dailyLossLimitPct  = 0.03,
    double weeklyLossLimitPct = 0.06,
    int maxOpenTrades         = 3,
    double riskPerTradePct    = 0.01,
  }) async {
    try {
      final response = await _client
          .post(Uri.parse('$baseUrl$apiV1/risk/drawdown'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'account_balance': accountBalance,
                'daily_loss_limit_pct': dailyLossLimitPct,
                'weekly_loss_limit_pct': weeklyLossLimitPct,
                'max_open_trades': maxOpenTrades,
                'risk_per_trade_pct': riskPerTradePct,
              }))
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Drawdown error: $e');
    }
  }

  Future<Map<String, dynamic>> fetchStressTest({
    required double winRate,
    required double avgWin,
    required double avgLoss,
    required double startingBalance,
    int numTrades   = 100,
    int simulations = 300,
  }) async {
    try {
      final response = await _client
          .post(Uri.parse('$baseUrl$apiV1/risk/stress-test'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'win_rate': winRate, 'avg_win': avgWin, 'avg_loss': avgLoss,
                'starting_balance': startingBalance, 'num_trades': numTrades,
                'simulations': simulations,
              }))
          .timeout(const Duration(seconds: 30));
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Stress test error: $e');
    }
  }

  // =========================================================================
  // RISK SIMULATOR ENDPOINTS
  // =========================================================================

  Future<Map<String, dynamic>> fetchRiskSimulation({
    double winRate         = 0.55,
    double avgWin          = 50.0,
    double avgLoss         = 30.0,
    int numTrades          = 100,
    double startingBalance = 10000.0,
    int simulations        = 1000,
  }) async {
    try {
      final response = await _client
          .post(Uri.parse('$baseUrl$apiV1/risk/simulate'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'win_rate': winRate, 'avg_win': avgWin, 'avg_loss': avgLoss,
                'num_trades': numTrades, 'starting_balance': startingBalance,
                'simulations': simulations,
              }))
          .timeout(const Duration(seconds: 30));
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error running risk simulation: $e');
      throw ApiException('Error running risk simulation: $e');
    }
  }

  // =========================================================================
  // NLP VOICE COPILOT (Phase 7)
  // =========================================================================
  // NLP VOICE COPILOT (Phase 7)
  // =========================================================================

  Future<Map<String, dynamic>> parseNLPCommand({
    required String text,
    double accountBalance = 10000.0,
  }) async {
    try {
      final response = await _client
          .post(Uri.parse('$baseUrl$apiV1/signals/nlp/parse'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({'text': text, 'account_balance': accountBalance}))
          .timeout(const Duration(seconds: 10));
      return _handleResponse(response);
    } catch (e) {
      debugPrint('NLP parse error: $e');
      return {'intent': 'CHAT', 'confidence': 0.0, 'response': null};
    }
  }

  Future<Map<String, dynamic>> aiChat(
    List<Map<String, dynamic>> messages, {
    String? pair,
    Map<String, dynamic>? context,
  }) async {
    try {
      final headers = await _buildHeaders();
      final body = <String, dynamic>{
        'messages': messages,
        if (pair?.trim().isNotEmpty == true) 'pair': pair!.trim().toUpperCase(),
        if (context != null) 'context': context,
      };
      final response = await _client
          .post(
            Uri.parse('$baseUrl$apiV1b/advanced/nlp/chat'),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(_authTimeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('aiChat error: $e');
      return {
        'success': false,
        'response': 'AI chat is temporarily unavailable. Please try again shortly.',
        'error': e.toString(),
      };
    }
  }

  // =========================================================================
  // PAPER TRADING ENDPOINTS
  // =========================================================================

  Future<Map<String, dynamic>> openPaperTrade({
    required String userId,
    required String pair,
    required String direction,
    required double entryPrice,
    required double stopLoss,
    required double takeProfit,
    double lotSize  = 1000.0,
    String? reasoning,
    String? signalId,
  }) async {
    try {
      final response = await _client
          .post(Uri.parse('$baseUrl$apiV1/paper/open'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'user_id': userId, 'pair': pair, 'direction': direction,
                'entry_price': entryPrice, 'stop_loss': stopLoss,
                'take_profit': takeProfit, 'lot_size': lotSize,
                if (reasoning != null) 'reasoning': reasoning,
                if (signalId  != null) 'signal_id': signalId,
              }))
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      debugPrint('openPaperTrade error: $e');
      throw ApiException('Error opening paper trade: $e');
    }
  }

  Future<Map<String, dynamic>> closePaperTrade({
    required String tradeId,
    required double closePrice,
    String closeReason = 'manual',
  }) async {
    try {
      final response = await _client
          .post(Uri.parse('$baseUrl$apiV1/paper/close'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'trade_id': tradeId, 'close_price': closePrice, 'close_reason': closeReason,
              }))
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Error closing paper trade: $e');
    }
  }

  Future<Map<String, dynamic>> fetchOpenPaperTrades({required String userId}) async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl$apiV1/paper/trades/open?user_id=$userId'))
          .timeout(const Duration(seconds: 10));
      return _handleResponse(response);
    } catch (e) {
      return {'trades': [], 'count': 0};
    }
  }

  Future<Map<String, dynamic>> fetchPaperTradeHistory({
    required String userId,
    int limit = 50,
  }) async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl$apiV1/paper/trades/history?user_id=$userId&limit=$limit'))
          .timeout(const Duration(seconds: 10));
      return _handleResponse(response);
    } catch (e) {
      return {'trades': [], 'count': 0};
    }
  }

  Future<Map<String, dynamic>> fetchPaperPerformance({required String userId}) async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl$apiV1/paper/performance?user_id=$userId'))
          .timeout(const Duration(seconds: 10));
      return _handleResponse(response);
    } catch (e) {
      return {'total_trades': 0, 'win_rate': 0.0, 'total_pnl': 0.0};
    }
  }

// Public instance accessors for external services (e.g. NotificationService)
  Future<Map<String, String>> authHeaders() => _buildHeaders();
  String get instanceBaseUrl => ApiService.baseUrl;

  void dispose() => _client.close();
}