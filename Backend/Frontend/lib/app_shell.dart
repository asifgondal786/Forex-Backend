import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/automation/automation_screen.dart';
import 'features/dashboard/home_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/trade_signals/trade_signals_screen.dart';
import 'providers/app_shell_provider.dart';
import 'shared/widgets/bottom_nav_bar.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = const [
      HomeScreen(),
      TradeSignalsScreen(),
      AutomationScreen(),
      SettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppShellProvider>(
      builder: (context, shellProvider, _) {
        final safeIndex = shellProvider.currentIndex >= _screens.length
            ? 0
            : shellProvider.currentIndex;

        if (safeIndex != shellProvider.currentIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              shellProvider.setTab(0);
            }
          });
        }

        return Scaffold(
          body: IndexedStack(
            index: safeIndex,
            children: _screens,
          ),
          bottomNavigationBar: TajirBottomNavBar(
            currentIndex: safeIndex,
            onTap: shellProvider.setTab,
          ),
        );
      },
    );
  }
}

