import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'routes/app_routes.dart';
import 'core/theme/app_colors.dart';
import 'core/config/firebase_config.dart';
import 'services/api_service.dart';
import 'services/websocket_service.dart';
import 'services/firebase_service.dart';
import 'providers/task_provider.dart';
import 'providers/user_provider.dart';
import 'providers/theme_provider.dart';
import 'helpers/mock_data_helper.dart';

// Toggle this to switch between Firebase and API mode
const bool useFirebase = true;

// Set to true for UI development without a backend. Overrides useFirebase.
const bool useMockData = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase if enabled
  if (useFirebase) {
    try {
      await Firebase.initializeApp(
        options: FirebaseConfig.currentPlatform,
      );
      debugPrint('✅ Firebase initialized successfully');
      debugPrint('📱 Project: forexcompanion-e5a28');
    } catch (e) {
      debugPrint('❌ Firebase initialization error: $e');
      debugPrint('⚠️ Falling back to API mode');
    }
  } else {
    debugPrint('ℹ️ Running in API-only mode (Firebase disabled)');
  }
  
  runApp(const ForexCompanionApp());
}

class ForexCompanionApp extends StatelessWidget {
  const ForexCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      // Initialize services
      final apiService = ApiService();
      final firebaseService = useFirebase ? FirebaseService() : null;

      return MultiProvider(
        providers: [
          // Services
          Provider<ApiService>.value(value: apiService),
          if (firebaseService != null)
            Provider<FirebaseService>.value(value: firebaseService),
          
          // Theme Provider
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          
          // Providers
          ChangeNotifierProvider(
            create: (_) {
              final provider = TaskProvider(
                apiService: apiService,
                firebaseService: firebaseService,
                useFirebase: useFirebase && !useMockData,
              );
              if (useMockData) {
                MockDataHelper.loadMockData(provider);
              } else {
                provider.fetchTasks();
              }
              return provider;
            },
          ),
          ChangeNotifierProvider(
            create: (_) {
              final provider = UserProvider(apiService: apiService);
              if (useMockData) {
                provider.setUser(MockDataHelper.generateMockUser());
              } else {
                provider.fetchUser();
              }
              return provider;
            },
          ),       
        ],
        child: Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) {
            return MaterialApp(
              title: 'Forex Companion',
              debugShowCheckedModeBanner: false,
              theme: themeProvider.getThemeData(),
              routes: AppRoutes.routes,
              initialRoute: '/',
            );
          },
        ),
      );
    } catch (e) {
      debugPrint('❌ App initialization error: $e');
      return MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0F1419),
          body: Center(
            child: Text(
              'App Error: $e',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
    }
  }
}