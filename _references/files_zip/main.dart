import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_shell.dart';
import 'features/auth/login_screen.dart';
import 'providers/portfolio_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/beginner_mode_provider.dart';
import 'providers/automation_provider.dart';
import 'providers/social_provider.dart';
import 'providers/trade_execution_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO: await Firebase.initializeApp(); when Firebase is configured
  runApp(const TajirApp());
}

class TajirApp extends StatelessWidget {
  const TajirApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PortfolioProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => BeginnerModeProvider()..load()),
        ChangeNotifierProvider(create: (_) => AutomationProvider()),
        ChangeNotifierProvider(create: (_) => SocialProvider()),
        ChangeNotifierProvider(create: (_) => TradeExecutionProvider()),
      ],
      child: MaterialApp(
        title: 'Tajir',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: ThemeMode.dark, // Default to dark — trading apps prefer dark
        home: const _AuthGate(),
      ),
    );
  }
}

/// AuthGate decides whether to show login or app shell.
/// Replace isAuthenticated logic with your actual auth provider.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with real auth check from your AuthProvider
    const bool isAuthenticated = true;
    return isAuthenticated ? const AppShell() : const LoginScreen();
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2563EB), // Tajir blue
    brightness: brightness,
    surface: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
    surfaceContainerHighest:
        isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
    primary: const Color(0xFF3B82F6),
    primaryContainer: const Color(0xFF1D4ED8),
    onPrimary: Colors.white,
    secondary: const Color(0xFF10B981),
    onSecondary: Colors.white,
    error: const Color(0xFFEF4444),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    fontFamily: 'Inter', // Add Inter to pubspec.yaml fonts
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: colorScheme.onSurface),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
        fontFamily: 'Inter',
      ),
    ),
    cardTheme: CardTheme(
      color: colorScheme.surfaceContainerHighest,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.primary,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outline.withOpacity(0.12),
      space: 1,
      thickness: 1,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return isDark ? Colors.grey.shade600 : Colors.grey.shade400;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colorScheme.primary;
        return isDark ? Colors.grey.shade800 : Colors.grey.shade300;
      }),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: colorScheme.primary,
      inactiveTrackColor: colorScheme.primary.withOpacity(0.2),
      thumbColor: colorScheme.primary,
      overlayColor: colorScheme.primary.withOpacity(0.12),
      trackHeight: 4,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surfaceContainerHighest,
      selectedColor: colorScheme.primary,
      labelStyle: TextStyle(
        fontSize: 13,
        fontFamily: 'Inter',
        color: colorScheme.onSurface,
      ),
      side: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    tabBarTheme: TabBarTheme(
      labelColor: colorScheme.primary,
      unselectedLabelColor: colorScheme.onSurface.withOpacity(0.5),
      indicatorColor: colorScheme.primary,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: const TextStyle(
          fontWeight: FontWeight.w700, fontFamily: 'Inter', fontSize: 14),
      unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500, fontFamily: 'Inter', fontSize: 14),
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
        borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(
        color: colorScheme.onSurface.withOpacity(0.35),
        fontFamily: 'Inter',
        fontSize: 14,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
