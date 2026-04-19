// lib/services/chart_service.dart
//
// Lightweight init wrapper for Phase 16 TradingView charting.
// Called once from main() before runApp so the webview platform
// is registered before any chart widget is created.

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class ChartService {
  ChartService._();

  static bool _initialized = false;

  /// Call once from main() after WidgetsFlutterBinding.ensureInitialized().
  static Future<void> init() async {
    if (_initialized) return;

    try {
      // On Android, enable debugging for InAppWebView in debug builds.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
      }
      _initialized = true;
      debugPrint('[ChartService] Initialized successfully.');
    } catch (e) {
      // Non-fatal — charts will still render, just without debug tooling.
      debugPrint('[ChartService] Init warning: $e');
      _initialized = true;
    }
  }

  static bool get isInitialized => _initialized;
}

