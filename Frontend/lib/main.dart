// lib/main.dart
//
// Tajir — entry point.
// Providers: ONLY what the 4 active screens (Home, Signals, Agent, Settings) need.
// Everything from lib/archive/ is intentionally excluded.

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forex_companion/providers/mode_provider.dart';
import 'package:provider/provider.dart';

import 'core/config/firebase_config.dart';
import 'core/config/release_build_guard.dart';
import 'core/utils/runtime_url_resolver.dart';
import 'providers/account_connection_provider.dart';
import 'providers/app_shell_provider.dart';
import 'providers/automation_provider.dart';
import 'providers/market_watch_provider.dart';
import 'providers/news_events_provider.dart';
import 'providers/risk_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/trade_signals_provider.dart';
import 'providers/user_provider.dart';
import 'routes/app_routes.dart';
import 'services/api_service.dart';
import 'services/chart_service.dart';
import 'services/firebase_service.dart';

// ── Auth flags ───────────────────────────────────────────────────────────
const bool useFirebaseAuth  = true;
const bool useAnonymousAuth = false;

void _validateUrlConfigOnBoot() {
  if (kDebugMode) return;
  final apiBaseUrl = ApiService.baseUrl;
  assertSecureRuntimeUrl(
    apiBaseUrl,
    label: 'API_BASE_URL',
    allowHttpInRelease: false,
  );
  resolveAppWebUrl(
    const String.fromEnvironment('APP_WEB_URL', defaultValue: ''),
  );
}

Future<void> main() async {
  ensureReleaseBuildConfig();
  WidgetsFlutterBinding.ensureInitialized();
  _validateUrlConfigOnBoot();
  await ChartService.init();

  var firebaseReady = false;
  if (useFirebaseAuth) {
    try {
      await Firebase.initializeApp(
        options: FirebaseConfig.currentPlatform,
      );
      firebaseReady = true;
      if (useAnonymousAuth) {
        final auth = firebase_auth.FirebaseAuth.instance;
        if (auth.currentUser == null) {
          await auth.signInAnonymously();
        }
      }
    } catch (e) {
      debugPrint('Firebase initialization error: $e');
    }
  }

  runApp(TajirApp(firebaseReady: firebaseReady));
}

class TajirApp extends StatelessWidget {
  final bool firebaseReady;
  const TajirApp({super.key, required this.firebaseReady});

  @override
  Widget build(BuildContext context) {
    final apiService     = ApiService();
    final firebaseService =
        (useFirebaseAuth && firebaseReady) ? FirebaseService() : null;

    return MultiProvider(
      providers: [
        // ── Core services ──────────────────────────────────────────────
        Provider<ApiService>.value(value: apiService),
        if (firebaseService != null)
          Provider<FirebaseService>.value(value: firebaseService),

        // ── UI / shell ─────────────────────────────────────────────────
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AppShellProvider()),

        // ── Account & broker connection (Home + Settings + Agent) ──────
        ChangeNotifierProvider(
          create: (_) => AccountConnectionProvider()..loadConnections(),
        ),

        // ── User (Settings, auth checks) ───────────────────────────────
        ChangeNotifierProvider(
          create: (_) => UserProvider(apiService: apiService),
        ),

        // ── Market data (Home screen — live prices) ────────────────────
        ChangeNotifierProvider(
          create: (ctx) =>
              MarketWatchProvider(apiService: ctx.read<ApiService>())..init(),
        ),

        // ── News feed (Home screen) ────────────────────────────────────
        ChangeNotifierProvider(
          create: (ctx) =>
              NewsEventsProvider(ctx.read<ApiService>())..init(),
        ),

        // ── Trade signals (Signals screen) ─────────────────────────────
        ChangeNotifierProvider(
          create: (ctx) =>
              TradeSignalsProvider(ctx.read<ApiService>())..init(),
        ),

        // ── Risk guardian (Agent screen + Settings) ────────────────────
        ChangeNotifierProvider(
          create: (ctx) => RiskProvider(ctx.read<ApiService>()),
        ),

        // ── Automation / agent modes (Agent screen) ────────────────────
        ChangeNotifierProvider(create: (_) => AutomationProvider()),
        ChangeNotifierProvider(
          create: (_) {
            final provider = ModeProvider();
            provider.load(); // Fire async init in background
            return provider;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          title: 'Tajir',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: themeProvider.themeMode,
          initialRoute: AppRoutes.root,
          routes: AppRoutes.routes,
        ),
      ),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2563EB),
    brightness: brightness,
    surface: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
    surfaceContainerHighest:
        isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
    primary: const Color(0xFF3B82F6),
    secondary: const Color(0xFF10B981),
    error: const Color(0xFFEF4444),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        fontFamily: 'Inter',
      ),
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surfaceContainerHighest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: colorScheme.onSurface,
      textColor: colorScheme.onSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );
}