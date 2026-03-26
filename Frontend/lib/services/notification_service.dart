// lib/services/notification_service.dart
// Phase 13 — Flutter FCM token registration + permission handling
//
// Call NotificationService().initialize() from main.dart after login.
// It requests permission, gets the FCM token, and POSTs it to the backend.

import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';   // existing service — has authHeaders()

// Top-level handler required by Firebase for background messages
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
  // Background messages are shown automatically by the OS — no action needed
}

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final ApiService _api;

  NotificationService(this._api);

  Future<void> initialize() async {
    // 1 — Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // 2 — Request permission (iOS requires explicit ask; Android 13+ also needs it)
    final settings = await _fcm.requestPermission(
      alert:         true,
      badge:         true,
      sound:         true,
      announcement:  false,
      carPlay:       false,
      criticalAlert: false,
      provisional:   false,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // 3 — Get token and register with backend
    final token = await _fcm.getToken();
    if (token != null) {
      await _registerToken(token);
    }

    // 4 — Refresh token when Firebase rotates it
    _fcm.onTokenRefresh.listen(_registerToken);

    // 5 — Handle foreground messages (show in-app banner or snackbar)
    FirebaseMessaging.onMessage.listen(_handleForeground);

    // 6 — Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // 7 — Handle notification that launched the app from terminated state
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _handleTap(initial);
  }

  // ── Token registration ─────────────────────────────────────────────────

  Future<void> _registerToken(String token) async {
    try {
      final platform = kIsWeb
          ? 'web'
          : defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android';

      await _api.post(
        '/api/v1/notifications/device/register',
        body: {'fcm_token': token, 'platform': platform},
      );
      debugPrint('[FCM] Token registered: ${token.substring(0, 20)}...');
    } catch (e) {
      debugPrint('[FCM] Token registration failed: $e');
    }
  }

  // ── Message handlers ───────────────────────────────────────────────────

  void _handleForeground(RemoteMessage message) {
    debugPrint('[FCM] Foreground: ${message.notification?.title}');
    // TODO (Phase 13): Show in-app SnackBar or overlay banner
    // Example: NotificationBanner.show(message.notification?.title ?? '');
  }

  void _handleTap(RemoteMessage message) {
    final eventType = message.data['event_type'] ?? '';
    debugPrint('[FCM] Tapped: $eventType');
    // TODO (Phase 13): Route to relevant screen based on event_type
    // e.g. "trade" → TradeHistoryScreen, "risk" → RiskDashboardScreen
  }
}