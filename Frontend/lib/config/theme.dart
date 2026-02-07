import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Color Palette from Forex Companion Design
  static const Color primaryDark = Color(0xFF0A1628);
  static const Color primaryDarkBlue = Color(0xFF1A2742);
  static const Color accentCyan = Color(0xFF00D9FF);
  static const Color accentTeal = Color(0xFF00FFC2);
  static const Color successGreen = Color(0xFF00FF88);
  static const Color warningOrange = Color(0xFFFF9500);
  static const Color errorRed = Color(0xFFFF3B30);
  static const Color cardBackground = Color(0xFF1E2A3E);
  static const Color cardBackgroundLight = Color(0xFF253447);

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0A1628), Color(0xFF1A2742)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF00D9FF), Color(0xFF00FFC2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF00FF88), Color(0xFF00D9B5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Text Styles
  static TextStyle get headingLarge => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      );

  static TextStyle get headingMedium => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: Colors.white70,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: Colors.white60,
      );

  static TextStyle get captionText => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: Colors.white54,
      );

  static TextStyle get buttonText => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );

  // Theme Data
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryDarkBlue,
      scaffoldBackgroundColor: primaryDark,
      colorScheme: const ColorScheme.dark(
        primary: accentCyan,
        secondary: accentTeal,
        surface: cardBackground,
        error: errorRed,
      ),
      textTheme: TextTheme(
        displayLarge: headingLarge,
        displayMedium: headingMedium,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        labelSmall: captionText,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: glassElevatedButtonStyle(
          tintColor: accentCyan,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          borderRadius: 12,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: glassOutlinedButtonStyle(
          tintColor: accentCyan,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          borderRadius: 12,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: glassTextButtonStyle(
          tintColor: accentCyan,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          borderRadius: 10,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: glassIconButtonStyle(
          tintColor: accentCyan,
          borderRadius: 10,
          padding: const EdgeInsets.all(6),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicator: BoxDecoration(
          color: _glassFill(accentCyan, 0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accentCyan.withOpacity(0.35), width: 1),
          boxShadow: [
            BoxShadow(
              color: accentCyan.withOpacity(0.35),
              blurRadius: 14,
              spreadRadius: 0,
            ),
          ],
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBackground.withOpacity(0.6),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: accentCyan.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentCyan.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentCyan.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentCyan, width: 2),
        ),
      ),
    );
  }

  static ButtonStyle glassElevatedButtonStyle({
    Color? tintColor,
    Color? foregroundColor,
    EdgeInsetsGeometry? padding,
    double borderRadius = 12,
    double fillOpacity = 0.14,
    double glowOpacity = 0.35,
    double elevation = 3,
  }) {
    final resolvedTint = tintColor ?? accentCyan;
    final resolvedForeground = foregroundColor ?? Colors.white;

    return ButtonStyle(
      padding:
          padding == null ? null : MaterialStateProperty.all(padding),
      foregroundColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.disabled)) {
          return resolvedForeground.withOpacity(0.5);
        }
        return resolvedForeground;
      }),
      backgroundColor: MaterialStateProperty.resolveWith((states) {
        final opacity =
            states.contains(MaterialState.disabled) ? fillOpacity * 0.6 : fillOpacity;
        return _glassFill(resolvedTint, opacity);
      }),
      shadowColor: MaterialStateProperty.all(
        resolvedTint.withOpacity(glowOpacity),
      ),
      elevation: MaterialStateProperty.resolveWith((states) {
        return states.contains(MaterialState.disabled) ? 0 : elevation;
      }),
      overlayColor:
          MaterialStateProperty.all(resolvedTint.withOpacity(0.12)),
      side: MaterialStateProperty.all(
        BorderSide(color: resolvedTint.withOpacity(0.35), width: 1),
      ),
      shape: MaterialStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  static ButtonStyle glassOutlinedButtonStyle({
    Color? tintColor,
    Color? foregroundColor,
    EdgeInsetsGeometry? padding,
    double borderRadius = 12,
  }) {
    final resolvedTint = tintColor ?? accentCyan;
    return glassElevatedButtonStyle(
      tintColor: resolvedTint,
      foregroundColor: foregroundColor ?? resolvedTint,
      padding: padding,
      borderRadius: borderRadius,
      fillOpacity: 0.06,
      glowOpacity: 0.3,
      elevation: 1,
    ).copyWith(
      side: MaterialStateProperty.all(
        BorderSide(color: resolvedTint.withOpacity(0.4), width: 1.2),
      ),
    );
  }

  static ButtonStyle glassTextButtonStyle({
    Color? tintColor,
    Color? foregroundColor,
    EdgeInsetsGeometry? padding,
    double borderRadius = 10,
  }) {
    final resolvedTint = tintColor ?? accentCyan;
    return glassElevatedButtonStyle(
      tintColor: resolvedTint,
      foregroundColor: foregroundColor ?? resolvedTint,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: borderRadius,
      fillOpacity: 0.04,
      glowOpacity: 0.25,
      elevation: 0,
    ).copyWith(
      side: MaterialStateProperty.all(
        BorderSide(color: resolvedTint.withOpacity(0.25), width: 1),
      ),
    );
  }

  static ButtonStyle glassIconButtonStyle({
    Color? tintColor,
    EdgeInsetsGeometry? padding,
    double borderRadius = 10,
  }) {
    final resolvedTint = tintColor ?? accentCyan;
    return glassElevatedButtonStyle(
      tintColor: resolvedTint,
      padding: padding ?? const EdgeInsets.all(8),
      borderRadius: borderRadius,
      fillOpacity: 0.08,
      glowOpacity: 0.3,
      elevation: 2,
    );
  }

  static Color _glassFill(Color tint, double opacity) {
    final blended = Color.lerp(tint, Colors.white, 0.18) ?? tint;
    return blended.withOpacity(opacity);
  }

  // Box Decorations
  static BoxDecoration get glassCardDecoration => BoxDecoration(
        color: cardBackground.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentCyan.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accentCyan.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      );

  static BoxDecoration get gradientCardDecoration => BoxDecoration(
        gradient: primaryGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentCyan.withOpacity(0.3),
          width: 1,
        ),
      );
}
