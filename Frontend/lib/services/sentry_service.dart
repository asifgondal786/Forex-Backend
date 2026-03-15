import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Tajir Sentry service.
/// Call [SentryService.init] once, wrapping runApp().
/// Use [SentryService.captureException] anywhere in the app.
class SentryService {
  SentryService._();

  static bool _initialised = false;

  /// Wrap your runApp() call with this.
  /// [appRunner] is a callback that calls runApp(MyApp()).
  ///
  /// Usage in main.dart:
  ///   await SentryService.init(() => runApp(const MyApp()));
  static Future<void> init(AppRunner appRunner) async {
    const dsn = String.fromEnvironment('SENTRY_DSN');

    if (dsn.isEmpty) {
      debugPrint('⚠️  SENTRY_DSN not provided — Sentry disabled.');
      await appRunner();
      return;
    }

    await SentryFlutter.init(
      (options) {
        options.dsn = dsn;

        // Environment tag: 'development' in debug, 'production' in release
        options.environment = kDebugMode ? 'development' : 'production';

        // 20% of navigations become performance transactions
        options.tracesSampleRate = 0.2;

        // Capture Flutter framework errors
        options.enableAutoSessionTracking = true;
        options.attachStacktrace = true;

        // Navigator observer for screen-level breadcrumbs
        // (Add SentryNavigatorObserver() to MaterialApp.navigatorObservers)
        options.enableAutoNativeBreadcrumbs = true;

        // Don't send PII
        options.sendDefaultPii = false;

        // Release tagging (set via --dart-define at build time)
        const release = String.fromEnvironment('APP_VERSION');
        if (release.isNotEmpty) {
          options.release = 'tajir@$release';
        }
      },
      appRunner: appRunner,
    );

    _initialised = true;
    debugPrint('✅ Sentry initialised');
  }

  /// Manually capture an exception (e.g. in catch blocks).
  static Future<void> captureException(
    Object error,
    StackTrace? stackTrace, {
    String? hint,
    Map<String, dynamic>? extras,
  }) async {
    if (!_initialised) return;

    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      hint: hint != null ? Hint.withMap({'hint': hint}) : null,
      withScope: extras != null
          ? (scope) {
              extras.forEach((k, v) => scope.setTag(k, v.toString()));
            }
          : null,
    );
  }

  /// Tag the current session with the authenticated user ID.
  /// Call after successful login. Pass null on logout.
  static Future<void> setUser(String? userId) async {
    if (!_initialised) return;
    await Sentry.configureScope((scope) {
      scope.setUser(userId != null ? SentryUser(id: userId) : null);
    });
  }

  /// Add a breadcrumb manually (e.g. "User tapped Trade button").
  static void addBreadcrumb(String message, {String category = 'ui.action'}) {
    if (!_initialised) return;
    Sentry.addBreadcrumb(
      Breadcrumb(message: message, category: category),
    );
  }
}

// Type alias to match SentryFlutter's expected callback signature
typedef AppRunner = Future<void> Function();
