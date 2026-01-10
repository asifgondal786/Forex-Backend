import '../features/ai_chat/ai_chat_screen.dart';
import 'package:flutter/material.dart';
import '../features/dashboard/dashboard_screen.dart';

class AppRoutes {
  static Map<String, WidgetBuilder> routes = {
    '/': (_) => const DashboardScreen(),
    '/create-task': (_) => const Scaffold(
          body: Center(child: Text('Create Task Screen')),
        ),
    '/task-history': (_) => const Scaffold(
          body: Center(child: Text('Task History Screen')),
        ),
        '/ai-chat': (context) => const AiChatScreen(),
    '/settings': (_) => const Scaffold(
          body: Center(child: Text('Settings Screen')),
        ),
  };
}