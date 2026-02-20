import 'package:flutter/material.dart';
import '../features/embodied_agent/embodied_agent_screen.dart';
import '../features/auth/auth_gate.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/auth/verification_screen.dart';
import '../features/ai_chat/ai_chat_screen.dart';
import '../features/task_creation/task_creation_screen.dart';
import '../features/task_history/task_history_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/admin/user_admin_dashboard_screen.dart';

class AppRoutes {
  static const String root = '/';
  static const String dashboard = '/dashboard';
  static const String createTask = '/create-task';
  static const String taskHistory = '/task-history';
  static const String aiChat = '/ai-chat';
  static const String settings = '/settings';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String verify = '/verify';
  static const String profile = '/profile';
  static const String security = '/security';
  static const String help = '/help';

  static Map<String, WidgetBuilder> routes = {
    root: (_) => const AuthGate(),
    login: (_) => LoginScreen(onLoginSuccess: () {}),
    signup: (_) => const SignupScreen(),
    verify: (_) => const VerificationScreen(),
    dashboard: (_) => const EmbodiedAgentScreen(),
    createTask: (_) => const TaskCreationScreen(),
    taskHistory: (_) => const TaskHistoryScreen(),
    aiChat: (_) => const AiChatScreen(),
    settings: (_) => const SettingsScreen(),
    profile: (_) => const UserAdminDashboardScreen(),
    security: (_) => const PlaceholderScreen(title: 'Security'),
    help: (_) => const PlaceholderScreen(title: 'Help & Support'),
  };
}

class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '$title Page',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'This page is under construction',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
