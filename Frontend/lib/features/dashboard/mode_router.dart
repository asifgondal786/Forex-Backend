import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/mode_provider.dart';
import '../embodied_agent/embodied_agent_screen.dart';
import '../ai_chat/ai_chat_screen.dart';
import '../settings/settings_screen.dart';

/// Sits at /dashboard and renders the right screen based on [ModeProvider].
/// Switching mode in Settings instantly re-routes without a full Navigator push.
class ModeRouter extends StatelessWidget {
  const ModeRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<ModeProvider>().mode;

    return switch (mode) {
      // Market Watch → main dashboard (forex feed is already the hero widget)
      AppMode.marketWatch  => const EmbodiedAgentScreen(),

      // AI Chat → raw Gemini chat
      AppMode.aiChat       => const AiChatScreen(),

      // AI Copilot → same chat screen for now; copilot enhancements in Phase 5
      AppMode.aiCopilot    => const AiChatScreen(),

      // Trade Signals → main dashboard (signals panel already lives here)
      AppMode.tradeSignals => const EmbodiedAgentScreen(),

      // News & Events → main dashboard (news_sentiment_widget already here)
      AppMode.newsEvents   => const EmbodiedAgentScreen(),

      // Custom Setup → settings so user can configure preferences
      AppMode.customSetup  => const SettingsScreen(),

      // Fallback
      null                 => const EmbodiedAgentScreen(),
    };
  }
}