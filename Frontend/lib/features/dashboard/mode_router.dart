// lib/features/dashboard/mode_router.dart
//
// ─────────────────────────────────────────────────────────────────────────────
// Paste these changes into your existing mode_router.dart
// ─────────────────────────────────────────────────────────────────────────────
//
// 1. ADD these imports (replacing any conflicting ones):
//
//    import '../market_watch/market_watch_screen.dart';
//    import '../ai_chat/ai_chat_screen.dart';
//    import '../embodied_agent/embodied_agent_screen.dart';
//    import '../trade_signals/trade_signals_screen.dart';
//    import '../news/news_events_screen.dart';
//    import '../custom_setup/custom_setup_screen.dart';   // ← NEW
//
// 2. In your switch/if block that maps AppMode → screen, add:
//
//    case AppMode.customSetup:           // ← was routing to SettingsScreen
//      return const CustomSetupScreen();
//
// ─────────────────────────────────────────────────────────────────────────────
// FULL REFERENCE IMPLEMENTATION (replace the whole file if easier):
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/mode_provider.dart';
import '../market_watch/market_watch_screen.dart';
import '../ai_chat/ai_chat_screen.dart';
import '../embodied_agent/embodied_agent_screen.dart';
import '../trade_signals/trade_signals_screen.dart';
import '../news/news_events_screen.dart' ;
import '../custom_setup/custom_setup_screen.dart'; // ← NEW

class ModeRouter extends StatelessWidget {
  const ModeRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<ModeProvider>().mode;

    return switch (mode) {
      AppMode.marketWatch   => const MarketWatchScreen(),
      AppMode.aiChat        => const AiChatScreen(),
      AppMode.aiCopilot     => const EmbodiedAgentScreen(),
      AppMode.tradeSignals  => const TradeSignalsScreen(),
      AppMode.newsEvents    => const NewsEventsScreen(),
      AppMode.customSetup   => const CustomSetupScreen(), // ← WAS: SettingsScreen
      null                  => const EmbodiedAgentScreen(),
    };
  }
}
