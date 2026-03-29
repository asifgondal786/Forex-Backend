import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
}

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final ApiService _api;

  NotificationService(this._api);

  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await _fcm.getToken();
    if (token != null) await _registerToken(token);

    _fcm.onTokenRefresh.listen(_registerToken);
    FirebaseMessaging.onMessage.listen(_handleForeground);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    final initial = await _fcm.getInitialMessage();
    if (initial != null) _handleTap(initial);
  }

  Future<void> _registerToken(String token) async {
    try {
      final platform = kIsWeb
          ? 'web'
          : defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android';

      final authHeaders = await _api.authHeaders();
      final uri = Uri.parse(
          '${_api.baseUrl}/api/v1/notifications/device/register');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          ...authHeaders,
        },
        body: jsonEncode({'fcm_token': token, 'platform': platform}),
      );
      debugPrint('[FCM] Register response: ${response.statusCode}');
    } catch (e) {
      debugPrint('[FCM] Token registration failed: $e');
    }
  }

  void _handleForeground(RemoteMessage message) {
    debugPrint('[FCM] Foreground: ${message.notification?.title}');
  }

  void _handleTap(RemoteMessage message) {
    final eventType = message.data['event_type'] ?? '';
    debugPrint('[FCM] Tapped: $eventType');
  }
}