import 'package:flutter/material.dart';
import 'package:forex_companion/config/theme.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = true; // Default to dark mode

  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void setDarkMode(bool isDark) {
    if (_isDarkMode == isDark) return;
    _isDarkMode = isDark;
    notifyListeners();
  }

  ThemeData getThemeData() {
    return _isDarkMode ? AppTheme.darkTheme : ThemeData.light();
  }
}

