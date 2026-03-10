import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Enum ────────────────────────────────────────────────────────────────────

enum AppMode {
  marketWatch,
  aiChat,
  aiCopilot,
  tradeSignals,
  newsEvents,
  customSetup,
}

extension AppModeX on AppMode {
  String get key => name; // stored as plain string in SharedPreferences

  String get label => switch (this) {
        AppMode.marketWatch  => 'Market Watch',
        AppMode.aiChat       => 'AI Chat',
        AppMode.aiCopilot    => 'AI Copilot',
        AppMode.tradeSignals => 'Trade Signals',
        AppMode.newsEvents   => 'News & Events',
        AppMode.customSetup  => 'Custom Setup',
      };

  IconData get icon => switch (this) {
        AppMode.marketWatch  => Icons.candlestick_chart_rounded,
        AppMode.aiChat       => Icons.chat_bubble_rounded,
        AppMode.aiCopilot    => Icons.auto_awesome_rounded,
        AppMode.tradeSignals => Icons.trending_up_rounded,
        AppMode.newsEvents   => Icons.newspaper_rounded,
        AppMode.customSetup  => Icons.tune_rounded,
      };
}

// ─── Provider ────────────────────────────────────────────────────────────────

class ModeProvider extends ChangeNotifier {
  static const _prefKey = 'tajir_app_mode';

  AppMode? _mode;
  bool _loaded = false;

  AppMode? get mode => _mode;
  bool get loaded => _loaded;

  /// True once user has picked a mode at onboarding
  bool get hasChosen => _mode != null;

  /// Load persisted mode on app boot — call once in main()
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKey);
    if (stored != null) {
      _mode = AppMode.values.firstWhere(
        (m) => m.key == stored,
        orElse: () => AppMode.aiChat,
      );
    }
    _loaded = true;
    notifyListeners();
  }

  /// Persist and notify — called from onboarding + settings
  Future<void> setMode(AppMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, mode.key);
  }

  /// Reset — useful for testing or "start over" in settings
  Future<void> clearMode() async {
    _mode = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }
}