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

// Toggle this to switch between Firebase and API mode
const bool useFirebase = true;

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
    // Initialize services
    final apiService = ApiService();
    final websocketService = WebSocketService();
    final firebaseService = useFirebase ? FirebaseService() : null;

    return MultiProvider(
      providers: [
        // Services
        Provider<ApiService>.value(value: apiService),
        Provider<WebSocketService>.value(value: websocketService),
        if (firebaseService != null)
          Provider<FirebaseService>.value(value: firebaseService),
        
        // Providers
        ChangeNotifierProvider(
          create: (_) => TaskProvider(
            apiService: apiService,
            firebaseService: firebaseService,
            useFirebase: useFirebase,
          )..fetchTasks(),
        ),
        ChangeNotifierProvider(
          create: (_) => UserProvider(apiService: apiService)..fetchUser(),
        ),
      ],
      child: MaterialApp(
        title: 'Forex Companion',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primaryBlue,
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: AppColors.backgroundDark,
        ),
        routes: AppRoutes.routes,
        initialRoute: '/',
      ),
    );
  }
}