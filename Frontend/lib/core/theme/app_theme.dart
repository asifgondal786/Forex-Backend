import 'package:flutter/material.dart';

class AppTheme {
  // Light Theme Colors
  static const Color _lightPrimaryBlue = Color(0xFF3B82F6);
  static const Color _lightPrimaryGreen = Color(0xFF10B981);
  static const Color _lightWarningOrange = Color(0xFFF59E0B);
  static const Color _lightErrorRed = Color(0xFFEF4444);
  static const Color _lightBackground = Color(0xFFF8F9FA);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightText = Color(0xFF1F2937);

  // Dark Theme Colors
  static const Color _darkPrimaryBlue = Color(0xFF3B82F6);
  static const Color _darkPrimaryGreen = Color(0xFF10B981);
  static const Color _darkWarningOrange = Color(0xFFF59E0B);
  static const Color _darkErrorRed = Color(0xFFEF4444);
  static const Color _darkBackground = Color(0xFF0F1419);
  static const Color _darkSurface = Color(0xFF1A1F2E);
  static const Color _darkText = Color(0xFFF3F4F6);

  // Light Theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: _lightPrimaryBlue,
    scaffoldBackgroundColor: _lightBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: _lightSurface,
      foregroundColor: _lightText,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: _lightText,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: const CardTheme(
      color: _lightSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _lightPrimaryBlue,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 12,
        ),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: _lightText,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      displayMedium: TextStyle(
        color: _lightText,
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: TextStyle(
        color: _lightText,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: _lightText,
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        color: _lightText,
        fontSize: 14,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      fillColor: Colors.white,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _lightPrimaryBlue, width: 2),
      ),
      labelStyle: const TextStyle(color: _lightText),
    ),
    colorScheme: const ColorScheme.light(
      primary: _lightPrimaryBlue,
      secondary: _lightPrimaryGreen,
      error: _lightErrorRed,
      surface: _lightSurface,
      background: _lightBackground,
    ),
  );

  // Dark Theme
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: _darkPrimaryBlue,
    scaffoldBackgroundColor: _darkBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: _darkSurface,
      foregroundColor: _darkText,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: _darkText,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: const CardTheme(
      color: _darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _darkPrimaryBlue,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 12,
        ),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: _darkText,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      displayMedium: TextStyle(
        color: _darkText,
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: TextStyle(
        color: _darkText,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: _darkText,
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        color: _darkText,
        fontSize: 14,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      fillColor: _darkSurface,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF374151)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF374151)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _darkPrimaryBlue, width: 2),
      ),
      labelStyle: const TextStyle(color: _darkText),
    ),
    colorScheme: const ColorScheme.dark(
      primary: _darkPrimaryBlue,
      secondary: _darkPrimaryGreen,
      error: _darkErrorRed,
      surface: _darkSurface,
      background: _darkBackground,
    ),
  );
}
