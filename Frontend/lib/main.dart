import 'package:forex_companion/services/api_service.dart';
import 'providers/quick_actions_provider.dart';
import 'providers/custom_setup_provider.dart';
import 'providers/mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'routes/app_routes.dart';
import 'core/config/firebase_config.dart';
import 'core/config/release_build_guard.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'services/firebase_service.dart';
import 'services/live_updates_service.dart';
import 'providers/task_provider.dart';
import 'providers/user_provider.dart';
import 'providers/header_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/account_connection_provider.dart';
import 'providers/agent_orchestrator_provider.dart';
import 'providers/market_watch_provider.dart';
import 'providers/trade_signals_provider.dart';
import 'providers/chart_provider.dart';
import 'providers/news_events_provider.dart';
import 'providers/risk_provider.dart';
import 'providers/paper_trading_provider.dart';
import 'core/utils/runtime_url_resolver.dart';
import 'helpers/mock_data_helper.dart';

// Toggle Firebase initialization (Auth/Storage/etc)
const bool useFirebaseAuth = true;

// Use anonymous sign-in so API requests have a Firebase ID token in dev
const bool useAnonymousAuth = false;

// Toggle Firestore-backed tasks on the client (backend is now source of truth)
const bool useFirestoreTasks = false;

// Set to true for UI development without a backend.
const bool useMockData = false;

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

  // Phase 13 - Notification service init

  bool firebaseReady = false;
  if (useFirebaseAuth) {
    try {
      await Firebase.initializeApp(
        options: FirebaseConfig.currentPlatform,
      );
      firebaseReady = true;
      debugPrint('Firebase initialized successfully');
      debugPrint('Project: forexcompanion-e5a28');

      if (useAnonymousAuth) {
        try {
          final auth = firebase_auth.FirebaseAuth.instance;
          if (auth.currentUser == null) {
            await auth.signInAnonymously();
            debugPrint('Signed in anonymously');
          }
        } catch (e) {
          debugPrint('Anonymous sign-in failed: $e');
        }
      }
    } catch (e) {
      debugPrint('Firebase initialization error: $e');
      debugPrint('Falling back to API mode');
    }
  } else {
    debugPrint('Running in API-only mode (Firebase disabled)');
  }

  runApp(ForexCompanionApp(firebaseReady: firebaseReady));
}

class ForexCompanionApp extends StatelessWidget {
  final bool firebaseReady;
  const ForexCompanionApp({super.key, required this.firebaseReady});

  @override
  Widget build(BuildContext context) {
    final apiService = ApiService();
    final firebaseService =
        (useFirebaseAuth && firebaseReady) ? FirebaseService() : null;

    return MultiProvider(
      providers: [
        // Ã¢â€â‚¬Ã¢â€â‚¬ Services Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
        Provider<ApiService>.value(value: apiService),
        if (firebaseService != null)
          Provider<FirebaseService>.value(value: firebaseService),
        Provider<LiveUpdatesService>(
          create: (_) => LiveUpdatesService(),
          dispose: (_, service) => service.dispose(),
        ),

        // Ã¢â€â‚¬Ã¢â€â‚¬ Core providers Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
        ChangeNotifierProvider(create: (_) => ModeProvider()..load()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),

        // Ã¢â€â‚¬Ã¢â€â‚¬ Quick actions (loads persisted dismiss state on boot) Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
        ChangeNotifierProvider(
          create: (_) => QuickActionsProvider()..load(),
        ),

        // Ã¢â€â‚¬Ã¢â€â‚¬ Custom setup preferences Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
        ChangeNotifierProvider(create: (_) => CustomSetupProvider()),

        // Ã¢â€â‚¬Ã¢â€â‚¬ Mode-specific live data providers Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
        ChangeNotifierProvider(create: (ctx) => MarketWatchProvider(apiService: ctx.read<ApiService>())..init()),
        ChangeNotifierProvider(create: (ctx) => ChartProvider(ctx.read<ApiService>())),
        ChangeNotifierProvider(create: (ctx) => TradeSignalsProvider(ctx.read<ApiService>())..init()),
        ChangeNotifierProvider(create: (ctx) => NewsEventsProvider(ctx.read<ApiService>())..init()),
        ChangeNotifierProvider(create: (ctx) => RiskProvider(ctx.read<ApiService>())),
        ChangeNotifierProvider(create: (ctx) => PaperTradingProvider(ctx.read<ApiService>())),

        // Ã¢â€â‚¬Ã¢â€â‚¬ Feature providers Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
        ChangeNotifierProvider(
          create: (_) {
            final provider = TaskProvider(
              apiService: apiService,
              firebaseService: firebaseService,
              useFirebase: useFirestoreTasks && firebaseReady && !useMockData,
            );
            if (useMockData) MockDataHelper.loadMockData(provider);
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final provider = UserProvider(apiService: apiService);
            if (useMockData) provider.setUser(MockDataHelper.generateMockUser());
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final provider = HeaderProvider(apiService: apiService);
            if (useMockData) {
              provider.setHeader(MockDataHelper.generateMockHeader());
            }
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => AccountConnectionProvider()..loadConnections(),
        ),
        ChangeNotifierProvider(
          create: (_) => AgentOrchestratorProvider(apiService: apiService),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          title: 'Forex Companion',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.getThemeData(),
          routes: AppRoutes.routes,
          initialRoute: '/',
        ),
      ),
    );
  }
}


