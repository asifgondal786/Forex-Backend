import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'routes/app_routes.dart';
import 'core/config/firebase_config.dart';
import 'services/api_service.dart';
import 'services/firebase_service.dart';
import 'providers/task_provider.dart';
import 'providers/user_provider.dart';
import 'providers/theme_provider.dart';
import 'helpers/mock_data_helper.dart';

// Toggle Firebase initialization (Auth/Storage/etc)
const bool useFirebaseAuth = true;

// Toggle Firestore-backed tasks on the client (backend is now the source of truth)
const bool useFirestoreTasks = false;

// Set to true for UI development without a backend. Overrides task/API usage.
const bool useMockData = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase if enabled
  bool firebaseReady = false;
  if (useFirebaseAuth) {
    try {
      await Firebase.initializeApp(
        options: FirebaseConfig.currentPlatform,
      );
      firebaseReady = true;
      debugPrint('Firebase initialized successfully');
      debugPrint('Project: forexcompanion-e5a28');
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
    // Initialize services
    final apiService = ApiService();
    final firebaseService = (useFirebaseAuth && firebaseReady) ? FirebaseService() : null;

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
              useFirebase: useFirestoreTasks && firebaseReady && !useMockData,
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
  }
}
