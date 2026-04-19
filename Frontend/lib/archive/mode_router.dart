import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/mode_provider.dart';
import '../market_watch/market_watch_screen.dart';
import '../ai_chat/ai_chat_screen.dart';
import '../embodied_agent/embodied_agent_screen.dart';
import '../trade_signals/trade_signals_screen.dart';
import '../news/news_events_screen.dart';
import '../custom_setup/custom_setup_screen.dart';
import '../charts/chart_screen.dart';
import '../news/event_countdown_widget.dart';
import '../paper_trading/paper_trading_screen.dart';

class ModeRouter extends StatelessWidget {
  const ModeRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<ModeProvider>().mode;

    final screen = switch (mode) {
      AppMode.marketWatch   => const MarketWatchScreen(),
      AppMode.aiChat        => const AiChatScreen(),
      AppMode.aiCopilot     => const EmbodiedAgentScreen(),
      AppMode.tradeSignals  => const TradeSignalsScreen(),
      AppMode.newsEvents    => const NewsEventsScreen(),
      AppMode.customSetup   => const CustomSetupScreen(),
      AppMode.paperTrading  => const PaperTradingScreen(),
      null                  => const EmbodiedAgentScreen(),
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/onboarding',
            (route) => false,
          );
        }
      },
      child: Stack(
        children: [
          Column(
            children: [
              const EventCountdownWidget(),
              Expanded(child: screen),
            ],
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              heroTag: 'charts_fab',
              onPressed: () => Navigator.pushNamed(context, '/charts'),
              icon: const Icon(Icons.candlestick_chart),
              label: const Text('Charts'),
            ),
          ),
        ],
      ),
    );
  }
}

