import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/mode_provider.dart';
import '../features/market_watch/market_watch_screen.dart';
import '../features/ai_chat/ai_chat_screen.dart';
import '../features/agent/embodied_agent_screen.dart';
import '../features/trade_signals/trade_signals_screen.dart';
import '../features/news/news_events_screen.dart';
import '../features/settings/custom_setup_screen.dart';

/// Routes the /dashboard path to the correct screen based on
/// the active [AppMode] stored in [ModeProvider].
///
/// Drop this widget wherever your previous mode_router was used,
/// e.g. in app_routes.dart:
///   '/dashboard': (_) => const ModeRouter(),
class ModeRouter extends StatelessWidget {
  const ModeRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<ModeProvider>().currentMode;
    return _modeScreen(mode);
  }
}

Widget _modeScreen(AppMode mode) {
  switch (mode) {
    case AppMode.marketWatch:
      return const MarketWatchScreen();
    case AppMode.aiChat:
      return const AiChatScreen();
    case AppMode.aiCopilot:
      return const EmbodiedAgentScreen();
    case AppMode.tradeSignals:
      return const TradeSignalsScreen();
    case AppMode.newsEvents:
      return const NewsEventsScreen();
    case AppMode.customSetup:
      return const CustomSetupScreen();
  }
}