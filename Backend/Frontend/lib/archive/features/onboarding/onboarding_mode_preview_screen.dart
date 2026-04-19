import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_shell_provider.dart';
import '../../providers/mode_provider.dart';
import '../../routes/app_routes.dart';
import '../ai_chat/ai_chat_screen.dart';
import '../custom_setup/custom_setup_screen.dart';
import '../embodied_agent/embodied_agent_screen.dart';
import '../market_watch/market_watch_screen.dart';
import '../news/news_events_screen.dart';
import '../paper_trading/paper_trading_screen.dart';
import '../trade_signals/trade_signals_screen.dart';

class OnboardingModePreviewScreen extends StatelessWidget {
  final AppMode mode;

  const OnboardingModePreviewScreen({
    super.key,
    required this.mode,
  });

  void _goHome(BuildContext context) {
    context.read<AppShellProvider>().setTab(0);
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.home,
      (route) => false,
    );
  }

  void _goBackToModes(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    navigator.pushNamedAndRemoveUntil(
      AppRoutes.onboarding,
      (route) => false,
    );
  }

  Widget _buildScreen() {
    return switch (mode) {
      AppMode.marketWatch => const MarketWatchScreen(),
      AppMode.aiChat => const AiChatScreen(embeddedInPreview: true),
      AppMode.aiCopilot => const EmbodiedAgentScreen(embeddedInPreview: true),
      AppMode.tradeSignals => const TradeSignalsScreen(),
      AppMode.newsEvents => const NewsEventsScreen(),
      AppMode.customSetup => const CustomSetupScreen(),
      AppMode.paperTrading => const PaperTradingScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _goBackToModes(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back to Modes',
            onPressed: () => _goBackToModes(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(mode.label),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'Home Dashboard',
              onPressed: () => _goHome(context),
              icon: const Icon(Icons.home_rounded),
            ),
          ],
        ),
        body: _buildScreen(),
      ),
    );
  }
}

