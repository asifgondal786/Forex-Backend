import 'package:flutter/material.dart';
import '../features/dashboard/home_screen.dart';
import '../features/market_watch/market_watch_screen.dart';
import '../features/trade_signals/trade_signals_screen.dart';
import '../features/portfolio/portfolio_screen.dart';
import '../features/more/more_screen.dart';
import '../shared/widgets/bottom_nav_bar.dart';
import '../core/widgets/connection_banner.dart';

/// AppShell wraps the entire authenticated experience.
/// It provides the persistent BottomNavBar and global overlays.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  static const _screens = [
    HomeScreen(),
    MarketWatchScreen(),
    TradeSignalsScreen(),
    PortfolioScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const ConnectionBanner(),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: TajirBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}
