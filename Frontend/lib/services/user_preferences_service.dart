import 'package:shared_preferences/shared_preferences.dart';

class UserPreferencesService {
  static const String _themeKey = 'user_theme_preference';
  static const String _languageKey = 'user_language';
  static const String _notificationsKey = 'user_notifications_enabled';
  static const String _soundKey = 'user_sound_enabled';
  static const String _autoTradeKey = 'user_auto_trade_enabled';
  static const String _riskLevelKey = 'user_risk_level';

  late SharedPreferences _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Theme Preferences
  Future<void> setTheme(String theme) async {
    await _prefs.setString(_themeKey, theme);
  }

  String getTheme() {
    return _prefs.getString(_themeKey) ?? 'auto';
  }

  // Language Preferences
  Future<void> setLanguage(String language) async {
    await _prefs.setString(_languageKey, language);
  }

  String getLanguage() {
    return _prefs.getString(_languageKey) ?? 'en';
  }

  // Notification Preferences
  Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs.setBool(_notificationsKey, enabled);
  }

  bool isNotificationsEnabled() {
    return _prefs.getBool(_notificationsKey) ?? true;
  }

  // Sound Preferences
  Future<void> setSoundEnabled(bool enabled) async {
    await _prefs.setBool(_soundKey, enabled);
  }

  bool isSoundEnabled() {
    return _prefs.getBool(_soundKey) ?? true;
  }

  // Auto Trade Preferences
  Future<void> setAutoTradeEnabled(bool enabled) async {
    await _prefs.setBool(_autoTradeKey, enabled);
  }

  bool isAutoTradeEnabled() {
    return _prefs.getBool(_autoTradeKey) ?? false;
  }

  // Risk Level Preferences
  Future<void> setRiskLevel(String level) async {
    await _prefs.setString(_riskLevelKey, level);
  }

  String getRiskLevel() {
    return _prefs.getString(_riskLevelKey) ?? 'medium';
  }

  // Clear All Preferences
  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
