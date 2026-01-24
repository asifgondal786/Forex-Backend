import '../features/ai_chat/ai_chat_screen.dart';
import '../features/task_creation/task_creation_screen.dart';
import '../features/task_history/task_history_screen.dart';
import '../features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/dashboard/dashboard_screen_enhanced.dart';

class AppRoutes {
  static Map<String, WidgetBuilder> routes = {
    '/': (_) => const DashboardScreenEnhanced(),
    '/dashboard': (_) => const DashboardScreen(),
    '/create-task': (_) => const TaskCreationScreen(),
    '/task-history': (_) => const TaskHistoryScreen(),
    '/ai-chat': (context) => const AiChatScreen(),
    '/settings': (_) => const SettingsScreen(),
  };
}