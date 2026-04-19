import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../app_shell.dart';
import '../features/auth/auth_entry_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/password_reset_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/auth/verification_screen.dart';

/// Main routing configuration for Tajir app
/// 
/// Routes are organized by authentication state:
/// - Public routes: auth entry, login, signup, password reset
/// - Protected routes: main app shell with 4 tabs (Home, Signals, Automation, Settings)
class AppRoutes {
  // Public auth routes
  static const String root = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String verify = '/verify';
  static const String reset = '/reset';

  // Protected app routes
  static const String home = '/home';

  static final Map<String, WidgetBuilder> routes = {
    root: (_) => const AuthEntryScreen(),
    login: (_) => LoginScreen(onLoginSuccess: () {}),
    signup: (_) => const SignupScreen(),
    verify: (_) => const VerificationScreen(),
    reset: (_) => const PasswordResetScreen(),
    home: (_) => const _ProtectedRoute(child: AppShell()),
  };
}

class _ProtectedRoute extends StatelessWidget {
  final Widget child;

  const _ProtectedRoute({required this.child});

  bool get _firebaseReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_firebaseReady) {
      return LoginScreen(onLoginSuccess: () {});
    }

    return StreamBuilder<firebase_auth.User?>(
      stream: firebase_auth.FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == null) {
          return LoginScreen(onLoginSuccess: () {});
        }

        return child;
      },
    );
  }
}

