import 'package:flutter/material.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/ai_chat/ai_chat_screen.dart';
import '../features/task_creation/task_creation_screen.dart';
import '../features/task_history/task_history_screen.dart';
import '../features/settings/settings_screen.dart';

class AppRoutes {
  static const String root = '/';
  static const String dashboard = '/dashboard';
  static const String createTask = '/create-task';
  static const String taskHistory = '/task-history';
  static const String aiChat = '/ai-chat';
  static const String settings = '/settings';

  static Map<String, WidgetBuilder> routes = {
    root: (_) => const DashboardScreen(),
    dashboard: (_) => const DashboardScreen(),
    createTask: (_) => const TaskCreationScreen(),
    taskHistory: (_) => const TaskHistoryScreen(),
    aiChat: (_) => const AiChatScreen(),
    settings: (_) => const SettingsScreen(),
  };
}
