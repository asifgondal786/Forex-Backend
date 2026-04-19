// lib/providers/quick_actions_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kDismissedKey = 'quick_actions_dismissed_modes';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────
class QuickAction {
  final String id;
  final String label;
  final String subtitle;
  final String icon;       // emoji icon — no asset dependency
  final String routeOrAction; // named route OR special action key
  final bool isRoute;

  const QuickAction({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.routeOrAction,
    this.isRoute = true,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-mode action definitions
// ─────────────────────────────────────────────────────────────────────────────
const _kActionsByMode = <String, List<QuickAction>>{
  // ── Market Watch ──────────────────────────────────────────────────────────
  'marketWatch': [
    QuickAction(
      id: 'mw_fav',
      label: 'View Favourites',
      subtitle: 'See only the pairs you follow',
      icon: '⭐',
      routeOrAction: 'filter_favourites',
      isRoute: false,
    ),
    QuickAction(
      id: 'mw_top_movers',
      label: 'Top Movers',
      subtitle: 'Biggest % changes right now',
      icon: '🚀',
      routeOrAction: 'filter_movers',
      isRoute: false,
    ),
    QuickAction(
      id: 'mw_setup',
      label: 'Add More Pairs',
      subtitle: 'Customise your watchlist',
      icon: '➕',
      routeOrAction: '/custom-setup',
    ),
    QuickAction(
      id: 'mw_signals',
      label: 'Get AI Signal',
      subtitle: 'See what the AI recommends',
      icon: '🤖',
      routeOrAction: 'switch_signals',
      isRoute: false,
    ),
  ],

  // ── AI Chat ───────────────────────────────────────────────────────────────
  'aiChat': [
    QuickAction(
      id: 'ac_analyse',
      label: 'Analyse My Pairs',
      subtitle: 'Ask AI to review your watchlist',
      icon: '🔍',
      routeOrAction: 'prompt_analyse',
      isRoute: false,
    ),
    QuickAction(
      id: 'ac_explain',
      label: 'Explain a Signal',
      subtitle: 'Get plain-English trade reasoning',
      icon: '💡',
      routeOrAction: 'prompt_explain',
      isRoute: false,
    ),
    QuickAction(
      id: 'ac_risk',
      label: 'Check My Risk',
      subtitle: 'How much am I risking right now?',
      icon: '🛡️',
      routeOrAction: 'prompt_risk',
      isRoute: false,
    ),
    QuickAction(
      id: 'ac_news',
      label: 'What\'s Moving Markets?',
      subtitle: 'Latest macro news summary',
      icon: '📰',
      routeOrAction: 'prompt_news',
      isRoute: false,
    ),
  ],

  // ── AI Copilot ────────────────────────────────────────────────────────────
  'aiCopilot': [
    QuickAction(
      id: 'cop_start',
      label: 'Start Guided Session',
      subtitle: 'Let the AI walk you through a trade',
      icon: '▶️',
      routeOrAction: 'copilot_start',
      isRoute: false,
    ),
    QuickAction(
      id: 'cop_paper',
      label: 'Paper Trade Mode',
      subtitle: 'Practice with zero real risk',
      icon: '📋',
      routeOrAction: 'copilot_paper',
      isRoute: false,
    ),
    QuickAction(
      id: 'cop_review',
      label: 'Review Last Session',
      subtitle: 'See what the AI recommended',
      icon: '📊',
      routeOrAction: '/task-history',
    ),
    QuickAction(
      id: 'cop_settings',
      label: 'Adjust AI Behaviour',
      subtitle: 'Risk level, pair prefs, signals',
      icon: '⚙️',
      routeOrAction: '/custom-setup',
    ),
  ],

  // ── Trade Signals ─────────────────────────────────────────────────────────
  'tradeSignals': [
    QuickAction(
      id: 'ts_buy',
      label: 'Buy Signals Only',
      subtitle: 'Filter to long opportunities',
      icon: '📈',
      routeOrAction: 'filter_buy',
      isRoute: false,
    ),
    QuickAction(
      id: 'ts_sell',
      label: 'Sell Signals Only',
      subtitle: 'Filter to short opportunities',
      icon: '📉',
      routeOrAction: 'filter_sell',
      isRoute: false,
    ),
    QuickAction(
      id: 'ts_high_conf',
      label: 'High Confidence',
      subtitle: 'Signals with 70%+ confidence',
      icon: '🎯',
      routeOrAction: 'filter_high_conf',
      isRoute: false,
    ),
    QuickAction(
      id: 'ts_explain',
      label: 'Explain a Signal',
      subtitle: 'Ask AI about any signal',
      icon: '🤖',
      routeOrAction: 'switch_chat',
      isRoute: false,
    ),
  ],

  // ── News & Events ─────────────────────────────────────────────────────────
  'newsEvents': [
    QuickAction(
      id: 'ne_calendar',
      label: 'Economic Calendar',
      subtitle: 'Upcoming high-impact events',
      icon: '📅',
      routeOrAction: 'tab_calendar',
      isRoute: false,
    ),
    QuickAction(
      id: 'ne_high',
      label: 'High-Impact Only',
      subtitle: 'Filter to market-moving news',
      icon: '🔴',
      routeOrAction: 'filter_high',
      isRoute: false,
    ),
    QuickAction(
      id: 'ne_bullish',
      label: 'Bullish News',
      subtitle: 'Positive sentiment articles',
      icon: '🟢',
      routeOrAction: 'filter_bullish',
      isRoute: false,
    ),
    QuickAction(
      id: 'ne_ask_ai',
      label: 'Ask AI About News',
      subtitle: 'What does this mean for my trades?',
      icon: '💬',
      routeOrAction: 'switch_chat',
      isRoute: false,
    ),
  ],

  // ── Custom Setup ──────────────────────────────────────────────────────────
  'customSetup': [
    QuickAction(
      id: 'cs_pairs',
      label: 'Pick Your Pairs',
      subtitle: 'Choose currencies you trade',
      icon: '💱',
      routeOrAction: 'scroll_pairs',
      isRoute: false,
    ),
    QuickAction(
      id: 'cs_risk',
      label: 'Set Risk Level',
      subtitle: 'Conservative, Moderate or Aggressive',
      icon: '🛡️',
      routeOrAction: 'scroll_risk',
      isRoute: false,
    ),
    QuickAction(
      id: 'cs_indicators',
      label: 'Add Indicators',
      subtitle: 'RSI, MACD, Bollinger and more',
      icon: '📊',
      routeOrAction: 'scroll_indicators',
      isRoute: false,
    ),
    QuickAction(
      id: 'cs_save',
      label: 'Save & Launch',
      subtitle: 'Apply settings and go to dashboard',
      icon: '✅',
      routeOrAction: 'save_and_launch',
      isRoute: false,
    ),
  ],
};

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────
class QuickActionsProvider extends ChangeNotifier {
  Set<String> _dismissedModes = {};

  bool isVisible(String modeKey) => !_dismissedModes.contains(modeKey);

  List<QuickAction> actionsFor(String modeKey) =>
      _kActionsByMode[modeKey] ?? [];

  void dismiss(String modeKey) {
    _dismissedModes.add(modeKey);
    _persist();
    notifyListeners();
  }

  void restoreAll() {
    _dismissedModes.clear();
    _persist();
    notifyListeners();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_kDismissedKey) ?? [];
    _dismissedModes = saved.toSet();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kDismissedKey, _dismissedModes.toList());
  }
}

